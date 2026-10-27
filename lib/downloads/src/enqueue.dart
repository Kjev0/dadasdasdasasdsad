part of '../download_manager_impl.dart';

/// Enqueue internals: eligibility gate and "same track id → reuse".
extension _Enqueue on DownloadManagerImpl {
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
      if (existing.task.filePath != null) await _withFsLock(() => _deleteFileIfUnshared(existing));
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
      case DownloadStatus.queued ||
          DownloadStatus.waitingForNetwork ||
          DownloadStatus.downloading ||
          DownloadStatus.verifying:
        return (existing.task, const DownloadEligibility(DownloadEligibilityKind.allowed));
      case DownloadStatus.paused:
        await resume(existing.id);
        return (_records[existing.id]!.task, const DownloadEligibility(DownloadEligibilityKind.allowed));
      case DownloadStatus.failed || DownloadStatus.canceled:
        return null;
    }
  }
}
