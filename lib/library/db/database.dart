import 'dart:io';

import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi, sqfliteFfiInit;

import '../../core/errors.dart';
import 'migrations.dart';

final _log = Logger('library.db');

/// The library's SQLite database.
///
/// * Android: system SQLite through the `sqflite` plugin.
/// * Desktop (Linux/Windows) and tests: `sqflite_common_ffi`
///   ([databaseFactoryFfi] runs SQLite in a background isolate).
///
/// WAL journaling and foreign keys are enabled. The schema is upgraded with
/// the versioned [migrations] (stored in `PRAGMA user_version`).
class FermataDatabase {
  FermataDatabase._(this.db, this.path, this.schemaVersion);

  /// Underlying sqflite handle. Repositories use it directly.
  final Database db;

  /// File path, or [inMemoryDatabasePath] for in-memory databases.
  final String path;

  /// Schema version after migrations ran.
  final int schemaVersion;

  bool get isInMemory => path == inMemoryDatabasePath;

  static bool _ffiInitialized = false;

  /// The platform's default factory (sqflite on Android, FFI elsewhere).
  static DatabaseFactory defaultFactory() {
    if (Platform.isAndroid) return databaseFactorySqflitePlugin;
    if (!_ffiInitialized) {
      sqfliteFfiInit();
      _ffiInitialized = true;
    }
    return databaseFactoryFfi;
  }

  /// Opens (creating if needed) the database at [dbFile] and migrates it to
  /// [targetVersion] (default: latest). Throws [StorageException] when the
  /// file was written by a newer app version or cannot be opened.
  static Future<FermataDatabase> open(File dbFile, {DatabaseFactory? factory, int? targetVersion}) async {
    await dbFile.parent.create(recursive: true);
    return _open(dbFile.path, factory ?? defaultFactory(), targetVersion);
  }

  /// A private in-memory database (tests, previews).
  static Future<FermataDatabase> openInMemory({DatabaseFactory? factory, int? targetVersion}) =>
      _open(inMemoryDatabasePath, factory ?? defaultFactory(), targetVersion);

  static Future<FermataDatabase> _open(String path, DatabaseFactory factory, int? targetVersion) async {
    final target = targetVersion ?? latestSchemaVersion;
    if (target < 1 || target > latestSchemaVersion) {
      throw ArgumentError.value(targetVersion, 'targetVersion', 'must be 1..$latestSchemaVersion');
    }
    final Database db;
    try {
      db = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          singleInstance: path != inMemoryDatabasePath,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
            if (path != inMemoryDatabasePath) {
              // journal_mode returns a row, so it must be a query.
              await db.rawQuery('PRAGMA journal_mode = WAL');
              await db.execute('PRAGMA synchronous = NORMAL');
            }
          },
        ),
      );
    } catch (e) {
      throw StorageException('database_open_failed', 'Could not open library database at $path', cause: e);
    }
    try {
      final version = await migrate(db, target);
      return FermataDatabase._(db, path, version);
    } catch (e) {
      await db.close();
      rethrow;
    }
  }

  /// Runs every pending migration up to [target], each in its own
  /// transaction together with the `user_version` bump. Returns the version.
  static Future<int> migrate(Database db, int target) async {
    final current = await readUserVersion(db);
    if (current > latestSchemaVersion) {
      throw StorageException(
        'database_too_new',
        'Library database schema v$current is newer than this app (v$latestSchemaVersion)',
      );
    }
    for (var v = current; v < target; v++) {
      _log.info('Migrating library database v$v -> v${v + 1}');
      await db.transaction((txn) async {
        await migrations[v](txn);
        await txn.execute('PRAGMA user_version = ${v + 1}');
      });
    }
    return current > target ? current : target;
  }

  static Future<int> readUserVersion(DatabaseExecutor db) async {
    final rows = await db.rawQuery('PRAGMA user_version');
    return (rows.first.values.first as num?)?.toInt() ?? 0;
  }

  /// Size of the database including WAL/SHM side files (in-memory: pages).
  Future<int> sizeBytes() async {
    if (isInMemory) {
      final count = await db.rawQuery('PRAGMA page_count');
      final size = await db.rawQuery('PRAGMA page_size');
      return ((count.first.values.first as num?)?.toInt() ?? 0) * ((size.first.values.first as num?)?.toInt() ?? 0);
    }
    var total = 0;
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final f = File('$path$suffix');
      try {
        if (await f.exists()) total += await f.length();
      } on FileSystemException {
        // ignore races with checkpoints
      }
    }
    return total;
  }

  Future<void> close() => db.close();
}
