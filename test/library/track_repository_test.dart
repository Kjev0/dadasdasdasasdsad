import 'dart:io';

import 'package:fermata/core/contracts/library.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers.dart';

void main() {
  late TestLibrary lib;
  setUp(() async => lib = await openTestLibrary());
  tearDown(() async => lib.dispose());

  group('CRUD', () {
    test('upsert, get, getTracks order, count, remove', () async {
      final repo = lib.module.tracks;
      await repo.upsertTracks([remoteTrack('1'), remoteTrack('2'), remoteTrack('3')]);
      expect((await repo.getTrack('soundcloud:2'))!.title, 'Title 2');
      expect(await repo.getTrack('soundcloud:404'), isNull);
      final ordered = await repo.getTracks(['soundcloud:3', 'nope', 'soundcloud:1']);
      expect(ordered.map((t) => t.id), ['soundcloud:3', 'soundcloud:1']);
      expect(await repo.count(const TrackQuery()), 3);
      await repo.removeTracks(['soundcloud:1']);
      expect(await repo.count(const TrackQuery()), 2);
    });

    test('upsert keeps date_added and updates metadata', () async {
      final repo = lib.module.tracks;
      await repo.upsertTracks([remoteTrack('1', title: 'First')]);
      final before = await lib.module.database.db.query('tracks', columns: ['date_added']);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.upsertTracks([remoteTrack('1', title: 'Renamed')]);
      final after = await lib.module.database.db.query('tracks', columns: ['date_added']);
      expect(after.single['date_added'], before.single['date_added']);
      expect((await repo.getTrack('soundcloud:1'))!.title, 'Renamed');
    });

    test('round-trips the full Track JSON', () async {
      final t = Track(
        sourceId: 'deezer',
        sourceTrackId: '42',
        title: 'Song',
        artists: const [ArtistRef('A', sourceArtistId: '7'), ArtistRef('B')],
        album: 'LP',
        albumArtist: 'A',
        duration: const Duration(milliseconds: 123456),
        isrc: 'GBAYE0601498',
        explicit: true,
        year: 2001,
        genre: 'Pop',
        trackNumber: 2,
        discNumber: 1,
        artworkUrl: Uri.parse('https://img/x.jpg'),
        permalink: Uri.parse('https://deezer.com/track/42'),
        availability: const TrackAvailability(playback: PlaybackRights.preview, offline: OfflineRights.streamOnly, previewDuration: Duration(seconds: 30)),
        format: const AudioFormatInfo(codec: 'mp3', bitrateKbps: 128),
        replayGainTrackDb: -3.2,
        extra: const {'k': 'v'},
      );
      await lib.module.tracks.upsertTracks([t]);
      final back = (await lib.module.tracks.getTrack(t.id))!;
      expect(back.toJson(), t.toJson());
    });

    test('override_json wins over source values and survives re-upserts', () async {
      final repo = lib.module.tracks;
      await repo.upsertTracks([remoteTrack('1', title: 'Scanned', genre: 'Rock')]);
      await repo.setOverride('soundcloud:1', {'title': 'Edited', 'genre': null});
      var t = (await repo.getTrack('soundcloud:1'))!;
      expect(t.title, 'Edited');
      expect(t.genre, isNull);
      await repo.upsertTracks([remoteTrack('1', title: 'Rescanned', genre: 'Jazz', album: 'New Album')]);
      t = (await repo.getTrack('soundcloud:1'))!;
      expect(t.title, 'Edited');
      expect(t.genre, isNull);
      expect(t.album, 'New Album');
      // Denormalized columns follow the effective values (search finds the edit).
      expect(await repo.count(const TrackQuery(text: 'edited')), 1);
      expect(await repo.count(const TrackQuery(text: 'rescanned')), 0);
      await repo.setOverride('soundcloud:1', null);
      expect((await repo.getTrack('soundcloud:1'))!.title, 'Rescanned');
    });

    test('change bus coalesces notifications', () async {
      final events = <Set<LibraryTopic>>[];
      final sub = lib.module.changes.changes.listen(events.add);
      await lib.module.tracks.upsertTracks([remoteTrack('1')]);
      await lib.module.tracks.removeTracks(['soundcloud:1']);
      await pumpEventQueue();
      expect(events, isNotEmpty);
      expect(events.expand((e) => e), contains(LibraryTopic.tracks));
      await sub.cancel();
    });
  });

  group('search & filters', () {
    setUp(() async {
      await lib.module.tracks.upsertTracks([
        remoteTrack('1', title: 'Blåbærgrød', artists: ['Søren Ørsted'], album: 'Ålborg Nights', genre: 'Jazz', year: 1999, seconds: 200),
        remoteTrack('2', title: 'Café del Mar', artists: ['Beyoncé', 'Jay-Z'], album: 'Ibiza', genre: 'Chill', year: 2005, seconds: 300),
        remoteTrack('3', source: 'audius', title: 'Æble', artists: ['Kim Larsen'], album: 'Aalborg Nights', genre: 'jazz', year: 2010, seconds: 100),
        localTrack('l1', '/music/a.flac', title: 'Local Song', artists: ['Kim Larsen'], seconds: 250),
      ]);
    });

    Future<List<String>> ids(TrackQuery q) async => (await lib.module.tracks.query(q)).map((t) => t.id).toList();

    test('accent and case insensitive text search', () async {
      expect(await ids(const TrackQuery(text: 'blabaergrod')), ['soundcloud:1']);
      expect(await ids(const TrackQuery(text: 'SOREN')), ['soundcloud:1']);
      expect(await ids(const TrackQuery(text: 'beyonce cafe')), ['soundcloud:2']);
      expect(await ids(const TrackQuery(text: 'aeble')), ['audius:3']);
      // å / aa / a all match.
      expect((await ids(const TrackQuery(text: 'aalborg'))).toSet(), {'soundcloud:1', 'audius:3'});
      expect((await ids(const TrackQuery(text: 'ålborg'))).toSet(), {'soundcloud:1', 'audius:3'});
      expect((await ids(const TrackQuery(text: 'alborg'))).toSet(), {'soundcloud:1', 'audius:3'});
      expect(await ids(const TrackQuery(text: '100%')), isEmpty);
    });

    test('field filters', () async {
      expect((await ids(const TrackQuery(sourceIds: {'audius', 'local'}))).toSet(), {'audius:3', 'local:l1'});
      expect((await ids(const TrackQuery(artist: 'kim larsen'))).toSet(), {'audius:3', 'local:l1'});
      expect(await ids(const TrackQuery(artist: 'jay-z')), ['soundcloud:2']);
      expect((await ids(const TrackQuery(genre: 'JAZZ'))).toSet(), {'soundcloud:1', 'audius:3'});
      expect(await ids(const TrackQuery(album: 'ibiza')), ['soundcloud:2']);
      expect((await ids(const TrackQuery(minYear: 2000, maxYear: 2006))), ['soundcloud:2']);
      expect((await ids(const TrackQuery(minDuration: Duration(seconds: 150), maxDuration: Duration(seconds: 260)))).toSet(),
          {'soundcloud:1', 'local:l1'});
      expect(await ids(const TrackQuery(localFilesOnly: true)), ['local:l1']);
      expect(await ids(const TrackQuery(offlineAvailableOnly: true)), ['local:l1']);
      await lib.module.downloadedIndex.replaceAll({'soundcloud:2'});
      expect(await ids(const TrackQuery(downloadedOnly: true)), ['soundcloud:2']);
      expect((await ids(const TrackQuery(offlineAvailableOnly: true))).toSet(), {'local:l1', 'soundcloud:2'});
      await lib.module.favorites.setFavorite((await lib.module.tracks.getTrack('audius:3'))!, true);
      expect(await ids(const TrackQuery(favoritesOnly: true)), ['audius:3']);
    });

    test('sorting, limit and offset', () async {
      expect(await ids(const TrackQuery(sort: TrackSortField.duration, descending: false)),
          ['audius:3', 'soundcloud:1', 'local:l1', 'soundcloud:2']);
      expect(await ids(const TrackQuery(sort: TrackSortField.year, descending: true)),
          ['audius:3', 'soundcloud:2', 'soundcloud:1', 'local:l1']); // null year last
      expect(await ids(const TrackQuery(sort: TrackSortField.title, descending: false, limit: 2, offset: 1)),
          ['soundcloud:1', 'soundcloud:2']); // aeble, blabaergrod, cafe, local
      final history = lib.module.history;
      final t2 = (await lib.module.tracks.getTrack('soundcloud:2'))!;
      final t3 = (await lib.module.tracks.getTrack('audius:3'))!;
      for (var i = 0; i < 3; i++) {
        await history.recordPlay(PlayRecord(track: t2, playedAt: DateTime(2024, 1, 1 + i), listened: const Duration(minutes: 1), completed: true));
      }
      await history.recordPlay(PlayRecord(track: t3, playedAt: DateTime(2024, 2, 1), listened: const Duration(minutes: 1), completed: true));
      expect((await ids(const TrackQuery(sort: TrackSortField.playCount))).take(2), ['soundcloud:2', 'audius:3']);
      expect((await ids(const TrackQuery(sort: TrackSortField.lastPlayed))).take(2), ['audius:3', 'soundcloud:2']);
    });

    test('albums, artists and genres', () async {
      final albums = await lib.module.tracks.albums();
      expect(albums.map((a) => a.title), containsAll(['Ålborg Nights', 'Ibiza', 'Aalborg Nights']));
      final ibiza = albums.firstWhere((a) => a.title == 'Ibiza');
      expect(ibiza.artist, 'Beyoncé');
      expect(ibiza.trackCount, 1);
      expect(ibiza.totalDuration, const Duration(seconds: 300));
      expect((await lib.module.tracks.albums(artist: 'Kim Larsen')).map((a) => a.title), ['Aalborg Nights']);
      expect((await lib.module.tracks.albums(text: 'ibiza')).length, 1);

      final artists = await lib.module.tracks.artists();
      final kim = artists.firstWhere((a) => a.name == 'Kim Larsen');
      expect(kim.trackCount, 2);
      expect(artists.map((a) => a.name), contains('Jay-Z'));
      expect((await lib.module.tracks.artists(text: 'beyonce')).single.name, 'Beyoncé');

      final genres = await lib.module.tracks.genres();
      expect(genres.length, 2); // Jazz + jazz folded together, Chill
      expect(genres.map((g) => g.toLowerCase()).toSet(), {'chill', 'jazz'});
    });
  });

  group('duplicates & missing files', () {
    test('findDuplicates groups by hash, ISRC and metadata', () async {
      final db = lib.module.database.db;
      await lib.module.tracks.upsertTracks([
        localTrack('a', '/m/a.mp3', title: 'Same', artists: ['X'], seconds: 100),
        localTrack('b', '/m/b.mp3', title: 'Other', artists: ['Y'], seconds: 50),
        remoteTrack('i1', isrc: 'USRC17607839', title: 'One'),
        remoteTrack('i2', isrc: 'usrc-1760-7839', title: 'Two'),
        remoteTrack('m1', title: 'Hello', artists: ['Adele'], seconds: 295),
        remoteTrack('m2', title: 'HELLO', artists: ['adele'], seconds: 296),
        remoteTrack('m3', title: 'Hello', artists: ['Adele'], seconds: 400), // different length
        remoteTrack('x1', source: 'audius', title: 'Hello', artists: ['Adele'], seconds: 295), // other source
      ]);
      await db.update('tracks', {'file_hash': 'h1'}, where: 'id IN (?, ?)', whereArgs: ['local:a', 'local:b']);
      final groups = await lib.module.tracks.findDuplicates();
      final byReason = {for (final g in groups) g.reason: g.tracks.map((t) => t.id).toSet()};
      expect(byReason['same_hash'], {'local:a', 'local:b'});
      expect(byReason['same_isrc'], {'soundcloud:i1', 'soundcloud:i2'});
      expect(byReason['same_metadata'], {'soundcloud:m1', 'soundcloud:m2'});
      expect(groups.length, 3);
    });

    test('findMissingFiles checks the file system and flags availability', () async {
      final dir = Directory(p.join(lib.root.path, 'files'))..createSync();
      final present = File(p.join(dir.path, 'here.mp3'))..writeAsStringSync('x');
      await lib.module.tracks.upsertTracks([
        localTrack('here', present.path),
        localTrack('gone', p.join(dir.path, 'gone.mp3')),
        remoteTrack('r'),
      ]);
      final missing = await lib.module.tracks.findMissingFiles();
      expect(missing.map((t) => t.id), ['local:gone']);
      expect(missing.single.availability.reason, AvailabilityReason.fileMissing);
      expect((await lib.module.tracks.getTrack('local:here'))!.availability.offline, OfflineRights.userOwned);
      expect(await lib.module.tracks.count(const TrackQuery(offlineAvailableOnly: true)), 1);
      File(p.join(dir.path, 'gone.mp3')).writeAsStringSync('back');
      expect(await lib.module.tracks.findMissingFiles(), isEmpty);
      expect((await lib.module.tracks.getTrack('local:gone'))!.availability.playback, PlaybackRights.full);
    });
  });
}
