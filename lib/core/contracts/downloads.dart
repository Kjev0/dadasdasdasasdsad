import '../models/download.dart';
import '../models/track.dart';

/// Offline downloads. Only tracks whose source explicitly authorizes
/// downloading (`MusicSource.authorizeDownload` returns non-null) are ever
/// downloaded. Stream URLs are never saved as files.
abstract class DownloadManager {
  Future<void> init();

  List<DownloadTask> get tasks;
  Stream<List<DownloadTask>> get tasksStream;

  /// Classifies [track] into the four offline categories.
  Future<DownloadEligibility> checkEligibility(Track track);

  /// Throws `DownloadNotPermittedException` if not allowed.
  Future<DownloadTask> enqueue(Track track, {String? origin});

  /// Enqueues the allowed ones; returns how many were rejected and why.
  Future<Map<String, DownloadEligibility>> enqueueAll(List<Track> tracks, {String? origin});

  Future<void> pause(String taskId);
  Future<void> resume(String taskId);
  Future<void> retry(String taskId);
  Future<void> cancel(String taskId);
  Future<void> pauseAll();
  Future<void> resumeAll();

  /// Remove a finished/failed task; optionally delete the file.
  Future<void> remove(String taskId, {bool deleteFile = true});

  /// Delete the offline copy of a track.
  Future<void> deleteDownload(String trackId);

  /// Path of a completed, integrity-checked download for [trackId], if any.
  Future<String?> localFileFor(String trackId);

  bool isDownloaded(String trackId);

  /// Ids of tracks with completed downloads (for "Downloaded" filters).
  Stream<Set<String>> watchDownloadedIds();

  Future<StorageUsage> storageUsage();

  /// Remove least-recently-played downloads/caches until under the limit.
  /// Returns bytes freed.
  Future<int> enforceStorageLimit();

  Future<int> clearArtworkCache();

  /// Re-verify all completed files (size + SHA-256). Returns broken task ids.
  Future<List<String>> verifyAll();

  /// Move downloads to a new directory.
  Future<void> changeDownloadDirectory(String newPath);

  /// Sync auto-download playlists (enqueue missing permitted tracks).
  Future<void> syncAutoDownloads();

  Future<void> dispose();
}
