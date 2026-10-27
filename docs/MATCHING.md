# Track matching and playlist migration

When a user imports a playlist from one provider (Spotify, SoundCloud,
Deezer, YouTube, ...), Fermata looks for the **same recording** on the
user's other authorized sources. The code lives in `lib/matching/` and
implements the contracts in `lib/core/contracts/matching.dart`.

| Piece | File | Role |
|---|---|---|
| `TrackNormalizer` | `normalizer.dart`, `text/*` | Folds accents, cleans titles, extracts qualifiers/features, parses "Artist - Title" uploads |
| `VersionDetector` | `version_detector.dart` | Finds remix/live/acoustic/... tags in title qualifiers and album names |
| `Similarity` | `similarity.dart` | Levenshtein, Jaro-Winkler, token Jaccard, title/name/artist-set similarity |
| `WeightedTrackScorer` | `scorer.dart`, `scoring_config.dart` | `TrackScorer`: one candidate vs. the original → `MatchCandidate` |
| `SourceTrackMatcher` | `matcher.dart`, `query_builder.dart`, `match_policy.dart` | `TrackMatcher`: ISRC lookup + searches on every target, ranking, decision |
| `PlaylistImportServiceImpl` | `playlist_import_service.dart`, `import_session.dart`, `import_saver.dart`, `alternative_search.dart` | `PlaylistImportService`: fetch → match → review → save |
| `ImportReport` | `import_report.dart` | Counts per decision and the list of tracks without a match |
| `MatchingSourceRules` | `source_rules.dart` | Provider constraints that affect matching (quotas, page sizes, ISRC resolver) |

Every scoring rule is deterministic and side-effect free, so it can be
unit-tested without a network (`test/matching/`, 330+ cases).

---

## 1. Normalization

All comparisons use normalized **keys**. The display text is kept for
search queries.

**Character folding** (`text/char_folding.dart`). Dart has no NFKD, so a
lookup table approximates "NFKD + drop combining marks + compatibility
mapping": Latin diacritics (é→e, ł→l, ř→r ...), `ß→ss`, `æ→ae`, `œ→oe`,
`þ→th`, full-width forms, ligatures (`ﬁ→fi`), typographic quotes and dashes,
super/subscript digits. Emoji, pictographs, ©/®/™ and decorative symbols
turn into spaces. Non-Latin scripts pass through unchanged.

*Danish/German letters.* `ø`, `å`, `ä`, `ö`, `ü` have two spellings in the
wild ("Mø" / "MO" / "Moe", "Ålborg" / "Aalborg", "Björk" / "Bjoerk"). Each
key therefore carries a primary fold (`ø→o`, `å→a`, `ä→a`, ...) and, only
when such letters are present, a transliterated **alt** fold (`ø→oe`,
`å→aa`, `ä→ae`, `ö→oe`, `ü→ue`). Similarity takes the best of key/alt
combinations. This is consistent (both sides fold the same way) without
making unrelated digraphs equal ("Joe" never becomes "Jo"). `æ` is always
`ae`.

**Keys** (`text/text_keys.dart`). Lower case; apostrophes removed
("Don’t"→"dont"); `&`/`+`→"and"; in-word `$`→s and `!`→i ("Ke$ha",
"P!nk"); other punctuation → space; number words zero..twenty and
standalone roman numerals II..XII → digits; `pt`→part, `vol`→volume,
`'n'`→and. Artist keys also drop every "the" token ("The Weeknd") and
channel suffixes ("- Topic", "VEVO", "Official").

**Artists** (`text/artist_parser.dart`). Credits are split on `,` `;`
spaced `/`, `&`, "and", "og", "och", "und", "et", "y", `+`, `x`, `×`,
"vs." (so "AC/DC" and "Jay-Z" stay intact); "feat./ft./featuring/with/w/"
separate featured guests. The first credit is the main artist; further
`ArtistRef`s are featured. Splitting is a canonicalization applied to both
sides, and the scorer also compares the joined credit line, so bands whose
names contain a separator ("Tyler, The Creator", "Earth, Wind & Fire")
still match unsplit spellings.

