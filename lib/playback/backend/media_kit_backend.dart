import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart' as mk;

import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import '../../settings/app_settings.dart';
import 'audio_backend.dart';

final _log = Logger('playback.mediakit');

/// Desktop backend (Linux/Windows) on libmpv via `media_kit`.
///
/// * audio only (`vo=null`, `vid=no`), process/window title "Fermata",
///   PulseAudio/PipeWire client name "Fermata", in-memory demuxer cache only
///   (stream audio is never written to disk),
/// * gapless through a 2-item mpv playlist (`gapless-audio=yes`,
///   `prefetch-playlist=yes`),
/// * ReplayGain (`replaygain`, `replaygain-preamp`, `replaygain-clip`) and
///   EBU R128 (`af=lavfi=[loudnorm=I=-16:TP=-1.5:LRA=11]`),
/// * output device listing/selection (`audio-device`).
///
/// Call [ensureInitialized] once (bootstrap) before creating the backend.
class MediaKitBackend implements AudioBackend {
  MediaKitBackend({
    this._configuration = defaultConfiguration,
    Map<String, String> extraMpvOptions = const {},
  }) : _extraOptions = extraMpvOptions;

  /// Loads libmpv. Safe to call more than once.
  static void ensureInitialized({String? libmpv}) => mk.MediaKit.ensureInitialized(libmpv: libmpv);

  static const defaultConfiguration = mk.PlayerConfiguration(
    title: 'Fermata',
    vo: 'null',
    // Per deck; enough for ~2 min of 320 kbps or ~15 s of hi-res FLAC ahead.
    bufferSize: 16 * 1024 * 1024,
    logLevel: mk.MPVLogLevel.error,
  );

  /// Options applied to every player after creation (before any load).
  static const baseMpvOptions = {
    'audio-client-name': 'Fermata',
    'gapless-audio': 'yes',
    'prefetch-playlist': 'yes',
    'cache-on-disk': 'no',
    'network-timeout': '15',
    'stream-lavf-o': 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5',
  };

  static const loudnormFilter = 'lavfi=[loudnorm=I=-16:TP=-1.5:LRA=11]';

  final mk.PlayerConfiguration _configuration;
  final Map<String, String> _extraOptions;
  final _decks = <MediaKitDeck>[];
  final _devicesCtrl = StreamController<List<AudioOutputDevice>>.broadcast();
  final _interruptions = StreamController<AudioInterruption>.broadcast();
  NormalizationConfig _normalization = const NormalizationConfig.off();
  String? _deviceId;
  mk.Player? _probe;
  StreamSubscription<List<mk.AudioDevice>>? _devicesSub;
  bool _disposed = false;

  NormalizationConfig get normalization => _normalization;
  String? get outputDeviceId => _deviceId;

  /// mpv properties for a normalization config (exposed for tests).
  static Map<String, String> normalizationProperties(NormalizationConfig c) {
    if (!c.enabled) return const {'replaygain': 'no', 'af': ''};
    return switch (c.mode) {
      NormalizationMode.loudness => const {'replaygain': 'no', 'af': loudnormFilter},
      NormalizationMode.replayGainTrack || NormalizationMode.replayGainAlbum => {
          'replaygain': c.mode == NormalizationMode.replayGainAlbum ? 'album' : 'track',
          'replaygain-preamp': c.preampDb.toStringAsFixed(2),
          'replaygain-clip': 'yes',
          'af': '',
        },
    };
  }

  /// Maps mpv devices to the app model (`auto` = system default).
  static AudioOutputDevice mapDevice(mk.AudioDevice d) => AudioOutputDevice(
        id: d.name,
        name: d.description.isNotEmpty ? d.description : (d.name == 'auto' ? 'System default' : d.name),
        isDefault: d.name == 'auto',
      );

  mk.Player _newPlayer() {
    final player = mk.Player(configuration: _configuration);
    _devicesSub ??= player.stream.audioDevices.listen((list) {
      if (!_devicesCtrl.isClosed) _devicesCtrl.add([for (final d in list) mapDevice(d)]);
    });
    return player;
  }

  Future<void> configurePlayer(mk.Player player) async {
    final native = player.platform;
    if (native is! mk.NativePlayer) return;
    final options = {
      ...baseMpvOptions,
      ..._extraOptions,
      ...normalizationProperties(_normalization),
    };
    for (final e in options.entries) {
      await native.setProperty(e.key, e.value);
    }
    if (_deviceId != null) await player.setAudioDevice(mk.AudioDevice(_deviceId!, ''));
  }

  @override
  Future<void> init() async {}

  @override
  AudioDeck createDeck() {
    if (_disposed) throw StateError('MediaKitBackend disposed');
    final deck = MediaKitDeck._(this, _newPlayer());
    _decks.add(deck);
    return deck;
  }

  @override
  bool get supportsSpeed => true;

  @override
  bool get supportsOutputDeviceSelection => true;

