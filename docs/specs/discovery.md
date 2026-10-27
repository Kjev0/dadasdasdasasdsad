# Spec: Discovery, recommendations, lyrics, updates (`lib/discovery/**`, `test/discovery/**`)

Privacy-first: computed on device. No analytics, no hidden tracking.

## Implement
1. **`RecommendationServiceImpl implements RecommendationService`**
   constructor `(SourceRegistry sources, HistoryRepository history,
   TrackRepository tracks, FavoritesRepository favorites, SettingsStore
   settings, AppPaths paths)`.
   * Candidate pools: listening history (artist/genre affinity with time
     decay, skip-penalty for short listens), favorites, provider
     `relatedTracks`, `artistTopTracks`, `trending`, `newReleases`, `genres`.
     Prefer sources that can actually play in-app (SoundCloud first when
     ready and `services.preferSoundCloudInDiscovery`, then Audius, Local,
     Jamendo); Deezer is used for metadata/charts/new releases (previews)
     — when a Deezer item is shown, it is labeled preview/external by the
     UI from its availability, and `similarTo`/mixes should try to resolve
     playable equivalents by searching playable sources (simple
     title+artist search, best result by a quick check; the full matcher is
     not required here).
   * `homeShelves`: continue listening (recently played), Daily Mix 1–4,
     Discover Weekly, trending (in-app playable source first), new releases,
     recently added local tracks, "because you liked <artist>". When
     `privacy.personalizedRecommendations` is false → only non-personal
     shelves (trending, new releases, genres, recently added).
   * `dailyMixes`: cluster history by artist/genre affinity (deterministic
     per day: seed with the date), 25–50 tracks each, mix known favorites
     with related discoveries (~60/40), no artist more than 3× in a row.
   * `discoverWeekly`: seeded by ISO year+week; tracks NOT in the user's
     library/history from related artists/tracks of top artists.
   * `similarTo`, `similarArtists`, `genreTracks`, moods (Focus, Chill,
     Workout, Party, Sleep, Commute, Happy, Melancholy) as `MoodCategory` with
     search seeds per source + genre tags; `moodTracks`.
   * `smartQueueContinuation(recent)`: tracks related to the last few,
     excluding the recent ones, playable in-app only.
   * Caching: memoize per shelf with TTL (e.g. 6 h, 24 h for weekly) in
     memory + a JSON cache file in `AppPaths.cacheDir`; respect
     `performance.backgroundSync`/data saver (no background refresh; refresh
     on demand only). Cancellation everywhere. Graceful when every source
     fails or nothing is connected (returns local-only shelves, never throws
     for the whole home page).
2. **`LyricsServiceImpl implements LyricsService`** using LRCLIB
   (`https://lrclib.net/api/get` with track_name/artist_name/album_name/
   duration; fallback `/api/search`), a descriptive User-Agent
   (`FermataHttp` default UA is fine), LRC parsing (multiple timestamps per
   line, offsets `[offset:]`, metadata tags), instrumental flag, embedded
   lyrics for local files when `audio_metadata_reader` exposes them (check),
   on-disk cache (JSON per track id, 30 days), honours
   `playback.lyricsEnabled` (no network when off). Attribution "LRCLIB".
3. **`UpdateChecker`** (`lib/discovery/update_checker.dart`): opt-in
   (`updates.checkForUpdates`); queries
   `https://api.github.com/repos/kjev0/dadasdasdasasdsad/releases/latest`
   at most once per day; compares semver with `package_info_plus` version;
   returns release notes URL + asset names for the current platform. No
   auto-install (documented).
4. Tests: affinity math, determinism of daily mixes for a given date,
   discover-weekly excludes library tracks, personalization off → no
   personal shelves, source failure isolation, smart-queue exclusion, LRC
   parser edge cases, LRCLIB request building + duration tolerance with
   MockClient (fixtures recorded from the real public API with curl are
   fine), lyrics disabled → no requests, update version comparison.
