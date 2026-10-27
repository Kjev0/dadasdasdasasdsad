import 'package:sqflite/sqflite.dart';

import '../../core/sources/source_ids.dart';
import '../db/sql_utils.dart';
import '../repositories/track_codec.dart';
import '../repositories/track_store.dart';
import 'tag_reader.dart';

/// State of a local track row as the scanner sees it.
class LocalRow {
  const LocalRow({
    required this.id,
    required this.path,
    this.size,
    this.mtimeMs,
    this.hash,
    this.missing = false,
    this.artworkUrl,
  });

  final String id;
  final String path;
  final int? size;
  final int? mtimeMs;
  final String? hash;
  final bool missing;
  final String? artworkUrl;
}

/// SQL used by the scanner for local-file bookkeeping.
abstract final class LocalFileStore {
  /// `substr(local_path, 1, len(prefix)) = prefix` for [root] (+ separator).
  static (String, List<Object?>) underRoot(String rootWithSep) =>
      ('substr(t.local_path, 1, ?) = ?', [rootWithSep.length, rootWithSep]);

  /// Local rows under any of [roots] (each ending with a separator).
  static Future<List<LocalRow>> rowsUnder(DatabaseExecutor ex, List<String> roots) async {
    if (roots.isEmpty) return const [];
    final parts = <String>[];
    final args = <Object?>[];
    for (final r in roots) {
      final (sql, a) = underRoot(r);
      parts.add(sql);
      args.addAll(a);
    }
    final rows = await ex.rawQuery(
      'SELECT t.id, t.local_path, t.file_size, t.file_mtime, t.file_hash, t.missing_since, t.artwork_url '
      "FROM tracks t WHERE t.source_id = '${SourceIds.local}' AND t.local_path IS NOT NULL AND (${parts.join(' OR ')})",
      args,
    );
    return [
      for (final r in rows)
        LocalRow(
          id: r['id'] as String,
          path: r['local_path'] as String,
          size: (r['file_size'] as num?)?.toInt(),
          mtimeMs: (r['file_mtime'] as num?)?.toInt(),
          hash: r['file_hash'] as String?,
          missing: r['missing_since'] != null,
          artworkUrl: r['artwork_url'] as String?,
        ),
    ];
  }

  /// Upserts scanned tracks and records their file state, in [txn].
  static Future<void> saveScanned(Transaction txn, List<ScannedFile> files) async {
    final ok = [for (final f in files) if (f.track != null) f];
    if (ok.isEmpty) return;
    await TrackStore.upsert(txn, [for (final f in ok) f.track!]);
    final now = nowMs();
    final batch = txn.batch();
    for (final f in ok) {
      batch.update(
        'tracks',
        {'file_size': f.size, 'file_mtime': f.mtimeMs, 'file_hash': f.hash, 'missing_since': null, 'last_seen_at': now},
        where: 'id = ?',
        whereArgs: [f.track!.id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Marks unchanged files as seen (and present again).
  static Future<void> touch(Transaction txn, List<String> ids) async {
    final now = nowMs();
    for (final chunk in chunked(ids)) {
      await txn.rawUpdate(
        'UPDATE tracks SET last_seen_at = ?, missing_since = NULL WHERE id IN (${placeholders(chunk.length)})',
        [now, ...chunk],
      );
    }
  }

  /// The ids among [ids] referenced by a playlist, favorite, history entry or link.
  static Future<Set<String>> referenced(DatabaseExecutor ex, List<String> ids) async {
    final out = <String>{};
    for (final chunk in chunked(ids, sqlChunkSize ~/ 4)) {
      final ph = placeholders(chunk.length);
      final rows = await ex.rawQuery('''
        SELECT track_id AS id FROM playlist_entries WHERE track_id IN ($ph)
        UNION SELECT track_id FROM favorites WHERE track_id IN ($ph)
        UNION SELECT track_id FROM play_history WHERE track_id IN ($ph)
        UNION SELECT a FROM track_links WHERE a IN ($ph)
        UNION SELECT b FROM track_links WHERE b IN ($ph)''', [...chunk, ...chunk, ...chunk, ...chunk, ...chunk]);
      out.addAll(rows.map((r) => r['id'] as String));
    }
    return out;
  }

  /// Moves every reference (playlists, favorites, history, links, tag
  /// override, date added) from [oldId] to [newId] and deletes [oldId].
  /// Used when a file was moved/renamed (same content hash).
  static Future<void> migrate(Transaction txn, String oldId, String newId) async {
    await txn.rawUpdate('UPDATE playlist_entries SET track_id = ? WHERE track_id = ?', [newId, oldId]);
    await txn.rawUpdate('UPDATE OR IGNORE favorites SET track_id = ? WHERE track_id = ?', [newId, oldId]);
    await txn.rawUpdate('UPDATE play_history SET track_id = ? WHERE track_id = ?', [newId, oldId]);
    final links = await txn.rawQuery('SELECT a, b, confidence, confirmed, created_at FROM track_links WHERE a = ? OR b = ?', [oldId, oldId]);
    for (final l in links) {
      final other = l['a'] == oldId ? l['b'] as String : l['a'] as String;
      if (other == newId) continue;
      final (a, b) = newId.compareTo(other) < 0 ? (newId, other) : (other, newId);
      await txn.rawInsert(
        'INSERT OR IGNORE INTO track_links(a, b, confidence, confirmed, created_at) VALUES (?, ?, ?, ?, ?)',
        [a, b, l['confidence'], l['confirmed'], l['created_at']],
      );
    }
    final old = await txn.rawQuery('SELECT override_json, date_added FROM tracks WHERE id = ?', [oldId]);
    if (old.isNotEmpty) {
      await txn.rawUpdate('UPDATE tracks SET date_added = MIN(date_added, ?) WHERE id = ?', [old.first['date_added'], newId]);
      final ov = old.first['override_json'] as String?;
      if (ov != null) {
        final current = await TrackStore.override(txn, newId);
        if (current == null) await TrackStore.setOverride(txn, newId, TrackCodec.decodeJson(ov));
      }
    }
    await txn.delete('tracks', where: 'id = ?', whereArgs: [oldId]);
  }
}
