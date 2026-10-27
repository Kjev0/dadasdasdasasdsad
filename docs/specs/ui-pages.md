# Spec: UI content pages (`lib/ui/pages/{home,search,explore,library,playlists,artist,album,downloads,favorites,history}/**`, `lib/l10n/fragments/pages_*.arb`, `test/ui/pages/**`)

Built on the ui-foundation module (design system, shared widgets, fake kit in
`test/ui/fakes/`, router). Read `lib/ui/design/README.md` first and reuse its
components — do not create parallel versions; if something is missing, add
it inside your own page folders and report it. Replace the `// STUB(ui-pages)`
files with real pages (keep the class names/constructors).

Every page: loading skeletons, empty states with a helpful action, error
states with retry (mapped from `FermataException.code`), works offline for
local data, responsive (compact/medium/expanded), keyboard navigable,
semantic labels on icon buttons, localized strings (EN + natural DA).
Data via `lib/app/providers.dart` only; refetch on `libraryRevisionProvider`/
`sourcesRevisionProvider`; cancel obsolete searches (`LatestOnly`).

## Pages
* **Home**: greeting by time of day; shelves from
  `RecommendationService.homeShelves()` (continue listening, daily mixes,
  discover weekly, trending, new releases, recently added); first-run empty
  state (add a music folder / connect a service / explore) when everything is
  empty; quick-play on cards.
* **Search**: debounced (300 ms) search-as-you-type over
  `SourceRegistry.searchAll` with results streaming in per source; results
  grouped (Top result, Tracks, Artists, Albums, Playlists) and ordered by
  provider preference with **SoundCloud first** by default (setting
  `services.providerOrder`); source filter chips; recent searches (from
  `SearchHistoryRepository`, respects `privacy.saveSearchHistory`, clear
  button); suggestions (recent + library matches as you type); per-source
  error/“not connected”/“credentials missing” inline notices with a link to
  Settings → Connected services; paste a share URL (SoundCloud/Spotify/
  Deezer/YouTube/Audius) → offers to open/import that playlist or track.
* **Explore**: genres (from `RecommendationService.genres`), moods
  (`moods`), trending, new releases; genre/mood detail lists playable
  tracks; clearly labels preview-only / external tracks.
* **Library**: tabs Tracks / Albums / Artists / Folders; sort (title,
  artist, album, year, duration, date added, play count) and filters
  (source, downloaded only, local files only, offline-available, favorites,
  genre, year range, duration); a "Downloaded" quick filter; Folders tab
  manages `LocalLibraryService` folders (add via `file_picker` directory
  picker, remove, rescan with progress, watch toggle) and shows missing
  files and duplicates tools; import a single audio file; tag editor dialog
  for local tracks (`editTags`; indicate when only a non-destructive
  override is stored); format/bitrate/sample-rate details sheet.
* **Playlists**: grid/list of local, smart and imported playlists; create
  (name/description), rename, delete (confirm), artwork (pick image →
  copy into support dir → `updatePlaylist`), smart playlist rule editor
  (field/operator/value rows, match all/any, limit, sort; live preview count),
  import (→ `/import`), import/export M3U/M3U8 (`file_picker`), auto-download
  toggle (explain permitted-only), dedupe action with result count.
* **Playlist detail** (local id or remote `<source>:<id>`): header with
  artwork mosaic, stats, play/shuffle, reorder (drag), bulk select (remove,
  add to queue, add to other playlist, download eligible), per-track
  availability, unavailable tracks greyed with reason, "find alternatives"
  for unplayable imported tracks (→ matcher via `PlaylistImportService.searchAlternatives`
  or `TrackMatcher.findMatches` and linking via `TrackLinkRepository`). Remote
  playlists: "Save to library"/"Import & match".
* **Artist** (`sourceId` + `artistId`; `local` uses the name): header,
  top tracks, albums/releases, related artists, "open on provider" link with
  attribution.
* **Album**: track list with disc grouping, total duration, play/shuffle,
  download-eligible action.
* **Downloads**: active queue with progress, speed, ETA, status chips;
  pause/resume/retry/cancel per task and all; completed list; filters;
  storage usage summary (downloads, artwork cache, database, limit) with
  link to Settings → Storage; Wi-Fi-only waiting state explained; mobile
  data confirmation dialog when `needsMobileDataConfirmation`.
* **Favorites**: liked tracks, sort/filter, play all, download eligible.
* **History**: recently played (grouped by day), clear history (confirm),
  listening statistics (optional section: totals, top tracks/artists/genres,
  plays per day as a small bar chart — draw with CustomPaint; colors from
  tokens), respects `privacy.recordHistory` (shows a notice when off).

## Tests (`test/ui/pages/`)
Widget tests with the fake kit for each page: loading → data → empty →
error states; search streaming merge order (SoundCloud first) and
cancellation; recent searches; library filters; playlist CRUD, reorder,
smart rule editor; downloads actions; history clear; responsive layouts at
360×640 and 1440×900 without overflow errors.
