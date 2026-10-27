import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../settings/app_settings.dart';
import 'routes.dart';
import 'track_actions.dart';

/// Groups in the command palette.
enum CommandCategory { navigation, player, settings, playlist, track }

/// What a command needs to run. Built from the root navigator's context and
/// the app's [ProviderContainer] so it stays valid after the palette or the
/// widget that triggered it is gone.
class CommandContext {
  CommandContext({required this.container, required this.router, required this.context});

  final ProviderContainer container;
  final GoRouter router;

  /// A long-lived context below the navigator (for dialogs and toasts).
  final BuildContext context;

  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  TrackActions get trackActions => TrackActions.fromContainer(context, container);
}

/// A runnable command (palette entry and/or keyboard shortcut target).
class FermataCommand {
  const FermataCommand({
    required this.id,
    required this.category,
    required this.label,
    required this.icon,
    required this.run,
    this.keywords = const [],
    this.shortcutAction,
  });

  /// Stable id. Player and navigation commands that have a keyboard binding
  /// use the `ShortcutActions` id (e.g. `playPause`).
  final String id;
  final CommandCategory category;
  final String label;
  final IconData icon;
  final List<String> keywords;

  /// `ShortcutActions` id whose binding is shown next to the command.
  final String? shortcutAction;
  final FutureOr<void> Function(CommandContext ctx) run;
}

/// Opens the command palette (registered by the shell to avoid an import
/// cycle; set in `command_palette.dart`).
typedef PaletteOpener = Future<void> Function(BuildContext context);

/// The action registry behind keyboard shortcuts and the command palette.
///
/// ui-settings uses [labelFor] / [shortcutActions] for the Keyboard
/// shortcuts page.
abstract final class CommandRegistry {
  /// Set by the shell; opens the palette.
  static PaletteOpener? paletteOpener;

  static const _seekStep = Duration(seconds: 10);
  static const _volumeStep = 0.05;

  /// In-app (non-global) shortcut action ids, in display order.
  static List<String> get shortcutActions =>
      [for (final a in ShortcutActions.defaults.keys) if (!ShortcutActions.isGlobal(a)) a];

  /// All bindable action ids (in-app first, then global hotkeys).
  static List<String> get allBindableActions => ShortcutActions.defaults.keys.toList();

  /// Localized label for a `ShortcutActions` id.
  static String labelFor(AppLocalizations l10n, String actionId) => switch (actionId) {
        ShortcutActions.playPause => l10n.cmdPlayPause,
        ShortcutActions.next => l10n.cmdNext,
        ShortcutActions.previous => l10n.cmdPrevious,
        ShortcutActions.seekForward => l10n.cmdSeekForward,
        ShortcutActions.seekBackward => l10n.cmdSeekBackward,
        ShortcutActions.volumeUp => l10n.cmdVolumeUp,
        ShortcutActions.volumeDown => l10n.cmdVolumeDown,
        ShortcutActions.toggleShuffle => l10n.cmdToggleShuffle,
        ShortcutActions.cycleRepeat => l10n.cmdCycleRepeat,
        ShortcutActions.like => l10n.cmdLike,
        ShortcutActions.search => l10n.cmdSearch,
        ShortcutActions.commandPalette => l10n.cmdCommandPalette,
        ShortcutActions.nowPlaying => l10n.cmdNowPlaying,
        ShortcutActions.queue => l10n.cmdQueue,
        ShortcutActions.settings => l10n.cmdSettings,
        ShortcutActions.globalPlayPause => l10n.cmdGlobalPlayPause,
        ShortcutActions.globalNext => l10n.cmdGlobalNext,
        ShortcutActions.globalPrevious => l10n.cmdGlobalPrevious,
        ShortcutActions.globalShowWindow => l10n.cmdGlobalShowWindow,
        _ => actionId,
      };

