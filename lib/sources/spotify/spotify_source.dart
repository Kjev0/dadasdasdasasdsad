import 'package:logging/logging.dart';

import '../../core/contracts/auth.dart';
import '../../core/contracts/music_source.dart';
import '../../core/errors.dart';
import '../../core/models/auth.dart';
import '../../core/models/catalog.dart';
import '../../core/models/download.dart';
import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import '../../core/net/http_client.dart';
import '../../core/platform/platform_info.dart';
import '../../core/sources/source_ids.dart';
import '../../core/util/cancel_token.dart';
import '../auth/oauth_session.dart';
import '../auth/oauth_source_mixin.dart';
import '../base/json_utils.dart';
import '../base/music_source_base.dart';
import '../base/paging.dart';
import 'spotify_links.dart';
import 'spotify_mapper.dart';

final _log = Logger('sources.spotify');

/// Spotify answered 403 for a playlist's items, or returned the playlist
/// without items: in development mode Spotify only returns the contents of
/// playlists the user owns or collaborates on. [message] is shown to the
/// user.
class SpotifyPlaylistNotAccessibleException extends UnsupportedSourceOperation {
  const SpotifyPlaylistNotAccessibleException(this.playlistId)
    : super(
        SourceIds.spotify,
        'getPlaylist',
        'Spotify only lets apps read the tracks of playlists you created or collaborate on. Playlists made by '
            'other people or by Spotify (editorial and personalised mixes) cannot be imported — copy the tracks '
            'into a playlist of your own in Spotify, then import that one.',
      );

  final String playlistId;
}

/// Spotify — playlist/library import and metadata for matching. No audio.
///
/// * Credentials: your own app's `clientId` (PKCE, no secret). Redirect URIs:
///   `http://127.0.0.1:43821/callback/spotify` (desktop; Spotify forbids
///   `localhost`) and `fermata://oauth/spotify` (Android).
/// * Scopes: `playlist-read-private playlist-read-collaborative
///   user-library-read`.
/// * Every call needs a connected account (Spotify issues no app tokens
///   without a client secret); without credentials every call throws
///   [MissingCredentialsException] before any request.
/// * Playback is [PlaybackRights.externalOnly] (`open.spotify.com/track/…`).
class SpotifySource extends MusicSourceBase with OAuthSourceMixin {
  SpotifySource({
    required FermataHttp http,
    required OAuthClient oauth,
    required TokenStore tokens,
    required CredentialsStore credentials,
    PlatformInfo? platform,
    Uri? apiBaseUri,
    DateTime Function()? clock,
  }) : _http = http,
       _clock = clock ?? DateTime.now,
       baseUri = apiBaseUri ?? defaultBaseUri,
       oauthSession = OAuthSession(
         sourceId: SourceIds.spotify,
         displayName: 'Spotify',
         client: oauth,
         tokens: tokens,
         credentials: credentials,
         http: http,
         requiredCredentialFields: const ['clientId'],
         credentialsHelpUrl: helpUrl,
         headerStyle: AuthHeaderStyle.bearer,
         platform: platform,
         buildConfig: buildOAuthConfig,
         fetchAccount: (session, cancel) => _fetchAccount(session, apiBaseUri ?? defaultBaseUri, cancel),
       );

  static final defaultBaseUri = Uri.parse('https://api.spotify.com/v1');
  static final helpUrl = Uri.parse('https://developer.spotify.com/dashboard');
  static final authorizeEndpoint = Uri.parse('https://accounts.spotify.com/authorize');
  static final tokenEndpoint = Uri.parse('https://accounts.spotify.com/api/token');
  static const scopes = ['playlist-read-private', 'playlist-read-collaborative', 'user-library-read'];

  /// Search returns at most 10 items per page (Feb 2026 dev-mode change);
  /// offsets stop at 1000.
  static const maxSearchLimit = 10;
  static const _maxSearchOffset = 1000;
  static const _pageLimit = 50;
  static const _maxLibraryPages = 40;

