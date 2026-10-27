part of '../playback_controller_impl.dart';

/// Snapshot building, emission and small helpers.
extension _State on PlaybackControllerImpl {
  /// Current position. After a seek (or an open at an offset) real backends
  /// report the new position only after a moment; until the deck catches up
  /// (or 3 s passed) the requested target is reported instead, so the UI and
  /// persistence never see the stale value.
  Duration get _positionNow {
    final loaded = _loaded;
    if (loaded == null) return _pendingPosition;
    final deckPosition = _decks[loaded.deck]?.position ?? _pendingPosition;
    final target = _seekTarget;
    if (target == null) return deckPosition;
    final caughtUp = (deckPosition - target).abs() <= const Duration(seconds: 1);
    if (caughtUp || _now().difference(_seekTargetAt!) > const Duration(seconds: 3)) {
      _seekTarget = null;
      return deckPosition;
    }
    return target;
  }

  void _expectPosition(Duration? target) {
    _seekTarget = target == null || target <= Duration.zero ? null : target;
    _seekTargetAt = _now();
  }

  Duration? get _durationNow {
    final loaded = _loaded;
    final deckDuration = loaded == null ? null : _decks[loaded.deck]?.duration;
    if (deckDuration != null && deckDuration > Duration.zero) return deckDuration;
    return loaded?.resolved.playedTrack.duration ?? _queue.current?.track.duration;
  }

  PlaybackSnapshot _buildSnapshot() {
    final loaded = _loaded;
    final deck = loaded == null ? null : _decks[loaded.deck];
    return PlaybackSnapshot(
      current: _queue.current,
      playing: _playIntent,
      status: _status,
      position: _positionNow,
      bufferedPosition: deck?.bufferedPosition ?? Duration.zero,
      duration: _durationNow,
      volume: _volume,
      speed: _speed,
      shuffle: _queue.shuffle,
      repeat: _queue.repeat,
      errorMessage: _error,
      sleepTimerEndsAt: _sleepEndsAt,
      sleepAtEndOfTrack: _sleepAtEndOfTrack,
      isPreview: loaded?.source.isPreview ?? false,
    );
  }

  /// When nothing is current (empty queue, or the queue had ended), newly
  /// added items become current (parked; `play()` starts them).
  void _selectAddedIfIdle(int firstNewIndex) {
    final ended = _status == PlayerStatus.completed && _loaded == null;
    if (_queue.current != null && !ended) return;
    if (_queue.skipToIndex(firstNewIndex)) _park(Duration.zero);
  }

  void _queueChanged() {
    _emitQueue();
    _revalidatePrefetch();
    _schedulePersist();
  }

  void _emitQueue() {
    if (_disposed) return;
    _queueCtrl.add(_queue.state);
    _markDirty();
  }

  void _emitEvent(PlaybackEvent event) {
    if (!_disposed) _eventCtrl.add(event);
  }

  /// Coalesces state-change emissions within one event-loop turn.
  void _markDirty() {
    if (_disposed || _emitScheduled) return;
    _emitScheduled = true;
    scheduleMicrotask(() {
      if (_emitScheduled) _emitNow();
    });
  }

  void _emitNow() {
    _emitScheduled = false;
    if (!_disposed) _snapshotCtrl.add(_buildSnapshot());
  }

  bool _isExpired(PlayableSource source) {
    final expiresAt = source.expiresAt;
    if (expiresAt == null || source.isLocalFile) return false;
    // Re-resolve slightly early so a resume never starts on a dying URL.
    return !_now().isBefore(expiresAt.subtract(const Duration(seconds: 10)));
  }
}

/// Localizable code shown in [PlaybackSnapshot.errorMessage].
String _errorCode(Object error) => switch (error) {
      UnplayableTrackException(:final reason) => reason,
      FermataException(:final code) => code,
      _ => 'playback_error',
    };

/// The item opened on a deck.
class _Loaded {
  _Loaded({required this.item, required this.resolved, required this.deck, required this.clock});

  final QueueItem item;
  final ResolvedStream resolved;
  final int deck;
  final ListenClock clock;
  bool started = false;
  DateTime? startedAt;
  bool ended = false;
  bool retriedAfterError = false;

  PlayableSource get source => resolved.source;
}

/// Ahead-of-time resolution of the next item (and optional gapless preload).
class _Prefetch {
  _Prefetch(this.item) : cancel = CancelToken();

  final QueueItem item;
  final CancelToken cancel;
  ResolvedStream? resolved;
  Object? error;

  /// Deck holding a gapless preload of [resolved], if any.
  int? onDeck;
}

class _Crossfade {
  _Crossfade({required this.from, required this.to, required this.startedAt, required this.length});

  final int from;
  final int to;
  final DateTime startedAt;
  final Duration length;
  Timer? timer;
}
