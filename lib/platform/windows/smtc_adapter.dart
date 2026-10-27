import 'dart:async';

import 'package:logging/logging.dart';

import '../../core/contracts/playback.dart';
import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import '../../core/platform/platform_info.dart';
import 'smtc_port.dart';

final _log = Logger('windows.smtc');

/// Windows System Media Transport Controls: the media overlay (volume
/// flyout / lock screen / Quick Settings) and hardware media keys, which
/// Windows delivers through SMTC.
///
/// Mirrors metadata, status, shuffle/repeat and the timeline (throttled to
/// ~1 Hz, immediately on track change, status change or seek) and routes
/// button presses and shuffle/repeat requests to the [PlaybackController].
/// Inert on every platform but Windows.
class SmtcAdapter {
  SmtcAdapter({
    required this._playback,
    required this._platform,
    Future<SmtcPort> Function()? portFactory,
    this.timelineInterval = const Duration(seconds: 1),
    DateTime Function()? clock,
  })  : _portFactory = portFactory ?? SmtcWindowsPort.create,
        _clock = clock ?? DateTime.now;

  final PlaybackController _playback;
  final PlatformInfo _platform;
  final Future<SmtcPort> Function() _portFactory;
  final DateTime Function() _clock;
  final Duration timelineInterval;

  SmtcPort? _port;
  final _subs = <StreamSubscription<Object?>>[];
  Future<void> _chain = Future.value();

  _MetaKey? _meta;
  SmtcStatus? _status;
  bool? _shuffle;
  RepeatMode? _repeat;
  _ConfigKey? _config;
  DateTime? _lastTimelineAt;
  int? _lastTimelinePos;
  int? _lastTimelineEnd;

  bool get isActive => _port != null;

  /// Initializes SMTC on Windows; does nothing elsewhere. Failures are
  /// logged (media keys then simply do not work) and never thrown.
  Future<void> start() async {
    if (!_platform.isWindows || _port != null) return;
    final SmtcPort port;
    try {
      port = await _portFactory();
    } catch (e, st) {
      _log.warning('SMTC unavailable', e, st);
      return;
    }
    _port = port;
    _subs.add(port.buttons.listen(_onButton, onError: (Object e) => _log.fine('SMTC button error: $e')));
    _subs.add(port.shuffleRequests.listen((v) => _run('shuffle', () => _playback.setShuffle(v))));
    _subs.add(port.repeatRequests.listen((m) => _run('repeat', () => _playback.setRepeat(m))));
    _subs.add(_playback.snapshots.listen(_sync));
    _subs.add(_playback.queueStream.listen((_) => _sync(_playback.snapshot)));
    _sync(_playback.snapshot);
    await _chain;
  }

  void _onButton(SmtcButton b) {
    switch (b) {
      case SmtcButton.play:
        _run('play', _playback.play);
      case SmtcButton.pause:
        _run('pause', _playback.pause);
      case SmtcButton.next:
        _run('next', _playback.next);
      case SmtcButton.previous:
        _run('previous', _playback.previous);
      case SmtcButton.stop:
        _run('stop', _playback.stop);
      case SmtcButton.other:
        break;
    }
  }

  void _run(String what, Future<void> Function() action) {
    unawaited(Future.sync(action).catchError((Object e, StackTrace st) {
      _log.warning('SMTC action $what failed', e, st);
    }));
  }

