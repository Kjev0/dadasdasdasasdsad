import 'dart:io';
import 'dart:isolate';

import '../../core/contracts/library.dart';
import '../../core/models/library.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../change_bus.dart';
import '../db/database.dart';
import '../db/sql_utils.dart';
import 'track_codec.dart';
import 'track_query_sql.dart';
import 'track_store.dart';

/// SQLite implementation of [TrackRepository].
///
/// Upserts keep `date_added` and user tag overrides; local tracks owned by
/// the scanner are not overwritten by upserts (the file is the source of
/// truth — edit them with `LocalLibraryService.editTags`). Reads return the
/// effective track (overrides applied). Local tracks whose file is known to
/// be missing are returned with `AvailabilityReason.fileMissing`.
class SqlTrackRepository implements TrackRepository {
  SqlTrackRepository(this._db, this._bus);

  final FermataDatabase _db;
  final LibraryChangeBus _bus;

  @override
  Future<void> upsertTracks(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    await _db.db.transaction((txn) => TrackStore.upsert(txn, tracks, preserveScanned: true));
    notifyLibrary(_bus, {LibraryTopic.tracks});
  }

  @override
  Future<Track?> getTrack(String id) async {
    final list = await TrackStore.byIds(_db.db, [id]);
    return list.isEmpty ? null : list.first;
  }

  @override
  Future<List<Track>> getTracks(List<String> ids) => TrackStore.byIds(_db.db, ids);

  /// The library track stored for the local file at [path], if any.
  Future<Track?> getTrackByPath(String path) async {
    final rows = await _db.db.rawQuery(
      'SELECT ${TrackCodec.selectColumns} FROM tracks t WHERE t.local_path = ? LIMIT 1',
      [path],
    );
    return rows.isEmpty ? null : TrackCodec.decode(rows.first);
  }

  @override
  Future<List<Track>> query(TrackQuery query) async {
    final where = TrackQuerySql.where(query);
    final join = TrackQuerySql.needsPlayStats(query.sort) ? ' $playStatsJoin' : '';
    final sql = StringBuffer('SELECT ${TrackCodec.selectColumns} FROM tracks t$join');
    if (!where.isEmpty) sql.write(' WHERE ${where.sql}');
    sql.write(' ORDER BY ${TrackQuerySql.orderBy(query.sort, query.descending)}');
    sql.write(TrackQuerySql.limitClause(query.limit, query.offset));
    final rows = await _db.db.rawQuery(sql.toString(), where.args);
    return rows.map(TrackCodec.decode).toList();
  }

  @override
  Future<int> count(TrackQuery query) async {
    final where = TrackQuerySql.where(query);
    final rows = await _db.db.rawQuery(
      'SELECT COUNT(*) AS n FROM tracks t${where.isEmpty ? '' : ' WHERE ${where.sql}'}',
      where.args,
    );
    return (rows.first['n'] as num).toInt();
  }

  @override
  Future<void> removeTracks(List<String> ids) async {
    if (ids.isEmpty) return;
    await _db.db.transaction((txn) async {
      for (final chunk in chunked(ids.toSet().toList())) {
        await txn.rawDelete('DELETE FROM tracks WHERE id IN (${placeholders(chunk.length)})', chunk);
      }
    });
    notifyLibrary(_bus, {
      LibraryTopic.tracks,
      LibraryTopic.playlists,
      LibraryTopic.favorites,
      LibraryTopic.history,
      LibraryTopic.links,
    });
  }

  @override
  Future<List<AlbumSummary>> albums({String? artist, String? text}) async {
    final parts = <String>["t.album_norm IS NOT NULL AND t.album_norm <> ''"];
    final args = <Object?>[];
    if (artist != null) {
      final a = TrackQuerySql.artistMatch(artist);
      parts.add(a.sql);
      args.addAll(a.args);
    }
    final textMatch = TrackQuerySql.textMatch(
      text,
      "(t.album_norm || ' ' || COALESCE(t.album_artist_norm, '') || ' ' || t.artist_norm)",
    );
    if (!textMatch.isEmpty) {
      parts.add(textMatch.sql);
      args.addAll(textMatch.args);
    }
    final rows = await _db.db.rawQuery('''
      SELECT MIN(t.album) AS title,
             MIN(COALESCE(t.album_artist, t.primary_artist)) AS artist,
             COUNT(*) AS n, MAX(t.year) AS year, MAX(t.artwork_url) AS art,
             SUM(t.duration_ms) AS dur
      FROM tracks t WHERE ${parts.join(' AND ')}
      GROUP BY t.album_norm, t.album_artist_norm
      ORDER BY t.album_norm, t.album_artist_norm''', args);
    return [
      for (final r in rows)
        AlbumSummary(
          title: r['title'] as String,
          artist: r['artist'] as String? ?? '',
          trackCount: (r['n'] as num).toInt(),
          year: (r['year'] as num?)?.toInt(),
          artworkUrl: r['art'] == null ? null : Uri.tryParse(r['art'] as String),
          totalDuration: r['dur'] == null ? null : Duration(milliseconds: (r['dur'] as num).toInt()),
        ),
    ];
  }

  @override
  Future<List<ArtistSummary>> artists({String? text}) async {
    final textMatch = TrackQuerySql.textMatch(text, 'ta.name_norm');
    final rows = await _db.db.rawQuery('''
      SELECT MIN(ta.name) AS name, COUNT(DISTINCT ta.track_id) AS n,
             COUNT(DISTINCT t.album_norm) AS albums, MAX(t.artwork_url) AS art
      FROM track_artists ta JOIN tracks t ON t.id = ta.track_id
      WHERE ta.name_norm <> ''${textMatch.isEmpty ? '' : ' AND ${textMatch.sql}'}
      GROUP BY ta.name_norm ORDER BY ta.name_norm''', textMatch.args);
    return [
      for (final r in rows)
        ArtistSummary(
          name: r['name'] as String,
          trackCount: (r['n'] as num).toInt(),
          albumCount: (r['albums'] as num).toInt(),
          artworkUrl: r['art'] == null ? null : Uri.tryParse(r['art'] as String),
        ),
    ];
  }

