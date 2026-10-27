part of '../download_manager_impl.dart';

/// Scheduling and the per-task transfer pipeline:
/// authorize → transfer (resumable) → verify → artwork + library → finalize.
extension _Engine on DownloadManagerImpl {
  /// Applies the network policy, starts queued tasks up to
  /// `downloads.maxConcurrent`, and arms the backoff wake-up timer.
  void _pump() {
    if (!_initialized || _disposed) return;
    final wait = _policy.evaluate();
    var changed = false;
    for (final r in _records.values.toList()) {
      if (wait != null && r.status == DownloadStatus.queued) {
        _put(r.copyWith(task: rebuildTask(r.task, status: DownloadStatus.waitingForNetwork, bytesPerSecond: 0)));
        changed = true;
      } else if (wait == null && r.status == DownloadStatus.waitingForNetwork) {
        _put(r.copyWith(task: rebuildTask(r.task, status: DownloadStatus.queued)));
        changed = true;
      }
    }
    _wakeTimer?.cancel();
    _wakeTimer = null;
    if (wait != null) {
      // Only transfers need the network; verification/finalizing continue.
      for (final run in _active.values) {
        if (run.intent == null && _records[run.id]?.status == DownloadStatus.downloading) {
          run.stop(_StopIntent.network);
        }
      }
    } else {
      final now = DateTime.now();
      final maxConcurrent = _settings.current.downloads.maxConcurrent;
      DateTime? wake;
      final ready = _records.values
          .where((r) => r.status == DownloadStatus.queued && !_active.containsKey(r.id))
          .toList()
        ..sort((a, b) => a.task.createdAt.compareTo(b.task.createdAt));
      for (final r in ready) {
        if (_active.length >= maxConcurrent) break;
        final at = r.nextAttemptAt;
        if (at != null && at.isAfter(now)) {
          if (wake == null || at.isBefore(wake)) wake = at;
          continue;
        }
        _start(r);
        changed = true;
      }
      if (wake != null) {
        _wakeTimer = Timer(wake.difference(now) + const Duration(milliseconds: 5), _pump);
      }
    }
    if (changed) _changed();
    _checkDrained();
  }

  void _onNetworkChanged() {
    _pump();
    if (_syncSkippedForNetwork && _policy.allowsBackgroundSync && !_disposed) {
      _track(syncAutoDownloads());
    }
  }

  void _checkDrained() {
    if (_batch.pendingCompleted == 0 || _active.isNotEmpty) return;
    final busy = _records.values.any((r) =>
        r.status == DownloadStatus.queued ||
        r.status == DownloadStatus.downloading ||
        r.status == DownloadStatus.verifying);
    if (!busy) _track(_batch.onQueueDrained());
  }

  void _start(DownloadRecord r) {
    final run = _ActiveRun(r.id, _options.progressInterval);
    _active[r.id] = run;
    _put(r.copyWith(
      task: rebuildTask(r.task, status: DownloadStatus.downloading, bytesPerSecond: 0),
      nextAttemptAt: null,
    ));
    run.done = _run(run);
  }

  Future<void> _run(_ActiveRun run) async {
    try {
      final completed = await _download(run);
      if (completed && _settings.current.storage.autoCleanup && _limitBytes != null) {
        _track(_enforce(protect: {run.id}).then((_) {}));
      }
    } catch (e, st) {
      if (e is OperationCanceledException || run.cancel.isCanceled) {
        await _onStopped(run);
      } else {
        await _onFailed(run, e, st);
      }
    } finally {
      _active.remove(run.id);
      _pump();
    }
  }

