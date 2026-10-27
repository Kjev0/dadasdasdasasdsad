import 'package:logging/logging.dart';

import '../../core/contracts/library.dart';
import '../../core/models/download.dart';
import '../../core/models/track.dart';

final _log = Logger('downloads.storage');

/// LRU ordering for the download storage limit.
abstract final class StoragePolicy {
  /// Most recent `playedAt` for each of [trackIds], paging through
  /// [HistoryRepository.history] (newest first) until every id was seen or
  /// [maxRecords] were scanned.
  static Future<Map<String, DateTime>> lastPlayed(
    HistoryRepository history,
    Set<String> trackIds, {
    int pageSize = 500,
    int maxRecords = 20000,
  }) async {
    final result = <String, DateTime>{};
    if (trackIds.isEmpty) return result;
    DateTime? before;
    var scanned = 0;
    try {
      while (scanned < maxRecords && result.length < trackIds.length) {
        final page = await history.history(limit: pageSize, before: before);
        if (page.isEmpty) break;
        DateTime? oldest;
        for (final record in page) {
          final id = record.track.id;
          if (trackIds.contains(id)) {
            final known = result[id];
            if (known == null || record.playedAt.isAfter(known)) result[id] = record.playedAt;
          }
          if (oldest == null || record.playedAt.isBefore(oldest)) oldest = record.playedAt;
        }
        scanned += page.length;
        if (page.length < pageSize || oldest == null || oldest == before) break;
        before = oldest;
      }
    } catch (e) {
      _log.warning('Could not read listening history for LRU; falling back to completion time', e);
    }
    return result;
  }

  /// Completed, evictable tasks ordered least-recently-used first. The "last
  /// used" time is the later of the last play and the download completion
  /// (a fresh download counts as use, so it is not evicted immediately).
  /// User-owned local tracks and [protect]ed ids are never included.
  static List<DownloadTask> evictionOrder(
    Iterable<DownloadTask> tasks,
    Map<String, DateTime> lastPlayed, {
    Set<String> protect = const {},
  }) {
    DateTime lastUse(DownloadTask t) {
      final played = lastPlayed[t.trackId];
      final completed = t.completedAt ?? t.createdAt;
      return played != null && played.isAfter(completed) ? played : completed;
    }

    final candidates = tasks
        .where((t) =>
            t.status == DownloadStatus.completed &&
            t.filePath != null &&
            !t.track.isLocal &&
            t.track.availability.offline != OfflineRights.userOwned &&
            !protect.contains(t.id))
        .toList()
      ..sort((a, b) => lastUse(a).compareTo(lastUse(b)));
    return candidates;
  }
}
