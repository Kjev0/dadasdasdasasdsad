import 'dart:async';

import 'package:fermata/core/contracts/library.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';

/// Change bus whose events tests can trigger with [emit].
class FakeLibraryChangeBus implements LibraryChangeBus {
  final _ctl = StreamController<Set<LibraryTopic>>.broadcast();

  void emit(Set<LibraryTopic> topics) => _ctl.add(topics);

  @override
  Stream<Set<LibraryTopic>> get changes => _ctl.stream;
}

/// Base for fakes that record calls and can be told to fail.
mixin FakeCallLog {
  final calls = <String>[];

  /// method name → error thrown on its next call.
  final throwOn = <String, Object>{};

  void record(String method) {
    calls.add(method);
    final e = throwOn.remove(method);
    if (e != null) throw e;
  }

  bool called(String method) => calls.contains(method);
}

/// In-memory track store with simple text search.
class FakeTrackRepository with FakeCallLog implements TrackRepository {
  FakeTrackRepository(this._bus, [List<Track> initial = const []]) {
    for (final t in initial) {
      _tracks[t.id] = t;
    }
  }

  final FakeLibraryChangeBus _bus;
  final _tracks = <String, Track>{};

  List<Track> get all => _tracks.values.toList();

  @override
  Future<void> upsertTracks(List<Track> tracks) async {
    record('upsertTracks');
    for (final t in tracks) {
      _tracks[t.id] = t;
    }
    _bus.emit({LibraryTopic.tracks});
  }

  @override
  Future<Track?> getTrack(String id) async {
    record('getTrack');
    return _tracks[id];
  }

  @override
  Future<List<Track>> getTracks(List<String> ids) async {
    record('getTracks');
    return [for (final id in ids) ?_tracks[id]];
  }

  bool _matches(Track t, TrackQuery q) {
    final text = q.text?.trim().toLowerCase();
    if (text != null && text.isNotEmpty) {
      final hay = '${t.title} ${t.artistLine} ${t.album ?? ''}'.toLowerCase();
      if (!hay.contains(text)) return false;
    }
    if (q.sourceIds != null && !q.sourceIds!.contains(t.sourceId)) return false;
    if (q.localFilesOnly && !t.isLocal) return false;
    if (q.artist != null && t.primaryArtist != q.artist) return false;
    if (q.album != null && t.album != q.album) return false;
    if (q.genre != null && t.genre != q.genre) return false;
    return true;
  }

  @override
  Future<List<Track>> query(TrackQuery query) async {
    record('query');
    var result = _tracks.values.where((t) => _matches(t, query)).skip(query.offset).toList();
    if (query.limit != null && result.length > query.limit!) result = result.sublist(0, query.limit!);
    return result;
  }

  @override
  Future<int> count(TrackQuery query) async {
    record('count');
    return _tracks.values.where((t) => _matches(t, query)).length;
  }

  @override
  Future<void> removeTracks(List<String> ids) async {
    record('removeTracks');
    ids.forEach(_tracks.remove);
    _bus.emit({LibraryTopic.tracks});
  }

  @override
  Future<List<AlbumSummary>> albums({String? artist, String? text}) async {
    record('albums');
    final byAlbum = <String, List<Track>>{};
    for (final t in _tracks.values) {
      if (t.album == null) continue;
      if (artist != null && t.primaryArtist != artist) continue;
      byAlbum.putIfAbsent(t.album!, () => []).add(t);
    }
    return [
      for (final e in byAlbum.entries)
        AlbumSummary(title: e.key, artist: e.value.first.primaryArtist, trackCount: e.value.length),
    ];
  }

  @override
  Future<List<ArtistSummary>> artists({String? text}) async {
    record('artists');
    final counts = <String, int>{};
    for (final t in _tracks.values) {
      counts[t.primaryArtist] = (counts[t.primaryArtist] ?? 0) + 1;
    }
    return [for (final e in counts.entries) ArtistSummary(name: e.key, trackCount: e.value)];
  }

  @override
  Future<List<String>> genres() async {
    record('genres');
    return {for (final t in _tracks.values) ?t.genre}.toList();
  }

  @override
  Future<List<DuplicateGroup>> findDuplicates() async {
    record('findDuplicates');
    return const [];
  }

  @override
  Future<List<Track>> findMissingFiles() async {
    record('findMissingFiles');
    return const [];
  }
}

/// In-memory playlists (track ids resolved through [FakeTrackRepository]).
class FakePlaylistRepository with FakeCallLog implements PlaylistRepository {
  FakePlaylistRepository(this._bus, this._tracks);

  final FakeLibraryChangeBus _bus;
  final FakeTrackRepository _tracks;
  final _playlists = <Playlist>[];
  final entries = <String, List<String>>{};
  int _next = 1;

  /// Adds a playlist directly (test setup).
  Playlist add(Playlist p, {List<String> trackIds = const []}) {
    _playlists.add(p);
    entries[p.id] = [...trackIds];
    return p;
  }

