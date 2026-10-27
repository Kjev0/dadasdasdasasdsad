import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/ui/actions/routes.dart';
import 'package:fermata/ui/pages/album/album_page.dart';
import 'package:fermata/ui/pages/artist/artist_page.dart';
import 'package:fermata/ui/pages/artist/artist_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'support/page_harness.dart';

Track _albumTrack(String sid, {String sourceId = SourceIds.audius, required int disc, required int no, OfflineRights offline = OfflineRights.streamOnly}) =>
    testTrack(sid, sourceId: sourceId, title: 'Track $sid', album: 'Double Album', artist: 'Band', offline: offline, extra: const {'albumId': 'al1'})
        .copyWith(discNumber: disc, trackNumber: no, year: 2024);

void main() {
  group('artist', () {
    FakeMusicSource soundcloud() => FakeMusicSource(
          id: SourceIds.soundcloud,
          displayName: 'SoundCloud',
          capabilities: const {SourceCapability.searchTracks, SourceCapability.stream, SourceCapability.artistPages},
          artists: [
            Artist(
              sourceId: SourceIds.soundcloud,
              sourceArtistId: 'u1',
              name: 'Producer',
              followers: 12500,
              permalink: Uri.parse('https://soundcloud.com/producer'),
              genres: const ['House'],
            ),
            const Artist(sourceId: SourceIds.soundcloud, sourceArtistId: 'u2', name: 'Friend'),
          ],
          tracks: [
            for (var i = 1; i <= 7; i++)
              testTrack('s$i', sourceId: SourceIds.soundcloud, title: 'Cut $i', artist: 'Producer', artistId: 'u1', album: 'EP', extra: const {'albumId': 'ep1'}),
          ],
        );

    testWidgets('header, top tracks, releases, related artists and provider link with attribution', (tester) async {
      final kit = FakeKit(sources: [soundcloud()]);
      await pumpPage(tester, kit: kit, route: AppRoutes.artist(SourceIds.soundcloud, 'u1'));
      expect(find.text('Producer'), findsWidgets);
      expect(find.text('ARTIST ON SOUNDCLOUD'), findsOneWidget);
      expect(find.text('12.5K followers · House'), findsOneWidget);
      expect(find.byKey(const ValueKey('artist-attribution')), findsOneWidget);
      expect(find.text('Popular tracks'), findsOneWidget);
      expect(find.text('Cut 5'), findsOneWidget);
      expect(find.text('Cut 6'), findsNothing);
      await tester.tap(find.text('Show all 7'));
      await settle(tester);
      expect(find.text('Cut 7'), findsOneWidget);
      expect(find.text('Releases'), findsOneWidget);
      expect(find.byKey(const ValueKey('artist-album-ep1')), findsOneWidget);
      expect(find.text('Fans also like'), findsOneWidget);
      expect(find.text('Friend'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('artist-open-on-provider')));
      await settle(tester);
      expect(kit.openedLinks.single.toString(), 'https://soundcloud.com/producer');
    });

    testWidgets('play plays the top tracks', (tester) async {
      final kit = FakeKit(sources: [soundcloud()]);
      await pumpPage(tester, kit: kit, route: AppRoutes.artist(SourceIds.soundcloud, 'u1'));
      await tester.tap(find.widgetWithText(FilledButton, 'Play'));
      await settle(tester);
      expect((kit.playback.argsOf('playTracks')[0] as List).length, 7);
    });

    testWidgets('library artist by name', (tester) async {
      final kit = FakeKit(tracks: [
        testTrack('l1', sourceId: SourceIds.local, title: 'Feeling Good', artist: 'Nina Simone', album: 'I Put a Spell on You'),
        testTrack('l2', sourceId: SourceIds.local, title: 'Sinnerman', artist: 'Nina Simone', album: 'Pastel Blues'),
      ]);
      await pumpPage(tester, kit: kit, route: AppRoutes.artist(SourceIds.local, 'Nina Simone'));
      expect(find.text('ARTIST IN YOUR LIBRARY'), findsOneWidget);
      expect(find.text('Feeling Good'), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Pastel Blues'), findsWidgets);
      expect(find.byKey(const ValueKey('artist-open-on-provider')), findsNothing);
    });

    testWidgets('unknown artist → error with retry', (tester) async {
      final kit = FakeKit(sources: [soundcloud()]);
      await pumpPage(tester, kit: kit, route: AppRoutes.artist(SourceIds.soundcloud, 'nobody'));
      expect(find.text('Retry'), findsOneWidget);
    });

    test('albums are derived from top tracks', () {
      final albums = albumsFromTracks(SourceIds.audius, [
        testTrack('a', album: 'One', extra: const {'albumId': '1'}),
        testTrack('b', album: 'One', extra: const {'albumId': '1'}),
        testTrack('c', album: 'Two', extra: const {'audius.albumId': '2'}),
        testTrack('d', album: 'No id'),
      ]);
      expect(albums.map((a) => (a.albumId, a.title)), [('1', 'One'), ('2', 'Two')]);
    });
  });

  group('album', () {
    testWidgets('disc grouping, total duration, play / shuffle, download for permitted providers', (tester) async {
      final tracks = [
        _albumTrack('d2t1', disc: 2, no: 1, offline: OfflineRights.downloadable),
        _albumTrack('d1t2', disc: 1, no: 2, offline: OfflineRights.downloadable),
        _albumTrack('d1t1', disc: 1, no: 1, offline: OfflineRights.downloadable),
      ];
      final kit = FakeKit(sources: [FakeMusicSource(id: SourceIds.audius, displayName: 'Audius', tracks: tracks)]);
      await pumpPage(tester, kit: kit, route: AppRoutes.album(SourceIds.audius, 'al1'));
      expect(find.text('Double Album'), findsWidgets);
      expect(find.text('2024 · 3 tracks · 10 min'), findsOneWidget);
      expect(find.text('Disc 1'), findsOneWidget);
      expect(find.text('Disc 2'), findsOneWidget);
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('Track d1t1'), lessThan(y('Track d1t2')));
      expect(y('Track d1t2'), lessThan(y('Disc 2')));
      expect(y('Disc 2'), lessThan(y('Track d2t1')));
      await tester.tap(find.widgetWithText(FilledButton, 'Download'));
      await settle(tester);
      expect(kit.downloads.calls, contains('enqueueAll'));
      expect(find.text('3 downloads added'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Shuffle'));
      await settle(tester);
      expect(kit.playback.argsOf('playTracks')[4], isTrue);
    });

    testWidgets('no download action for SoundCloud albums', (tester) async {
      final tracks = [_albumTrack('s1', sourceId: SourceIds.soundcloud, disc: 1, no: 1, offline: OfflineRights.downloadable)];
      final kit = FakeKit(sources: [FakeMusicSource(id: SourceIds.soundcloud, displayName: 'SoundCloud', tracks: tracks)]);
      await pumpPage(tester, kit: kit, route: AppRoutes.album(SourceIds.soundcloud, 'al1'));
      expect(find.text('Track s1'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Download'), findsNothing);
      expect(find.text('Disc 1'), findsNothing);
    });

    testWidgets('library album by title', (tester) async {
      final kit = FakeKit(tracks: [
        testTrack('l1', sourceId: SourceIds.local, title: 'So What', album: 'Kind of Blue', artist: 'Miles Davis').copyWith(trackNumber: 1),
        testTrack('l2', sourceId: SourceIds.local, title: 'Freddie Freeloader', album: 'Kind of Blue', artist: 'Miles Davis').copyWith(trackNumber: 2),
      ]);
      await pumpPage(tester, kit: kit, route: AppRoutes.album(SourceIds.local, 'Kind of Blue'));
      expect(find.text('ALBUM IN YOUR LIBRARY'), findsOneWidget);
      expect(find.text('Miles Davis'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'Download'), findsNothing);
      await tester.tap(find.text('Go to artist'));
      await settle(tester);
      expect(tester.widget<ArtistPage>(find.byType(ArtistPage)).artistId, 'Miles Davis');
    });

    testWidgets('unknown source → error', (tester) async {
      await pumpPage(tester, kit: FakeKit(), route: AppRoutes.album('nowhere', 'x'));
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(AlbumPage), findsOneWidget);
    });
  });
}
