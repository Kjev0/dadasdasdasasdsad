# Downloads, offline & storage (`lib/downloads`)

Only legally downloadable content is stored. User-owned files are already
local; remote tracks are downloaded only when
`MusicSource.authorizeDownload` returns a `DownloadAuthorization`, and that
call is repeated before **every** (re)start because download URLs can be
signed and expire. Stream URLs are never saved as downloads.

## Public API

Import `package:fermata/downloads/downloads.dart`.

| Class | Purpose |
|---|---|
| `DownloadManagerImpl implements DownloadManager` | Queue, resumable transfers, integrity, storage limits, auto-download sync, notifications. |
| `NetworkStatus` (abstract), `NetworkState`, `NetworkKind` | Connectivity as seen by downloads and the stream resolver. |
| `ConnectivityNetworkStatus extends NetworkStatus` | `connectivity_plus` implementation. |
| `DownloadNetworkPolicy`, `NetworkWaitReason` | Wi-Fi-only / mobile-data decisions (used internally, exposed for UI). |
| `FermataArtworkCache extends CacheManager with ImageCacheManager` | Artwork cache for `cached_network_image` (`cacheManager:`), rooted in `AppPaths.artworkCacheDir/remote`, bounded by `storage.artworkCacheMb`. Implements `OfflineArtworkStore`. |
| `DownloadOptions` | Engine tunables (attempts, backoff, progress rate, timeouts). |
| `DownloadErrorCode` | Stable, localizable codes stored in `DownloadTask.error`. |
| `AudioSniffer`, `IntegrityChecker`, `FileNameSanitizer`, `DownloadPathBuilder`, `FileMover`, `FreeSpace` | Building blocks (pure, unit-tested). |

### Constructors

```dart
DownloadManagerImpl({
  required SourceRegistry sources,
  required TrackRepository tracks,
  required PlaylistRepository playlists,
  required HistoryRepository history,
  required SettingsStore settings,
  required AppPaths paths,
  required FermataHttp http,
  required NetworkStatus network,
  SystemNotifier? notifier,
  OfflineArtworkStore? artwork,               // default: new FermataArtworkCache (owned + disposed)
  Future<int> Function()? databaseSize,       // default: size of fermata.db (+ -wal/-shm)
  Future<int> Function()? streamCacheSize,    // default: 0 (no stream cache in Fermata)
  DownloadNotificationStrings? notificationStrings, // default: EN/DA by localeCode
  DownloadOptions options = const DownloadOptions(),
  FileMover? fileMover,
})

ConnectivityNetworkStatus({Connectivity? connectivity, PlatformInfo? platform})
FermataArtworkCache({required AppPaths paths, required SettingsStore settings, required FermataHttp http,
                     Duration stalePeriod = const Duration(days: 60), int maxObjects = 20000})
```

### Extras on `DownloadManagerImpl` (beyond the contract)

* `bool get needsMobileDataConfirmation` / `void confirmMobileDataForSession()`
  — with `wifiOnly` off and `warnOnMobileData` on, downloads on a metered
  network wait (`waitingForNetwork`) until the user confirms once per session.
* `NetworkWaitReason? get networkWaitReason` — `offline`, `wifiOnly`,
  `mobileDataConfirmation` or null.
* `bool get isMetered`, `NetworkStatus get network`, `String get downloadDirectory`,
  `OfflineArtworkStore get artwork`, `Future<void> get idle`.

## Bootstrap wiring (`lib/app/bootstrap.dart`)

Order: after settings, HTTP, library repositories and the source registry;
before the stream resolver.

```dart
final network = ConnectivityNetworkStatus(platform: platform);
await network.init();
final artworkCache = FermataArtworkCache(paths: paths, settings: settings, http: http);
final downloads = DownloadManagerImpl(
  sources: sources,
  tracks: tracks,
  playlists: playlists,
  history: history,
  settings: settings,
  paths: paths,
  http: http,
  network: network,
  notifier: notifier,                       // SystemNotifier, if created before this point
  artwork: artworkCache,
  databaseSize: maintenance.databaseSizeBytes,
);
await downloads.init();                     // restores the queue, starts transfers + auto-download sync

final streamResolver = StreamResolverImpl(
  sources: sources, downloads: downloads, links: links, settings: settings,
  isMetered: network.isMeteredNow,
);

// Quit / dispose (reverse order):
await downloads.dispose();                  // stops transfers (resumable), flushes the index
await artworkCache.dispose();
await network.dispose();
```

UI: pass `artworkCache` to `CachedNetworkImage(cacheManager: artworkCache)`.

## Behaviour

* **Eligibility** (`checkEligibility`): local/user-owned → `alreadyLocal`;
  completed → `alreadyDownloaded`; `offline == downloadable` and the source
  exists, supports `download`, has credentials and is ready → `allowed`;
  `streamOnly` → `streamOnly`; otherwise `unavailable` with a reason
  (`AvailabilityReason` code or `source_unavailable`). `enqueue` throws
  `DownloadNotPermittedException` unless allowed; the same track id reuses
  its task (completed / active / paused; failed or canceled are re-queued).
