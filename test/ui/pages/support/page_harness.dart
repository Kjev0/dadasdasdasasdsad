import 'dart:async';

import 'package:fermata/app/services.dart';
import 'package:fermata/core/contracts/downloads.dart';
import 'package:fermata/core/contracts/library.dart';
import 'package:fermata/core/contracts/discovery.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/ui/pages/library/shared/page_services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

/// A fixed "now" for greeting / day-grouping tests (a Tuesday, 10:30).
final testNow = DateTime(2026, 10, 27, 10, 30);

/// Track repository that records queries and applies sort + every filter
/// the Library offers (the shared fake only does text/source/artist/album).
class RecordingTrackRepository extends FakeTrackRepository {
  RecordingTrackRepository(super.bus, [super.initial]);

  final queries = <TrackQuery>[];
  TrackQuery? get lastQuery => queries.isEmpty ? null : queries.last;

  /// Ids treated as favorites / downloaded for the filters.
  final favoriteIds = <String>{};
  final downloadedIds = <String>{};
  List<Track> missing = const [];
  List<DuplicateGroup> duplicates = const [];

  @override
  Future<List<Track>> query(TrackQuery query) async {
    queries.add(query);
    var list = await super.query(TrackQuery(text: query.text, sourceIds: query.sourceIds, localFilesOnly: query.localFilesOnly, artist: query.artist, album: query.album, genre: query.genre));
    list = [
      for (final t in list)
        if ((!query.favoritesOnly || favoriteIds.contains(t.id)) &&
            (!query.downloadedOnly || downloadedIds.contains(t.id)) &&
            (!query.offlineAvailableOnly || t.isLocal || downloadedIds.contains(t.id)) &&
            (query.minYear == null || (t.year ?? 0) >= query.minYear!) &&
            (query.maxYear == null || (t.year ?? 9999) <= query.maxYear!) &&
            (query.minDuration == null || (t.duration ?? Duration.zero) >= query.minDuration!) &&
            (query.maxDuration == null || (t.duration ?? Duration.zero) <= query.maxDuration!))
          t,
    ];
    int cmp(Track a, Track b) => switch (query.sort) {
          TrackSortField.title => a.title.compareTo(b.title),
          TrackSortField.artist => a.artistLine.compareTo(b.artistLine),
          TrackSortField.album => (a.album ?? '').compareTo(b.album ?? ''),
          TrackSortField.year => (a.year ?? 0).compareTo(b.year ?? 0),
          TrackSortField.duration => (a.duration ?? Duration.zero).compareTo(b.duration ?? Duration.zero),
          _ => 0,
        };
    if (query.sort != TrackSortField.dateAdded) {
      list.sort((a, b) => query.descending ? cmp(b, a) : cmp(a, b));
    }
    if (query.limit != null && list.length > query.limit!) list = list.sublist(0, query.limit!);
    return list;
  }

  @override
  Future<List<Track>> findMissingFiles() async => missing;

  @override
  Future<List<DuplicateGroup>> findDuplicates() async => duplicates;
}

/// Local library fake with upserting folders, controllable scans and
/// import results.
class ControllableLocalLibrary extends FakeLocalLibraryService {
  final addCalls = <(String, bool)>[];
  final removeCalls = <String>[];
  StreamController<ScanProgress>? scanController;
  Track? importResult;
  List<Track> m3uTracks = const [];
  final exported = <(String, String)>[];
  final edits = <Track>[];

  @override
  Future<void> addFolder(String path, {bool watch = true}) async {
    record('addFolder');
    addCalls.add((path, watch));
    final i = folderList.indexWhere((f) => f.path == path);
    final folder = LibraryFolder(path: path, watch: watch, trackCount: i >= 0 ? folderList[i].trackCount : 0);
    i >= 0 ? folderList[i] = folder : folderList.add(folder);
  }

  @override
  Future<void> removeFolder(String path, {bool removeTracks = true}) async {
    removeCalls.add(path);
    await super.removeFolder(path, removeTracks: removeTracks);
  }

  @override
  Stream<ScanProgress> scan({String? folder, bool full = false}) {
    record('scan');
    final c = scanController;
    if (c == null) return super.scan(folder: folder, full: full);
    return c.stream;
  }

  @override
  Future<Track?> importFile(String path) async {
    record('importFile');
    return importResult;
  }

  @override
  Future<List<Track>> importM3u(String path) async {
    record('importM3u');
    return m3uTracks;
  }

  @override
  Future<void> exportM3u(String playlistId, String path, {bool extended = true}) async {
    record('exportM3u');
    exported.add((playlistId, path));
  }

  @override
  Future<bool> editTags(Track track, Track edited) async {
    edits.add(edited);
    return super.editTags(track, edited);
  }
}

/// Playlist repository fake that keeps smart rules and records moves.
class RecordingPlaylistRepository extends FakePlaylistRepository {
  RecordingPlaylistRepository(super.bus, super.tracks);

  final moves = <(int, int)>[];
  final updated = <Playlist>[];
  SmartPlaylistRules? lastRules;

  @override
  Future<Playlist> createSmartPlaylist(String name, SmartPlaylistRules rules, {String? description}) async {
    lastRules = rules;
    return super.createSmartPlaylist(name, rules, description: description);
  }

