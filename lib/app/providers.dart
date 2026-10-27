import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/contracts/auth.dart';
import '../core/contracts/discovery.dart';
import '../core/contracts/downloads.dart';
import '../core/contracts/library.dart';
import '../core/contracts/matching.dart';
import '../core/contracts/music_source.dart';
import '../core/contracts/platform.dart';
import '../core/contracts/playback.dart';
import '../core/models/download.dart';
import '../core/models/playback.dart';
import '../core/platform/app_paths.dart';
import '../core/platform/platform_info.dart';
import '../settings/app_settings.dart';
import '../settings/performance_profiles.dart';
import '../settings/settings_store.dart';
import 'services.dart';

// ---------------------------------------------------------------------------
// Service providers. All are overridden at startup from [AppServices]
// (see `serviceOverrides`). Widgets use `ref.read(xProvider)` for actions and
// the derived stream providers below for reactive state.
// ---------------------------------------------------------------------------

Never _missing(String name) => throw UnimplementedError('$name is provided by bootstrap overrides');

final appServicesProvider = Provider<AppServices>((ref) => _missing('appServicesProvider'));

final platformInfoProvider = Provider<PlatformInfo>((ref) => ref.watch(appServicesProvider).platform);
final appPathsProvider = Provider<AppPaths>((ref) => ref.watch(appServicesProvider).paths);
final settingsStoreProvider = Provider<SettingsStore>((ref) => ref.watch(appServicesProvider).settings);

final libraryChangesProvider = Provider<LibraryChangeBus>((ref) => ref.watch(appServicesProvider).libraryChanges);
final trackRepositoryProvider = Provider<TrackRepository>((ref) => ref.watch(appServicesProvider).tracks);
final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) => ref.watch(appServicesProvider).playlists);
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) => ref.watch(appServicesProvider).favorites);
final historyRepositoryProvider = Provider<HistoryRepository>((ref) => ref.watch(appServicesProvider).history);
final trackLinkRepositoryProvider = Provider<TrackLinkRepository>((ref) => ref.watch(appServicesProvider).links);
final searchHistoryProvider = Provider<SearchHistoryRepository>((ref) => ref.watch(appServicesProvider).searchHistory);
final localLibraryProvider = Provider<LocalLibraryService>((ref) => ref.watch(appServicesProvider).localLibrary);
final libraryMaintenanceProvider = Provider<LibraryMaintenance>((ref) => ref.watch(appServicesProvider).maintenance);

final tokenStoreProvider = Provider<TokenStore>((ref) => ref.watch(appServicesProvider).tokens);
final credentialsStoreProvider = Provider<CredentialsStore>((ref) => ref.watch(appServicesProvider).credentials);
final oauthClientProvider = Provider<OAuthClient>((ref) => ref.watch(appServicesProvider).oauth);
final sourceRegistryProvider = Provider<SourceRegistry>((ref) => ref.watch(appServicesProvider).sources);

final playbackProvider = Provider<PlaybackController>((ref) => ref.watch(appServicesProvider).playback);
final downloadManagerProvider = Provider<DownloadManager>((ref) => ref.watch(appServicesProvider).downloads);

final trackScorerProvider = Provider<TrackScorer>((ref) => ref.watch(appServicesProvider).scorer);
final trackMatcherProvider = Provider<TrackMatcher>((ref) => ref.watch(appServicesProvider).matcher);
final playlistImportProvider = Provider<PlaylistImportService>((ref) => ref.watch(appServicesProvider).imports);

final lyricsServiceProvider = Provider<LyricsService>((ref) => ref.watch(appServicesProvider).lyrics);
final recommendationsProvider = Provider<RecommendationService>((ref) => ref.watch(appServicesProvider).recommendations);

final appLifecycleProvider = Provider<AppLifecycleController>((ref) => ref.watch(appServicesProvider).lifecycle);
final startupManagerProvider = Provider<StartupManager>((ref) => ref.watch(appServicesProvider).startup);
final globalHotkeysProvider = Provider<GlobalHotkeyService>((ref) => ref.watch(appServicesProvider).hotkeys);
final androidSystemProvider = Provider<AndroidSystemHelper>((ref) => ref.watch(appServicesProvider).androidSystem);
final systemNotifierProvider = Provider<SystemNotifier>((ref) => ref.watch(appServicesProvider).notifier);

List<Override> serviceOverrides(AppServices services) => [appServicesProvider.overrideWithValue(services)];

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

/// Reactive mirror of [SettingsStore]. Write via
/// `ref.read(settingsStoreProvider).update((s) => ...)`.
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final store = ref.watch(settingsStoreProvider);
    final sub = store.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return store.current;
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// OS "reduce motion" preference, updated by the app shell from MediaQuery
/// via `ref.read(systemReduceMotionProvider.notifier).set(value)`.
class SystemReduceMotion extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final systemReduceMotionProvider = NotifierProvider<SystemReduceMotion, bool>(SystemReduceMotion.new);

final effectiveVisualsProvider = Provider<EffectiveVisuals>((ref) {
  final settings = ref.watch(settingsProvider);
  return EffectiveVisuals.from(
    settings,
    systemReduceMotion: ref.watch(systemReduceMotionProvider),
    platformSupportsBlur: ref.watch(platformInfoProvider).supportsBlur,
  );
});

final localeProvider = Provider<Locale?>((ref) {
  final code = ref.watch(settingsProvider.select((s) => s.localeCode));
  return code == null ? null : Locale(code);
});

// ---------------------------------------------------------------------------
// Playback state
// ---------------------------------------------------------------------------

final playbackSnapshotProvider = StreamProvider<PlaybackSnapshot>((ref) async* {
  final playback = ref.watch(playbackProvider);
  yield playback.snapshot;
  yield* playback.snapshots;
});

final queueStateProvider = StreamProvider<QueueState>((ref) async* {
  final playback = ref.watch(playbackProvider);
  yield playback.queue;
  yield* playback.queueStream;
});

/// Current snapshot without AsyncValue plumbing (falls back to idle).
final currentSnapshotProvider = Provider<PlaybackSnapshot>((ref) {
  return ref.watch(playbackSnapshotProvider).value ?? ref.watch(playbackProvider).snapshot;
});

// ---------------------------------------------------------------------------
// Library / downloads reactive helpers
// ---------------------------------------------------------------------------

final favoriteIdsProvider = StreamProvider<Set<String>>((ref) => ref.watch(favoritesRepositoryProvider).watchFavoriteIds());

final downloadedIdsProvider = StreamProvider<Set<String>>((ref) => ref.watch(downloadManagerProvider).watchDownloadedIds());

final downloadTasksProvider = StreamProvider<List<DownloadTask>>((ref) async* {
  final dm = ref.watch(downloadManagerProvider);
  yield dm.tasks;
  yield* dm.tasksStream;
});

/// Increments whenever the given library topics change — `ref.watch` it in
/// FutureProviders to refetch.
final libraryRevisionProvider = StreamProvider.family<int, LibraryTopic>((ref, topic) async* {
  var revision = 0;
  yield revision;
  await for (final topics in ref.watch(libraryChangesProvider).changes) {
    if (topics.contains(topic)) yield ++revision;
  }
});

/// Emits whenever sources' auth state or preference order changes.
final sourcesRevisionProvider = StreamProvider<int>((ref) async* {
  var revision = 0;
  yield revision;
  await for (final _ in ref.watch(sourceRegistryProvider).changes) {
    yield ++revision;
  }
});
