import 'dart:io';

import 'package:fermata/core/errors.dart';
import 'package:fermata/library/db/database.dart';
import 'package:fermata/library/db/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await tempDir('mig'));
  tearDown(() async => dir.delete(recursive: true));

  Future<Set<String>> tables(FermataDatabase db) async =>
      {for (final r in await db.db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'")) r['name'] as String};

  test('fresh database is created at the latest version with WAL + foreign keys', () async {
    final db = await FermataDatabase.open(File(p.join(dir.path, 'f.db')), factory: testDbFactory());
    expect(db.schemaVersion, latestSchemaVersion);
    expect(await FermataDatabase.readUserVersion(db.db), latestSchemaVersion);
    final fk = await db.db.rawQuery('PRAGMA foreign_keys');
    expect(fk.first.values.first, 1);
    final journal = await db.db.rawQuery('PRAGMA journal_mode');
    expect(journal.first.values.first.toString().toLowerCase(), 'wal');
    expect(await tables(db), containsAll(['tracks', 'track_artists', 'playlists', 'playlist_entries', 'favorites',
        'play_history', 'search_history', 'library_folders', 'track_links', 'downloaded_tracks']));
    expect(await db.sizeBytes(), greaterThan(0));
    await db.close();
  });

  test('upgrade v1 -> latest keeps data and adds new schema', () async {
    final file = File(p.join(dir.path, 'up.db'));
    final v1 = await FermataDatabase.open(file, factory: testDbFactory(), targetVersion: 1);
    expect(v1.schemaVersion, 1);
    expect(await tables(v1), isNot(contains('track_links')));
    await v1.db.insert('tracks', {
      'id': 'soundcloud:1', 'source_id': 'soundcloud', 'source_track_id': '1', 'title': 'Old', 'title_norm': 'old',
      'date_added': 1000, 'json': '{"source":"soundcloud","sid":"1","title":"Old"}',
    });
    await v1.db.insert('playlists', {'id': 'p1', 'name': 'Mix', 'kind': 'local', 'created_at': 1, 'updated_at': 1});
    await v1.db.insert('playlist_entries', {'playlist_id': 'p1', 'position': 0, 'track_id': 'soundcloud:1', 'added_at': 1});
    await v1.close();

    final latest = await FermataDatabase.open(file, factory: testDbFactory());
    expect(latest.schemaVersion, latestSchemaVersion);
    expect(await tables(latest), containsAll(['track_links', 'downloaded_tracks']));
    final cols = {for (final r in await latest.db.rawQuery('PRAGMA table_info(tracks)')) r['name']};
    expect(cols, contains('missing_since'));
    final rows = await latest.db.query('tracks');
    expect(rows.single['title'], 'Old');
    expect(rows.single['date_added'], 1000);
    expect((await latest.db.query('playlist_entries')).length, 1);
    await latest.close();
  });

  test('each step v1 -> v2 -> v3 can be applied separately', () async {
    final file = File(p.join(dir.path, 'steps.db'));
    for (var v = 1; v <= latestSchemaVersion; v++) {
      final db = await FermataDatabase.open(file, factory: testDbFactory(), targetVersion: v);
      expect(await FermataDatabase.readUserVersion(db.db), v);
      await db.close();
    }
  });

  test('database from a newer app version is refused', () async {
    final file = File(p.join(dir.path, 'new.db'));
    final db = await FermataDatabase.open(file, factory: testDbFactory());
    await db.db.execute('PRAGMA user_version = ${latestSchemaVersion + 5}');
    await db.close();
    await expectLater(
      FermataDatabase.open(file, factory: testDbFactory()),
      throwsA(isA<StorageException>().having((e) => e.code, 'code', 'database_too_new')),
    );
  });

  test('default platform factory (FFI in a background isolate) works', () async {
    final db = await FermataDatabase.open(File(p.join(dir.path, 'iso.db')));
    expect(db.schemaVersion, latestSchemaVersion);
    await db.db.insert('search_history', {'query_key': 'a', 'query': 'A', 'searched_at': 1});
    expect((await db.db.query('search_history')).single['query'], 'A');
    await db.close();
  });

  test('foreign keys cascade playlist entries', () async {
    final db = await FermataDatabase.openInMemory(factory: testDbFactory());
    await db.db.insert('tracks', {
      'id': 'x:1', 'source_id': 'x', 'source_track_id': '1', 'title': 't', 'title_norm': 't', 'date_added': 1, 'json': '{}',
    });
    await db.db.insert('playlists', {'id': 'p', 'name': 'n', 'kind': 'local', 'created_at': 1, 'updated_at': 1});
    await db.db.insert('playlist_entries', {'playlist_id': 'p', 'position': 0, 'track_id': 'x:1', 'added_at': 1});
    await db.db.delete('tracks');
    expect(await db.db.query('playlist_entries'), isEmpty);
    await db.close();
  });
}