  /// PKCE without a client secret (a configured secret is never sent).
  static OAuthConfig buildOAuthConfig(SourceCredentials c) => OAuthConfig(
    sourceId: SourceIds.spotify,
    authorizeEndpoint: authorizeEndpoint,
    tokenEndpoint: tokenEndpoint,
    clientId: c.clientId!,
    scopes: scopes,
    redirectUriOverride: c.redirectUri,
  );

  static Future<OAuthAccount> _fetchAccount(OAuthSession session, Uri base, CancelToken? cancel) async {
    final me = asJsonMap(await session.authorizedGetJson(base.replace(path: '${base.path}/me'), cancel: cancel));
    return OAuthAccount(
      name: jsonString(me['display_name']) ?? jsonString(me['id']) ?? 'Spotify',
      avatar: SpotifyMapper.image(me['images']),
      // "Use account_id rather than id when linking user accounts" (May 2026).
      id: jsonString(me['account_id']) ?? jsonString(me['id']),
    );
  }

  @override
  final OAuthSession oauthSession;
  final FermataHttp _http;
  final DateTime Function() _clock;
  final Uri baseUri;

  String? _userId;
  final Set<String> _importable = {};
  final Set<String> _notImportable = {};

  @override
  String get id => SourceIds.spotify;

  @override
  String get displayName => 'Spotify';

  @override
  Set<SourceCapability> get capabilities => const {
    SourceCapability.searchTracks,
    SourceCapability.externalPlayback,
    SourceCapability.userLibrary,
    SourceCapability.playlistImport,
    SourceCapability.isrcLookup,
    SourceCapability.oauth,
  };

  @override
  String get limitationsNote =>
      'Spotify is used to import your playlists and liked songs and as a metadata source for matching. Spotify '
      'does not permit third-party apps to play its music, so imported tracks are matched to other sources '
      '(or opened in Spotify). You need your own Spotify app (Client ID) from the Spotify developer dashboard; in '
      'development mode the app owner needs Spotify Premium and only up to 5 users added under User Management '
      'can sign in. Spotify only returns the tracks of playlists you own or collaborate on, so playlists by other '
      'people or by Spotify cannot be imported.';

  @override
  Uri? get termsUrl => Uri.parse('https://developer.spotify.com/terms');

  Uri _uri(String path, [Map<String, Object?> query = const {}]) {
    final params = <String, String>{
      for (final e in query.entries)
        if (e.value != null) e.key: '${e.value}',
    };
    return baseUri.replace(path: '${baseUri.path}/$path', queryParameters: params.isEmpty ? null : params);
  }

