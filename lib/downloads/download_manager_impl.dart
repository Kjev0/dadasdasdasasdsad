import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/contracts/downloads.dart';
import '../core/contracts/library.dart';
import '../core/contracts/music_source.dart';
import '../core/contracts/platform.dart';
import '../core/errors.dart';
import '../core/models/download.dart';
import '../core/models/track.dart';
import '../core/net/http_client.dart';
import '../core/platform/app_paths.dart';
import '../core/util/cancel_token.dart';
import '../settings/app_settings.dart';
import '../settings/settings_store.dart';
import 'artwork/fermata_artwork_cache.dart';
import 'download_errors.dart';
import 'download_options.dart';
import 'files/file_ops.dart';
import 'files/path_builder.dart';
import 'integrity/audio_sniffer.dart';
import 'integrity/integrity.dart';
import 'network/network_policy.dart';
import 'network/network_status.dart';
import 'notify/batch_notifier.dart';
import 'storage/free_space.dart';
import 'storage/storage_policy.dart';
import 'store/download_index.dart';
import 'store/download_record.dart';
import 'sync/auto_download_scheduler.dart';
import 'transfer/http_transfer.dart';
import 'transfer/speed_meter.dart';

part 'src/engine.dart';
part 'src/storage_ops.dart';

final _log = Logger('downloads.manager');

/// Why a running transfer was stopped on purpose.
enum _StopIntent { pause, cancel, network, shutdown, remove }

class _ActiveRun {
  _ActiveRun(this.id, Duration window) : meter = SpeedMeter(window: window);

  final String id;
  final cancel = CancelToken();
  final SpeedMeter meter;
  _StopIntent? intent;
  int lastReceived = 0;
  late final Future<void> done;

  void stop(_StopIntent why) {
    intent ??= why;
    cancel.cancel();
  }
}

/// Offline downloads: queue, resumable transfers, integrity, storage limits,
/// auto-download playlists. See `lib/downloads/README.md`.
///
/// Only tracks whose source returns a `DownloadAuthorization` are ever
/// stored; authorization is requested again for every (re)start because
/// download URLs may be signed and expire. Stream URLs are never saved.
class DownloadManagerImpl implements DownloadManager {
  DownloadManagerImpl({
    required this._sources,
    required this._tracks,
    required this._playlists,
    required this._history,
    required SettingsStore settings,
    required AppPaths paths,
    required FermataHttp http,
    required NetworkStatus network,
    SystemNotifier? notifier,
    OfflineArtworkStore? artwork,
    this._databaseSize,
    this._streamCacheSize,
    DownloadNotificationStrings? notificationStrings,
    DownloadOptions options = const DownloadOptions(),
    FileMover? fileMover,
  })  : _settings = settings,
        _paths = paths,
        _network = network,
        _options = options,
        _mover = fileMover ?? FileMover(),
        _ownsArtwork = artwork == null,
        _artwork = artwork ?? FermataArtworkCache(paths: paths, settings: settings, http: http),
        _policy = DownloadNetworkPolicy(network: network, settings: settings),
        _transfer = HttpTransfer(http: http, headerTimeout: options.headerTimeout, idleTimeout: options.idleTimeout),
        _batch = DownloadBatchNotifier(notifier: notifier, settings: settings, strings: notificationStrings),
        _index = DownloadIndex(File(p.join(paths.supportDir.path, 'downloads', 'index.json')),
            debounce: options.indexWriteDebounce) {
    _scheduler = AutoDownloadScheduler(settings: settings, sync: syncAutoDownloads);
  }

  final SourceRegistry _sources;
  final TrackRepository _tracks;
  final PlaylistRepository _playlists;
  final HistoryRepository _history;
  final SettingsStore _settings;
  final AppPaths _paths;
  final NetworkStatus _network;
  final DownloadOptions _options;
  final Future<int> Function()? _databaseSize;
  final Future<int> Function()? _streamCacheSize;
  final FileMover _mover;
  final bool _ownsArtwork;
  final OfflineArtworkStore _artwork;
  final DownloadNetworkPolicy _policy;
  final HttpTransfer _transfer;
  final DownloadBatchNotifier _batch;
  final DownloadIndex _index;
  late final AutoDownloadScheduler _scheduler;

  /// Insertion order == creation order.
  final _records = <String, DownloadRecord>{};
  final _active = <String, _ActiveRun>{};
  final _pending = <Future<void>>{};
  final _tasksController = StreamController<List<DownloadTask>>.broadcast();
  final _idsController = StreamController<Set<String>>.broadcast();
  final _uptime = Stopwatch()..start();

