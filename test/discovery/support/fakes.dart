import 'dart:async';

import 'package:fermata/core/contracts/library.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/settings/settings_store.dart';

// ---------------------------------------------------------------------------
// Track helpers
// ---------------------------------------------------------------------------

const fullRights = TrackAvailability(playback: PlaybackRights.full, offline: OfflineRights.streamOnly);
const previewRights = TrackAvailability(playback: PlaybackRights.preview, offline: OfflineRights.unavailable);

Track tr(
  String source,
  String id, {
  String? title,
  required String artist,
  String? artistId,
  String? genre,
  int seconds = 200,
  TrackAvailability? availability,
  String? localPath,
  String? album,
  Uri? artwork,
}) =>
    Track(
      sourceId: source,
      sourceTrackId: id,
      title: title ?? 'Song $id',
      artists: [ArtistRef(artist, sourceArtistId: artistId)],
      genre: genre,
      duration: Duration(seconds: seconds),
      album: album,
      artworkUrl: artwork,
      localPath: source == SourceIds.local ? (localPath ?? '/music/$id.mp3') : localPath,
      availability: availability ??
          (source == SourceIds.local
              ? const TrackAvailability.local()
              : source == SourceIds.deezer
                  ? previewRights
                  : fullRights),
    );

Artist ar(String source, String id, String name) => Artist(sourceId: source, sourceArtistId: id, name: name);

// ---------------------------------------------------------------------------
// Sources
// ---------------------------------------------------------------------------

/// Scriptable in-memory [MusicSource] that counts calls.
class FakeSource extends MusicSource {
  FakeSource(
    this.id, {
    Set<SourceCapability>? capabilities,
    this.ready = true,
  }) : capabilities = capabilities ??
            const {
              SourceCapability.searchTracks,
              SourceCapability.searchArtists,
              SourceCapability.stream,
              SourceCapability.relatedTracks,
              SourceCapability.trending,
              SourceCapability.artistPages,
              SourceCapability.albumPages,
              SourceCapability.genres,
              SourceCapability.newReleases,
            };

  /// Metadata/preview-only source like Deezer.
  FakeSource.metadata(this.id, {this.ready = true})
      : capabilities = const {
          SourceCapability.searchTracks,
          SourceCapability.searchArtists,
          SourceCapability.previewOnly,
          SourceCapability.externalPlayback,
          SourceCapability.relatedTracks,
          SourceCapability.trending,
          SourceCapability.artistPages,
          SourceCapability.albumPages,
          SourceCapability.genres,
          SourceCapability.newReleases,
        };

  @override
  final String id;
  @override
  final Set<SourceCapability> capabilities;
  bool ready;

  /// Every call throws this when set (source "down").
  Object? failWith;

  final List<Track> catalog = [];
  final List<Artist> artistIndex = [];
  final Map<String, List<Track>> related = {};
  final Map<String, List<Track>> topTracks = {};
  final Map<String, List<Artist>> relatedArtistsMap = {};
  final List<Track> trendingList = [];
  final Map<String, List<Track>> trendingByGenre = {};
  final List<Album> releases = [];
  final Map<String, List<Track>> albums = {};
  final List<String> genreList = [];

  final Map<String, int> calls = {};

  int get totalCalls => calls.values.fold(0, (a, b) => a + b);

  void _hit(String op) {
    calls[op] = (calls[op] ?? 0) + 1;
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  String get displayName => id;
  @override
  String get limitationsNote => '';
  @override
  Uri? get termsUrl => null;
  @override
  Future<void> init() async {}
  @override
  CredentialStatus get credentialStatus => const CredentialStatus.notNeeded();
  @override
  SourceAuthState get authState => const SourceAuthState.notRequired();
  @override
  Stream<SourceAuthState> get authStateChanges => const Stream.empty();
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  bool get isReady => ready;

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    _hit('searchTracks');
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final hits = catalog.where((t) {
      final hay = '${t.artistLine} ${t.title} ${t.genre ?? ''}'.toLowerCase();
      return words.every(hay.contains);
    }).take(limit);
    return Page(hits.toList());
  }

