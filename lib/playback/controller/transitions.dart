part of '../playback_controller_impl.dart';

/// Loading items onto decks, natural/gapless advances, failures, queue end.
extension _Transitions on PlaybackControllerImpl {
  AudioDeck _deckAt(int index) {
    final existing = _decks[index];
    if (existing != null) return existing;
    final deck = _backend.createDeck();
    _decks[index] = deck;
    _deckSubs.addAll([
      deck.stateStream.listen((s) => _onDeckState(index, s)),
      deck.durationStream.listen((_) {
        if (_loaded?.deck == index) _markDirty();
      }),
      deck.completions.listen((_) => _onDeckCompleted(index)),
      deck.advancedToPreloaded.listen((_) => _onDeckAdvanced(index)),
      deck.errors.listen((e) => _onDeckError(index, e)),
    ]);
    if (_speed != 1.0) unawaited(deck.setSpeed(_speed));
    return deck;
  }

  static PlayerStatus _statusOf(DeckState s) => switch (s) {
        DeckState.idle => PlayerStatus.idle,
        DeckState.loading => PlayerStatus.loading,
        DeckState.buffering => PlayerStatus.buffering,
        DeckState.ready => PlayerStatus.ready,
        DeckState.completed => PlayerStatus.completed,
      };

  void _onDeckState(int index, DeckState state) {
    if (_disposed || _loaded?.deck != index) return;
    // Completion is handled by [_onDeckCompleted]; idle happens transiently
    // while a deck reloads.
    if (state == DeckState.completed || state == DeckState.idle) return;
    final status = _statusOf(state);
    if (status != _status) {
      _status = status;
      _markDirty();
    }
  }

  void _onDeckCompleted(int index) {
    final loaded = _loaded;
    if (_disposed || loaded == null || loaded.deck != index) return;
    // A completion that was queued before the deck was reloaded is stale.
    if (_deckAt(index).state != DeckState.completed) return;
    unawaited(_onCompleted());
  }

  void _onDeckAdvanced(int index) {
    if (_disposed || _loaded?.deck != index) return;
    unawaited(_onGaplessAdvance(index));
  }

  void _onDeckError(int index, DeckError error) {
    final loaded = _loaded;
    if (_disposed) return;
    if (!error.fatal || loaded == null || loaded.deck != index) {
      _log.fine('Ignoring deck $index error: $error');
      return;
    }
    _log.warning('Playback error on "${loaded.item.track.title}": $error');
    if (loaded.started && !loaded.source.isLocalFile && !loaded.retriedAfterError) {
      // Remote streams may die mid-way (expired signature, dropped
      // connection): re-resolve once and continue at the same position.
      loaded.retriedAfterError = true;
      unawaited(_loadCurrent(autoplay: _playIntent, start: _positionNow, continuing: loaded));
      return;
    }
    _endCurrent(completed: false);
    unawaited(_onItemFailed(loaded.item, error));
  }

  /// Starts (autoplay) or parks (lazily, without touching the network) the
  /// current queue item.
  Future<void> _selectCurrent({required bool autoplay, Duration start = Duration.zero, bool crossfade = false}) {
    if (autoplay) return _loadCurrent(autoplay: true, start: start, crossfade: crossfade);
    _park(start);
    return Future.value();
  }

  /// Unloads the decks but keeps the current item and position. `play()`
  /// loads it again.
  void _park(Duration position, {PlayerStatus status = PlayerStatus.idle}) {
    _loadGen++;
    _loading = false;
    _loadCancel?.cancel();
    _finishCrossfade();
    _dropPrefetch();
    _loaded = null;
    _pendingPosition = position;
    _playIntent = false;
    _status = status;
    for (final deck in _decks) {
      if (deck != null) unawaited(deck.stop().catchError((Object e) => _log.fine('deck stop failed', e)));
    }
    _updateTicker();
    _markDirty();
  }

