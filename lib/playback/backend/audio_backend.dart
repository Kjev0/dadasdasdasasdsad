import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import '../../settings/app_settings.dart';

/// Processing state of a single [AudioDeck].
enum DeckState {
  /// Nothing loaded (initial state, or after [AudioDeck.stop]).
  idle,

  /// Opening the media (probing, connecting).
  loading,

  /// Loaded but waiting for data.
  buffering,

  /// Able to play.
  ready,

  /// Reached the natural end of the last loaded item.
  completed,
}

/// An error reported by a deck.
@immutable
class DeckError {
  const DeckError(this.message, {this.fatal = true, this.cause});

  final String message;

  /// Fatal errors mean the current item cannot be played (open failure,
  /// decoder failure before playback started, network gone mid-stream).
  /// Non-fatal errors are logged by the engine and otherwise ignored.
  final bool fatal;
  final Object? cause;

  @override
  String toString() => 'DeckError(${fatal ? 'fatal' : 'non-fatal'}: $message)';
}

/// Loudness normalization configuration applied by the backend.
///
/// Desktop (libmpv) applies it natively (`replaygain*` options, EBU R128
/// `loudnorm` filter); Android applies ReplayGain as volume attenuation.
@immutable
class NormalizationConfig {
  const NormalizationConfig({
    this.enabled = false,
    this.mode = NormalizationMode.replayGainTrack,
    this.preampDb = 0,
  });

  const NormalizationConfig.off() : this();

  factory NormalizationConfig.fromSettings(PlaybackSettings s) =>
      NormalizationConfig(enabled: s.normalizeVolume, mode: s.normalizationMode, preampDb: s.preampDb);

  final bool enabled;
  final NormalizationMode mode;
  final double preampDb;

  @override
  bool operator ==(Object other) =>
      other is NormalizationConfig && other.enabled == enabled && other.mode == mode && other.preampDb == preampDb;

  @override
  int get hashCode => Object.hash(enabled, mode, preampDb);

  @override
  String toString() => 'NormalizationConfig(enabled: $enabled, mode: ${mode.name}, preamp: $preampDb dB)';
}

/// System audio-focus / route events (Android). Desktop backends never emit.
enum AudioInterruptionKind {
  /// Another app took audio focus for a short time (call, navigation prompt).
  transientPause,

  /// Another app wants us to lower our volume for a short time.
  transientDuck,

  /// Audio focus was lost for an unknown/long time (another player started).
  permanentLoss,

  /// Headphones were unplugged / Bluetooth audio disconnected.
  becomingNoisy,
}

/// A begin/end pair of interruption notifications.
@immutable
class AudioInterruption {
  const AudioInterruption(this.kind, {required this.begin});

  final AudioInterruptionKind kind;

  /// True when the interruption starts; false when it ends (focus regained).
  /// [AudioInterruptionKind.becomingNoisy] is always `begin == true`.
  final bool begin;

  @override
  String toString() => 'AudioInterruption(${kind.name}, ${begin ? 'begin' : 'end'})';
}

/// One audio player instance. The engine uses two decks for crossfading.
///
/// Volumes are *linear amplitude gains* in 0..1 (the engine already applied
/// the user's volume curve, fades and ducking); a backend that normalizes by
/// attenuation multiplies its own normalization gain on top.
abstract class AudioDeck {
  /// Loads [source] and starts at [start]. When [autoplay] is false the deck
  /// stays paused at [start]. [track] carries metadata (ReplayGain tags) for
  /// backends that normalize in Dart. May throw when the media cannot be
  /// opened; asynchronous failures are reported on [errors].
  Future<void> open(PlayableSource source, {Duration start = Duration.zero, bool autoplay = true, Track? track});

  Future<void> play();
  Future<void> pause();

  /// Unloads the media and releases the output (the deck stays usable).
  Future<void> stop();
  Future<void> seek(Duration position);

  /// Linear amplitude gain 0..1.
  Future<void> setVolume(double gain);
  Future<void> setSpeed(double speed);

  /// Whether [preloadNext] gives a gapless transition.
  bool get supportsGapless;

  /// Queue [source] to start seamlessly when the current item ends. When the
  /// transition happens [advancedToPreloaded] fires instead of [completions].
  Future<void> preloadNext(PlayableSource source, {Track? track});

  /// Drops a pending [preloadNext] (e.g. the queue changed).
  Future<void> clearPreloaded();

  bool get hasPreloaded;

  Duration get position;
  Duration get bufferedPosition;
  Duration? get duration;
  bool get playing;
  DeckState get state;

  Stream<Duration> get positionStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Stream<DeckState> get stateStream;

  /// Natural end of the current item when nothing was preloaded.
  Stream<void> get completions;

  /// A gapless transition to the preloaded item happened.
  Stream<void> get advancedToPreloaded;
  Stream<DeckError> get errors;

  Future<void> dispose();
}

/// Factory for [AudioDeck]s plus device-wide capabilities.
abstract class AudioBackend {
  /// One-time asynchronous setup (audio session configuration, ...).
  Future<void> init();

  AudioDeck createDeck();

  bool get supportsSpeed;
  bool get supportsOutputDeviceSelection;

  /// True when [NormalizationMode.loudness] (EBU R128) is available.
  bool get supportsLoudnessNormalization;

  Future<List<AudioOutputDevice>> outputDevices();

  /// Emits whenever the list of output devices changes.
  Stream<List<AudioOutputDevice>> get outputDevicesChanges;

  /// Null selects the system default. Applies to every deck.
  Future<void> setOutputDevice(String? deviceId);

  /// Applies to every deck (current and future).
  Future<void> setNormalization(NormalizationConfig config);

  /// Audio focus / becoming-noisy events (Android only).
  Stream<AudioInterruption> get interruptions;

  /// Disposes every deck created by this backend.
  Future<void> dispose();
}