  @override
  Future<Page<Artist>> searchArtists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    _hit('searchArtists');
    final q = query.toLowerCase();
    return Page(artistIndex.where((a) => a.name.toLowerCase().contains(q)).take(limit).toList());
  }

  @override
  Future<Page<Album>> searchAlbums(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async =>
      const Page.empty();

  @override
  Future<Page<Playlist>> searchPlaylists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async =>
      const Page.empty();

  @override
  Future<Track?> getTrack(String sourceTrackId, {CancelToken? cancel}) async =>
      catalog.where((t) => t.sourceTrackId == sourceTrackId).firstOrNull;

  @override
  Future<Artist?> getArtist(String sourceArtistId, {CancelToken? cancel}) async =>
      artistIndex.where((a) => a.sourceArtistId == sourceArtistId).firstOrNull;

  @override
  Future<Page<Track>> artistTopTracks(String sourceArtistId, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    _hit('artistTopTracks');
    return Page((topTracks[sourceArtistId] ?? const []).take(limit).toList());
  }

  @override
  Future<List<Artist>> relatedArtists(String sourceArtistId, {int limit = 12, CancelToken? cancel}) async {
    _hit('relatedArtists');
    return (relatedArtistsMap[sourceArtistId] ?? const []).take(limit).toList();
  }

  @override
  Future<Page<Track>> albumTracks(String sourceAlbumId, {String? cursor, CancelToken? cancel}) async {
    _hit('albumTracks');
    return Page(albums[sourceAlbumId] ?? const []);
  }

  @override
  Future<PlaylistDetail> getPlaylist(String idOrUrl, {String? cursor, CancelToken? cancel}) =>
      throw UnsupportedSourceOperation(id, 'getPlaylist', 'fake');

  @override
  Future<List<Track>> relatedTracks(String sourceTrackId, {int limit = 20, CancelToken? cancel}) async {
    _hit('relatedTracks');
    return (related[sourceTrackId] ?? const []).take(limit).toList();
  }

  @override
  Future<List<Track>> trending({String? genre, int limit = 30, CancelToken? cancel}) async {
    _hit('trending');
    if (genre != null) {
      final l = trendingByGenre[genre];
      if (l == null) throw UnsupportedSourceOperation(id, 'trending', 'no genre $genre');
      return l.take(limit).toList();
    }
    return trendingList.take(limit).toList();
  }

  @override
  Future<List<Album>> newReleases({int limit = 20, CancelToken? cancel}) async {
    _hit('newReleases');
    return releases.take(limit).toList();
  }

  @override
  Future<List<String>> genres({CancelToken? cancel}) async {
    _hit('genres');
    return genreList;
  }

  @override
  Future<Track?> lookupByIsrc(String isrc, {CancelToken? cancel}) async => null;
  @override
  Future<List<Playlist>> userPlaylists({CancelToken? cancel}) async => const [];
  @override
  Future<Page<Track>> userLikedTracks({String? cursor, CancelToken? cancel}) async => const Page.empty();
  @override
  Future<PlayableSource> resolveStream(Track track, {AudioQuality quality = AudioQuality.high, CancelToken? cancel}) =>
      throw UnsupportedSourceOperation(id, 'resolveStream', 'fake');
  @override
  Uri? externalPlaybackUri(Track track) => null;
  @override
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel}) async => null;
  @override
  Future<void> dispose() async {}
}

/// Registry honouring `services.disabledSources` from [settings].
class FakeRegistry implements SourceRegistry {
  FakeRegistry(this.settings, [List<MusicSource> sources = const []]) {
    _sources.addAll(sources);
  }

  final SettingsStore settings;
  final List<MusicSource> _sources = [];

  @override
  List<MusicSource> get all => List.unmodifiable(_sources);

  @override
  List<MusicSource> get ordered {
    final order = settings.current.services.providerOrder;
    final disabled = settings.current.services.disabledSources;
    final list = _sources.where((s) => !disabled.contains(s.id)).toList()
      ..sort((a, b) {
        final ia = order.indexOf(a.id), ib = order.indexOf(b.id);
        return (ia < 0 ? 999 : ia).compareTo(ib < 0 ? 999 : ib);
      });
    return list;
  }

  @override
  MusicSource? byId(String id) => _sources.where((s) => s.id == id).firstOrNull;

  @override
  MusicSource require(String id) => byId(id)!;

  @override
  void register(MusicSource source) => _sources.add(source);

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Stream<SourceSearchResults> searchAll(String query,
          {Set<SearchType> types = const {SearchType.tracks}, Set<String>? onlySources, CancelToken? cancel}) =>
      const Stream.empty();
}