  /// Resolves and opens the current queue item.
  ///
  /// * [crossfade]: open on the other deck and ramp volumes.
  /// * [resolved]: an already resolved stream (prefetch).
  /// * [continuing]: the same item re-opened (expired URL, stream error);
  ///   keeps its listen clock and does not emit a new [TrackStarted].
  Future<void> _loadCurrent({
    required bool autoplay,
    Duration start = Duration.zero,
    bool crossfade = false,
    Duration? crossfadeLength,
    ResolvedStream? resolved,
    _Loaded? continuing,
  }) async {
    final item = _queue.current;
    final gen = ++_loadGen;
    _loadCancel?.cancel();
    final cancel = _loadCancel = CancelToken();
    if (item == null) {
      _park(Duration.zero);
      return;
    }

    final previous = _loaded;
    final prefetched = _prefetch;
    if (resolved == null &&
        continuing == null &&
        prefetched?.item.uid == item.uid &&
        prefetched?.resolved != null &&
        !_isExpired(prefetched!.resolved!.source)) {
      resolved = prefetched.resolved;
    }
    // The deck is about to be reopened, which drops any gapless preload.
    prefetched?.onDeck = null;
    _dropPrefetch();
    if (resolved == null &&
        continuing == null &&
        previous != null &&
        previous.item.uid == item.uid &&
        !_isExpired(previous.source)) {
      resolved = previous.resolved; // repeat-one / restart: same stream
    }

    final outgoing = _activeDeck;
    if (!crossfade) {
      _finishCrossfade();
      final deck = _decks[outgoing];
      if (deck != null && deck.playing) unawaited(deck.pause());
    } else {
      _finishCrossfade();
    }

    _loaded = null;
    _loading = true;
    _pendingPosition = start;
    _playIntent = autoplay;
    _status = PlayerStatus.loading;
    _updateTicker();
    _markDirty();

    ResolvedStream stream;
    try {
      stream = resolved ?? await _resolver.resolve(item.track, cancel: cancel);
    } on OperationCanceledException {
      return;
    } catch (e, st) {
      if (gen != _loadGen || _disposed) return;
      _loading = false;
      _log.info('Could not resolve "${item.track.title}" (${item.track.id})', e, st);
      await _onItemFailed(item, e);
      return;
    }
    if (gen != _loadGen || _disposed) return;

    final outgoingPreview = previous?.source.isPreview ?? true;
    var useCrossfade = crossfade && previous != null && !outgoingPreview && !stream.source.isPreview;
    if (crossfade && !useCrossfade) {
      final deck = _decks[outgoing];
      if (deck != null) unawaited(deck.stop());
    }
    final deckIndex = useCrossfade ? 1 - outgoing : outgoing;
    _loadingDeck = deckIndex;
    final deck = _deckAt(deckIndex);
    try {
      await deck.setVolume(useCrossfade ? 0 : _baseGain);
      await deck.open(stream.source, start: start, autoplay: _playIntent, track: stream.playedTrack);
    } catch (e, st) {
      if (gen != _loadGen || _disposed) return;
      _loading = false;
      _log.warning('Could not open "${item.track.title}"', e, st);
      if (useCrossfade) unawaited(_decks[outgoing]?.stop());
      await _onItemFailed(item, e);
      return;
    }
    if (gen != _loadGen || _disposed) {
      // Superseded by a newer load: make sure this deck does not keep playing.
      if (deckIndex != _loadingDeck && deckIndex != _loaded?.deck) unawaited(deck.stop());
      return;
    }
    _loading = false;
    if (useCrossfade && !_playIntent) {
      // Paused while resolving: just switch.
      useCrossfade = false;
      unawaited(_decks[outgoing]?.stop());
      unawaited(deck.setVolume(_baseGain));
    }
    if (!_playIntent && deck.playing) await deck.pause();
    if (_playIntent && !deck.playing) unawaited(deck.play());

    final loaded = _Loaded(
      item: item,
      resolved: stream,
      deck: deckIndex,
      clock: continuing?.clock ?? ListenClock(_now),
    );
    if (continuing != null) {
      loaded
        ..started = continuing.started
        ..startedAt = continuing.startedAt
        ..retriedAfterError = continuing.retriedAfterError;
    }
    _loaded = loaded;
    _activeDeck = deckIndex;
    _status = deck.state == DeckState.idle || deck.state == DeckState.completed
        ? PlayerStatus.ready
        : _statusOf(deck.state);
    if (useCrossfade) {
      final configured = _crossfadeDuration;
      final length = crossfadeLength == null || crossfadeLength > configured ? configured : crossfadeLength;
      _startCrossfade(outgoing, deckIndex, length);
    }
    if (_playIntent) _markStarted();
    unawaited(_persistNow());
    _updateTicker();
    _markDirty();
  }

  /// Resume (or start) playback of the current item.
  Future<void> _resume() async {
    if (_queue.current == null) {
      if (_queue.isEmpty) return;
      _queue.skipToIndex(0);
      _pendingPosition = Duration.zero;
      _emitQueue();
    }
    final loaded = _loaded;
    if (loaded == null) {
      if (_loading) {
        _playIntent = true;
        _markDirty();
        return;
      }
      final start = _status == PlayerStatus.completed ? Duration.zero : _pendingPosition;
      await _loadCurrent(autoplay: true, start: start);
      return;
    }
    if (_isExpired(loaded.source)) {
      await _loadCurrent(autoplay: true, start: _positionNow, continuing: loaded);
      return;
    }
    _playIntent = true;
    _applyGain();
    await _deckAt(loaded.deck).play();
    _markStarted();
    _updateTicker();
    _markDirty();
  }

  Future<void> _pauseInternal() async {
    _finishCrossfade();
    _playIntent = false;
    final loaded = _loaded;
    if (loaded != null) {
      loaded.clock.pause();
      await _deckAt(loaded.deck).pause();
    }
    _updateTicker();
    unawaited(_persistNow());
    _markDirty();
  }

