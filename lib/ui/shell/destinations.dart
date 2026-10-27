import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../actions/routes.dart';

/// Responsive layout classes: compact < 600 dp ≤ medium < 1024 dp ≤ expanded.
enum LayoutSize {
  compact,
  medium,
  expanded;

  static LayoutSize forWidth(double width) => width < 600
      ? LayoutSize.compact
      : width < 1024
          ? LayoutSize.medium
          : LayoutSize.expanded;

  static LayoutSize of(BuildContext context) => forWidth(MediaQuery.sizeOf(context).width);
}

/// Top-level navigation destinations.
enum NavDestination {
  home(AppRoutes.home, Icons.home_rounded),
  search(AppRoutes.search, Icons.search_rounded),
  explore(AppRoutes.explore, Icons.explore_rounded),
  library(AppRoutes.libraryPath, Icons.library_music_rounded),
  playlists(AppRoutes.playlists, Icons.playlist_play_rounded),
  downloads(AppRoutes.downloads, Icons.download_rounded),
  favorites(AppRoutes.favorites, Icons.favorite_rounded),
  history(AppRoutes.history, Icons.history_rounded),
  queue(AppRoutes.queue, Icons.queue_music_rounded),
  settings(AppRoutes.settings, Icons.settings_rounded);

  const NavDestination(this.path, this.icon);

  final String path;
  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
        home => l10n.navHome,
        search => l10n.navSearch,
        explore => l10n.navExplore,
        library => l10n.navLibrary,
        playlists => l10n.navPlaylists,
        downloads => l10n.navDownloads,
        favorites => l10n.navFavorites,
        history => l10n.navHistory,
        queue => l10n.navQueue,
        settings => l10n.navSettings,
      };

  /// Bottom navigation (compact layouts).
  static const compactItems = [home, search, explore, library, settings];

  /// Navigation rail (medium layouts); settings sits at the bottom.
  static const railItems = [home, search, explore, library, playlists, downloads, favorites, history, queue];

  /// Sidebar groups (expanded layouts).
  static const sidebarPrimary = [home, search, explore];
  static const sidebarLibrary = [library, playlists, downloads, favorites, history, queue];

  /// The destination whose section contains [path] (exact or nested), if any.
  static NavDestination? matching(String path) {
    for (final d in values) {
      if (path == d.path || path.startsWith('${d.path}/')) return d;
    }
    return null;
  }

  /// The bottom-navigation item to highlight for [path]: library-related
  /// pages (playlists, artists, albums, downloads, …) highlight Library.
  static NavDestination compactFor(String path) {
    final d = matching(path);
    if (d != null && compactItems.contains(d)) return d;
    if (path.startsWith('/import')) return settings;
    return d == null && (path.startsWith('/artist') || path.startsWith('/album')) ? library : (d == null ? home : library);
  }
}