  @override
  Future<List<String>> genres() async {
    final rows = await _db.db.rawQuery(
      "SELECT MIN(genre) AS g FROM tracks WHERE genre_norm IS NOT NULL AND genre_norm <> '' "
      'GROUP BY genre_norm ORDER BY genre_norm',
    );
    return [for (final r in rows) r['g'] as String];
  }

  /// Groups duplicates within the same source: identical file hash (local
  /// files), identical ISRC, or identical normalized title + artist with
  /// durations within ±2 s. Each track appears in at most one group (first
  /// matching reason wins). Cross-source copies are links, not duplicates.
  @override
  Future<List<DuplicateGroup>> findDuplicates() async {
    final groups = <DuplicateGroup>[];
    final seen = <String>{};

    Future<void> collect(String reason, String keySql, String filter) async {
      final rows = await _db.db.rawQuery('''
        SELECT t.id, $keySql AS k, t.duration_ms, ${TrackCodec.selectColumns}
        FROM tracks t
        WHERE $filter AND $keySql IN (
          SELECT $keySql FROM tracks t WHERE $filter GROUP BY $keySql HAVING COUNT(*) > 1)
        ORDER BY k, t.date_added, t.id''');
      final byKey = <String, List<Map<String, Object?>>>{};
      for (final r in rows) {
        if (seen.contains(r['id'])) continue;
        byKey.putIfAbsent(r['k'] as String, () => []).add(r);
      }
      for (final members in byKey.values) {
        final clusters = reason == 'same_metadata' ? _clusterByDuration(members) : [members];
        for (final c in clusters) {
          if (c.length < 2) continue;
          seen.addAll(c.map((r) => r['id'] as String));
          groups.add(DuplicateGroup(tracks: c.map(TrackCodec.decode).toList(), reason: reason));
        }
      }
    }

    await collect(
      'same_hash',
      't.file_hash',
      "t.file_hash IS NOT NULL AND t.source_id = '${SourceIds.local}' AND t.missing_since IS NULL",
    );
    await collect('same_isrc', "t.source_id || '|' || t.isrc", 't.isrc IS NOT NULL');
    await collect(
      'same_metadata',
      "t.source_id || '|' || t.title_norm || '|' || t.artist_norm",
      "t.title_norm <> '' AND t.artist_norm <> ''",
    );
    return groups;
  }

  static List<List<Map<String, Object?>>> _clusterByDuration(List<Map<String, Object?>> rows) {
    final sorted = [...rows]..sort((a, b) => ((a['duration_ms'] as num?) ?? -1).compareTo((b['duration_ms'] as num?) ?? -1));
    final out = <List<Map<String, Object?>>>[];
    for (final r in sorted) {
      final d = (r['duration_ms'] as num?)?.toInt();
      final last = out.isEmpty ? null : out.last;
      // Compared with the first member (not the previous one): no chaining.
      final firstD = last == null ? null : (last.first['duration_ms'] as num?)?.toInt();
      final fits = last != null && ((d == null && firstD == null) || (d != null && firstD != null && (d - firstD).abs() <= 2000));
      if (fits) {
        last.add(r);
      } else {
        out.add([r]);
      }
    }
    return out;
  }

  /// Checks every local track against the file system (in a background
  /// isolate), records the result in `missing_since` and returns the tracks
  /// whose file is gone.
  @override
  Future<List<Track>> findMissingFiles() async {
    final rows = await _db.db.rawQuery(
      "SELECT id, local_path, missing_since FROM tracks WHERE source_id = '${SourceIds.local}' AND local_path IS NOT NULL",
    );
    if (rows.isEmpty) return const [];
    final paths = [for (final r in rows) r['local_path'] as String];
    final missingPaths = await missingFilesAmong(paths);
    final now = nowMs();
    final missingIds = <String>[];
    var changed = false;
    await _db.db.transaction((txn) async {
      final batch = txn.batch();
      for (final r in rows) {
        final id = r['id'] as String;
        final isMissing = missingPaths.contains(r['local_path']);
        final wasMissing = r['missing_since'] != null;
        if (isMissing) missingIds.add(id);
        if (isMissing != wasMissing) {
          changed = true;
          batch.update('tracks', {'missing_since': isMissing ? now : null}, where: 'id = ?', whereArgs: [id]);
        }
      }
      await batch.commit(noResult: true);
    });
    if (changed) notifyLibrary(_bus, {LibraryTopic.tracks});
    return TrackStore.byIds(_db.db, missingIds);
  }

  /// The subset of [paths] that do not exist, checked in a background isolate.
  static Future<Set<String>> missingFilesAmong(List<String> paths) =>
      Isolate.run(() => {for (final p in paths) if (!File(p).existsSync()) p});

  /// The user's tag override for [id] (partial Track JSON) or null.
  Future<Map<String, Object?>?> overrideOf(String id) => TrackStore.override(_db.db, id);

  /// Replaces the user's tag override (null clears it). Returns the
  /// effective track or null when [id] is unknown.
  Future<Track?> setOverride(String id, Map<String, Object?>? override) async {
    final t = await _db.db.transaction((txn) => TrackStore.setOverride(txn, id, override));
    if (t != null) notifyLibrary(_bus, {LibraryTopic.tracks});
    return t;
  }
}
