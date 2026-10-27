import 'package:fermata/app/router.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/actions/routes.dart';
import 'package:fermata/ui/pages/album/album_page.dart';
import 'package:fermata/ui/pages/artist/artist_page.dart';
import 'package:fermata/ui/pages/downloads/downloads_page.dart';
import 'package:fermata/ui/pages/explore/explore_page.dart';
import 'package:fermata/ui/pages/favorites/favorites_page.dart';
import 'package:fermata/ui/pages/history/history_page.dart';
import 'package:fermata/ui/pages/home/home_page.dart';
import 'package:fermata/ui/pages/import/import_page.dart';
import 'package:fermata/ui/pages/import/import_review_page.dart';
import 'package:fermata/ui/pages/library/library_page.dart';
import 'package:fermata/ui/pages/onboarding/onboarding_page.dart';
import 'package:fermata/ui/pages/playlists/playlist_detail_page.dart';
import 'package:fermata/ui/pages/playlists/playlists_page.dart';
import 'package:fermata/ui/pages/search/search_page.dart';
import 'package:fermata/ui/pages/settings/settings_page.dart';
import 'package:fermata/ui/player/now_playing_page.dart';
import 'package:fermata/ui/player/queue_page.dart';
import 'package:fermata/ui/shell/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

void main() {
  group('onboardingRedirect', () {
    test('/ goes to onboarding until completed, then home', () {
      expect(onboardingRedirect(Uri.parse('/'), onboardingCompleted: false), '/onboarding');
      expect(onboardingRedirect(Uri.parse('/'), onboardingCompleted: true), '/home');
      expect(onboardingRedirect(Uri.parse(''), onboardingCompleted: true), '/home');
    });

    test('other locations are untouched', () {
      expect(onboardingRedirect(Uri.parse('/search'), onboardingCompleted: false), isNull);
      expect(onboardingRedirect(Uri.parse('/onboarding'), onboardingCompleted: true), isNull);
    });
  });

  group('router', () {
    testWidgets('first run: / redirects to onboarding (outside the shell)', (tester) async {
      await pumpFermata(tester, kit: FakeKit(settings: const AppSettings()), initialRoute: '/');
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(appRouter(tester).routerDelegate.currentConfiguration.uri.path, '/onboarding');
    });

    testWidgets('completed onboarding: / redirects to home', (tester) async {
      await pumpFermata(tester, initialRoute: '/');
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('completing onboarding while on / re-evaluates the redirect', (tester) async {
      final kit = FakeKit(settings: const AppSettings());
      await pumpFermata(tester, kit: kit, initialRoute: '/');
      expect(find.byType(OnboardingPage), findsOneWidget);
      await kit.settingsStore.update((s) => s.copyWith(onboardingCompleted: true));
      await goTo(tester, '/');
      expect(find.byType(HomePage), findsOneWidget);
    });

    final cases = <String, (Type, bool Function(Object))>{
      '/home': (HomePage, (_) => true),
      '/search': (SearchPage, (_) => true),
      '/explore': (ExplorePage, (_) => true),
      '/library': (LibraryPage, (w) => (w as LibraryPage).tab == null),
      '/library?tab=albums': (LibraryPage, (w) => (w as LibraryPage).tab == 'albums'),
      '/playlists': (PlaylistsPage, (_) => true),
      '/playlists/abc-123': (PlaylistDetailPage, (w) => (w as PlaylistDetailPage).playlistId == 'abc-123'),
      AppRoutes.playlist('spotify:37i9'): (PlaylistDetailPage, (w) => (w as PlaylistDetailPage).playlistId == 'spotify:37i9'),
      '/artist/audius/a1': (ArtistPage, (w) => (w as ArtistPage).sourceId == 'audius' && w.artistId == 'a1'),
      AppRoutes.artist('local', 'Nina Simone'): (ArtistPage, (w) => (w as ArtistPage).artistId == 'Nina Simone'),
      '/album/deezer/302127': (AlbumPage, (w) => (w as AlbumPage).sourceId == 'deezer' && w.albumId == '302127'),
      '/downloads': (DownloadsPage, (_) => true),
      '/favorites': (FavoritesPage, (_) => true),
      '/history': (HistoryPage, (_) => true),
      '/queue': (QueuePage, (_) => true),
      '/settings': (SettingsPage, (w) => (w as SettingsPage).section == null),
      '/settings/glass': (SettingsPage, (w) => (w as SettingsPage).section == 'glass'),
      '/import': (ImportPage, (_) => true),
      '/import/s42': (ImportReviewPage, (w) => (w as ImportReviewPage).sessionId == 's42'),
    };

    for (final entry in cases.entries) {
      testWidgets('${entry.key} → ${entry.value.$1}', (tester) async {
        await pumpFermata(tester, initialRoute: entry.key);
        final finder = find.byType(entry.value.$1);
        expect(finder, findsOneWidget);
        expect(entry.value.$2(tester.widget(finder)), isTrue);
        expect(find.byType(AppShell), findsOneWidget, reason: 'content pages live inside the shell');
      });
    }

    testWidgets('/now-playing is full screen (root navigator) and honours ?view=', (tester) async {
      final kit = FakeKit(tracks: testTracks(2));
      kit.playback.load(kit.tracks.all);
      await pumpFermata(tester, kit: kit, initialRoute: '/now-playing?view=queue');
      final page = tester.widget<NowPlayingPage>(find.byType(NowPlayingPage));
      expect(page.initialPanel, NowPlayingPanel.queue);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('unknown locations show the not-found page with a way home', (tester) async {
      await pumpFermata(tester, initialRoute: '/does-not-exist');
      expect(find.byType(NotFoundPage), findsOneWidget);
      await tester.tap(find.text('Go to Home'));
      await pumpFrames(tester);
      expect(find.byType(HomePage), findsOneWidget);
    });
  });
}
