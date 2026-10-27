import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:fermata/core/contracts/playback.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/platform/desktop/hotkeys/accelerator.dart';
import 'package:fermata/platform/desktop/hotkeys/global_hotkey_service.dart';
import 'package:fermata/platform/desktop/tray/tray_availability.dart';
import 'package:fermata/platform/desktop/tray/tray_backend.dart';
import 'package:fermata/platform/desktop/tray/tray_menu.dart';
import 'package:fermata/platform/desktop/window/window_backend.dart';
import 'package:fermata/platform/windows/smtc_port.dart';

Track track(String id, {String? title, String artist = 'Artist', String? album, Duration? duration, Uri? art, String? path}) =>
    Track(
      sourceId: 'local',
      sourceTrackId: id,
      title: title ?? 'Song $id',
      artists: [ArtistRef(artist)],
      album: album,
      duration: duration ?? const Duration(minutes: 3),
      artworkUrl: art,
      localPath: path,
    );

/// Controllable in-memory [PlaybackController] that records calls and
/// behaves like a small real player (queue, position, flags).
class FakePlaybackController implements PlaybackController {
  PlaybackSnapshot _snapshot = const PlaybackSnapshot();
  QueueState _queue = const QueueState.empty();
  final _snapshots = StreamController<PlaybackSnapshot>.broadcast(sync: true);
  final _queues = StreamController<QueueState>.broadcast(sync: true);
  final _events = StreamController<PlaybackEvent>.broadcast(sync: true);
  final calls = <String>[];
  bool speedSupported = true;
  Completer<void>? disposeGate;
  int _uid = 0;

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

  /// Replaces the queue without recording a call.
  void load(List<Track> tracks, {int index = 0, bool playing = false, Duration position = Duration.zero}) {
    final items = [for (final t in tracks) QueueItem(uid: 'uid-${_uid++}', track: t)];
    _queue = QueueState(items: items, currentIndex: items.isEmpty ? -1 : index);
    _queues.add(_queue);
    final current = _queue.current;
    emit(PlaybackSnapshot(
      current: current,
      playing: playing,
      status: current == null ? PlayerStatus.idle : PlayerStatus.ready,
      position: position,
      duration: current?.track.duration,
      shuffle: _snapshot.shuffle,
      repeat: _snapshot.repeat,
      volume: _snapshot.volume,
      speed: _snapshot.speed,
    ));
    if (current != null) _events.add(TrackStarted(current, DateTime.now()));
  }

  void emit(PlaybackSnapshot s) {
    _snapshot = s;
    _snapshots.add(s);
  }

