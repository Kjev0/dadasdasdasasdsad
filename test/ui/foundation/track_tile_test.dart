import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/l10n/gen/app_localizations.dart';
import 'package:fermata/ui/design/theme.dart';
import 'package:fermata/ui/widgets/tracks/now_playing_glyph.dart';
import 'package:fermata/ui/widgets/tracks/track_list_view.dart';
import 'package:fermata/ui/widgets/tracks/track_menu.dart';
import 'package:fermata/ui/widgets/tracks/track_tile.dart';
import 'package:fermata/ui/widgets/util/async_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fakes.dart';

/// Hosts [child] in a minimal router so navigation actions can be checked.
Future<FakeKit> _pumpTiles(WidgetTester tester, Widget child, {required FakeKit kit, Size size = TestSizes.expanded}) async {
  setTestWindowSize(tester, size);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => Scaffold(body: child)),
    GoRoute(path: '/artist/:s/:a', builder: (_, s) => Scaffold(body: Text('artist ${s.pathParameters['s']}/${s.pathParameters['a']}'))),
    GoRoute(path: '/album/:s/:a', builder: (_, s) => Scaffold(body: Text('album ${s.pathParameters['s']}/${s.pathParameters['a']}'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: kit.overrides(),
    retry: noRetry,
    child: MaterialApp.router(
      routerConfig: router,
      theme: buildFermataTheme(brightness: Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await pumpFrames(tester);
  return kit;
}

Future<void> _openMenu(WidgetTester tester, String title) async {
  await tester.tap(find.descendant(of: find.widgetWithText(TrackTile, title), matching: find.byTooltip('More options')));
  await pumpFrames(tester);
}

Future<List<String>> _menuLabels(WidgetTester tester, FakeKit kit, Track track) async {
  late List<TrackMenuEntry> entries;
  await _pumpTiles(tester, Consumer(builder: (context, ref, _) {
    return TextButton(
      onPressed: () async => entries = await buildTrackMenuEntries(context, ref, track),
      child: const Text('build'),
    );
  }), kit: kit);
  await tester.tap(find.text('build'));
  await pumpFrames(tester, count: 2);
  return [for (final e in entries) e.label];
}

void main() {
  group('TrackTile menu: download only when eligible', () {
    testWidgets('Audius track the artist made downloadable → Download', (tester) async {
      final t = testTrack('a1', offline: OfflineRights.downloadable);
      final labels = await _menuLabels(tester, FakeKit(tracks: [t]), t);
      expect(labels, contains('Download'));
      expect(labels, isNot(contains('Remove download')));
    });

    testWidgets('stream-only track → no download entry', (tester) async {
      final t = testTrack('a2', offline: OfflineRights.streamOnly);
      final labels = await _menuLabels(tester, FakeKit(tracks: [t]), t);
      expect(labels, isNot(contains('Download')));
    });

    testWidgets('SoundCloud never shows Download, even if the manager says allowed', (tester) async {
      final t = testTrack('sc1', sourceId: SourceIds.soundcloud, offline: OfflineRights.downloadable);
      final kit = FakeKit(tracks: [t]);
      kit.downloads.eligibility[t.id] = const DownloadEligibility(DownloadEligibilityKind.allowed);
      final labels = await _menuLabels(tester, kit, t);
      expect(labels, isNot(contains('Download')));
      expect(kit.downloads.calls, isNot(contains('checkEligibility')));
    });

    for (final source in [SourceIds.deezer, SourceIds.spotify, SourceIds.youtube]) {
      testWidgets('$source never shows Download', (tester) async {
        final t = testTrack('x', sourceId: source, offline: OfflineRights.downloadable);
        final labels = await _menuLabels(tester, FakeKit(tracks: [t]), t);
        expect(labels, isNot(contains('Download')));
      });
    }

    testWidgets('downloaded track → Remove download instead', (tester) async {
      final t = testTrack('a3', offline: OfflineRights.downloadable);
      final kit = FakeKit(tracks: [t]);
      kit.downloads.downloaded.add(t.id);
      final labels = await _menuLabels(tester, kit, t);
      expect(labels, contains('Remove download'));
      expect(labels, isNot(contains('Download')));
    });

    testWidgets('local file → no download, no external links', (tester) async {
      final t = testTrack('song', sourceId: SourceIds.local, album: 'Blue');
      final labels = await _menuLabels(tester, FakeKit(tracks: [t]), t);
      expect(labels, isNot(contains('Download')));
      expect(labels, isNot(contains('Copy link')));
      expect(labels.where((l) => l.startsWith('Open on')), isEmpty);
      expect(labels, containsAll(['Play', 'Play next', 'Add to queue', 'Add to playlist', 'Like', 'Go to artist', 'Go to album']));
    });
  });

  group('TrackTile interactions', () {
    testWidgets('tap plays the list from this track', (tester) async {
      final kit = FakeKit(tracks: testTracks(3));
      await _pumpTiles(tester, TrackListView(tracks: kit.tracks.all, origin: 'playlist:p1', originLabel: 'Mix'), kit: kit);
      await tester.tap(find.text('Song 2'));
      await pumpFrames(tester);
      final args = kit.playback.argsOf('playTracks');
      expect(args[0], kit.tracks.all);
      expect(args[1], 1);
      expect(args[2], 'playlist:p1');
      expect(args[3], 'Mix');
    });

    testWidgets('menu Download enqueues and confirms', (tester) async {
      final t = testTrack('d1', title: 'Free song', offline: OfflineRights.downloadable);
      final kit = FakeKit(tracks: [t]);
      await _pumpTiles(tester, TrackTile(track: t), kit: kit);
      await _openMenu(tester, 'Free song');
      await tester.tap(find.text('Download').last);
      await pumpFrames(tester);
      expect(kit.downloads.calls, contains('enqueue'));
      expect(kit.downloads.tasks.single.trackId, t.id);
      expect(find.text('Download added'), findsOneWidget);
    });

    testWidgets('long-press opens the action sheet', (tester) async {
      final t = testTrack('s1', title: 'Sheet song');
      final kit = FakeKit(tracks: [t]);
      await _pumpTiles(tester, TrackTile(track: t), kit: kit, size: TestSizes.compact);
      await tester.longPress(find.text('Sheet song'));
      await pumpFrames(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Add to queue')));
      await pumpFrames(tester);
      expect(kit.playback.called('enqueue'), isTrue);
      expect(find.text('Added to queue'), findsOneWidget);
    });

    testWidgets('SoundCloud silo: offers a new queue instead of mixing', (tester) async {
      final sc = testTrack('sc', sourceId: SourceIds.soundcloud, title: 'Cloud song');
      final kit = FakeKit(tracks: [sc]);
      kit.playback.canJoin = (tracks) => false;
      await _pumpTiles(tester, TrackTile(track: sc), kit: kit);
      await _openMenu(tester, 'Cloud song');
      await tester.tap(find.text('Play next').last);
      await pumpFrames(tester);
      expect(find.text("SoundCloud tracks play in their own queue (SoundCloud's terms). Start a new queue?"), findsOneWidget);
      expect(kit.playback.called('playTracks'), isFalse);
      await tester.tap(find.text('Start new queue'));
      await pumpFrames(tester);
      expect(kit.playback.argsOf('playTracks').first, [sc]);
    });

    testWidgets('silo dialog can be declined', (tester) async {
      final sc = testTrack('sc', sourceId: SourceIds.soundcloud, title: 'Cloud song');
      final kit = FakeKit(tracks: [sc]);
      kit.playback.canJoin = (tracks) => false;
      await _pumpTiles(tester, TrackTile(track: sc), kit: kit);
      await _openMenu(tester, 'Cloud song');
      await tester.tap(find.text('Add to queue').last);
      await pumpFrames(tester);
      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(kit.playback.called('playTracks'), isFalse);
    });

    testWidgets('open on provider and copy link', (tester) async {
      final t = testTrack('ext', title: 'Linked song');
      final source = FakeMusicSource(id: SourceIds.audius, displayName: 'Audius', externalBase: Uri.parse('https://audius.invalid/t/'));
      final kit = FakeKit(tracks: [t], sources: [source]);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await _pumpTiles(tester, TrackTile(track: t), kit: kit);
      await _openMenu(tester, 'Linked song');
      await tester.tap(find.text('Open on Audius').last);
      await pumpFrames(tester);
      expect(kit.openedLinks.single, Uri.parse('https://audius.invalid/t/ext'));

      await _openMenu(tester, 'Linked song');
      await tester.tap(find.text('Copy link').last);
      await pumpFrames(tester);
      expect(clipboard, t.permalink.toString());
      expect(find.text('Link copied'), findsOneWidget);
    });

    testWidgets('go to artist / album', (tester) async {
      final t = testTrack('g', title: 'Nav song', artistId: 'art9', extra: const {'albumId': 'alb3'});
      final kit = FakeKit(tracks: [t]);
      await _pumpTiles(tester, TrackTile(track: t), kit: kit);
      await _openMenu(tester, 'Nav song');
      await tester.tap(find.text('Go to artist').last);
      await pumpFrames(tester);
      expect(find.text('artist audius/art9'), findsOneWidget);
    });

    testWidgets('unavailable tracks are dimmed and explain why on tap', (tester) async {
      final t = testTrack('u', title: 'Gone song', playback: PlaybackRights.unavailable, reason: AvailabilityReason.regionRestricted);
      final kit = FakeKit(tracks: [t]);
      await _pumpTiles(tester, TrackTile(track: t), kit: kit);
      final opacity = tester.widget<Opacity>(find.ancestor(of: find.text('Gone song'), matching: find.byType(Opacity)).first);
      expect(opacity.opacity, lessThan(1));
      expect(find.text('Unavailable'), findsOneWidget);
      await tester.tap(find.text('Gone song'));
      await pumpFrames(tester);
      expect(kit.playback.called('playTracks'), isFalse);
      expect(find.text('Not available in your region.'), findsOneWidget);
    });

    testWidgets('external-only tracks open on their provider', (tester) async {
      final t = testTrack('sp', sourceId: SourceIds.spotify, title: 'Spotify song', playback: PlaybackRights.externalOnly);
      final kit = FakeKit(tracks: [t]);
      await _pumpTiles(tester, TrackTile(track: t), kit: kit);
      expect(find.text('Plays on Spotify'), findsOneWidget);
      await tester.tap(find.text('Spotify song'));
      await pumpFrames(tester);
      expect(kit.openedLinks.single, t.permalink);
      expect(kit.playback.called('playTracks'), isFalse);
    });

    testWidgets('like button and now-playing indicator', (tester) async {
      final tracks = testTracks(2);
      final kit = FakeKit(tracks: tracks);
      kit.playback.load(tracks, index: 0, playing: true);
      await _pumpTiles(tester, TrackListView(tracks: tracks), kit: kit);
      final glyph = tester.widget<NowPlayingGlyph>(find.byType(NowPlayingGlyph));
      expect(glyph.animate, isTrue);
      expect(find.bySemanticsLabel(RegExp('^Now playing: Song 1')), findsOneWidget);
      await tester.tap(find.descendant(of: find.widgetWithText(TrackTile, 'Song 1'), matching: find.byTooltip('Like')));
      await pumpFrames(tester);
      expect(kit.favorites.ids, contains(tracks[0].id));
    });

    testWidgets('selection mode: long-press selects, bulk add to queue', (tester) async {
      final tracks = testTracks(4);
      final kit = FakeKit(tracks: tracks);
      await _pumpTiles(tester, TrackListView(tracks: tracks), kit: kit);
      await tester.longPress(find.text('Song 1'));
      await pumpFrames(tester);
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.text('Song 3'));
      await pumpFrames(tester);
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(TrackSelectionBar), matching: find.byTooltip('Add to queue')));
      await pumpFrames(tester);
      expect(kit.playback.argsOf('enqueue').first, [tracks[0], tracks[2]]);
      expect(find.byType(TrackSelectionBar), findsNothing);
    });
  });
}
