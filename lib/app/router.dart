import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/actions/routes.dart';
import '../ui/design/context_ext.dart';
import '../ui/pages/album/album_page.dart';
import '../ui/pages/artist/artist_page.dart';
import '../ui/pages/downloads/downloads_page.dart';
import '../ui/pages/explore/explore_page.dart';
import '../ui/pages/favorites/favorites_page.dart';
import '../ui/pages/history/history_page.dart';
import '../ui/pages/home/home_page.dart';
import '../ui/pages/import/import_page.dart';
import '../ui/pages/import/import_review_page.dart';
import '../ui/pages/library/library_page.dart';
import '../ui/pages/onboarding/onboarding_page.dart';
import '../ui/pages/playlists/playlist_detail_page.dart';
import '../ui/pages/playlists/playlists_page.dart';
import '../ui/pages/search/search_page.dart';
import '../ui/pages/settings/settings_page.dart';
import '../ui/player/now_playing_page.dart';
import '../ui/player/queue_page.dart';
import '../ui/shell/app_shell.dart';
import '../ui/widgets/feedback/states.dart';
import 'providers.dart';

/// Location the router starts at (`/` → redirected by onboarding state).
/// Tests override it to open a specific page.
final initialLocationProvider = Provider<String>((ref) => AppRoutes.root);

/// The app's single [GoRouter]; lives as long as the provider container.
final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});

/// `/` → `/onboarding` until onboarding is completed, else `/home`. Other
/// locations are left alone.
String? onboardingRedirect(Uri uri, {required bool onboardingCompleted}) {
  if (uri.path.isEmpty || uri.path == AppRoutes.root) {
    return onboardingCompleted ? AppRoutes.home : AppRoutes.onboarding;
  }
  return null;
}

/// Builds the router: a [ShellRoute] (sidebar / rail / bottom nav + player)
/// around the content pages, plus full-screen `/now-playing` and
/// `/onboarding` on the root navigator. Only reads providers (never
/// watches), so the router is created once.
GoRouter buildRouter(Ref ref) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

  final onboarding = ValueNotifier<bool>(ref.read(settingsProvider).onboardingCompleted);
  ref.listen<bool>(settingsProvider.select((s) => s.onboardingCompleted), (_, next) => onboarding.value = next);
  ref.onDispose(onboarding.dispose);

  Duration scaled(Duration base) => ref.read(effectiveVisualsProvider).duration(base);

  Page<void> fade(GoRouterState state, Widget child) {
    final d = scaled(const Duration(milliseconds: 220));
    if (d == Duration.zero) return NoTransitionPage<void>(key: state.pageKey, child: child);
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: d,
      reverseTransitionDuration: d,
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic), child: child),
    );
  }

  Page<void> slideUp(GoRouterState state, Widget child) {
    final d = scaled(const Duration(milliseconds: 360));
    if (d == Duration.zero) return NoTransitionPage<void>(key: state.pageKey, child: child);
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: d,
      reverseTransitionDuration: d,
      transitionsBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  GoRoute page(String path, Widget Function(GoRouterState state) build, {List<RouteBase> routes = const []}) =>
      GoRoute(path: path, pageBuilder: (context, state) => fade(state, build(state)), routes: routes);

  String p(GoRouterState s, String name) => s.pathParameters[name] ?? '';

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: onboarding,
    redirect: (context, state) =>
        onboardingRedirect(state.uri, onboardingCompleted: ref.read(settingsProvider).onboardingCompleted),
    errorPageBuilder: (context, state) => fade(state, const NotFoundPage()),
    routes: [
      ShellRoute(
        navigatorKey: shellKey,
        pageBuilder: (context, state, child) => NoTransitionPage<void>(
          key: const ValueKey('shell'),
          child: AppShell(location: state.uri, child: child),
        ),
        routes: [
          page(AppRoutes.home, (_) => const HomePage()),
          page(AppRoutes.search, (_) => const SearchPage()),
          page(AppRoutes.explore, (_) => const ExplorePage()),
          page(AppRoutes.libraryPath, (s) => LibraryPage(tab: s.uri.queryParameters['tab'])),
          page(AppRoutes.playlists, (_) => const PlaylistsPage(), routes: [
            page(':id', (s) => PlaylistDetailPage(playlistId: p(s, 'id'))),
          ]),
          page('/artist/:sourceId/:artistId', (s) => ArtistPage(sourceId: p(s, 'sourceId'), artistId: p(s, 'artistId'))),
          page('/album/:sourceId/:albumId', (s) => AlbumPage(sourceId: p(s, 'sourceId'), albumId: p(s, 'albumId'))),
          page(AppRoutes.downloads, (_) => const DownloadsPage()),
          page(AppRoutes.favorites, (_) => const FavoritesPage()),
          page(AppRoutes.history, (_) => const HistoryPage()),
          page(AppRoutes.queue, (_) => const QueuePage()),
          page(AppRoutes.settings, (_) => const SettingsPage(), routes: [
            page(':section', (s) => SettingsPage(section: p(s, 'section'))),
          ]),
          page(AppRoutes.import, (_) => const ImportPage(), routes: [
            page(':sessionId', (s) => ImportReviewPage(sessionId: p(s, 'sessionId'))),
          ]),
        ],
      ),
      GoRoute(
        path: AppRoutes.nowPlaying,
        parentNavigatorKey: rootKey,
        pageBuilder: (context, state) =>
            slideUp(state, NowPlayingPage(initialPanel: NowPlayingPanel.parse(state.uri.queryParameters['view']))),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        parentNavigatorKey: rootKey,
        pageBuilder: (context, state) => fade(state, const OnboardingPage()),
      ),
    ],
  );
}

/// Shown for unknown locations.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: EmptyState(
        icon: Icons.explore_off_rounded,
        title: l10n.shellPageNotFound,
        actionLabel: l10n.shellGoHome,
        onAction: () => context.go(AppRoutes.home),
      ),
    );
  }
}
