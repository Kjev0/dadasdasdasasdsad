import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/ui/pages/home/home_page.dart';
import 'package:fermata/ui/pages/library/library_page.dart';
import 'package:fermata/ui/player/mini_player.dart';
import 'package:fermata/ui/player/player_bar.dart';
import 'package:fermata/ui/shell/nav_rail.dart';
import 'package:fermata/ui/shell/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

void main() {
  group('shell layout', () {
    testWidgets('compact (360x640): bottom navigation + mini-player, no rail/sidebar', (tester) async {
      final kit = FakeKit(tracks: testTracks(3));
      kit.playback.load(kit.tracks.all);
      await pumpFermata(tester, kit: kit, size: TestSizes.compact);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(find.text('Song 1'), findsOneWidget);
      expect(find.byType(FermataNavRail), findsNothing);
      expect(find.byType(Sidebar), findsNothing);
      expect(find.byType(PlayerBar), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      // The five compact destinations.
      for (final label in ['Home', 'Search', 'Explore', 'Library', 'Settings']) {
        expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact: mini-player hidden when nothing is loaded', (tester) async {
      await pumpFermata(tester, size: TestSizes.compact);
      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(find.byType(GestureDetector).hitTestable(), findsWidgets);
      expect(find.text('Nothing playing'), findsNothing);
    });

    testWidgets('medium (800x600): navigation rail + player bar', (tester) async {
      final kit = FakeKit(tracks: testTracks(3));
      kit.playback.load(kit.tracks.all);
      await pumpFermata(tester, kit: kit, size: TestSizes.medium);

      expect(find.byType(FermataNavRail), findsOneWidget);
      expect(find.byType(PlayerBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(Sidebar), findsNothing);
      expect(tester.getSize(find.byType(PlayerBar)).height, PlayerBar.height);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expanded (1440x900): 248 px sidebar with playlists + 88 px player bar', (tester) async {
      final kit = FakeKit(tracks: testTracks(3));
      kit.playlists.add(testPlaylist('p1', name: 'Morning Run'));
      kit.playback.load(kit.tracks.all);
      await pumpFermata(tester, kit: kit, size: TestSizes.expanded);

      expect(find.byType(Sidebar), findsOneWidget);
      expect(tester.getSize(find.byType(Sidebar)).width, Sidebar.width);
      expect(tester.getSize(find.byType(PlayerBar)).height, PlayerBar.height);
      expect(find.text('Morning Run'), findsOneWidget);
      for (final label in ['Home', 'Search', 'Explore', 'Library', 'Playlists', 'Downloads', 'Liked songs', 'History', 'Queue', 'Settings']) {
        expect(find.descendant(of: find.byType(Sidebar), matching: find.text(label)), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('resizing reflows between all breakpoints without overflow', (tester) async {
      final kit = FakeKit(tracks: [
        testTrack('long', title: 'A very long track title that keeps going and going well past any reasonable width', artist: 'An artist with an equally long name'),
        testTrack('loc', sourceId: SourceIds.local),
      ]);
      kit.playback.load(kit.tracks.all, playing: true);
      await pumpFermata(tester, kit: kit, size: TestSizes.expanded, initialRoute: '/library');
      expect(find.byType(LibraryPage), findsOneWidget);

      for (final size in [TestSizes.medium, TestSizes.compact, const Size(1024, 600), const Size(599, 900), TestSizes.expanded]) {
        setTestWindowSize(tester, size);
        await pumpFrames(tester);
        expect(tester.takeException(), isNull, reason: 'overflow at $size');
        // The routed page keeps its state across layout changes.
        expect(find.byType(LibraryPage), findsOneWidget);
      }
    });

    testWidgets('sidebar highlights the active destination and navigates', (tester) async {
      await pumpFermata(tester, initialRoute: '/home');
      await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Library')));
      await pumpFrames(tester);
      expect(find.byType(LibraryPage), findsOneWidget);
      final item = tester.widget<SidebarItem>(find.widgetWithText(SidebarItem, 'Library'));
      expect(item.selected, isTrue);
    });
  });
}
