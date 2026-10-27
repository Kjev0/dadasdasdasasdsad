# Spec: Downloads, offline & storage (`lib/downloads/**`, `test/downloads/**`)

Only legally downloadable content is ever stored: user-owned files are
already local; remote tracks only when `MusicSource.authorizeDownload`
returns a `DownloadAuthorization`. Stream URLs are never saved as downloads.

## Implement `DownloadManagerImpl implements DownloadManager`
Constructor (adapt names if needed, keep it injectable):
`DownloadManagerImpl({required SourceRegistry sources, required TrackRepository tracks, required PlaylistRepository playlists, required HistoryRepository history, required SettingsStore settings, required AppPaths paths, required FermataHttp http, required NetworkStatus network, SystemNotifier? notifier})`.

1. **Eligibility** (`checkEligibility`) → the four categories: local file →
   `alreadyLocal`; completed → `alreadyDownloaded`; `availability.offline ==
   downloadable` and source supports `download` → `allowed` (final check
   happens in `authorizeDownload` at download time); `streamOnly` →
   `streamOnly`; else `unavailable` with reason. `enqueue` throws
   `DownloadNotPermittedException` when not allowed.
2. **Queue & transfers**: persistent task list (JSON index under
   `<support>/downloads/index.json` with atomic writes, or a small SQLite DB
   of your own — not the library DB), restored on `init()` (interrupted
   `downloading` → `queued`). `maxConcurrent` from settings. Resumable via
   HTTP `Range` (`If-Range` with ETag/Last-Modified when present) into
   `AppPaths.tempDownloadDir`; fall back to restart when the server ignores
   ranges. Pause/resume/cancel/retry (exponential backoff, max 5 attempts,
   respect `RateLimitedException.retryAfter`). Progress + speed (EMA, emitted
   ≤ 4 Hz). Cancellation via `CancelToken`/aborting the stream.
   Re-authorize (`authorizeDownload`) on every (re)start because download URLs
   may be signed/expiring. Use `FermataHttp.raw` (streamed `http.Request`)
   for the body stream.
3. **Network policy**: `NetworkStatus` interface (implement with
   `connectivity_plus`; tests use a fake): `wifiOnly` → wait
   (`waitingForNetwork`) on cellular/none; resume automatically when Wi-Fi
   returns; `isMetered` exposed for the stream resolver. Expose
   `bool get needsMobileDataConfirmation` + `confirmMobileDataForSession()` so
   the UI can warn before large downloads on mobile data
   (`warnOnMobileData`).
4. **Integrity**: verify size (Content-Length / expectedBytes) and SHA-256
   (expectedSha256 if provided; always compute and store our own), sniff
   the file header to make sure it is audio (ID3/MP3 frame sync, fLaC, OggS,
   ftyp (M4A), RIFF/WAVE, Opus) and not an HTML error page; mark failed with
   a clear error code otherwise. `verifyAll()` re-checks completed files.
5. **Files**: final path `<downloadDir>/<Artist>/<Album or Singles>/<NN - >Title.<ext>`
   with sanitized names (Windows-reserved names & characters, max lengths);
   extension from authorization / Content-Type / sniffing. Duplicate
   detection: same track id → reuse; same SHA-256 as an existing download →
   keep one file. Store artwork for downloaded tracks in the artwork cache
   (download `artworkUrl` once) and keep metadata in the library (upsert the
   track with updated availability).
6. **Storage**: `storageUsage()` (download dir size, artwork cache size,
   DB size via callback or file size, free space if obtainable — on Linux
   `df`-free approach: `statvfs` via FFI is optional; acceptable to return
   null), `enforceStorageLimit()` (LRU by last played from
   `HistoryRepository`, else completedAt; never deletes user-owned local
   files), automatic enforcement after each completed download when
   `storage.autoCleanup`, `clearArtworkCache()`,
   `changeDownloadDirectory(newPath)` (move files, update index, handle
   cross-device move by copy+delete).
7. **Artwork cache for the UI**: provide `FermataArtworkCache` — a
   `CacheManager` for `cached_network_image` rooted in
   `AppPaths.artworkCacheDir` with size limits from `storage.artworkCacheMb`
   (you may `flutter pub add flutter_cache_manager` — report it). Expose it so
   the UI can pass `cacheManager:`.
8. **Auto-download playlists**: `syncAutoDownloads()` enqueues permitted,
   missing tracks of `PlaylistRepository.autoDownloadPlaylists()`; also run on
   `init()` and periodically when `performance.backgroundSync` (interval
   `syncIntervalMinutes`) — but never on metered networks when `wifiOnly`.
9. Notifications: when `downloads.notifyOnComplete`/`notifications.downloads`
   and a notifier is supported, notify once per batch ("12 tracks
   downloaded").
10. Tests with a local `HttpServer` (dart:io) serving real bytes (support
    Range, ETag, slow streaming, mid-transfer disconnect, wrong content type,
    404/429/500): enqueue → complete → verify; pause/resume continues from
    the byte offset; cancel deletes partial file; retry/backoff; wifi-only
    waiting + resume; integrity failure on HTML body; duplicate detection;
    storage limit LRU; directory change; eligibility for the four
    categories; restart restoration; auto-download sync.

## Compliance addendum (binding — see docs/COMPLIANCE.md)
* Eligibility must consult `SourcePolicies.of(track.sourceId)`:
  SoundCloud → never downloadable (stream-only) even if the API says
  `downloadable`; Audius/Jamendo → only user-initiated single downloads of
  tracks the uploader marked downloadable; Deezer/Spotify/YouTube → never.
* `syncAutoDownloads()` and any automatic enqueue only for sources with
  `automaticDownloads` (no remote provider today) — tracks skipped this way
  are reported (count + reason) so the UI can explain it.
* `enqueue` takes the user-initiated path; `enqueueAll` from a playlist is
  allowed (user tapped "Download" on the playlist) but only for sources with
  `userInitiatedDownloads` and per-track downloadable rights.
