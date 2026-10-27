part of '../download_manager_impl.dart';

/// Storage usage & limits, directory changes, verification, auto-download
/// sync — the [DownloadManager] operations that work on finished files.
extension _StorageOps on DownloadManagerImpl {
  Iterable<DownloadRecord> get _completedRecords =>
      _records.values.where((r) => r.status == DownloadStatus.completed && r.task.filePath != null);

  /// Bytes of completed downloads (files shared by identical tracks count
  /// once).
  Future<int> _downloadsBytes() async {
    var total = 0;
    for (final path in {for (final r in _completedRecords) r.task.filePath!}) {
      total += await fileSize(path);
    }
    return total;
  }

  Future<int> _defaultDatabaseBytes() async {
    final db = _paths.databaseFile.path;
    return await fileSize(db) + await fileSize('$db-wal') + await fileSize('$db-shm');
  }

  Future<StorageUsage> _storageUsage() async {
    return StorageUsage(
      downloadsBytes: await _downloadsBytes(),
      downloadCount: _completedRecords.length,
      artworkCacheBytes: await directorySize(_paths.artworkCacheDir),
      streamCacheBytes: await (_streamCacheSize?.call() ?? Future.value(0)),
      databaseBytes: await (_databaseSize?.call() ?? _defaultDatabaseBytes()),
      freeDiskBytes: await FreeSpace.bytesAvailable(_downloadDir),
      downloadLimitBytes: _limitBytes,
    );
  }

  bool _isShared(DownloadRecord r) => _records.values.any((o) =>
      o.id != r.id &&
      o.task.filePath == r.task.filePath &&
      (o.status == DownloadStatus.completed || o.status == DownloadStatus.failed));

  /// Deletes [r]'s file unless another task still references it or the
  /// track is a user-owned local file. Returns true when deleted. A file
  /// that cannot be deleted (locked on Windows while playing) returns false,
  /// or throws [StorageException] (`download_delete_failed`) with
  /// [throwOnError].
  Future<bool> _deleteFileIfUnshared(DownloadRecord r, {bool throwOnError = false}) async {
    final path = r.task.filePath;
    if (path == null) return false;
    if (r.task.track.isLocal || r.task.track.availability.offline == OfflineRights.userOwned) return false;
    if (_isShared(r)) return false;
    final file = File(path);
    try {
      if (!await file.exists()) return false;
      await file.delete();
    } on FileSystemException catch (e) {
      _log.warning('Could not delete $path', e);
      if (throwOnError) throw StorageException('download_delete_failed', 'Could not delete $path', cause: e);
      return false;
    }
    final root = _downloadDir;
    if (isInside(root, path)) await removeEmptyParents(p.dirname(path), root);
    return true;
  }

  Future<void> _unpinArtworkIfUnused(Track track) async {
    final url = track.artworkUrl;
    if (url == null || !_artwork.isPinned(url)) return;
    final stillUsed = _completedRecords.any((r) => r.task.track.artworkUrl == url);
    if (!stillUsed) await _artwork.unpin(url);
  }

  /// LRU eviction of downloads above `storage.downloadLimitMb`, then the
  /// artwork cache trim. [protect]ed task ids are never evicted.
  Future<int> _enforce({Set<String> protect = const {}}) async {
    var freed = 0;
    final limit = _limitBytes;
    if (limit != null) {
      freed += await _withFsLock(() async {
        var used = await _downloadsBytes();
        if (used <= limit) return 0;
        final completed = _completedRecords.map((r) => r.task).toList();
        final lastPlayed = await StoragePolicy.lastPlayed(_history, {for (final t in completed) t.trackId});
        var evictedBytes = 0;
        for (final task in StoragePolicy.evictionOrder(completed, lastPlayed, protect: protect)) {
          if (used <= limit) break;
          final record = _records[task.id];
          if (record == null) continue;
          final size = await fileSize(task.filePath);
          final shared = _isShared(record);
          final deleted = await _deleteFileIfUnshared(record);
          if (!deleted && !shared && await File(task.filePath!).exists()) continue; // locked / in use
          _records.remove(task.id);
          _tasksCache = null;
          await _unpinArtworkIfUnused(task.track);
          if (deleted) {
            used -= size;
            evictedBytes += size;
          }
          _log.info('Storage limit: evicted ${task.trackId} ($size B)');
        }
        if (used > limit) _log.warning('Download storage still above the limit ($used > $limit B)');
        return evictedBytes;
      });
      _changed();
    }
    try {
      freed += await _artwork.trimToLimit();
    } catch (e) {
      _log.fine('Artwork trim failed', e);
    }
    return freed;
  }

