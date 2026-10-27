import 'dart:async';

import 'package:audio_session/audio_session.dart' as session;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:logging/logging.dart';

import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import '../engine/gain.dart';
import 'audio_backend.dart';

final _log = Logger('playback.justaudio');

/// Android backend on `just_audio` (ExoPlayer/Media3).
///
/// * Audio focus is configured with `AudioSessionConfiguration.music()`;
///   players run with `handleInterruptions: false` and the session's
///   interruption/becoming-noisy events are forwarded as
///   [AudioInterruption]s so the engine applies Fermata's own policy.
/// * Gapless: the preloaded item is appended to the player's playlist;
///   ExoPlayer transitions seamlessly.
/// * ReplayGain: applied as volume attenuation (never above 1.0) from
///   `Track.replayGainTrackDb/AlbumDb` + preamp. EBU R128 is not available.
/// * HTTP headers from [PlayableSource.headers] are passed natively to
///   ExoPlayer (no local proxy, so no cleartext-traffic exception needed).
class JustAudioBackend implements AudioBackend {
  JustAudioBackend({this.loadConfiguration});

  final ja.AudioLoadConfiguration? loadConfiguration;
  final _decks = <JustAudioDeck>[];
  final _interruptions = StreamController<AudioInterruption>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];
  NormalizationConfig _normalization = const NormalizationConfig.off();
  bool _initialized = false;

  NormalizationConfig get normalization => _normalization;

  /// Maps audio_session events (Android focus changes) to engine events.
  @visibleForTesting
  static AudioInterruption mapInterruption(session.AudioInterruptionEvent e) => AudioInterruption(
        switch (e.type) {
          session.AudioInterruptionType.pause => AudioInterruptionKind.transientPause,
          session.AudioInterruptionType.duck => AudioInterruptionKind.transientDuck,
          session.AudioInterruptionType.unknown => AudioInterruptionKind.permanentLoss,
        },
        begin: e.begin,
      );

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final s = await session.AudioSession.instance;
      await s.configure(const session.AudioSessionConfiguration.music());
      _subs
        ..add(s.interruptionEventStream.listen((e) => _interruptions.add(mapInterruption(e))))
        ..add(s.becomingNoisyEventStream.listen(
            (_) => _interruptions.add(const AudioInterruption(AudioInterruptionKind.becomingNoisy, begin: true))));
    } catch (e, st) {
      _log.warning('Audio session setup failed; interruptions will not be handled', e, st);
    }
  }

  @override
  AudioDeck createDeck() {
    final player = ja.AudioPlayer(
      handleInterruptions: false,
      handleAudioSessionActivation: true,
      androidApplyAudioAttributes: true,
      useProxyForRequestHeaders: false,
      audioLoadConfiguration: loadConfiguration,
    );
    final deck = JustAudioDeck._(this, player);
    _decks.add(deck);
    return deck;
  }

  @override
  bool get supportsSpeed => true;

  @override
  bool get supportsOutputDeviceSelection => false;

  @override
  bool get supportsLoudnessNormalization => false;

  @override
  Future<List<AudioOutputDevice>> outputDevices() async => const [];

  @override
  Stream<List<AudioOutputDevice>> get outputDevicesChanges => const Stream.empty();

  @override
  Future<void> setOutputDevice(String? deviceId) async {}

  @override
  Future<void> setNormalization(NormalizationConfig config) async {
    _normalization = config;
    for (final deck in _decks) {
      await deck._applyVolume();
    }
  }

  @override
  Stream<AudioInterruption> get interruptions => _interruptions.stream;

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    for (final deck in List.of(_decks)) {
      await deck.dispose();
    }
    _decks.clear();
    unawaited(_interruptions.close());
  }
}

/// One ExoPlayer instance.
class JustAudioDeck implements AudioDeck {
  JustAudioDeck._(this._backend, this._player) {
    _subs.addAll([
      _player.processingStateStream.listen(_onProcessingState),
      _player.currentIndexStream.listen(_onIndex),
      _player.errorStream.listen((e) => _errorsCtrl.add(DeckError(e.message ?? 'Playback error ${e.code}', cause: e))),
    ]);
  }

