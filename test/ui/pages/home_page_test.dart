import 'package:fermata/core/contracts/discovery.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/pages/home/home_page.dart';
import 'package:fermata/ui/pages/home/home_providers.dart';
import 'package:fermata/ui/pages/library/library_page.dart';
import 'package:fermata/ui/pages/library/shared/page_layout.dart';
import 'package:fermata/ui/pages/explore/explore_page.dart';
import 'package:fermata/ui/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'support/page_harness.dart';

List<Shelf> _shelves() => [
      Shelf(id: 'continueListening', title: 'shelfContinueListening', tracks: testTracks(3, prefix: 'c'), kind: ShelfKind.continueListening),
      Shelf(id: 'dailyMix:1', title: 'shelfDailyMix', subtitle: 'Artist 1, Artist 2', tracks: testTracks(6, prefix: 'm'), kind: ShelfKind.mix),
      Shelf(id: 'dailyMix:2', title: 'shelfDailyMix', subtitle: 'Artist 3', tracks: testTracks(4, prefix: 'n'), kind: ShelfKind.mix),
      Shelf(id: 'discoverWeekly', title: 'shelfDiscoverWeekly', tracks: testTracks(5, prefix: 'w'), kind: ShelfKind.discoverWeekly),
      Shelf(
        id: 'trending',
        title: 'shelfTrending',
        tracks: [for (var i = 1; i <= 6; i++) testTrack('sc$i', sourceId: SourceIds.soundcloud, title: 'Trend $i')],
        kind: ShelfKind.trending,
      ),
      Shelf(id: 'recentlyAdded', title: 'shelfRecentlyAdded', tracks: [testTrack('l1', sourceId: SourceIds.local, title: 'Local One')]),
    ];