  List<DownloadTask>? _tasksCache;
  Set<String> _downloadedIds = const {};
  Duration _lastEmit = Duration.zero;
  Timer? _emitTimer;
  Timer? _wakeTimer;
  Future<void> _fsLock = Future.value();
  Future<void>? _syncing;
  bool _syncSkippedForNetwork = false;
  StreamSubscription<AppSettings>? _settingsSub;
  StreamSubscription<NetworkState>? _networkSub;
  bool _initialized = false;
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Extras beyond the DownloadManager contract (UI / bootstrap).
  // ---------------------------------------------------------------------------

  /// Artwork store used for downloaded tracks (a [FermataArtworkCache]
  /// unless a custom one was injected).
  OfflineArtworkStore get artwork => _artwork;

  /// Current download directory (setting or platform default).
  String get downloadDirectory => _downloadDir;

  /// Network status used by the policy (`isMetered` for the stream resolver).
  NetworkStatus get network => _network;

  /// Whether the active connection is metered.
  bool get isMetered => _network.isMetered;

  /// Why queued downloads are currently held back, or null.
  NetworkWaitReason? get networkWaitReason => _policy.evaluate();

  /// True while downloads wait for the user to accept mobile data
  /// (`downloads.warnOnMobileData`, Wi-Fi-only off, metered connection).
  /// The UI should ask, then call [confirmMobileDataForSession].
  bool get needsMobileDataConfirmation => _policy.needsMobileDataConfirmation;

  /// Allow downloads over mobile data until the app restarts.
  void confirmMobileDataForSession() {
    _policy.confirmMobileDataForSession();
    _pump();
  }