  @override
  Future<void> move(String playlistId, int from, int to) async {
    moves.add((from, to));
    await super.move(playlistId, from, to);
  }

  @override
  Future<void> updatePlaylist(Playlist playlist) async {
    updated.add(playlist);
    await super.updatePlaylist(playlist);
  }
}

/// History fake with preset statistics.
class StatsHistoryRepository extends FakeHistoryRepository {
  ListeningStats? preset;

  @override
  Future<ListeningStats> stats({DateTime? since}) async {
    record('stats');
    return preset ?? await super.stats(since: since);
  }
}

/// Download manager fake exposing the implementation's network-policy
/// extras (`needsMobileDataConfirmation` …).
class PolicyDownloadManager extends FakeDownloadManager {
  bool needsMobileDataConfirmation = false;
  Object? networkWaitReason;
  int confirmations = 0;

  void confirmMobileDataForSession() {
    confirmations++;
    needsMobileDataConfirmation = false;
  }
}

/// Recommendation fake whose home shelves wait for [gate] (loading state).
class GatedRecommendations extends FakeRecommendationService {
  final gate = Completer<void>();

  @override
  Future<List<Shelf>> homeShelves({CancelToken? cancel}) async {
    await gate.future;
    return super.homeShelves(cancel: cancel);
  }
}

/// File dialogs answered from fields.
class FakePageFilePicker implements PageFilePicker {
  String? directory;
  String? audioFile;
  String? image;
  String? playlistFile;
  String exportPath = '/exports/out.m3u8';
  bool cancelExport = false;
  final calls = <String>[];

  @override
  Future<String?> pickDirectory({String? title}) async {
    calls.add('pickDirectory');
    return directory;
  }

  @override
  Future<String?> pickAudioFile({String? title}) async {
    calls.add('pickAudioFile');
    return audioFile;
  }

  @override
  Future<String?> pickImage({String? title}) async {
    calls.add('pickImage');
    return image;
  }

  @override
  Future<String?> pickPlaylistFile({String? title}) async {
    calls.add('pickPlaylistFile');
    return playlistFile;
  }

  @override
  Future<String?> exportFile({required String fileName, required Future<void> Function(String path) write, String? title}) async {
    calls.add('exportFile:$fileName');
    if (cancelExport) return null;
    await write(exportPath);
    return exportPath;
  }
}

/// Artwork store that records copies.
class FakeArtworkStore implements PlaylistArtworkStore {
  final stored = <(String, String)>[];

  @override
  Future<Uri> store(String playlistId, String sourcePath) async {
    stored.add((playlistId, sourcePath));
    return Uri.parse('file:///support/playlist_artwork/$playlistId.jpg');
  }
}

/// A copy of [kit]'s services with some replaced.
AppServices servicesWith(
  FakeKit kit, {
  TrackRepository? tracks,
  PlaylistRepository? playlists,
  LocalLibraryService? localLibrary,
  HistoryRepository? history,
  DownloadManager? downloads,
  RecommendationService? recommendations,
}) {
  final s = kit.services;
  return AppServices(
    platform: s.platform,
    paths: s.paths,
    settings: s.settings,
    http: s.http,
    libraryChanges: s.libraryChanges,
    tracks: tracks ?? s.tracks,
    playlists: playlists ?? s.playlists,
    favorites: s.favorites,
    history: history ?? s.history,
    links: s.links,
    searchHistory: s.searchHistory,
    localLibrary: localLibrary ?? s.localLibrary,
    maintenance: s.maintenance,
    tokens: s.tokens,
    credentials: s.credentials,
    oauth: s.oauth,
    sources: s.sources,
    streamResolver: s.streamResolver,
    playback: s.playback,
    downloads: downloads ?? s.downloads,
    scorer: s.scorer,
    matcher: s.matcher,
    imports: s.imports,
    lyrics: s.lyrics,
    recommendations: recommendations ?? s.recommendations,
    lifecycle: s.lifecycle,
    startup: s.startup,
    hotkeys: s.hotkeys,
    androidSystem: s.androidSystem,
    notifier: s.notifier,
  );
}

/// Pumps the app on [route] with page-level test doubles.
Future<FakeKit> pumpPage(
  WidgetTester tester, {
  required FakeKit kit,
  required String route,
  Size size = TestSizes.expanded,
  AppServices? services,
  FakePageFilePicker? picker,
  FakeArtworkStore? artwork,
  DateTime? now,
  List<Override> overrides = const [],
}) =>
    pumpFermata(
      tester,
      kit: kit,
      services: services,
      initialRoute: route,
      size: size,
      overrides: [
        pageFilePickerProvider.overrideWithValue(picker ?? FakePageFilePicker()),
        playlistArtworkStoreProvider.overrideWithValue(artwork ?? FakeArtworkStore()),
        pageClockProvider.overrideWithValue(() => now ?? testNow),
        ...overrides,
      ],
    );

/// Pumps a short burst of frames (state changes / toasts).
Future<void> settle(WidgetTester tester, {int count = 8}) => pumpFrames(tester, count: count);

/// Finds a widget by its [ValueKey] string.
Finder byKey(String key) => find.byKey(ValueKey(key));
