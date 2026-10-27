import 'package:logging/logging.dart';

import '../core/contracts/matching.dart';
import '../core/models/matching.dart';
import '../core/models/track.dart';
import 'normalizer.dart';
import 'scoring_config.dart';
import 'similarity.dart';
import 'version_detector.dart';

/// Breakdown keys of [MatchCandidate.breakdown] produced by
/// [WeightedTrackScorer]. Signals that were unknown are absent.
abstract final class ScoreKeys {
  static const title = 'title';
  static const artist = 'artist';
  static const featured = 'featured';
  static const album = 'album';
  static const duration = 'duration';
  static const explicit = 'explicit';
  static const year = 'year';

  /// 1 = same version, 0.9 = only remaster/radio-edit differences,
  /// 0 = significantly different version.
  static const version = 'version';

  /// 1 = identical ISRC, 0 = both known but different,
  /// [MatchThresholds.isrcContradicted] = identical but contradicted by the
  /// title/artist/duration, so it was ignored.
  static const isrc = 'isrc';

  /// Weighted metadata score before penalties.
  static const raw = 'raw';

  /// 1 when the best reading parsed "Artist - Title" out of a title.
  static const artistTitleSplit = 'artistTitleSplit';
}

/// Scores a candidate against an original from weighted metadata signals.
///
/// Deterministic and side-effect free. Normalized forms are cached per
/// [Track] instance, so scoring many candidates against one original only
/// normalizes the original once.
class WeightedTrackScorer implements TrackScorer {
  WeightedTrackScorer({
    this.normalizer = const TrackNormalizer(),
    this.detector = const VersionDetector(),
    this.config = const ScoringConfig(),
  });

  final TrackNormalizer normalizer;
  final VersionDetector detector;
  final ScoringConfig config;

  static final _log = Logger('matching.scorer');
  final _cache = Expando<NormalizedTrack>('normalizedTrack');

  /// The (cached) normalized form of [track].
  NormalizedTrack normalized(Track track) => _cache[track] ??= normalizer.normalize(track);

