import 'package:sqflite/sqflite.dart';

import '../../core/contracts/library.dart';
import '../../core/errors.dart';
import '../../core/models/library.dart';
import '../../core/models/track.dart';
import '../change_bus.dart';
import '../db/database.dart';
import '../db/sql_utils.dart';
import 'track_store.dart';

/// One stored link row.
class _Edge {
  _Edge(this.a, this.b, this.confidence, this.confirmed, this.createdAt);

  final String a;
  final String b;
  final double confidence;
  final bool confirmed;
  final int createdAt;

  String other(String id) => id == a ? b : a;
}

/// SQLite implementation of [TrackLinkRepository].
///
/// Each pair is stored once in canonical order (`a < b`); links are
/// symmetric and groups are transitive (A–B and B–C put A, B and C in one
/// group). Re-linking an existing pair updates its confidence, but a
/// user-confirmed link is never downgraded by a later automatic match.
class SqlTrackLinkRepository implements TrackLinkRepository {
  SqlTrackLinkRepository(this._db, this._bus);

  final FermataDatabase _db;
  final LibraryChangeBus _bus;

  @override
  Future<void> link(String trackId, String linkedTrackId, {required double confidence, bool userConfirmed = false}) async {
    if (trackId == linkedTrackId) throw ArgumentError('A track cannot be linked to itself ($trackId)');
    final (a, b) = trackId.compareTo(linkedTrackId) < 0 ? (trackId, linkedTrackId) : (linkedTrackId, trackId);
    final conf = confidence.clamp(0.0, 1.0).toDouble();
    await _db.db.transaction((txn) async {
      final existing = await TrackStore.existingIds(txn, [a, b]);
      if (existing.length != 2) {
        throw StorageException(
          'track_not_in_library',
          'Both tracks must be upserted before linking ($trackId, $linkedTrackId)',
        );
      }
      final rows = await txn.query('track_links', where: 'a = ? AND b = ?', whereArgs: [a, b]);
      if (rows.isEmpty) {
        await txn.insert('track_links', {
          'a': a,
          'b': b,
          'confidence': conf,
          'confirmed': boolInt(userConfirmed),
          'created_at': nowMs(),
        });
      } else {
        final wasConfirmed = intBool(rows.first['confirmed']);
        final keepOld = wasConfirmed && !userConfirmed;
        await txn.update(
          'track_links',
          {
            'confidence': keepOld ? rows.first['confidence'] : conf,
            'confirmed': boolInt(wasConfirmed || userConfirmed),
          },
          where: 'a = ? AND b = ?',
          whereArgs: [a, b],
        );
      }
    });
    notifyLibrary(_bus, {LibraryTopic.links});
  }

  @override
  Future<void> unlink(String trackId, String linkedTrackId) async {
    final (a, b) = trackId.compareTo(linkedTrackId) < 0 ? (trackId, linkedTrackId) : (linkedTrackId, trackId);
    final n = await _db.db.delete('track_links', where: 'a = ? AND b = ?', whereArgs: [a, b]);
    if (n > 0) notifyLibrary(_bus, {LibraryTopic.links});
  }

