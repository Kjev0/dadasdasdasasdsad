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

  /// Sources where ISRCs are entered by uploaders rather than delivered by
  /// distributors (API_NOTES: SoundCloud/Audius `isrc` fields). An
  /// identical ISRC from them is only trusted when title, artist and
  /// duration agree as well.
  static const uploaderIsrcSources = {SourceIds.soundcloud, SourceIds.youtube, SourceIds.audius};

  /// Sources whose originals are stored minimized when an import is saved
  /// (no cover art, marked for purge): Spotify's Developer Terms forbid a
  /// persistent mirror of Spotify metadata and cover art (API_NOTES §2.7).
  static const minimizedOriginalSources = {SourceIds.spotify};
}