  @override
  bool get supportsLoudnessNormalization => true;

  @override
  Future<List<AudioOutputDevice>> outputDevices() async {
    final player = _decks.isNotEmpty ? _decks.first._player : (_probe ??= _newPlayer());
    var devices = player.state.audioDevices;
    if (devices.isEmpty) {
      try {
        devices = await player.stream.audioDevices.firstWhere((l) => l.isNotEmpty).timeout(const Duration(seconds: 2));
      } on TimeoutException {
        _log.fine('mpv reported no audio devices');
      }
    }
    final mapped = [for (final d in devices) mapDevice(d)];
    if (!mapped.any((d) => d.isDefault)) {
      mapped.insert(0, const AudioOutputDevice(id: 'auto', name: 'System default', isDefault: true));
    }
    return mapped;
  }

  @override
  Stream<List<AudioOutputDevice>> get outputDevicesChanges => _devicesCtrl.stream;

  @override
  Future<void> setOutputDevice(String? deviceId) async {
    _deviceId = deviceId == 'auto' ? null : deviceId;
    final device = _deviceId == null ? mk.AudioDevice.auto() : mk.AudioDevice(_deviceId!, '');
    for (final deck in _decks) {
      await deck._ready;
      await deck._player.setAudioDevice(device);
    }
  }

  @override
  Future<void> setNormalization(NormalizationConfig config) async {
    _normalization = config;
    final props = normalizationProperties(config);
    for (final deck in _decks) {
      await deck._ready;
      final native = deck._player.platform;
      if (native is! mk.NativePlayer) continue;
      for (final e in props.entries) {
        await native.setProperty(e.key, e.value);
      }
    }
  }

  @override
  Stream<AudioInterruption> get interruptions => _interruptions.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _devicesSub?.cancel();
    for (final deck in List.of(_decks)) {
      await deck.dispose();
    }
    _decks.clear();
    await _probe?.dispose();
    await _devicesCtrl.close();
    await _interruptions.close();
  }
}

/// One libmpv player.
class MediaKitDeck implements AudioDeck {
  MediaKitDeck._(this._backend, this._player) {
    _ready = _backend.configurePlayer(_player).catchError((Object e, StackTrace st) {
      _log.warning('Could not configure mpv', e, st);
    });
    final s = _player.stream;
    _subs.addAll([
      s.position.listen((p) {
        if (p > Duration.zero) _startedPlaying = true;
      }),
      s.duration.listen((d) => _durationCtrl.add(d > Duration.zero ? d : null)),
      s.buffering.listen((b) => _refreshState()),
      s.completed.listen(_onCompleted),
      s.playlist.listen(_onPlaylist),
      s.error.listen(_onError),
    ]);
  }

  final MediaKitBackend _backend;
  final mk.Player _player;
  late final Future<void> _ready;
  final _subs = <StreamSubscription<Object?>>[];

  final _stateCtrl = StreamController<DeckState>.broadcast();
  final _durationCtrl = StreamController<Duration?>.broadcast();
  final _completionsCtrl = StreamController<void>.broadcast();
  final _advancedCtrl = StreamController<void>.broadcast();
  final _errorsCtrl = StreamController<DeckError>.broadcast();

  DeckState _state = DeckState.idle;
  bool _loaded = false;
  bool _startedPlaying = false;
  bool _hasPreloaded = false;
  String? _errorSinceOpen;
  bool _disposed = false;

  @visibleForTesting
  mk.Player get debugPlayer => _player;

