import 'dart:async';

import 'package:fermata/core/contracts/playback.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';

/// One recorded controller call.
class PlaybackCall {
  const PlaybackCall(this.method, [this.args = const []]);

  final String method;
  final List<Object?> args;

  @override
  String toString() => '$method(${args.join(', ')})';
}

/// In-memory [PlaybackController] with controllable state and a call log.
///
/// * Every method is recorded in [calls] (`called('next')`, `argsOf('seek')`).
/// * State changes behave like a simple player (queue ops, shuffle, repeat,
///   volume, sleep timer) and are emitted on the streams.
/// * Push arbitrary state with [emit] / [setQueue] / [emitEvent].
/// * [throwOn] makes the next call of a method throw.
/// * [canJoin] simulates the SoundCloud queue silo: `enqueue`/`playNext`
///   throw `UnsupportedSourceOperation(…, 'mix_queue', …)` when it returns
///   false.
class FakePlaybackController implements PlaybackController {
  FakePlaybackController({
    this._snapshot = const PlaybackSnapshot(),
    this._queue = const QueueState.empty(),
    this.supportsSpeed = true,
    this.supportsOutputDeviceSelection = true,
    this.devices = const [
      AudioOutputDevice(id: 'default', name: 'Speakers', isDefault: true),
      AudioOutputDevice(id: 'usb', name: 'USB DAC'),
    ],
  });

  final calls = <PlaybackCall>[];
  final throwOn = <String, Object>{};
  bool Function(List<Track> tracks)? canJoin;
  List<AudioOutputDevice> devices;

  @override
  bool supportsSpeed;

  @override
  bool supportsOutputDeviceSelection;

  PlaybackSnapshot _snapshot;
  QueueState _queue;
  int _uid = 0;
  final _snapshots = StreamController<PlaybackSnapshot>.broadcast();
  final _queues = StreamController<QueueState>.broadcast();
  final _events = StreamController<PlaybackEvent>.broadcast();

  bool called(String method) => calls.any((c) => c.method == method);
  int countOf(String method) => calls.where((c) => c.method == method).length;
  List<Object?> argsOf(String method) => calls.lastWhere((c) => c.method == method).args;
  List<String> get methods => [for (final c in calls) c.method];

  /// Replaces the snapshot and notifies listeners.
  void emit(PlaybackSnapshot s) {
    _snapshot = s;
    _snapshots.add(s);
  }

  /// Replaces the queue and notifies listeners (also updates `current`).
  void setQueue(QueueState q) {
    _queue = q;
    _queues.add(q);
    _snapshot = q.current == null ? _snapshot.copyWith(clearCurrent: true) : _snapshot.copyWith(current: q.current);
    _snapshots.add(_snapshot);
  }

  void emitEvent(PlaybackEvent e) => _events.add(e);

  /// Loads [tracks] as the queue (not playing) — handy test setup.
  void load(List<Track> tracks, {int index = 0, bool playing = false, Duration position = Duration.zero, String? originLabel}) {
    final items = [for (final t in tracks) QueueItem(uid: 'u${_uid++}', track: t)];
    _queue = QueueState(items: items, currentIndex: tracks.isEmpty ? -1 : index, originLabel: originLabel);
    _snapshot = PlaybackSnapshot(
      current: _queue.current,
      playing: playing,
      status: PlayerStatus.ready,
      position: position,
      duration: _queue.current?.track.duration,
      volume: _snapshot.volume,
      speed: _snapshot.speed,
      shuffle: _snapshot.shuffle,
      repeat: _snapshot.repeat,
    );
    _queues.add(_queue);
    _snapshots.add(_snapshot);
  }

  void _record(String method, [List<Object?> args = const []]) {
    calls.add(PlaybackCall(method, args));
    final error = throwOn.remove(method);
    if (error != null) throw error;
  }

  void _updateQueue(List<QueueItem> items, int index) {
    _queue = QueueState(items: List.unmodifiable(items), currentIndex: index, originLabel: _queue.originLabel);
    _queues.add(_queue);
    final current = _queue.current;
    _snapshot = current == null
        ? _snapshot.copyWith(clearCurrent: true, playing: false)
        : _snapshot.copyWith(current: current, duration: current.track.duration);
    _snapshots.add(_snapshot);
  }

  void _set(PlaybackSnapshot s) => emit(s);

  @override
  Future<void> init() async => _record('init');

  @override
  PlaybackSnapshot get snapshot => _snapshot;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  QueueState get queue => _queue;

  @override
  Stream<QueueState> get queueStream => _queues.stream;

  @override
  Stream<PlaybackEvent> get events => _events.stream;

  @override
  Future<void> playTracks(
    List<Track> tracks, {
    int startIndex = 0,
    String? origin,
    String? originLabel,
    bool shuffle = false,
    Duration? startPosition,
  }) async {
    _record('playTracks', [tracks, startIndex, origin, originLabel, shuffle]);
    final items = [for (final t in tracks) QueueItem(uid: 'u${_uid++}', track: t, origin: origin)];
    _queue = QueueState(items: items, currentIndex: tracks.isEmpty ? -1 : startIndex, originLabel: originLabel);
    _queues.add(_queue);
    _set(_snapshot.copyWith(
      current: _queue.current,
      playing: true,
      status: PlayerStatus.ready,
      position: startPosition ?? Duration.zero,
      duration: _queue.current?.track.duration,
      shuffle: shuffle,
    ));
  }

