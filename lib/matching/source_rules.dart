import '../core/sources/source_ids.dart';

/// Provider constraints that shape *matching* (verified 2026-10-27, see
/// docs/research/API_NOTES.md and docs/COMPLIANCE.md). Playback/download
/// rules live in `SourcePolicies`; these are the matcher's defaults and can
/// be overridden through `MatcherSettings` / `ImportSettings`.
abstract final class MatchingSourceRules {
  /// Never searched automatically; only when the user explicitly selects
  /// them as a target. YouTube Data API search is capped at 100 calls per
  /// day per project.
  static const explicitOnlySources = {SourceIds.youtube};

  /// Maximum metadata search queries per track and source.
  static const maxQueriesPerTrack = {SourceIds.youtube: 1};

  /// Largest page size a provider accepts for track search (Spotify: 10
  /// since Feb 2026).
  static const maxSearchPageSize = {SourceIds.spotify: 10};

  /// Sources used to look up a missing ISRC before matching (Deezer's
  /// public search returns ISRCs and `track/isrc:` resolves them without
  /// auth). The enriched ISRC is only used for `lookupByIsrc` on other
  /// targets; it never makes a candidate `exact`, because it was derived
  /// from a metadata match rather than from the original.
  static const isrcResolvers = [SourceIds.deezer];
}
