import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:logging/logging.dart';

import '../core/contracts/playback.dart';
import '../core/errors.dart';
import '../core/models/playback.dart';
import '../core/models/track.dart';
import '../core/platform/platform_info.dart';
import '../core/util/cancel_token.dart';
import '../settings/app_settings.dart';
import '../settings/settings_store.dart';
import 'backend/audio_backend.dart';
import 'engine/gain.dart';
import 'engine/interruption_policy.dart';
import 'engine/listen_clock.dart';
import 'engine/playback_tuning.dart';
import 'queue/play_queue.dart';
import 'queue/queue_state_store.dart';
import 'queue_silo.dart';

part 'controller/fades.dart';
part 'controller/housekeeping.dart';
part 'controller/prefetch.dart';
part 'controller/state.dart';
part 'controller/transitions.dart';

final _log = Logger('playback.controller');

/// The playback engine: queue, transport, crossfade/gapless transitions,
/// normalization, sleep timer, interruptions and persistence.
///
/// Lives for the whole process (created in `bootstrap.dart`), independent of
/// any widget, so UI navigation never affects audio. Platform media sessions
/// observe [snapshots]/[queueStream]/[events] and call the transport methods.
class PlaybackControllerImpl implements PlaybackController {
  PlaybackControllerImpl({
    required this._backend,
    required this._resolver,
    required SettingsStore settings,
    required File stateFile,
    this._smartQueueProvider,
    PlatformInfo? platform,
    this._tuning = const PlaybackTuning(),
    QueueStateStore? stateStore,
    DateTime Function()? now,
    math.Random? random,
    this._silo,
  })  : _settings = settings,
        _store = stateStore ?? QueueStateStore(stateFile),
        _platform = platform ?? PlatformInfo.current(),
        _now = now ?? DateTime.now,
        _queue = PlayQueue(random: random),
        _volume = settings.current.playback.volume,
        _speed = settings.current.playback.speed,
        _lastSettings = settings.current;

  final AudioBackend _backend;
  final StreamResolver _resolver;
  final SettingsStore _settings;

  /// Provider-terms queue silo shared with the stream resolver (may be null
  /// in tests).
  final QueueSilo? _silo;
  final QueueStateStore _store;
  final Future<List<Track>> Function(List<Track> recent)? _smartQueueProvider;
  final PlatformInfo _platform;
  final PlaybackTuning _tuning;
  final DateTime Function() _now;
  final PlayQueue _queue;
  final InterruptionPolicy _interruptions = InterruptionPolicy();

  final _snapshotCtrl = StreamController<PlaybackSnapshot>.broadcast();
  final _queueCtrl = StreamController<QueueState>.broadcast();
  final _eventCtrl = StreamController<PlaybackEvent>.broadcast();

  // Decks are created lazily (the second one only when crossfading).
  final List<AudioDeck?> _decks = [null, null];
  final List<StreamSubscription<Object?>> _deckSubs = [];
  int _activeDeck = 0;

  /// The item currently opened on a deck (null while resolving, parked,
  /// stopped or idle).
  _Loaded? _loaded;
  _Prefetch? _prefetch;
  _Crossfade? _crossfade;

  /// Position of the current item while it is not loaded on a deck.
  Duration _pendingPosition = Duration.zero;

  /// Last requested seek/start position until the deck reports it.
  Duration? _seekTarget;
  DateTime? _seekTargetAt;

  /// What the user wants (play/pause), independent of deck transitions.
  bool _playIntent = false;
  PlayerStatus _status = PlayerStatus.idle;
  String? _error;
  double _volume;
  double _speed;
  double _duck = 1.0;
  double _sleepFade = 1.0;

  int _loadGen = 0;
  bool _loading = false;
  int _loadingDeck = 0;
  CancelToken? _loadCancel;
  int _failureStreak = 0;

