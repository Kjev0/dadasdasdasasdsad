import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/contracts/library.dart';
import '../../core/errors.dart';
import '../../core/models/catalog.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../change_bus.dart';
import '../db/database.dart';
import '../db/sql_utils.dart';
import 'track_codec.dart';
import 'track_store.dart';

final _log = Logger('library.maintenance');

/// SQLite implementation of [LibraryMaintenance].
///
/// Backup JSON (`format: fermata.library.backup`, `version: 1`) contains
/// playlists (+ entries), favorites, play history, track links, library
/// folders, search history and every track those reference (with the user's
/// tag overrides). Settings are not included — they have their own export.
class SqlLibraryMaintenance implements LibraryMaintenance {
  SqlLibraryMaintenance(this._db, this._bus, {this.maxSearchEntries = 50});

  static const backupFormat = 'fermata.library.backup';
  static const backupVersion = 1;

  final FermataDatabase _db;
  final LibraryChangeBus _bus;
  final int maxSearchEntries;

  static const _allTopics = {...LibraryTopic.values};

  /// Deletes history, favorites, playlists, links, searches and remote
  /// track metadata. Local files (and their library rows, folders and tag
  /// overrides) are kept, as are remote tracks with a completed download so
  /// downloads stay browsable offline. Audio files are never touched.
  @override
  Future<void> deleteAllUserData() async {
    await _db.db.transaction((txn) async {
      await _clearUserTables(txn, includeFolders: false);
      await txn.rawDelete(
        "DELETE FROM tracks WHERE source_id <> '${SourceIds.local}' "
        'AND id NOT IN (SELECT track_id FROM downloaded_tracks)',
      );
    });
    _log.info('All user library data deleted');
    notifyLibrary(_bus, _allTopics);
  }

  static Future<void> _clearUserTables(DatabaseExecutor txn, {required bool includeFolders}) async {
    for (final table in ['play_history', 'favorites', 'playlist_entries', 'playlists', 'track_links', 'search_history']) {
      await txn.delete(table);
    }
    if (includeFolders) await txn.delete('library_folders');
  }

  @override
  Future<int> databaseSizeBytes() => _db.sizeBytes();

