import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/pages/favorites/favorites_page.dart';
import 'package:fermata/ui/pages/history/history_page.dart';
import 'package:fermata/ui/pages/history/history_stats.dart';
import 'package:fermata/ui/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'support/page_harness.dart';

Future<FakeKit> _favoritesKit(List<Track> liked, {List<Track> other = const []}) async {
  final kit = FakeKit(tracks: [...liked, ...other]);
  kit.favorites.ids.addAll(liked.map((t) => t.id));
  return kit;
}

double _y(WidgetTester tester, String text) => tester.getTopLeft(find.descendant(of: find.byType(FavoritesPage), matching: find.text(text))).dy;

PlayRecord _play(Track t, DateTime at, {int seconds = 200}) =>
    PlayRecord(track: t, playedAt: at, listened: Duration(seconds: seconds), completed: true);

void main() {
  group('favorites', () {
    testWidgets('liked tracks; sort by title; text and source filters', (tester) async {
      final kit = await _favoritesKit([
        testTrack('a', title: 'Zebra'),
        testTrack('b', title: 'Apple'),
        testTrack('c', sourceId: SourceIds.soundcloud, title: 'Mango'),
      ]);
      await pumpPage(tester, kit: kit, route: '/favorites');
      expect(find.text('3 tracks · 10 min'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('favorites-sort')));
      await settle(tester);
      await tester.tap(find.text('Title').last);
      await settle(tester);
      expect(_y(tester, 'Apple'), lessThan(_y(tester, 'Mango')));
      expect(_y(tester, 'Mango'), lessThan(_y(tester, 'Zebra')));
      await tester.tap(find.byKey(const ValueKey('fav-source-soundcloud')));
      await settle(tester);
      expect(find.descendant(of: find.byType(FavoritesPage), matching: find.text('Apple')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('fav-source-soundcloud')));
      await tester.enterText(find.byType(TextField).first, 'app');
      await settle(tester);
      expect(find.descendant(of: find.byType(FavoritesPage), matching: find.text('Zebra')), findsNothing);
      expect(find.descendant(of: find.byType(FavoritesPage), matching: find.text('Apple')), findsOneWidget);
    });

    testWidgets('play all keeps SoundCloud in its own queue; download only for permitted providers', (tester) async {
      final kit = await _favoritesKit([
        testTrack('a', title: 'One', offline: OfflineRights.downloadable),
        testTrack('c', sourceId: SourceIds.soundcloud, title: 'Two'),
      ]);
      await pumpPage(tester, kit: kit, route: '/favorites');
      await tester.tap(find.widgetWithText(FilledButton, 'Play'));
      await settle(tester);
      final queued = kit.playback.argsOf('playTracks')[0] as List<Track>;
      expect(queued.map((t) => t.sourceId).toSet().length, 1);
      expect(kit.playback.argsOf('playTracks')[2], 'favorites');
      await tester.tap(find.widgetWithText(FilledButton, 'Download'));
      await settle(tester);
      expect(kit.downloads.calls, contains('enqueueAll'));
      expect(find.text("1 download added · 1 track can't be downloaded"), findsOneWidget);
    });

    testWidgets('no download action when nothing can be downloaded', (tester) async {
      final kit = await _favoritesKit([testTrack('c', sourceId: SourceIds.soundcloud, title: 'Two')]);
      await pumpPage(tester, kit: kit, route: '/favorites');
      expect(find.widgetWithText(FilledButton, 'Download'), findsNothing);
    });

    testWidgets('unliking refreshes the list; empty state', (tester) async {
      final t = testTrack('a', title: 'Only one');
      final kit = await _favoritesKit([t]);
      await pumpPage(tester, kit: kit, route: '/favorites');
      await kit.favorites.setFavorite(t, false);
      await settle(tester);
      expect(find.text('Songs you like show up here'), findsOneWidget);
    });

    testWidgets('error with retry', (tester) async {
      final kit = await _favoritesKit([testTrack('a')]);
      kit.favorites.throwOn['favorites'] = const NetworkException('x');
      await pumpPage(tester, kit: kit, route: '/favorites');
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Track a'), findsWidgets);
    });

    test('sortFavorites', () {
      final list = [testTrack('1', title: 'b'), testTrack('2', title: 'a')];
      expect(sortFavorites(list, sort: TrackSortField.dateAdded, descending: true).first.sourceTrackId, '1');
      expect(sortFavorites(list, sort: TrackSortField.dateAdded, descending: false).first.sourceTrackId, '2');
      expect(sortFavorites(list, sort: TrackSortField.title, descending: false).first.title, 'a');
    });
  });

  group('history', () {
    testWidgets('recently played grouped by day', (tester) async {
      final kit = FakeKit();
      final a = testTrack('a', title: 'This morning');
      final b = testTrack('b', title: 'Last night');
      final c = testTrack('c', title: 'Last week');
      kit.history.records.addAll([
        _play(a, DateTime(2026, 10, 27, 9, 15)),
        _play(b, DateTime(2026, 10, 26, 22, 5)),
        _play(c, DateTime(2026, 10, 10, 12)),
      ]);
      await pumpPage(tester, kit: kit, route: '/history');
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('October 10'), findsOneWidget);
      expect(find.text('This morning'), findsOneWidget);
      expect(find.textContaining('9:15'), findsOneWidget);
      await tester.tap(find.text('Last night'));
      await settle(tester);
      expect((kit.playback.argsOf('playTracks')[0] as List<Track>).single.title, 'Last night');
    });

    testWidgets('clear history asks first', (tester) async {
      final kit = FakeKit();
      kit.history.records.add(_play(testTrack('a'), DateTime(2026, 10, 27, 9)));
      await pumpPage(tester, kit: kit, route: '/history');
      await tester.tap(find.byKey(const ValueKey('history-clear')));
      await settle(tester);
      expect(find.text('Clear your listening history?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Clear history').last);
      await settle(tester);
      expect(kit.history.called('clearHistory'), isTrue);
      expect(find.text('Nothing played yet'), findsOneWidget);
    });

    testWidgets('canceling keeps the history', (tester) async {
      final kit = FakeKit();
      kit.history.records.add(_play(testTrack('a', title: 'Keep me'), DateTime(2026, 10, 27, 9)));
      await pumpPage(tester, kit: kit, route: '/history');
      await tester.tap(find.byKey(const ValueKey('history-clear')));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(kit.history.called('clearHistory'), isFalse);
      expect(find.text('Keep me'), findsOneWidget);
    });

    testWidgets('notice when history recording is off', (tester) async {
      final kit = FakeKit(settings: const AppSettings(onboardingCompleted: true, privacy: PrivacySettings(recordHistory: false)));
      await pumpPage(tester, kit: kit, route: '/history');
      expect(find.byKey(const ValueKey('history-off')), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await settle(tester);
      expect(tester.widget<SettingsPage>(find.byType(SettingsPage)).section, 'privacy');
    });

    testWidgets('statistics: totals, top lists and plays per day chart', (tester) async {
      final kit = FakeKit();
      final history = StatsHistoryRepository();
      final t = testTrack('a', title: 'Favourite tune');
      history.records.add(_play(t, DateTime(2026, 10, 27, 9)));
      history.preset = ListeningStats(
        totalPlays: 42,
        totalListened: const Duration(hours: 2, minutes: 5),
        topTracks: [(t, 12)],
        topArtists: const [('Big Artist', 20)],
        topGenres: const [('Jazz', 9)],
        playsPerDay: {DateTime(2026, 10, 27): 5, DateTime(2026, 10, 25): 2},
      );
      await pumpPage(tester, kit: kit, route: '/history', services: servicesWith(kit, history: history));
      await tester.tap(find.text('Statistics'));
      await settle(tester);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('2 h 5 min'), findsOneWidget);
      expect(find.text('Favourite tune'), findsOneWidget);
      expect(find.text('12 plays'), findsOneWidget);
      expect(find.text('Big Artist'), findsOneWidget);
      expect(find.text('Jazz'), findsOneWidget);
      final chart = tester.widget<PlaysPerDayChart>(find.byType(PlaysPerDayChart));
      expect(chart.series.length, 30);
      expect(chart.series.last, 5);
      expect(chart.series[chart.series.length - 3], 2);
      expect(find.bySemanticsLabel(RegExp('7 in total, at most 5')), findsOneWidget);
    });

    test('groupByDay keeps newest first', () {
      final t = testTrack('a');
      final groups = groupByDay([
        _play(t, DateTime(2026, 10, 27, 9)),
        _play(t, DateTime(2026, 10, 27, 1)),
        _play(t, DateTime(2026, 10, 25, 9)),
      ]);
      expect(groups.map((g) => (g.$1.day, g.$2.length)), [(27, 2), (25, 1)]);
    });
  });
}
