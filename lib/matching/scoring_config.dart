import 'package:flutter/foundation.dart';

import '../core/models/matching.dart';

/// Default thresholds of the matching engine. See docs/MATCHING.md for the
/// rationale and how to tune them; [ScoringConfig] lets callers override
/// every value.
abstract final class MatchThresholds {
  /// Minimum score for [MatchConfidence.high].
  static const double high = 0.88;

  /// Minimum score for [MatchConfidence.medium].
  static const double medium = 0.70;

  /// Minimum score for [MatchConfidence.low]; below is [MatchConfidence.none].
  static const double low = 0.45;

  /// Score floor for identical ISRCs (without significant version
  /// differences). Metadata agreement fills the remaining 0.02.
  static const double isrcFloor = 0.98;

  /// High confidence additionally needs a strong title and artist signal,
  /// so a perfect duration/album cannot compensate for a doubtful artist.
  static const double highMinTitle = 0.85;
  static const double highMinArtist = 0.80;

  /// Below these the candidate is capped at [MatchConfidence.low].
  static const double capMinTitle = 0.60;
  static const double capMinArtist = 0.50;

  /// Flag thresholds for the corresponding [MatchDifference]s.
  static const double titleMismatchBelow = 0.75;
  static const double artistMismatchBelow = 0.70;
  static const double featuredMismatchBelow = 0.50;
  static const double albumMismatchBelow = 0.50;
  static const int yearMismatchAboveYears = 3;

  /// Score multiplier when the versions differ significantly (remix vs
  /// original, live vs studio, ...). Confidence is also capped at low.
  static const double significantVersionPenalty = 0.6;

  /// Score multiplier when durations differ by more than
  /// [DurationBands.disqualifying]. Confidence is also capped at low.
  static const double farDurationPenalty = 0.75;

  /// Album score floor when one side is a single/EP release (singles and
  /// album releases of the same recording are common).
  static const double singleAlbumFloor = 0.7;
}

/// Duration agreement bands (absolute difference).
abstract final class DurationBands {
  /// Up to here the durations agree perfectly (encoding/rounding noise).
  static const perfect = Duration(seconds: 2);

  /// Up to here still good (different encodes, trimmed silence).
  static const good = Duration(seconds: 5);

  /// Beyond this the candidate cannot be high confidence.
  static const fair = Duration(seconds: 10);

  /// Beyond this the duration is near-disqualifying (different edit or a
  /// different recording).
  static const disqualifying = Duration(seconds: 30);

  /// Piecewise-linear duration score: 1.0 within [perfect], 0.85 at [good],
  /// 0.45 at [fair], 0.05 at [disqualifying] and 0 beyond.
  static double score(Duration delta) {
    final d = delta.inMilliseconds.abs() / 1000.0;
    final p = perfect.inMilliseconds / 1000.0;
    final g = good.inMilliseconds / 1000.0;
    final f = fair.inMilliseconds / 1000.0;
    final x = disqualifying.inMilliseconds / 1000.0;
    if (d <= p) return 1.0;
    if (d <= g) return _lerp(1.0, 0.85, (d - p) / (g - p));
    if (d <= f) return _lerp(0.85, 0.45, (d - g) / (f - g));
    if (d <= x) return _lerp(0.45, 0.05, (d - f) / (x - f));
    return 0.0;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Relative weights of the scoring signals. Signals that are unknown on
/// either side (album, duration, year, explicit flag, artist) are dropped
/// and the remaining weights renormalized, so missing metadata is neither
/// rewarded nor penalized. Version agreement is not a weight: a significant
/// version difference applies a penalty and a confidence cap instead.
@immutable
class ScoringWeights {
  const ScoringWeights({
    this.title = 0.40,
    this.primaryArtist = 0.28,
    this.duration = 0.14,
    this.featuredArtists = 0.05,
    this.album = 0.05,
    this.explicit = 0.04,
    this.year = 0.04,
  });

  final double title;
  final double primaryArtist;
  final double duration;
  final double featuredArtists;
  final double album;
  final double explicit;
  final double year;
}

/// All tunables of `WeightedTrackScorer`.
@immutable
class ScoringConfig {
  const ScoringConfig({
    this.weights = const ScoringWeights(),
    this.highThreshold = MatchThresholds.high,
    this.mediumThreshold = MatchThresholds.medium,
    this.lowThreshold = MatchThresholds.low,
    this.isrcFloor = MatchThresholds.isrcFloor,
    this.highMinTitle = MatchThresholds.highMinTitle,
    this.highMinArtist = MatchThresholds.highMinArtist,
    this.capMinTitle = MatchThresholds.capMinTitle,
    this.capMinArtist = MatchThresholds.capMinArtist,
    this.significantVersionPenalty = MatchThresholds.significantVersionPenalty,
    this.farDurationPenalty = MatchThresholds.farDurationPenalty,
    this.significantVersionCap = MatchConfidence.low,
  });

  final ScoringWeights weights;
  final double highThreshold;
  final double mediumThreshold;
  final double lowThreshold;
  final double isrcFloor;
  final double highMinTitle;
  final double highMinArtist;
  final double capMinTitle;
  final double capMinArtist;
  final double significantVersionPenalty;
  final double farDurationPenalty;

  /// Best confidence a candidate with a significant version difference can
  /// get. `low` by default so it is never auto-accepted nor bulk-accepted
  /// at "medium or better"; it still shows in review as an alternative.
  final MatchConfidence significantVersionCap;

  MatchConfidence band(double score) {
    if (score >= highThreshold) return MatchConfidence.high;
    if (score >= mediumThreshold) return MatchConfidence.medium;
    if (score >= lowThreshold) return MatchConfidence.low;
    return MatchConfidence.none;
  }
}

/// Ordering helpers: exact > high > medium > low > none.
extension MatchConfidenceOrdering on MatchConfidence {
  /// Whether this is at least as confident as [other].
  bool isAtLeast(MatchConfidence other) => index <= other.index;

  /// This confidence, lowered to [max] if it is better than [max].
  MatchConfidence cappedAt(MatchConfidence max) => index < max.index ? max : this;
}
