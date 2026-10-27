# Discovery module

Privacy-first, on-device recommendations, lyrics and an opt-in update
check. Nothing about the listener is uploaded: providers only receive
ordinary catalog requests (search, related, trending, ...). Import
everything via `package:fermata/discovery/discovery.dart`.

## Public API

### `RecommendationServiceImpl implements RecommendationService`

```dart
RecommendationServiceImpl(
  SourceRegistry sources,
  HistoryRepository history,
  TrackRepository tracks,
  FavoritesRepository favorites,
  SettingsStore settings,
  AppPaths paths, {
  DateTime Function()? clock,          // tests
  DiscoveryTuning tuning = const DiscoveryTuning(),
  Duration sourceTimeout = const Duration(seconds: 15),
  int maxConcurrentRequests = 6,
  bool persistCache = true,            // JSON cache in <cacheDir>/discovery/
})
```

Contract methods: `homeShelves`, `dailyMixes`, `discoverWeekly`,
`similarTo`, `similarArtists`, `newReleases`, `genres`, `genreTracks`,
`moods` (8 `MoodCategory`s: Focus, Chill, Workout, Party, Sleep, Commute,
Happy, Melancholy, label keys `moodFocus` ...), `moodTracks`,
`smartQueueContinuation`. Extras: `refresh()` (drop caches, pull-to-refresh),
`clearCache()` (memory + disk, e.g. after "clear history"), `dispose()`
(flush the cache file; call on exit).

* **Shelves**: ids/title keys in `ShelfIds`/`ShelfTitles`
  (`shelf_ids.dart`). `Shelf.title` is a localization key; the parameter
  (artist, genre, top artists of a mix) travels in `Shelf.subtitle`.
  Order: continue listening, Daily Mix 1-4, Discover Weekly, because you
  liked X, trending, new releases, genre shelves, recently added local.
* **Personalization off** (`privacy.personalizedRecommendations == false`):
  only trending, new releases, genres and recently added are returned; the
  history and favorites repositories are not even read and cached
  personal shelves are forgotten.
* **Taste model** (`taste_profile.dart`): artist/genre affinity with
  exponential time decay (half-life 30 days), completed plays weigh 1,
  short incomplete listens are skips with a penalty, favorites add a
  constant. Everything is tunable through `DiscoveryTuning`.
* **Determinism**: Daily Mixes are seeded by the calendar day, Discover
  Weekly by ISO year + week (`util/seeded_random.dart`). Mixes are 25-50
  tracks, ~60 % familiar / 40 % discoveries, no artist more than 3x in a
  row.
* **SoundCloud silo**: a generated shelf/mix/queue is either SoundCloud
  (+ local) only or contains no SoundCloud track (`silo.dart`).
* **Playable first**: SoundCloud (when ready and
  `services.preferSoundCloudInDiscovery`), Audius, Local, Jamendo; Deezer
  is metadata/preview and its items are resolved to playable equivalents by
  a title+artist search where possible (UI labels the rest from
  `Track.availability`).
* **Caching**: per shelf, 6 h (Discover Weekly 24 h, degraded results 30
  min) in memory and in `<cacheDir>/discovery/recommendations.json`. With
  `performance.backgroundSync` off / data saver, expired entries are
  served stale until `refresh()` - the service never refreshes by itself.
  A failing source never breaks a shelf; with every source down you get
  local-only shelves. Only `OperationCanceledException` propagates.

### `LyricsServiceImpl implements LyricsService`

```dart
LyricsServiceImpl(
  FermataHttp http,
  SettingsStore settings,
  AppPaths paths, {
  LrclibClient? client,
  EmbeddedLyricsReader? embeddedReader,
  DateTime Function()? clock,
  bool diskCache = true,
  Duration searchDurationTolerance = const Duration(seconds: 3),
  int memoryEntries = 64,
})
```

Order for `lyricsFor(track, {cancel})`: (1) sidecar `Song.lrc` and the
embedded lyrics tag of local files (`audio_metadata_reader`: ID3 `USLT`,
Vorbis/FLAC `LYRICS`, MP4 `©lyr`, APE; ID3 `SYLT` is not exposed by the
package; LRC text inside a tag is detected and parsed as synced lyrics),
(2) disk cache, (3) LRCLIB `GET /api/get?track_name&artist_name&album_name&duration`
(LRCLIB only matches within +/-2 s), falling back to `GET /api/search`
(<= 20 results, picked by title/artist, closest duration within 3 s, then
synced, then album). Records flagged `instrumental` produce
`Lyrics(instrumental: true)`. `Lyrics.provider` is `LRCLIB` (also
`Embedded`, `LRC file`); `sourceUrl` is https://lrclib.net.

* `playback.lyricsEnabled == false` -> returns `null` without any network
  or file access.
* Disk cache: one JSON file per track id in `<cacheDir>/lyrics/`, 30 days
  (misses 3 days); `clearCache()` wipes memory and disk.
