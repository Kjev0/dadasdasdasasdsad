import 'dart:async';
import 'dart:io' show pid;

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../core/contracts/playback.dart';
import '../../core/models/playback.dart';
import 'mpris_introspection.dart';
import 'mpris_model.dart';

final _log = Logger('linux.mpris');

/// MPRIS 2 server (`org.mpris.MediaPlayer2` + `.Player`) for Linux: desktop
/// media widgets, lock screens, KDE Connect, GSConnect and `playerctl`
/// control Fermata through it, and media keys reach it via the desktop.
///
/// Bus name `org.mpris.MediaPlayer2.fermata` (or `...fermata.instance<pid>`
/// when taken), object `/org/mpris/MediaPlayer2`. Emits `PropertiesChanged`
/// for every changed property except `Position`, which is read on demand,
/// and `Seeked` after seeks and position jumps.
class MprisServer {
  MprisServer({
    required this._playback,
    required this._client,
    this.onRaise,
    this.onQuit,
    this.onOpenFile,
    int? processId,
    this.jumpThreshold = const Duration(milliseconds: 1500),
    DateTime Function()? clock,
  })  : _pid = processId ?? pid,
        _clock = clock ?? DateTime.now;

  static const baseBusName = 'org.mpris.MediaPlayer2.fermata';
  static const objectPath = '/org/mpris/MediaPlayer2';
  static const rootInterface = 'org.mpris.MediaPlayer2';
  static const playerInterface = 'org.mpris.MediaPlayer2.Player';

  final PlaybackController _playback;
  final DBusClient _client;
  final int _pid;
  final DateTime Function() _clock;

  /// `Raise`: show the main window. Null → `CanRaise` false.
  final Future<void> Function()? onRaise;

  /// `Quit`: quit Fermata. Null → `CanQuit` false.
  final Future<void> Function()? onQuit;

  /// `OpenUri` with a `file://` URI: play that local file.
  final Future<void> Function(String path)? onOpenFile;

  /// Position differences larger than this (vs. the extrapolated position)
  /// are reported as `Seeked`.
  final Duration jumpThreshold;

  _MprisObject? _object;
  String? _busName;
  final _subs = <StreamSubscription<Object?>>[];
  Map<String, DBusValue> _lastPlayerProps = const {};
  String? _sampleUid;
  Duration _samplePosition = Duration.zero;
  DateTime _sampleTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _samplePlaying = false;
  double _sampleSpeed = 1.0;
  int _ownSeeks = 0;

  /// The bus name actually owned, null before [start] / after [stop].
  String? get busName => _busName;

  bool get isRunning => _busName != null;

  /// Exports the object and claims the bus name. Throws when the session bus
  /// is unreachable (callers log and continue without MPRIS).
  Future<void> start() async {
    if (_object != null) return;
    final object = _MprisObject(this);
    await _client.registerObject(object);
    _object = object;
    try {
      _busName = await _claimName();
    } catch (_) {
      await _client.unregisterObject(object);
      _object = null;
      rethrow;
    }
    _lastPlayerProps = _playerProperties(includePosition: false);
    _takeSample(_playback.snapshot);
    _subs.add(_playback.snapshots.listen(_onSnapshot));
    _subs.add(_playback.queueStream.listen((_) => _emitChanges()));
    _log.info('MPRIS server running as $_busName');
  }

  Future<String> _claimName() async {
    const flags = {DBusRequestNameFlag.doNotQueue};
    final reply = await _client.requestName(baseBusName, flags: flags);
    if (reply == DBusRequestNameReply.primaryOwner || reply == DBusRequestNameReply.alreadyOwner) {
      return baseBusName;
    }
    final alt = '$baseBusName.instance$_pid';
    final altReply = await _client.requestName(alt, flags: flags);
    if (altReply == DBusRequestNameReply.primaryOwner || altReply == DBusRequestNameReply.alreadyOwner) {
      return alt;
    }
    throw StateError('Could not own $baseBusName or $alt ($altReply)');
  }

