# Spec: Library & database (`lib/library/**`, `test/library/**`)

Local-first library: everything works offline and without any account.

## Implement
1. **Database** `lib/library/db/`: `FermataDatabase.open(File dbFile)` using
   `sqflite` on Android and `sqflite_common_ffi` (`databaseFactoryFfi`) on
   desktop (and in tests: `sqfliteFfiInit()` + `databaseFactoryFfi`, or
   `inMemoryDatabasePath`). WAL mode, foreign keys on.
   Versioned migrations (`PRAGMA user_version`), each migration a separate
   function, tested upgrade from v1 → latest. Suggested schema:
   `tracks` (id PK, source_id, source_track_id, title, title_norm, artist,
   artist_norm, album, album_norm, album_artist, genre, year, duration_ms,
   isrc, local_path, file_size, file_mtime, file_hash, date_added,
   last_seen_at, json (full Track JSON), override_json), indexes on norm
   columns, source_id, isrc, local_path;
   `playlists`, `playlist_entries` (playlist_id, position, track_id,
   added_at; FK cascade), `favorites`, `play_history` (id, track_id,
   played_at, listened_ms, completed, origin), `track_links` (a, b,
   confidence, confirmed, created_at; store both directions or canonical
   order — your choice), `search_history`, `library_folders`.
   Accent/case-insensitive text search via normalized columns (write a small
   `foldForSearch()` helper; Danish æøå handled).
2. **Repositories** implementing every interface in
   `lib/core/contracts/library.dart`: `TrackRepository`,
   `PlaylistRepository` (incl. smart playlists — evaluate
   `SmartPlaylistRules` in SQL where possible, Dart otherwise; reorder;
   dedupe incl. linked duplicates; auto-download flag), `FavoritesRepository`
   (watch stream), `HistoryRepository` (stats: totals, top tracks/artists/
   genres, plays per day), `TrackLinkRepository` (transitive groups),
   `SearchHistoryRepository` (dedupe, most-recent-first, cap 50),
   `LibraryChangeBus`, `LibraryMaintenance` (delete all user data, JSON
   backup/restore incl. playlists, favorites, history, links, folders,
   settings are NOT included — settings have their own export; DB size).
   Track upserts keep `date_added`; `override_json` (user tag edits) wins over
   scanned values when reading.
3. **Local scanner** `lib/library/scanner/` — `LocalLibraryServiceImpl
   implements LocalLibraryService`. Constructor: `(FermataDatabase,
   TrackRepository, AppPaths, LibraryChangeBus, PlatformInfo)`.
   * Recursive enumeration of folders (skip hidden dirs, follow no symlink
     loops), formats: mp3, flac, m4a/mp4/aac, ogg/oga, opus, wav, aiff,
     wma (desktop).
   * Tag reading with `audio_metadata_reader` (read its API in the pub
     cache: title, artists, album, album artist, track/disc no, year, genre,
     duration, bitrate, sample rate, embedded pictures, lyrics if exposed,
     ReplayGain if exposed — otherwise parse REPLAYGAIN_* from Vorbis/ID3
     TXXX where the reader exposes raw frames). Fall back to filename parsing
     ("Artist - Title.ext", track numbers) when tags are missing.
   * Parse in a background isolate (`Isolate.run`/`compute`) in batches so
     the UI never janks; emit `ScanProgress` frequently.
   * Incremental: skip unchanged files (size+mtime); detect removed files
     (mark missing or remove per `removeFolder`); `full: true` re-reads all.
   * Embedded artwork → saved once per album hash into
     `AppPaths.artworkCacheDir` as JPEG/PNG; folder art (`cover.jpg`,
     `folder.jpg`, `front.png`) used when no embedded art. `Track.artworkUrl`
     becomes a `file://` URI.
   * Track id for local files: `local:<sha1(absolute normalized path)>`;
     `file_hash` = SHA-1 of the first 1 MB + size (fast duplicate detection).
   * `TrackAvailability.local()`; `format` filled.
   * Watching (desktop): `watcher` package `DirectoryWatcher`, debounce
     events (2 s) into incremental scans. Android: no watching; rescan on
     demand.
   * `editTags`: if `audio_metadata_reader` supports writing for the format
     (check its API — e.g. `updateMetadata`), write the file; otherwise store
     `override_json`. Report which formats are writable via
     `supportsFileTagWriting` and document precisely.
   * M3U/M3U8 import (relative + absolute paths, `#EXTINF`, URLs ignored
     with a warning) → matched to library tracks (by path; otherwise import
     the file) and export (extended, relative paths when inside the export
     dir, UTF-8).
4. **`PlaybackHistoryRecorder`** `lib/library/history_recorder.dart`:
   subscribes to `PlaybackController.events`; on `TrackEnded` records a
   `PlayRecord` when `privacy.recordHistory` and listened ≥ 30 s or ≥ 50 % of
   duration (or completed); upserts the played track so history works
   offline. Constructor `(PlaybackController, HistoryRepository,
   TrackRepository, SettingsStore)`; `start()`/`dispose()`.
5. **`LibraryModule.open(...)`** facade returning all repositories for
   bootstrap.
6. Tests (sqflite_common_ffi in-memory): CRUD for every repository,
   migrations, search folding (é/e, æ/ae, ø/o, å/aa/a), smart playlist rules,
   playlist reorder/dedupe, favorites stream, history stats, links
   transitivity, backup/restore round-trip, delete-all, scanner on a temp
   folder with real audio files generated via `ffmpeg` (tags set with
   `-metadata title=...`, embedded cover via `-i cover.png -map 0 -map 1
   -disposition:v attached_pic`), incremental rescan, missing-file
   detection, duplicate detection, M3U round-trip, history-recorder rules.
