part of '../download_manager_impl.dart';

/// Record bookkeeping, change emission and small helpers shared by the
/// manager's parts.
extension _State on DownloadManagerImpl {
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

  DownloadRecord? _completedFor(String trackId) =>
      _records.values.firstWhereOrNull((r) => r.task.trackId == trackId && r.status == DownloadStatus.completed);

  List<DownloadRecord> _snapshot() => _records.values.toList();

  void _put(DownloadRecord r) {
    if (!_records.containsKey(r.id)) return; // removed meanwhile
    _records[r.id] = r;
    _tasksCache = null;
  }

  /// Deletes the file of a failed/canceled task so it can be re-downloaded —
  /// except for `file_missing`: that flag can be stale (drive was not
  /// mounted yet), so a file that is present again is never deleted.
  Future<void> _discardBrokenFile(DownloadRecord r) async {
    if (r.task.filePath == null || r.task.error == DownloadErrorCode.fileMissing) return;
    await _withFsLock(() => _deleteFileIfUnshared(r));
  }

  /// A task flagged `file_missing` whose file is back (external drive / SD
  /// card / NAS mounted late, file restored) is usable again.
  Future<void> _recoverMissing(String trackId) async {
    for (final r in _records.values.toList()) {
      final path = r.task.filePath;
      if (r.task.trackId != trackId ||
          r.status != DownloadStatus.failed ||
          r.task.error != DownloadErrorCode.fileMissing ||
          path == null ||
          !await File(path).exists()) {
        continue;
      }
      _put(r.copyWith(task: rebuildTask(r.task, status: DownloadStatus.completed, error: null)));
      _changed();
    }
  }

  void _requeue(DownloadRecord r, {Track? track, bool keepFile = false}) {
    _put(
      r.copyWith(
        task: rebuildTask(
          r.task,
          track: track,
          status: DownloadStatus.queued,
          attempts: 0,
          error: null,
          bytesPerSecond: 0,
          filePath: keepFile ? r.task.filePath : null,
          completedAt: null,
          sha256: null,
        ),
        fileSize: null,
        nextAttemptAt: null,
      ),
    );
    _changed();
    _pump();
  }

  void _markBroken(String id, String code) {
    final r = _records[id];
    if (r == null || r.status != DownloadStatus.completed) return;
    _log.warning('Download $id is broken: $code');
    _put(
      r.copyWith(
        task: rebuildTask(r.task, status: DownloadStatus.failed, error: code),
      ),
    );
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
    tracked = work
        .catchError((Object e, StackTrace st) {
          _log.warning('Background download work failed: ${redactUrls(e)}', null, st);
        })
        .whenComplete(() => _pending.remove(tracked));
    _pending.add(tracked);
  }
}