  final JustAudioBackend _backend;
  final ja.AudioPlayer _player;
  final _subs = <StreamSubscription<Object?>>[];
  final _stateCtrl = StreamController<DeckState>.broadcast();
  final _completionsCtrl = StreamController<void>.broadcast();
  final _advancedCtrl = StreamController<void>.broadcast();
  final _errorsCtrl = StreamController<DeckError>.broadcast();

  Track? _track;
  Track? _preloadedTrack;
  bool _hasPreloaded = false;
  double _mix = 1.0;
  DeckState _state = DeckState.idle;
  bool _disposed = false;

  @visibleForTesting
  static DeckState mapState(ja.ProcessingState s) => switch (s) {
        ja.ProcessingState.idle => DeckState.idle,
        ja.ProcessingState.loading => DeckState.loading,
        ja.ProcessingState.buffering => DeckState.buffering,
        ja.ProcessingState.ready => DeckState.ready,
        ja.ProcessingState.completed => DeckState.completed,
      };

  void _onProcessingState(ja.ProcessingState s) {
    final next = mapState(s);
    if (next == _state) return;
    _state = next;
    _stateCtrl.add(next);
    if (next == DeckState.completed) _completionsCtrl.add(null);
  }

  void _onIndex(int? index) {
    if (!_hasPreloaded || index == null || index < 1) return;
    // ExoPlayer moved to the preloaded item: gapless transition.
    _hasPreloaded = false;
    _track = _preloadedTrack;
    _preloadedTrack = null;
    unawaited(_applyVolume());
    _advancedCtrl.add(null);
    unawaited(_player.removeAudioSourceAt(0).catchError((Object e) => _log.fine('remove failed', e)));
  }

  static ja.AudioSource _source(PlayableSource s) =>
      ja.AudioSource.uri(s.uri, headers: s.headers.isEmpty ? null : s.headers);

  Future<void> _applyVolume() => _player.setVolume(_mix * Gain.replayGainFactor(_track, _backend._normalization));

  @override
  Future<void> open(PlayableSource source, {Duration start = Duration.zero, bool autoplay = true, Track? track}) async {
    _track = track;
    _hasPreloaded = false;
    _preloadedTrack = null;
    await _applyVolume();
    await _player.setAudioSource(_source(source), initialPosition: start > Duration.zero ? start : null);
    // play() completes only when playback stops; never await it.
    if (autoplay) unawaited(_player.play());
  }

  @override
  Future<void> play() async => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    _hasPreloaded = false;
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double gain) {
    _mix = gain.clamp(0.0, 1.0);
    return _applyVolume();
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  bool get supportsGapless => true;

  @override
  Future<void> preloadNext(PlayableSource source, {Track? track}) async {
    if (_hasPreloaded) await clearPreloaded();
    await _player.addAudioSource(_source(source));
    _preloadedTrack = track;
    _hasPreloaded = true;
  }

  @override
  Future<void> clearPreloaded() async {
    final sources = _player.audioSources;
    final index = _player.currentIndex ?? 0;
    _hasPreloaded = false;
    _preloadedTrack = null;
    if (sources.length > 1 && index < sources.length - 1) {
      await _player.removeAudioSourceAt(sources.length - 1);
    }
  }

  @override
  bool get hasPreloaded => _hasPreloaded;

  @override
  Duration get position => _player.position;

  @override
  Duration get bufferedPosition => _player.bufferedPosition;

  @override
  Duration? get duration => _player.duration;

  @override
  bool get playing => _player.playing;

  @override
  DeckState get state => _state;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<DeckState> get stateStream => _stateCtrl.stream;

  @override
  Stream<void> get completions => _completionsCtrl.stream;

  @override
  Stream<void> get advancedToPreloaded => _advancedCtrl.stream;

  @override
  Stream<DeckError> get errors => _errorsCtrl.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _backend._decks.remove(this);
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    await _player.dispose();
    for (final c in [_stateCtrl, _completionsCtrl, _advancedCtrl, _errorsCtrl]) {
      unawaited(c.close());
    }
  }
}