  void _goTo(int index) {
    _queue = QueueState(items: _queue.items, currentIndex: index);
    _queues.add(_queue);
    final current = _queue.current!;
    emit(_snapshot.copyWith(current: current, position: Duration.zero, duration: current.track.duration));
    _events.add(TrackStarted(current, DateTime.now()));
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> playTracks(List<Track> tracks,
      {int startIndex = 0, String? origin, String? originLabel, bool shuffle = false, Duration? startPosition}) async {
    calls.add('playTracks:${tracks.map((t) => t.localPath ?? t.id).join(',')}');
    load(tracks, index: startIndex, playing: true, position: startPosition ?? Duration.zero);
  }

  @override
  Future<void> play() async {
    calls.add('play');
    emit(_snapshot.copyWith(playing: true, status: PlayerStatus.ready));
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    emit(_snapshot.copyWith(playing: false));
  }

  @override
  Future<void> togglePlayPause() async {
    calls.add('togglePlayPause');
    emit(_snapshot.copyWith(playing: !_snapshot.playing, status: PlayerStatus.ready));
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    emit(_snapshot.copyWith(playing: false, status: PlayerStatus.idle, position: Duration.zero));
  }

  @override
  Future<void> next() async {
    calls.add('next');
    if (_queue.currentIndex < _queue.items.length - 1) _goTo(_queue.currentIndex + 1);
  }

  @override
  Future<void> previous() async {
    calls.add('previous');
    if (_snapshot.position > const Duration(seconds: 3) || _queue.currentIndex <= 0) {
      emit(_snapshot.copyWith(position: Duration.zero));
    } else {
      _goTo(_queue.currentIndex - 1);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
    emit(_snapshot.copyWith(position: position));
  }

  @override
  Future<void> seekRelative(Duration delta) => seek(_snapshot.position + delta);

  @override
  Future<void> skipToIndex(int index) async => _goTo(index);

  @override
  Future<void> setShuffle(bool enabled) async {
    calls.add('shuffle:$enabled');
    emit(_snapshot.copyWith(shuffle: enabled));
  }

  @override
  Future<void> setRepeat(RepeatMode mode) async {
    calls.add('repeat:${mode.name}');
    emit(_snapshot.copyWith(repeat: mode));
  }

  @override
  Future<void> cycleRepeat() async {}

  @override
  Future<void> setVolume(double volume) async {
    calls.add('volume:$volume');
    emit(_snapshot.copyWith(volume: volume));
  }

  @override
  Future<void> setSpeed(double speed) async {
    calls.add('speed:$speed');
    emit(_snapshot.copyWith(speed: speed));
  }

  @override
  Future<void> enqueue(List<Track> tracks, {String? origin}) async {}
  @override
  Future<void> playNext(List<Track> tracks, {String? origin}) async {}
  @override
  Future<void> removeFromQueue(String uid) async {}
  @override
  Future<void> moveQueueItem(int from, int to) async {}
  @override
  Future<void> clearQueue({bool keepCurrent = true}) async {}
  @override
  Future<void> setSleepTimer(Duration? duration, {bool endOfTrack = false}) async {}
  @override
  bool get supportsSpeed => speedSupported;
  @override
  bool get supportsOutputDeviceSelection => false;
  @override
  Future<List<AudioOutputDevice>> outputDevices() async => const [];
  @override
  Future<void> setOutputDevice(String deviceId) async {}
  @override
  Future<void> saveState() async {}

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    final gate = disposeGate;
    if (gate != null) await gate.future;
  }
}

/// Records window calls; state behaves like a simple window.
class FakeWindowBackend implements WindowBackend {
  final calls = <String>[];
  final _events = StreamController<WindowEventKind>.broadcast(sync: true);
  Rect bounds = const Rect.fromLTWH(100, 100, 1200, 780);
  bool visible = false;
  bool minimized = false;
  bool maximized = false;
  bool preventClose = false;
  Size? minimumSize;
  List<Rect> workAreas = const [Rect.fromLTWH(0, 0, 1920, 1080)];

  void fire(WindowEventKind e) => _events.add(e);

  @override
  Stream<WindowEventKind> get events => _events.stream;
  @override
  Future<void> ensureInitialized() async => calls.add('ensureInitialized');
  @override
  Future<void> setPreventClose(bool prevent) async {
    calls.add('setPreventClose:$prevent');
    preventClose = prevent;
  }

  @override
  Future<void> setTitle(String title) async => calls.add('setTitle:$title');
  @override
  Future<void> setMinimumSize(Size size) async {
    calls.add('setMinimumSize:${size.width.toInt()}x${size.height.toInt()}');
    minimumSize = size;
  }

  @override
  Future<void> setAlwaysOnTop(bool onTop) async => calls.add('setAlwaysOnTop:$onTop');
  @override
  Future<Rect> getBounds() async => bounds;
  @override
  Future<void> setBounds(Rect b) async {
    calls.add('setBounds:${b.left.toInt()},${b.top.toInt()},${b.width.toInt()}x${b.height.toInt()}');
    bounds = b;
  }

  @override
  Future<bool> isMaximized() async => maximized;
  @override
  Future<void> maximize() async {
    calls.add('maximize');
    maximized = true;
  }

  @override
  Future<bool> isMinimized() async => minimized;
  @override
  Future<void> minimize() async {
    calls.add('minimize');
    minimized = true;
  }

  @override
  Future<void> restore() async {
    calls.add('restore');
    minimized = false;
    maximized = false;
  }

  @override
  Future<bool> isVisible() async => visible;
  @override
  Future<void> show() async {
    calls.add('show');
    visible = true;
  }

  @override
  Future<void> hide() async {
    calls.add('hide');
    visible = false;
  }

