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
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/matching/normalizer.dart';

/// Builds a track with sensible test defaults.
Track track(
  String source,
  String id,
  String title,
  List<String> artists, {
  String? album,
  int? seconds,
  String? isrc,
  bool? explicit,
  int? year,
  PlaybackRights playback = PlaybackRights.full,
}) =>
    Track(
      sourceId: source,
      sourceTrackId: id,
      title: title,
      artists: [for (final a in artists) ArtistRef(a)],
      album: album,
      duration: seconds == null ? null : Duration(seconds: seconds),
      isrc: isrc,
      explicit: explicit,
      year: year,
      availability: TrackAvailability(playback: playback, offline: OfflineRights.streamOnly),
    );

/// A scriptable in-memory [MusicSource].
///
/// Search returns catalog tracks sharing at least one normalized token
/// with the query (a crude but realistic text search). Errors, rate limits
/// and latency can be injected.
class FakeSource implements MusicSource {
  FakeSource(
    this.id, {
    List<Track> catalog = const [],
    Set<SourceCapability>? capabilities,
    this.ready = true,
    this.latency = Duration.zero,
  })  : catalog = [...catalog],
        capabilities = capabilities ??
            {SourceCapability.searchTracks, SourceCapability.isrcLookup, SourceCapability.playlistImport};

  @override
  final String id;

  final List<Track> catalog;

  @override
  final Set<SourceCapability> capabilities;

  bool ready;
  Duration latency;

  /// Thrown by every search (if set).
  Object? searchError;

  /// Thrown by every ISRC lookup (if set).
  Object? isrcError;

  /// The next N requests (search or ISRC) throw [RateLimitedException].
  int rateLimitTimes = 0;
  Duration? rateLimitRetryAfter = const Duration(milliseconds: 5);

  /// Playlists served by [getPlaylist]: id → tracks, paged by [pageSize].
  final Map<String, (Playlist, List<Track>)> playlists = {};
  int pageSize = 2;
  Object? playlistError;

  final List<String> queries = [];
  int isrcCalls = 0;
  int playlistCalls = 0;
  int _inFlight = 0;
  int maxInFlight = 0;

  int get searchCalls => queries.length;

  Future<T> _request<T>(CancelToken? cancel, T Function() body) async {
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      if (latency > Duration.zero) {
        await Future.any([Future<void>.delayed(latency), if (cancel != null) cancel.whenCanceled]);
      }
      cancel?.throwIfCanceled();
      if (rateLimitTimes > 0) {
        rateLimitTimes--;
        throw RateLimitedException('slow down', retryAfter: rateLimitRetryAfter);
      }
      return body();
    } finally {
      _inFlight--;
    }
  }

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) {
    queries.add(query);
    return _request(cancel, () {
      if (searchError != null) throw searchError!;
      final q = TextKeys.title(query).tokens.toSet();
      final hits = catalog.where((t) {
        final hay = {
          ...TextKeys.title(t.title).tokens,
          for (final a in t.artists) ...TextKeys.title(a.name).tokens,
        };
        return q.any(hay.contains);
      }).take(limit);
      return Page(hits.toList());
    });
  }

  @override
  Future<Track?> lookupByIsrc(String isrc, {CancelToken? cancel}) {
    isrcCalls++;
    return _request(cancel, () {
      if (isrcError != null) throw isrcError!;
      final wanted = TrackNormalizer.normalizeIsrc(isrc);
      for (final t in catalog) {
        if (TrackNormalizer.normalizeIsrc(t.isrc) == wanted) return t;
      }
      return null;
    });
  }

  @override
  Future<PlaylistDetail> getPlaylist(String idOrUrl, {String? cursor, CancelToken? cancel}) async {
    playlistCalls++;
    if (playlistError != null) throw playlistError!;
    final entry = playlists[idOrUrl];
    if (entry == null) throw ApiException(404, 'no playlist $idOrUrl');
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, entry.$2.length);
    return PlaylistDetail(
      playlist: entry.$1,
      tracks: Page(entry.$2.sublist(start, end), nextCursor: end < entry.$2.length ? '$end' : null),
    );
  }

  // ---- Boilerplate -------------------------------------------------------

  @override
  bool supports(SourceCapability c) => capabilities.contains(c);

  @override
  String get displayName => 'Fake $id';

  @override
  String get limitationsNote => 'Test double';

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

  Never _unsupported(String op) => throw UnsupportedSourceOperation(id, op, 'not in fake');

  @override
  Future<Page<Artist>> searchArtists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) =>
      _unsupported('searchArtists');

  @override
  Future<Page<Album>> searchAlbums(String query, {String? cursor, int limit = 20, CancelToken? cancel}) =>
      _unsupported('searchAlbums');

  @override
  Future<Page<Playlist>> searchPlaylists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) =>
      _unsupported('searchPlaylists');

  @override
  Future<Track?> getTrack(String sourceTrackId, {CancelToken? cancel}) async =>
      catalog.where((t) => t.sourceTrackId == sourceTrackId).firstOrNull;

  @override
  Future<Artist?> getArtist(String sourceArtistId, {CancelToken? cancel}) => _unsupported('getArtist');

  @override
  Future<Page<Track>> artistTopTracks(String sourceArtistId, {String? cursor, int limit = 30, CancelToken? cancel}) =>
      _unsupported('artistTopTracks');

  @override
  Future<List<Artist>> relatedArtists(String sourceArtistId, {int limit = 12, CancelToken? cancel}) =>
      _unsupported('relatedArtists');

  @override
  Future<Page<Track>> albumTracks(String sourceAlbumId, {String? cursor, CancelToken? cancel}) =>
      _unsupported('albumTracks');

  @override
  Future<List<Track>> relatedTracks(String sourceTrackId, {int limit = 20, CancelToken? cancel}) =>
      _unsupported('relatedTracks');

  @override
  Future<List<Track>> trending({String? genre, int limit = 30, CancelToken? cancel}) => _unsupported('trending');

  @override
  Future<List<Album>> newReleases({int limit = 20, CancelToken? cancel}) => _unsupported('newReleases');

  @override
  Future<List<String>> genres({CancelToken? cancel}) => _unsupported('genres');

  @override
  Future<List<Playlist>> userPlaylists({CancelToken? cancel}) => _unsupported('userPlaylists');

  @override
  Future<Page<Track>> userLikedTracks({String? cursor, CancelToken? cancel}) => _unsupported('userLikedTracks');

  @override
  Future<PlayableSource> resolveStream(Track track, {AudioQuality quality = AudioQuality.high, CancelToken? cancel}) =>
      _unsupported('resolveStream');

  @override
  Uri? externalPlaybackUri(Track track) => null;

  @override
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel}) async => null;

  @override
  Future<void> dispose() async {}
}