// ---------------------------------------------------------------------------
// Library
// ---------------------------------------------------------------------------

String _fold(String s) => s.toLowerCase().trim();

class FakeTracks implements TrackRepository {
  /// In "date added" order (oldest first).
  final List<Track> items = [];
  int reads = 0;

  @override
  Future<void> upsertTracks(List<Track> tracks) async {
    for (final t in tracks) {
      items.removeWhere((e) => e.id == t.id);
      items.add(t);
    }
  }

  @override
  Future<Track?> getTrack(String id) async => items.where((t) => t.id == id).firstOrNull;

  @override
  Future<List<Track>> getTracks(List<String> ids) async {
    reads++;
    return [for (final id in ids) ?items.where((t) => t.id == id).firstOrNull];
  }

  @override
  Future<List<Track>> query(TrackQuery q) async {
    reads++;
    var list = items.where((t) {
      if (q.sourceIds != null && !q.sourceIds!.contains(t.sourceId)) return false;
      if (q.localFilesOnly && !(t.isLocal && t.localPath != null)) return false;
      if (q.artist != null && _fold(t.primaryArtist) != _fold(q.artist!)) return false;
      if (q.genre != null && _fold(t.genre ?? '') != _fold(q.genre!)) return false;
      return true;
    }).toList();
    if (q.sort == TrackSortField.dateAdded && q.descending) list = list.reversed.toList();
    if (q.limit != null) list = list.take(q.limit!).toList();
    return list;
  }

  @override
  Future<int> count(TrackQuery query) async => (await this.query(query)).length;
  @override
  Future<void> removeTracks(List<String> ids) async => items.removeWhere((t) => ids.contains(t.id));
  @override
  Future<List<AlbumSummary>> albums({String? artist, String? text}) async => const [];
  @override
  Future<List<ArtistSummary>> artists({String? text}) async => const [];
  @override
  Future<List<String>> genres() async => {for (final t in items) ?t.genre}.toList();
  @override
  Future<List<DuplicateGroup>> findDuplicates() async => const [];
  @override
  Future<List<Track>> findMissingFiles() async => const [];
}

class FakeHistory implements HistoryRepository {
  final List<PlayRecord> records = [];
  int reads = 0;

  void play(Track t, DateTime at, {Duration? listened, bool completed = true}) => records.add(PlayRecord(
        track: t,
        playedAt: at,
        listened: listened ?? t.duration ?? const Duration(minutes: 3),
        completed: completed,
      ));

  @override
  Future<void> recordPlay(PlayRecord record) async => records.add(record);

  @override
  Future<List<PlayRecord>> history({int limit = 200, DateTime? before}) async {
    reads++;
    final sorted = [...records]..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<Track>> recentlyPlayed({int limit = 30}) async {
    reads++;
    final sorted = [...records]..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    final seen = <String>{};
    return [for (final r in sorted) if (seen.add(r.track.id)) r.track].take(limit).toList();
  }

  @override
  Future<ListeningStats> stats({DateTime? since}) async => throw UnimplementedError();
  @override
  Future<int> playCount(String trackId) async => records.where((r) => r.track.id == trackId).length;
  @override
  Future<void> clearHistory() async => records.clear();
}

class FakeFavorites implements FavoritesRepository {
  final List<Track> items = [];
  int reads = 0;

  @override
  Future<bool> isFavorite(String trackId) async => items.any((t) => t.id == trackId);

  @override
  Future<void> setFavorite(Track track, bool favorite) async {
    items.removeWhere((t) => t.id == track.id);
    if (favorite) items.add(track);
  }

  @override
  Future<List<Track>> favorites() async {
    reads++;
    return [...items];
  }

  @override
  Stream<Set<String>> watchFavoriteIds() => const Stream.empty();
}

/// Throws for every call (a broken library/database).
class ThrowingHistory extends FakeHistory {
  @override
  Future<List<PlayRecord>> history({int limit = 200, DateTime? before}) async =>
      throw const StorageException('db', 'broken');

  @override
  Future<List<Track>> recentlyPlayed({int limit = 30}) async => throw const StorageException('db', 'broken');
}

/// Completes after [delay] — for cancellation tests.
Future<T> later<T>(Duration delay, T value) => Future.delayed(delay, () => value);

/// A cancel token canceled after [delay].
CancelToken cancelAfter(Duration delay) {
  final t = CancelToken();
  Timer(delay, t.cancel);
  return t;
}
