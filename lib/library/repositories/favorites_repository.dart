import 'dart:async';

import '../../core/contracts/library.dart';
import '../../core/models/track.dart';
import '../change_bus.dart';
import '../db/database.dart';
import '../db/sql_utils.dart';
import 'track_codec.dart';
import 'track_store.dart';

/// SQLite implementation of [FavoritesRepository].
class SqlFavoritesRepository implements FavoritesRepository {
  SqlFavoritesRepository(this._db, this._bus);

  final FermataDatabase _db;
  final LibraryChangeBus _bus;

  @override
  Future<bool> isFavorite(String trackId) async {
    final rows = await _db.db.rawQuery('SELECT 1 FROM favorites WHERE track_id = ?', [trackId]);
    return rows.isNotEmpty;
  }

  @override
  Future<void> setFavorite(Track track, bool favorite) async {
    await _db.db.transaction((txn) async {
      await TrackStore.upsert(txn, [track], preserveScanned: true);
      if (favorite) {
        await txn.rawInsert('INSERT OR IGNORE INTO favorites(track_id, added_at) VALUES (?, ?)', [track.id, nowMs()]);
      } else {
        await txn.delete('favorites', where: 'track_id = ?', whereArgs: [track.id]);
      }
    });
    notifyLibrary(_bus, {LibraryTopic.favorites, LibraryTopic.tracks});
  }

  /// Favorites, most recently added first.
  @override
  Future<List<Track>> favorites() async {
    final rows = await _db.db.rawQuery(
      'SELECT ${TrackCodec.selectColumns} FROM favorites f JOIN tracks t ON t.id = f.track_id '
      'ORDER BY f.added_at DESC, t.title_norm',
    );
    return rows.map(TrackCodec.decode).toList();
  }

  Future<Set<String>> _ids() async =>
      {for (final r in await _db.db.rawQuery('SELECT track_id FROM favorites')) r['track_id'] as String};

  /// Emits the current set on listen and again after every favorites change
  /// (including changes caused by deletes/restores).
  @override
  Stream<Set<String>> watchFavoriteIds() => Stream<Set<String>>.multi((controller) {
        Set<String>? last;
        var closed = false;
        Future<void> emit() async {
          try {
            final ids = await _ids();
            if (closed) return;
            if (last == null || last!.length != ids.length || !last!.containsAll(ids)) {
              last = ids;
              controller.add(Set.unmodifiable(ids));
            }
          } catch (e, st) {
            if (!closed) controller.addError(e, st);
          }
        }

        // Serialize refreshes so emissions arrive in order.
        var chain = emit();
        final sub = _bus.changes.where((t) => t.contains(LibraryTopic.favorites)).listen((_) {
          chain = chain.then((_) => emit());
        });
        controller.onCancel = () {
          closed = true;
          return sub.cancel();
        };
      });

  /// Raw rows for backup.
  Future<List<Map<String, Object?>>> exportRows() => _db.db.query('favorites', orderBy: 'added_at');
}
