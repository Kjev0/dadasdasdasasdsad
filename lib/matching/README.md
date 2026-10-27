# lib/matching — smart track matching & playlist migration

Finds the same recording on the user's other sources and imports playlists
across providers. Implements `lib/core/contracts/matching.dart`
(`TrackScorer`, `TrackMatcher`, `PlaylistImportService`). Design, rules and
tuning: [`docs/MATCHING.md`](../../docs/MATCHING.md).

Import from `package:fermata/matching/matching.dart`.

## Public API

| Class | Constructor | Role |
|---|---|---|
| `WeightedTrackScorer` | `WeightedTrackScorer({TrackNormalizer normalizer = const TrackNormalizer(), VersionDetector detector = const VersionDetector(), ScoringConfig config = const ScoringConfig()})` | `TrackScorer`. Pure, deterministic; caches normalized tracks per `Track` instance |
| `SourceTrackMatcher` | `SourceTrackMatcher({required SourceRegistry registry, required TrackScorer scorer, TrackNormalizer normalizer = const TrackNormalizer(), MatcherSettings settings = const MatcherSettings(), DateTime Function()? clock})` | `TrackMatcher`: ISRC lookup, up to 3 queries per source, ranking, decision, shared rate-limit gate |
| | `SourceTrackMatcher.withSources({required List<MusicSource> Function() sources, required TrackScorer scorer, ...same optionals})` | Same over an explicit source list |
| `PlaylistImportServiceImpl` | `PlaylistImportServiceImpl({required SourceRegistry registry, required TrackMatcher matcher, required TrackScorer scorer, required TrackRepository trackRepository, required PlaylistRepository playlistRepository, required TrackLinkRepository linkRepository, ImportSettings settings = const ImportSettings(), TrackNormalizer normalizer = const TrackNormalizer(), String Function()? idGenerator, DateTime Function()? clock})` | `PlaylistImportService`; extra: `report(id)`, `discard(id)`, `dispose()`, `sessionIds` |
| `ImportReport` | `ImportReport.fromPositions(List<TrackMatchResult?>, {int? expectedTotal, bool truncated})`, `.fromResults(...)`, `.fromState(state, {bool truncated})` | Counts per decision, matches per source, missing tracks with playlist positions, `truncated`. Prefer `PlaylistImportServiceImpl.report(id)` (real positions + truncation) |
| `ScoringConfig`, `ScoringWeights`, `MatchThresholds`, `DurationBands` | `const` | Weights, thresholds, caps (`significantVersionCap`, `explicitMismatchCap`, `isrcMaxDurationDelta`, `uploaderIsrcSources`) |
| `MatcherSettings` | `const MatcherSettings({maxConcurrentTracks = 3, searchLimit = 10, rateLimit = const RateLimitPolicy(), uploaderStyleSources, stopAfterStrongCandidate = true, explicitOnlySources, maxQueriesPerTrack, maxSearchPageSize, isrcResolvers, rateLimitCooldown = 30 s})` | Matcher tunables |
| `ImportSettings` | `const ImportSettings({maxConcurrentMatches = 3, maxTracks = 10000, maxPages = 1000, progressInterval = 100 ms, rateLimit, alternativesLimit = 20, writeChunkSize = 500, explicitOnlySources, maxSearchPageSize, minimizedOriginalSources = {spotify}, maxFinishedSessions = 5, finishedSessionTtl = 1 h})` | Import tunables |
| `RateLimitPolicy` | `const RateLimitPolicy({maxRetries = 2, defaultDelay = 2 s, maxDelay = 30 s})` | `delayFor` returns `null` (= do not retry) for a Retry-After beyond `maxDelay` |
| `TrackNormalizer`, `TitleParser`, `VersionDetector`, `VersionKeywords`, `Similarity`, `SearchQueryBuilder`, `MatchPolicy`, `MatchingSourceRules`, `SourceMatchFailures`, `ImportSaver`, `AlternativeSearch` | — | Building blocks, exported for tests and diagnostics |

`SourceMatchFailures` (in `TrackMatchResult.error`) lists per-source
errors; a source skipped because of a long rate limit shows up there as a
`RateLimitedException` with the remaining `retryAfter`.
`SourceTrackMatcher.rateLimitedUntil(sourceId)` returns the end of a
source's current block (for a "Spotify is rate limited until …" notice).

## Bootstrap wiring (`lib/app/bootstrap.dart`)

After the source registry is initialized (`await sources.initAll()`) and
the library repositories exist; no `init()` is needed. One scorer instance
is shared so normalization is cached once.

```dart
// Matching / playlist migration.
final scorer = WeightedTrackScorer();
final matcher = SourceTrackMatcher(registry: sources, scorer: scorer);
final imports = PlaylistImportServiceImpl(
  registry: sources,
  matcher: matcher,
  scorer: scorer,
  trackRepository: library.tracks,
  playlistRepository: library.playlists,
  linkRepository: library.links,
);

// in disposeAll(), before sources.dispose():
imports.dispose(); // cancels running imports, closes their streams
```

`AppServices(scorer: scorer, matcher: matcher, imports: imports, ...)`
feeds `trackScorerProvider`, `trackMatcherProvider` and
`playlistImportProvider`.

## Platform notes

Pure Dart, no platform code. All network access goes through the
`MusicSource`s.

## Known limitations

* **Spotify data retention (needs a lead decision).** The contract requires
  the saved playlist to hold the *original* tracks. Spotify's Developer
  Terms (API_NOTES §2.7) forbid a persistent mirror of Spotify metadata
  and cover art. As a mitigation, tracks from
  `ImportSettings.minimizedOriginalSources` (Spotify) are saved without
  artwork and marked with `Track.extra[ImportSaver.minimizedMarker]`, and
  the playlist gets no Spotify cover. Purging them on disconnect, and the
  30-day refresh/delete of stored YouTube API data, belong to the library
  and sources modules and are not done here.
* YouTube search has a project-wide quota of 100 calls/day. YouTube is
  therefore explicit-only (1 query per track). Once the quota is used up,
  the matcher stops asking YouTube until the reset (Retry-After from the
  source). There is no local daily budget: the quota is shared by every
  install that uses the same API key.
* Sessions live in memory only. An import in review does not survive an
  app restart.
* `ImportReport.fromState` cannot know true playlist positions while
  matching or after a cancel. `report(id)` can.
* Matching is metadata-based apart from ISRCs. Versions that are not
  labelled in the title or album (an unlabelled live recording, a sped-up
  upload titled like the original) can only be told apart by duration.