  /// Returns true when the task completed.
  Future<bool> _download(_ActiveRun run) async {
    final record = _records[run.id];
    if (record == null) throw const OperationCanceledException();
    final track = record.task.track;
    final source = _sources.byId(track.sourceId);
    if (source == null) {
      throw DownloadFailureException(
          const DownloadFailure(DownloadErrorCode.sourceUnavailable, retryable: false), track.sourceId);
    }

    // Always re-authorize: download URLs may be signed and expire.
    final auth = await source.authorizeDownload(track, cancel: run.cancel);
    run.cancel.throwIfCanceled();
    if (auth == null) {
      throw DownloadNotPermittedException(track.id, AvailabilityReason.notAuthorized);
    }

    var current = _records[run.id];
    if (current == null) throw const OperationCanceledException();
    final partial = File(current.partialPath ?? _partialPathFor(run.id));
    if (current.partialPath == null) {
      _put(current.copyWith(partialPath: partial.path));
      _index.scheduleSave(_snapshot);
    }

    final result = await _transfer.run(
      uri: auth.uri,
      partial: partial,
      headers: auth.headers,
      etag: current.etag,
      lastModified: current.lastModified,
      cancel: run.cancel,
      onHeaders: (h) {
        final r = _records[run.id];
        if (r == null) return;
        run.lastReceived = h.offset;
        _put(r.copyWith(
          etag: h.etag,
          lastModified: h.lastModified,
          contentType: h.contentType,
          task: rebuildTask(r.task, receivedBytes: h.offset, totalBytes: h.totalBytes ?? auth.expectedBytes),
        ));
        _changed();
      },
      onProgress: (received, total) {
        final r = _records[run.id];
        if (r == null) return;
        run.meter.add(received - run.lastReceived);
        run.lastReceived = received;
        _put(r.copyWith(
          task: rebuildTask(r.task,
              receivedBytes: received,
              totalBytes: total ?? r.task.totalBytes,
              bytesPerSecond: run.meter.bytesPerSecond),
        ));
        _changed(immediate: false);
      },
    );
    run.cancel.throwIfCanceled();

    current = _records[run.id];
    if (current == null) throw const OperationCanceledException();
    _put(current.copyWith(task: rebuildTask(current.task, status: DownloadStatus.verifying, bytesPerSecond: 0)));
    _changed();

    final verified = await IntegrityChecker.verify(
      partial,
      expectedBytes: auth.expectedBytes,
      declaredBytes: result.headers.totalBytes,
      expectedSha256: auth.expectedSha256,
      strict: _settings.current.downloads.verifyIntegrity,
    );
    run.cancel.throwIfCanceled();
    final extension = AudioSniffer.chooseExtension(
      suggested: auth.suggestedFileExtension,
      contentType: result.headers.contentType,
      sniffed: verified.sniff,
    );

    // Artwork + library metadata before the task is reported completed, so
    // "completed" means fully usable offline.
    final artworkUrl = track.artworkUrl;
    if (artworkUrl != null && (artworkUrl.scheme == 'http' || artworkUrl.scheme == 'https')) {
      await _artwork
          .pin(artworkUrl, cancel: run.cancel)
          .timeout(_options.artworkTimeout, onTimeout: () => false)
          .catchError((Object _) => false);
    }
    final updatedTrack = await _updateLibrary(track, verified);
    run.cancel.throwIfCanceled();

    await _withFsLock(() => _finalize(run, partial, verified, extension, updatedTrack));
    return true;
  }

  Future<Track> _updateLibrary(Track track, VerifiedFile verified) async {
    final f = track.format;
    final updated = track.copyWith(
      availability: track.availability.copyWith(offline: OfflineRights.downloadable, checkedAt: DateTime.now()),
      format: AudioFormatInfo(
        codec: verified.sniff.container?.codec ?? f?.codec,
        bitrateKbps: f?.bitrateKbps,
        sampleRateHz: f?.sampleRateHz,
        channels: f?.channels,
        bitsPerSample: f?.bitsPerSample,
        fileSizeBytes: verified.sizeBytes,
      ),
    );
    try {
      await _tracks.upsertTracks([updated]);
    } catch (e) {
      _log.warning('Could not update library metadata for ${track.id}', e);
    }
    return updated;
  }

  /// Moves the verified file into the library layout (or reuses an identical
  /// existing download) and marks the task completed. Runs under the fs lock.
  Future<void> _finalize(_ActiveRun run, File partial, VerifiedFile verified, String extension, Track track) async {
    run.cancel.throwIfCanceled();
    final record = _records[run.id];
    if (record == null) throw const OperationCanceledException();
    final duplicate = _records.values.firstWhereOrNull((r) =>
        r.id != run.id &&
        r.status == DownloadStatus.completed &&
        r.task.sha256 == verified.sha256 &&
        r.task.filePath != null &&
        File(r.task.filePath!).existsSync());
    final String path;
    if (duplicate != null) {
      path = duplicate.task.filePath!;
      await partial.delete();
      _log.info('${track.id} is identical to ${duplicate.task.trackId}; sharing $path');
    } else {
      path = await DownloadPathBuilder.uniqueTarget(_downloadDir, track, extension);
      await _mover.move(partial, path);
    }
    final now = DateTime.now();
    final completedTask = rebuildTask(
      record.task,
      track: track,
      status: DownloadStatus.completed,
      filePath: path,
      sha256: verified.sha256,
      completedAt: now,
      receivedBytes: verified.sizeBytes,
      totalBytes: verified.sizeBytes,
      bytesPerSecond: 0,
      error: null,
    );
    _put(record.copyWith(
      task: completedTask,
      partialPath: null,
      fileSize: verified.sizeBytes,
      nextAttemptAt: null,
    ));
    _batch.recordCompleted(completedTask);
    _log.info('Downloaded ${track.id} → $path (${verified.sizeBytes} B)');
    _changed();
  }