  DateTime? _sleepEndsAt;
  bool _sleepAtEndOfTrack = false;
  Timer? _sleepTimer;
  Timer? _sleepFadeStartTimer;
  Timer? _sleepFadeTimer;
  Duration _sleepFadeLength = Duration.zero;

  Timer? _ticker;
  Timer? _persistTimer;
  Timer? _settingsWriteTimer;
  DateTime? _lastPersistAt;
  int _encodedListsRevision = -1;
  Map<String, String>? _encodedLists;
  bool _emitScheduled = false;

  AppSettings _lastSettings;
  String? _activeDeviceId;
  StreamSubscription<AppSettings>? _settingsSub;
  StreamSubscription<AudioInterruption>? _interruptSub;
  StreamSubscription<List<AudioOutputDevice>>? _devicesSub;

  bool _initialized = false;
  bool _disposed = false;

  // ------------------------------------------------------------------ state

  @override
  PlaybackSnapshot get snapshot => _buildSnapshot();

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshotCtrl.stream;

  @override
  QueueState get queue => _queue.state;

  @override
  Stream<QueueState> get queueStream => _queueCtrl.stream;

  @override
  Stream<PlaybackEvent> get events => _eventCtrl.stream;

  @override
  bool get supportsSpeed => _backend.supportsSpeed;

  @override
  bool get supportsOutputDeviceSelection => _platform.isDesktop && _backend.supportsOutputDeviceSelection;

  // -------------------------------------------------------------- lifecycle