  Future<void> _changeDirectory(String newPath) async {
    final target = p.normalize(p.absolute(newPath));
    final old = p.normalize(p.absolute(_downloadDir));
    if (p.equals(target, old)) return;
    try {
      await Directory(target).create(recursive: true);
      final probe = File(p.join(target, '.fermata-write-test'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
    } on FileSystemException catch (e) {
      throw StorageException('download_dir_not_writable', 'Cannot write to $target', cause: e);
    }
    await _withFsLock(() async {
      final moved = <String, String>{};
      for (final r in _records.values.toList()) {
        final path = r.task.filePath;
        if (path == null) continue;
        var dest = moved[path];
        if (dest == null) {
          final source = File(path);
          if (!await source.exists()) continue;
          final ext = p.extension(path).replaceFirst('.', '');
          final relative =
              isInside(old, path) ? p.relative(path, from: old) : DownloadPathBuilder.relativePathFor(r.task.track, ext);
          var candidate = p.join(target, relative);
          if (await File(candidate).exists()) {
            if (r.task.sha256 != null && await IntegrityChecker.sha256Of(File(candidate)) == r.task.sha256) {
              await source.delete();
              dest = candidate;
            } else {
              candidate = await DownloadPathBuilder.uniqueTarget(target, r.task.track, ext);
            }
          }
          if (dest == null) {
            await _mover.move(source, candidate);
            dest = candidate;
          }
          moved[path] = dest;
          if (isInside(old, path)) await removeEmptyParents(p.dirname(path), old);
        }
        _put(r.copyWith(task: rebuildTask(r.task, filePath: dest)));
        _index.scheduleSave(_snapshot);
      }
      // Inside the lock so no finalize can land in the old directory.
      await _settings.update((s) => s.copyWith(downloads: s.downloads.copyWith(directory: target)));
      _log.info('Moved ${moved.length} downloaded files from $old to $target');
    });
    await _index.flush(_snapshot);
    _changed();
  }

  Future<List<String>> _verifyAll() {
    return _withFsLock(() async {
      final broken = <String>[];
      final hashes = <String, String>{};
      for (final r in _completedRecords.toList()) {
        final path = r.task.filePath!;
        final file = File(path);
        String? code;
        if (!await file.exists()) {
          code = DownloadErrorCode.fileMissing;
        } else if (r.fileSize != null && await file.length() != r.fileSize) {
          code = DownloadErrorCode.sizeMismatch;
        } else {
          final hash = hashes[path] ??= await IntegrityChecker.sha256Of(file);
          if (r.task.sha256 != null && hash != r.task.sha256) {
            code = DownloadErrorCode.checksumMismatch;
          } else if (!(await AudioSniffer.sniffFile(file)).isAudio) {
            code = DownloadErrorCode.notAudio;
          }
        }
        if (code != null) {
          broken.add(r.id);
          _log.warning('Verification failed for ${r.task.trackId}: $code');
          _put(r.copyWith(task: rebuildTask(r.task, status: DownloadStatus.failed, error: code)));
        }
      }
      if (broken.isNotEmpty) _changed();
      return broken;
    });
  }

  Future<void> _syncAutoDownloads() async {
    if (!_policy.allowsBackgroundSync) {
      _syncSkippedForNetwork = true;
      _log.fine('Auto-download sync skipped (network policy)');
      return;
    }
    _syncSkippedForNetwork = false;
    final playlists = await _playlists.autoDownloadPlaylists();
    final limit = _limitBytes;
    var used = limit == null ? 0 : await _downloadsBytes();
    var added = 0;
    for (final playlist in playlists) {
      final tracks = await _playlists.playlistTracks(playlist.id);
      for (final track in tracks) {
        if (_disposed) return;
        // Existing tasks (incl. failed/canceled ones the user can retry) are
        // left alone so a canceled track is not re-added on every sync.
        if (_recordFor(track.id) != null) continue;
        if (limit != null && used >= limit) {
          _log.info('Auto-download sync stopped: storage limit reached');
          return;
        }
        final eligibility = await checkEligibility(track);
        if (!eligibility.canDownload) continue;
        try {
          await enqueue(track, origin: 'playlist:${playlist.id}');
          added++;
          used += track.format?.fileSizeBytes ?? 0;
        } on DownloadNotPermittedException {
          // raced with a change in rights
        }
      }
    }
    if (added > 0) _log.info('Auto-download sync queued $added tracks');
  }
}