  void _setState(DeckState s) {
    if (_state == s) return;
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  void _refreshState() {
    if (!_loaded || _state == DeckState.completed) return;
    final st = _player.state;
    if (st.buffering) {
      _setState(_startedPlaying || st.duration > Duration.zero ? DeckState.buffering : DeckState.loading);
    } else if (st.duration > Duration.zero) {
      _setState(DeckState.ready);
    }
  }

  /// mpv sets `eof-reached` briefly at the end of an item even when it then
  /// moves on to the next playlist entry, so completions are debounced
  /// around gapless transitions.
  static const _transitionWindow = Duration(milliseconds: 750);
  Timer? _pendingCompletion;
  final _sinceAdvance = Stopwatch();

  void _onCompleted(bool completed) {
    if (!completed || !_loaded) return;
    if (_hasPreloaded) {
      _pendingCompletion?.cancel();
      _pendingCompletion = Timer(_transitionWindow, () {
        if (!_hasPreloaded || !_loaded) return;
        // mpv stayed at the end (the preload came too late): plain completion.
        _hasPreloaded = false;
        _emitCompletion();
      });
      return;
    }
    if (_sinceAdvance.isRunning && _sinceAdvance.elapsed < _transitionWindow) return; // previous item's EOF
    _emitCompletion();
  }

  void _emitCompletion() {
    final st = _player.state;
    final remaining = st.duration - st.position;
    if (_errorSinceOpen != null && st.duration > Duration.zero && remaining > const Duration(seconds: 3)) {
      // The stream died early (network/decoder) — not a natural end.
      _errorsCtrl.add(DeckError('Stream ended early: $_errorSinceOpen'));
      return;
    }
    _setState(DeckState.completed);
    _completionsCtrl.add(null);
  }

  void _onPlaylist(mk.Playlist playlist) {
    if (!_hasPreloaded || playlist.index < 1) return;
    // mpv moved on to the preloaded item: gapless transition.
    _pendingCompletion?.cancel();
    _sinceAdvance
      ..reset()
      ..start();
    _hasPreloaded = false;
    _startedPlaying = false;
    _errorSinceOpen = null;
    _advancedCtrl.add(null);
    unawaited(_player.remove(0).catchError((Object e) => _log.fine('playlist-remove failed', e)));
  }

  void _onError(String message) {
    if (!_loaded) return;
    _errorSinceOpen = message;
    final st = _player.state;
    if (_hasPreloaded && st.duration > Duration.zero && st.duration - st.position < const Duration(seconds: 2)) {
      // The *preloaded* item failed while the current one is ending: let
      // the engine load the next item itself (it will report the failure).
      _hasPreloaded = false;
      _log.info('Preloaded item failed: $message');
      unawaited(clearPreloaded());
      return;
    }
    final fatal = !_startedPlaying;
    _errorsCtrl.add(DeckError(message, fatal: fatal));
  }

  static String resource(PlayableSource source) =>
      source.isLocalFile || source.uri.isScheme('file') ? source.uri.toFilePath() : source.uri.toString();

  mk.Media _media(PlayableSource source, {Duration? start}) => mk.Media(
        resource(source),
        httpHeaders: source.headers.isEmpty ? null : source.headers,
        start: start == null || start <= Duration.zero ? null : start,
      );

  @override
  Future<void> open(PlayableSource source, {Duration start = Duration.zero, bool autoplay = true, Track? track}) async {
    await _ready;
    _loaded = true;
    _startedPlaying = false;
    _hasPreloaded = false;
    _errorSinceOpen = null;
    _pendingCompletion?.cancel();
    _sinceAdvance
      ..stop()
      ..reset();
    _setState(DeckState.loading);
    await _player.open(_media(source, start: start), play: autoplay);
  }

  @override
  Future<void> play() async {
    await _ready;
    if (_state == DeckState.completed) _setState(DeckState.ready);
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _ready;
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _ready;
    _loaded = false;
    _hasPreloaded = false;
    _pendingCompletion?.cancel();
    await _player.stop();
    _setState(DeckState.idle);
  }

  @override
  Future<void> seek(Duration position) async {
    await _ready;
    if (_state == DeckState.completed) _setState(DeckState.ready);
    await _player.seek(position);
  }

  /// mpv's volume is cubic (gain = (v/100)³), so map linear gain back.
  static double mpvVolumeFor(double gain) => 100 * math.pow(gain.clamp(0.0, 1.0), 1 / 3).toDouble();

  @override
  Future<void> setVolume(double gain) async {
    await _ready;
    await _player.setVolume(mpvVolumeFor(gain));
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _ready;
    await _player.setRate(speed);
  }

  @override
  bool get supportsGapless => true;

  @override
  Future<void> preloadNext(PlayableSource source, {Track? track}) async {
    await _ready;
    if (!_loaded) return;
    if (_hasPreloaded) await clearPreloaded();
    await _player.add(_media(source));
    _hasPreloaded = true;
  }

  @override
  Future<void> clearPreloaded() async {
    await _ready;
    final medias = _player.state.playlist.medias;
    final index = _player.state.playlist.index;
    _hasPreloaded = false;
    if (medias.length > 1 && index < medias.length - 1) {
      await _player.remove(medias.length - 1);
    }
  }

  @override
  bool get hasPreloaded => _hasPreloaded;

  @override
  Duration get position => _player.state.position;

  @override
  Duration get bufferedPosition => _player.state.buffer;

  @override
  Duration? get duration {
    final d = _player.state.duration;
    return d > Duration.zero ? d : null;
  }

  @override
  bool get playing => _player.state.playing;

  @override
  DeckState get state => _state;

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get bufferedPositionStream => _player.stream.buffer;

  @override
  Stream<Duration?> get durationStream => _durationCtrl.stream;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<DeckState> get stateStream => _stateCtrl.stream;

  @override
  Stream<void> get completions => _completionsCtrl.stream;

  @override
  Stream<void> get advancedToPreloaded => _advancedCtrl.stream;

  @override
  Stream<DeckError> get errors => _errorsCtrl.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pendingCompletion?.cancel();
    _backend._decks.remove(this);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    await _player.dispose();
    for (final c in [_stateCtrl, _durationCtrl, _completionsCtrl, _advancedCtrl, _errorsCtrl]) {
      unawaited(c.close());
    }
  }
}