  void _markStarted() {
    final loaded = _loaded;
    if (loaded == null || loaded.ended) return;
    if (!loaded.started) {
      loaded
        ..started = true
        ..startedAt = _now();
      _failureStreak = 0;
      _error = null;
      _emitEvent(TrackStarted(loaded.item, loaded.startedAt!));
    }
    loaded.clock.start();
  }

  /// Emits [TrackEnded] for the loaded item (once).
  void _endCurrent({required bool completed}) {
    final loaded = _loaded;
    if (loaded == null || !loaded.started || loaded.ended) return;
    loaded
      ..ended = true
      ..clock.pause();
    _emitEvent(TrackEnded(
      item: loaded.item,
      startedAt: loaded.startedAt!,
      listened: loaded.clock.elapsed,
      completed: completed,
    ));
  }

  Future<void> _onItemFailed(QueueItem item, Object error) async {
    _failureStreak++;
    _error = PlaybackControllerImpl._errorCode(error);
    final settings = _settings.current.playback;
    final hasNext = _queue.peekNextIndex(manual: true) != null;
    // Guard against endless loops: stop after one full pass of failures.
    final skip = settings.skipUnplayable && hasNext && _failureStreak < _queue.length;
    _emitEvent(PlaybackFailed(item, error, skipped: skip));
    if (skip) {
      final autoplay = _playIntent;
      _queue.advance(manual: true);
      _emitQueue();
      await _selectCurrent(autoplay: autoplay);
      return;
    }
    _failureStreak = 0;
    _park(Duration.zero, status: PlayerStatus.error);
    if (settings.skipUnplayable && !hasNext) _emitEvent(const QueueEnded());
    unawaited(_persistNow());
  }

  /// Natural end of the loaded item (no gapless preload).
  Future<void> _onCompleted() async {
    _finishCrossfade();
    final sleepAtEnd = _sleepAtEndOfTrack;
    _endCurrent(completed: true);
    final before = _queue.currentIndex;
    final next = _queue.advance();
    if (next == null) {
      await _onQueueEnd();
      return;
    }
    if (_queue.currentIndex != before) _emitQueue();
    if (sleepAtEnd) {
      // Sleep timer "end of track": stop at the boundary, next item ready.
      _park(Duration.zero);
      _cancelSleepTimer();
      unawaited(_persistNow());
      return;
    }
    await _loadCurrent(autoplay: true);
  }

  /// The deck switched to its gapless preload.
  Future<void> _onGaplessAdvance(int deckIndex) async {
    final pf = _prefetch;
    if (pf == null || pf.onDeck != deckIndex || pf.resolved == null) {
      _log.warning('Deck advanced to an unknown preloaded item; reloading the queue position');
      _endCurrent(completed: true);
      final next = _queue.advance();
      if (next == null) return _onQueueEnd();
      _emitQueue();
      return _loadCurrent(autoplay: true);
    }
    _endCurrent(completed: true);
    _prefetch = null;
    final next = _queue.advance();
    if (next == null) return _onQueueEnd();
    _emitQueue();
    if (next.uid != pf.item.uid) return _loadCurrent(autoplay: true);
    _loaded = _Loaded(item: next, resolved: pf.resolved!, deck: deckIndex, clock: ListenClock(_now));
    final state = _deckAt(deckIndex).state;
    _status = state == DeckState.idle || state == DeckState.completed ? PlayerStatus.ready : _statusOf(state);
    if (_playIntent) _markStarted();
    unawaited(_persistNow());
    _markDirty();
  }

  Future<void> _onQueueEnd() async {
    if (await _tryExtendWithSmartQueue()) return;
    _emitEvent(const QueueEnded());
    _park(Duration.zero, status: PlayerStatus.completed);
    unawaited(_persistNow());
  }

  /// Appends smart-queue suggestions and continues. Returns true when it
  /// took over (or a newer action superseded it).
  Future<bool> _tryExtendWithSmartQueue() async {
    final provider = _smartQueueProvider;
    if (provider == null || !_settings.current.playback.smartQueue || _queue.isEmpty) return false;
    final gen = ++_loadGen;
    _loadCancel?.cancel();
    _status = PlayerStatus.loading;
    _markDirty();
    List<Track> more;
    try {
      more = await provider(_queue.recentTracks(limit: _tuning.smartQueueContext));
    } catch (e, st) {
      _log.warning('Smart queue provider failed', e, st);
      return gen != _loadGen;
    }
    if (_disposed || gen != _loadGen) return true;
    if (more.isEmpty) return false;
    _queue.enqueue(more, origin: smartQueueOrigin, manual: false);
    if (_queue.advance() == null) return false;
    _emitQueue();
    await _loadCurrent(autoplay: true);
    return true;
  }
}