  @override
  Future<void> play() async {
    _record('play');
    _set(_snapshot.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    _record('pause');
    _set(_snapshot.copyWith(playing: false));
  }

  @override
  Future<void> togglePlayPause() async {
    _record('togglePlayPause');
    _set(_snapshot.copyWith(playing: !_snapshot.playing));
  }

  @override
  Future<void> stop() async {
    _record('stop');
    _set(_snapshot.copyWith(playing: false, status: PlayerStatus.idle));
  }

  @override
  Future<void> next() async {
    _record('next');
    if (_queue.currentIndex < _queue.items.length - 1) _updateQueue(_queue.items, _queue.currentIndex + 1);
  }

  @override
  Future<void> previous() async {
    _record('previous');
    if (_queue.currentIndex > 0) _updateQueue(_queue.items, _queue.currentIndex - 1);
  }

  @override
  Future<void> seek(Duration position) async {
    _record('seek', [position]);
    _set(_snapshot.copyWith(position: position));
  }

  @override
  Future<void> seekRelative(Duration delta) async {
    _record('seekRelative', [delta]);
    final p = _snapshot.position + delta;
    _set(_snapshot.copyWith(position: p.isNegative ? Duration.zero : p));
  }

  @override
  Future<void> skipToIndex(int index) async {
    _record('skipToIndex', [index]);
    _updateQueue(_queue.items, index);
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    _record('setShuffle', [enabled]);
    _set(_snapshot.copyWith(shuffle: enabled));
  }

  @override
  Future<void> setRepeat(RepeatMode mode) async {
    _record('setRepeat', [mode]);
    _set(_snapshot.copyWith(repeat: mode));
  }

  @override
  Future<void> cycleRepeat() async {
    _record('cycleRepeat');
    final next = switch (_snapshot.repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    _set(_snapshot.copyWith(repeat: next));
  }

  @override
  Future<void> setVolume(double volume) async {
    _record('setVolume', [volume]);
    _set(_snapshot.copyWith(volume: volume));
  }

  @override
  Future<void> setSpeed(double speed) async {
    _record('setSpeed', [speed]);
    _set(_snapshot.copyWith(speed: speed));
  }

  void _checkSilo(List<Track> tracks) {
    if (canJoin != null && !canJoin!(tracks)) {
      throw UnsupportedSourceOperation(tracks.first.sourceId, 'mix_queue', 'Tracks cannot join this queue');
    }
  }

  @override
  Future<void> enqueue(List<Track> tracks, {String? origin}) async {
    _record('enqueue', [tracks, origin]);
    _checkSilo(tracks);
    final added = [for (final t in tracks) QueueItem(uid: 'u${_uid++}', track: t, origin: origin, addedManually: true)];
    _updateQueue([..._queue.items, ...added], _queue.currentIndex < 0 ? 0 : _queue.currentIndex);
  }

  @override
  Future<void> playNext(List<Track> tracks, {String? origin}) async {
    _record('playNext', [tracks, origin]);
    _checkSilo(tracks);
    final added = [for (final t in tracks) QueueItem(uid: 'u${_uid++}', track: t, origin: origin, addedManually: true)];
    final items = [..._queue.items];
    final at = _queue.currentIndex < 0 ? 0 : _queue.currentIndex + 1;
    items.insertAll(at, added);
    _updateQueue(items, _queue.currentIndex < 0 ? 0 : _queue.currentIndex);
  }

  @override
  Future<void> removeFromQueue(String uid) async {
    _record('removeFromQueue', [uid]);
    final items = [..._queue.items];
    final i = items.indexWhere((e) => e.uid == uid);
    if (i < 0) return;
    items.removeAt(i);
    var current = _queue.currentIndex;
    if (i < current) current--;
    if (current >= items.length) current = items.length - 1;
    _updateQueue(items, current);
  }

  @override
  Future<void> moveQueueItem(int from, int to) async {
    _record('moveQueueItem', [from, to]);
    final items = [..._queue.items];
    final currentUid = _queue.current?.uid;
    final item = items.removeAt(from);
    items.insert(to.clamp(0, items.length), item);
    _updateQueue(items, currentUid == null ? -1 : items.indexWhere((e) => e.uid == currentUid));
  }

  @override
  Future<void> clearQueue({bool keepCurrent = true}) async {
    _record('clearQueue', [keepCurrent]);
    final current = _queue.current;
    if (keepCurrent && current != null) {
      _updateQueue([current], 0);
    } else {
      _updateQueue(const [], -1);
    }
  }

  @override
  Future<void> setSleepTimer(Duration? duration, {bool endOfTrack = false}) async {
    _record('setSleepTimer', [duration, endOfTrack]);
    if (endOfTrack) {
      _set(_snapshot.copyWith(clearSleepTimer: true, sleepAtEndOfTrack: true));
    } else if (duration == null) {
      _set(_snapshot.copyWith(clearSleepTimer: true, sleepAtEndOfTrack: false));
    } else {
      _set(_snapshot.copyWith(sleepTimerEndsAt: DateTime.now().add(duration), sleepAtEndOfTrack: false));
    }
  }

  @override
  Future<List<AudioOutputDevice>> outputDevices() async {
    _record('outputDevices');
    return devices;
  }

  @override
  Future<void> setOutputDevice(String deviceId) async => _record('setOutputDevice', [deviceId]);

  @override
  Future<void> saveState() async => _record('saveState');

  @override
  Future<void> dispose() async {
    _record('dispose');
    await _snapshots.close();
    await _queues.close();
    await _events.close();
  }
}

/// Resolver fake: every track resolves to a placeholder file URI.
class FakeStreamResolver implements StreamResolver {
  final resolved = <String>[];

  @override
  Future<ResolvedStream> resolve(Track track, {CancelToken? cancel}) async {
    resolved.add(track.id);
    return ResolvedStream(source: PlayableSource(uri: Uri.parse('file:///fake/${track.sourceTrackId}')), playedTrack: track);
  }
}
