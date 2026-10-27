# Library & database (`lib/library`)

Local-first library: everything works offline and without any account.
SQLite via `sqflite` (Android) / `sqflite_common_ffi` (Linux, Windows, tests).

## Public API

| Class | Implements | Constructor |
|---|---|---|
| `LibraryModule` | facade | `static Future<LibraryModule> open({required AppPaths paths, required PlatformInfo platform, SettingsStore? settings, File? databaseFile, bool inMemory = false, DatabaseFactory? databaseFactory, Duration watchDebounce = 2 s, DirectoryWatcherFactory? watcherFactory})`, `static LibraryModule fromDatabase(FermataDatabase db, {...same named args})` |
| `FermataDatabase` | – | `static Future<FermataDatabase> open(File dbFile, {DatabaseFactory? factory, int? targetVersion})`, `openInMemory({...})` |
| `LibraryChangeBusImpl` | `LibraryChangeBus` | `LibraryChangeBusImpl()`; `notify(Set<LibraryTopic>)` (coalesced per microtask) |
| `SqlTrackRepository` | `TrackRepository` | `(FermataDatabase, LibraryChangeBus)` + `getTrackByPath`, `overrideOf`, `setOverride` |
| `SqlPlaylistRepository` | `PlaylistRepository` | `(FermataDatabase, LibraryChangeBus, {DateTime Function()? clock})` + `evaluateSmart`, `setAutoDownload`, `rulesOf` |
| `SqlFavoritesRepository` | `FavoritesRepository` | `(FermataDatabase, LibraryChangeBus)` |
| `SqlHistoryRepository` | `HistoryRepository` | `(FermataDatabase, LibraryChangeBus, {int topLimit = 10})` |
| `SqlTrackLinkRepository` | `TrackLinkRepository` | `(FermataDatabase, LibraryChangeBus)` + `groupKeys` |
| `SqlSearchHistoryRepository` | `SearchHistoryRepository` | `(FermataDatabase, LibraryChangeBus, {SettingsStore? settings, int maxEntries = 50})` |
| `SqlLibraryMaintenance` | `LibraryMaintenance` | `(FermataDatabase, LibraryChangeBus)` |
| `DownloadedTracksIndex` | – | `(FermataDatabase, LibraryChangeBus)`; `attach(Stream<Set<String>>)` |
| `LocalLibraryServiceImpl` | `LocalLibraryService` | `(FermataDatabase, TrackRepository, AppPaths, LibraryChangeBus, PlatformInfo, {PlaylistRepository? playlists, Duration watchDebounce = 2 s, int batchSize = 32, DirectoryWatcherFactory? watcherFactory})` |
| `PlaybackHistoryRecorder` | – | `(PlaybackController, HistoryRepository, TrackRepository, SettingsStore, {Duration minListened = 30 s, double minFraction = 0.5})`; `start()`, `dispose()` |
| `foldForSearch(String?)` | – | accent/case folding used for every `*_norm` column |

## Bootstrap wiring (init order)

```dart
// after paths + settings
final library = await LibraryModule.open(paths: paths, platform: platform, settings: settings);

// ... credentials, sources, then downloads (they need library.tracks etc.):
library.attachDownloads(downloads.watchDownloadedIds());

// ... after the playback controller exists:
final historyRecorder = library.createHistoryRecorder(playback, settings)..start();

// platform integrations
await library.localLibrary.startWatching();          // desktop only; no-op on Android
unawaited(library.localLibrary.scan().drain<void>()); // incremental scan at start (and on Android resume)

AppServices(
  libraryChanges: library.changes,
  tracks: library.tracks,
  playlists: library.playlists,
  favorites: library.favorites,
  history: library.history,
  links: library.links,
  searchHistory: library.searchHistory,
  localLibrary: library.localLibrary,
  maintenance: library.maintenance,
  // ...
);

// on Quit
await historyRecorder.dispose();
await library.close();
```

## Schema & migrations

`PRAGMA user_version` holds the schema version; `db/migrations.dart` has one
function per step (`migrateV1`, `migrateV2`, `migrateV3`), each run in its own
transaction. SQL is restricted to what Android 7's SQLite 3.9 understands
(no UPSERT / window functions / column renames). A database written by a newer
app version is refused (`StorageException('database_too_new')`).

* v1 `tracks` (source JSON in `json`, user edits in `override_json`,
  denormalized + folded columns for search/sort, file size/mtime/hash),
  `track_artists`, `playlists`, `playlist_entries` (FK cascade),
  `favorites`, `play_history`, `search_history`, `library_folders`
* v2 `track_links` (one row per pair, canonical order `a < b`)
* v3 `tracks.missing_since`, `downloaded_tracks`
* v4 `track_moves` (old id → new id of moved local files; redirects stale `Track` objects)

## Behavior notes

* **Search folding**: lower-case, diacritics removed, `æ→ae`, `ø→o`,
  `å→a`, runs of `a` collapse (`Århus` = `Aarhus` = `Arhus`), apostrophes
  dropped, punctuation → space. Every query token must match.
* **Overrides**: `override_json` (partial Track JSON, `null` clears a field)
  wins over scanned/provider values on every read and in all denormalized
  columns. Upserts never overwrite overrides or `date_added`. Local rows owned
  by the scanner are not overwritten by `upsertTracks`/favorites/history
  upserts — a stale `Track` from the queue cannot undo a rescan.