  Playlist _withCount(Playlist p) => p.copyWith(trackCount: entries[p.id]?.length ?? 0);

  void _changed() => _bus.emit({LibraryTopic.playlists});

  @override
  Future<List<Playlist>> playlists() async {
    record('playlists');
    return [for (final p in _playlists) _withCount(p)];
  }

  @override
  Future<Playlist?> getPlaylist(String id) async {
    record('getPlaylist');
    final p = _playlists.where((p) => p.id == id).firstOrNull;
    return p == null ? null : _withCount(p);
  }

  @override
  Future<Playlist> createPlaylist(String name, {String? description, String? sourceId, String? sourcePlaylistId, Uri? artworkUrl}) async {
    record('createPlaylist');
    final p = add(Playlist(id: 'pl${_next++}', name: name, kind: PlaylistKind.local, description: description, sourceId: sourceId, sourcePlaylistId: sourcePlaylistId, artworkUrl: artworkUrl, createdAt: DateTime(2026)));
    _changed();
    return p;
  }

  @override
  Future<Playlist> createSmartPlaylist(String name, SmartPlaylistRules rules, {String? description}) async {
    record('createSmartPlaylist');
    final p = add(Playlist(id: 'pl${_next++}', name: name, kind: PlaylistKind.smart, description: description));
    _changed();
    return p;
  }

  @override
  Future<void> updatePlaylist(Playlist playlist) async {
    record('updatePlaylist');
    final i = _playlists.indexWhere((p) => p.id == playlist.id);
    if (i >= 0) _playlists[i] = playlist;
    _changed();
  }

  @override
  Future<void> deletePlaylist(String id) async {
    record('deletePlaylist');
    _playlists.removeWhere((p) => p.id == id);
    entries.remove(id);
    _changed();
  }

  @override
  Future<List<String>> playlistTrackIds(String id) async {
    record('playlistTrackIds');
    return [...?entries[id]];
  }

  @override
  Future<List<Track>> playlistTracks(String id) async {
    record('playlistTracks');
    return _tracks.getTracks(entries[id] ?? const []);
  }

  @override
  Future<void> addTracks(String playlistId, List<String> trackIds, {int? position}) async {
    record('addTracks');
    final list = entries.putIfAbsent(playlistId, () => []);
    list.insertAll((position ?? list.length).clamp(0, list.length), trackIds);
    _changed();
  }

  @override
  Future<void> removeAt(String playlistId, List<int> positions) async {
    record('removeAt');
    final list = entries[playlistId];
    if (list == null) return;
    for (final p in [...positions]..sort((a, b) => b.compareTo(a))) {
      if (p >= 0 && p < list.length) list.removeAt(p);
    }
    _changed();
  }

  @override
  Future<void> removeTracks(String playlistId, List<String> trackIds) async {
    record('removeTracks');
    entries[playlistId]?.removeWhere(trackIds.contains);
    _changed();
  }

  @override
  Future<void> move(String playlistId, int from, int to) async {
    record('move');
    final list = entries[playlistId];
    if (list == null) return;
    final id = list.removeAt(from);
    list.insert(to.clamp(0, list.length), id);
    _changed();
  }

  @override
  Future<int> deduplicate(String playlistId) async {
    record('deduplicate');
    final list = entries[playlistId];
    if (list == null) return 0;
    final before = list.length;
    final seen = <String>{};
    list.retainWhere(seen.add);
    _changed();
    return before - list.length;
  }

  @override
  Future<List<Playlist>> autoDownloadPlaylists() async {
    record('autoDownloadPlaylists');
    return [for (final p in _playlists) if (p.autoDownload) p];
  }
}

class FakeFavoritesRepository with FakeCallLog implements FavoritesRepository {
  FakeFavoritesRepository(this._bus, this._tracks);

  final FakeLibraryChangeBus _bus;
  final FakeTrackRepository _tracks;
  final ids = <String>{};
  final _ctl = StreamController<Set<String>>.broadcast();

  @override
  Future<bool> isFavorite(String trackId) async {
    record('isFavorite');
    return ids.contains(trackId);
  }

  @override
  Future<void> setFavorite(Track track, bool favorite) async {
    record('setFavorite');
    await _tracks.upsertTracks([track]);
    favorite ? ids.add(track.id) : ids.remove(track.id);
    _ctl.add(Set.of(ids));
    _bus.emit({LibraryTopic.favorites});
  }

  @override
  Future<List<Track>> favorites() async {
    record('favorites');
    return _tracks.getTracks(ids.toList());
  }

  @override
  Stream<Set<String>> watchFavoriteIds() async* {
    yield Set.of(ids);
    yield* _ctl.stream;
  }
}

class FakeHistoryRepository with FakeCallLog implements HistoryRepository {
  final records = <PlayRecord>[];

  @override
  Future<void> recordPlay(PlayRecord record) async {
    this.record('recordPlay');
    records.insert(0, record);
  }

