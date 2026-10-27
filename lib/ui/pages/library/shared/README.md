# UI content pages (ui-pages module)

Home, Search, Explore, Library, Playlists (+ detail), Artist, Album,
Downloads, Liked songs and History. Built on the ui-foundation design system
and shared widgets (`lib/ui/design/README.md`); every service is reached
through `lib/app/providers.dart`. Strings live in
`lib/l10n/fragments/pages_en.arb` / `pages_da.arb`.

## Pages (routes are built with `AppRoutes`)

| Route | Class (constructor) | Main pieces |
|---|---|---|
| `/home` | `HomePage()` | greeting by time of day (`greetingFor`, `pageClockProvider`), `homeShelvesProvider` (drops empty shelves, refetches on history/tracks/favorites/sources/personalization), `MixesRow` (Daily Mixes + Discover Weekly), `TrackShelfRow`, in-page `TrackCollectionView`, `FirstRunPanel` (add folder / connect / explore) |
| `/search` | `SearchPage()` | `searchControllerProvider` (`SearchPageController`: 300 ms debounce, `LatestOnly` cancellation, per-source streaming), `GroupedResults` (top result, tracks, artists, albums, playlists; `services.providerOrder`, SoundCloud first by default), source chips, per-source notices, `recentSearchesProvider` / `recordSearch` (respects `privacy.saveSearchHistory`), `searchSuggestionsProvider`, `ShareLink.parse` + `ShareLinkCard` (open / import & match / play) |
| `/explore` | `ExplorePage()` | moods (`RecommendationService.moods`), genres, trending, new releases; in-page genre / mood detail with preview / external labels |
| `/library?tab=` | `LibraryPage({String? tab})` | tabs `tracks`, `albums`, `artists`, `folders` (`downloaded` = Tracks with the Downloaded filter). Tracks: `libraryFiltersProvider` (`LibraryFilters` → `TrackQuery`), sort, filter sheet, quick filters, import a file, `LibraryTrackList`, `TrackDetailsSheet`, `TagEditorDialog`. Folders: `libraryScanProvider` (`LibraryScanController`), `addMusicFolder`, watch toggle, rescan, missing files / duplicates sheets |
| `/playlists` | `PlaylistsPage()` | grid / list, filters, `PlaylistActions` (create, edit details, delete, artwork, M3U import / export, auto-download, dedupe, quick play), `SmartRuleEditor` |
| `/playlists/:id` | `PlaylistDetailPage({required String playlistId})` | library playlists (`localPlaylistProvider`): reorder (drag handles; compact "Reorder" mode), bulk select, links / "Find alternatives" (`AlternativesSheet`); remote `<sourceId>:<id or URL>` (`remotePlaylistProvider`): paging, "Save to library", "Import & match" |
| `/artist/:sourceId/:artistId` | `ArtistPage({required String sourceId, required String artistId})` | `artistPageProvider`; `local` uses the artist name |
| `/album/:sourceId/:albumId` | `AlbumPage({required String sourceId, required String albumId})` | `albumPageProvider`; disc grouping; `local` matches the album title |
| `/downloads` | `DownloadsPage()` | queue / finished lists, per-task and bulk actions, filters, `StorageSummaryCard`, Wi-Fi-only / mobile-data states |
| `/favorites` | `FavoritesPage()` | `favoriteTracksProvider`, sort / text / source filters, play, download |
| `/history` | `HistoryPage()` | `historyProvider` grouped by day, load more, clear, `ListeningStatsView` + `PlaysPerDayChart` (CustomPaint) |

## Shared helpers (`lib/ui/pages/library/shared/`)

* `page_layout.dart` — `PageHeader`, `CollectionHeader`, `ArtworkMosaic`,
  `PlayShuffleButtons`, `InlineNotice`, `SkeletonShelf`, `SkeletonHeader`,
  `ClippedSkeleton`, `AsyncBody`, `pageInsets`, `roomyRows`, `menuRow`.
* `track_helpers.dart` — `playCollection` (queues playable tracks, or a
  custom `canPlay`), `siloSafeContext` / `SiloPartition` (SoundCloud never
  shares a queue with other services), `orderByPreference`,
  `sortAlbumTracks`.
* `provider_notices.dart` — `TrackListNotices` ("30-second preview ·
  Deezer", "Plays on Spotify").
* `track_actions_row.dart` — `CollectionDownloadButton` (only when a
  provider permits downloads; never SoundCloud/Deezer/Spotify/YouTube).
* `import_helpers.dart` — `importTargets`, `matchOptionsFor`,
  `startPlaylistImport`.
* `labels.dart` — shelf / mood titles, byte sizes, durations, day labels.
* `revisions.dart` — `watchLibrary`, `watchSources`, `providerCancelToken`.
* `page_services.dart` — overridable platform services:
  * `pageFilePickerProvider` → `PageFilePicker` (default `SystemFilePicker`
    on `file_picker`: directory, audio file, image, M3U, export),
  * `playlistArtworkStoreProvider` → `PlaylistArtworkStore` (default copies
    into `<support>/playlist_artwork/`),
  * `pageClockProvider` (greeting, day grouping, statistics).

## Bootstrap wiring

Nothing to wire: the pages only read `lib/app/providers.dart`. The three
providers above have working defaults; tests override them.

## Platform notes

* Folder picking: Linux uses the XDG portal, Windows the native dialog,
  Android SAF; Android asks for the audio library permission first
  (`AndroidSystemHelper`). The watch toggle is desktop only (Android rescans
  on start).
* M3U export writes to a temp file and hands the bytes to the save dialog
  (works with Android content URIs); on desktop the file is then re-exported
  in place so paths can be relative to the chosen folder.
* Below 600 dp, track rows drop the source chip and trailing buttons
  (`TrackTile` badges don't shrink): Library details move to the selection
  bar, unplayable playlist rows open "Find alternatives" on tap, and
  playlists reorder in a separate mode.

## Known limitations

* The smart-rule preview evaluates rules in Dart over the library (history,
  favorites, downloads); "date added" isn't on `Track`, so such previews are
  marked approximate. The saved playlist is evaluated by the library (SQL).
* Remote artist "releases" are derived from the artist's top tracks and
  album headers from the album's tracks (no `getAlbum` / `artistAlbums` in
  `MusicSource`).
* The Folders tab shows progress only for scans it started.
* The mobile-data confirmation and network wait reason use optional extras
  of the download manager implementation (not in the contract).