  Future<void> _onStopped(_ActiveRun run) async {
    final r = _records[run.id];
    if (r == null) return;
    final partialBytes = await fileSize(r.partialPath);
    switch (run.intent) {
      case _StopIntent.cancel:
        await _deletePartial(r);
        _put(r.copyWith(
          task: rebuildTask(r.task, status: DownloadStatus.canceled, receivedBytes: 0, bytesPerSecond: 0),
          partialPath: null,
          etag: null,
          lastModified: null,
          nextAttemptAt: null,
        ));
      case _StopIntent.pause:
        _put(r.copyWith(
            task: rebuildTask(r.task, status: DownloadStatus.paused, receivedBytes: partialBytes, bytesPerSecond: 0)));
      case _StopIntent.network:
        _put(r.copyWith(
            task: rebuildTask(r.task,
                status: DownloadStatus.waitingForNetwork, receivedBytes: partialBytes, bytesPerSecond: 0)));
      case _StopIntent.remove:
        return;
      case _StopIntent.shutdown || null:
        _put(r.copyWith(
            task: rebuildTask(r.task, status: DownloadStatus.queued, receivedBytes: partialBytes, bytesPerSecond: 0)));
    }
    _changed();
  }

  Future<void> _onFailed(_ActiveRun run, Object error, StackTrace stack) async {
    final r = _records[run.id];
    if (r == null) return;
    final failure = DownloadFailure.classify(error);
    var record = r;
    if (failure.discardPartial) {
      await _deletePartial(record);
      record = record.copyWith(partialPath: null, etag: null, lastModified: null);
    }
    final partialBytes = await fileSize(record.partialPath);
    final networkGone = (failure.code == DownloadErrorCode.network || failure.code == DownloadErrorCode.timeout) &&
        _policy.evaluate() != null;
    if (networkGone) {
      // Connectivity dropped: wait for it instead of burning an attempt.
      _put(record.copyWith(
          task: rebuildTask(record.task,
              status: DownloadStatus.waitingForNetwork, receivedBytes: partialBytes, bytesPerSecond: 0)));
      _changed();
      return;
    }
    final attempts = record.task.attempts + 1;
    if (failure.retryable && attempts < _options.maxAttempts) {
      final delay = _options.backoff(attempts, retryAfter: failure.retryAfter);
      _log.info('Download ${run.id} failed (${failure.code}); retry $attempts/${_options.maxAttempts - 1} '
          'in ${delay.inMilliseconds} ms');
      _put(record.copyWith(
        task: rebuildTask(record.task,
            status: DownloadStatus.queued,
            attempts: attempts,
            error: failure.code,
            receivedBytes: partialBytes,
            bytesPerSecond: 0),
        nextAttemptAt: DateTime.now().add(delay),
      ));
    } else {
      _log.warning('Download ${run.id} (${record.task.trackId}) failed: ${failure.code}', error,
          failure.code == DownloadErrorCode.unknown ? stack : null);
      final failed = rebuildTask(record.task,
          status: DownloadStatus.failed,
          attempts: attempts,
          error: failure.code,
          receivedBytes: partialBytes,
          bytesPerSecond: 0);
      _put(record.copyWith(task: failed, nextAttemptAt: null));
      _batch.recordFailed(failed);
    }
    _changed();
  }

  Future<void> _deletePartial(DownloadRecord r) async {
    final path = r.partialPath ?? _partialPathFor(r.id);
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } on FileSystemException catch (e) {
      _log.fine('Could not delete partial $path', e);
    }
  }

  /// Restores a persisted record after a restart.
  Future<DownloadRecord> _restore(DownloadRecord r) async {
    final partialBytes = await fileSize(r.partialPath);
    switch (r.status) {
      case DownloadStatus.downloading ||
            DownloadStatus.verifying ||
            DownloadStatus.waitingForNetwork ||
            DownloadStatus.queued:
        return r.copyWith(
          task: rebuildTask(r.task, status: DownloadStatus.queued, receivedBytes: partialBytes, bytesPerSecond: 0),
          nextAttemptAt: null,
          etag: partialBytes == 0 ? null : r.etag,
          lastModified: partialBytes == 0 ? null : r.lastModified,
        );
      case DownloadStatus.completed:
        final path = r.task.filePath;
        if (path == null || !await File(path).exists()) {
          _log.warning('Downloaded file of ${r.task.trackId} is missing: $path');
          return r.copyWith(task: rebuildTask(r.task, status: DownloadStatus.failed, error: DownloadErrorCode.fileMissing));
        }
        return r;
      case DownloadStatus.paused || DownloadStatus.failed || DownloadStatus.canceled:
        return r.copyWith(task: rebuildTask(r.task, receivedBytes: partialBytes, bytesPerSecond: 0));
    }
  }

  Future<void> _deleteOrphanPartials() async {
    final known = {for (final r in _records.values) r.partialPath ?? _partialPathFor(r.id)};
    try {
      await for (final entity in _paths.tempDownloadDir.list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.part') && !known.contains(entity.path)) {
          await entity.delete();
        }
      }
    } on FileSystemException catch (e) {
      _log.fine('Could not clean partial downloads', e);
    }
  }
}