void main() {
  group('greeting', () {
    test('day parts', () {
      expect(dayPartOf(DateTime(2026, 1, 1, 6)), DayPart.morning);
      expect(dayPartOf(DateTime(2026, 1, 1, 12)), DayPart.afternoon);
      expect(dayPartOf(DateTime(2026, 1, 1, 19)), DayPart.evening);
      expect(dayPartOf(DateTime(2026, 1, 1, 2)), DayPart.night);
      expect(dayPartOf(DateTime(2026, 1, 1, 23, 30)), DayPart.night);
    });

    testWidgets('greets by time of day (EN and DA)', (tester) async {
      final kit = FakeKit();
      kit.recommendations.shelves = _shelves();
      await pumpPage(tester, kit: kit, route: '/home', now: DateTime(2026, 10, 27, 8));
      expect(find.text('Good morning'), findsOneWidget);
      await kit.settingsStore.update((s) => s.copyWith(localeCode: 'da'));
      await settle(tester);
      expect(find.text('Godmorgen'), findsOneWidget);
    });

    testWidgets('evening greeting', (tester) async {
      final kit = FakeKit();
      await pumpPage(tester, kit: kit, route: '/home', now: DateTime(2026, 10, 27, 20));
      expect(find.text('Good evening'), findsOneWidget);
    });
  });

  group('shelves', () {
    testWidgets('loading skeleton → shelves with localized titles', (tester) async {
      final kit = FakeKit();
      final recs = GatedRecommendations()..shelves = _shelves();
      await pumpPage(tester, kit: kit, route: '/home', services: servicesWith(kit, recommendations: recs));
      expect(find.byType(SkeletonShelf), findsWidgets);
      recs.gate.complete();
      await settle(tester);
      expect(find.byType(SkeletonShelf), findsNothing);
      expect(find.text('Continue listening'), findsOneWidget);
      expect(find.text('Made for you'), findsOneWidget);
      expect(find.text('Daily Mix 1'), findsOneWidget);
      expect(find.text('Daily Mix 2'), findsOneWidget);
      expect(find.text('Discover Weekly'), findsOneWidget);
      expect(find.text('Trending'), findsOneWidget);
      expect(find.text('Recently added'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('quick-play on a track card plays the shelf from that track', (tester) async {
      final kit = FakeKit();
      kit.recommendations.shelves = _shelves();
      await pumpPage(tester, kit: kit, route: '/home');
      await tester.tap(find.byKey(const ValueKey('card-audius:c2')));
      await settle(tester);
      final args = kit.playback.argsOf('playTracks');
      expect((args[0] as List).length, 3);
      expect(args[1], 1);
      expect(args[2], 'shelf:continueListening');
    });

    testWidgets('a mix card opens the mix; play plays it; back returns', (tester) async {
      final kit = FakeKit();
      kit.recommendations.shelves = _shelves();
      await pumpPage(tester, kit: kit, route: '/home');
      await tester.tap(find.text('Daily Mix 1'));
      await settle(tester);
      expect(find.text('Song 1'), findsWidgets);
      expect(find.text('6 tracks · 21 min'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Play'));
      await settle(tester);
      expect(kit.playback.argsOf('playTracks')[2], 'shelf:dailyMix:1');
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.text('Made for you'), findsOneWidget);
    });

    testWidgets('error → localized message → retry loads', (tester) async {
      final kit = FakeKit();
      kit.recommendations
        ..shelves = _shelves()
        ..error = const NetworkException('down');
      await pumpPage(tester, kit: kit, route: '/home');
      expect(find.text("You're offline. Check your connection and try again."), findsOneWidget);
      kit.recommendations.error = null;
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Continue listening'), findsOneWidget);
    });

    testWidgets('personalization setting change refetches', (tester) async {
      final kit = FakeKit();
      kit.recommendations.shelves = _shelves();
      await pumpPage(tester, kit: kit, route: '/home');
      final before = kit.recommendations.calls.where((c) => c == 'homeShelves').length;
      await kit.settingsStore.update((s) => s.copyWith(privacy: const PrivacySettings(personalizedRecommendations: false)));
      await settle(tester);
      expect(kit.recommendations.calls.where((c) => c == 'homeShelves').length, greaterThan(before));
    });
  });

  group('first run', () {
    testWidgets('empty → three ways to start', (tester) async {
      await pumpPage(tester, kit: FakeKit(), route: '/home');
      expect(find.byType(FirstRunPanel), findsOneWidget);
      expect(find.text('Add a music folder'), findsOneWidget);
      expect(find.text('Connect a service'), findsOneWidget);
      expect(find.text('Start exploring'), findsOneWidget);
    });

    testWidgets('connect a service opens Settings → Connected services', (tester) async {
      await pumpPage(tester, kit: FakeKit(), route: '/home');
      await tester.tap(find.text('Connected services'));
      await settle(tester);
      expect(tester.widget<SettingsPage>(find.byType(SettingsPage)).section, 'services');
    });

    testWidgets('explore', (tester) async {
      await pumpPage(tester, kit: FakeKit(), route: '/home');
      await tester.tap(find.text('Start exploring'));
      await settle(tester);
      expect(find.byType(ExplorePage), findsOneWidget);
    });

    testWidgets('add a folder adds, scans and opens Library → Folders', (tester) async {
      final kit = FakeKit();
      final picker = FakePageFilePicker()..directory = '/music/new';
      await pumpPage(tester, kit: kit, route: '/home', picker: picker);
      await tester.tap(find.widgetWithText(FilledButton, 'Add folder'));
      await settle(tester);
      expect(kit.localLibrary.called('addFolder'), isTrue);
      expect(kit.localLibrary.called('scan'), isTrue);
      expect(tester.widget<LibraryPage>(find.byType(LibraryPage)).tab, 'folders');
    });

    testWidgets('canceling the folder picker changes nothing', (tester) async {
      final kit = FakeKit();
      await pumpPage(tester, kit: kit, route: '/home', picker: FakePageFilePicker());
      await tester.tap(find.widgetWithText(FilledButton, 'Add folder'));
      await settle(tester);
      expect(kit.localLibrary.called('addFolder'), isFalse);
      expect(find.byType(HomePage), findsOneWidget);
    });
  });
}
