import 'dart:async';

import 'package:fermata/core/contracts/auth.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';

/// Configurable in-memory [MusicSource]. Search matches [tracks] (and the
/// other lists) by case-insensitive substring. Set [searchError] /
/// [searchDelay] to test error and streaming behaviour.
class FakeMusicSource extends MusicSource {
  FakeMusicSource({
    required this.id,
    String? displayName,
    Set<SourceCapability>? capabilities,
    SourceAuthState authState = const SourceAuthState.notRequired(),
    this.credentialStatus = const CredentialStatus.notNeeded(),
    this.tracks = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
    this.limitationsNote = 'Test source.',
    this.termsUrl,
    this.externalBase,
    this.searchDelay = Duration.zero,
    this.searchError,
    this.ready = true,
  })  : displayName = displayName ?? id,
        capabilities = capabilities ??
            const {
              SourceCapability.searchTracks,
              SourceCapability.searchArtists,
              SourceCapability.searchAlbums,
              SourceCapability.searchPlaylists,
              SourceCapability.stream,
            },
        _auth = authState;

  @override
  final String id;

  @override
  final String displayName;

  @override
  final Set<SourceCapability> capabilities;

  @override
  final String limitationsNote;

  @override
  final Uri? termsUrl;

  @override
  CredentialStatus credentialStatus;

  List<Track> tracks;
  List<Artist> artists;
  List<Album> albums;
  List<Playlist> playlists;

  /// When set, `externalPlaybackUri` returns `<externalBase>/<sourceTrackId>`.
  Uri? externalBase;
  Duration searchDelay;
  Object? searchError;
  bool ready;

  /// Track ids whose download is authorized.
  final downloadable = <String>{};
  final calls = <String>[];

  SourceAuthState _auth;
  final _authCtl = StreamController<SourceAuthState>.broadcast();

  void setAuthState(SourceAuthState s) {
    _auth = s;
    _authCtl.add(s);
  }

  @override
  SourceAuthState get authState => _auth;

  @override
  Stream<SourceAuthState> get authStateChanges => _authCtl.stream;

  @override
  bool get isReady => ready;

  @override
  Future<void> init() async => calls.add('init');

  @override
  Future<void> connect() async {
    calls.add('connect');
    setAuthState(const SourceAuthState(status: SourceConnectionStatus.connected, accountName: 'Tester'));
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
    setAuthState(const SourceAuthState(status: SourceConnectionStatus.notConnected));
  }

  Future<void> _searchPrelude(CancelToken? cancel) async {
    if (searchDelay > Duration.zero) await Future<void>.delayed(searchDelay);
    cancel?.throwIfCanceled();
    if (searchError != null) throw searchError!;
  }

