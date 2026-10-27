import 'dart:math' as math;

import '../../core/models/track.dart';
import '../../settings/app_settings.dart';
import '../backend/audio_backend.dart';

/// Volume/gain math shared by the engine and the backends.
abstract final class Gain {
  /// Maps the user's perceptual volume slider (0..1) to a linear amplitude
  /// gain. Cubic, like mpv's own volume curve, so the slider feels even.
  static double fromUserVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    return v * v * v;
  }

  /// Converts decibels to a linear amplitude factor.
  static double dbToLinear(double db) => math.pow(10, db / 20).toDouble();

  /// Equal-power crossfade curves for progress [t] in 0..1.
  /// Returns (outgoing, incoming) gains whose powers sum to 1.
  static (double, double) equalPower(double t) {
    final p = t.clamp(0.0, 1.0);
    return (math.cos(p * math.pi / 2), math.sin(p * math.pi / 2));
  }

  /// ReplayGain applied as attenuation (never amplifies above 1.0), used by
  /// backends without native ReplayGain support (Android/ExoPlayer).
  ///
  /// Album mode falls back to the track gain when the album tag is missing
  /// (and vice versa). Without tags only the preamp applies (if negative).
  /// [NormalizationMode.loudness] is not available there and behaves like
  /// track mode.
  static double replayGainFactor(Track? track, NormalizationConfig config) {
    if (!config.enabled) return 1.0;
    final trackDb = track?.replayGainTrackDb;
    final albumDb = track?.replayGainAlbumDb;
    final tagDb = switch (config.mode) {
      NormalizationMode.replayGainAlbum => albumDb ?? trackDb,
      NormalizationMode.replayGainTrack || NormalizationMode.loudness => trackDb ?? albumDb,
    };
    final db = (tagDb ?? 0) + config.preampDb;
    return dbToLinear(db).clamp(0.0, 1.0);
  }
}
