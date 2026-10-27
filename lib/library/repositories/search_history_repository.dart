import '../../core/contracts/library.dart';
import '../../settings/settings_store.dart';
import '../change_bus.dart';
import '../db/database.dart';
import '../db/sql_utils.dart';

/// SQLite implementation of [SearchHistoryRepository].
///
/// Queries are trimmed, deduplicated case-insensitively (the latest spelling
/// wins and moves to the top) and capped at [maxEntries]. When a
/// [SettingsStore] is given and `privacy.saveSearchHistory` is off, [add]
/// does nothing.
class SqlSearchHistoryRepository implements SearchHistoryRepository {
  SqlSearchHistoryRepository(this._db, this._bus, {this.settings, this.maxEntries = 50});

  final FermataDatabase _db;
  final LibraryChangeBus _bus;
  /// When set, `privacy.saveSearchHistory` is honored by [add].
  final SettingsStore? settings;
  final int maxEntries;
  int _lastAt = 0;

  static String keyOf(String query) => query.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  @override
  Future<void> add(String query) async {
    final display = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (display.isEmpty) return;
    final store = settings;
    if (store != null && !store.current.privacy.saveSearchHistory) return;
    // Strictly increasing timestamps keep the order stable for rapid adds.
    var at = nowMs();
    if (at <= _lastAt) at = _lastAt + 1;
    _lastAt = at;
    await _db.db.transaction((txn) async {
      await txn.rawInsert(
        'INSERT OR REPLACE INTO search_history(query_key, query, searched_at) VALUES (?, ?, ?)',
        [keyOf(display), display, at],
      );
      await txn.rawDelete(
        'DELETE FROM search_history WHERE query_key NOT IN '
        '(SELECT query_key FROM search_history ORDER BY searched_at DESC LIMIT ?)',
        [maxEntries],
      );
    });
    notifyLibrary(_bus, {LibraryTopic.searches});
  }

  @override
  Future<List<String>> recent({int limit = 12}) async {
    final rows = await _db.db.rawQuery('SELECT query FROM search_history ORDER BY searched_at DESC LIMIT ?', [limit]);
    return [for (final r in rows) r['query'] as String];
  }

  @override
  Future<void> remove(String query) async {
    final n = await _db.db.delete('search_history', where: 'query_key = ?', whereArgs: [keyOf(query)]);
    if (n > 0) notifyLibrary(_bus, {LibraryTopic.searches});
  }

  @override
  Future<void> clear() async {
    await _db.db.delete('search_history');
    notifyLibrary(_bus, {LibraryTopic.searches});
  }

  /// Raw rows for backup.
  Future<List<Map<String, Object?>>> exportRows() => _db.db.query('search_history', orderBy: 'searched_at');
}