  @override
  MatchCandidate score(Track original, Track candidate) {
    final o = normalized(original);
    final c = normalized(candidate);
    final w = config.weights;

    // Title, artist and version depend on how each title is read ("Artist -
    // Title" uploads, dash tails that may be qualifiers); keep the best
    // combination.
    late _ReadingMatch reading;
    var first = true;
    for (final ro in o.readings) {
      for (final rc in c.readings) {
        final m = _ReadingMatch.of(ro, rc, w, detector, config.significantVersionPenalty);
        if (first || m.weighted > reading.weighted) reading = m;
        first = false;
      }
    }

    final signals = <String, double>{};
    final weights = <String, double>{};
    void signal(String key, double? value, double weight) {
      if (value == null || weight <= 0) return;
      signals[key] = value;
      weights[key] = weight;
    }

    final durationDelta = (original.duration != null && candidate.duration != null)
        ? candidate.duration! - original.duration!
        : null;
    final absDelta = durationDelta?.abs();

    signal(ScoreKeys.title, reading.title, w.title);
    signal(ScoreKeys.artist, reading.primary, w.primaryArtist);
    signal(ScoreKeys.featured, reading.featured, w.featuredArtists);
    signal(ScoreKeys.album, _albumScore(o, c), w.album);
    signal(ScoreKeys.duration, absDelta == null ? null : DurationBands.score(absDelta), w.duration);
    signal(ScoreKeys.explicit, _explicitScore(o, c), w.explicit);
    signal(ScoreKeys.year, _yearScore(original.year, candidate.year), w.year);

    final totalWeight = weights.values.fold(0.0, (a, b) => a + b);
    var raw = 0.0;
    signals.forEach((k, v) => raw += v * weights[k]!);
    raw = totalWeight == 0 ? 0 : raw / totalWeight;

    // ---- Differences -----------------------------------------------------
    final diffs = {...reading.versionDiffs};
    final significant = reading.significant;
    final explicitMismatch = signals[ScoreKeys.explicit] == 0;
    if (explicitMismatch) diffs.add(MatchDifference.explicitMismatch);
    if (absDelta != null && absDelta > DurationBands.good) diffs.add(MatchDifference.durationMismatch);
    final album = signals[ScoreKeys.album];
    if (album != null && album < MatchThresholds.albumMismatchBelow) diffs.add(MatchDifference.albumMismatch);
    if (original.year != null &&
        candidate.year != null &&
        (original.year! - candidate.year!).abs() > MatchThresholds.yearMismatchAboveYears) {
      diffs.add(MatchDifference.yearMismatch);
    }
    final primary = reading.primary;
    if (primary != null && primary < MatchThresholds.artistMismatchBelow) diffs.add(MatchDifference.artistMismatch);
    if (reading.hasFeatured && reading.featured < MatchThresholds.featuredMismatchBelow) {
      diffs.add(MatchDifference.featuredArtistMismatch);
    }
    if (reading.title < MatchThresholds.titleMismatchBelow) diffs.add(MatchDifference.titleMismatch);
    if (candidate.availability.playback == PlaybackRights.preview) diffs.add(MatchDifference.previewOnly);

    // ---- ISRC --------------------------------------------------------------
    // An identical ISRC is only trusted when the metadata does not
    // contradict it: uploader platforms let anyone type an ISRC, and a fan
    // re-upload or edit can carry the original's code.
    final isrcEqual = o.isrc != null && o.isrc == c.isrc;
    final isrcTrusted = isrcEqual && _isrcConsistent(original, candidate, reading, absDelta);

    // ---- Score -----------------------------------------------------------
    final farDuration = absDelta != null && absDelta > DurationBands.disqualifying;
    var score = raw;
    if (isrcTrusted) score = config.isrcFloor + (1 - config.isrcFloor) * raw;
    if (significant) score *= config.significantVersionPenalty;
    if (farDuration && !isrcTrusted) score *= config.farDurationPenalty;
    score = score.clamp(0.0, 1.0);

    // ---- Confidence ------------------------------------------------------
    MatchConfidence confidence;
    if (isrcTrusted && !significant) {
      confidence = MatchConfidence.exact;
    } else {
      confidence = config.band(score);
      final strongIdentity = reading.title >= config.highMinTitle && primary != null && primary >= config.highMinArtist;
      final durationOk = absDelta == null || absDelta <= DurationBands.fair;
      if (confidence == MatchConfidence.high && !(strongIdentity && durationOk)) {
        confidence = MatchConfidence.medium;
      }
      // A clean (censored) edit is not the explicit original, nor the other
      // way round: never accepted without the user.
      if (explicitMismatch) confidence = confidence.cappedAt(config.explicitMismatchCap);
      if (significant) confidence = confidence.cappedAt(config.significantVersionCap);
      final weakIdentity = reading.title < config.capMinTitle || (primary != null && primary < config.capMinArtist);
      if (farDuration || weakIdentity) confidence = confidence.cappedAt(MatchConfidence.low);
      if (primary == null) confidence = confidence.cappedAt(MatchConfidence.medium);
      if (reading.title < config.minTitle) confidence = MatchConfidence.none;
      // Keep score and confidence consistent: a capped candidate must not
      // outrank (or display a higher percentage than) a better band.
      score = score.clamp(0.0, _ceiling(confidence));
    }

    final nonSignificantOnly = diffs.any(_versionDiffs.contains);
    final breakdown = <String, double>{
      ...signals,
      ScoreKeys.version: significant ? 0 : (nonSignificantOnly ? 0.9 : 1),
      ScoreKeys.raw: raw,
      if (o.isrc != null && c.isrc != null)
        ScoreKeys.isrc: isrcTrusted ? 1 : (isrcEqual ? MatchThresholds.isrcContradicted : 0),
      if (reading.split) ScoreKeys.artistTitleSplit: 1,
    };

    _log.finest(() => 'score ${original.id} vs ${candidate.id}: ${score.toStringAsFixed(3)} '
        '${confidence.name} ${diffs.map((d) => d.name).join(',')} $breakdown');

    return MatchCandidate(
      candidate: candidate,
      score: score,
      confidence: confidence,
      differences: Set.unmodifiable(diffs),
      durationDelta: durationDelta,
      matchedByIsrc: isrcTrusted,
      breakdown: Map.unmodifiable(breakdown),
    );
  }