  bool _hit(String text, String q) => text.toLowerCase().contains(q.toLowerCase());

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    calls.add('searchTracks');
    await _searchPrelude(cancel);
    return Page([for (final t in tracks) if (_hit('${t.title} ${t.artistLine}', query)) t].take(limit).toList());
  }

  @override
  Future<Page<Artist>> searchArtists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    calls.add('searchArtists');
    await _searchPrelude(cancel);
    return Page([for (final a in artists) if (_hit(a.name, query)) a].take(limit).toList());
  }

  @override
  Future<Page<Album>> searchAlbums(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    calls.add('searchAlbums');
    await _searchPrelude(cancel);
    return Page([for (final a in albums) if (_hit(a.title, query)) a].take(limit).toList());
  }

  @override
  Future<Page<Playlist>> searchPlaylists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    calls.add('searchPlaylists');
    await _searchPrelude(cancel);
    return Page([for (final p in playlists) if (_hit(p.name, query)) p].take(limit).toList());
  }

  @override
  Future<Track?> getTrack(String sourceTrackId, {CancelToken? cancel}) async =>
      tracks.where((t) => t.sourceTrackId == sourceTrackId).firstOrNull;

  @override
  Future<Artist?> getArtist(String sourceArtistId, {CancelToken? cancel}) async =>
      artists.where((a) => a.sourceArtistId == sourceArtistId).firstOrNull;

  @override
  Future<Page<Track>> artistTopTracks(String sourceArtistId, {String? cursor, int limit = 30, CancelToken? cancel}) async =>
      Page([for (final t in tracks) if (t.artists.any((a) => a.sourceArtistId == sourceArtistId)) t]);

  @override
  Future<List<Artist>> relatedArtists(String sourceArtistId, {int limit = 12, CancelToken? cancel}) async =>
      artists.where((a) => a.sourceArtistId != sourceArtistId).take(limit).toList();

  @override
  Future<Page<Track>> albumTracks(String sourceAlbumId, {String? cursor, CancelToken? cancel}) async =>
      Page([for (final t in tracks) if (t.extra['albumId'] == sourceAlbumId) t]);

  @override
  Future<PlaylistDetail> getPlaylist(String idOrUrl, {String? cursor, CancelToken? cancel}) async {
    final p = playlists.where((p) => p.id == idOrUrl || p.sourcePlaylistId == idOrUrl).firstOrNull;
    if (p == null) throw ApiException(404, 'Playlist $idOrUrl not found');
    return PlaylistDetail(playlist: p, tracks: Page(tracks));
  }

  @override
  Future<List<Track>> relatedTracks(String sourceTrackId, {int limit = 20, CancelToken? cancel}) async =>
      tracks.where((t) => t.sourceTrackId != sourceTrackId).take(limit).toList();

  @override
  Future<List<Track>> trending({String? genre, int limit = 30, CancelToken? cancel}) async => tracks.take(limit).toList();

  @override
  Future<List<Album>> newReleases({int limit = 20, CancelToken? cancel}) async => albums.take(limit).toList();

  @override
  Future<List<String>> genres({CancelToken? cancel}) async => const ['Electronic', 'Jazz'];

  @override
  Future<Track?> lookupByIsrc(String isrc, {CancelToken? cancel}) async =>
      tracks.where((t) => t.isrc == isrc).firstOrNull;

  @override
  Future<List<Playlist>> userPlaylists({CancelToken? cancel}) async => playlists;

  @override
  Future<Page<Track>> userLikedTracks({String? cursor, CancelToken? cancel}) async => Page(tracks);

  @override
  Future<PlayableSource> resolveStream(Track track, {AudioQuality quality = AudioQuality.high, CancelToken? cancel}) async {
    if (!track.availability.isPlayableInApp) {
      throw UnplayableTrackException(track.id, track.availability.reason ?? AvailabilityReason.unknown);
    }
    return PlayableSource(uri: Uri.parse('https://stream.invalid/${track.sourceTrackId}'));
  }

  @override
  Uri? externalPlaybackUri(Track track) => externalBase?.resolve(track.sourceTrackId);

  @override
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel}) async =>
      downloadable.contains(track.id) ? DownloadAuthorization(uri: Uri.parse('https://download.invalid/${track.sourceTrackId}')) : null;

  @override
  Future<void> dispose() async => _authCtl.close();
}

/// Registry over [FakeMusicSource]s; `searchAll` emits per source as each
/// completes (respecting each source's `searchDelay`).
class FakeSourceRegistry implements SourceRegistry {
  FakeSourceRegistry([List<MusicSource> sources = const [], this.order]) : _sources = [...sources];

  final List<MusicSource> _sources;

  /// Preference order of ids; null = registration order.
  List<String>? order;
  final _changes = StreamController<void>.broadcast();

  void notifyChanged() => _changes.add(null);

  @override
  List<MusicSource> get all => List.unmodifiable(_sources);

  @override
  List<MusicSource> get ordered {
    if (order == null) return all;
    final list = [..._sources];
    int rank(MusicSource s) {
      final i = order!.indexOf(s.id);
      return i < 0 ? order!.length : i;
    }

    list.sort((a, b) => rank(a).compareTo(rank(b)));
    return list;
  }

  @override
  MusicSource? byId(String id) => _sources.where((s) => s.id == id).firstOrNull;

