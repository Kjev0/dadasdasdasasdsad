import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../db/sql_utils.dart';
import '../text/fold.dart';
import 'track_codec.dart';

/// Low-level track persistence shared by the repositories and the scanner.
/// All functions take a [DatabaseExecutor]; callers run them inside a
/// transaction when atomicity matters. No change notifications here.
abstract final class TrackStore {
  /// Insert or update [tracks] by id, keeping `date_added`, `override_json`
  /// and file columns of existing rows. [dateAdded] (ms) is used for new
  /// rows when given (backup restore), otherwise "now".
  ///
  /// With [preserveScanned], existing local rows that the scanner owns (they
  /// have a file hash) are left untouched: a `Track` object held by the UI or
  /// the play queue may be older than the last scan and must not overwrite
  /// tags read from the file. For the same reason such callers cannot create
  /// *new* local rows: a local track that is unknown to the library and whose
  /// file no longer exists is a stale object (e.g. the old id of a moved
  /// file) and would resurrect a phantom track, so it is skipped.
  static Future<void> upsert(
    DatabaseExecutor ex,
    List<Track> tracks, {
    Map<String, int>? dateAdded,
    bool preserveScanned = false,
  }) async {
    if (tracks.isEmpty) return;
    final now = nowMs();
    final unique = <String, Track>{for (final t in tracks) t.id: t};
    final existing = <String, String?>{};
    final scanned = <String>{};
    for (final chunk in chunked(unique.keys.toList())) {
      final rows = await ex.rawQuery(
        'SELECT id, override_json, file_hash, source_id FROM tracks WHERE id IN (${placeholders(chunk.length)})',
        chunk,
      );
      for (final r in rows) {
        existing[r['id'] as String] = r['override_json'] as String?;
        if (r['file_hash'] != null && r['source_id'] == SourceIds.local) scanned.add(r['id'] as String);
      }
    }
    final batch = ex.batch();
    for (final t in unique.values) {
      if (preserveScanned && scanned.contains(t.id)) continue;
      if (preserveScanned && !existing.containsKey(t.id) && _isDeadLocalFile(t)) continue;
      final json = t.toJson();
      final exists = existing.containsKey(t.id);
      final ovRaw = existing[t.id];
      final effective = ovRaw == null ? t : TrackCodec.applyOverride(json, TrackCodec.decodeJson(ovRaw));
      final cols = TrackCodec.columns(effective)
        ..['json'] = jsonEncode(json)
        ..['last_seen_at'] = now;
      if (exists) {
        cols.remove('id');
        batch.update('tracks', cols, where: 'id = ?', whereArgs: [t.id]);
      } else {
        cols['date_added'] = dateAdded?[t.id] ?? now;
        batch.insert('tracks', cols);
      }
      _writeArtists(batch, effective);
    }
    await batch.commit(noResult: true);
  }

  static bool _isDeadLocalFile(Track t) {
    final path = t.localPath;
    return t.sourceId == SourceIds.local && path != null && !File(path).existsSync();
  }

  static void _writeArtists(Batch batch, Track effective) {
    batch.delete('track_artists', where: 'track_id = ?', whereArgs: [effective.id]);
    for (var i = 0; i < effective.artists.length; i++) {
      final name = effective.artists[i].name;
      batch.insert('track_artists', {
        'track_id': effective.id,
        'position': i,
        'name': name,
        'name_norm': foldForSearch(name),
      });
    }
  }

  /// Replaces the user override of track [id] (null clears it) and refreshes
  /// the denormalized columns. Returns the effective track, or null when the
  /// track does not exist.
  static Future<Track?> setOverride(DatabaseExecutor ex, String id, Map<String, Object?>? override) async {
    final rows = await ex.rawQuery('SELECT json FROM tracks WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final json = TrackCodec.decodeJson(rows.first['json'] as String);
    final ov = (override == null || override.isEmpty) ? null : override;
    final effective = TrackCodec.applyOverride(json, ov);
    final cols = TrackCodec.columns(effective)
      ..remove('id')
      ..['override_json'] = ov == null ? null : jsonEncode(ov);
    final batch = ex.batch();
    batch.update('tracks', cols, where: 'id = ?', whereArgs: [id]);
    _writeArtists(batch, effective);
    await batch.commit(noResult: true);
    return effective;
  }

  /// The stored override of track [id] (null when none / unknown track).
  static Future<Map<String, Object?>?> override(DatabaseExecutor ex, String id) async {
    final rows = await ex.rawQuery('SELECT override_json FROM tracks WHERE id = ?', [id]);
    final raw = rows.isEmpty ? null : rows.first['override_json'] as String?;
    return raw == null ? null : TrackCodec.decodeJson(raw);
  }

  /// The track as delivered by its source, without user overrides.
  static Future<Track?> sourceTrack(DatabaseExecutor ex, String id) async {
    final rows = await ex.rawQuery('SELECT json FROM tracks WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return Track.fromJson(TrackCodec.decodeJson(rows.first['json'] as String));
  }

  /// Effective tracks for [ids], in the order of [ids]; unknown ids skipped.
  static Future<List<Track>> byIds(DatabaseExecutor ex, List<String> ids) async {
    if (ids.isEmpty) return const [];
    final found = <String, Track>{};
    for (final chunk in chunked(ids.toSet().toList())) {
      final rows = await ex.rawQuery(
        'SELECT t.id, ${TrackCodec.selectColumns} FROM tracks t WHERE t.id IN (${placeholders(chunk.length)})',
        chunk,
      );
      for (final r in rows) {
        found[r['id'] as String] = TrackCodec.decode(r);
      }
    }
    return [for (final id in ids) ?found[id]];
  }

  /// Ids among [ids] that exist in `tracks`.
  static Future<Set<String>> existingIds(DatabaseExecutor ex, Iterable<String> ids) async {
    final out = <String>{};
    for (final chunk in chunked(ids.toSet().toList())) {
      final rows = await ex.rawQuery('SELECT id FROM tracks WHERE id IN (${placeholders(chunk.length)})', chunk);
      out.addAll(rows.map((r) => r['id'] as String));
    }
    return out;
  }
}
