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
import 'youtube_api.dart';
import 'youtube_links.dart';
import 'youtube_mapper.dart';

/// YouTube / YouTube Music — playlist import and metadata via the YouTube
/// Data API v3. There is no YouTube Music API; playback is external only
/// (`music.youtube.com/watch?v=…`) because YouTube's policies forbid
/// extracting, background-playing or caching the audio.
///
/// * Credentials (either is enough): an API key for search and public
///   playlists, and/or an OAuth client (`clientId` + the `clientSecret`
///   Google issues to "Desktop app" clients) for the user's playlists and
///   likes (`youtube.readonly`). Without both: `credentialsMissing`, every
///   call throws [MissingCredentialsException] before any request.
/// * Sign-in is desktop-only (loopback redirect): Google rejects custom URI
///   schemes and loopback redirects for Android clients and requires its
///   Play-services `AuthorizationClient` instead.
/// * Search is expensive (100 calls/day/project) — see [YouTubeApi].
class YouTubeSource extends MusicSourceBase with OAuthSourceMixin {
  YouTubeSource({
    required FermataHttp http,
    required OAuthClient oauth,
    required TokenStore tokens,
    required CredentialsStore credentials,
    PlatformInfo? platform,
    Uri? apiBaseUri,
    DateTime Function()? clock,
    int searchCallsPerDay = 100,
  }) : _credentials = credentials,
       _clock = clock ?? DateTime.now,
       oauthSession = OAuthSession(
         sourceId: SourceIds.youtube,
         displayName: 'YouTube',
         client: oauth,
         tokens: tokens,
         credentials: credentials,
         http: http,
         requiredCredentialFields: const ['clientId'],
         credentialsHelpUrl: helpUrl,
         headerStyle: AuthHeaderStyle.bearer,
         platform: platform,
         supportsAndroidRedirect: false,
         androidUnsupportedExplanation: androidExplanation,
         buildConfig: buildOAuthConfig,
         fetchAccount: (session, cancel) => _fetchAccount(session, apiBaseUri ?? YouTubeApi.defaultBaseUri, cancel),
       ) {
    api = YouTubeApi(
      http: http,
      session: oauthSession,
      apiKey: () => _credentials.get(SourceIds.youtube)?.apiKey,
      baseUri: apiBaseUri,
      clock: _clock,
      searchCallsPerDay: searchCallsPerDay,
    );
  }

  static final helpUrl = Uri.parse('https://console.cloud.google.com/apis/credentials');
  static final authorizeEndpoint = Uri.parse('https://accounts.google.com/o/oauth2/v2/auth');
  static final tokenEndpoint = Uri.parse('https://oauth2.googleapis.com/token');
  static final revokeEndpoint = Uri.parse('https://oauth2.googleapis.com/revoke');
  static const scope = 'https://www.googleapis.com/auth/youtube.readonly';

  static const androidExplanation =
      'Connecting a YouTube account is only available in Fermata for Linux and Windows: Google does not accept the '
      'sign-in redirects Fermata uses on Android. Search and public playlists still work with an API key.';

  static const _pageSize = 50;
  static const _maxLibraryPages = 20;

  /// Google "Desktop app" OAuth client: PKCE + loopback redirect.
  static OAuthConfig buildOAuthConfig(SourceCredentials c) => OAuthConfig(
    sourceId: SourceIds.youtube,
    authorizeEndpoint: authorizeEndpoint,
    tokenEndpoint: tokenEndpoint,
    revokeEndpoint: revokeEndpoint,
    clientId: c.clientId!,
    clientSecret: c.clientSecret,
    scopes: const [scope],
    redirectStrategy: RedirectStrategy.loopback,
    redirectUriOverride: c.redirectUri,
  );