  /// Releases the bus name and unexports the object. Does not close the
  /// shared [DBusClient].
  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final name = _busName;
    _busName = null;
    if (name != null) {
      try {
        await _client.releaseName(name);
      } catch (e) {
        _log.fine('releaseName failed: $e');
      }
    }
    final object = _object;
    _object = null;
    if (object != null) {
      try {
        await _client.unregisterObject(object);
      } catch (e) {
        _log.fine('unregisterObject failed: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // State → properties

  Map<String, DBusValue> _rootProperties() => {
        'CanQuit': DBusBoolean(onQuit != null),
        'CanRaise': DBusBoolean(onRaise != null),
        'CanSetFullscreen': const DBusBoolean(false),
        'Fullscreen': const DBusBoolean(false),
        'HasTrackList': const DBusBoolean(false),
        'Identity': const DBusString(MprisModel.identity),
        'DesktopEntry': const DBusString(MprisModel.desktopEntry),
        'SupportedUriSchemes': DBusArray.string(MprisModel.supportedUriSchemes),
        'SupportedMimeTypes': DBusArray.string(MprisModel.supportedMimeTypes),
      };

  double get _minRate => _playback.supportsSpeed ? 0.5 : 1.0;
  double get _maxRate => _playback.supportsSpeed ? 2.0 : 1.0;

  Map<String, DBusValue> _playerProperties({required bool includePosition}) {
    final s = _playback.snapshot;
    final q = _playback.queue;
    return {
      'PlaybackStatus': DBusString(MprisModel.playbackStatus(s)),
      'LoopStatus': DBusString(MprisModel.loopStatus(s.repeat)),
      'Rate': DBusDouble(s.speed),
      'Shuffle': DBusBoolean(s.shuffle),
      'Metadata': DBusDict.stringVariant(MprisModel.metadata(s)),
      'Volume': DBusDouble(s.volume),
      if (includePosition) 'Position': DBusInt64(currentPosition.inMicroseconds),
      'MinimumRate': DBusDouble(_minRate),
      'MaximumRate': DBusDouble(_maxRate),
      'CanGoNext': DBusBoolean(MprisModel.canGoNext(s, q)),
      'CanGoPrevious': DBusBoolean(MprisModel.canGoPrevious(s)),
      'CanPlay': DBusBoolean(MprisModel.canPlay(s)),
      'CanPause': DBusBoolean(MprisModel.canPause(s)),
      'CanSeek': DBusBoolean(MprisModel.canSeek(s)),
      'CanControl': const DBusBoolean(true),
    };
  }

  /// Position extrapolated from the last snapshot (snapshots arrive ~4 Hz).
  Duration get currentPosition {
    final s = _playback.snapshot;
    var pos = s.position;
    if (s.current?.uid == _sampleUid && _samplePlaying) {
      final elapsed = _clock().difference(_sampleTime);
      if (elapsed > Duration.zero && elapsed < const Duration(seconds: 5)) {
        pos = _samplePosition + elapsed * _sampleSpeed;
      }
    }
    final length = MprisModel.lengthOf(s);
    if (length != null && pos > length) pos = length;
    return pos < Duration.zero ? Duration.zero : pos;
  }

  void _onSnapshot(PlaybackSnapshot s) {
    _detectJump(s);
    _takeSample(s);
    _emitChanges();
  }

  void _detectJump(PlaybackSnapshot s) {
    if (_ownSeeks > 0) return; // reported by _seekTo
    final uid = s.current?.uid;
    if (uid == null || uid != _sampleUid) return; // new track: Metadata changes instead
    var expected = _samplePosition;
    if (_samplePlaying) {
      final elapsed = _clock().difference(_sampleTime);
      if (elapsed > Duration.zero) expected += elapsed * _sampleSpeed;
    }
    if ((s.position - expected).abs() > jumpThreshold) _emitSeeked(s.position);
  }

  void _takeSample(PlaybackSnapshot s) {
    _sampleUid = s.current?.uid;
    _samplePosition = s.position;
    _sampleTime = _clock();
    _samplePlaying = s.playing;
    _sampleSpeed = s.speed;
  }

  void _emitChanges() {
    final object = _object;
    if (object == null) return;
    final next = _playerProperties(includePosition: false);
    final changed = <String, DBusValue>{
      for (final e in next.entries)
        if (_lastPlayerProps[e.key] != e.value) e.key: e.value,
    };
    _lastPlayerProps = next;
    if (changed.isEmpty) return;
    unawaited(object.emitPropertiesChanged(playerInterface, changedProperties: changed).catchError((Object e) {
      _log.fine('PropertiesChanged failed: $e');
    }));
  }

  void _emitSeeked(Duration position) {
    final object = _object;
    if (object == null) return;
    unawaited(object.emitSignal(playerInterface, 'Seeked', [DBusInt64(position.inMicroseconds)]).catchError(
      (Object e) => _log.fine('Seeked failed: $e'),
    ));
  }

  /// Seeks and reports it once; snapshots arriving while the seek is in
  /// flight are not treated as jumps.
  Future<void> _seekTo(Duration target) async {
    _ownSeeks++;
    try {
      await _playback.seek(target);
    } finally {
      _ownSeeks--;
    }
    _sampleUid = _playback.snapshot.current?.uid;
    _samplePosition = target;
    _sampleTime = _clock();
    _samplePlaying = _playback.snapshot.playing;
    _emitSeeked(target);
  }

  // ---------------------------------------------------------------------------
  // D-Bus handlers

  Future<DBusMethodResponse> _getProperty(String interface, String name) async {
    final props = switch (interface) {
      rootInterface => _rootProperties(),
      playerInterface => _playerProperties(includePosition: name == 'Position'),
      _ => null,
    };
    if (props == null) return DBusMethodErrorResponse.unknownInterface();
    final value = props[name];
    if (value == null) return DBusMethodErrorResponse.unknownProperty();
    return DBusGetPropertyResponse(value);
  }

  Future<DBusMethodResponse> _getAllProperties(String interface) async => switch (interface) {
        rootInterface => DBusGetAllPropertiesResponse(_rootProperties()),
        playerInterface => DBusGetAllPropertiesResponse(_playerProperties(includePosition: true)),
        _ => DBusMethodErrorResponse.unknownInterface(),
      };

  Future<DBusMethodResponse> _setProperty(String interface, String name, DBusValue value) async {
    if (interface == rootInterface) {
      return _rootProperties().containsKey(name)
          ? DBusMethodErrorResponse.propertyReadOnly()
          : DBusMethodErrorResponse.unknownProperty();
    }
    if (interface != playerInterface) return DBusMethodErrorResponse.unknownInterface();
    try {
      switch (name) {
        case 'LoopStatus':
          if (value is! DBusString) return DBusMethodErrorResponse.invalidArgs('LoopStatus is a string');
          final mode = MprisModel.repeatModeFor(value.value);
          if (mode == null) return DBusMethodErrorResponse.invalidArgs('Unknown LoopStatus ${value.value}');
          await _playback.setRepeat(mode);
        case 'Shuffle':
          if (value is! DBusBoolean) return DBusMethodErrorResponse.invalidArgs('Shuffle is a boolean');
          await _playback.setShuffle(value.value);
        case 'Rate':
          if (value is! DBusDouble) return DBusMethodErrorResponse.invalidArgs('Rate is a double');
          final rate = value.value;
          if (rate.isNaN) return DBusMethodErrorResponse.invalidArgs('Rate is NaN');
          if (rate <= 0) {
            await _playback.pause(); // MPRIS: a rate of 0 acts as Pause
          } else if (_playback.supportsSpeed) {
            await _playback.setSpeed(rate.clamp(_minRate, _maxRate).toDouble());
          }
        case 'Volume':
          if (value is! DBusDouble) return DBusMethodErrorResponse.invalidArgs('Volume is a double');
          final v = value.value;
          if (v.isNaN) return DBusMethodErrorResponse.invalidArgs('Volume is NaN');
          await _playback.setVolume(v.clamp(0.0, 1.0).toDouble());
        default:
          return _playerProperties(includePosition: true).containsKey(name)
              ? DBusMethodErrorResponse.propertyReadOnly()
              : DBusMethodErrorResponse.unknownProperty();
      }
    } catch (e, st) {
      _log.warning('Setting $name failed', e, st);
      return DBusMethodErrorResponse.failed('$e');
    }
    _emitChanges();
    return DBusMethodSuccessResponse();
  }

  Future<DBusMethodResponse> _call(DBusMethodCall call) async {
    final iface = call.interface ?? (MprisIntrospection.playerMethods.contains(call.name) ? playerInterface : rootInterface);
    try {
      if (iface == rootInterface) return await _callRoot(call);
      if (iface == playerInterface) return await _callPlayer(call);
      return DBusMethodErrorResponse.unknownInterface();
    } catch (e, st) {
      _log.warning('MPRIS ${call.name} failed', e, st);
      return DBusMethodErrorResponse.failed('$e');
    }
  }

  Future<DBusMethodResponse> _callRoot(DBusMethodCall call) async {
    if (call.values.isNotEmpty) return DBusMethodErrorResponse.invalidArgs();
    switch (call.name) {
      case 'Raise':
        unawaited(onRaise?.call());
      case 'Quit':
        // Reply first: quitting tears down this connection.
        final quit = onQuit;
        if (quit != null) Timer.run(() => unawaited(quit()));
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodSuccessResponse();
  }

  Future<DBusMethodResponse> _callPlayer(DBusMethodCall call) async {
    final s = _playback.snapshot;
    switch (call.name) {
      case 'Next' || 'Previous' || 'Pause' || 'PlayPause' || 'Stop' || 'Play':
        if (call.values.isNotEmpty) return DBusMethodErrorResponse.invalidArgs();
    }
    switch (call.name) {
      case 'Next':
        if (MprisModel.canGoNext(s, _playback.queue)) await _playback.next();
      case 'Previous':
        if (MprisModel.canGoPrevious(s)) await _playback.previous();
      case 'Pause':
        if (s.playing) await _playback.pause();
      case 'PlayPause':
        if (MprisModel.canPlay(s)) await _playback.togglePlayPause();
      case 'Stop':
        await _playback.stop();
      case 'Play':
        if (MprisModel.canPlay(s) && !s.playing) await _playback.play();
      case 'Seek':
        if (call.signature != DBusSignature('x')) return DBusMethodErrorResponse.invalidArgs();
        await _seekBy(Duration(microseconds: call.values[0].asInt64()));
      case 'SetPosition':
        if (call.signature != DBusSignature('ox')) return DBusMethodErrorResponse.invalidArgs();
        await _setPosition(call.values[0].asObjectPath().value, Duration(microseconds: call.values[1].asInt64()));
      case 'OpenUri':
        if (call.signature != DBusSignature('s')) return DBusMethodErrorResponse.invalidArgs();
        return _openUri(call.values[0].asString());
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
    _emitChanges();
    return DBusMethodSuccessResponse();
  }

  Future<void> _seekBy(Duration offset) async {
    final s = _playback.snapshot;
    if (!MprisModel.canSeek(s)) return;
    var target = currentPosition + offset;
    if (target < Duration.zero) target = Duration.zero;
    final length = MprisModel.lengthOf(s)!;
    if (target >= length) {
      // MPRIS: seeking past the end acts like Next.
      if (MprisModel.canGoNext(s, _playback.queue)) await _playback.next();
      return;
    }
    await _seekTo(target);
  }

  Future<void> _setPosition(String trackId, Duration position) async {
    final s = _playback.snapshot;
    if (!MprisModel.canSeek(s)) return;
    if (trackId != MprisModel.trackIdFor(s.current?.uid)) return; // stale request
    final length = MprisModel.lengthOf(s)!;
    if (position < Duration.zero || position > length) return;
    await _seekTo(position);
  }

  Future<DBusMethodResponse> _openUri(String uri) async {
    final parsed = Uri.tryParse(uri);
    final open = onOpenFile;
    if (parsed == null || parsed.scheme != 'file' || open == null) {
      return DBusMethodErrorResponse.notSupported('Only file:// URIs are supported');
    }
    final String path;
    try {
      path = parsed.toFilePath();
    } catch (_) {
      return DBusMethodErrorResponse.invalidArgs('Invalid file URI');
    }
    await open(path);
    return DBusMethodSuccessResponse();
  }
}

class _MprisObject extends DBusObject {
  _MprisObject(this._server) : super(DBusObjectPath(MprisServer.objectPath));

  final MprisServer _server;

  @override
  List<DBusIntrospectInterface> introspect() => MprisIntrospection.interfaces;

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) => _server._call(methodCall);

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) => _server._getProperty(interface, name);

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) => _server._getAllProperties(interface);

  @override
  Future<DBusMethodResponse> setProperty(String interface, String name, DBusValue value) =>
      _server._setProperty(interface, name, value);
}