  @override
  Future<void> focus() async => calls.add('focus');
  @override
  Future<void> destroy() async => calls.add('destroy');
  @override
  Future<List<Rect>> displayWorkAreas() async => workAreas;
  @override
  Future<void> dispose() async {}
}

class FakeTrayBackend implements TrayBackend {
  bool createResult = true;
  bool created = false;
  int createCount = 0;
  String? iconPath;
  String? tooltip;
  List<TrayMenuEntry> menu = const [];
  int menuUpdates = 0;
  void Function()? onActivate;
  void Function(String id)? onMenuItem;

  @override
  Future<bool> create({
    required String iconPath,
    required void Function() onActivate,
    required void Function(String id) onMenuItem,
  }) async {
    createCount++;
    if (!createResult) return false;
    created = true;
    this.iconPath = iconPath;
    this.onActivate = onActivate;
    this.onMenuItem = onMenuItem;
    return true;
  }

  @override
  Future<void> setTooltip(String tooltip) async => this.tooltip = tooltip;

  @override
  Future<void> setMenu(List<TrayMenuEntry> entries) async {
    menu = entries;
    menuUpdates++;
  }

  @override
  Future<void> destroy() async {
    created = false;
    menu = const [];
  }

  TrayMenuEntry entry(String id) => menu.firstWhere((e) => e.id == id);
}

class FakeTrayProbe implements TrayAvailabilityProbe {
  FakeTrayProbe([this.state = TrayHostState.available]);
  TrayHostState state;
  final _changes = StreamController<void>.broadcast(sync: true);
  void hostChanged() => _changes.add(null);

  @override
  Future<TrayHostState> check() async => state;
  @override
  Stream<void> get hostChanges => _changes.stream;
  @override
  Future<void> dispose() async {}
}

class FakeHotkeyBackend implements HotkeyBackend {
  final registered = <String, Accelerator>{};
  final handlers = <String, void Function()>{};
  final failFor = <String>{};
  int unregisterAllCount = 0;

  @override
  Future<void> register(String id, Accelerator accelerator, void Function() onPressed) async {
    if (failFor.contains(accelerator.canonical)) throw Exception('taken');
    registered[id] = accelerator;
    handlers[id] = onPressed;
  }

  @override
  Future<void> unregisterAll() async {
    unregisterAllCount++;
    registered.clear();
    handlers.clear();
  }
}

class FakeSmtcPort implements SmtcPort {
  final calls = <String>[];
  final timelines = <(int, int, int)>[];
  final buttonCtl = StreamController<SmtcButton>.broadcast(sync: true);
  final shuffleCtl = StreamController<bool>.broadcast(sync: true);
  final repeatCtl = StreamController<RepeatMode>.broadcast(sync: true);
  Map<String, String?> metadata = const {};
  SmtcStatus? status;
  bool disposed = false;

  @override
  Future<void> updateConfig({required bool play, required bool pause, required bool next, required bool previous, required bool stop}) async =>
      calls.add('config:play=$play,next=$next,prev=$previous');
  @override
  Future<void> updateMetadata({String? title, String? artist, String? album, String? albumArtist, String? thumbnail}) async {
    calls.add('metadata:$title');
    metadata = {'title': title, 'artist': artist, 'album': album, 'albumArtist': albumArtist, 'thumbnail': thumbnail};
  }

  @override
  Future<void> clearMetadata() async {
    calls.add('clearMetadata');
    metadata = const {};
  }

  @override
  Future<void> setStatus(SmtcStatus s) async {
    calls.add('status:${s.name}');
    status = s;
  }

  @override
  Future<void> updateTimeline({required int startMs, required int endMs, required int positionMs}) async =>
      timelines.add((startMs, endMs, positionMs));
  @override
  Future<void> setShuffle(bool enabled) async => calls.add('shuffle:$enabled');
  @override
  Future<void> setRepeat(RepeatMode mode) async => calls.add('repeat:${mode.name}');
  @override
  Future<void> setEnabled(bool enabled) async => calls.add('enabled:$enabled');
  @override
  Stream<SmtcButton> get buttons => buttonCtl.stream;
  @override
  Stream<bool> get shuffleRequests => shuffleCtl.stream;
  @override
  Stream<RepeatMode> get repeatRequests => repeatCtl.stream;
  @override
  Future<void> dispose() async => disposed = true;
}

/// Lets queued microtasks and zero-delay timers run.
Future<void> settle([int rounds = 5]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