  @override
  Future<Map<String, Object?>> exportBackup() async {
    final d = _db.db;
    final playlists = await d.query('playlists', orderBy: 'created_at, id');
    final playlistJson = <Map<String, Object?>>[];
    for (final p in playlists) {
      final entries = await d.rawQuery(
        'SELECT track_id, added_at FROM playlist_entries WHERE playlist_id = ? ORDER BY position, entry_id',
        [p['id']],
      );
      playlistJson.add({
        'id': p['id'],
        'name': p['name'],
        'description': p['description'],
        'kind': p['kind'],
        'artworkUrl': p['artwork_url'],
        'ownerName': p['owner_name'],
        'sourceId': p['source_id'],
        'sourcePlaylistId': p['source_playlist_id'],
        'createdAt': p['created_at'],
        'updatedAt': p['updated_at'],
        'autoDownload': intBool(p['auto_download']),
        'smartRules': p['smart_rules'] == null ? null : jsonDecode(p['smart_rules'] as String),
        'permalink': p['permalink'],
        'entries': [for (final e in entries) {'trackId': e['track_id'], 'addedAt': e['added_at']}],
      });
    }
    final favorites = await d.query('favorites', orderBy: 'added_at, track_id');
    final history = await d.query('play_history', orderBy: 'played_at, id');
    final links = await d.query('track_links', orderBy: 'a, b');
    final folders = await d.query('library_folders', orderBy: 'path');
    final searches = await d.query('search_history', orderBy: 'searched_at');
    final trackRows = await d.rawQuery('''
      SELECT id, json, override_json, date_added FROM tracks WHERE override_json IS NOT NULL
        OR id IN (SELECT track_id FROM playlist_entries)
        OR id IN (SELECT track_id FROM favorites)
        OR id IN (SELECT track_id FROM play_history)
        OR id IN (SELECT a FROM track_links) OR id IN (SELECT b FROM track_links)
      ORDER BY id''');
    return {
      'format': backupFormat,
      'version': backupVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tracks': [
        for (final r in trackRows)
          {
            'track': TrackCodec.decodeJson(r['json'] as String),
            'dateAdded': r['date_added'],
            if (r['override_json'] != null) 'override': TrackCodec.decodeJson(r['override_json'] as String),
          },
      ],
      'playlists': playlistJson,
      'favorites': [for (final f in favorites) {'trackId': f['track_id'], 'addedAt': f['added_at']}],
      'history': [
        for (final h in history)
          {
            'trackId': h['track_id'],
            'playedAt': h['played_at'],
            'listenedMs': h['listened_ms'],
            'completed': intBool(h['completed']),
            if (h['origin'] != null) 'origin': h['origin'],
          },
      ],
      'links': [
        for (final l in links)
          {'a': l['a'], 'b': l['b'], 'confidence': l['confidence'], 'confirmed': intBool(l['confirmed']), 'createdAt': l['created_at']},
      ],
      'folders': [for (final f in folders) {'path': f['path'], 'watch': intBool(f['watch'])}],
      'searches': [for (final s in searches) {'query': s['query'], 'at': s['searched_at']}],
    };
  }

  /// Restores [backup]. With [merge] (default) existing data is kept and the
  /// backup is added (same playlist id → replaced by the backup version,
  /// identical history entries are not duplicated). Without [merge] the
  /// user tables are cleared first. Runs in one transaction: a malformed
  /// backup changes nothing and throws [StorageException].
  @override
  Future<void> importBackup(Map<String, Object?> backup, {bool merge = true}) async {
    if (backup['format'] != backupFormat) {
      throw const StorageException('backup_invalid', 'Not a Fermata library backup');
    }
    final version = (backup['version'] as num?)?.toInt() ?? 0;
    if (version < 1 || version > backupVersion) {
      throw StorageException('backup_unsupported', 'Unsupported library backup version $version');
    }
    try {
      await _db.db.transaction((txn) async {
        if (!merge) await _clearUserTables(txn, includeFolders: true);
        await _importTracks(txn, _list(backup['tracks']), merge);
        final known = await _knownIds(txn);
        await _importPlaylists(txn, _list(backup['playlists']), known, merge);
        await _importFavorites(txn, _list(backup['favorites']), known);
        await _importHistory(txn, _list(backup['history']), known);
        await _importLinks(txn, _list(backup['links']), known);
        await _importFolders(txn, _list(backup['folders']));
        await _importSearches(txn, _list(backup['searches']));
      });
    } on FermataException {
      rethrow;
    } catch (e) {
      throw StorageException('backup_invalid', 'Library backup could not be restored', cause: e);
    }
    notifyLibrary(_bus, _allTopics);
  }

  static List<Map<String, Object?>> _list(Object? v) =>
      [for (final e in (v as List? ?? const [])) (e as Map).cast<String, Object?>()];

  static Future<Set<String>> _knownIds(DatabaseExecutor txn) async =>
      {for (final r in await txn.rawQuery('SELECT id FROM tracks')) r['id'] as String};

  static Future<void> _importTracks(Transaction txn, List<Map<String, Object?>> items, bool merge) async {
    final tracks = <Track>[];
    final dateAdded = <String, int>{};
    final overrides = <String, Map<String, Object?>>{};
    for (final item in items) {
      final t = Track.fromJson((item['track'] as Map).cast<String, Object?>());
      tracks.add(t);
      final added = (item['dateAdded'] as num?)?.toInt();
      if (added != null) dateAdded[t.id] = added;
      final ov = item['override'];
      if (ov is Map) overrides[t.id] = ov.cast<String, Object?>();
    }
    final existing = await TrackStore.existingIds(txn, tracks.map((t) => t.id));
    // Existing rows keep their (fresher) metadata; only missing ones are added.
    await TrackStore.upsert(txn, [for (final t in tracks) if (!existing.contains(t.id)) t], dateAdded: dateAdded);
    for (final id in existing) {
      final added = dateAdded[id];
      if (added != null) {
        await txn.rawUpdate('UPDATE tracks SET date_added = MIN(date_added, ?) WHERE id = ?', [added, id]);
      }
    }
    for (final e in overrides.entries) {
      // A merge keeps edits made since the backup; the backup's edit only
      // fills in tracks that have none.
      if (merge && existing.contains(e.key) && await TrackStore.override(txn, e.key) != null) continue;
      await TrackStore.setOverride(txn, e.key, e.value);
    }
  }

  static Future<void> _importPlaylists(Transaction txn, List<Map<String, Object?>> items, Set<String> known, bool merge) async {
    for (final p in items) {
      final id = p['id'] as String;
      final kind = PlaylistKind.values.asNameMap()[p['kind']] ?? PlaylistKind.local;
      final now = nowMs();
      var position = 0;
      final present = <String>{};
      final exists = (await txn.rawQuery('SELECT 1 FROM playlists WHERE id = ?', [id])).isNotEmpty;
      if (exists && merge) {
        // Keep the playlist as it is now; only add the entries it lacks.
        final rows = await txn.rawQuery('SELECT track_id, position FROM playlist_entries WHERE playlist_id = ?', [id]);
        for (final r in rows) {
          present.add(r['track_id'] as String);
          position = position > (r['position'] as num).toInt() ? position : (r['position'] as num).toInt() + 1;
        }
      } else {
        await txn.delete('playlists', where: 'id = ?', whereArgs: [id]); // cascades entries
      }
      if (!(exists && merge)) {
        await _insertPlaylist(txn, id, p, kind, now);
      }
      final batch = txn.batch();
      for (final e in _list(p['entries'])) {
        final trackId = e['trackId'] as String;
        if (merge && exists && present.contains(trackId)) continue;
        if (!known.contains(trackId)) {
          _log.warning('Backup playlist $id references unknown track; entry skipped');
          continue;
        }
        batch.insert('playlist_entries', {
          'playlist_id': id,
          'position': position++,
          'track_id': trackId,
          'added_at': (e['addedAt'] as num?)?.toInt() ?? now,
        });
      }
      await batch.commit(noResult: true);
    }
  }

  static Future<void> _insertPlaylist(Transaction txn, String id, Map<String, Object?> p, PlaylistKind kind, int now) {
    return txn.insert('playlists', {
      'id': id,
      'name': p['name'] as String,
      'description': p['description'],
      'kind': kind.name,
      'artwork_url': p['artworkUrl'],
      'owner_name': p['ownerName'],
      'source_id': p['sourceId'],
      'source_playlist_id': p['sourcePlaylistId'],
      'created_at': (p['createdAt'] as num?)?.toInt() ?? now,
      'updated_at': (p['updatedAt'] as num?)?.toInt() ?? now,
      'auto_download': boolInt(p['autoDownload'] == true),
      'smart_rules': p['smartRules'] == null ? null : jsonEncode(p['smartRules']),
      'permalink': p['permalink'],
    });
  }

  static Future<void> _importFavorites(Transaction txn, List<Map<String, Object?>> items, Set<String> known) async {
    final batch = txn.batch();
    for (final f in items) {
      final id = f['trackId'] as String;
      if (!known.contains(id)) continue;
      batch.rawInsert('INSERT OR IGNORE INTO favorites(track_id, added_at) VALUES (?, ?)', [id, (f['addedAt'] as num?)?.toInt() ?? nowMs()]);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _importHistory(Transaction txn, List<Map<String, Object?>> items, Set<String> known) async {
    final batch = txn.batch();
    for (final h in items) {
      final id = h['trackId'] as String;
      if (!known.contains(id)) continue;
      final playedAt = (h['playedAt'] as num).toInt();
      batch.rawInsert(
        'INSERT INTO play_history(track_id, played_at, listened_ms, completed, origin) '
        'SELECT ?, ?, ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM play_history WHERE track_id = ? AND played_at = ?)',
        [id, playedAt, (h['listenedMs'] as num?)?.toInt() ?? 0, boolInt(h['completed'] == true), h['origin'], id, playedAt],
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _importLinks(Transaction txn, List<Map<String, Object?>> items, Set<String> known) async {
    final batch = txn.batch();
    for (final l in items) {
      final x = l['a'] as String;
      final y = l['b'] as String;
      if (x == y || !known.contains(x) || !known.contains(y)) continue;
      final (a, b) = x.compareTo(y) < 0 ? (x, y) : (y, x);
      batch.rawInsert(
        'INSERT OR IGNORE INTO track_links(a, b, confidence, confirmed, created_at) VALUES (?, ?, ?, ?, ?)',
        [a, b, (l['confidence'] as num).toDouble(), boolInt(l['confirmed'] == true), (l['createdAt'] as num?)?.toInt() ?? nowMs()],
      );
      if (l['confirmed'] == true) {
        // Never downgrade; a confirmation in the backup may upgrade an unconfirmed link.
        batch.rawUpdate(
          'UPDATE track_links SET confirmed = 1, confidence = MAX(confidence, ?) WHERE a = ? AND b = ? AND confirmed = 0',
          [(l['confidence'] as num).toDouble(), a, b],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _importFolders(Transaction txn, List<Map<String, Object?>> items) async {
    final batch = txn.batch();
    for (final f in items) {
      batch.rawInsert(
        'INSERT OR IGNORE INTO library_folders(path, watch, added_at) VALUES (?, ?, ?)',
        [f['path'] as String, boolInt(f['watch'] != false), nowMs()],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _importSearches(Transaction txn, List<Map<String, Object?>> items) async {
    final batch = txn.batch();
    for (final s in items) {
      final q = (s['query'] as String).trim();
      if (q.isEmpty) continue;
      final at = (s['at'] as num?)?.toInt() ?? 0;
      final key = q.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      batch.rawInsert(
        'INSERT OR REPLACE INTO search_history(query_key, query, searched_at) '
        'SELECT ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM search_history WHERE query_key = ? AND searched_at >= ?)',
        [key, q, at, key, at],
      );
    }
    await batch.commit(noResult: true);
    await txn.rawDelete(
      'DELETE FROM search_history WHERE query_key NOT IN (SELECT query_key FROM search_history ORDER BY searched_at DESC LIMIT ?)',
      [maxSearchEntries],
    );
  }
}
