import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/ui/pages/home/home_page.dart';
import 'package:fermata/ui/player/lyrics_view.dart';
import 'package:fermata/ui/player/now_playing_page.dart';
import 'package:fermata/ui/player/now_playing_parts.dart';
import 'package:fermata/ui/player/queue_page.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

Future<FakeKit> _pumpNowPlaying(WidgetTester tester, List<Track> tracks, {Size size = TestSizes.expanded, String? originLabel, FakeKit? kit}) async {
  final k = kit ?? FakeKit(tracks: tracks);
  k.playback.load(tracks, playing: true, originLabel: originLabel);
  await pumpFermata(tester, kit: k, size: size);
  appRouter(tester).push('/now-playing');
  await pumpFrames(tester);
  expect(find.byType(NowPlayingPage), findsOneWidget);
  return k;
}

void main() {
  group('NowPlayingPage', () {
    for (final size in [TestSizes.compact, TestSizes.medium, TestSizes.expanded]) {
      testWidgets('renders track info without overflow at $size', (tester) async {
        await _pumpNowPlaying(
          tester,
          [testTrack('n1', title: 'Clair de lune', artist: 'Debussy', album: 'Suite bergamasque')],
          size: size,
          originLabel: 'Evening',
        );
        expect(find.text('Clair de lune'), findsOneWidget);
        expect(find.text('Debussy'), findsWidgets);
        expect(find.text('Suite bergamasque'), findsOneWidget);
        expect(find.text('Playing from Evening'), findsOneWidget);
        expect(find.byTooltip('Pause'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('chips: Deezer preview attribution, source name', (tester) async {
      final t = testTrack('dz', sourceId: SourceIds.deezer, playback: PlaybackRights.preview);
      await _pumpNowPlaying(tester, [t]);
      expect(find.text('30-second preview · Deezer'), findsOneWidget);
      expect(find.text('Deezer'), findsOneWidget);
    });

    testWidgets('chips: your file / downloaded', (tester) async {
      await _pumpNowPlaying(tester, [testTrack('mine', sourceId: SourceIds.local)]);
      expect(find.text('Your file'), findsOneWidget);
    });

    testWidgets('downloaded chip', (tester) async {
      final t = testTrack('dl', offline: OfflineRights.downloadable);
      final kit = FakeKit(tracks: [t]);
      kit.downloads.downloaded.add(t.id);
      await _pumpNowPlaying(tester, [t], kit: kit);
      expect(find.text('Downloaded'), findsOneWidget);
      expect(find.byTooltip('Download'), findsNothing);
    });

    testWidgets('download action only when eligible', (tester) async {
      final t = testTrack('ok', offline: OfflineRights.downloadable);
      final kit = await _pumpNowPlaying(tester, [t]);
      await tester.tap(find.byTooltip('Download'));
      await pumpFrames(tester);
      expect(kit.downloads.calls, contains('enqueue'));
    });

    testWidgets('no download action for SoundCloud', (tester) async {
      final t = testTrack('sc', sourceId: SourceIds.soundcloud, offline: OfflineRights.downloadable, extra: const {'uploaderUrl': 'https://soundcloud.invalid/someone'});
      final kit = await _pumpNowPlaying(tester, [t]);
      expect(find.byTooltip('Download'), findsNothing);
      // Attribution: track + uploader links.
      await tester.tap(find.byTooltip('More'));
      await pumpFrames(tester);
      expect(find.text('Open on SoundCloud'), findsOneWidget);
      await tester.tap(find.text('Uploader on SoundCloud'));
      await pumpFrames(tester);
      expect(kit.openedLinks.single, Uri.parse('https://soundcloud.invalid/someone'));
    });

    testWidgets('error banner shows the localized unplayable reason', (tester) async {
      final tracks = testTracks(2);
      final kit = await _pumpNowPlaying(tester, tracks);
      kit.playback.emitEvent(PlaybackFailed(kit.playback.queue.items.first, UnplayableTrackException(tracks.first.id, AvailabilityReason.regionRestricted)));
      await pumpFrames(tester);
      expect(find.text("Can't play this track"), findsOneWidget);
      expect(find.text('Not available in your region.'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(PlaybackErrorBanner), matching: find.byTooltip('Close')));
      await pumpFrames(tester);
      expect(find.text("Can't play this track"), findsNothing);
    });

    testWidgets('transport, like and add to playlist', (tester) async {
      final tracks = testTracks(2);
      final kit = FakeKit(tracks: tracks);
      kit.playlists.add(testPlaylist('p1', name: 'Faves'));
      await _pumpNowPlaying(tester, tracks, kit: kit);
      await tester.tap(find.byTooltip('Next'));
      await tester.pump();
      expect(kit.playback.called('next'), isTrue);
      await tester.tap(find.byTooltip('Like'));
      await pumpFrames(tester);
      expect(kit.favorites.ids, isNotEmpty);
      await tester.tap(find.byTooltip('Add to playlist'));
      await pumpFrames(tester);
      await tester.tap(find.text('Faves'));
      await pumpFrames(tester);
      expect(kit.playlists.entries['p1'], isNotEmpty);
      expect(find.text('Added to Faves'), findsOneWidget);
    });

    testWidgets('lyrics and queue panels', (tester) async {
      final tracks = testTracks(3);
      final kit = FakeKit(tracks: tracks);
      kit.lyrics.lyrics[tracks.first.id] = testSyncedLyrics(['First line', 'Second line']);
      await _pumpNowPlaying(tester, tracks, kit: kit, size: TestSizes.compact);
      await tester.tap(find.byTooltip('Show lyrics'));
      await pumpFrames(tester);
      expect(find.byType(LyricsView), findsOneWidget);
      expect(find.text('First line'), findsOneWidget);
      await tester.tap(find.byTooltip('Show queue'));
      await pumpFrames(tester);
      expect(find.byType(QueueList), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('close button returns to the previous page', (tester) async {
      await _pumpNowPlaying(tester, testTracks(1));
      await tester.tap(find.byTooltip('Close now playing'));
      await pumpFrames(tester);
      expect(find.byType(NowPlayingPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('swipe down closes on phones', (tester) async {
      await _pumpNowPlaying(tester, testTracks(1), size: TestSizes.compact);
      await tester.fling(find.text('Song 1'), const Offset(0, 400), 1500);
      await pumpFrames(tester);
      expect(find.byType(NowPlayingPage), findsNothing);
    });

    testWidgets('mini-player tap opens now playing (compact)', (tester) async {
      final kit = FakeKit(tracks: testTracks(1));
      kit.playback.load(kit.tracks.all);
      await pumpFermata(tester, kit: kit, size: TestSizes.compact);
      await tester.tap(find.text('Song 1'));
      await pumpFrames(tester);
      expect(find.byType(NowPlayingPage), findsOneWidget);
    });

    testWidgets('nothing playing state', (tester) async {
      await pumpFermata(tester, initialRoute: '/now-playing');
      expect(find.text('Nothing playing'), findsOneWidget);
    });
  });
}