  static Future<OAuthAccount> _fetchAccount(OAuthSession session, Uri base, CancelToken? cancel) async {
    final uri = base.replace(path: '${base.path}/channels', queryParameters: const {'part': 'snippet', 'mine': 'true'});
    final json = asJsonMap(await session.authorizedGetJson(uri, cancel: cancel));
    final channel = asJsonMapList(json['items']).firstOrNull;
    final snippet = asJsonMap(channel?['snippet']);
    return OAuthAccount(
      name: jsonString(snippet['title']) ?? 'Google account',
      avatar: YouTubeMapper.thumbnail(snippet['thumbnails'], targetPx: 120),
      id: jsonString(channel?['id']),
    );
  }

  @override
  final OAuthSession oauthSession;
  final CredentialsStore _credentials;
  final DateTime Function() _clock;

  /// Request layer (quota bookkeeping; exposed for diagnostics and tests).
  late final YouTubeApi api;

  String? _likesPlaylistId;

  @override
  String get id => SourceIds.youtube;

  @override
  String get displayName => 'YouTube';

  @override
  Set<SourceCapability> get capabilities => const {
    SourceCapability.searchTracks,
    SourceCapability.externalPlayback,
    SourceCapability.userLibrary,
    SourceCapability.playlistImport,
    SourceCapability.oauth,
  };

  @override
  String get limitationsNote =>
      'YouTube Music has no public API, so Fermata uses the YouTube Data API to import your playlists and liked '
      'music videos and to find tracks, and opens them in YouTube Music for playback: YouTube does not allow apps '
      'to play the audio on its own, in the background or offline. You need your own Google Cloud credentials: an '
      'API key for search and public playlists, and an OAuth client of type "Desktop app" to connect your account '
      '(desktop only — Google does not allow this sign-in on Android). Search is limited to 100 searches per day '
      'per Google Cloud project.';

  @override
  Uri? get termsUrl => Uri.parse('https://developers.google.com/youtube/terms/developer-policies');

  // ---- Credentials & state ------------------------------------------------

  bool get _hasApiKey {
    final key = _credentials.get(id)?.apiKey;
    return key != null && key.trim().isNotEmpty;
  }

  /// Configured when an API key **or** an OAuth client id is present.
  @override
  CredentialStatus get credentialStatus {
    final configured = _hasApiKey || oauthSession.hasCredentials;
    return CredentialStatus(
      configured: configured,
      origin: _credentials.originOf(id),
      missing: configured ? const [] : const ['apiKey', 'clientId'],
      helpUrl: helpUrl,
    );
  }

  /// With only an API key the source is usable but not connected.
  @override
  SourceAuthState get authState => _adapt(oauthSession.state);

  @override
  Stream<SourceAuthState> get authStateChanges => oauthSession.changes.map(_adapt);

  SourceAuthState _adapt(SourceAuthState s) => s.status == SourceConnectionStatus.credentialsMissing && _hasApiKey
      ? const SourceAuthState(status: SourceConnectionStatus.notConnected)
      : s;

  @override
  bool get isReady => _hasApiKey || (oauthSession.hasCredentials && oauthSession.state.isConnected);

  void _ensureConfigured() {
    if (!credentialStatus.configured) throw MissingCredentialsException(id, const ['apiKey', 'clientId']);
  }

  // ---- Search & tracks --------------------------------------------------------

