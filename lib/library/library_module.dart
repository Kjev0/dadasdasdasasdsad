import 'dart:io';

import 'package:sqflite/sqflite.dart' show DatabaseFactory;

import '../core/contracts/playback.dart';
import '../core/platform/app_paths.dart';
import '../core/platform/platform_info.dart';
import '../settings/settings_store.dart';
import 'change_bus.dart';
import 'db/database.dart';
import 'history_recorder.dart';
import 'repositories/downloaded_index.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/history_repository.dart';
import 'repositories/maintenance.dart';
import 'repositories/playlist_repository.dart';
import 'repositories/search_history_repository.dart';
import 'repositories/track_link_repository.dart';
import 'repositories/track_repository.dart';
import 'scanner/folder_watcher.dart';
import 'scanner/local_library_service.dart';

/// Facade that opens the library database and creates every repository and
/// the local library service, for `lib/app/bootstrap.dart`.
class LibraryModule {
  LibraryModule._({
    required this.database,
    required this.changes,
    required this.tracks,
    required this.playlists,
    required this.favorites,
    required this.history,
    required this.links,
    required this.searchHistory,
    required this.localLibrary,
    required this.maintenance,
    required this.downloadedIndex,
  });

  /// Opens `paths.databaseFile` (or [databaseFile]; [inMemory] for tests).
  /// [settings] enables the `privacy.saveSearchHistory` check.
  static Future<LibraryModule> open({
    required AppPaths paths,
    required PlatformInfo platform,
    SettingsStore? settings,
    File? databaseFile,
    bool inMemory = false,
    DatabaseFactory? databaseFactory,
    Duration watchDebounce = const Duration(seconds: 2),
    DirectoryWatcherFactory? watcherFactory,
  }) async {
    final db = inMemory
        ? await FermataDatabase.openInMemory(factory: databaseFactory)
        : await FermataDatabase.open(databaseFile ?? paths.databaseFile, factory: databaseFactory);
    return fromDatabase(
      db,
      paths: paths,
      platform: platform,
      settings: settings,
      watchDebounce: watchDebounce,
      watcherFactory: watcherFactory,
    );
  }

  /// Builds the module on an already opened database.
  static LibraryModule fromDatabase(
    FermataDatabase db, {
    required AppPaths paths,
    required PlatformInfo platform,
    SettingsStore? settings,
    Duration watchDebounce = const Duration(seconds: 2),
    DirectoryWatcherFactory? watcherFactory,
  }) {
    final bus = LibraryChangeBusImpl();
    final tracks = SqlTrackRepository(db, bus);
    final playlists = SqlPlaylistRepository(db, bus);
    return LibraryModule._(
      database: db,
      changes: bus,
      tracks: tracks,
      playlists: playlists,
      favorites: SqlFavoritesRepository(db, bus),
      history: SqlHistoryRepository(db, bus),
      links: SqlTrackLinkRepository(db, bus),
      searchHistory: SqlSearchHistoryRepository(db, bus, settings: settings),
      localLibrary: LocalLibraryServiceImpl(
        db,
        tracks,
        paths,
        bus,
        platform,
        playlists: playlists,
        watchDebounce: watchDebounce,
        watcherFactory: watcherFactory,
      ),
      maintenance: SqlLibraryMaintenance(db, bus),
      downloadedIndex: DownloadedTracksIndex(db, bus),
    );
  }

  final FermataDatabase database;
  final LibraryChangeBusImpl changes;
  final SqlTrackRepository tracks;
  final SqlPlaylistRepository playlists;
  final SqlFavoritesRepository favorites;
  final SqlHistoryRepository history;
  final SqlTrackLinkRepository links;
  final SqlSearchHistoryRepository searchHistory;
  final LocalLibraryServiceImpl localLibrary;
  final SqlLibraryMaintenance maintenance;

  /// Feed it `DownloadManager.watchDownloadedIds()` once downloads exist.
  final DownloadedTracksIndex downloadedIndex;

  /// Mirrors completed downloads for the "Downloaded"/"Offline" filters.
  void attachDownloads(Stream<Set<String>> downloadedIds) => downloadedIndex.attach(downloadedIds);

  /// Creates (not started) the recorder that writes listening history.
  PlaybackHistoryRecorder createHistoryRecorder(PlaybackController playback, SettingsStore settings) =>
      PlaybackHistoryRecorder(playback, history, tracks, settings);

  /// Stops watchers/scans and closes the database.
  Future<void> close() async {
    await localLibrary.dispose();
    await downloadedIndex.dispose();
    await changes.dispose();
    await database.close();
  }
}
