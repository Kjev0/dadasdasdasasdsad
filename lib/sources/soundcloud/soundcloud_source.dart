import 'dart:async';

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
import '../auth/token_endpoint_client.dart';
import '../base/availability.dart';
import '../base/json_utils.dart';
import '../base/music_source_base.dart';
import '../base/paging.dart';
import 'soundcloud_api.dart';
import 'soundcloud_app_token.dart';
import 'soundcloud_links.dart';
import 'soundcloud_mapper.dart';
import 'soundcloud_rate_limits.dart';
import 'soundcloud_streams.dart';

final _log = Logger('sources.soundcloud');

/// What a SoundCloud share link resolved to (exactly one field is set).
class SoundCloudResolved {
  const SoundCloudResolved({this.track, this.playlist, this.artist});

  final Track? track;
  final Playlist? playlist;
  final Artist? artist;
}

/// SoundCloud — Fermata's first-class streaming source.
///
/// * Developer credentials: `clientId` **and** `clientSecret` (SoundCloud
///   treats every client as confidential; registration currently requires
///   Artist Pro). Without them: `credentialsMissing`, [isReady] false, every
///   call throws [MissingCredentialsException] before any request.
/// * Public browsing (search, pages, share links, streaming) works without a
///   connected account through an app token (client-credentials grant);
///   connecting (OAuth 2.1 + PKCE) adds likes and playlists.
/// * Streams: AAC/MP3 HLS via `/tracks/{urn}/streams`, never downloadable,
///   played in a SoundCloud-only queue (`SourcePolicies` silo).
/// * Ids are URNs (`soundcloud:tracks:123`); see [SoundCloudLinks].
class SoundCloudSource extends MusicSourceBase with OAuthSourceMixin {
  SoundCloudSource({
    required FermataHttp http,
    required OAuthClient oauth,
    required TokenStore tokens,
    required CredentialsStore credentials,
    PlatformInfo? platform,
    Uri? apiBaseUri,
    int dailyStreamLimit = 1500,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       oauthSession = OAuthSession(
         sourceId: SourceIds.soundcloud,
         displayName: 'SoundCloud',
         client: oauth,
         tokens: tokens,
         credentials: credentials,
         http: http,
         requiredCredentialFields: const ['clientId', 'clientSecret'],
         credentialsHelpUrl: helpUrl,
         headerStyle: AuthHeaderStyle.oauth,
         platform: platform,
         buildConfig: (c) => buildOAuthConfig(c, android: (platform ?? PlatformInfo.current()).isAndroid),
         fetchAccount: (session, cancel) => _fetchAccount(session, apiBaseUri ?? SoundCloudApi.defaultBaseUri, cancel),
         revoker: (session, token) => SoundCloudApi.revokeRemotely(session, token, baseUri: apiBaseUri),
       ) {
    _appTokens = SoundCloudAppTokens(
      tokenEndpoint: TokenEndpointClient(http, clock: _clock),
      store: tokens,
      grantConfig: () => buildOAuthConfig(oauthSession.requireCredentials(), clientAuthInHeader: true),
      refreshConfig: () => buildOAuthConfig(oauthSession.requireCredentials()),
      clock: _clock,
    );
    gate = SoundCloudRateGate(dailyStreamLimit: dailyStreamLimit, clock: _clock);
    api = SoundCloudApi(
      http: http,
      session: oauthSession,
      appTokens: _appTokens,
      gate: gate,
      baseUri: apiBaseUri,
      clock: _clock,
    );
    streams = SoundCloudStreams(api, clock: _clock);
    _credSub = credentials.changes.where((id) => id == SourceIds.soundcloud).listen((_) => _onCredentialsChanged());
  }

  /// Where developers register a SoundCloud app.
  static final helpUrl = Uri.parse('https://soundcloud.com/you/apps');

  static final authorizeEndpoint = Uri.parse('https://secure.soundcloud.com/authorize');
  static final tokenEndpoint = Uri.parse('https://secure.soundcloud.com/oauth/token');

  /// Re-check availability before playing when older than this.
  static const availabilityMaxAge = Duration(minutes: 10);

  /// `access` filter: search/browse show what can be played; imports keep
  /// blocked tracks so playlists stay complete (they are marked unavailable).
  static const _playableAccess = ['playable', 'preview'];
  static const _allAccess = ['playable', 'preview', 'blocked'];

  static const _maxLibraryPages = 25;

  /// The OAuth 2.1 configuration (secret required for code exchange and
  /// refresh; HTTP Basic for the client-credentials grant).
  static OAuthConfig buildOAuthConfig(SourceCredentials c, {bool android = false, bool clientAuthInHeader = false}) =>
      OAuthConfig(
        sourceId: SourceIds.soundcloud,
        authorizeEndpoint: authorizeEndpoint,
        tokenEndpoint: tokenEndpoint,
        clientId: c.clientId!,
        clientSecret: c.clientSecret,
        scopes: const [],
        // "For mobile devices, add display=popup" (API guide).
        extraAuthorizeParams: android ? const {'display': 'popup'} : const {},
        redirectUriOverride: c.redirectUri,
        clientAuthInHeader: clientAuthInHeader,
      );

  static Future<OAuthAccount> _fetchAccount(OAuthSession session, Uri base, CancelToken? cancel) async {
    final me = asJsonMap(await session.authorizedGetJson(base.replace(path: '${base.path}/me'), cancel: cancel));
    return OAuthAccount(
      name: jsonString(me['username']) ?? jsonString(me['full_name']) ?? 'SoundCloud',
      avatar: SoundCloudMapper.artwork(me['avatar_url']),
      id: jsonString(me['urn']),
    );
  }

  @override
  final OAuthSession oauthSession;
  final DateTime Function() _clock;
  late final SoundCloudAppTokens _appTokens;
  late final StreamSubscription<String> _credSub;

  /// Request layer (exposed for diagnostics and tests).
  late final SoundCloudApi api;

  /// Rate-limit state (429 back-off and the daily stream budget).
  late final SoundCloudRateGate gate;

  /// Resolved stream URL cache.
  late final SoundCloudStreams streams;

  @override
  String get id => SourceIds.soundcloud;

  @override
  String get displayName => 'SoundCloud';

  @override
  Set<SourceCapability> get capabilities => const {
    SourceCapability.searchTracks,
    SourceCapability.searchArtists,
    SourceCapability.searchPlaylists,
    SourceCapability.stream,
    SourceCapability.externalPlayback,
    SourceCapability.userLibrary,
    SourceCapability.playlistImport,
    SourceCapability.relatedTracks,
    SourceCapability.artistPages,
    SourceCapability.oauth,
  };

  @override
  String get limitationsNote =>
      'SoundCloud only works with your own SoundCloud app credentials (client ID and client secret). SoundCloud '
      'currently issues API keys only to Artist Pro subscribers, one app per person. With them you can search, '
      'browse and stream SoundCloud, and after connecting your account import your likes and playlists. '
      "SoundCloud's API terms require SoundCloud streams to play in their own queue (never mixed with other "
      'streaming services) and forbid downloads and offline listening, even for tracks the uploader made '
      'downloadable. Some tracks are preview-only or blocked in your country, and an app may start about 1,500 '
      'streams per day.';

  @override
  Uri? get termsUrl => Uri.parse('https://developers.soundcloud.com/docs/api/terms-of-use');

  /// Public browsing works with an app token, so the source is ready as soon
  /// as the developer credentials are configured.
  @override
  bool get isReady => oauthSession.hasCredentials;

  void _onCredentialsChanged() {
    streams.clear();
    unawaited(_appTokens.clear());
  }

  int _clampLimit(int limit) => limit.clamp(1, 200);

  // ---- Search -------------------------------------------------------------

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    ensureCredentials();
    if (query.trim().isEmpty && cursor == null) return const Page.empty();
    final page = await api.collection(
      api.uri('tracks', {
        'q': query.trim(),
        'access': _playableAccess,
        'limit': _clampLimit(limit),
        'linked_partitioning': 'true',
      }),
      cursor: cursor,
      group: SoundCloudRateGroup.search,
      cancel: cancel,
    );
    return Page(SoundCloudMapper.tracks(page.items, now: _clock()), nextCursor: page.nextCursor);
  }

  @override
  Future<Page<Artist>> searchArtists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    ensureCredentials();
    if (query.trim().isEmpty && cursor == null) return const Page.empty();
    final page = await api.collection(
      api.uri('users', {'q': query.trim(), 'limit': _clampLimit(limit), 'linked_partitioning': 'true'}),
      cursor: cursor,
      group: SoundCloudRateGroup.search,
      cancel: cancel,
    );
    return Page(SoundCloudMapper.artists(page.items), nextCursor: page.nextCursor);
  }