  /// `search?type=video&videoCategoryId=10` (Music) plus one `videos` call
  /// for durations. Each page costs one of the 100 daily searches — never use
  /// this in automatic loops.
  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    _ensureConfigured();
    if (query.trim().isEmpty) return const Page.empty();
    final json = await api.get('search', {
      'part': 'snippet',
      'type': 'video',
      'videoCategoryId': YouTubeMapper.musicCategoryId,
      'q': query.trim(),
      'maxResults': limit.clamp(1, _pageSize),
      'pageToken': PageCursor.decodeToken(cursor),
    }, cancel: cancel);
    final results = asJsonMapList(json['items']);
    final ids = [for (final r in results) ?jsonString(asJsonMap(r['id'])['videoId'])];
    final videos = await _videos(ids, cancel: cancel);
    final tracks = <Track>[
      for (final r in results)
        ?(videos[jsonString(asJsonMap(r['id'])['videoId'])] ?? YouTubeMapper.searchResult(r, now: _clock())),
    ];
    final next = jsonString(json['nextPageToken']);
    return Page(
      tracks,
      nextCursor: next == null || results.isEmpty ? null : PageCursor.encodeToken(next),
      total: jsonInt(asJsonMap(json['pageInfo'])['totalResults']),
    );
  }

  /// `videos?id=…` (≤ 50 ids, 1 quota unit) → tracks by video id.
  Future<Map<String, Track>> _videos(List<String> ids, {CancelToken? cancel}) async {
    if (ids.isEmpty) return const {};
    final json = await api.get('videos', {
      'part': 'snippet,contentDetails',
      'id': ids.take(_pageSize).join(','),
      'maxResults': _pageSize,
    }, cancel: cancel);
    final byId = <String, Track>{};
    for (final v in asJsonMapList(json['items'])) {
      final track = YouTubeMapper.video(v, now: _clock());
      if (track != null) byId[track.sourceTrackId] = track;
    }
    return byId;
  }

  /// [sourceTrackId]: a video id or a youtube.com / music.youtube.com /
  /// youtu.be link. Null when the video does not exist (or is private).
  @override
  Future<Track?> getTrack(String sourceTrackId, {CancelToken? cancel}) async {
    _ensureConfigured();
    final videoId = YouTubeLinks.videoId(sourceTrackId);
    if (videoId == null) return null;
    return (await _videos([videoId], cancel: cancel))[videoId];
  }

  // ---- Playlists ----------------------------------------------------------------

  /// [idOrUrl]: a playlist id or a youtube.com / music.youtube.com link
  /// (`playlist?list=…`, `watch?v=…&list=…`, `browse/VL…`). Pages of 50
  /// via `playlistItems`, durations via `videos` (3 quota units per page).
  @override
  Future<PlaylistDetail> getPlaylist(String idOrUrl, {String? cursor, CancelToken? cancel}) async {
    _ensureConfigured();
    final String playlistId;
    String? pageToken;
    if (cursor != null) {
      final state = PageCursor.decode(cursor)!;
      final p = jsonString(state['p']);
      if (p == null) throw FormatException('Invalid YouTube playlist cursor', cursor);
      playlistId = p;
      pageToken = jsonString(state['t']);
    } else {
      final parsed = YouTubeLinks.playlistId(idOrUrl);
      if (parsed == null) throw ArgumentError.value(idOrUrl, 'idOrUrl', 'Not a YouTube playlist id or link');
      playlistId = parsed;
    }
    if (playlistId.startsWith('RD')) {
      throw UnsupportedSourceOperation(
        id,
        'getPlaylist',
        'YouTube mixes ("RD…" playlists) are generated for each viewer and cannot be read through the YouTube API.',
      );
    }
    final userList = playlistId == 'LL';
    final meta = await api.get(
      'playlists',
      {'part': 'snippet,contentDetails', 'id': playlistId},
      requireUser: userList,
      cancel: cancel,
    );
    final playlist = YouTubeMapper.playlist(asJsonMapList(meta['items']).firstOrNull);
    if (playlist == null) {
      throw ApiException(404, 'YouTube playlist $playlistId was not found or is private.');
    }
    final page = await _playlistPage(playlistId, pageToken, requireUser: userList, cancel: cancel);
    return PlaylistDetail(
      playlist: playlist,
      tracks: Page(
        page.tracks,
        nextCursor: page.next == null ? null : PageCursor.encode({'p': playlistId, 't': page.next}),
        total: page.total ?? playlist.trackCount,
      ),
    );
  }

  Future<({List<Track> tracks, String? next, int? total})> _playlistPage(
    String playlistId,
    String? pageToken, {
    bool requireUser = false,
    bool musicOnly = false,
    CancelToken? cancel,
  }) async {
    final Map<String, Object?> json;
    try {
      json = await api.get(
        'playlistItems',
        {
          'part': 'snippet,contentDetails,status',
          'playlistId': playlistId,
          'maxResults': _pageSize,
          'pageToken': pageToken,
        },
        requireUser: requireUser,
        cancel: cancel,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        throw ApiException(
          403,
          'This YouTube playlist is private. Connect the account that owns it to import it.',
          body: e.body,
        );
      }
      if (e.statusCode == 404) throw ApiException(404, 'YouTube playlist $playlistId was not found.', body: e.body);
      rethrow;
    }
    final items = asJsonMapList(json['items']);
    final placeholders = [for (final i in items) ?YouTubeMapper.playlistItem(i, now: _clock())];
    final ids = [
      for (final t in placeholders)
        if (t.availability.playback == PlaybackRights.externalOnly) t.sourceTrackId,
    ];
    final videos = await _videos(ids, cancel: cancel);
    final tracks = <Track>[
      for (final t in placeholders)
        if (!musicOnly ||
            videos[t.sourceTrackId]?.extra[YouTubeMapper.extraCategoryId] == YouTubeMapper.musicCategoryId)
          videos[t.sourceTrackId] ?? t,
    ];
    final next = jsonString(json['nextPageToken']);
    return (
      tracks: tracks,
      next: items.isEmpty ? null : next,
      total: jsonInt(asJsonMap(json['pageInfo'])['totalResults']),
    );
  }

  // ---- User library -------------------------------------------------------------

  /// The connected user's playlists (`playlists?mine=true`, all pages).
  @override
  Future<List<Playlist>> userPlaylists({CancelToken? cancel}) async {
    _ensureConfigured();
    oauthSession.requireCredentials();
    final result = <Playlist>[];
    String? token;
    for (var i = 0; i < _maxLibraryPages; i++) {
      final json = await api.get(
        'playlists',
        {'part': 'snippet,contentDetails', 'mine': 'true', 'maxResults': _pageSize, 'pageToken': token},
        requireUser: true,
        cancel: cancel,
      );
      result.addAll([for (final p in asJsonMapList(json['items'])) ?YouTubeMapper.playlist(p)]);
      token = jsonString(json['nextPageToken']);
      if (token == null) break;
    }
    return result;
  }

  /// Liked videos in the Music category (the account's "likes" playlist from
  /// `channels?mine=true`); other liked videos are skipped, so a page can
  /// hold fewer than 50 tracks.
  @override
  Future<Page<Track>> userLikedTracks({String? cursor, CancelToken? cancel}) async {
    _ensureConfigured();
    oauthSession.requireCredentials();
    final likes = _likesPlaylistId ??= await _fetchLikesPlaylistId(cancel);
    if (likes == null) return const Page.empty();
    final page = await _playlistPage(
      likes,
      PageCursor.decodeToken(cursor),
      requireUser: true,
      musicOnly: true,
      cancel: cancel,
    );
    return Page(page.tracks, nextCursor: page.next == null ? null : PageCursor.encodeToken(page.next!));
  }

  Future<String?> _fetchLikesPlaylistId(CancelToken? cancel) async {
    final json = await api.get(
      'channels',
      {'part': 'contentDetails', 'mine': 'true'},
      requireUser: true,
      cancel: cancel,
    );
    final channel = asJsonMapList(json['items']).firstOrNull;
    return jsonString(asJsonMap(asJsonMap(asJsonMap(channel?['contentDetails'])['relatedPlaylists']))['likes']);
  }

  // ---- Playback -------------------------------------------------------------------

  /// Always throws: YouTube audio must not be played outside YouTube's own
  /// player.
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
      message: 'YouTube does not allow playing its audio in other players; open it in YouTube Music.',
    );
  }

  /// `https://music.youtube.com/watch?v=<id>`.
  @override
  Uri? externalPlaybackUri(Track track) => track.sourceId == id && YouTubeLinks.isVideoId(track.sourceTrackId)
      ? YouTubeLinks.musicWatchUrl(track.sourceTrackId)
      : null;

  @override
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel}) async => null;

  @override
  Future<void> disconnect() async {
    _likesPlaylistId = null;
    await super.disconnect();
  }
}