  /// All tracks in [trackId]'s group. Direct links are returned as stored;
  /// transitive ones get the best path confidence (product of the edges),
  /// `userConfirmed` when every edge on that path is confirmed and the
  /// newest edge's `createdAt`. Sorted by confidence (confirmed first on ties).
  @override
  Future<List<(Track, TrackLink)>> linkedTracks(String trackId) async {
    final edges = await _component(_db.db, {trackId});
    if (edges.isEmpty) return const [];
    final adj = <String, List<_Edge>>{};
    for (final e in edges) {
      adj.putIfAbsent(e.a, () => []).add(e);
      adj.putIfAbsent(e.b, () => []).add(e);
    }
    // Widest-path search maximizing the product of confidences.
    final best = <String, ({double conf, bool confirmed, int createdAt})>{
      trackId: (conf: 1.0, confirmed: true, createdAt: 0),
    };
    final done = <String>{};
    while (true) {
      String? current;
      for (final entry in best.entries) {
        if (done.contains(entry.key)) continue;
        if (current == null || entry.value.conf > best[current]!.conf) current = entry.key;
      }
      if (current == null) break;
      done.add(current);
      final here = best[current]!;
      for (final e in adj[current] ?? const <_Edge>[]) {
        final next = e.other(current);
        if (done.contains(next)) continue;
        final cand = (
          conf: here.conf * e.confidence,
          confirmed: here.confirmed && e.confirmed,
          createdAt: here.createdAt > e.createdAt ? here.createdAt : e.createdAt,
        );
        final prev = best[next];
        if (prev == null || cand.conf > prev.conf || (cand.conf == prev.conf && cand.confirmed && !prev.confirmed)) {
          best[next] = cand;
        }
      }
    }
    best.remove(trackId);
    final tracks = await TrackStore.byIds(_db.db, best.keys.toList());
    final out = [
      for (final t in tracks)
        (
          t,
          TrackLink(
            trackId: trackId,
            linkedTrackId: t.id,
            confidence: best[t.id]!.conf,
            userConfirmed: best[t.id]!.confirmed,
            createdAt: DateTime.fromMillisecondsSinceEpoch(best[t.id]!.createdAt),
          ),
        ),
    ];
    out.sort((x, y) {
      final c = y.$2.confidence.compareTo(x.$2.confidence);
      if (c != 0) return c;
      if (x.$2.userConfirmed != y.$2.userConfirmed) return x.$2.userConfirmed ? -1 : 1;
      return x.$1.id.compareTo(y.$1.id);
    });
    return out;
  }

  /// Maps every id in [ids] to a group key; ids in the same (transitive)
  /// link group share a key. Unlinked ids map to themselves.
  Future<Map<String, String>> groupKeys(Iterable<String> ids, {DatabaseExecutor? executor}) =>
      linkGroupKeys(executor ?? _db.db, ids);

  /// Every stored link (backup).
  Future<List<Map<String, Object?>>> allLinks() => _db.db.query('track_links', orderBy: 'a, b');
}

/// Union-find over the link components touching [ids].
Future<Map<String, String>> linkGroupKeys(DatabaseExecutor ex, Iterable<String> ids) async {
  final idSet = ids.toSet();
  final parent = <String, String>{};
  String find(String x) {
    var root = x;
    while (parent[root] != null && parent[root] != root) {
      root = parent[root]!;
    }
    var cur = x;
    while (parent[cur] != null && parent[cur] != root) {
      final next = parent[cur]!;
      parent[cur] = root;
      cur = next;
    }
    return root;
  }

  for (final e in await _component(ex, idSet)) {
    parent.putIfAbsent(e.a, () => e.a);
    parent.putIfAbsent(e.b, () => e.b);
    final ra = find(e.a);
    final rb = find(e.b);
    if (ra != rb) parent[ra.compareTo(rb) < 0 ? rb : ra] = ra.compareTo(rb) < 0 ? ra : rb;
  }
  return {for (final id in idSet) id: parent.containsKey(id) ? find(id) : id};
}

/// All edges reachable from [start] (breadth-first over the link table).
Future<List<_Edge>> _component(DatabaseExecutor ex, Set<String> start) async {
  final visited = <String>{...start};
  var frontier = start.toList();
  final edges = <String, _Edge>{};
  while (frontier.isNotEmpty) {
    final next = <String>[];
    for (final chunk in chunked(frontier, sqlChunkSize ~/ 2)) {
      final ph = placeholders(chunk.length);
      final rows = await ex.rawQuery(
        'SELECT a, b, confidence, confirmed, created_at FROM track_links WHERE a IN ($ph) OR b IN ($ph)',
        [...chunk, ...chunk],
      );
      for (final r in rows) {
        final e = _Edge(
          r['a'] as String,
          r['b'] as String,
          (r['confidence'] as num).toDouble(),
          intBool(r['confirmed']),
          (r['created_at'] as num).toInt(),
        );
        edges['${e.a}\u0000${e.b}'] = e;
        for (final id in [e.a, e.b]) {
          if (visited.add(id)) next.add(id);
        }
      }
    }
    frontier = next;
  }
  return edges.values.toList();
}