  @override
  Future<List<PlayRecord>> history({int limit = 200, DateTime? before}) async {
    record('history');
    return records.where((r) => before == null || r.playedAt.isBefore(before)).take(limit).toList();
  }

  @override
  Future<List<Track>> recentlyPlayed({int limit = 30}) async {
    record('recentlyPlayed');
    final seen = <String>{};
    return [for (final r in records) if (seen.add(r.track.id)) r.track].take(limit).toList();
  }

  @override
  Future<ListeningStats> stats({DateTime? since}) async {
    record('stats');
    final list = records.where((r) => since == null || r.playedAt.isAfter(since)).toList();
    return ListeningStats(
      totalPlays: list.length,
      totalListened: list.fold(Duration.zero, (s, r) => s + r.listened),
      topTracks: const [],
      topArtists: const [],
      topGenres: const [],
      playsPerDay: const {},
    );
  }

  @override
  Future<int> playCount(String trackId) async {
    record('playCount');
    return records.where((r) => r.track.id == trackId).length;
  }

  @override
  Future<void> clearHistory() async {
    record('clearHistory');
    records.clear();
  }
}

class FakeTrackLinkRepository with FakeCallLog implements TrackLinkRepository {
  FakeTrackLinkRepository(this._tracks);

  final FakeTrackRepository _tracks;
  final links = <TrackLink>[];

  @override
  Future<void> link(String trackId, String linkedTrackId, {required double confidence, bool userConfirmed = false}) async {
    record('link');
    links.add(TrackLink(trackId: trackId, linkedTrackId: linkedTrackId, confidence: confidence, userConfirmed: userConfirmed, createdAt: DateTime(2026)));
  }

  @override
  Future<void> unlink(String trackId, String linkedTrackId) async {
    record('unlink');
    links.removeWhere((l) =>
        (l.trackId == trackId && l.linkedTrackId == linkedTrackId) || (l.trackId == linkedTrackId && l.linkedTrackId == trackId));
  }

  @override
  Future<List<(Track, TrackLink)>> linkedTracks(String trackId) async {
    record('linkedTracks');
    final result = <(Track, TrackLink)>[];
    for (final l in links) {
      final other = l.trackId == trackId ? l.linkedTrackId : (l.linkedTrackId == trackId ? l.trackId : null);
      if (other == null) continue;
      final t = await _tracks.getTrack(other);
      if (t != null) result.add((t, l));
    }
    return result;
  }
}

class FakeSearchHistoryRepository with FakeCallLog implements SearchHistoryRepository {
  final queries = <String>[];

  @override
  Future<void> add(String query) async {
    record('add');
    queries
      ..remove(query)
      ..insert(0, query);
  }

  @override
  Future<List<String>> recent({int limit = 12}) async {
    record('recent');
    return queries.take(limit).toList();
  }

  @override
  Future<void> remove(String query) async {
    record('remove');
    queries.remove(query);
  }

  @override
  Future<void> clear() async {
    record('clear');
    queries.clear();
  }
}

class FakeLocalLibraryService with FakeCallLog implements LocalLibraryService {
  final folderList = <LibraryFolder>[];

  @override
  bool supportsFileTagWriting = true;

  @override
  Future<List<LibraryFolder>> folders() async {
    record('folders');
    return [...folderList];
  }

  @override
  Future<void> addFolder(String path, {bool watch = true}) async {
    record('addFolder');
    folderList.add(LibraryFolder(path: path, watch: watch));
  }

  @override
  Future<void> removeFolder(String path, {bool removeTracks = true}) async {
    record('removeFolder');
    folderList.removeWhere((f) => f.path == path);
  }

  @override
  Stream<ScanProgress> scan({String? folder, bool full = false}) async* {
    record('scan');
    yield const ScanProgress(scannedFiles: 0, totalFiles: 0, added: 0, updated: 0, removed: 0, done: true);
  }

  @override
  Future<void> startWatching() async => record('startWatching');

  @override
  Future<void> stopWatching() async => record('stopWatching');

  @override
  Future<Track?> importFile(String path) async {
    record('importFile');
    return null;
  }

  @override
  Future<bool> editTags(Track track, Track edited) async {
    record('editTags');
    return supportsFileTagWriting;
  }

  @override
  Future<List<Track>> importM3u(String path) async {
    record('importM3u');
    return const [];
  }

  @override
  Future<void> exportM3u(String playlistId, String path, {bool extended = true}) async => record('exportM3u');
}

class FakeLibraryMaintenance with FakeCallLog implements LibraryMaintenance {
  Map<String, Object?> backup = const {'version': 1};

  @override
  Future<void> deleteAllUserData() async => record('deleteAllUserData');

  @override
  Future<Map<String, Object?>> exportBackup() async {
    record('exportBackup');
    return backup;
  }

  @override
  Future<void> importBackup(Map<String, Object?> backup, {bool merge = true}) async {
    record('importBackup');
    this.backup = backup;
  }

  @override
  Future<int> databaseSizeBytes() async {
    record('databaseSizeBytes');
    return 4096;
  }
}
