import 'package:flutter/foundation.dart';

import '../../core/models/download.dart';
import '../../core/models/track.dart';

const Object _keep = Object();

/// Rebuilds a [DownloadTask] with nullable fields that `copyWith` cannot
/// clear (file path, completion time, hash, error).
DownloadTask rebuildTask(
  DownloadTask t, {
  DownloadStatus? status,
  Track? track,
  int? receivedBytes,
  Object? totalBytes = _keep,
  double? bytesPerSecond,
  Object? error = _keep,
  Object? filePath = _keep,
  Object? completedAt = _keep,
  Object? sha256 = _keep,
  int? attempts,
}) =>
    DownloadTask(
      id: t.id,
      track: track ?? t.track,
      status: status ?? t.status,
      createdAt: t.createdAt,
      receivedBytes: receivedBytes ?? t.receivedBytes,
      totalBytes: identical(totalBytes, _keep) ? t.totalBytes : totalBytes as int?,
      bytesPerSecond: bytesPerSecond ?? t.bytesPerSecond,
      error: identical(error, _keep) ? t.error : error as String?,
      filePath: identical(filePath, _keep) ? t.filePath : filePath as String?,
      completedAt: identical(completedAt, _keep) ? t.completedAt : completedAt as DateTime?,
      sha256: identical(sha256, _keep) ? t.sha256 : sha256 as String?,
      attempts: attempts ?? t.attempts,
      origin: t.origin,
    );

/// A [DownloadTask] plus the transfer bookkeeping persisted in the index
/// (resume validators, partial file, retry schedule).
@immutable
class DownloadRecord {
  const DownloadRecord({
    required this.task,
    this.partialPath,
    this.etag,
    this.lastModified,
    this.contentType,
    this.fileSize,
    this.nextAttemptAt,
  });

  final DownloadTask task;

  /// `<tempDownloadDir>/<taskId>.part` while transferring.
  final String? partialPath;

  /// Validators of the partial body for `If-Range`.
  final String? etag;
  final String? lastModified;
  final String? contentType;

  /// Size of the completed file (cheap integrity check in `localFileFor`).
  final int? fileSize;

  /// Earliest time of the next automatic retry (backoff).
  final DateTime? nextAttemptAt;

  String get id => task.id;

  DownloadStatus get status => task.status;

  DownloadRecord copyWith({
    DownloadTask? task,
    Object? partialPath = _keep,
    Object? etag = _keep,
    Object? lastModified = _keep,
    Object? contentType = _keep,
    Object? fileSize = _keep,
    Object? nextAttemptAt = _keep,
  }) =>
      DownloadRecord(
        task: task ?? this.task,
        partialPath: identical(partialPath, _keep) ? this.partialPath : partialPath as String?,
        etag: identical(etag, _keep) ? this.etag : etag as String?,
        lastModified: identical(lastModified, _keep) ? this.lastModified : lastModified as String?,
        contentType: identical(contentType, _keep) ? this.contentType : contentType as String?,
        fileSize: identical(fileSize, _keep) ? this.fileSize : fileSize as int?,
        nextAttemptAt: identical(nextAttemptAt, _keep) ? this.nextAttemptAt : nextAttemptAt as DateTime?,
      );

  Map<String, Object?> toJson() => {
        'id': task.id,
        'track': task.track.toJson(),
        'status': task.status.name,
        'createdAt': task.createdAt.toIso8601String(),
        'received': task.receivedBytes,
        if (task.totalBytes != null) 'total': task.totalBytes,
        if (task.error != null) 'error': task.error,
        if (task.filePath != null) 'file': task.filePath,
        if (task.completedAt != null) 'completedAt': task.completedAt!.toIso8601String(),
        if (task.sha256 != null) 'sha256': task.sha256,
        'attempts': task.attempts,
        if (task.origin != null) 'origin': task.origin,
        if (partialPath != null) 'partial': partialPath,
        if (etag != null) 'etag': etag,
        if (lastModified != null) 'lastModified': lastModified,
        if (contentType != null) 'contentType': contentType,
        if (fileSize != null) 'size': fileSize,
        if (nextAttemptAt != null) 'nextAttemptAt': nextAttemptAt!.toIso8601String(),
      };

  /// Throws on malformed input (the index skips such entries).
  factory DownloadRecord.fromJson(Map<String, Object?> j) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
    final task = DownloadTask(
      id: j['id'] as String,
      track: Track.fromJson((j['track'] as Map).cast<String, Object?>()),
      status: DownloadStatus.values.asNameMap()[j['status']] ?? DownloadStatus.queued,
      createdAt: date(j['createdAt']) ?? DateTime.now(),
      receivedBytes: (j['received'] as num?)?.toInt() ?? 0,
      totalBytes: (j['total'] as num?)?.toInt(),
      error: j['error'] as String?,
      filePath: j['file'] as String?,
      completedAt: date(j['completedAt']),
      sha256: j['sha256'] as String?,
      attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      origin: j['origin'] as String?,
    );
    return DownloadRecord(
      task: task,
      partialPath: j['partial'] as String?,
      etag: j['etag'] as String?,
      lastModified: j['lastModified'] as String?,
      contentType: j['contentType'] as String?,
      fileSize: (j['size'] as num?)?.toInt(),
      nextAttemptAt: date(j['nextAttemptAt']),
    );
  }
}