  /// Whether the metadata agrees with an identical ISRC: the durations
  /// match within [ScoringConfig.isrcMaxDurationDelta] (or one is unknown)
  /// and the title or the artist agrees. When either track comes from a
  /// platform where uploaders type ISRCs in ([ScoringConfig.uploaderIsrcSources])
  /// both title and artist must agree. Titles/artists are only "or"-ed for
  /// curated catalogs because they legitimately differ there (another
  /// script or a translated title).
  bool _isrcConsistent(Track original, Track candidate, _ReadingMatch reading, Duration? absDelta) {
    if (absDelta != null && absDelta > config.isrcMaxDurationDelta) return false;
    final titleOk = reading.title >= config.capMinTitle;
    final primary = reading.primary;
    final artistOk = primary == null || primary >= config.capMinArtist;
    final uploaded = config.uploaderIsrcSources.contains(original.sourceId) ||
        config.uploaderIsrcSources.contains(candidate.sourceId);
    return uploaded ? titleOk && artistOk : titleOk || artistOk;
  }

  /// Non-significant version differences.
  static const _versionDiffs = {MatchDifference.remaster, MatchDifference.radioEdit};

  /// Highest score a candidate of [confidence] may carry.
  double _ceiling(MatchConfidence confidence) => switch (confidence) {
        MatchConfidence.exact || MatchConfidence.high => 1.0,
        MatchConfidence.medium => config.highThreshold - _bandGap,
        MatchConfidence.low => config.mediumThreshold - _bandGap,
        MatchConfidence.none => config.lowThreshold - _bandGap,
      };

  /// Distance of a capped score below the next band's floor. 0.01 keeps a
  /// capped candidate out of the next band's 0.01 ranking bucket and below
  /// its displayed percentage (0.69 → "69 %", not "70 %").
  static const _bandGap = 0.01;

  double? _albumScore(NormalizedTrack o, NormalizedTrack c) {
    final a = o.album, b = c.album;
    if (a == null || b == null) return null;
    var s = Similarity.foldedTitle(a, b);
    if ((o.albumIsSingle || c.albumIsSingle) && s < MatchThresholds.singleAlbumFloor) {
      s = MatchThresholds.singleAlbumFloor;
    }
    return s;
  }

  static double? _explicitScore(NormalizedTrack o, NormalizedTrack c) {
    if (o.explicit == null || c.explicit == null) return null;
    return o.explicit == c.explicit ? 1 : 0;
  }

  static double? _yearScore(int? a, int? b) {
    if (a == null || b == null || a <= 0 || b <= 0) return null;
    final d = (a - b).abs();
    if (d == 0) return 1;
    if (d == 1) return 0.9;
    if (d <= MatchThresholds.yearMismatchAboveYears) return 0.6;
    return 0.3;
  }
}

/// Title/artist/version agreement of one reading pair.
class _ReadingMatch {
  _ReadingMatch(
    this.title,
    this.primary,
    this.featured,
    this.hasFeatured,
    this.split,
    this.versionDiffs,
    this.significant,
    this.weighted,
  );

  factory _ReadingMatch.of(
    TrackReading a,
    TrackReading b,
    ScoringWeights w,
    VersionDetector detector,
    double significantPenalty,
  ) {
    final title = Similarity.qualifiedTitle(a.title, a.titleQualifier, b.title, b.titleQualifier);
    final overlap = Similarity.artistOverlap(
      primaryA: a.primaryArtists,
      featuredA: a.featuredArtists,
      primaryB: b.primaryArtists,
      featuredB: b.featuredArtists,
    );
    final versionDiffs = detector.compare(a.version, b.version);
    final significant = versionDiffs.any(MatchCandidate.significantVersionDifferences.contains);
    // Unknown artists count as neutral for choosing the reading only. A
    // version difference costs what it costs in the final score, so a
    // reading that explains a dash tail as the title ("Oasis - Live
    // Forever") beats one that reads it as a live qualifier.
    var weighted =
        title * w.title + (overlap.primary ?? 0.5) * w.primaryArtist + overlap.featured * w.featuredArtists;
    if (significant) weighted *= significantPenalty;
    return _ReadingMatch(
      title,
      overlap.primary,
      overlap.featured,
      overlap.hasFeatured,
      a.isArtistTitleSplit || b.isArtistTitleSplit,
      versionDiffs,
      significant,
      weighted,
    );
  }

  final double title;
  final double? primary;
  final double featured;
  final bool hasFeatured;
  final bool split;
  final Set<MatchDifference> versionDiffs;
  final bool significant;
  final double weighted;
}
