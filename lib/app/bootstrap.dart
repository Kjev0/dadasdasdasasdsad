import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../core/contracts/discovery.dart';
import '../core/contracts/platform.dart';
import '../core/logging/logging.dart';
import '../core/net/http_client.dart';
import '../core/platform/app_paths.dart';
import '../core/platform/platform_info.dart';
import '../discovery/discovery.dart';
import '../downloads/downloads.dart';
import '../library/library_module.dart';
import '../matching/matching.dart';
import '../platform/android/android_platform.dart';
import '../platform/desktop/desktop_integration.dart';
import '../platform/desktop/single_instance.dart';
import '../playback/playback.dart';
import '../settings/settings_store.dart';
import '../sources/audius/audius_source.dart';
import '../sources/auth/auth.dart';
import '../sources/deezer/deezer_source.dart';
import '../sources/local/local_source.dart';
import '../sources/registry/source_registry_impl.dart';
import 'services.dart';

final _log = Logger('app.bootstrap');

/// Everything created at startup, plus what is needed to shut down cleanly.
class Bootstrapped {
  Bootstrapped(this.services, this.artworkCache);

  final AppServices services;
  final FermataArtworkCache artworkCache;
}

/// Creates every long-lived service in dependency order (see
/// docs/ARCHITECTURE.md → Runtime flow). Must run before `runApp`.
Future<Bootstrapped> bootstrap(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = PlatformInfo.current();
  final paths = await AppPaths.resolve();

  // A second desktop launch forwards its command to the running instance and
  // exits here, before any heavy work.
  final instance = platform.isDesktop ? await SingleInstance.ensure(paths, args) : null;

  await AppLogging.init(logsDir: paths.logsDir);
  _log.info('Starting Fermata on ${platform.os.name}');

  final settings = await SettingsStore.load(paths.settingsFile);
  final http = FermataHttp();

  // Library (SQLite) and repositories.
  final library = await LibraryModule.open(paths: paths, platform: platform, settings: settings);

  // Credentials, tokens, OAuth and sources.
  final secureStorage = await ProbedSecureStorage.open();
  final tokens = SecureTokenStore(secureStorage);
  final credentials = CredentialsStoreImpl(configFile: paths.credentialsFile, secureStorage: secureStorage);
  await credentials.init();
  final oauth = OAuthClientImpl(http: http, platform: platform);
  final sources = SourceRegistryImpl(settings: settings)
    ..register(LocalSource(tracks: library.tracks))
    ..register(AudiusSource(http: http, credentials: credentials))
    ..register(DeezerSource(http: http));
  await sources.initAll();

  // Notifications: the desktop notifier only exists once the desktop
  // integration has started, so downloads get a forwarding notifier.
  final notifier = _ForwardingNotifier(platform.isAndroid ? const AndroidNotifier() : null);

  // Downloads + offline.
  final network = ConnectivityNetworkStatus(platform: platform);
  await network.init();
  final artworkCache = FermataArtworkCache(paths: paths, settings: settings, http: http);
  final downloads = DownloadManagerImpl(
    sources: sources,
    tracks: library.tracks,
    playlists: library.playlists,
    history: library.history,
    settings: settings,
    paths: paths,
    http: http,
    network: network,
    notifier: notifier,
    artwork: artworkCache,
    databaseSize: library.maintenance.databaseSizeBytes,
  );
  await downloads.init();
  library.attachDownloads(downloads.watchDownloadedIds());

  // Discovery (needed by the smart queue).
  final RecommendationService recommendations = RecommendationServiceImpl(
    sources,
    library.history,
    library.tracks,
    library.favorites,
    settings,
    paths,
  );
  final lyrics = LyricsServiceImpl(http, settings, paths);

  // Playback.
  if (platform.isDesktop) MediaKitBackend.ensureInitialized();
  final resolver = StreamResolverImpl(
    sources: sources,
    downloads: downloads,
    links: library.links,
    settings: settings,
    isMetered: network.isMeteredNow,
  );
  final playback = PlaybackControllerImpl(
    backend: createPlatformAudioBackend(platform),
    resolver: resolver,
    settings: settings,
    stateFile: paths.queueStateFile,
    smartQueueProvider: (recent) => recommendations.smartQueueContinuation(recent),
    platform: platform,
  );
  await playback.init();
  final historyRecorder = library.createHistoryRecorder(playback, settings)..start();

  // Matching / playlist migration.
  final scorer = WeightedTrackScorer();
  final matcher = SourceTrackMatcher(registry: sources, scorer: scorer);
  final imports = PlaylistImportServiceImpl(
    registry: sources,
    matcher: matcher,
    scorer: scorer,
    trackRepository: library.tracks,
    playlistRepository: library.playlists,
    linkRepository: library.links,
  );

  // Platform media sessions.
  final androidSession = platform.isAndroid
      ? await AndroidMediaSession.start(
          playback: playback,
          settings: settings,
          tracks: library.tracks,
          playlists: library.playlists,
          history: library.history,
          favorites: library.favorites,
          platform: platform,
        )
      : null;

  Future<void> disposeAll() async {
    await historyRecorder.dispose();
    await androidSession?.dispose();
    await downloads.dispose();
    await artworkCache.dispose();
    await network.dispose();
    for (final s in sources.all) {
      await s.dispose();
    }
    await sources.dispose();
    await credentials.dispose();
    await library.close();
    http.close();
    await settings.dispose();
    await AppLogging.close();
  }

  final desktop = await DesktopIntegration.start(
    platform: platform,
    playback: playback,
    settings: settings,
    paths: paths,
    singleInstance: instance,
    args: args,
    disposeAll: disposeAll,
    openFile: (path) async {
      final track = await library.localLibrary.importFile(path);
      if (track != null) await playback.playTracks([track], origin: 'file');
    },
  );
  if (!platform.isAndroid) notifier.target = desktop.notifier;

  // Local library: watch folders (desktop) and run an incremental scan.
  unawaited(library.localLibrary.startWatching());
  unawaited(library.localLibrary.scan().drain<void>().catchError((Object e, StackTrace st) {
    _log.warning('Initial library scan failed', e, st);
  }));

  final services = AppServices(
    platform: platform,
    paths: paths,
    settings: settings,
    http: http,
    libraryChanges: library.changes,
    tracks: library.tracks,
    playlists: library.playlists,
    favorites: library.favorites,
    history: library.history,
    links: library.links,
    searchHistory: library.searchHistory,
    localLibrary: library.localLibrary,
    maintenance: library.maintenance,
    tokens: tokens,
    credentials: credentials,
    oauth: oauth,
    sources: sources,
    streamResolver: resolver,
    playback: playback,
    downloads: downloads,
    scorer: scorer,
    matcher: matcher,
    imports: imports,
    lyrics: lyrics,
    recommendations: recommendations,
    lifecycle: desktop.lifecycle,
    startup: desktop.startup,
    hotkeys: desktop.hotkeys,
    androidSystem: AndroidSystemHelperImpl(platform: platform),
    notifier: notifier,
  );
  return Bootstrapped(services, artworkCache);
}

/// Delegates to a notifier that may only become available later in startup.
class _ForwardingNotifier implements SystemNotifier {
  _ForwardingNotifier(this.target);

  SystemNotifier? target;

  @override
  bool get isSupported => target?.isSupported ?? false;

  @override
  Future<void> show({required String id, required String title, String? body, String? iconPath}) async {
    final t = target;
    if (t != null && t.isSupported) await t.show(id: id, title: title, body: body, iconPath: iconPath);
  }
}
