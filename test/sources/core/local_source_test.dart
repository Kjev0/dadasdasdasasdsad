import 'dart:io';

import 'package:fermata/core/contracts/library.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/sources/base/paging.dart';
import 'package:fermata/sources/local/local_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal in-memory TrackRepository implementing the filters LocalSource
/// relies on (text/artist/album/sourceIds/localFilesOnly, limit/offset).
class _FakeTracks implements TrackRepository {
  _FakeTracks(this.tracks);

  final List<Track> tracks;
  final List<TrackQuery> queries = [];

  @override
  Future<List<Track>> query(TrackQuery q) async {
    queries.add(q);
    bool has(String? field, String? needle) => needle == null || (field ?? '').toLowerCase() == needle.toLowerCase();
    var r = tracks.where((t) {
      if (q.sourceIds != null && !q.sourceIds!.contains(t.sourceId)) return false;
      if (q.localFilesOnly && t.localPath == null) return false;
      if (q.text != null) {
        final hay = '${t.title} ${t.artistLine} ${t.album ?? ''}'.toLowerCase();
        if (!hay.contains(q.text!.toLowerCase())) return false;
      }
      return has(t.primaryArtist, q.artist) && has(t.album, q.album);
    }).toList();
    r.sort((a, b) => a.title.compareTo(b.title));
    r = r.skip(q.offset).toList();
    if (q.limit != null) r = r.take(q.limit!).toList();
    return r;
  }

  @override
  Future<Track?> getTrack(String id) async => tracks.where((t) => t.id == id).firstOrNull;

  @override
  Future<List<ArtistSummary>> artists({String? text}) async {
    final names = <String>{
      for (final t in tracks)
        if (text == null || t.primaryArtist.toLowerCase().contains(text.toLowerCase())) t.primaryArtist,
    };
    return [
      for (final n in names) ArtistSummary(name: n, trackCount: tracks.where((t) => t.primaryArtist == n).length),
    ];
  }

  @override
  Future<List<AlbumSummary>> albums({String? artist, String? text}) async {
    final keys = <(String, String)>{
      for (final t in tracks)
        if (t.album != null && (text == null || t.album!.toLowerCase().contains(text.toLowerCase())))
          (t.albumArtist ?? t.primaryArtist, t.album!),
    };
    return [for (final k in keys) AlbumSummary(title: k.$2, artist: k.$1, trackCount: 1, year: 2001)];
  }

  @override
  Future<List<String>> genres() async => {for (final t in tracks) ?t.genre}.toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  late Directory tmp;
  late File existing;
  late _FakeTracks repo;
  late LocalSource source;

  Track local(
    String id,
    String title,
    String artist, {
    String? album,
    int? no,
    int? disc,
    String? path,
    String? genre,
  }) => Track(
    sourceId: 'local',
    sourceTrackId: id,
    title: title,
    artists: [ArtistRef(artist)],
    album: album,
    trackNumber: no,
    discNumber: disc,
    localPath: path ?? '/music/$id.flac',
    genre: genre,
    availability: const TrackAvailability.local(),
  );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fermata_local');
    existing = File('${tmp.path}/one more time.flac')..writeAsBytesSync([0, 1, 2]);
    repo = _FakeTracks([
      local('1', 'One More Time', 'Daft Punk', album: 'Discovery', no: 1, path: existing.path, genre: 'House'),
      local('2', 'Aerodynamic', 'Daft Punk', album: 'Discovery', no: 2, genre: 'House'),
      local('3', 'Digital Love', 'Daft Punk', album: 'Discovery', no: 3),
      local('4', 'Teardrop', 'Massive Attack', album: 'Mezzanine', no: 3, disc: 1),
      local('5', 'Angel', 'Massive Attack', album: 'Mezzanine', no: 1, disc: 1),
      const Track(sourceId: 'audius', sourceTrackId: 'x', title: 'Daft remote'),
    ]);
    source = LocalSource(tracks: repo);
  });
  tearDown(() async {
    await source.dispose();
    await tmp.delete(recursive: true);
  });

  test('identity and capabilities', () {
    expect(source.id, 'local');
    expect(source.isReady, isTrue);
    expect(source.authState.status, SourceConnectionStatus.notRequired);
    for (final c in [
      SourceCapability.searchTracks,
      SourceCapability.stream,
      SourceCapability.artistPages,
      SourceCapability.albumPages,
    ]) {
      expect(source.supports(c), isTrue, reason: c.name);
    }
    expect(source.supports(SourceCapability.download), isFalse);
  });

  test('searchTracks queries local files only, with paging', () async {
    final page = await source.searchTracks('daft', limit: 2);
    expect(repo.queries.last.localFilesOnly, isTrue);
    expect(repo.queries.last.sourceIds, {'local'});
    expect(page.items.map((t) => t.title), ['Aerodynamic', 'Digital Love']);
    expect(page.hasMore, isTrue);
    final next = await source.searchTracks('daft', cursor: page.nextCursor, limit: 2);
    expect(next.items.map((t) => t.title), ['One More Time']);
    expect(next.hasMore, isFalse);
    expect((await source.searchTracks('  ')).items, isEmpty);
  });

  test('artists and albums from library queries', () async {
    final artists = await source.searchArtists('massive');
    expect(artists.items.single.name, 'Massive Attack');
    expect(artists.items.single.sourceArtistId, 'Massive Attack');
    final top = await source.artistTopTracks('Massive Attack');
    expect(top.items.map((t) => t.title).toSet(), {'Teardrop', 'Angel'});

    final albums = await source.searchAlbums('mezz');
    final album = albums.items.single;
    expect(album.title, 'Mezzanine');
    expect(LocalSource.decodeAlbumId(album.sourceAlbumId), (artist: 'Massive Attack', title: 'Mezzanine'));
    final tracks = await source.albumTracks(album.sourceAlbumId);
    expect(tracks.items.map((t) => t.title), ['Angel', 'Teardrop'], reason: 'disc/track order');
    expect(() => LocalSource.decodeAlbumId(PageCursor.encodeOffset(1)), throwsFormatException);
    expect(await source.genres(), ['House']);
  });

  test('getTrack only returns local tracks', () async {
    expect((await source.getTrack('1'))!.title, 'One More Time');
    expect(await source.getTrack('missing'), isNull);
  });

  test('resolveStream returns a file:// URI for existing files', () async {
    final s = await source.resolveStream(repo.tracks.first);
    expect(s.uri.scheme, 'file');
    expect(s.uri.toFilePath(), existing.path);
    expect(s.isLocalFile, isTrue);
  });

  test('resolveStream reports file_missing', () async {
    await expectLater(
      source.resolveStream(repo.tracks[1]),
      throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.fileMissing)),
    );
  });

  test('resolveStream falls back to the stored path', () async {
    final withoutPath = Track(sourceId: 'local', sourceTrackId: '1', title: 'x');
    final s = await source.resolveStream(withoutPath);
    expect(s.uri.toFilePath(), existing.path);
  });

  test('downloads are not needed', () async {
    expect(await source.authorizeDownload(repo.tracks.first), isNull);
    expect(source.externalPlaybackUri(repo.tracks.first), isNull);
  });
}