* `LrclibClient` serializes requests (250 ms gap), honours `Retry-After`
  (short waits retried once with jitter, longer waits suspend the client
  and throw `RateLimitedException`), identifies the app with the
  `FermataHttp` User-Agent (`Fermata/1.0 (+https://github.com/kjev0/dadasdasdasasdsad)`).
  Optional `appId` sends a public `Lrclib-App-Id`.
* Network/API failures are thrown as `FermataException`s (not cached);
  "no lyrics" is `null`.
* `LrcParser.parse(text)`: multiple timestamps per line, `mm:ss`,
  `mm:ss.x[x[x]]`, `mm:ss:xx`, `h:mm:ss.xx`, `[offset:+/-ms]`, metadata
  tags, enhanced `<mm:ss.xx>` word timings stripped, BOM/CRLF/CR.

### `UpdateChecker` (`update_checker.dart`)

```dart
UpdateChecker(
  FermataHttp http,
  SettingsStore settings,
  AppPaths paths, {
  PlatformInfo? platform,                         // default PlatformInfo.current()
  Future<String> Function()? currentVersion,      // default package_info_plus
  DateTime Function()? clock,
  Uri? endpoint,   // default https://api.github.com/repos/kjev0/dadasdasdasasdsad/releases/latest
  Duration minInterval = const Duration(days: 1),
})
```

* `checkIfDue({cancel})` -> `UpdateCheckResult?`: opt-in
  (`updates.checkForUpdates`), at most once per day (state, ETag and last
  result survive restarts in `<supportDir>/update_check.json`; conditional
  requests keep GitHub rate-limit usage near zero). Returns `null` when
  disabled, not due, or on network/API errors.
* `checkNow({cancel})` -> `UpdateCheckResult`: for an explicit "Check for
  updates" button (the click is the consent; skips the daily limit; throws
  typed errors).
* `lastResult()`: the stored result without network access.
* `UpdateCheckResult`: `status` (`upToDate` / `updateAvailable` /
  `noReleases`), `currentVersion`, `latestVersion`, `releaseNotesUrl`
  (GitHub release page), `releaseNotes` (Markdown), `publishedAt`,
  `assets` (name + URL + size, **only for the current platform**: APK on
  Android; `linux` archives, AppImage/deb/rpm/flatpak/snap on Linux;
  `windows` archives, exe/msi/msix on Windows; checksums omitted).
* Versions are compared with `SemVer` (`updates/semver.dart`; `v` prefix
  and `+build` ignored, pre-releases rank below releases).
* **No auto-download and no auto-install.** The UI links to the release
  page; the user installs the update.

## Bootstrap wiring

`AppServices` (frozen) has fields for `lyrics` and `recommendations`, but
none for the update checker: create it next to them in
`lib/app/bootstrap.dart` and hand it to whichever startup code/UI shows
the update banner (it has no Riverpod dependency).

```dart
import 'discovery/discovery.dart';

// after: platform, paths, settings, http, sources (SourceRegistry),
//        tracks, favorites, history (library repositories)
final lyrics = LyricsServiceImpl(http, settings, paths);
final recommendations = RecommendationServiceImpl(
  sources, history, tracks, favorites, settings, paths,
);
final updates = UpdateChecker(http, settings, paths, platform: platform);

// AppServices(..., lyrics: lyrics, recommendations: recommendations, ...)

// Startup (after the first frame; never blocks launch, never throws):
unawaited(updates.checkIfDue());   // no-op unless the user opted in
// On shutdown (AppLifecycleController): await recommendations.dispose();
// "Clear history"/"Delete all data": await recommendations.clearCache();
// Pull-to-refresh on Home:          await recommendations.refresh();
```

Init order: settings -> paths -> http -> library repositories -> source
registry -> `LyricsServiceImpl` / `RecommendationServiceImpl` /
`UpdateChecker` (no `init()` needed; all three are lazy).

## Platform notes

* Pure Dart/`dart:io` plus `package_info_plus` (version lookup) and
  `audio_metadata_reader` (tag parsing runs in a background isolate).
  Nothing is platform specific; `PlatformInfo` only selects release assets.
* Caches live in `AppPaths.cacheDir` (`discovery/`, `lyrics/`); update
  state in `AppPaths.supportDir`.

## Tests

`flutter test test/discovery` (fixtures in `test/discovery/fixtures/` are
real LRCLIB responses recorded with curl; `embedded_lyrics.mp3` is a tiny
generated MP3 with an ID3v2.3 `USLT` frame).

## Known limitations

* ID3 `SYLT` (binary synced lyrics) is not exposed by
  `audio_metadata_reader`; synced lyrics from tags work only as LRC text.
* Deezer-sourced items that cannot be resolved to a playable source stay
  preview-only (labelled by the UI from `Track.availability`).
* The simple title+artist resolver is not the full matcher in `lib/matching`.
* Windows/Android paths of `UpdateChecker` asset selection are covered by
  unit tests only (no installer is produced by this module).
