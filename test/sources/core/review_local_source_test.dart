// Adversarial review tests for LocalSource, run against the real SQLite
// TrackRepository of the library module (not a hand-written fake).
// Each test demonstrates a defect; they are expected to FAIL until fixed.
import 'package:fermata/core/models/track.dart';
import 'package:fermata/sources/local/local_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../library/helpers.dart';

void main() {
  late TestLibrary lib;
  late LocalSource source;

  setUp(() async {
    lib = await openTestLibrary();
    await lib.module.tracks.upsertTracks([
      // The user's own file.
      Track(
        sourceId: 'local',
        sourceTrackId: 'f1',
        title: 'Teardrop',
        artists: const [ArtistRef('Massive Attack')],
        album: 'Mezzanine',
        genre: 'Trip Hop',
        localPath: '${lib.root.path}/teardrop.flac',
        availability: const TrackAvailability.local(),
      ),
      // Remote tracks the library stores because the user favorited /
      // played / imported them (they are NOT local files).
      remoteTrack(
        'dz1',
        source: 'deezer',
        title: 'Angel',
        artists: const ['Massive Attack Tribute Band'],
        album: 'Massive Covers',
        genre: 'Deezer Pop',
        artwork: Uri.parse('https://cdn-images.dzcdn.net/images/cover/x/500x500.jpg'),
      ),
      remoteTrack('sc1', source: 'soundcloud', title: 'Mix', artists: const ['Massive DJ'], genre: 'SoundCloud House'),
    ]);
    source = LocalSource(tracks: lib.module.tracks);
  });

  tearDown(() async {
    await source.dispose();
    await lib.dispose();
  });

  test('searchTracks only returns local files (sanity check, passes)', () async {
    final page = await source.searchTracks('massive');
    expect(page.items.map((t) => t.sourceId).toSet(), {'local'});
  });

  test('searchArtists must only return artists of local files', () async {
    final page = await source.searchArtists('massive');
    // BUG: LocalSource.searchArtists uses TrackRepository.artists(), which
    // aggregates over every row of `tracks` (remote favorites/history too).
    // "Massive Attack Tribute Band" (Deezer) and "Massive DJ" (SoundCloud)
    // are shown as "Local files" artists whose artist page is then empty.
    expect(page.items.map((a) => a.name), ['Massive Attack']);
  });

  test('searchAlbums must only return albums of local files', () async {
    final page = await source.searchAlbums('massive');
    expect(page.items.map((a) => a.title), isNot(contains('Massive Covers')));
    for (final album in page.items) {
      final tracks = await source.albumTracks(album.sourceAlbumId);
      expect(tracks.items, isNotEmpty, reason: 'local album "${album.title}" opens an empty page');
    }
  });

  test('genres must only list genres of local files', () async {
    final genres = await source.genres();
    expect(genres, ['Trip Hop']);
  });
}
