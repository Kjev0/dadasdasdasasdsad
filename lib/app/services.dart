import '../core/contracts/auth.dart';
import '../core/contracts/discovery.dart';
import '../core/contracts/downloads.dart';
import '../core/contracts/library.dart';
import '../core/contracts/matching.dart';
import '../core/contracts/music_source.dart';
import '../core/contracts/platform.dart';
import '../core/contracts/playback.dart';
import '../core/net/http_client.dart';
import '../core/platform/app_paths.dart';
import '../core/platform/platform_info.dart';
import '../settings/settings_store.dart';

/// Composition root: every long-lived service, created once in
/// `bootstrap.dart` in dependency order and injected into Riverpod via
/// `serviceOverrides`. Services never depend on widgets.
class AppServices {
  AppServices({
    required this.platform,
    required this.paths,
    required this.settings,
    required this.http,
    required this.libraryChanges,
    required this.tracks,
    required this.playlists,
    required this.favorites,
    required this.history,
    required this.links,
    required this.searchHistory,
    required this.localLibrary,
    required this.maintenance,
    required this.tokens,
    required this.credentials,
    required this.oauth,
    required this.sources,
    required this.streamResolver,
    required this.playback,
    required this.downloads,
    required this.scorer,
    required this.matcher,
    required this.imports,
    required this.lyrics,
    required this.recommendations,
    required this.lifecycle,
    required this.startup,
    required this.hotkeys,
    required this.androidSystem,
    required this.notifier,
  });

  final PlatformInfo platform;
  final AppPaths paths;
  final SettingsStore settings;
  final FermataHttp http;

  final LibraryChangeBus libraryChanges;
  final TrackRepository tracks;
  final PlaylistRepository playlists;
  final FavoritesRepository favorites;
  final HistoryRepository history;
  final TrackLinkRepository links;
  final SearchHistoryRepository searchHistory;
  final LocalLibraryService localLibrary;
  final LibraryMaintenance maintenance;

  final TokenStore tokens;
  final CredentialsStore credentials;
  final OAuthClient oauth;
  final SourceRegistry sources;

  final StreamResolver streamResolver;
  final PlaybackController playback;
  final DownloadManager downloads;

  final TrackScorer scorer;
  final TrackMatcher matcher;
  final PlaylistImportService imports;

  final LyricsService lyrics;
  final RecommendationService recommendations;

  final AppLifecycleController lifecycle;
  final StartupManager startup;
  final GlobalHotkeyService hotkeys;
  final AndroidSystemHelper androidSystem;
  final SystemNotifier notifier;
}