  @override
  Future<void> init() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    await _backend.init();
    await _backend.setNormalization(_normalizationFor(_settings.current.playback));
    _settingsSub = _settings.changes.listen(_onSettingsChanged);
    _interruptSub = _backend.interruptions.listen(_onInterruption);
    if (supportsOutputDeviceSelection) {
      _devicesSub = _backend.outputDevicesChanges.listen(_onDevicesChanged);
      await _applySavedOutputDevice();
    }
    await _restoreState();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    final position = _positionNow;
    _endCurrent(completed: false);
    _disposed = true;
    _loadGen++;
    _loadCancel?.cancel();
    _prefetch?.cancel.cancel();
    _prefetch = null;
    for (final t in [_ticker, _persistTimer, _sleepTimer, _sleepFadeStartTimer, _sleepFadeTimer]) {
      t?.cancel();
    }
    _crossfade?.timer?.cancel();
    _crossfade = null;
    if (_settingsWriteTimer != null) {
      _settingsWriteTimer!.cancel();
      _writeSettingsNow();
    }
    await _store.write(_persistedState(position));
    await _store.flush();
    // Cancellation results are irrelevant here; do not wait for them.
    for (final s in [_settingsSub, _interruptSub, _devicesSub, ..._deckSubs]) {
      unawaited(s?.cancel());
    }
    for (final deck in _decks) {
      try {
        await deck?.stop();
      } catch (e) {
        _log.fine('Ignoring deck stop failure during dispose', e);
      }
    }
    await _backend.dispose();
    unawaited(_snapshotCtrl.close());
    unawaited(_queueCtrl.close());
    unawaited(_eventCtrl.close());
  }

  // -------------------------------------------------------------- transport

  @override
  Future<void> playTracks(
    List<Track> tracks, {
    int startIndex = 0,
    String? origin,
    String? originLabel,
    bool shuffle = false,
    Duration? startPosition,
  }) async {
    if (!_guard()) return;
    _interruptions.userTookControl();
    if (tracks.isEmpty) {
      await clearQueue(keepCurrent: false);
      return;
    }
    final crossfade = _manualCrossfadeAllowed();
    _endCurrent(completed: false);
    _silo?.reset();
    _queue.replace(tracks, startIndex: startIndex, origin: origin, originLabel: originLabel, shuffle: shuffle);
    _failureStreak = 0;
    _emitQueue();
    await _loadCurrent(autoplay: true, start: startPosition ?? Duration.zero, crossfade: crossfade);
  }

  @override
  Future<void> play() async {
    if (!_guard()) return;
    _interruptions.userTookControl();
    await _resume();
  }

  @override
  Future<void> pause() async {
    if (!_guard()) return;
    _interruptions.userTookControl();
    await _pauseInternal();
  }

  @override
  Future<void> togglePlayPause() => _playIntent ? pause() : play();

  @override
  Future<void> stop() async {
    if (!_guard()) return;
    _interruptions.userTookControl();
    final position = _positionNow;
    _endCurrent(completed: false);
    _park(position);
    await _persistNow();
  }

  @override
  Future<void> next() async {
    if (!_guard() || _queue.isEmpty) return;
    _interruptions.userTookControl();
    final autoplay = _playIntent;
    if (_queue.peekNextIndex(manual: true) == null) {
      _endCurrent(completed: false);
      await _onQueueEnd();
      return;
    }
    final crossfade = _manualCrossfadeAllowed();
    _endCurrent(completed: false);
    _queue.advance(manual: true);
    _emitQueue();
    await _selectCurrent(autoplay: autoplay, crossfade: crossfade);
  }

  @override
  Future<void> previous() async {
    if (!_guard() || _queue.current == null) return;
    _interruptions.userTookControl();
    final threshold = Duration(seconds: _settings.current.playback.previousRestartThresholdSeconds);
    if (_positionNow > threshold || _queue.peekPreviousIndex() == null) {
      await seek(Duration.zero);
      return;
    }
    final autoplay = _playIntent;
    final crossfade = _manualCrossfadeAllowed();
    _endCurrent(completed: false);
    _queue.goPrevious();
    _emitQueue();
    await _selectCurrent(autoplay: autoplay, crossfade: crossfade);
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_guard()) return;
    var target = position.isNegative ? Duration.zero : position;
    final duration = _durationNow;
    if (duration != null && duration > Duration.zero && target > duration) target = duration;
    final loaded = _loaded;
    if (loaded == null) {
      _pendingPosition = target;
      _markDirty();
      _schedulePersist();
      return;
    }
    _finishCrossfade();
    if (_isExpired(loaded.source)) {
      // Signed URL expired: re-resolve and continue at the requested position.
      await _loadCurrent(autoplay: _playIntent, start: target, continuing: loaded);
      return;
    }
    _expectPosition(target);
    await _deckAt(loaded.deck).seek(target);
    _markDirty();
    _schedulePersist();
  }

  @override
  Future<void> seekRelative(Duration delta) => seek(_positionNow + delta);

  @override
  Future<void> skipToIndex(int index) async {
    if (!_guard() || index < 0 || index >= _queue.length) return;
    _interruptions.userTookControl();
    final crossfade = _manualCrossfadeAllowed();
    _endCurrent(completed: false);
    _queue.skipToIndex(index);
    _emitQueue();
    await _loadCurrent(autoplay: true, crossfade: crossfade);
  }

  // ------------------------------------------------------------ queue modes

  @override
  Future<void> setShuffle(bool enabled) async {
    if (!_guard()) return;
    _queue.setShuffle(enabled);
    _queueChanged();
  }

  @override
  Future<void> setRepeat(RepeatMode mode) async {
    if (!_guard()) return;
    _queue.repeat = mode;
    _revalidatePrefetch();
    _schedulePersist();
    _markDirty();
  }

  @override
  Future<void> cycleRepeat() => setRepeat(switch (_queue.repeat) {
        RepeatMode.off => RepeatMode.all,
        RepeatMode.all => RepeatMode.one,
        RepeatMode.one => RepeatMode.off,
      });

  // ------------------------------------------------------------ queue edits

  @override
  Future<void> enqueue(List<Track> tracks, {String? origin}) async {
    if (!_guard() || tracks.isEmpty) return;
    final firstNew = _queue.length;
    _queue.enqueue(tracks, origin: origin);
    _selectAddedIfIdle(firstNew);
    _queueChanged();
  }

  @override
  Future<void> playNext(List<Track> tracks, {String? origin}) async {
    if (!_guard() || tracks.isEmpty) return;
    final firstNew = _queue.current == null ? 0 : _queue.currentIndex + 1;
    _queue.playNext(tracks, origin: origin);
    _selectAddedIfIdle(firstNew);
    _queueChanged();
  }

  @override
  Future<void> removeFromQueue(String uid) async {
    if (!_guard()) return;
    final wasLast = _queue.current?.uid == uid && _queue.currentIndex == _queue.length - 1;
    final removal = _queue.remove(uid);
    if (removal == null) return;
    if (removal.wasCurrent) {
      _endCurrent(completed: false);
      _emitQueue();
      if (_queue.current == null) {
        _park(Duration.zero);
      } else {
        await _selectCurrent(autoplay: _playIntent && !wasLast);
      }
      _schedulePersist();
      return;
    }
    _queueChanged();
  }

  @override
  Future<void> moveQueueItem(int from, int to) async {
    if (!_guard()) return;
    if (_queue.move(from, to)) _queueChanged();
  }

  @override
  Future<void> clearQueue({bool keepCurrent = true}) async {
    if (!_guard()) return;
    if (!keepCurrent || _queue.current == null) {
      _endCurrent(completed: false);
      _queue.clear(keepCurrent: false);
      _silo?.reset();
      _park(Duration.zero);
    } else {
      _queue.clear(keepCurrent: true);
    }
    _queueChanged();
  }

  // ------------------------------------------------------------ audio props

  @override
  Future<void> setVolume(double volume) async {
    if (!_guard()) return;
    final v = volume.isNaN ? 0.0 : volume.clamp(0.0, 1.0);
    if (v == _volume) return;
    _volume = v;
    _applyGain();
    _scheduleSettingsWrite();
    _markDirty();
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (!_guard() || !supportsSpeed) return;
    final s = speed.isNaN ? 1.0 : speed.clamp(0.5, 2.0);
    if (s == _speed) return;
    await _applySpeed(s);
    _scheduleSettingsWrite();
  }

  @override
  Future<void> setSleepTimer(Duration? duration, {bool endOfTrack = false}) async {
    if (!_guard()) return;
    _cancelSleepTimer();
    if (endOfTrack) {
      _sleepAtEndOfTrack = true;
      _revalidatePrefetch();
    } else if (duration != null && duration > Duration.zero) {
      _startSleepTimer(duration);
    }
    _markDirty();
  }

  @override
  Future<List<AudioOutputDevice>> outputDevices() async =>
      supportsOutputDeviceSelection ? _backend.outputDevices() : const [];

  @override
  Future<void> setOutputDevice(String deviceId) async {
    if (!_guard()) return;
    if (!supportsOutputDeviceSelection) {
      _log.warning('Output device selection is not supported on this platform');
      return;
    }
    final devices = await _backend.outputDevices();
    final device = devices.where((d) => d.id == deviceId).firstOrNull;
    if (device == null) throw ArgumentError.value(deviceId, 'deviceId', 'Unknown output device');
    final id = device.isDefault ? null : device.id;
    await _backend.setOutputDevice(id);
    _activeDeviceId = id;
    await _settings.update((s) => s.copyWith(
          playback: id == null
              ? s.playback.copyWith(clearOutputDevice: true)
              : s.playback.copyWith(outputDeviceId: id),
        ));
  }

  @override
  Future<void> saveState() async {
    if (_disposed) return;
    await _persistNow();
    await _store.flush();
  }

  // ---------------------------------------------------------------- helpers

  /// False after [dispose] (calls become no-ops); throws before [init].
  bool _guard() {
    if (_disposed) return false;
    if (!_initialized) throw StateError('PlaybackControllerImpl.init() must be called first');
    return true;
  }
}
