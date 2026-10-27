import 'package:fermata/core/contracts/discovery.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/ui/pages/album/album_page.dart';
import 'package:fermata/ui/pages/explore/explore_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'support/page_harness.dart';

void main() {
  testWidgets('moods, genres, trending and new releases', (tester) async {
    final kit = FakeKit();
    kit.recommendations
      ..shelves = [Shelf(id: 'trending', title: 'shelfTrending', kind: ShelfKind.trending, tracks: testTracks(4, prefix: 'tr'))]
      ..releases = const [Album(sourceId: SourceIds.audius, sourceAlbumId: 'al1', title: 'Fresh Album', artists: [ArtistRef('Newcomer')])];
    await pumpPage(tester, kit: kit, route: '/explore');
    expect(find.text('Moods'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Chill'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Electronic'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Folk'), findsOneWidget);
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('New releases'), findsOneWidget);
    await tester.ensureVisible(find.text('Fresh Album'));
    await settle(tester);
    await tester.tap(find.text('Fresh Album'));
    await settle(tester);
    expect(tester.widget<AlbumPage>(find.byType(AlbumPage)).albumId, 'al1');
  });

  testWidgets('a genre lists playable tracks and labels previews / external tracks', (tester) async {
    final kit = FakeKit();
    kit.recommendations.genreTrackMap = {
      'Jazz': [
        testTrack('j1', title: 'Full jazz'),
        testTrack('dz1', sourceId: SourceIds.deezer, title: 'Preview jazz', playback: PlaybackRights.preview),
        testTrack('sp1', sourceId: SourceIds.spotify, title: 'Spotify jazz', playback: PlaybackRights.externalOnly),
      ],
    };
    await pumpPage(tester, kit: kit, route: '/explore');
    await tester.tap(find.widgetWithText(ActionChip, 'Jazz'));
    await settle(tester);
    expect(find.text('Full jazz'), findsOneWidget);
    expect(find.text('30-second preview · Deezer'), findsOneWidget);
    expect(find.text('Plays on Spotify'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await settle(tester);
    final queued = kit.playback.argsOf('playTracks')[0] as List<Track>;
    // External-only tracks are not queued.
    expect(queued.map((t) => t.sourceTrackId), ['j1', 'dz1']);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(find.text('Moods'), findsOneWidget);
  });

  testWidgets('a mood opens its tracks; empty mood explains', (tester) async {
    final kit = FakeKit();
    await pumpPage(tester, kit: kit, route: '/explore');
    await tester.tap(find.byKey(const ValueKey('mood-focus')));
    await settle(tester);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Nothing playable found right now. Try again later or connect another service.'), findsOneWidget);
    expect(kit.recommendations.calls, contains('moodTracks'));
  });

  testWidgets('genre loading error shows retry', (tester) async {
    final kit = FakeKit();
    kit.recommendations.error = const NetworkException('offline');
    await pumpPage(tester, kit: kit, route: '/explore');
    expect(find.text('Retry'), findsWidgets);
    kit.recommendations.error = null;
    await tester.tap(find.text('Retry').first);
    await settle(tester);
    expect(find.widgetWithText(ActionChip, 'Jazz'), findsOneWidget);
  });

  testWidgets('system back closes a genre view', (tester) async {
    final kit = FakeKit();
    kit.recommendations.genreTrackMap = {'Folk': testTracks(2)};
    await pumpPage(tester, kit: kit, route: '/explore');
    await tester.tap(find.widgetWithText(ActionChip, 'Folk'));
    await settle(tester);
    expect(find.text('Moods'), findsNothing);
    final popped = await tester.binding.handlePopRoute();
    await settle(tester);
    expect(popped, isTrue);
    expect(find.text('Moods'), findsOneWidget);
    expect(find.byType(ExplorePage), findsOneWidget);
  });
}
