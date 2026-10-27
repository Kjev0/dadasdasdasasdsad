import '../../core/contracts/library.dart';
import '../../core/models/library.dart';
import '../../core/models/track.dart';
import '../change_bus.dart';
import '../db/database.dart';
import '../db/sql_utils.dart';
import 'track_codec.dart';
import 'track_store.dart';

/// SQLite implementation of [HistoryRepository].
///
/// `recordPlay` also upserts the played track so history (and stats) work
/// offline for remote tracks.
class SqlHistoryRepository implements HistoryRepository {
  SqlHistoryRepository(this._db, this._bus, {this.topLimit = 10});

  final FermataDatabase _db;
  final LibraryChangeBus _bus;

  /// Length of the top-tracks/artists/genres lists in [stats].
  final int topLimit;

  @override
  Future<void> recordPlay(PlayRecord record) async {
    await _db.db.transaction((txn) async {
      await TrackStore.upsert(txn, [record.track]);
      await txn.insert('play_history', {
        'track_id': record.track.id,
        'played_at': record.playedAt.millisecondsSinceEpoch,
        'listened_ms': record.listened.inMilliseconds,
        'completed': boolInt(record.completed),
        'origin': record.origin,
      });
    });
    notifyLibrary(_bus, {LibraryTopic.history, LibraryTopic.tracks});
  }

  @override
  Future<List<PlayRecord>> history({int limit = 200, DateTime? before}) async {
    final rows = await _db.db.rawQuery('''
      SELECT h.id, h.played_at, h.listened_ms, h.completed, h.origin, ${TrackCodec.selectColumns}
      FROM play_history h JOIN tracks t ON t.id = h.track_id
      ${before == null ? '' : 'WHERE h.played_at < ?'}
      ORDER BY h.played_at DESC, h.id DESC LIMIT ?''', [?before?.millisecondsSinceEpoch, limit]);
    return [
      for (final r in rows)
        PlayRecord(
          id: (r['id'] as num).toInt(),
          track: TrackCodec.decode(r),
          playedAt: msToDate(r['played_at'])!,
          listened: Duration(milliseconds: (r['listened_ms'] as num).toInt()),
          completed: intBool(r['completed']),
          origin: r['origin'] as String?,
        ),
    ];
  }

  @override
  Future<List<Track>> recentlyPlayed({int limit = 30}) async {
    final rows = await _db.db.rawQuery('''
      SELECT ${TrackCodec.selectColumns}
      FROM (SELECT track_id, MAX(played_at) AS last FROM play_history GROUP BY track_id) h
      JOIN tracks t ON t.id = h.track_id
      ORDER BY h.last DESC LIMIT ?''', [limit]);
    return rows.map(TrackCodec.decode).toList();
  }

  @override
  Future<ListeningStats> stats({DateTime? since}) async {
    final where = since == null ? '' : 'WHERE h.played_at >= ?';
    final args = [?since?.millisecondsSinceEpoch];
    final totals = await _db.db.rawQuery(
      'SELECT COUNT(*) AS n, COALESCE(SUM(h.listened_ms), 0) AS ms FROM play_history h $where',
      args,
    );
    final topTrackRows = await _db.db.rawQuery('''
      SELECT h.n, ${TrackCodec.selectColumns}
      FROM (SELECT track_id, COUNT(*) AS n, MAX(played_at) AS last FROM play_history h $where GROUP BY track_id) h
      JOIN tracks t ON t.id = h.track_id
      ORDER BY h.n DESC, h.last DESC LIMIT ?''', [...args, topLimit]);
    final topArtistRows = await _db.db.rawQuery('''
      SELECT MIN(ta.name) AS name, COUNT(*) AS n
      FROM play_history h JOIN track_artists ta ON ta.track_id = h.track_id AND ta.position = 0
      ${where.isEmpty ? "WHERE ta.name_norm <> ''" : "$where AND ta.name_norm <> ''"}
      GROUP BY ta.name_norm ORDER BY n DESC, ta.name_norm LIMIT ?''', [...args, topLimit]);
    final topGenreRows = await _db.db.rawQuery('''
      SELECT MIN(t.genre) AS name, COUNT(*) AS n
      FROM play_history h JOIN tracks t ON t.id = h.track_id
      ${where.isEmpty ? 'WHERE' : '$where AND'} t.genre_norm IS NOT NULL AND t.genre_norm <> ''
      GROUP BY t.genre_norm ORDER BY n DESC, t.genre_norm LIMIT ?''', [...args, topLimit]);
    // Group by the local calendar day (SQLite 'localtime' uses the same
    // OS time zone as Dart's DateTime).
    final dayRows = await _db.db.rawQuery('''
      SELECT date(h.played_at / 1000, 'unixepoch', 'localtime') AS d, COUNT(*) AS n
      FROM play_history h $where GROUP BY d ORDER BY d''', args);
    final perDay = <DateTime, int>{};
    for (final r in dayRows) {
      final parts = (r['d'] as String).split('-').map(int.parse).toList();
      perDay[DateTime(parts[0], parts[1], parts[2])] = (r['n'] as num).toInt();
    }
    return ListeningStats(
      totalPlays: (totals.first['n'] as num).toInt(),
      totalListened: Duration(milliseconds: (totals.first['ms'] as num).toInt()),
      topTracks: [for (final r in topTrackRows) (TrackCodec.decode(r), (r['n'] as num).toInt())],
      topArtists: [for (final r in topArtistRows) (r['name'] as String, (r['n'] as num).toInt())],
      topGenres: [for (final r in topGenreRows) (r['name'] as String, (r['n'] as num).toInt())],
      playsPerDay: perDay,
    );
  }

  @override
  Future<int> playCount(String trackId) async {
    final rows = await _db.db.rawQuery('SELECT COUNT(*) AS n FROM play_history WHERE track_id = ?', [trackId]);
    return (rows.first['n'] as num).toInt();
  }

  @override
  Future<void> clearHistory() async {
    await _db.db.delete('play_history');
    notifyLibrary(_bus, {LibraryTopic.history});
  }

  /// Raw rows for backup (oldest first).
  Future<List<Map<String, Object?>>> exportRows() =>
      _db.db.query('play_history', columns: ['track_id', 'played_at', 'listened_ms', 'completed', 'origin'], orderBy: 'played_at, id');
}
