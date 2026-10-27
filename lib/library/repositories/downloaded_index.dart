import 'dart:async';

import 'package:logging/logging.dart';

import '../../core/contracts/library.dart';
import '../change_bus.dart';
import '../db/database.dart';
import '../db/sql_utils.dart';

final _log = Logger('library.downloads_index');

/// Mirrors the download manager's set of completed downloads into the
/// `downloaded_tracks` table so `TrackQuery.downloadedOnly`,
/// `offlineAvailableOnly` and the smart-playlist `downloaded` field can be
/// evaluated in SQL.
///
/// The library is created before the download manager (which depends on the
/// repositories), so the stream is attached later with [attach].
class DownloadedTracksIndex {
  DownloadedTracksIndex(this._db, this._bus);

  final FermataDatabase _db;
  final LibraryChangeBus _bus;
  StreamSubscription<Set<String>>? _sub;
  Future<void> _chain = Future.value();

  /// Follows `DownloadManager.watchDownloadedIds()`.
  void attach(Stream<Set<String>> downloadedIds) {
    _sub?.cancel();
    _sub = downloadedIds.listen(
      (ids) => _chain = _chain.then((_) => replaceAll(ids)).catchError((Object e, StackTrace st) {
        _log.warning('Could not update downloaded-tracks index', e, st);
      }),
    );
  }

  /// Replaces the stored set with [ids] (diffed; notifies on change).
  Future<void> replaceAll(Set<String> ids) async {
    var changed = false;
    await _db.db.transaction((txn) async {
      final current = {for (final r in await txn.rawQuery('SELECT track_id FROM downloaded_tracks')) r['track_id'] as String};
      final remove = current.difference(ids).toList();
      final add = ids.difference(current).toList();
      changed = remove.isNotEmpty || add.isNotEmpty;
      for (final chunk in chunked(remove)) {
        await txn.rawDelete('DELETE FROM downloaded_tracks WHERE track_id IN (${placeholders(chunk.length)})', chunk);
      }
      final batch = txn.batch();
      for (final id in add) {
        batch.rawInsert('INSERT OR IGNORE INTO downloaded_tracks(track_id) VALUES (?)', [id]);
      }
      await batch.commit(noResult: true);
    });
    if (changed) notifyLibrary(_bus, {LibraryTopic.tracks});
  }

  /// Waits until queued updates are written (tests, shutdown).
  Future<void> flush() => _chain;

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _chain;
  }
}
