part of '../playback_controller_impl.dart';

/// Resolving the next item ahead of time, gapless preloading and starting
/// natural crossfades.
extension _Prefetching on PlaybackControllerImpl {
  Duration get _crossfadeDuration =>
      Duration(milliseconds: (_settings.current.playback.crossfadeSeconds * 1000).round());

  bool _gaplessAllowed(AudioDeck deck) {
    final s = _settings.current;
    return s.playback.gapless &&
        s.performance.preloadNext &&
        _crossfadeDuration == Duration.zero &&
        !_sleepAtEndOfTrack &&
        deck.supportsGapless;
  }

  /// Natural (end-of-track) crossfade: needs crossfade > 0, not repeat-one,
  /// no preview involved, no "sleep at end of track".
  bool _naturalCrossfadeAllowed() {
    final loaded = _loaded;
    return loaded != null &&
        _playIntent &&
        _crossfade == null &&
        _crossfadeDuration > Duration.zero &&
        _queue.repeat != RepeatMode.one &&
        !loaded.source.isPreview &&
        !_sleepAtEndOfTrack;
  }

  /// Manual skips crossfade too, but never when less than
  /// [PlaybackTuning.manualCrossfadeMinPosition] into the track.
  bool _manualCrossfadeAllowed() {
    final loaded = _loaded;
    if (loaded == null || !_playIntent) return false;
    if (_crossfadeDuration == Duration.zero || _queue.repeat == RepeatMode.one) return false;
    if (loaded.source.isPreview) return false;
    final deck = _decks[loaded.deck];
    if (deck == null || deck.state == DeckState.completed) return false;
    return deck.position >= _tuning.manualCrossfadeMinPosition;
  }

  void _dropPrefetch() {
    final pf = _prefetch;
    if (pf == null) return;
    pf.cancel.cancel();
    final onDeck = pf.onDeck;
    if (onDeck != null) {
      unawaited(_decks[onDeck]?.clearPreloaded().catchError((Object e) => _log.fine('clearPreloaded failed', e)));
    }
    _prefetch = null;
  }

  /// Called after anything that may change the natural next item.
  void _revalidatePrefetch() {
    final pf = _prefetch;
    if (pf == null) return;
    final expected = _queue.peekNext();
    final loaded = _loaded;
    if (loaded == null || expected == null || expected.uid != pf.item.uid || expected.uid == loaded.item.uid) {
      _dropPrefetch();
      return;
    }
    final onDeck = pf.onDeck;
    if (onDeck != null && !_gaplessAllowed(_deckAt(onDeck))) {
      pf.onDeck = null;
      unawaited(_deckAt(onDeck).clearPreloaded());
    }
  }

  /// Runs on every tick while playing.
  void _checkPrefetch() {
    final loaded = _loaded;
    if (loaded == null || !_playIntent || _crossfade != null) return;
    final deck = _deckAt(loaded.deck);
    final duration = _durationNow;
    if (duration == null || duration <= Duration.zero) return;
    final remaining = duration - deck.position;
    var lead = Duration.zero;
    if (_settings.current.performance.preloadNext) lead = _tuning.prefetchLead;
    if (_naturalCrossfadeAllowed()) {
      final needed = _crossfadeDuration + const Duration(seconds: 3);
      if (needed > lead) lead = needed;
    }
    if (lead == Duration.zero || remaining > lead) return;
    final next = _queue.peekNext();
    if (next == null || next.uid == loaded.item.uid) return;

    var pf = _prefetch;
    if (pf != null && pf.item.uid != next.uid) {
      _dropPrefetch();
      pf = null;
    }
    if (pf == null) {
      _startPrefetch(next);
      return;
    }
    final resolved = pf.resolved;
    if (resolved != null && pf.onDeck == null && _gaplessAllowed(deck) && !deck.hasPreloaded) {
      pf.onDeck = loaded.deck;
      final current = pf;
      unawaited(deck.preloadNext(resolved.source, track: resolved.playedTrack).catchError((Object e) {
        _log.warning('Gapless preload failed', e);
        if (identical(_prefetch, current)) current.onDeck = null;
      }));
    }
  }

  void _startPrefetch(QueueItem next) {
    final pf = _prefetch = _Prefetch(next);
    unawaited(() async {
      try {
        final resolved = await _resolver.resolve(next.track, cancel: pf.cancel);
        if (!identical(_prefetch, pf) || _disposed) return;
        pf.resolved = resolved;
        _checkPrefetch(); // may set up the gapless preload right away
      } on OperationCanceledException {
        // Dropped.
      } catch (e) {
        // Reported for real when the item is loaded.
        if (identical(_prefetch, pf)) pf.error = e;
        _log.fine('Prefetch of ${next.track.id} failed', e);
      }
    }());
  }

  /// Starts the end-of-track crossfade once the outgoing item is within the
  /// crossfade window and the next item is resolved.
  void _checkCrossfadeStart() {
    if (!_naturalCrossfadeAllowed()) return;
    final loaded = _loaded!;
    final deck = _deckAt(loaded.deck);
    final duration = _durationNow;
    if (duration == null || duration <= Duration.zero) return;
    final remaining = duration - deck.position;
    if (remaining > _crossfadeDuration) return;
    final pf = _prefetch;
    final next = _queue.peekNext();
    if (next == null || pf == null || pf.item.uid != next.uid || next.uid == loaded.item.uid) return;
    final resolved = pf.resolved;
    if (resolved == null || resolved.source.isPreview) return;
    _endCurrent(completed: true);
    _queue.advance();
    _emitQueue();
    unawaited(_loadCurrent(
      autoplay: true,
      crossfade: true,
      crossfadeLength: remaining.isNegative ? Duration.zero : remaining,
      resolved: resolved,
    ));
  }
}