**Titles** (`text/title_parser.dart`), in order:
1. Strip emoji and `#hashtags`.
2. Cut at hard separators (` | `, ` // `, ` • `); the tail is noise or a qualifier.
3. Extract bracketed segments (`()`, `[]`, `{}`, `【】` ...) and classify each:
   *featured* ("feat. X", "with X"), *producer* ("prod. X", dropped),
   *explicit hint* ("Explicit"/"Dirty" vs. "Clean"/"Edited"), *noise*
   ("Official Music Video", "Lyrics", "HD", "Free Download", "Out Now",
   "Video Oficial", ...), otherwise a *qualifier* ("Remastered 2011",
   "Live at Wembley", "Kygo Remix", "Taylor's Version").
4. Inline "feat. X", "prod. by X" and trailing "Official Video" are removed.
5. Split on spaced dashes (" - ", "–", "—"). Tails that look like
   qualifiers (version keywords, "From …", "Bonus Track", years, "Single
   Version" ...) become qualifiers. A leading tag-only part ("Nightcore -
   Song") is a qualifier too.
6. Unambiguous trailing version words without brackets ("Song Sped Up",
   "Song slowed + reverb", "Song Remix") become qualifiers.
7. If a non-qualifier dash part remains, the title is also read as
   **"Artist - Title"**.

**Readings.** A track gets one *reading* (title + artists) or, for "X - Y"
titles, two: as-is, and artist = X, title = Y. On uploader-style sources
(SoundCloud, YouTube, Audius), or when X matches the uploader, the split
reading is preferred (it drives the search queries). The scorer compares
every reading pair and keeps the best, so a SoundCloud upload
"Rogue - Adventure" by the label account "Monstercat" matches Spotify
"Adventure" by Rogue, and the reverse works too.

**Albums** get edition words removed ("Deluxe Edition", "Remastered",
"- Single" ...). A release is *single-like* when marked Single/EP or named
like the track.

## 2. Version detection

Keywords are only searched in **qualifiers** (brackets, dash tails) and the
**album name**, never in the bare title. So "Live Forever", "Acoustic Love"
and "Remix to Ignition" are not versions.

| Tag | Examples (case/accent-insensitive) | `MatchDifference` | Significant |
|---|---|---|---|
| remix | Remix, Kygo Remix, Remixed by X, RMX, VIP, Bootleg, Flip, Rework/Re-Work, Refix, Re-edit, *X* Edit, *X* Mix, Dub, Mash-up, 8D, a cappella, Reprise, Medley, Mixed | remix | yes |
| live | Live, Live at/in/from …, En Vivo, En Directo, Ao Vivo, Dal Vivo, In Concert, Unplugged, BBC/Peel Session, Recorded Live/At, Koncert/Konzert | live | yes |
| acoustic | Acoustic, Akustisk, Akustik, Akustisch, Acústico, Acoustique, Unplugged, Stripped, Piano Version | acoustic | yes |
| extended | Extended (Mix/Version/Edit), Club Mix/Version, 12" / 12 inch, Maxi, Long Version | extended | yes |
| radioEdit | Radio Edit/Version/Mix, Single Edit/Version/Mix, Short Version, bare "Edit" | radioEdit | no |
| instrumental | Instrumental(e/s), Inst., Off Vocal, No Vocals | instrumental | yes |
| karaoke | Karaoke, Backing Track, In the Style of, Sing-along, Minus One | karaoke | yes |
| cover | Cover, Tribute, Originally Performed by, Made Famous by | cover | yes |
| remaster | Remaster(ed/izado/isé ...), "2011 Remaster", Mono, Stereo, "2009 Mix" | remaster | **no** |
| sped | Sped Up, Speed Up, Nightcore, Fast Version | sped | yes |
| slowed | Slowed (+ Reverb), Reverb alone, Daycore, Chopped & Screwed | slowed | yes |
| demo | Demo, Rough Mix, Outtake, Alternate Take/Version, Take *n*, Work Tape | demo | yes |
| reRecorded | Taylor's Version, Re-Recorded, Rerecording, From The Vault | **cover** | yes |

Neutral qualifiers ("Original Mix", "Album Version", "Bonus Track", "From
'Movie'", "Deluxe") denote the original.

*Decision on re-recordings.* A re-recording ("Taylor's Version") is a
different recording of the same song by the same artist. It must never be
auto-matched to the original, but it is not a remix. The contract has no
dedicated `MatchDifference`, so it is reported as `cover` ("a different
performance") and is therefore significant. Two re-recordings match each
other normally.

*Albums.* "Live at …", "… Live", "MTV Unplugged", "(Taylor's Version)",
"(Karaoke Version)", "(Sped Up)", "(Remastered)" tag every track of the
album. Remix, extended and radio-edit tags are **ignored for albums**: remix
EPs ("Adventure (The Remixes)") usually include the original mix, and each
remix carries its own title tag.

*Comparing versions* (`VersionDetector.compare`). A tag on one side only is
a difference. Two remixes by clearly different remixers are a `remix`
difference, and so are two live recordings of different occasions ("Live at
Wembley" vs. "Live in Tokyo"). Two remasters with different years are a
`remaster` difference. An unknown detail on either side counts as equal.

## 3. Scoring (`WeightedTrackScorer`)

### Signals and weights (`ScoringWeights`)

| Signal | Weight | Sub-score |
|---|---|---|
| title | 0.40 | `Similarity.title` of the base titles (best reading pair) |
| primary artist | 0.28 | Main artist of each side found among the other side's artists (averaged), or the joined credit lines, whichever is higher |
| duration | 0.14 | Piecewise linear: ≤ 2 s → 1.0, 5 s → 0.85, 10 s → 0.45, 30 s → 0.05, beyond → 0 |
| featured artists | 0.05 | Share of non-main artists found on the other side, order-insensitive (1.0 if neither has any) |
| album | 0.05 | Title similarity of album keys; ≥ 0.7 when either side is a single/EP |
| explicit | 0.04 | 1 if equal, 0 if explicit vs. clean (the title hint "(Clean)" counts) |
| year | 0.04 | 1 same, 0.9 ±1, 0.6 ±3, 0.3 otherwise |

Signals that are **unknown on either side** (album, duration, year,
explicit, artist) are dropped and the remaining weights renormalized.
Missing metadata is neither rewarded nor penalized. *Version agreement is
not a weight*: it is a gate (see below).

`Similarity.title` = 0.45·Levenshtein + 0.35·fuzzy token Jaccard (typo
tolerant) + 0.20·Jaro-Winkler. Spacing-only differences score 1, word-order
swaps ≥ 0.95, and different numbers ("Part 2" vs. "Part 3") ×0.6.
`Similarity.name` uses compact/token-order equality, then max(0.5·JW +
0.5·Levenshtein, token Jaccard).

### Score

```
raw   = Σ weight·signal / Σ weight            (known signals only)
score = raw
ISRC equal            → score = 0.98 + 0.02·raw
significant version Δ → score ×= 0.6
|Δduration| > 30 s    → score ×= 0.75          (not when ISRC equal)
score is then capped to the ceiling of its final confidence band
```

The final cap keeps score and confidence consistent: a candidate capped at
`low` never shows 85 % or outranks a `medium` one.

### Confidence (`MatchThresholds`, all overridable via `ScoringConfig`)

| Band | Rule |
|---|---|
| exact | identical ISRC (case/whitespace/hyphen-insensitive) **and** no significant version difference |
| high | score ≥ **0.88** and title ≥ 0.85 and artist ≥ 0.80 and \|Δduration\| ≤ 10 s (or unknown); otherwise demoted to medium |
| medium | score ≥ **0.70** |
| low | score ≥ **0.45** |
| none | below 0.45 |

Caps, applied after banding:
* **significant version difference → at most `low`** (configurable via
  `ScoringConfig.significantVersionCap`). We chose `low` over "medium when
  everything else is identical". A remix is never the same recording, so it
  must not be bulk-accepted by "accept all ≥ medium". It still shows in
  review as a possible alternative. This also applies to identical ISRCs
  with conflicting version tags (metadata errors), which are flagged.
* \|Δduration\| > 30 s (both known) → at most `low`.
* title < 0.60 or artist < 0.50 → at most `low`. A title below **0.45**
  means a different song → `none`.
* no artist on either side → at most `medium`.
* Remaster-only and radio-edit-only differences are flagged and not capped.
  A radio edit's duration difference usually caps it anyway.

### Differences and breakdown

`differences` gets the version differences plus `explicitMismatch`,
`durationMismatch` (> 5 s), `albumMismatch` (album < 0.5),
`yearMismatch` (> 3 years), `artistMismatch` (< 0.70),
`featuredArtistMismatch` (< 0.5), `titleMismatch` (< 0.75) and
`previewOnly` (candidate playback is `preview`). `breakdown` holds the
sub-scores (`title`, `artist`, `featured`, `album`, `duration`, `explicit`,
`year`) for known signals, plus `version` (1 same, 0.9 remaster/radio-edit
only, 0 significant), `raw`, `isrc` (when both sides have one) and
`artistTitleSplit` (when an "Artist - Title" reading won). See `ScoreKeys`.

## 4. Matching (`SourceTrackMatcher`)

For each `findMatches(original, options)` (at most `maxConcurrentTracks` = 3
tracks in flight per matcher):

1. **Targets**: `options.targetSources` in order, or, if empty, every
   registered source in preference order **except explicit-only sources
   (YouTube)**. The original's own source and duplicates are skipped. Unknown
   or not-`isReady` sources are recorded as `notReady`.
2. **ISRC enrichment** (optional, failure-tolerant): if the original has no
   ISRC and some target supports `isrcLookup`, one "artist + title" search
   on an `isrcResolvers` source (Deezer) is scored, and the ISRC of a strong
   candidate (exact/high, no version difference) is used for the ISRC
   lookups. It never makes a candidate `exact`, because it comes from a
   metadata match. The search response is reused if Deezer is also a target.
3. Per target, **concurrently**:
   * `lookupByIsrc` first when an ISRC is known and the source supports it;
   * unless a strong candidate was found, up to 3 plain-text queries
     (`SearchQueryBuilder`): "artist title [version]", "title [version]",
     and for uploader-style sources (SoundCloud/YouTube/Audius) "title
     [version] artist". Significant version qualifiers ("Kygo Remix") are
     kept so a remix is searched as a remix. Remaster qualifiers, features
     and albums are left out. Quotes, colons and brackets are stripped, so
     provider syntax like Deezer's unreliable `artist:"…"` is never sent.
     Querying stops early once a strong candidate appears. Per-source caps:
     YouTube 1 query per track (search quota is 100 calls/day), Spotify
     page size 10.
   * Every result is scored; candidates are de-duplicated by `Track.id`.
4. **Ranking** (`MatchPolicy.rank`): score in 0.01 buckets, then
   `preferredSource`, then target order, then playback (full > external >
   unknown > preview > unavailable), then exact score and id. The top
   `maxCandidates` are kept.
5. **Decision** (`MatchPolicy.decide`):
   * `skipped`: `skipUnavailable` and no viable (≥ low) *playable*
     candidate (unavailable never counts; preview only with
     `allowPreviewOnly`);
   * `notFound`: no candidate ≥ low;
   * `autoAccepted`: `reviewMode == autoAcceptHigh` and some candidate
     (first in rank order) has confidence exact/high, score ≥
     `autoAcceptThreshold`, no significant version difference, is playable,
     and is not preview-only unless `allowPreviewOnly`;
   * otherwise `needsReview`.

**Failures.** Each source is isolated. Rate limits are retried
(`RateLimitPolicy`: `retryAfter` or 2 s × attempt, capped at 30 s, 2
retries). `MissingCredentialsException` / `AuthRequiredException` stop
further requests to that source. Network/API errors on one query are
tolerated if another query succeeds. A source with no successful request
ends up in `SourceMatchFailures.errors`. `TrackMatchResult.error` is set
when any source failed or nothing could be searched
(`isTotalFailure`), and `searchedSources` lists only the sources that
answered. `OperationCanceledException` propagates; cancellation is checked
between steps and while waiting for a concurrency slot or a retry delay.

## 5. Playlist import (`PlaylistImportServiceImpl`)

`fetching → matching → reviewing → saving → done`, or `failed` (fetch error)
and `canceled`.

* `start` validates the source (unknown → `ArgumentError`, no
  `playlistImport` → `UnsupportedSourceOperation`), returns the session id,
  then follows `nextCursor` pages (cap 10 000 tracks / 1 000 pages /
  repeated cursor) with rate-limit retries. `startWithTracks` imports a
  given list.
* Matching runs with 3 workers; duplicate tracks are matched once and share
  the result. A broken track becomes `notFound` with the error and does not
  fail the import. Progress is emitted at most every 100 ms; phase changes
  are emitted immediately. `watch` replays the current state first.
* Review: `accept` (also takes candidates from `searchAlternatives`),
  `reject`, `skip`, `acceptAllAtLeast(min)` (only `needsReview` results
  whose best candidate is ≥ min, not `none`, has no significant version
  difference and is playable).
* `searchAlternatives` searches one source or all session targets (no
  explicit-only sources by default) with the user's query, or "artist +
  title" when empty. It scores and ranks the results; failing sources are
  skipped, and if all fail the first error is thrown.
* `save` (only while reviewing; `ImportSaver`):
  1. upserts all originals and all accepted candidates;
  2. creates a local playlist (original name, or `playlistName`, plus
     description and artwork; `sourceId` and `sourcePlaylistId` set) holding
     the **original** tracks in order, including those without a match;
  3. links original ↔ accepted candidate. Confidence is the score, or
     **1.0 for user-confirmed or ISRC-exact links** (`TrackLink` contract);
     `userConfirmed` is set for user-accepted results.

  On failure the partial playlist is deleted, the session returns to
  `reviewing` with `error` set, and the error is rethrown so the user can
  retry.
* `ImportReport.fromState(state)`: counts per decision, matched per source,
  match rate, `truncated`, and `missing`: every entry without an accepted
  match (notFound, skipped, userRejected, unresolved needsReview) with
  position and error.

## 6. Tuning

* **Weights / thresholds**: pass a `ScoringConfig` to `WeightedTrackScorer`.
  Raise `highThreshold` or `highMinArtist` if wrong auto-accepts appear.
  Lower `mediumThreshold` if users see too many `notFound` that they then
  find manually. Keep `significantVersionCap` at `low` unless the UI shows
  version chips very prominently.
* **Duration tolerance**: `DurationBands` (2/5/10/30 s). Very long tracks
  (DJ mixes) tolerate more; consider scaling the bands by track length if
  that becomes a problem.
* **Keywords**: add language variants to the token/phrase lists in
  `VersionDetector` (single tokens, or phrases matched on whole words) and
  noise words to `TitleParser._noiseTokens`. Add a table row to
  `test/matching/version_detector_test.dart` for every new keyword.
* **Provider rules**: `MatchingSourceRules` (explicit-only sources, queries
  per track, page sizes, ISRC resolvers), overridable in `MatcherSettings` /
  `ImportSettings`.
* **Diagnostics**: enable `Logger('matching.scorer')` at `FINEST` for every
  score with its breakdown, `matching.matcher` at `FINE` for decisions, and
  `matching.import` / `matching.alternatives` for session events.
