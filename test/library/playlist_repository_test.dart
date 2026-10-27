import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/library/repositories/playlist_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestLibrary lib;
  late SqlPlaylistRepository repo;

  setUp(() async {
    lib = await openTestLibrary();
    repo = lib.module.playlists;
    await lib.module.tracks.upsertTracks([for (var i = 1; i <= 6; i++) remoteTrack('$i')]);
  });
  tearDown(() async => lib.dispose());

  String id(int i) => 'soundcloud:$i';

  group('CRUD', () {
    test('create, list, get, update, delete', () async {
      final p = await repo.createPlaylist('  Road trip ', description: 'Summer', sourceId: 'spotify', sourcePlaylistId: 'abc');
      expect(p.name, 'Road trip');
      expect(p.kind, PlaylistKind.local);
      expect(p.trackCount, 0);
      expect(p.sourceId, 'spotify');
      await repo.createPlaylist('A list');
      expect((await repo.playlists()).map((p) => p.name), ['A list', 'Road trip']);
      await repo.updatePlaylist(p.copyWith(name: 'Road trip 2025', autoDownload: true));
      final got = (await repo.getPlaylist(p.id))!;
      expect(got.name, 'Road trip 2025');
      expect(got.autoDownload, isTrue);
      expect((await repo.autoDownloadPlaylists()).map((p) => p.id), [p.id]);
      await repo.deletePlaylist(p.id);
      expect(await repo.getPlaylist(p.id), isNull);
      expect(() => repo.createPlaylist('   '), throwsArgumentError);
    });

    test('add (append + insert), track count and order', () async {
      final p = await repo.createPlaylist('P');
      await repo.addTracks(p.id, [id(1), id(2), id(3)]);
      await repo.addTracks(p.id, [id(4), id(5)], position: 1);
      expect(await repo.playlistTrackIds(p.id), [id(1), id(4), id(5), id(2), id(3)]);
      await repo.addTracks(p.id, [id(1)], position: 0); // duplicates are allowed
      expect(await repo.playlistTrackIds(p.id), [id(1), id(1), id(4), id(5), id(2), id(3)]);
      expect((await repo.getPlaylist(p.id))!.trackCount, 6);
      final tracks = await repo.playlistTracks(p.id);
      expect(tracks.first.title, 'Title 1');
    });

    test('adding unknown tracks fails', () async {
      final p = await repo.createPlaylist('P');
      await expectLater(repo.addTracks(p.id, ['nope:1']), throwsA(isA<StorageException>()));
      expect(await repo.playlistTrackIds(p.id), isEmpty);
    });

    test('removeAt, removeTracks, move', () async {
      final p = await repo.createPlaylist('P');
      await repo.addTracks(p.id, [id(1), id(2), id(3), id(4), id(5), id(2)]);
      await repo.removeAt(p.id, [0, 2]);
      expect(await repo.playlistTrackIds(p.id), [id(2), id(4), id(5), id(2)]);
      await repo.removeTracks(p.id, [id(2)]);
      expect(await repo.playlistTrackIds(p.id), [id(4), id(5)]);
      await repo.addTracks(p.id, [id(1), id(6)]);
      await repo.move(p.id, 0, 3);
      expect(await repo.playlistTrackIds(p.id), [id(5), id(1), id(6), id(4)]);
      await repo.move(p.id, 3, 0);
      expect(await repo.playlistTrackIds(p.id), [id(4), id(5), id(1), id(6)]);
      await repo.move(p.id, 1, 99); // clamped
      expect(await repo.playlistTrackIds(p.id), [id(4), id(1), id(6), id(5)]);
    });

    test('removing a track from the library removes its entries (positions stay consistent)', () async {
      final p = await repo.createPlaylist('P');
      await repo.addTracks(p.id, [id(1), id(2), id(3)]);
      await lib.module.tracks.removeTracks([id(2)]);
      expect(await repo.playlistTrackIds(p.id), [id(1), id(3)]);
      await repo.addTracks(p.id, [id(4)], position: 1);
      expect(await repo.playlistTrackIds(p.id), [id(1), id(4), id(3)]);
    });

    test('deduplicate removes same ids and linked duplicates', () async {
      final p = await repo.createPlaylist('P');
      await lib.module.links.link(id(1), id(5), confidence: 0.95);
      await lib.module.links.link(id(5), id(6), confidence: 0.9); // 1 ~ 6 transitively
      await repo.addTracks(p.id, [id(1), id(2), id(1), id(3), id(6), id(2), id(4)]);
      final removed = await repo.deduplicate(p.id);
      expect(removed, 3);
      expect(await repo.playlistTrackIds(p.id), [id(1), id(2), id(3), id(4)]);
      expect(await repo.deduplicate(p.id), 0);
    });
  });

  group('smart playlists', () {
    setUp(() async {
      await lib.module.tracks.upsertTracks([
        remoteTrack('j1', title: 'Søren Blues', artists: ['Ben Webster'], genre: 'Jazz', year: 1960, seconds: 300),
        remoteTrack('j2', title: 'Take Five', artists: ['Dave Brubeck', 'Paul Desmond'], genre: 'Jazz', year: 1959, seconds: 324),
        remoteTrack('r1', source: 'audius', title: 'Thunderstruck', artists: ['AC/DC'], genre: 'Rock', year: 1990, seconds: 292),
        remoteTrack('p1', source: 'deezer', title: 'Hello', artists: ['Adele'], genre: 'Pop', year: 2015, seconds: 295),
      ]);
      final h = lib.module.history;
      final t = await lib.module.tracks.getTracks(['soundcloud:j2', 'audius:r1']);
      for (var i = 0; i < 3; i++) {
        await h.recordPlay(PlayRecord(track: t[0], playedAt: DateTime.now().subtract(Duration(days: i)), listened: const Duration(minutes: 5), completed: true));
      }
      await h.recordPlay(PlayRecord(track: t[1], playedAt: DateTime.now().subtract(const Duration(days: 60)), listened: const Duration(minutes: 5), completed: true));
      await lib.module.favorites.setFavorite((await lib.module.tracks.getTrack('deezer:p1'))!, true);
      await lib.module.downloadedIndex.replaceAll({'soundcloud:j1'});
    });

    Future<List<String>> eval(List<SmartRule> rules, {bool all = true, int? limit, TrackSortField sort = TrackSortField.title, bool desc = false}) async {
      final p = await repo.createSmartPlaylist('S', SmartPlaylistRules(rules: rules, matchAll: all, limit: limit, sort: sort, descending: desc));
      expect(p.kind, PlaylistKind.smart);
      return repo.playlistTrackIds(p.id);
    }

    test('text rules (folded, any artist)', () async {
      expect(await eval([const SmartRule(field: SmartField.genre, op: SmartOperator.equals, value: 'jazz')]),
          ['soundcloud:j1', 'soundcloud:j2']);
      expect(await eval([const SmartRule(field: SmartField.title, op: SmartOperator.contains, value: 'soren')]), ['soundcloud:j1']);
      expect(await eval([const SmartRule(field: SmartField.artist, op: SmartOperator.equals, value: 'Paul Desmond')]), ['soundcloud:j2']);
      expect(await eval([const SmartRule(field: SmartField.title, op: SmartOperator.startsWith, value: 'th')]), ['audius:r1']);
      expect(await eval([const SmartRule(field: SmartField.source, op: SmartOperator.notEquals, value: 'soundcloud')]).then((v) => v.toSet()),
          {'audius:r1', 'deezer:p1'});
    });

    test('numeric and date rules, AND / OR, sort and limit', () async {
      expect(await eval([
        const SmartRule(field: SmartField.year, op: SmartOperator.lessThan, value: 1991),
        const SmartRule(field: SmartField.duration, op: SmartOperator.greaterThan, value: 295),
      ]), ['soundcloud:j1', 'soundcloud:j2']);
      expect(await eval([const SmartRule(field: SmartField.playCount, op: SmartOperator.greaterThan, value: 2)]), ['soundcloud:j2']);
      expect(await eval([const SmartRule(field: SmartField.lastPlayed, op: SmartOperator.inLastDays, value: 7)]), ['soundcloud:j2']);
      final stale = (await eval([const SmartRule(field: SmartField.lastPlayed, op: SmartOperator.notInLastDays, value: 30)])).toSet();
      expect(stale, containsAll(['audius:r1', 'soundcloud:j1', 'deezer:p1', 'soundcloud:1'])); // includes never played
      expect(stale, isNot(contains('soundcloud:j2')));
      expect(await eval([const SmartRule(field: SmartField.dateAdded, op: SmartOperator.inLastDays, value: 1)]).then((v) => v.length), 10);
      expect(
        await eval([
          const SmartRule(field: SmartField.genre, op: SmartOperator.equals, value: 'Rock'),
          const SmartRule(field: SmartField.genre, op: SmartOperator.equals, value: 'Pop'),
        ], all: false),
        ['deezer:p1', 'audius:r1'],
      );
      expect(
        await eval([const SmartRule(field: SmartField.genre, op: SmartOperator.equals, value: 'jazz')],
            sort: TrackSortField.year, desc: true, limit: 1),
        ['soundcloud:j1'],
      );
    });

    test('favorite and downloaded flags', () async {
      expect(await eval([const SmartRule(field: SmartField.favorite, op: SmartOperator.isTrue)]), ['deezer:p1']);
      expect(await eval([const SmartRule(field: SmartField.downloaded, op: SmartOperator.equals, value: true)]), ['soundcloud:j1']);
      expect((await eval([
        const SmartRule(field: SmartField.favorite, op: SmartOperator.isFalse),
        const SmartRule(field: SmartField.genre, op: SmartOperator.equals, value: 'pop'),
      ])), isEmpty);
    });

    test('rules SQL cannot express are evaluated in Dart', () async {
      // String operator on a numeric field -> Dart fallback.
      expect(await eval([const SmartRule(field: SmartField.year, op: SmartOperator.startsWith, value: '19')]),
          ['soundcloud:j1', 'soundcloud:j2', 'audius:r1']);
      // Mixed with an SQL rule in OR mode.
      expect(
        (await eval([
          const SmartRule(field: SmartField.year, op: SmartOperator.contains, value: '015'),
          const SmartRule(field: SmartField.genre, op: SmartOperator.equals, value: 'rock'),
        ], all: false)).toSet(),
        {'deezer:p1', 'audius:r1'},
      );
      // Nonsense combination matches nothing.
      expect(await eval([const SmartRule(field: SmartField.favorite, op: SmartOperator.contains, value: 'x')]), isEmpty);
    });

    test('smart playlists are live, counted and read-only', () async {
      final p = await repo.createSmartPlaylist(
        'Jazz',
        const SmartPlaylistRules(rules: [SmartRule(field: SmartField.genre, op: SmartOperator.equals, value: 'Jazz')]),
      );
      expect((await repo.getPlaylist(p.id))!.trackCount, 2);
      await lib.module.tracks.upsertTracks([remoteTrack('j3', genre: 'Jazz')]);
      expect((await repo.getPlaylist(p.id))!.trackCount, 3);
      expect(SqlPlaylistRepository.rulesOf(p)!.rules.single.field, SmartField.genre);
      await expectLater(repo.addTracks(p.id, ['soundcloud:1']), throwsA(isA<StorageException>()));
    });
  });
}