* **Smart playlists**: compiled to SQL (`repositories/smart_rules.dart`);
  combinations SQL cannot express (string operators on numeric fields) are
  evaluated in Dart. Date rules take a number of days; `notInLastDays` on
  `lastPlayed` includes never-played tracks.
* **Deduplicate** keeps the first entry per track id *and* per transitive link
  group (e.g. a Spotify import and its SoundCloud match).
* **Links** are symmetric and transitive; transitive confidence is the best
  path product; a user-confirmed link is never downgraded by a later match.
* **Search history**: case-insensitive dedupe, most recent first, capped at
  50, disabled when `privacy.saveSearchHistory` is off (if `settings` given).
* **Backup** (`format: fermata.library.backup`, `version: 1`): playlists +
  entries, favorites, history, links, folders, search history, referenced
  tracks with overrides. Settings are not included. Import is one
  transaction; `merge: false` clears user tables first; merging the same
  backup twice is idempotent.
* **deleteAllUserData** keeps local tracks (and their overrides/folders) and
  remote tracks that have a completed download.

## Local scanner

* Folders are enumerated in a background isolate: hidden entries and
  directories with `.nomedia` are skipped; symlinks are followed, each real
  directory is visited once (no loops).
* Formats: mp3, flac, m4a/mp4/aac, ogg/oga, opus, wav, aiff/aif/aifc
  everywhere; wma on desktop only. Tags via `audio_metadata_reader`
  (format-specific models): title, artists (multi-value split on NUL/`;`,
  never on `/`), album, album artist (not available for MP4), year, genre,
  track/disc no., duration, sample rate, ISRC, ReplayGain (Vorbis comments,
  ID3 `TXXX:REPLAYGAIN_*`, Opus `R128_*`), embedded cover. RIFF/AIFF text
  that is UTF-8 read as Latin-1 is repaired. Bitrate = average from size and
  duration. Missing tags fall back to the file name (`Artist - Title`,
  `01 - Title`, `1-05 Title`).
* Parsing runs in batches of 32 files per `Isolate.run`; progress is emitted
  after enumeration and every batch. Scans are queued (one at a time);
  cancelling the stream stops after the current batch.
* Incremental: unchanged size + mtime → skipped; `full: true` re-reads all.
  Moved/renamed files (same content hash) keep playlists, favorites,
  history, links and overrides. Missing files: unreferenced tracks are
  removed, referenced ones are flagged (`AvailabilityReason.fileMissing`)
  and come back when the file reappears. An unavailable/unmounted folder is
  never treated as "all files deleted".
* Ids: `local:<sha1(canonical absolute path)>`; `file_hash` = SHA-1 of the
  first MiB + size (duplicate detection `same_hash`).
* Artwork: embedded images saved once per album (`local_<sha1(album artist,
  album)>.png|jpg`) in `AppPaths.artworkCacheDir`; otherwise `cover.*`,
  `folder.*`, `front.*`, `albumart.*` next to the file (case-insensitive).
  If the cache is cleared, the next incremental scan restores it.
* Watching: desktop only (`watcher` `DirectoryWatcher`), events debounced 2 s
  into an incremental scan of that folder. Android: no watching — rescan on
  start/resume.

### Tag writing (`editTags`, `supportsFileTagWriting`)

`supportsFileTagWriting` is `true` on desktop, `false` on Android (scoped
storage does not reliably allow rewriting other apps' files; edits become
library overrides there).

`audio_metadata_reader` 1.8.1 rebuilds the whole tag and drops frames it does
not model (ID3 `TXXX`/`COMM`/`USLT`, FLAC `REPLAYGAIN_*`/`DISCNUMBER`/
unknown comments, MP4 `aART`/freeform atoms; RIFF only encodes ASCII). So a
write is attempted only for these formats and fields, and only kept when it
is verified lossless (file backed up, written, re-read, compared with the
original tag model; otherwise restored byte-for-byte):

| Extension | Fields written to the file |
|---|---|
| `.mp3` | title, artists (TPE1), album, album artist (TPE2), year, genre, track no., disc no., ISRC |
| `.flac` | title, artists, album, album artist, year, genre, track no., ISRC |
| `.wav` | title, artists, album, year, genre, track no. (ASCII only) |
| others (m4a/mp4, ogg, opus, aiff, wma) | none — override only |

Fields the file cannot hold (and every edit that would lose data) are stored
as `override_json`; `editTags` returns `true` only when the file was written.
`LocalLibraryServiceImpl.canWriteTags(track)` tells the UI in advance.

### M3U

Import: UTF-8 (BOM ok) or Latin-1, `#EXTINF`, relative (also `\`-separated)
and absolute paths, `file://` URIs; http(s) and other URLs are ignored with a
warning. Entries are matched to library tracks by path, otherwise the file is
imported (`importFile`); missing files are skipped. The caller creates the
playlist from the returned tracks. Export: extended M3U (`#EXTM3U`,
`#PLAYLIST`, `#EXTINF`), UTF-8, paths relative when inside the export
directory, CRLF on Windows; tracks without a local file are skipped.

## Known limitations

* `query()`/`albums()`/`artists()` return every known track (including remote
  tracks that were only played) — the contract has no "in library" flag.
* Embedded lyrics are not stored (no field on `Track`); read them from
  `Track.localPath` with `audio_metadata_reader` (`readMetadata(f).lyrics`).
* Album artist of MP4 files and ReplayGain of MP4/WMA are not exposed by the
  tag reader; WMA has no tag reader at all (file-name fallback only).
