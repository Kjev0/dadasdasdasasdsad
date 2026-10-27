import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/contracts/library.dart';
import '../../core/errors.dart';
import '../../core/models/catalog.dart';
import '../../core/models/library.dart';
import '../../core/models/track.dart';
import '../change_bus.dart';
import '../db/database.dart';
import '../db/sql_utils.dart';
import 'smart_rules.dart';
import 'track_link_repository.dart';
import 'track_query_sql.dart';
import 'track_store.dart';

final _log = Logger('library.playlists');

/// SQLite implementation of [PlaylistRepository].
///
/// Positions in the API are 0-based indexes into the ordered entry list.
/// Smart playlists store their rules as JSON and are evaluated on read
/// (in SQL; rules SQL cannot express are filtered in Dart, see
/// [SmartRulesSql]). Smart playlists cannot be edited entry-by-entry.
class SqlPlaylistRepository implements PlaylistRepository {
  SqlPlaylistRepository(this._db, this._bus, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final FermataDatabase _db;
  final LibraryChangeBus _bus;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  Database get _d => _db.db;

  void _changed() => notifyLibrary(_bus, {LibraryTopic.playlists});

  @override
  Future<List<Playlist>> playlists() async {
    final rows = await _d.rawQuery('''
      SELECT p.*, (SELECT COUNT(*) FROM playlist_entries e WHERE e.playlist_id = p.id) AS n
      FROM playlists p ORDER BY p.name COLLATE NOCASE, p.created_at''');
    final out = <Playlist>[];
    for (final r in rows) {
      var count = (r['n'] as num).toInt();
      if (r['kind'] == PlaylistKind.smart.name) count = await _smartCount(r['smart_rules'] as String?);
      out.add(_decode(r, count));
    }
    return out;
  }

  @override
  Future<Playlist?> getPlaylist(String id) async {
    final rows = await _d.rawQuery('''
      SELECT p.*, (SELECT COUNT(*) FROM playlist_entries e WHERE e.playlist_id = p.id) AS n
      FROM playlists p WHERE p.id = ?''', [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    final count = r['kind'] == PlaylistKind.smart.name ? await _smartCount(r['smart_rules'] as String?) : (r['n'] as num).toInt();
    return _decode(r, count);
  }

  Playlist _decode(Map<String, Object?> r, int count) => Playlist(
        id: r['id'] as String,
        name: r['name'] as String,
        kind: PlaylistKind.values.asNameMap()[r['kind']] ?? PlaylistKind.local,
        description: r['description'] as String?,
        artworkUrl: r['artwork_url'] == null ? null : Uri.tryParse(r['artwork_url'] as String),
        ownerName: r['owner_name'] as String?,
        sourceId: r['source_id'] as String?,
        sourcePlaylistId: r['source_playlist_id'] as String?,
        trackCount: count,
        createdAt: msToDate(r['created_at']),
        updatedAt: msToDate(r['updated_at']),
        autoDownload: intBool(r['auto_download']),
        smartRulesJson: r['smart_rules'] as String?,
        permalink: r['permalink'] == null ? null : Uri.tryParse(r['permalink'] as String),
      );

  @override
  Future<Playlist> createPlaylist(
    String name, {
    String? description,
    String? sourceId,
    String? sourcePlaylistId,
    Uri? artworkUrl,
  }) =>
      _insert(name: name, kind: PlaylistKind.local, description: description, sourceId: sourceId, sourcePlaylistId: sourcePlaylistId, artworkUrl: artworkUrl);

  @override
  Future<Playlist> createSmartPlaylist(String name, SmartPlaylistRules rules, {String? description}) =>
      _insert(name: name, kind: PlaylistKind.smart, description: description, smartRules: jsonEncode(rules.toJson()));

  Future<Playlist> _insert({
    required String name,
    required PlaylistKind kind,
    String? description,
    String? sourceId,
    String? sourcePlaylistId,
    Uri? artworkUrl,
    String? smartRules,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'must not be empty');
    final id = _uuid.v4();
    final now = _clock().millisecondsSinceEpoch;
    await _d.insert('playlists', {
      'id': id,
      'name': trimmed,
      'description': description,
      'kind': kind.name,
      'artwork_url': artworkUrl?.toString(),
      'source_id': sourceId,
      'source_playlist_id': sourcePlaylistId,
      'created_at': now,
      'updated_at': now,
      'auto_download': 0,
      'smart_rules': smartRules,
    });
    _changed();
    return (await getPlaylist(id))!;
  }

  @override
  Future<void> updatePlaylist(Playlist playlist) async {
    final name = playlist.name.trim();
    if (name.isEmpty) throw ArgumentError.value(playlist.name, 'name', 'must not be empty');
    final n = await _d.update(
      'playlists',
      {
        'name': name,
        'description': playlist.description,
        'artwork_url': playlist.artworkUrl?.toString(),
        'owner_name': playlist.ownerName,
        'auto_download': boolInt(playlist.autoDownload),
        'smart_rules': playlist.kind == PlaylistKind.smart ? playlist.smartRulesJson : null,
        'permalink': playlist.permalink?.toString(),
        'updated_at': _clock().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [playlist.id],
    );
    if (n == 0) throw StorageException('playlist_not_found', 'Playlist ${playlist.id} does not exist');
    _changed();
  }

  @override
  Future<void> deletePlaylist(String id) async {
    final n = await _d.delete('playlists', where: 'id = ?', whereArgs: [id]);
    if (n > 0) _changed();
  }

  @override
  Future<List<String>> playlistTrackIds(String id) async {
    final rows = await _d.query('playlists', columns: ['kind', 'smart_rules'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return const [];
    if (rows.first['kind'] == PlaylistKind.smart.name) {
      return evaluateSmart(_rules(rows.first['smart_rules'] as String?));
    }
    final entries = await _d.rawQuery(
      'SELECT track_id FROM playlist_entries WHERE playlist_id = ? ORDER BY position, entry_id',
      [id],
    );
    return [for (final e in entries) e['track_id'] as String];
  }

  @override
  Future<List<Track>> playlistTracks(String id) async => TrackStore.byIds(_d, await playlistTrackIds(id));

  SmartPlaylistRules _rules(String? json) {
    if (json == null) return const SmartPlaylistRules(rules: []);
    try {
      return SmartPlaylistRules.fromJson((jsonDecode(json) as Map).cast<String, Object?>());
    } catch (e) {
      _log.warning('Invalid smart playlist rules', e);
      return const SmartPlaylistRules(rules: [], limit: 0);
    }
  }

  Future<int> _smartCount(String? rulesJson) async => (await evaluateSmart(_rules(rulesJson))).length;

  /// Track ids matching [rules] (sorted and limited as the rules say).
  Future<List<String>> evaluateSmart(SmartPlaylistRules rules) async {
    final now = _clock();
    final compiled = [for (final r in rules.rules) SmartRulesSql.compile(r, now)];
    final dartRules = [
      for (var i = 0; i < rules.rules.length; i++)
        if (compiled[i] == null) rules.rules[i],
    ];
    final sqlParts = [for (final c in compiled) ?c];
    final order = TrackQuerySql.orderBy(rules.sort, rules.descending);
    final from = 'FROM tracks t $playStatsJoin';
    if (dartRules.isEmpty) {
      final where = sqlParts.isEmpty ? '' : ' WHERE ${sqlParts.map((f) => '(${f.sql})').join(rules.matchAll ? ' AND ' : ' OR ')}';
      final rows = await _d.rawQuery(
        'SELECT t.id $from$where ORDER BY $order${TrackQuerySql.limitClause(rules.limit, 0)}',
        [for (final f in sqlParts) ...f.args],
      );
      return [for (final r in rows) r['id'] as String];
    }
    // Mixed evaluation: SQL narrows (AND) or flags (OR), Dart decides.
    final String sql;
    final args = <Object?>[for (final f in sqlParts) ...f.args];
    final combined = sqlParts.map((f) => '(${f.sql})').join(rules.matchAll ? ' AND ' : ' OR ');
    if (rules.matchAll) {
      sql = 'SELECT t.id, ${SmartRulesSql.contextColumns}, 0 AS sql_match $from'
          '${combined.isEmpty ? '' : ' WHERE $combined'} ORDER BY $order';
    } else {
      sql = 'SELECT t.id, ${SmartRulesSql.contextColumns}, ${combined.isEmpty ? '0' : '($combined)'} AS sql_match '
          '$from ORDER BY $order';
    }
    final rows = await _d.rawQuery(sql, args);
    final out = <String>[];
    for (final r in rows) {
      final ctx = SmartRowContext.fromRow(r);
      final bool keep;
      if (rules.matchAll) {
        keep = dartRules.every((rule) => SmartRulesSql.evaluate(rule, ctx, now));
      } else {
        keep = intBool(r['sql_match']) || dartRules.any((rule) => SmartRulesSql.evaluate(rule, ctx, now));
      }
      if (keep) {
        out.add(r['id'] as String);
        if (rules.limit != null && out.length >= rules.limit!) break;
      }
    }
    return out;
  }

  Future<String> _requireEditable(DatabaseExecutor ex, String playlistId) async {
    final rows = await ex.query('playlists', columns: ['kind'], where: 'id = ?', whereArgs: [playlistId]);
    if (rows.isEmpty) throw StorageException('playlist_not_found', 'Playlist $playlistId does not exist');
    final kind = rows.first['kind'] as String;
    if (kind == PlaylistKind.smart.name) {
      throw const StorageException('smart_playlist_read_only', 'Smart playlist entries are computed from rules');
    }
    return kind;
  }

  Future<List<Map<String, Object?>>> _entries(DatabaseExecutor ex, String playlistId) => ex.rawQuery(
        'SELECT entry_id, track_id, position FROM playlist_entries WHERE playlist_id = ? ORDER BY position, entry_id',
        [playlistId],
      );

  /// Rewrites positions 0..n-1 for [ordered] entries (only rows that changed).
  Future<void> _renumber(DatabaseExecutor ex, List<Map<String, Object?>> ordered) async {
    final batch = ex.batch();
    for (var i = 0; i < ordered.length; i++) {
      if ((ordered[i]['position'] as num?)?.toInt() != i) {
        batch.update('playlist_entries', {'position': i}, where: 'entry_id = ?', whereArgs: [ordered[i]['entry_id']]);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> _touch(DatabaseExecutor ex, String playlistId) =>
      ex.update('playlists', {'updated_at': _clock().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [playlistId]);

  @override
  Future<void> addTracks(String playlistId, List<String> trackIds, {int? position}) async {
    if (trackIds.isEmpty) return;
    await _d.transaction((txn) async {
      await _requireEditable(txn, playlistId);
      final known = await TrackStore.existingIds(txn, trackIds);
      final missing = trackIds.where((id) => !known.contains(id)).toSet();
      if (missing.isNotEmpty) {
        throw StorageException('track_not_in_library', 'Upsert tracks before adding them to a playlist: ${missing.take(3).join(', ')}');
      }
      final entries = List<Map<String, Object?>>.of(await _entries(txn, playlistId));
      final at = (position ?? entries.length).clamp(0, entries.length);
      final now = _clock().millisecondsSinceEpoch;
      // Shift the tail, then insert the new block at [at].
      await _renumber(txn, entries.sublist(0, at));
      final tail = entries.sublist(at);
      final batch = txn.batch();
      for (var i = 0; i < tail.length; i++) {
        batch.update('playlist_entries', {'position': at + trackIds.length + i}, where: 'entry_id = ?', whereArgs: [tail[i]['entry_id']]);
      }
      for (var i = 0; i < trackIds.length; i++) {
        batch.insert('playlist_entries', {
          'playlist_id': playlistId,
          'position': at + i,
          'track_id': trackIds[i],
          'added_at': now,
        });
      }
      await batch.commit(noResult: true);
      await _touch(txn, playlistId);
    });
    _changed();
  }

  @override
  Future<void> removeAt(String playlistId, List<int> positions) async {
    if (positions.isEmpty) return;
    await _d.transaction((txn) async {
      await _requireEditable(txn, playlistId);
      final entries = await _entries(txn, playlistId);
      final drop = positions.where((p) => p >= 0 && p < entries.length).toSet();
      await _deleteEntries(txn, [for (final p in drop) entries[p]['entry_id'] as int]);
      await _renumber(txn, [for (var i = 0; i < entries.length; i++) if (!drop.contains(i)) entries[i]]);
      await _touch(txn, playlistId);
    });
    _changed();
  }

  @override
  Future<void> removeTracks(String playlistId, List<String> trackIds) async {
    if (trackIds.isEmpty) return;
    final ids = trackIds.toSet();
    await _d.transaction((txn) async {
      await _requireEditable(txn, playlistId);
      final entries = await _entries(txn, playlistId);
      await _deleteEntries(txn, [for (final e in entries) if (ids.contains(e['track_id'])) e['entry_id'] as int]);
      await _renumber(txn, [for (final e in entries) if (!ids.contains(e['track_id'])) e]);
      await _touch(txn, playlistId);
    });
    _changed();
  }

  Future<void> _deleteEntries(DatabaseExecutor ex, List<int> entryIds) async {
    for (final chunk in chunked(entryIds)) {
      await ex.rawDelete('DELETE FROM playlist_entries WHERE entry_id IN (${placeholders(chunk.length)})', chunk);
    }
  }

  @override
  Future<void> move(String playlistId, int from, int to) async {
    await _d.transaction((txn) async {
      await _requireEditable(txn, playlistId);
      final entries = List<Map<String, Object?>>.of(await _entries(txn, playlistId));
      if (from < 0 || from >= entries.length) throw RangeError.range(from, 0, entries.length - 1, 'from');
      final target = to.clamp(0, entries.length - 1);
      if (target == from) return;
      final item = entries.removeAt(from);
      entries.insert(target, item);
      await _renumber(txn, entries);
      await _touch(txn, playlistId);
    });
    _changed();
  }

  /// Keeps the first occurrence of each track and of each link group
  /// (e.g. the Spotify original and its SoundCloud match).
  @override
  Future<int> deduplicate(String playlistId) async {
    var removed = 0;
    await _d.transaction((txn) async {
      await _requireEditable(txn, playlistId);
      final entries = await _entries(txn, playlistId);
      final groups = await linkGroupKeys(txn, entries.map((e) => e['track_id'] as String));
      final seen = <String>{};
      final keep = <Map<String, Object?>>[];
      final drop = <int>[];
      for (final e in entries) {
        final key = groups[e['track_id']] ?? e['track_id'] as String;
        if (seen.add(key)) {
          keep.add(e);
        } else {
          drop.add(e['entry_id'] as int);
        }
      }
      removed = drop.length;
      if (drop.isEmpty) return;
      await _deleteEntries(txn, drop);
      await _renumber(txn, keep);
      await _touch(txn, playlistId);
    });
    if (removed > 0) _changed();
    return removed;
  }

  @override
  Future<List<Playlist>> autoDownloadPlaylists() async => [
        for (final p in await playlists())
          if (p.autoDownload) p,
      ];

  /// Sets the auto-download flag without touching other fields.
  Future<void> setAutoDownload(String playlistId, bool enabled) async {
    final n = await _d.update('playlists', {'auto_download': boolInt(enabled)}, where: 'id = ?', whereArgs: [playlistId]);
    if (n > 0) _changed();
  }

  /// Raw rows for backup: playlists with their entries.
  Future<List<Map<String, Object?>>> exportRows() async {
    final out = <Map<String, Object?>>[];
    for (final p in await _d.query('playlists', orderBy: 'created_at, id')) {
      final entries = await _d.rawQuery(
        'SELECT track_id, added_at FROM playlist_entries WHERE playlist_id = ? ORDER BY position, entry_id',
        [p['id']],
      );
      out.add({...p, 'entries': entries.map((e) => {...e}).toList()});
    }
    return out;
  }

  /// Track ids referenced by any playlist entry.
  static Future<Set<String>> referencedTrackIds(DatabaseExecutor ex) async =>
      {for (final r in await ex.rawQuery('SELECT DISTINCT track_id FROM playlist_entries')) r['track_id'] as String};

  /// Helper so tests and services can decode [Playlist.smartRulesJson].
  static SmartPlaylistRules? rulesOf(Playlist p) => p.smartRulesJson == null
      ? null
      : SmartPlaylistRules.fromJson((jsonDecode(p.smartRulesJson!) as Map).cast<String, Object?>());
}