  /// Completes when no transfer or background work (auto-cleanup, sync,
  /// notifications) is running. Mainly for tests and orderly shutdown.
  Future<void> get idle async {
    while (true) {
      final futures = [..._active.values.map((r) => r.done), ..._pending];
      if (futures.isEmpty) return;
      await Future.wait(futures);
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> init() async {
    if (_initialized || _disposed) return;
    await _paths.tempDownloadDir.create(recursive: true);
    for (final record in await _index.load()) {
      _records[record.id] = await _restore(record);
    }
    await _deleteOrphanPartials();
    _initialized = true;
    _settingsSub = _settings.changes.listen((_) => _pump());
    _networkSub = _network.changes.listen((_) => _onNetworkChanged());
    _scheduler.start();
    _index.scheduleSave(_snapshot);
    _emitNow();
    _pump();
    if (_options.syncOnInit) _track(syncAutoDownloads());
    _log.info('Download manager ready: ${_records.length} tasks, dir $_downloadDir');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _wakeTimer?.cancel();
    await _scheduler.stop();
    await _settingsSub?.cancel();
    await _networkSub?.cancel();
    for (final run in _active.values.toList()) {
      run.stop(_StopIntent.shutdown);
    }
    try {
      await idle.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      _log.warning('Some download work did not stop in time');
    }
    _emitTimer?.cancel();
    await _index.flush(_snapshot);
    if (_ownsArtwork) await _artwork.dispose();
    await _tasksController.close();
    await _idsController.close();
  }

  // ---------------------------------------------------------------------------
  // Observation
  // ---------------------------------------------------------------------------

  @override
  List<DownloadTask> get tasks => _tasksCache ??= List.unmodifiable(_records.values.map((r) => r.task));

  @override
  Stream<List<DownloadTask>> get tasksStream => _tasksController.stream;

  @override
  bool isDownloaded(String trackId) => _completedFor(trackId) != null;

  @override
  Stream<Set<String>> watchDownloadedIds() {
    StreamSubscription<Set<String>>? sub;
    late final StreamController<Set<String>> controller;
    controller = StreamController<Set<String>>(
      onListen: () {
        controller.add(_downloadedIds);
        sub = _idsController.stream.listen(controller.add, onDone: controller.close);
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<String?> localFileFor(String trackId) async {
    final record = _completedFor(trackId);
    final path = record?.task.filePath;
    if (record == null || path == null) return null;
    final file = File(path);
    if (!await file.exists()) {
      _markBroken(record.id, DownloadErrorCode.fileMissing);
      return null;
    }
    final expected = record.fileSize;
    if (_settings.current.downloads.verifyIntegrity && expected != null && await file.length() != expected) {
      _markBroken(record.id, DownloadErrorCode.sizeMismatch);
      return null;
    }
    return path;
  }

  // ---------------------------------------------------------------------------
  // Eligibility & enqueue
  // ---------------------------------------------------------------------------

  @override
  Future<DownloadEligibility> checkEligibility(Track track) async {
    if (track.isLocal || track.availability.offline == OfflineRights.userOwned) {
      return const DownloadEligibility(DownloadEligibilityKind.alreadyLocal);
    }
    if (isDownloaded(track.id)) return const DownloadEligibility(DownloadEligibilityKind.alreadyDownloaded);
    final availability = track.availability;
    switch (availability.offline) {
      case OfflineRights.userOwned:
        return const DownloadEligibility(DownloadEligibilityKind.alreadyLocal);
      case OfflineRights.streamOnly:
        return DownloadEligibility(DownloadEligibilityKind.streamOnly, reason: availability.reason);
      case OfflineRights.unavailable:
        return DownloadEligibility(DownloadEligibilityKind.unavailable,
            reason: availability.reason ?? AvailabilityReason.unknown);
      case OfflineRights.downloadable:
        final source = _sources.byId(track.sourceId);
        if (source == null) {
          return const DownloadEligibility(DownloadEligibilityKind.unavailable,
              reason: DownloadErrorCode.sourceUnavailable);
        }
        if (!source.supports(SourceCapability.download)) {
          return const DownloadEligibility(DownloadEligibilityKind.unavailable,
              reason: AvailabilityReason.notAuthorized);
        }
        if (!source.credentialStatus.configured) {
          return const DownloadEligibility(DownloadEligibilityKind.unavailable,
              reason: AvailabilityReason.credentialsMissing);
        }
        if (!source.isReady) {
          return const DownloadEligibility(DownloadEligibilityKind.unavailable,
              reason: AvailabilityReason.notAuthorized);
        }
        // The final word is `authorizeDownload` at download time.
        return const DownloadEligibility(DownloadEligibilityKind.allowed);
    }
  }

  @override
  Future<DownloadTask> enqueue(Track track, {String? origin}) async {
    final (task, eligibility) = await _enqueue(track, origin: origin);
    if (task == null) {
      throw DownloadNotPermittedException(track.id, eligibility.reason ?? eligibility.kind.name);
    }
    return task;
  }

  @override
  Future<Map<String, DownloadEligibility>> enqueueAll(List<Track> tracks, {String? origin}) async {
    final rejected = <String, DownloadEligibility>{};
    for (final track in tracks) {
      final (_, eligibility) = await _enqueue(track, origin: origin);
      if (!eligibility.canDownload) rejected[track.id] = eligibility;
    }
    return rejected;
  }

  /// Returns the (new or reused) task, or null when not permitted.
  Future<(DownloadTask?, DownloadEligibility)> _enqueue(Track track, {String? origin}) async {
    _ensureInit();
    const allowed = DownloadEligibility(DownloadEligibilityKind.allowed);
    final reuse = await _reuseExisting(track.id);
    if (reuse != null) return reuse;
    final eligibility = await checkEligibility(track);
    if (!eligibility.canDownload) {
      return (_completedFor(track.id)?.task, eligibility);
    }
    // Re-check after the await: another enqueue may have raced us.
    final existing = _recordFor(track.id);
    if (existing != null) {
      if (existing.task.isActive || existing.status == DownloadStatus.completed) return (existing.task, allowed);
      _requeue(existing, track: track);
      return (_records[existing.id]!.task, allowed);
    }
    final now = DateTime.now();
    final task = DownloadTask(
      id: const Uuid().v4(),
      track: track,
      status: DownloadStatus.queued,
      createdAt: now,
      totalBytes: track.format?.fileSizeBytes,
      origin: origin,
    );
    _records[task.id] = DownloadRecord(task: task);
    _log.fine('Enqueued ${track.id} (${task.id})');
    _changed();
    _pump();
    try {
      await _tracks.upsertTracks([track]);
    } catch (e) {
      _log.fine('Could not upsert ${track.id} into the library', e);
    }
    return (_records[task.id]?.task ?? task, allowed);
  }

  /// "Same track id → reuse": completed, active and paused tasks are reused.
  Future<(DownloadTask?, DownloadEligibility)?> _reuseExisting(String trackId) async {
    final existing = _recordFor(trackId);
    if (existing == null) return null;
    switch (existing.status) {
      case DownloadStatus.completed:
        final path = existing.task.filePath;
        if (path != null && await File(path).exists()) {
          return (existing.task, const DownloadEligibility(DownloadEligibilityKind.alreadyDownloaded));
        }
        _markBroken(existing.id, DownloadErrorCode.fileMissing);
        return null;
      case DownloadStatus.queued || DownloadStatus.waitingForNetwork || DownloadStatus.downloading ||
            DownloadStatus.verifying:
        return (existing.task, const DownloadEligibility(DownloadEligibilityKind.allowed));
      case DownloadStatus.paused:
        await resume(existing.id);
        return (_records[existing.id]!.task, const DownloadEligibility(DownloadEligibilityKind.allowed));
      case DownloadStatus.failed || DownloadStatus.canceled:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Controls
  // ---------------------------------------------------------------------------

  @override
  Future<void> pause(String taskId) async {
    final run = _active[taskId];
    if (run != null) {
      run.stop(_StopIntent.pause);
      await run.done;
      return;
    }
    final r = _records[taskId];
    if (r != null && (r.status == DownloadStatus.queued || r.status == DownloadStatus.waitingForNetwork)) {
      _put(r.copyWith(task: rebuildTask(r.task, status: DownloadStatus.paused, bytesPerSecond: 0), nextAttemptAt: null));
      _changed();
      _pump();
    }
  }

  @override
  Future<void> resume(String taskId) async {
    final r = _records[taskId];
    if (r == null || r.status != DownloadStatus.paused) return;
    _put(r.copyWith(task: rebuildTask(r.task, status: DownloadStatus.queued), nextAttemptAt: null));
    _changed();
    _pump();
  }

  @override
  Future<void> retry(String taskId) async {
    final r = _records[taskId];
    if (r == null) return;
    if (r.status == DownloadStatus.queued && r.nextAttemptAt != null) {
      // Waiting for backoff: start now.
      _put(r.copyWith(nextAttemptAt: null));
      _pump();
      return;
    }
    if (r.status != DownloadStatus.failed && r.status != DownloadStatus.canceled) return;
    final broken = r.task.filePath;
    if (broken != null) {
      await _withFsLock(() => _deleteFileIfUnshared(r));
    }
    _requeue(r);
  }

  @override
  Future<void> cancel(String taskId) async {
    final run = _active[taskId];
    if (run != null) {
      run.stop(_StopIntent.cancel);
      await run.done;
      return;
    }
    final r = _records[taskId];
    if (r == null || r.status == DownloadStatus.completed || r.status == DownloadStatus.canceled) return;
    await _deletePartial(r);
    _put(r.copyWith(
      task: rebuildTask(r.task, status: DownloadStatus.canceled, receivedBytes: 0, bytesPerSecond: 0),
      partialPath: null,
      etag: null,
      lastModified: null,
      nextAttemptAt: null,
    ));
    _changed();
    _pump();
  }

  @override
  Future<void> pauseAll() async {
    for (final r in _records.values.toList()) {
      if (r.task.isActive) await pause(r.id);
    }
  }

  @override
  Future<void> resumeAll() async {
    for (final r in _records.values.toList()) {
      if (r.status == DownloadStatus.paused) {
        _put(r.copyWith(task: rebuildTask(r.task, status: DownloadStatus.queued), nextAttemptAt: null));
      }
    }
    _changed();
    _pump();
  }

  @override
  Future<void> remove(String taskId, {bool deleteFile = true}) async {
    final run = _active[taskId];
    if (run != null) {
      run.stop(_StopIntent.remove);
      await run.done;
    }
    await _withFsLock(() async {
      final r = _records.remove(taskId);
      if (r == null) return;
      await _deletePartial(r);
      if (deleteFile && r.task.filePath != null) await _deleteFileIfUnshared(r);
      await _unpinArtworkIfUnused(r.task.track);
    });
    _changed();
    _pump();
  }

  @override
  Future<void> deleteDownload(String trackId) async {
    for (final r in _records.values.where((r) => r.task.trackId == trackId).toList()) {
      await remove(r.id, deleteFile: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Storage, verification, sync (see src/storage_ops.dart)
  // ---------------------------------------------------------------------------

  @override
  Future<StorageUsage> storageUsage() {
    _ensureInit();
    return _storageUsage();
  }

  @override
  Future<int> enforceStorageLimit() {
    _ensureInit();
    return _enforce();
  }

  /// Clears the artwork cache except covers of downloaded tracks (needed
  /// offline). Artwork extracted from local files is not affected.
  @override
  Future<int> clearArtworkCache() => _artwork.clearUnpinned();

  @override
  Future<List<String>> verifyAll() {
    _ensureInit();
    return _verifyAll();
  }

  /// Moves every downloaded file below [newPath] (keeping the
  /// Artist/Album layout; copy + delete across file systems), updates the
  /// index and sets `downloads.directory`. Throws [StorageException]
  /// (`download_dir_not_writable`) when [newPath] cannot be written.
  @override
  Future<void> changeDownloadDirectory(String newPath) {
    _ensureInit();
    return _changeDirectory(newPath);
  }

  /// Enqueues permitted, missing tracks of auto-download playlists. Skipped
  /// offline and on metered networks when Wi-Fi-only is on (re-run
  /// automatically when an allowed network returns). Concurrent calls share
  /// one run.
  @override
  Future<void> syncAutoDownloads() {
    if (!_initialized || _disposed) return Future.value();
    return _syncing ??= _syncAutoDownloads().whenComplete(() => _syncing = null);
  }

  // ---------------------------------------------------------------------------
  // Internal state helpers
  // ---------------------------------------------------------------------------

  void _ensureInit() {
    if (!_initialized) throw StateError('DownloadManagerImpl.init() has not completed');
    if (_disposed) throw StateError('DownloadManagerImpl was disposed');
  }

  String get _downloadDir {
    final configured = _settings.current.downloads.directory;
    return (configured != null && configured.trim().isNotEmpty) ? configured : _paths.defaultDownloadDir.path;
  }

  int? get _limitBytes {
    final mb = _settings.current.storage.downloadLimitMb;
    return mb <= 0 ? null : mb * 1024 * 1024;
  }

  String _partialPathFor(String id) => p.join(_paths.tempDownloadDir.path, '$id.part');

  DownloadRecord? _recordFor(String trackId) => _records.values.firstWhereOrNull((r) => r.task.trackId == trackId);

  DownloadRecord? _completedFor(String trackId) => _records.values
      .firstWhereOrNull((r) => r.task.trackId == trackId && r.status == DownloadStatus.completed);

  List<DownloadRecord> _snapshot() => _records.values.toList();

  void _put(DownloadRecord r) {
    if (!_records.containsKey(r.id)) return; // removed meanwhile
    _records[r.id] = r;
    _tasksCache = null;
  }

  void _requeue(DownloadRecord r, {Track? track}) {
    _put(r.copyWith(
      task: rebuildTask(r.task,
          track: track,
          status: DownloadStatus.queued,
          attempts: 0,
          error: null,
          bytesPerSecond: 0,
          filePath: null,
          completedAt: null,
          sha256: null),
      fileSize: null,
      nextAttemptAt: null,
    ));
    _changed();
    _pump();
  }

  void _markBroken(String id, String code) {
    final r = _records[id];
    if (r == null || r.status != DownloadStatus.completed) return;
    _log.warning('Download $id is broken: $code');
    _put(r.copyWith(task: rebuildTask(r.task, status: DownloadStatus.failed, error: code)));
    _changed();
  }

  /// Persist + notify listeners. Status changes are emitted immediately,
  /// progress at most every `options.progressInterval` (≤ 4 Hz by default).
  void _changed({bool immediate = true}) {
    _tasksCache = null;
    if (immediate) _index.scheduleSave(_snapshot);
    if (immediate) {
      _emitNow();
    } else {
      _emitThrottled();
    }
  }

  void _emitThrottled() {
    if (_emitTimer != null) return;
    final since = _uptime.elapsed - _lastEmit;
    if (since >= _options.progressInterval) {
      _emitNow();
    } else {
      _emitTimer = Timer(_options.progressInterval - since, _emitNow);
    }
  }

  void _emitNow() {
    _emitTimer?.cancel();
    _emitTimer = null;
    _lastEmit = _uptime.elapsed;
    if (!_tasksController.isClosed) _tasksController.add(tasks);
    final ids = {
      for (final r in _records.values)
        if (r.status == DownloadStatus.completed) r.task.trackId,
    };
    if (!const SetEquality<String>().equals(ids, _downloadedIds)) {
      _downloadedIds = Set.unmodifiable(ids);
      if (!_idsController.isClosed) _idsController.add(_downloadedIds);
    }
  }

  /// Serializes file-system mutations (finalize, move, delete, evict).
  Future<T> _withFsLock<T>(Future<T> Function() action) {
    final result = _fsLock.then((_) => action());
    _fsLock = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  void _track(Future<void> work) {
    late final Future<void> tracked;
    tracked = work.catchError((Object e, StackTrace st) {
      _log.warning('Background download work failed', e, st);
    }).whenComplete(() => _pending.remove(tracked));
    _pending.add(tracked);
  }
}