* **Queue**: `<support>/downloads/index.json` (atomic temp+rename, `.bak`
  fallback, throttled writes). On `init()` interrupted `downloading` /
  `verifying` / `waitingForNetwork` tasks become `queued`; completed tasks
  whose file vanished become `failed(file_missing)`; orphan `.part` files are
  deleted. `downloads.maxConcurrent` parallel transfers.
* **Transfers**: streamed `http.AbortableRequest` over `FermataHttp.raw` into
  `<cache>/downloads-partial/<taskId>.part`; resume with `Range` +
  `If-Range` (strong ETag, else Last-Modified); `200` to a range request,
  a changed validator or a mismatching `Content-Range` restarts from byte 0;
  `416` with matching size = already complete. Idle timeout 30 s. Cancel
  aborts the socket.
* **Retries**: network errors, timeouts, 5xx/408, 401/403 (signed URL expiry;
  re-authorized), 429 and corrupted transfers (size/checksum) retry with
  exponential backoff (2 s · 2ⁿ, ±20 %, cap 5 min) up to **5 attempts**;
  `Retry-After` wins. 404/410, non-audio bodies, auth/credential errors and
  `authorizeDownload == null` fail immediately. A network error while the
  policy says "wait" does not consume an attempt.
* **Progress**: `receivedBytes`/`totalBytes`, EMA speed; progress emissions
  ≤ 4 Hz (status changes are immediate).
* **Network policy**: `wifiOnly` → `waitingForNetwork` on metered/no network;
  running transfers are suspended (partial kept) and resume automatically
  when Wi-Fi returns.
* **Integrity**: header sniffing (ID3/MPEG sync, ADTS, fLaC, OggS
  Vorbis/Opus/FLAC, ftyp, RIFF/WAVE, AIFF, ASF, WebM, APE, WavPack, DSF,
  Musepack) — text/HTML bodies are rejected early (`not_audio`); size must
  match Content-Length/Content-Range and `expectedBytes`; SHA-256 always
  computed and stored, compared to `expectedSha256` when given.
  `downloads.verifyIntegrity = false` keeps the sniff but skips size/hash
  comparisons. `verifyAll()` re-checks existence, size, hash and header.
* **Files**: `<downloadDir>/<Album artist or Artist>/<Album or Singles>/<NN - >Title.<ext>`
  (`D-NN` for disc > 1), Windows-safe names (reserved names, `<>:"/\|?*`,
  control chars, trailing dots/spaces, no leading dots), ≤ 120 UTF-8 bytes per
  component, ` (2)` on collisions. Extension: authorization → sniffed
  container → Content-Type. Identical bytes (same SHA-256) from another
  track share one file (reference-counted on delete).
* **Library**: the track is upserted at enqueue and again on completion with
  `availability.offline = downloadable`, `checkedAt` and `format` (codec,
  size). `localPath` is never set for downloads.
* **Artwork**: http(s) `artworkUrl` is fetched once into the artwork cache and
  *pinned* (never evicted while a completed download uses it).
* **Storage**: `storageUsage()` (completed files, whole artwork dir, DB,
  free space via `statvfs`/`GetDiskFreeSpaceExW`); `enforceStorageLimit()`
  evicts least-recently-used downloads (later of last play from
  `HistoryRepository` and completion time) until under
  `storage.downloadLimitMb`, then trims the artwork cache; runs automatically
  after each completion when `storage.autoCleanup` (never evicting the just
  finished task); never deletes user-owned local files.
  `clearArtworkCache()` removes unpinned cached images (not the local
  library's extracted artwork). `changeDownloadDirectory()` validates the
  target, moves files (copy + delete across devices), updates index and
  `downloads.directory`.
* **Auto-download playlists**: `syncAutoDownloads()` on `init()`, every
  `performance.syncIntervalMinutes` while `performance.backgroundSync`, and
  when an allowed network returns after a skipped run. Never offline or on
  metered networks with `wifiOnly`. Stops when the storage limit is reached.
  Tracks with an existing task (incl. failed/canceled) are left alone.
* **Notifications**: one `SystemNotifier.show` per batch (queue drained):
  "12 tracks downloaded" / "Downloaded: <title>" (+ failures), EN/DA by
  `localeCode`, only with `downloads.notifyOnComplete` and
  `notifications.downloads`.

## Platform notes

* Linux: connectivity via NetworkManager (connectivity_plus); without it the
  status is "connected, unmetered". Free space via `statvfs` (64-bit only).
* Android: Wi-Fi/Ethernet unmetered; cellular, satellite and unknown
  transports metered. Downloads go to the app-specific external Music dir
  (`AppPaths.defaultDownloadDir`, no permission needed).
* Windows: `GetDiskFreeSpaceExW`; a file held open by the player cannot be
  deleted — `remove()`/`deleteDownload()` then throw
  `StorageException('download_delete_failed')` and keep the task; eviction
  skips it. (Windows code paths are not exercised in CI here.)

## Known limitations

* Transfers run in the app process; Android has no WorkManager-style
  background download when the process is killed — the queue resumes on the
  next start.
* Tracks whose availability is still `unknown` (e.g. imported metadata that
  was never refreshed) classify as `unavailable` until the source updates
  them.
* `streamCacheBytes` is 0 unless a callback is supplied (Fermata has no
  persistent stream cache).
* Error codes in `DownloadErrorCode` need UI localization (the module owns no
  ARB fragments).