  @override
  MusicSource require(String id) => byId(id) ?? (throw StateError('Unknown source $id'));

  @override
  void register(MusicSource source) {
    _sources.add(source);
    notifyChanged();
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Stream<SourceSearchResults> searchAll(
    String query, {
    Set<SearchType> types = const {SearchType.tracks, SearchType.artists, SearchType.albums, SearchType.playlists},
    Set<String>? onlySources,
    CancelToken? cancel,
  }) {
    final ctl = StreamController<SourceSearchResults>();
    final targets = [
      for (final s in ordered)
        if (s.isReady && (onlySources == null || onlySources.contains(s.id))) s,
    ];
    var pending = targets.length;
    if (pending == 0) {
      ctl.close();
      return ctl.stream;
    }
    for (final s in targets) {
      () async {
        try {
          final tracks = types.contains(SearchType.tracks) ? await s.searchTracks(query, cancel: cancel) : const Page<Track>.empty();
          final artists = types.contains(SearchType.artists) ? await s.searchArtists(query, cancel: cancel) : const Page<Artist>.empty();
          final albums = types.contains(SearchType.albums) ? await s.searchAlbums(query, cancel: cancel) : const Page<Album>.empty();
          final playlists =
              types.contains(SearchType.playlists) ? await s.searchPlaylists(query, cancel: cancel) : const Page<Playlist>.empty();
          if (!ctl.isClosed && !(cancel?.isCanceled ?? false)) {
            ctl.add(SourceSearchResults(sourceId: s.id, tracks: tracks, artists: artists, albums: albums, playlists: playlists));
          }
        } catch (e) {
          if (!ctl.isClosed && e is! OperationCanceledException) ctl.add(SourceSearchResults(sourceId: s.id, error: e));
        } finally {
          if (--pending == 0) await ctl.close();
        }
      }();
    }
    return ctl.stream;
  }
}

class FakeTokenStore implements TokenStore {
  final tokens = <String, OAuthToken>{};

  @override
  bool isPersistent = true;

  @override
  Future<OAuthToken?> read(String sourceId) async => tokens[sourceId];

  @override
  Future<void> write(String sourceId, OAuthToken token) async => tokens[sourceId] = token;

  @override
  Future<void> delete(String sourceId) async => tokens.remove(sourceId);

  @override
  Future<void> deleteAll() async => tokens.clear();
}

class FakeCredentialsStore implements CredentialsStore {
  final credentials = <String, SourceCredentials>{};
  final origins = <String, CredentialOrigin>{};
  final _ctl = StreamController<String>.broadcast();

  @override
  Future<void> init() async {}

  @override
  SourceCredentials? get(String sourceId) => credentials[sourceId];

  @override
  CredentialOrigin originOf(String sourceId) =>
      origins[sourceId] ?? (credentials.containsKey(sourceId) ? CredentialOrigin.userEntered : CredentialOrigin.none);

  @override
  Future<void> setUserCredentials(String sourceId, SourceCredentials? c) async {
    if (c == null) {
      credentials.remove(sourceId);
    } else {
      credentials[sourceId] = c;
    }
    _ctl.add(sourceId);
  }

  @override
  Stream<String> get changes => _ctl.stream;

  @override
  String get configFilePath => '/tmp/fermata-test/credentials.json';
}

class FakeOAuthClient implements OAuthClient {
  final authorized = <String>[];

  /// When set, `authorize` throws it.
  Object? error;

  @override
  Future<OAuthToken> authorize(OAuthConfig config) async {
    authorized.add(config.sourceId);
    if (error != null) throw error!;
    return const OAuthToken(accessToken: 'test-access', refreshToken: 'test-refresh');
  }

  @override
  Future<OAuthToken> refresh(OAuthConfig config, OAuthToken token) async => token;

  @override
  Future<void> revoke(OAuthConfig config, OAuthToken token) async {}

  @override
  String redirectUriFor(OAuthConfig config) => 'http://127.0.0.1:${config.loopbackPort}/callback/${config.sourceId}';
}
