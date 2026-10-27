import 'package:flutter/foundation.dart';

import 'source_rules.dart';
import 'util/async_utils.dart';

/// Tunables of `PlaylistImportServiceImpl`.
@immutable
class ImportSettings {
  const ImportSettings({
    this.maxConcurrentMatches = 3,
    this.maxTracks = 10000,
    this.maxPages = 1000,
    this.progressInterval = const Duration(milliseconds: 100),
    this.rateLimit = const RateLimitPolicy(maxRetries: 3),
    this.alternativesLimit = 20,
    this.writeChunkSize = 500,
    this.explicitOnlySources = MatchingSourceRules.explicitOnlySources,
    this.maxSearchPageSize = MatchingSourceRules.maxSearchPageSize,
    this.minimizedOriginalSources = MatchingSourceRules.minimizedOriginalSources,
    this.maxFinishedSessions = 5,
    this.finishedSessionTtl = const Duration(hours: 1),
  });

  /// Tracks matched in parallel.
  final int maxConcurrentMatches;

  /// Imports stop fetching after this many tracks.
  final int maxTracks;

  /// Safety cap on playlist pages (guards against cursor loops).
  final int maxPages;

  /// Minimum spacing of progress events while matching (phase changes are
  /// always emitted immediately). Zero emits after every track.
  final Duration progressInterval;

  /// Retry policy for playlist page fetches and alternative searches.
  final RateLimitPolicy rateLimit;

  /// Results requested per source by `searchAlternatives`.
  final int alternativesLimit;

  /// Tracks per repository write.
  final int writeChunkSize;

  /// Sources searched for alternatives only when the user picks them (by
  /// `sourceId` or in the session's target sources); YouTube's search quota
  /// is tiny.
  final Set<String> explicitOnlySources;

  /// Per-source cap on the search page size.
  final Map<String, int> maxSearchPageSize;

  /// Sources whose tracks are saved minimized (no cover art, marked for
  /// purge); see `ImportSaver.minimize`.
  final Set<String> minimizedOriginalSources;

  /// Finished sessions (done, failed, canceled) kept in memory for
  /// `current`/`watch`/`report`; older ones are forgotten when a new import
  /// starts. Sessions that are still running or in review are never
  /// evicted.
  final int maxFinishedSessions;

  /// Finished sessions older than this are forgotten when a new import
  /// starts.
  final Duration finishedSessionTtl;
}
