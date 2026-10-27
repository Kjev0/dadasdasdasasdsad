import 'dart:async';

import 'package:fermata/core/contracts/downloads.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/track.dart';

/// In-memory [DownloadManager]. Eligibility defaults to the track's
/// `OfflineRights` (downloadable → allowed); override per track with
/// [eligibility]. Enqueued tasks stay `queued` until [complete] is called.
class FakeDownloadManager implements DownloadManager {
  final calls = <String>[];
  final eligibility = <String, DownloadEligibility>{};
  final downloaded = <String>{};
  final _tasks = <DownloadTask>[];
  final _tasksCtl = StreamController<List<DownloadTask>>.broadcast();
  final _idsCtl = StreamController<Set<String>>.broadcast();
  StorageUsage usage = const StorageUsage(
    downloadsBytes: 50 * 1024 * 1024,
    downloadCount: 12,
    artworkCacheBytes: 8 * 1024 * 1024,
    streamCacheBytes: 0,
    databaseBytes: 2 * 1024 * 1024,
  );
  int _next = 1;

  void _emitTasks() => _tasksCtl.add(List.unmodifiable(_tasks));
  void _emitIds() => _idsCtl.add(Set.of(downloaded));

  /// Adds a task directly (test setup).
  DownloadTask addTask(DownloadTask task) {
    _tasks.add(task);
    _emitTasks();
    return task;
  }

  /// Marks [trackId]'s task completed and downloaded.
  void complete(String trackId) {
    final i = _tasks.indexWhere((t) => t.trackId == trackId);
    if (i >= 0) _tasks[i] = _tasks[i].copyWith(status: DownloadStatus.completed, completedAt: DateTime(2026));
    downloaded.add(trackId);
    _emitTasks();
    _emitIds();
  }

  void _update(String taskId, DownloadStatus status) {
    final i = _tasks.indexWhere((t) => t.id == taskId);
    if (i >= 0) _tasks[i] = _tasks[i].copyWith(status: status);
    _emitTasks();
  }

  @override
  Future<void> init() async => calls.add('init');

  @override
  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  @override
  Stream<List<DownloadTask>> get tasksStream => _tasksCtl.stream;

  @override
  Future<DownloadEligibility> checkEligibility(Track track) async {
    calls.add('checkEligibility');
    if (downloaded.contains(track.id)) return const DownloadEligibility(DownloadEligibilityKind.alreadyDownloaded);
    final preset = eligibility[track.id];
    if (preset != null) return preset;
    return switch (track.availability.offline) {
      OfflineRights.userOwned => const DownloadEligibility(DownloadEligibilityKind.alreadyLocal),
      OfflineRights.downloadable => const DownloadEligibility(DownloadEligibilityKind.allowed),
      OfflineRights.streamOnly => const DownloadEligibility(DownloadEligibilityKind.streamOnly),
      OfflineRights.unavailable => const DownloadEligibility(DownloadEligibilityKind.unavailable),
    };
  }

  @override
  Future<DownloadTask> enqueue(Track track, {String? origin}) async {
    calls.add('enqueue');
    final e = await checkEligibility(track);
    if (!e.canDownload) throw DownloadNotPermittedException(track.id, e.reason ?? e.kind.name);
    return addTask(DownloadTask(id: 'd${_next++}', track: track, status: DownloadStatus.queued, createdAt: DateTime(2026), origin: origin));
  }

  @override
  Future<Map<String, DownloadEligibility>> enqueueAll(List<Track> tracks, {String? origin}) async {
    calls.add('enqueueAll');
    final rejected = <String, DownloadEligibility>{};
    for (final t in tracks) {
      final e = await checkEligibility(t);
      if (e.canDownload) {
        addTask(DownloadTask(id: 'd${_next++}', track: t, status: DownloadStatus.queued, createdAt: DateTime(2026), origin: origin));
      } else {
        rejected[t.id] = e;
      }
    }
    return rejected;
  }

  @override
  Future<void> pause(String taskId) async {
    calls.add('pause');
    _update(taskId, DownloadStatus.paused);
  }

  @override
  Future<void> resume(String taskId) async {
    calls.add('resume');
    _update(taskId, DownloadStatus.queued);
  }

  @override
  Future<void> retry(String taskId) async {
    calls.add('retry');
    _update(taskId, DownloadStatus.queued);
  }

  @override
  Future<void> cancel(String taskId) async {
    calls.add('cancel');
    _update(taskId, DownloadStatus.canceled);
  }

  @override
  Future<void> pauseAll() async {
    calls.add('pauseAll');
    for (final t in [..._tasks]) {
      if (t.isActive) _update(t.id, DownloadStatus.paused);
    }
  }

  @override
  Future<void> resumeAll() async {
    calls.add('resumeAll');
    for (final t in [..._tasks]) {
      if (t.status == DownloadStatus.paused) _update(t.id, DownloadStatus.queued);
    }
  }

  @override
  Future<void> remove(String taskId, {bool deleteFile = true}) async {
    calls.add('remove');
    _tasks.removeWhere((t) => t.id == taskId);
    _emitTasks();
  }

  @override
  Future<void> deleteDownload(String trackId) async {
    calls.add('deleteDownload');
    downloaded.remove(trackId);
    _tasks.removeWhere((t) => t.trackId == trackId);
    _emitTasks();
    _emitIds();
  }

  @override
  Future<String?> localFileFor(String trackId) async => downloaded.contains(trackId) ? '/downloads/$trackId.mp3' : null;

  @override
  bool isDownloaded(String trackId) => downloaded.contains(trackId);

  @override
  Stream<Set<String>> watchDownloadedIds() async* {
    yield Set.of(downloaded);
    yield* _idsCtl.stream;
  }

  @override
  Future<StorageUsage> storageUsage() async {
    calls.add('storageUsage');
    return usage;
  }

  @override
  Future<int> enforceStorageLimit() async {
    calls.add('enforceStorageLimit');
    return 0;
  }

  @override
  Future<int> clearArtworkCache() async {
    calls.add('clearArtworkCache');
    return usage.artworkCacheBytes;
  }

  @override
  Future<List<String>> verifyAll() async {
    calls.add('verifyAll');
    return const [];
  }

  @override
  Future<void> changeDownloadDirectory(String newPath) async => calls.add('changeDownloadDirectory');

  @override
  Future<void> syncAutoDownloads() async => calls.add('syncAutoDownloads');

  @override
  Future<void> dispose() async {
    await _tasksCtl.close();
    await _idsCtl.close();
  }
}