  /// Authorized GET with Spotify's dev-mode 403 explained.
  Future<Map<String, Object?>> _get(Uri uri, {CancelToken? cancel}) async {
    ensureCredentials();
    try {
      return asJsonMap(await oauthSession.authorizedGetJson(uri, cancel: cancel));
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        throw ApiException(
          403,
          'Spotify refused the request (HTTP 403). Apps in development mode only work for users added under '
          'User Management in the Spotify dashboard (and the app owner needs Premium).',
          body: e.body,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, Object?>?> _getOrNull(Uri uri, {CancelToken? cancel}) async {
    try {
      return await _get(uri, cancel: cancel);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 400) return null;
      rethrow;
    }
  }

  // ---- Search -------------------------------------------------------------

  /// Track search (max 10 per page, offsets up to 1000).
  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    ensureCredentials();
    final offset = PageCursor.decodeOffset(cursor);
    final pageSize = limit.clamp(1, maxSearchLimit);
    if (query.trim().isEmpty || offset >= _maxSearchOffset) return const Page.empty();
    final json = await _get(
      _uri('search', {'q': query.trim(), 'type': 'track', 'limit': pageSize, 'offset': offset}),
      cancel: cancel,
    );
    final tracks = asJsonMap(json['tracks']);
    final raw = asJsonMapList(tracks['items']);
    final total = jsonInt(tracks['total']);
    final page = PageCursor.offsetPage(
      SpotifyMapper.tracks(raw, now: _clock()),
      offset: offset,
      limit: pageSize,
      total: total == null ? null : (total > _maxSearchOffset ? _maxSearchOffset : total),
      hasMore: jsonString(tracks['next']) != null && offset + raw.length < _maxSearchOffset,
      consumed: raw.length,
    );
    return page;
  }

  /// `search?q=isrc:<ISRC>&type=track`; prefers an exact ISRC match.
  @override
  Future<Track?> lookupByIsrc(String isrc, {CancelToken? cancel}) async {
    ensureCredentials();
    final code = isrc.trim().replaceAll('-', '').toUpperCase();
    if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{3}\d{7}$').hasMatch(code)) return null;
    final json = await _get(_uri('search', {'q': 'isrc:$code', 'type': 'track', 'limit': 5}), cancel: cancel);
    final tracks = SpotifyMapper.tracks(asJsonMap(json['tracks'])['items'], now: _clock());
    return tracks.where((t) => t.isrc == code).firstOrNull ?? tracks.firstOrNull;
  }

  /// [sourceTrackId]: a track id, `spotify:track:…` URI or open.spotify.com
  /// link. Null when unknown.
  @override
  Future<Track?> getTrack(String sourceTrackId, {CancelToken? cancel}) async {
    ensureCredentials();
    final trackId = SpotifyLinks.trackId(sourceTrackId);
    if (trackId == null) return null;
    final json = await _getOrNull(_uri('tracks/$trackId'), cancel: cancel);
    return SpotifyMapper.track(json, now: _clock());
  }

  // ---- Playlists ------------------------------------------------------------

  /// [idOrUrl]: a playlist id, `spotify:playlist:…` URI, open.spotify.com
  /// link or spotify.link short link. Items come from
  /// `GET /playlists/{id}/items` (50 per page) — the endpoint that replaced
  /// `/tracks` in February 2026. Playlists the user neither owns nor
  /// collaborates on throw [SpotifyPlaylistNotAccessibleException].
  @override
  Future<PlaylistDetail> getPlaylist(String idOrUrl, {String? cursor, CancelToken? cancel}) async {
    ensureCredentials();
    final String playlistId;
    var offset = 0;
    if (cursor != null) {
      final state = PageCursor.decode(cursor)!;
      final p = jsonString(state['p']);
      if (p == null) throw FormatException('Invalid Spotify playlist cursor', cursor);
      playlistId = p;
      offset = PageCursor.decodeOffset(cursor);
    } else {
      final input = idOrUrl.trim();
      final direct = SpotifyLinks.playlistId(input);
      final link = direct == null && SpotifyLinks.isShortLink(input)
          ? await SpotifyLinks.resolve(_http, input, cancel: cancel)
          : null;
      final resolved = direct ?? (link?.kind == SpotifyLinkKind.playlist ? link!.id : null);
      if (resolved == null) {
        throw ArgumentError.value(idOrUrl, 'idOrUrl', 'Not a Spotify playlist id or link');
      }
      playlistId = resolved;
    }
    final meta = await _getOrNull(_uri('playlists/$playlistId'), cancel: cancel);
    final playlist = SpotifyMapper.playlist(meta);
    if (meta == null || playlist == null) throw ApiException(404, 'Spotify playlist $playlistId not found');
    if (!_hasItems(meta)) {
      _notImportable.add(playlistId);
      throw SpotifyPlaylistNotAccessibleException(playlistId);
    }
    final Map<String, Object?> json;
    try {
      json = await _get(
        _uri('playlists/$playlistId/items', {'limit': _pageLimit, 'offset': offset, 'additional_types': 'track'}),
        cancel: cancel,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        _notImportable.add(playlistId);
        throw SpotifyPlaylistNotAccessibleException(playlistId);
      }
      rethrow;
    }
    _importable.add(playlistId);
    final raw = asJsonMapList(json['items']);
    final page = PageCursor.offsetPage(
      SpotifyMapper.wrappedTracks(raw, now: _clock()),
      offset: offset,
      limit: _pageLimit,
      total: jsonInt(json['total']) ?? playlist.trackCount,
      hasMore: jsonString(json['next']) != null,
      consumed: raw.length,
    );
    return PlaylistDetail(
      playlist: playlist,
      tracks: Page(
        page.items,
        nextCursor: page.nextCursor == null ? null : PageCursor.encode({'o': offset + raw.length, 'p': playlistId}),
        total: page.total,
      ),
    );
  }

  /// "Playlist contents (items) are only returned for playlists the user
  /// owns or collaborates on. For other playlists … the items field will be
  /// absent." Older apps may still get the deprecated `tracks` field.
  static bool _hasItems(Map<String, Object?> meta) {
    if (meta['items'] is Map) return true;
    final legacy = asJsonMapOrNull(meta['tracks']);
    return legacy != null && legacy['items'] is List;
  }

  /// Whether [playlist] can be imported (owned or collaborative), as far as
  /// known from [userPlaylists] / [getPlaylist]; null when unknown.
  bool? isImportable(Playlist playlist) {
    final id = playlist.sourcePlaylistId;
    if (id == null || playlist.sourceId != this.id) return null;
    if (_importable.contains(id)) return true;
    if (_notImportable.contains(id)) return false;
    return null;
  }

  // ---- User library -------------------------------------------------------

  /// The user's playlists (owned and followed, all pages). Followed
  /// playlists by others are listed but cannot be imported
  /// ([isImportable]).
  @override
  Future<List<Playlist>> userPlaylists({CancelToken? cancel}) async {
    ensureCredentials();
    final me = _userId ??= jsonString((await _get(_uri('me'), cancel: cancel))['id']);
    final result = <Playlist>[];
    var offset = 0;
    for (var i = 0; i < _maxLibraryPages; i++) {
      final json = await _get(_uri('me/playlists', {'limit': _pageLimit, 'offset': offset}), cancel: cancel);
      final raw = asJsonMapList(json['items']);
      for (final p in raw) {
        final playlist = SpotifyMapper.playlist(p);
        if (playlist == null) continue;
        final owned = me != null && jsonString(asJsonMap(p['owner'])['id']) == me;
        final collaborative = jsonBool(p['collaborative']) == true;
        (owned || collaborative ? _importable : _notImportable).add(playlist.sourcePlaylistId!);
        result.add(playlist);
      }
      offset += raw.length;
      if (jsonString(json['next']) == null || raw.isEmpty) break;
    }
    _log.fine('Spotify: ${result.length} playlists, ${_importable.length} importable');
    return result;
  }

  /// Saved ("Liked") tracks, newest first, 50 per page.
  @override
  Future<Page<Track>> userLikedTracks({String? cursor, CancelToken? cancel}) async {
    ensureCredentials();
    final offset = PageCursor.decodeOffset(cursor);
    final json = await _get(_uri('me/tracks', {'limit': _pageLimit, 'offset': offset}), cancel: cancel);
    final raw = asJsonMapList(json['items']);
    return PageCursor.offsetPage(
      SpotifyMapper.wrappedTracks(raw, now: _clock()),
      offset: offset,
      limit: _pageLimit,
      total: jsonInt(json['total']),
      hasMore: jsonString(json['next']) != null,
      consumed: raw.length,
    );
  }

  // ---- Playback -----------------------------------------------------------

  /// Always throws: Spotify does not permit third-party playback.
  @override
  Future<PlayableSource> resolveStream(
    Track track, {
    AudioQuality quality = AudioQuality.high,
    CancelToken? cancel,
  }) async {
    checkOwnTrack(track);
    throw UnplayableTrackException(
      track.id,
      AvailabilityReason.externalOnly,
      message: 'Spotify does not permit playback in other apps; play a matched track or open it in Spotify.',
    );
  }

  /// `https://open.spotify.com/track/<id>` (opens the Spotify app when
  /// installed). Null for Spotify "local files".
  @override
  Uri? externalPlaybackUri(Track track) {
    if (track.sourceId != id || track.extra[SpotifyMapper.extraLocal] == 'true') return null;
    final trackId = SpotifyLinks.trackId(track.sourceTrackId);
    return trackId == null ? track.permalink : SpotifyLinks.trackUrl(trackId);
  }

  /// Never downloadable.
  @override
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel}) async => null;

  @override
  Future<void> disconnect() async {
    _userId = null;
    _importable.clear();
    _notImportable.clear();
    await super.disconnect();
  }
}