class FakeRegistry implements SourceRegistry {
  FakeRegistry(List<MusicSource> sources) : _sources = [...sources];

  final List<MusicSource> _sources;

  @override
  List<MusicSource> get all => List.unmodifiable(_sources);

  @override
  List<MusicSource> get ordered => all;

  @override
  MusicSource? byId(String id) => _sources.where((s) => s.id == id).firstOrNull;

  @override
  MusicSource require(String id) => byId(id) ?? (throw StateError('no source $id'));

  @override
  void register(MusicSource source) => _sources.add(source);

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Stream<SourceSearchResults> searchAll(
    String query, {
    Set<SearchType> types = const {SearchType.tracks, SearchType.artists, SearchType.albums, SearchType.playlists},
    Set<String>? onlySources,
    CancelToken? cancel,
  }) =>
      throw UnimplementedError();
}

class InMemoryTrackRepository implements TrackRepository {
  final Map<String, Track> tracks = {};
  int upsertCalls = 0;

  @override
  Future<void> upsertTracks(List<Track> list) async {
    upsertCalls++;
    for (final t in list) {
      tracks[t.id] = t;
    }
  }

  @override
  Future<Track?> getTrack(String id) async => tracks[id];

  @override
  Future<List<Track>> getTracks(List<String> ids) async => [
        for (final id in ids)
          if (tracks[id] != null) tracks[id]!,
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class InMemoryPlaylistRepository implements PlaylistRepository {
  final Map<String, Playlist> byId = {};
  final Map<String, List<String>> entries = {};
  final List<String> deleted = [];
  int _next = 0;

  /// When > 0, the n-th addTracks call (1-based) throws.
  int failAddTracksOnCall = 0;
  int _addCalls = 0;

  @override
  Future<Playlist> createPlaylist(
    String name, {
    String? description,
    String? sourceId,
    String? sourcePlaylistId,
    Uri? artworkUrl,
  }) async {
    final p = Playlist(
      id: 'pl-${++_next}',
      name: name,
      kind: PlaylistKind.local,
      description: description,
      sourceId: sourceId,
      sourcePlaylistId: sourcePlaylistId,
      artworkUrl: artworkUrl,
    );
    byId[p.id] = p;
    entries[p.id] = [];
    return p;
  }

  @override
  Future<void> addTracks(String playlistId, List<String> trackIds, {int? position}) async {
    _addCalls++;
    if (_addCalls == failAddTracksOnCall) throw const StorageException('db_error', 'disk full');
    entries[playlistId]!.addAll(trackIds);
  }

  @override
  Future<List<String>> playlistTrackIds(String id) async => entries[id] ?? const [];

  @override
  Future<Playlist?> getPlaylist(String id) async => byId[id];

  @override
  Future<void> deletePlaylist(String id) async {
    deleted.add(id);
    byId.remove(id);
    entries.remove(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class InMemoryLinkRepository implements TrackLinkRepository {
  final List<TrackLink> links = [];

  @override
  Future<void> link(String trackId, String linkedTrackId, {required double confidence, bool userConfirmed = false}) async {
    links.add(TrackLink(
      trackId: trackId,
      linkedTrackId: linkedTrackId,
      confidence: confidence,
      userConfirmed: userConfirmed,
      createdAt: DateTime(2026),
    ));
  }

  TrackLink? linkFor(String trackId) => links.where((l) => l.trackId == trackId).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}
