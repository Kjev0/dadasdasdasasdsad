import 'dart:convert';

import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/library.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestLibrary lib;
  setUp(() async => lib = await openTestLibrary());
  tearDown(() async => lib.dispose());

  Future<void> seed(TestLibrary l) async {
    final m = l.module;
    await m.tracks.upsertTracks([
      remoteTrack('1', title: 'One'),
      remoteTrack('2', source: 'spotify', title: 'Two'),
      remoteTrack('3', title: 'Three'),
      localTrack('l1', '/music/l1.flac', title: 'Local One'),
      remoteTrack('cache', title: 'Only cached'),
    ]);
    await m.tracks.setOverride('local:l1', {'title': 'Local One (edited)'});
    final p = await m.playlists.createPlaylist('Mix', description: 'd');
    await m.playlists.addTracks(p.id, ['soundcloud:1', 'spotify:2', 'local:l1']);
    await m.playlists.setAutoDownload(p.id, true);
    await m.playlists.createSmartPlaylist(
      'Smart',
      const SmartPlaylistRules(rules: [SmartRule(field: SmartField.title, op: SmartOperator.contains, value: 'o')]),
    );
    await m.favorites.setFavorite((await m.tracks.getTrack('soundcloud:3'))!, true);
    await m.history.recordPlay(PlayRecord(
      track: (await m.tracks.getTrack('soundcloud:1'))!,
      playedAt: DateTime(2024, 1, 1),
      listened: const Duration(minutes: 3),
      completed: true,
      origin: 'playlist:x',
    ));
    await m.links.link('spotify:2', 'soundcloud:1', confidence: 0.93, userConfirmed: true);
    await m.database.db.insert('library_folders', {'path': '/music', 'watch': 1, 'added_at': 1});
    await m.searchHistory.add('daft punk');
  }

  test('backup -> restore into an empty library round-trips all user data', () async {
    await seed(lib);
    final backup = await lib.module.maintenance.exportBackup();
    // Must be plain JSON (it is written to a file by the settings UI).
    final json = jsonDecode(jsonEncode(backup)) as Map<String, Object?>;
    expect(json['format'], 'fermata.library.backup');
    expect((json['tracks'] as List).length, 4); // the unreferenced cached track is not exported

    final other = await openTestLibrary();
    addTearDown(other.dispose);
    await other.module.maintenance.importBackup(json);
    final m = other.module;
    final playlists = await m.playlists.playlists();
    expect(playlists.map((p) => p.name), ['Mix', 'Smart']);
    final mix = playlists.first;
    expect(mix.autoDownload, isTrue);
    expect(mix.description, 'd');
    expect(await m.playlists.playlistTrackIds(mix.id), ['soundcloud:1', 'spotify:2', 'local:l1']);
    expect(playlists[1].kind, PlaylistKind.smart);
    expect((await m.playlists.playlistTrackIds(playlists[1].id)).toSet(), {'soundcloud:1', 'spotify:2', 'local:l1'});
    expect((await m.favorites.favorites()).map((t) => t.id), ['soundcloud:3']);
    final h = await m.history.history();
    expect(h.single.origin, 'playlist:x');
    expect(h.single.listened, const Duration(minutes: 3));
    final linked = await m.links.linkedTracks('soundcloud:1');
    expect(linked.single.$1.id, 'spotify:2');
    expect(linked.single.$2.userConfirmed, isTrue);
    expect(linked.single.$2.confidence, 0.93);
    expect((await m.localLibrary.folders()).single.path, '/music');
    expect(await m.searchHistory.recent(), ['daft punk']);
    expect((await m.tracks.getTrack('local:l1'))!.title, 'Local One (edited)');

    // Merging the same backup again does not duplicate anything.
    await m.maintenance.importBackup(json);
    expect((await m.playlists.playlists()).length, 2);
    expect((await m.history.history()).length, 1);
    expect((await m.favorites.favorites()).length, 1);
    expect(await m.playlists.playlistTrackIds(mix.id), ['soundcloud:1', 'spotify:2', 'local:l1']);
  });

  test('restore without merge replaces existing user data', () async {
    await seed(lib);
    final backup = await lib.module.maintenance.exportBackup();
    final other = await openTestLibrary();
    addTearDown(other.dispose);
    final p = await other.module.playlists.createPlaylist('Existing');
    await other.module.favorites.setFavorite(remoteTrack('zzz'), true);
    await other.module.maintenance.importBackup(backup, merge: false);
    expect((await other.module.playlists.playlists()).map((p) => p.name), ['Mix', 'Smart']);
    expect(await other.module.playlists.getPlaylist(p.id), isNull);
    expect((await other.module.favorites.favorites()).map((t) => t.id), ['soundcloud:3']);
  });

  test('invalid backups are rejected without changes', () async {
    await seed(lib);
    final m = lib.module.maintenance;
    await expectLater(m.importBackup({'format': 'nope'}), throwsA(isA<StorageException>()));
    await expectLater(
      m.importBackup({'format': 'fermata.library.backup', 'version': 99}),
      throwsA(isA<StorageException>().having((e) => e.code, 'code', 'backup_unsupported')),
    );
    await expectLater(
      m.importBackup({
        'format': 'fermata.library.backup',
        'version': 1,
        'playlists': [
          {'id': 'new', 'name': 'Half', 'kind': 'local', 'entries': []},
        ],
        'favorites': [
          {'trackId': 42}, // malformed
        ],
      }),
      throwsA(isA<StorageException>().having((e) => e.code, 'code', 'backup_invalid')),
    );
    // The transaction rolled back: the half-imported playlist is not there.
    expect(await lib.module.playlists.getPlaylist('new'), isNull);
  });

  test('deleteAllUserData keeps local files, folders and downloads', () async {
    await seed(lib);
    final m = lib.module;
    await m.downloadedIndex.replaceAll({'soundcloud:3'});
    await m.maintenance.deleteAllUserData();
    expect(await m.playlists.playlists(), isEmpty);
    expect(await m.favorites.favorites(), isEmpty);
    expect(await m.history.history(), isEmpty);
    expect(await m.links.linkedTracks('soundcloud:1'), isEmpty);
    expect(await m.searchHistory.recent(), isEmpty);
    final remaining = (await m.tracks.query(const TrackQuery())).map((t) => t.id).toSet();
    expect(remaining, {'local:l1', 'soundcloud:3'});
    expect((await m.tracks.getTrack('local:l1'))!.title, 'Local One (edited)');
    expect((await m.localLibrary.folders()).length, 1);
  });

  test('databaseSizeBytes reports the file size', () async {
    final onDisk = await openTestLibrary(onDisk: true);
    addTearDown(onDisk.dispose);
    final before = await onDisk.module.maintenance.databaseSizeBytes();
    expect(before, greaterThan(0));
    await onDisk.module.tracks.upsertTracks([for (var i = 0; i < 300; i++) remoteTrack('$i', title: 'x' * 200)]);
    expect(await onDisk.module.maintenance.databaseSizeBytes(), greaterThan(before));
    expect(await lib.module.maintenance.databaseSizeBytes(), greaterThan(0)); // in-memory: pages
  });
}
