/// Smart track matching and playlist migration.
///
/// * [TrackNormalizer] – metadata normalization ("Artist - Title" uploads,
///   feat. credits, qualifiers, accents).
/// * [VersionDetector] – remix/live/acoustic/... detection.
/// * [Similarity] – string and artist-set similarity.
/// * [WeightedTrackScorer] – `TrackScorer` implementation.
/// * [SourceTrackMatcher] – `TrackMatcher` implementation.
/// * [PlaylistImportServiceImpl] – `PlaylistImportService` implementation,
///   plus [ImportReport] for the result screen.
///
/// See docs/MATCHING.md.
library;

export 'alternative_search.dart';
export 'import_report.dart';
export 'import_saver.dart';
export 'match_errors.dart';
export 'match_policy.dart';
export 'matcher.dart';
export 'normalizer.dart';
export 'playlist_import_service.dart' show ImportSettings, PlaylistImportServiceImpl;
export 'query_builder.dart';
export 'scorer.dart';
export 'scoring_config.dart';
export 'similarity.dart';
export 'util/async_utils.dart' show RateLimitPolicy;
export 'version_detector.dart';