  @override
  Future<Page<Playlist>> searchPlaylists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    ensureCredentials();
    if (query.trim().isEmpty && cursor == null) return const Page.empty();
    final page = await api.collection(
      api.uri('playlists', {
        'q': query.trim(),
        'show_tracks': 'false',
        'limit': _clampLimit(limit),
        'linked_partitioning': 'true',
      }),
      cursor: cursor,
      group: SoundCloudRateGroup.search,
      cancel: cancel,
    );
    return Page(SoundCloudMapper.playlists(page.items), nextCursor: page.nextCursor);
  }

  // ---- Browse -------------------------------------------------------------

  String _requireUrn(String? urn, String input, String kind) =>
      urn ?? (throw ArgumentError.value(input, 'id', 'Not a SoundCloud $kind URN, id or link'));

  /// [sourceTrackId]: a track URN, a legacy numeric id or a share link.
  /// Null when the track was deleted (404). A private track without its
  /// secret token answers 403 ([ApiException]).
  @override
  Future<Track?> getTrack(String sourceTrackId, {CancelToken? cancel, String? secretToken}) async {
    ensureCredentials();
    if (SoundCloudLinks.isShareUrl(sourceTrackId)) {
      return (await resolveShareUrl(sourceTrackId, cancel: cancel))?.track;
    }
    final urn = _requireUrn(SoundCloudLinks.trackUrn(sourceTrackId), sourceTrackId, 'track');
    final json = await api.getJsonOrNull(
      api.uri('tracks/${SoundCloudApi.seg(urn)}', {'secret_token': secretToken}),
      cancel: cancel,
    );
    return SoundCloudMapper.track(json, now: _clock(), secretToken: secretToken);
  }

  @override
  Future<Artist?> getArtist(String sourceArtistId, {CancelToken? cancel}) async {
    ensureCredentials();
    final urn = _requireUrn(SoundCloudLinks.userUrn(sourceArtistId), sourceArtistId, 'user');
    final json = await api.getJsonOrNull(api.uri('users/${SoundCloudApi.seg(urn)}'), cancel: cancel);
    return SoundCloudMapper.artist(json);
  }

  /// SoundCloud has no "top tracks" endpoint: the uploader's tracks, newest
  /// first (`GET /users/{urn}/tracks`).
  @override
  Future<Page<Track>> artistTopTracks(String sourceArtistId, {String? cursor, int limit = 30, CancelToken? cancel}) =>
      userTracks(sourceArtistId, cursor: cursor, limit: limit, cancel: cancel);

  /// The tracks a user uploaded, newest first.
  Future<Page<Track>> userTracks(String userUrnOrId, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    ensureCredentials();
    final urn = _requireUrn(SoundCloudLinks.userUrn(userUrnOrId), userUrnOrId, 'user');
    final page = await api.collection(
      api.uri('users/${SoundCloudApi.seg(urn)}/tracks', {
        'access': _playableAccess,
        'limit': _clampLimit(limit),
        'linked_partitioning': 'true',
      }),
      cursor: cursor,
      cancel: cancel,
    );
    return Page(SoundCloudMapper.tracks(page.items, now: _clock()), nextCursor: page.nextCursor);
  }

  @override
  Future<List<Artist>> relatedArtists(String sourceArtistId, {int limit = 12, CancelToken? cancel}) async {
    ensureCredentials();
    final urn = _requireUrn(SoundCloudLinks.userUrn(sourceArtistId), sourceArtistId, 'user');
    final page = await api.collection(
      api.uri('users/${SoundCloudApi.seg(urn)}/related', {'limit': _clampLimit(limit), 'linked_partitioning': 'true'}),
      cancel: cancel,
    );
    return SoundCloudMapper.artists(page.items).take(limit).toList();
  }

  @override
  Future<List<Track>> relatedTracks(String sourceTrackId, {int limit = 20, CancelToken? cancel}) async {
    ensureCredentials();
    final urn = _requireUrn(SoundCloudLinks.trackUrn(sourceTrackId), sourceTrackId, 'track');
    final page = await api.collection(
      api.uri('tracks/${SoundCloudApi.seg(urn)}/related', {
        'access': _playableAccess,
        'limit': _clampLimit(limit),
        'linked_partitioning': 'true',
      }),
      cancel: cancel,
    );
    return SoundCloudMapper.tracks(page.items, now: _clock()).where((t) => t.sourceTrackId != urn).take(limit).toList();
  }

  /// [idOrUrl]: a playlist URN, a legacy numeric id, an API resource URL or
  /// a share link (`soundcloud.com/<user>/sets/<name>`, private `…/s-<token>`
  /// links, `on.soundcloud.com/<code>`). Tracks come in pages of up to 200;
  /// blocked tracks are included (marked unavailable) so imports are
  /// complete.
  @override
  Future<PlaylistDetail> getPlaylist(String idOrUrl, {String? cursor, CancelToken? cancel}) async {
    ensureCredentials();
    String? urn;
    String? secret;
    Map<String, Object?>? meta;
    if (cursor != null) {
      final state = PageCursor.decode(cursor)!;
      urn = jsonString(state['p']);
      secret = jsonString(state['s']);
      if (urn == null) throw FormatException('Invalid SoundCloud playlist cursor', cursor);
    } else {
      final input = idOrUrl.trim();
      secret = SoundCloudLinks.secretToken(input);
      urn = SoundCloudLinks.playlistUrn(input) ?? SoundCloudLinks.urnFromApiUrl(input);
      if (urn == null && SoundCloudLinks.isShareUrl(input)) {
        meta = await api.resolve(SoundCloudLinks.normaliseShareUrl(input)!, cancel: cancel);
        if (meta == null) throw ApiException(404, 'SoundCloud could not find $input');
        if (jsonString(meta['kind']) != 'playlist') {
          throw ApiException(
            400,
            'This SoundCloud link is a ${jsonString(meta['kind']) ?? 'resource'}, not a playlist.',
          );
        }
        urn = jsonString(meta['urn']);
      }
      urn = _requireUrn(urn, input, 'playlist');
    }
    meta ??= asJsonMapOrNull(
      await api.getJsonOrNull(
        api.uri('playlists/${SoundCloudApi.seg(urn)}', {'show_tracks': 'false', 'secret_token': secret}),
        cancel: cancel,
      ),
    );
    final playlist = SoundCloudMapper.playlist(meta);
    if (playlist == null) throw ApiException(404, 'SoundCloud playlist $urn not found');
    final page = await api.collection(
      api.uri('playlists/${SoundCloudApi.seg(urn)}/tracks', {
        'access': _allAccess,
        'limit': 200,
        'linked_partitioning': 'true',
        'secret_token': secret,
      }),
      cursor: cursor,
      cancel: cancel,
    );
    final next = page.nextHref;
    return PlaylistDetail(
      playlist: playlist,
      tracks: Page(
        SoundCloudMapper.tracks(page.items, now: _clock()),
        nextCursor: next == null ? null : PageCursor.encode({'t': next, 'p': urn, 's': ?secret}),
        total: playlist.trackCount,
      ),
    );
  }

  /// Resolves a soundcloud.com / on.soundcloud.com link with `/resolve`.
  /// Null when SoundCloud does not know it. Throws [ArgumentError] for
  /// non-SoundCloud input.
  Future<SoundCloudResolved?> resolveShareUrl(String url, {CancelToken? cancel}) async {
    ensureCredentials();
    final normalised = SoundCloudLinks.normaliseShareUrl(url);
    if (normalised == null) throw ArgumentError.value(url, 'url', 'Not a SoundCloud link');
    final json = await api.resolve(normalised, cancel: cancel);
    if (json == null) return null;
    final secret = SoundCloudLinks.secretToken(url);
    return switch (jsonString(json['kind'])) {
      'track' => SoundCloudResolved(
        track: SoundCloudMapper.track(json, now: _clock(), secretToken: secret),
      ),
      'playlist' => SoundCloudResolved(playlist: SoundCloudMapper.playlist(json)),
      'user' => SoundCloudResolved(artist: SoundCloudMapper.artist(json)),
      _ => null,
    };
  }

  // ---- User library -------------------------------------------------------

  /// The connected user's own playlists (all pages, metadata only).
  @override
  Future<List<Playlist>> userPlaylists({CancelToken? cancel}) async {
    ensureCredentials();
    final first = api.uri('me/playlists', {'show_tracks': 'false', 'limit': 200, 'linked_partitioning': 'true'});
    final result = <Playlist>[];
    String? cursor;
    for (var i = 0; i < _maxLibraryPages; i++) {
      final page = await api.collection(first, cursor: cursor, requireUser: true, cancel: cancel);
      result.addAll(SoundCloudMapper.playlists(page.items));
      cursor = page.nextCursor;
      if (cursor == null) break;
    }
    return result;
  }

  /// The connected user's liked tracks, newest first; blocked tracks are
  /// included and marked unavailable.
  @override
  Future<Page<Track>> userLikedTracks({String? cursor, CancelToken? cancel}) async {
    ensureCredentials();
    final page = await api.collection(
      api.uri('me/likes/tracks', {'access': _allAccess, 'limit': 200, 'linked_partitioning': 'true'}),
      cursor: cursor,
      requireUser: true,
      group: SoundCloudRateGroup.likes,
      cancel: cancel,
    );
    return Page(SoundCloudMapper.tracks(page.items, now: _clock()), nextCursor: page.nextCursor);
  }

  // ---- Playback -----------------------------------------------------------

  /// Re-checks stale availability, then resolves an AAC/MP3 HLS stream (or
  /// the 30 s preview for `access: preview`). Resolved URLs are cached for
  /// their lifetime.
  @override
  Future<PlayableSource> resolveStream(
    Track track, {
    AudioQuality quality = AudioQuality.high,
    CancelToken? cancel,
  }) async {
    checkOwnTrack(track);
    ensureCredentials();
    final urn = _requireUrn(SoundCloudLinks.trackUrn(track.sourceTrackId), track.sourceTrackId, 'track');
    final secret = track.extra[SoundCloudMapper.extraSecretToken];
    var current = track;
    if (Availabilities.isStale(track.availability, maxAge: availabilityMaxAge)) {
      current = await _refreshForPlayback(track, urn, secret, cancel);
    }
    Availabilities.ensurePlayable(current);
    final preview = current.availability.playback == PlaybackRights.preview;
    return streams.resolve(current, urn, preview: preview, quality: quality, secretToken: secret, cancel: cancel);
  }

  Future<Track> _refreshForPlayback(Track track, String urn, String? secret, CancelToken? cancel) async {
    final Object? json;
    try {
      json = await api.getJson(api.uri('tracks/${SoundCloudApi.seg(urn)}', {'secret_token': secret}), cancel: cancel);
    } on ApiException catch (e) {
      if (e.statusCode == 404) throw UnplayableTrackException(track.id, AvailabilityReason.deleted);
      if (e.statusCode == 403) throw UnplayableTrackException(track.id, AvailabilityReason.private);
      rethrow;
    }
    final fresh = SoundCloudMapper.track(json, now: _clock(), secretToken: secret);
    if (fresh == null) throw UnplayableTrackException(track.id, AvailabilityReason.deleted);
    _log.fine('Refreshed availability of ${track.id}: ${fresh.availability.playback.name}');
    return fresh;
  }

  /// The track on soundcloud.com (attribution link and "Open in SoundCloud").
  @override
  Uri? externalPlaybackUri(Track track) => track.sourceId == id ? track.permalink : null;

  /// Always null: SoundCloud's API terms forbid downloads and offline access
  /// regardless of the uploader's download setting (docs/COMPLIANCE.md).
  @override
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel}) async => null;

  @override
  Future<void> dispose() async {
    await _credSub.cancel();
    streams.clear();
    await super.dispose();
  }
}
