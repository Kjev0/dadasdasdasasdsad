import 'dart:io';

import 'package:fermata/app/providers.dart';
import 'package:fermata/app/services.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/net/http_client.dart';
import 'package:fermata/core/platform/app_paths.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:fermata/ui/actions/link_launcher.dart';
import 'package:fermata/ui/player/mini_mode.dart';
import 'package:fermata/ui/widgets/artwork/artwork_image.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_discovery.dart';
import 'fake_downloads.dart';
import 'fake_library.dart';
import 'fake_matching.dart';
import 'fake_platform.dart';
import 'fake_playback.dart';
import 'fake_sources.dart';

/// Every fake service wired into a real [AppServices] container.
///
/// ```dart
/// final kit = FakeKit(tracks: testTracks(3));
/// kit.playback.load(kit.tracks.all);
/// await pumpFermata(tester, kit: kit, initialRoute: '/queue');
/// expect(kit.playback.called('togglePlayPause'), isTrue);
/// ```
class FakeKit {
  FakeKit({
    AppSettings settings = const AppSettings(onboardingCompleted: true),
    this.os = HostOs.linux,
    List<MusicSource> sources = const [],
    List<Track> tracks = const [],
  })  : settingsStore = SettingsStore.inMemory(settings),
        sources = FakeSourceRegistry(sources) {
    trackRepo = FakeTrackRepository(libraryChanges, tracks);
    playlists = FakePlaylistRepository(libraryChanges, trackRepo);
    favorites = FakeFavoritesRepository(libraryChanges, trackRepo);
    links = FakeTrackLinkRepository(trackRepo);
  }

  final HostOs os;
  final SettingsStore settingsStore;
  final FakeSourceRegistry sources;

  final libraryChanges = FakeLibraryChangeBus();
  late final FakeTrackRepository trackRepo;
  late final FakePlaylistRepository playlists;
  late final FakeFavoritesRepository favorites;
  late final FakeTrackLinkRepository links;
  final history = FakeHistoryRepository();
  final searchHistory = FakeSearchHistoryRepository();
  final localLibrary = FakeLocalLibraryService();
  final maintenance = FakeLibraryMaintenance();

  final tokens = FakeTokenStore();
  final credentials = FakeCredentialsStore();
  final oauth = FakeOAuthClient();

  final streamResolver = FakeStreamResolver();
  final playback = FakePlaybackController();
  final downloads = FakeDownloadManager();

  final scorer = FakeTrackScorer();
  final matcher = FakeTrackMatcher();
  final imports = FakePlaylistImportService();

  final lyrics = FakeLyricsService();
  final recommendations = FakeRecommendationService();

  final lifecycle = FakeAppLifecycleController();
  final startup = FakeStartupManager();
  final hotkeys = FakeGlobalHotkeyService();
  final androidSystem = FakeAndroidSystemHelper();
  final notifier = FakeSystemNotifier();

  /// Mini-mode window fake (desktop kits only).
  final miniWindow = FakeMiniWindow();

  /// URLs "opened" through the external link launcher.
  final openedLinks = <Uri>[];

  /// HTTP responses for code that uses `FermataHttp` (default: 404).
  http.Response Function(http.Request request) httpHandler = (_) => http.Response('', 404);

  /// Convenience alias.
  FakeTrackRepository get tracks => trackRepo;

  PlatformInfo get platform => PlatformInfo(os: os);

  late final AppServices services = AppServices(
    platform: platform,
    paths: AppPaths(
      supportDir: Directory('${Directory.systemTemp.path}/fermata-ui-test/support'),
      cacheDir: Directory('${Directory.systemTemp.path}/fermata-ui-test/cache'),
      defaultDownloadDir: Directory('${Directory.systemTemp.path}/fermata-ui-test/downloads'),
      logsDir: Directory('${Directory.systemTemp.path}/fermata-ui-test/logs'),
    ),
    settings: settingsStore,
    http: FermataHttp(client: MockClient((r) async => httpHandler(r))),
    libraryChanges: libraryChanges,
    tracks: trackRepo,
    playlists: playlists,
    favorites: favorites,
    history: history,
    links: links,
    searchHistory: searchHistory,
    localLibrary: localLibrary,
    maintenance: maintenance,
    tokens: tokens,
    credentials: credentials,
    oauth: oauth,
    sources: sources,
    streamResolver: streamResolver,
    playback: playback,
    downloads: downloads,
    scorer: scorer,
    matcher: matcher,
    imports: imports,
    lyrics: lyrics,
    recommendations: recommendations,
    lifecycle: lifecycle,
    startup: startup,
    hotkeys: hotkeys,
    androidSystem: androidSystem,
    notifier: notifier,
  );

  /// Provider overrides for a `ProviderScope`: the services plus test-safe
  /// replacements (no url_launcher, no window_manager, no network images).
  /// Pass [services] to use a different container than [this.services].
  List<Override> overrides({AppServices? services}) => [
        ...serviceOverrides(services ?? this.services),
        externalLinkLauncherProvider.overrideWithValue((uri) async {
          openedLinks.add(uri);
          return true;
        }),
        miniWindowControllerProvider.overrideWithValue(platform.isDesktop ? miniWindow : null),
        artworkImageResolverProvider.overrideWithValue((uri) => null),
      ];
}
