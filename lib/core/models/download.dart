import 'package:flutter/foundation.dart';

import 'track.dart';

enum DownloadStatus {
  queued,

  /// Waiting because of the Wi-Fi-only / data-saver policy or no network.
  waitingForNetwork,
  downloading,
  verifying,
  paused,
  completed,
  failed,
  canceled,
}

@immutable
class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.track,
    required this.status,
    required this.createdAt,
    this.receivedBytes = 0,
    this.totalBytes,
    this.bytesPerSecond = 0,
    this.error,
    this.filePath,
    this.completedAt,
    this.sha256,
    this.attempts = 0,
    this.origin,
  });

  final String id;
  final Track track;
  final DownloadStatus status;
  final DateTime createdAt;
  final int receivedBytes;
  final int? totalBytes;
  final double bytesPerSecond;

  /// Localizable error code or message for [DownloadStatus.failed].
  final String? error;
  final String? filePath;
  final DateTime? completedAt;
  final String? sha256;
  final int attempts;

  /// e.g. `playlist:<id>` when auto-downloaded for a playlist.
  final String? origin;

  String get trackId => track.id;

  double? get progress =>
      totalBytes == null || totalBytes == 0 ? null : (receivedBytes / totalBytes!).clamp(0.0, 1.0);

  bool get isActive =>
      status == DownloadStatus.queued ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.verifying ||
      status == DownloadStatus.waitingForNetwork;

  DownloadTask copyWith({
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    double? bytesPerSecond,
    String? error,
    bool clearError = false,
    String? filePath,
    DateTime? completedAt,
    String? sha256,
    int? attempts,
  }) =>
      DownloadTask(
        id: id,
        track: track,
        status: status ?? this.status,
        createdAt: createdAt,
        receivedBytes: receivedBytes ?? this.receivedBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
        error: clearError ? null : (error ?? this.error),
        filePath: filePath ?? this.filePath,
        completedAt: completedAt ?? this.completedAt,
        sha256: sha256 ?? this.sha256,
        attempts: attempts ?? this.attempts,
        origin: origin,
      );
}

/// Why a track can or cannot be downloaded.
enum DownloadEligibilityKind {
  /// Already a user-owned local file — nothing to download.
  alreadyLocal,

  /// Already downloaded.
  alreadyDownloaded,

  /// The source explicitly permits downloading.
  allowed,

  /// Stream-only: the source does not permit third-party downloads.
  streamOnly,

  /// Not available at all (deleted, region-restricted, not connected, ...).
  unavailable,
}

@immutable
class DownloadEligibility {
  const DownloadEligibility(this.kind, {this.reason});

  final DownloadEligibilityKind kind;

  /// An `AvailabilityReason` code or short explanation.
  final String? reason;

  bool get canDownload => kind == DownloadEligibilityKind.allowed;
}

/// A direct, authorized download location returned by a source.
@immutable
class DownloadAuthorization {
  const DownloadAuthorization({
    required this.uri,
    this.headers = const {},
    this.suggestedFileExtension,
    this.expectedBytes,
    this.expectedSha256,
  });

  final Uri uri;
  final Map<String, String> headers;
  final String? suggestedFileExtension;
  final int? expectedBytes;
  final String? expectedSha256;
}

@immutable
class StorageUsage {
  const StorageUsage({
    required this.downloadsBytes,
    required this.downloadCount,
    required this.artworkCacheBytes,
    required this.streamCacheBytes,
    required this.databaseBytes,
    this.freeDiskBytes,
    this.downloadLimitBytes,
  });

  final int downloadsBytes;
  final int downloadCount;
  final int artworkCacheBytes;
  final int streamCacheBytes;
  final int databaseBytes;
  final int? freeDiskBytes;

  /// Null = unlimited.
  final int? downloadLimitBytes;

  int get totalBytes => downloadsBytes + artworkCacheBytes + streamCacheBytes + databaseBytes;
}