  /// Localized label for a settings section id (`SettingsSections`).
  static String sectionLabel(AppLocalizations l10n, String section) => switch (section) {
        SettingsSections.appearance => l10n.shellSectionAppearance,
        SettingsSections.glass => l10n.shellSectionGlass,
        SettingsSections.playback => l10n.shellSectionPlayback,
        SettingsSections.audioQuality => l10n.shellSectionAudioQuality,
        SettingsSections.downloads => l10n.shellSectionDownloads,
        SettingsSections.storage => l10n.shellSectionStorage,
        SettingsSections.performance => l10n.shellSectionPerformance,
        SettingsSections.savers => l10n.shellSectionSavers,
        SettingsSections.services => l10n.shellSectionServices,
        SettingsSections.import => l10n.shellSectionImport,
        SettingsSections.notifications => l10n.shellSectionNotifications,
        SettingsSections.background => l10n.shellSectionBackground,
        SettingsSections.desktop => l10n.shellSectionDesktop,
        SettingsSections.startup => l10n.shellSectionStartup,
        SettingsSections.shortcuts => l10n.shellSectionShortcuts,
        SettingsSections.privacy => l10n.shellSectionPrivacy,
        SettingsSections.language => l10n.shellSectionLanguage,
        SettingsSections.accessibility => l10n.shellSectionAccessibility,
        SettingsSections.updates => l10n.shellSectionUpdates,
        SettingsSections.about => l10n.shellSectionAbout,
        _ => section,
      };

  static void _go(CommandContext c, String path) => c.router.go(path);

