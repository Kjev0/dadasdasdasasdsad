import 'dart:async';

import 'package:logging/logging.dart';

import '../core/contracts/library.dart';
import '../core/contracts/playback.dart';
import '../core/models/library.dart';
import '../core/models/playback.dart';
import '../settings/settings_store.dart';

final _log = Logger('library.history_recorder');

/// Writes listening history from playback events.
///
/// On every `TrackEnded` a [PlayRecord] is stored when
/// `privacy.recordHistory` is on and the track was completed, or listened
/// to for at least [minListened] (30 s), or for at least [minFraction]
/// (50 %) of its duration. The played track is upserted first so history,
/// stats and "recently played" work offline. Events are processed in order;
/// failures are logged and never reach playback.
class PlaybackHistoryRecorder {
  PlaybackHistoryRecorder(
    this._playback,
    this._history,
    this._tracks,
    this._settings, {
    this.minListened = const Duration(seconds: 30),
    this.minFraction = 0.5,
  });

  final PlaybackController _playback;
  final HistoryRepository _history;
  final TrackRepository _tracks;
  final SettingsStore _settings;
  final Duration minListened;
  final double minFraction;

  StreamSubscription<PlaybackEvent>? _sub;
  Future<void> _chain = Future.value();

  bool get isRunning => _sub != null;

  void start() {
    if (_sub != null) return;
    _sub = _playback.events.listen((event) {
      if (event is TrackEnded) _chain = _chain.then((_) => _handle(event));
    });
  }

  /// Whether [event] counts as a play under the current rules.
  bool qualifies(TrackEnded event) {
    if (event.completed) return true;
    if (event.listened >= minListened) return true;
    final duration = event.item.track.duration;
    if (duration != null && duration > Duration.zero) {
      return event.listened.inMilliseconds >= duration.inMilliseconds * minFraction;
    }
    return false;
  }

  Future<void> _handle(TrackEnded event) async {
    try {
      if (!_settings.current.privacy.recordHistory) return;
      if (!qualifies(event)) return;
      final track = event.item.track;
      await _tracks.upsertTracks([track]);
      await _history.recordPlay(PlayRecord(
        track: track,
        playedAt: event.startedAt,
        listened: event.listened,
        completed: event.completed,
        origin: event.item.origin,
      ));
    } catch (e, st) {
      _log.warning('Could not record play', e, st);
    }
  }

  /// Waits for queued writes (tests, shutdown).
  Future<void> flush() => _chain;

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _chain;
  }
}
