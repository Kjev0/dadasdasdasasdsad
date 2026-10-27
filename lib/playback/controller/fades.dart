part of '../playback_controller_impl.dart';

/// Gain staging, crossfade ramps and the sleep timer.
extension _Fades on PlaybackControllerImpl {
  /// Linear gain of the active deck: user volume (cubic curve) × ducking ×
  /// sleep fade. Normalization is applied by the backend on top.
  double get _baseGain => Gain.fromUserVolume(_volume) * _duck * _sleepFade;

  void _applyGain() {
    if (_crossfade != null) {
      _stepCrossfade();
      return;
    }
    final deck = _decks[_loaded?.deck ?? _activeDeck];
    if (deck != null) unawaited(deck.setVolume(_baseGain));
  }

  Future<void> _applySpeed(double speed) async {
    _speed = speed;
    for (final deck in _decks) {
      if (deck != null) await deck.setSpeed(speed);
    }
    _markDirty();
  }

  // ------------------------------------------------------------- crossfade

  void _startCrossfade(int from, int to, Duration length) {
    _crossfade?.timer?.cancel();
    final cf = _crossfade = _Crossfade(from: from, to: to, startedAt: _now(), length: length);
    cf.timer = Timer.periodic(_tuning.fadeStep, (_) => _stepCrossfade());
    _stepCrossfade();
  }

  /// Applies equal-power gains for the current progress; finishes at t = 1.
  void _stepCrossfade() {
    final cf = _crossfade;
    if (cf == null) return;
    final elapsed = _now().difference(cf.startedAt);
    final t = cf.length <= Duration.zero ? 1.0 : elapsed.inMicroseconds / cf.length.inMicroseconds;
    if (t >= 1.0) {
      _finishCrossfade();
      return;
    }
    final base = _baseGain;
    final (outGain, inGain) = Gain.equalPower(t);
    unawaited(_deckAt(cf.from).setVolume(outGain * base));
    unawaited(_deckAt(cf.to).setVolume(inGain * base));
  }

  /// Completes a running crossfade immediately (also used before any manual
  /// action): stops the outgoing deck and gives the incoming one full gain.
  void _finishCrossfade() {
    final cf = _crossfade;
    if (cf == null) return;
    cf.timer?.cancel();
    _crossfade = null;
    final outgoing = _deckAt(cf.from);
    unawaited(() async {
      await outgoing.setVolume(0);
      await outgoing.stop();
    }());
    unawaited(_deckAt(cf.to).setVolume(_baseGain));
  }

  // ------------------------------------------------------------ sleep timer

  void _startSleepTimer(Duration duration) {
    _sleepEndsAt = _now().add(duration);
    _sleepTimer = Timer(duration, () => unawaited(_onSleepExpired()));
    if (!_settings.current.playback.sleepTimerFadeOut) return;
    final fadeLength = _tuning.sleepFadeDuration;
    final fadeIn = duration - fadeLength;
    if (fadeIn <= Duration.zero) {
      _startSleepFade(duration);
    } else {
      _sleepFadeStartTimer = Timer(fadeIn, () => _startSleepFade(fadeLength));
    }
  }

  void _startSleepFade(Duration length) {
    _sleepFadeLength = length;
    _sleepFadeTimer?.cancel();
    _sleepFadeTimer = Timer.periodic(_tuning.fadeStep, (_) => _sleepFadeTick());
    _sleepFadeTick();
  }

  void _sleepFadeTick() {
    final endsAt = _sleepEndsAt;
    if (endsAt == null || _sleepFadeLength <= Duration.zero) return;
    final remaining = endsAt.difference(_now());
    final fade = (remaining.inMicroseconds / _sleepFadeLength.inMicroseconds).clamp(0.0, 1.0);
    if (fade == _sleepFade) return;
    _sleepFade = fade;
    _applyGain();
  }

  Future<void> _onSleepExpired() async {
    _sleepFadeTimer?.cancel();
    _sleepFadeStartTimer?.cancel();
    _sleepTimer = null;
    _sleepFadeTimer = null;
    _sleepFadeStartTimer = null;
    _sleepEndsAt = null;
    await _pauseInternal();
    // Restore the gain after pausing so the next play() is at full volume.
    if (_sleepFade != 1.0) {
      _sleepFade = 1.0;
      _applyGain();
    }
    _markDirty();
  }

  /// "Sleep at end of track" fades over the last seconds of the track.
  void _updateEndOfTrackFade() {
    if (!_sleepAtEndOfTrack || !_settings.current.playback.sleepTimerFadeOut) return;
    final loaded = _loaded;
    final duration = _durationNow;
    if (loaded == null || duration == null || duration <= Duration.zero) return;
    final remaining = duration - _deckAt(loaded.deck).position;
    final length = _tuning.sleepFadeDuration;
    final fade = remaining >= length ? 1.0 : (remaining.inMicroseconds / length.inMicroseconds).clamp(0.0, 1.0);
    if (fade == _sleepFade) return;
    _sleepFade = fade;
    _applyGain();
  }

  void _cancelSleepTimer() {
    for (final t in [_sleepTimer, _sleepFadeStartTimer, _sleepFadeTimer]) {
      t?.cancel();
    }
    _sleepTimer = null;
    _sleepFadeStartTimer = null;
    _sleepFadeTimer = null;
    _sleepEndsAt = null;
    _sleepAtEndOfTrack = false;
    if (_sleepFade != 1.0) {
      _sleepFade = 1.0;
      _applyGain();
    }
  }
}