  /// Every static command (navigation, player, settings sections).
  /// [miniPlayerSupported] adds the mini-player toggle; [onToggleMiniPlayer]
  /// performs it.
  static List<FermataCommand> commands(
    AppLocalizations l10n, {
    bool miniPlayerSupported = false,
    FutureOr<void> Function(CommandContext ctx)? onToggleMiniPlayer,
  }) {
    FermataCommand nav(String id, String label, IconData icon, String path, {String? shortcut, List<String> keywords = const []}) =>
        FermataCommand(
          id: id,
          category: CommandCategory.navigation,
          label: label,
          icon: icon,
          keywords: keywords,
          shortcutAction: shortcut,
          run: (c) => _go(c, path),
        );
    FermataCommand player(String id, String label, IconData icon, FutureOr<void> Function(CommandContext) run, {List<String> keywords = const []}) =>
        FermataCommand(
          id: id,
          category: CommandCategory.player,
          label: label,
          icon: icon,
          keywords: keywords,
          shortcutAction: ShortcutActions.defaults.containsKey(id) ? id : null,
          run: run,
        );

    return [
      nav('nav.home', l10n.navHome, Icons.home_rounded, AppRoutes.home),
      nav(ShortcutActions.search, l10n.navSearch, Icons.search_rounded, AppRoutes.search, shortcut: ShortcutActions.search),
      nav('nav.explore', l10n.navExplore, Icons.explore_rounded, AppRoutes.explore),
      nav('nav.library', l10n.navLibrary, Icons.library_music_rounded, AppRoutes.libraryPath),
      nav('nav.playlists', l10n.navPlaylists, Icons.playlist_play_rounded, AppRoutes.playlists),
      nav('nav.downloads', l10n.navDownloads, Icons.download_rounded, AppRoutes.downloads),
      nav('nav.favorites', l10n.navFavorites, Icons.favorite_rounded, AppRoutes.favorites),
      nav('nav.history', l10n.navHistory, Icons.history_rounded, AppRoutes.history),
      nav(ShortcutActions.queue, l10n.navQueue, Icons.queue_music_rounded, AppRoutes.queue, shortcut: ShortcutActions.queue),
      FermataCommand(
        id: ShortcutActions.nowPlaying,
        category: CommandCategory.navigation,
        label: l10n.navNowPlaying,
        icon: Icons.album_rounded,
        shortcutAction: ShortcutActions.nowPlaying,
        run: (c) {
          if (c.router.routerDelegate.currentConfiguration.uri.path != AppRoutes.nowPlaying) {
            c.router.push(AppRoutes.nowPlaying);
          }
        },
      ),
      nav(ShortcutActions.settings, l10n.navSettings, Icons.settings_rounded, AppRoutes.settings, shortcut: ShortcutActions.settings),
      nav('nav.import', l10n.navImport, Icons.playlist_add_rounded, AppRoutes.import),
      player(ShortcutActions.playPause, l10n.cmdPlayPause, Icons.play_arrow_rounded, (c) => c.read(playbackProvider).togglePlayPause()),
      player(ShortcutActions.next, l10n.cmdNext, Icons.skip_next_rounded, (c) => c.read(playbackProvider).next()),
      player(ShortcutActions.previous, l10n.cmdPrevious, Icons.skip_previous_rounded, (c) => c.read(playbackProvider).previous()),
      player(ShortcutActions.seekForward, l10n.cmdSeekForward, Icons.forward_10_rounded,
          (c) => c.read(playbackProvider).seekRelative(_seekStep)),
      player(ShortcutActions.seekBackward, l10n.cmdSeekBackward, Icons.replay_10_rounded,
          (c) => c.read(playbackProvider).seekRelative(-_seekStep)),
      player(ShortcutActions.volumeUp, l10n.cmdVolumeUp, Icons.volume_up_rounded, (c) {
        final p = c.read(playbackProvider);
        return p.setVolume((p.snapshot.volume + _volumeStep).clamp(0.0, 1.0));
      }),
      player(ShortcutActions.volumeDown, l10n.cmdVolumeDown, Icons.volume_down_rounded, (c) {
        final p = c.read(playbackProvider);
        return p.setVolume((p.snapshot.volume - _volumeStep).clamp(0.0, 1.0));
      }),
      player(ShortcutActions.toggleShuffle, l10n.cmdToggleShuffle, Icons.shuffle_rounded, (c) {
        final p = c.read(playbackProvider);
        return p.setShuffle(!p.snapshot.shuffle);
      }),
      player(ShortcutActions.cycleRepeat, l10n.cmdCycleRepeat, Icons.repeat_rounded, (c) => c.read(playbackProvider).cycleRepeat()),
      player(ShortcutActions.like, l10n.cmdLike, Icons.favorite_rounded, (c) {
        final track = c.read(playbackProvider).snapshot.track;
        if (track == null) return null;
        return c.trackActions.toggleFavorite(track);
      }),
      player('player.stop', l10n.cmdStop, Icons.stop_rounded, (c) => c.read(playbackProvider).stop()),
      player('player.clearQueue', l10n.cmdClearQueue, Icons.clear_all_rounded,
          (c) => c.read(playbackProvider).clearQueue(keepCurrent: true)),
      if (miniPlayerSupported && onToggleMiniPlayer != null)
        player('player.miniPlayer', l10n.cmdMiniPlayer, Icons.picture_in_picture_alt_rounded, onToggleMiniPlayer),
      for (final section in SettingsSections.all)
        FermataCommand(
          id: 'settings.$section',
          category: CommandCategory.settings,
          label: sectionLabel(l10n, section),
          icon: Icons.tune_rounded,
          keywords: [l10n.navSettings],
          run: (c) => _go(c, AppRoutes.settingsSection(section)),
        ),
    ];
  }

  /// Runs the command bound to the in-app shortcut [actionId]. Returns false
  /// when no command exists for it.
  static Future<bool> runShortcut(String actionId, CommandContext ctx, AppLocalizations l10n,
      {bool miniPlayerSupported = false, FutureOr<void> Function(CommandContext ctx)? onToggleMiniPlayer}) async {
    if (actionId == ShortcutActions.commandPalette) {
      await paletteOpener?.call(ctx.context);
      return paletteOpener != null;
    }
    final command = commands(l10n, miniPlayerSupported: miniPlayerSupported, onToggleMiniPlayer: onToggleMiniPlayer)
        .where((c) => c.id == actionId)
        .firstOrNull;
    if (command == null) return false;
    await command.run(ctx);
    return true;
  }
}