  /// Valid thumbnail URI or null. smtc_windows `unwrap()`s the parsed URI
  /// in Rust, so anything that is not an absolute http(s)/file URI must
  /// never reach it.
  static String? thumbnailFor(Track track) {
    final art = track.artworkUrl;
    if (art == null || !art.isAbsolute) return null;
    if (art.scheme == 'https' || art.scheme == 'http') return art.host.isEmpty ? null : art.toString();
    if (art.scheme == 'file') {
      try {
        return Uri.file(art.toFilePath(windows: true), windows: true).toString();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static SmtcStatus statusFor(PlaybackSnapshot s) {
    if (s.current == null) return SmtcStatus.stopped;
    if (s.playing) return SmtcStatus.playing;
    return switch (s.status) {
      PlayerStatus.loading || PlayerStatus.buffering => SmtcStatus.changing,
      PlayerStatus.idle || PlayerStatus.completed => SmtcStatus.stopped,
      _ => SmtcStatus.paused,
    };
  }

  void _sync(PlaybackSnapshot s) {
    final port = _port;
    if (port == null) return;
    _chain = _chain.then((_) => _apply(port, s)).catchError((Object e, StackTrace st) {
      _log.warning('SMTC update failed', e, st);
    });
  }

  Future<void> _apply(SmtcPort port, PlaybackSnapshot s) async {
    final track = s.track;
    final q = _playback.queue;
    final config = _ConfigKey(
      hasTrack: track != null,
      canNext: track != null && (q.currentIndex < q.items.length - 1 || s.repeat == RepeatMode.all),
    );
    if (config != _config) {
      _config = config;
      await port.updateConfig(
        play: config.hasTrack,
        pause: config.hasTrack,
        next: config.canNext,
        previous: config.hasTrack,
        stop: config.hasTrack,
      );
    }

    var forceTimeline = false;
    final meta = track == null ? null : _MetaKey(s.current!.uid, track, thumbnailFor(track));
    if (meta != _meta) {
      _meta = meta;
      forceTimeline = true;
      if (meta == null) {
        await port.clearMetadata();
      } else {
        await port.updateMetadata(
          title: track!.title,
          artist: track.artistLine,
          album: track.album,
          albumArtist: track.albumArtist,
          thumbnail: meta.thumbnail,
        );
      }
    }

    final status = statusFor(s);
    if (status != _status) {
      _status = status;
      forceTimeline = true;
      await port.setStatus(status);
    }
    if (s.shuffle != _shuffle) {
      _shuffle = s.shuffle;
      await port.setShuffle(s.shuffle);
    }
    if (s.repeat != _repeat) {
      _repeat = s.repeat;
      await port.setRepeat(s.repeat);
    }

    if (track == null) return;
    final end = (s.duration ?? track.duration ?? Duration.zero).inMilliseconds;
    final pos = s.position.inMilliseconds.clamp(0, end > 0 ? end : s.position.inMilliseconds);
    final now = _clock();
    final last = _lastTimelineAt;
    final lastPos = _lastTimelinePos;
    // A seek shows up as a position that moved differently than time did.
    final seeked = last != null &&
        lastPos != null &&
        ((pos - lastPos) - (s.playing ? now.difference(last).inMilliseconds * s.speed : 0)).abs() > 1500;
    final due = last == null || now.difference(last) >= timelineInterval;
    if (forceTimeline || seeked || due || end != _lastTimelineEnd) {
      _lastTimelineAt = now;
      _lastTimelinePos = pos;
      _lastTimelineEnd = end;
      await port.updateTimeline(startMs: 0, endMs: end, positionMs: pos);
    }
  }

  /// Disables the controls and releases the native object (part of quit).
  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final port = _port;
    _port = null;
    if (port == null) return;
    await _chain;
    try {
      await port.setEnabled(false);
    } catch (_) {}
    try {
      await port.dispose();
    } catch (e) {
      _log.fine('SMTC dispose failed: $e');
    }
  }
}

class _MetaKey {
  _MetaKey(this.uid, Track track, this.thumbnail)
      : title = track.title,
        artist = track.artistLine,
        album = track.album,
        albumArtist = track.albumArtist;

  final String uid;
  final String title;
  final String artist;
  final String? album;
  final String? albumArtist;
  final String? thumbnail;

  @override
  bool operator ==(Object other) =>
      other is _MetaKey &&
      other.uid == uid &&
      other.title == title &&
      other.artist == artist &&
      other.album == album &&
      other.albumArtist == albumArtist &&
      other.thumbnail == thumbnail;

  @override
  int get hashCode => Object.hash(uid, title, artist, album, albumArtist, thumbnail);
}

class _ConfigKey {
  const _ConfigKey({required this.hasTrack, required this.canNext});
  final bool hasTrack;
  final bool canNext;

  @override
  bool operator ==(Object other) => other is _ConfigKey && other.hasTrack == hasTrack && other.canNext == canNext;

  @override
  int get hashCode => Object.hash(hasTrack, canNext);
}
