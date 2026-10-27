part of '../playback_controller_impl.dart';

/// Ticker, persistence, settings sync, output devices and interruptions.
extension _Housekeeping on PlaybackControllerImpl {
  // ----------------------------------------------------------------- ticker

  void _updateTicker() {
    final run = _playIntent && !_disposed;
    if (run && _ticker == null) {
      _ticker = Timer.periodic(_tuning.tickInterval, (_) => _onTick());
    } else if (!run && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  void _onTick() {
    if (_disposed) return;
    _checkPrefetch();
    _checkCrossfadeStart();
    _updateEndOfTrackFade();
    final last = _lastPersistAt;
    if (_loaded != null && (last == null || _now().difference(last) >= _tuning.positionPersistInterval)) {
      _schedulePersist();
    }
    _emitNow(); // ~4 Hz position updates while playing
  }

  // ------------------------------------------------------------ persistence

  void _schedulePersist() {
    if (_disposed) return;
    _persistTimer ??= Timer(_tuning.persistDebounce, () {
      _persistTimer = null;
      unawaited(_persistNow());
    });
  }

  Future<void> _persistNow() {
    if (_disposed) return Future.value();
    _persistTimer?.cancel();
    _persistTimer = null;
    _lastPersistAt = _now();
    return _store.write(PersistedPlaybackState(queue: _queue.toJson(), position: _positionNow, savedAt: _now()));
  }

  Future<void> _restoreState() async {
    final playback = _settings.current.playback;
    if (!playback.restoreQueueOnStartup) return;
    final saved = await _store.read();
    if (saved == null || _disposed) return;
    _queue.restoreJson(saved.queue);
    if (_queue.isEmpty) return;
    var position = saved.position;
    final duration = _queue.current?.track.duration;
    if (duration != null && duration > Duration.zero && position > duration) position = Duration.zero;
    _pendingPosition = position;
    _status = PlayerStatus.idle;
    _emitQueue();
    if (playback.autoPlayOnStartup && _queue.current != null) {
      // Not awaited: resolving may need the network; init() stays fast.
      unawaited(_loadCurrent(autoplay: true, start: position));
    }
  }

  // --------------------------------------------------------------- settings

  void _scheduleSettingsWrite() {
    _settingsWriteTimer?.cancel();
    _settingsWriteTimer = Timer(_tuning.settingsWriteDebounce, _writeSettingsNow);
  }

  void _writeSettingsNow() {
    _settingsWriteTimer = null;
    final p = _settings.current.playback;
    if (p.volume == _volume && p.speed == _speed) return;
    unawaited(_settings.update((s) => s.copyWith(playback: s.playback.copyWith(volume: _volume, speed: _speed))));
  }

  NormalizationConfig _normalizationFor(PlaybackSettings p) {
    var mode = p.normalizationMode;
    if (mode == NormalizationMode.loudness && !_backend.supportsLoudnessNormalization) {
      mode = NormalizationMode.replayGainTrack;
    }
    return NormalizationConfig(enabled: p.normalizeVolume, mode: mode, preampDb: p.preampDb);
  }

  void _onSettingsChanged(AppSettings next) {
    if (_disposed) return;
    final prev = _lastSettings;
    _lastSettings = next;
    final p = next.playback;
    final q = prev.playback;

    final norm = _normalizationFor(p);
    if (norm != _normalizationFor(q)) {
      unawaited(_backend.setNormalization(norm).then((_) => _applyGain()));
    }
    // External volume/speed changes (e.g. the settings page). Our own
    // debounced writes carry the values we already use.
    final localPending = _settingsWriteTimer != null;
    if (!localPending && p.volume != q.volume && p.volume != _volume) {
      _volume = p.volume;
      _applyGain();
      _markDirty();
    }
    if (!localPending && supportsSpeed && p.speed != q.speed && p.speed != _speed) {
      unawaited(_applySpeed(p.speed));
    }
    if (p.crossfadeSeconds != q.crossfadeSeconds ||
        p.gapless != q.gapless ||
        next.performance.preloadNext != prev.performance.preloadNext) {
      _revalidatePrefetch();
    }
    if (p.outputDeviceId != q.outputDeviceId && supportsOutputDeviceSelection) {
      unawaited(_applySavedOutputDevice());
    }
  }

  // --------------------------------------------------------- output devices

  /// Applies `playback.outputDeviceId`, falling back to the system default
  /// when that device is not present (the setting is kept, so the device is
  /// used again once it reappears).
  Future<void> _applySavedOutputDevice() async {
    final saved = _settings.current.playback.outputDeviceId;
    try {
      if (saved == null) {
        if (_activeDeviceId != null) {
          await _backend.setOutputDevice(null);
          _activeDeviceId = null;
        }
        return;
      }
      final devices = await _backend.outputDevices();
      if (devices.any((d) => d.id == saved)) {
        await _backend.setOutputDevice(saved);
        _activeDeviceId = saved;
      } else {
        _log.info('Saved output device "$saved" is not available; using the system default');
        await _backend.setOutputDevice(null);
        _activeDeviceId = null;
      }
    } catch (e, st) {
      _log.warning('Could not apply the output device', e, st);
    }
  }

  void _onDevicesChanged(List<AudioOutputDevice> devices) {
    if (_disposed) return;
    final ids = {for (final d in devices) d.id};
    final active = _activeDeviceId;
    final saved = _settings.current.playback.outputDeviceId;
    if (active != null && !ids.contains(active)) {
      _log.info('Output device "$active" disappeared; falling back to the system default');
      _activeDeviceId = null;
      unawaited(_backend.setOutputDevice(null));
    } else if (saved != null && active != saved && ids.contains(saved)) {
      _activeDeviceId = saved;
      unawaited(_backend.setOutputDevice(saved));
    }
  }

  // ---------------------------------------------------------- interruptions

  void _onInterruption(AudioInterruption event) {
    if (_disposed) return;
    final actions = _interruptions.handle(
      event,
      isPlaying: _playIntent,
      settings: _settings.current.playback,
    );
    for (final action in actions) {
      switch (action) {
        case InterruptionAction.pause:
          unawaited(_pauseInternal());
        case InterruptionAction.resume:
          unawaited(_resume());
        case InterruptionAction.duck:
          _duck = _tuning.duckGain;
          _applyGain();
        case InterruptionAction.unduck:
          _duck = 1.0;
          _applyGain();
      }
    }
  }
}
