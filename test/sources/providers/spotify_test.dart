import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/sources/auth/auth.dart';
import 'package:fermata/sources/spotify/spotify_links.dart';
import 'package:fermata/sources/spotify/spotify_mapper.dart';
import 'package:fermata/sources/spotify/spotify_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixtures/spotify_fixtures.dart';
import 'support/helpers.dart';

typedef Route = Future<http.Response> Function(http.Request request);

class _Harness {
  _Harness({SourceCredentials? credentials = const SourceCredentials(clientId: 'sp-id')})
    : credentials = FakeCredentialsStore({'spotify': ?credentials}) {
    net = RecordingHttp(_route);
    source = SpotifySource(
      http: net.fermata,
      oauth: oauth,
      tokens: tokens,
      credentials: this.credentials,
      platform: const PlatformInfo(os: HostOs.linux),
    );
  }

  final FakeCredentialsStore credentials;
  final tokens = InMemoryTokenStore();
  final oauth = FakeOAuthClient();
  late final RecordingHttp net;
  late final SpotifySource source;
  final Map<String, Route> routes = {};
  final accepted = <String>{'user-1', 'user-2'};

  Future<http.Response> _route(http.Request r) async {
    final auth = r.headers['Authorization'] ?? '';
    if (r.url.host == 'api.spotify.com' && !accepted.contains(auth.replaceFirst('Bearer ', ''))) {
      return jsonResponse(spError(401, 'The access token expired'), status: 401);
    }
    final handler = routes[r.url.path];
    if (handler == null) return jsonResponse(spError(404, 'Not found'), status: 404);
    return handler(r);
  }

  Future<SpotifySource> connect() async {
    routes.putIfAbsent('/v1/me', () => (r) async => jsonResponse(spMe()));
    await source.init();
    await source.connect();
    return source;
  }
}

void main() {
  group('without credentials', () {
    test('credentialsMissing, helpful status, every call throws before any request', () async {
      final h = _Harness(credentials: null);
      final s = h.source;
      await s.init();
      expect(s.credentialStatus.configured, isFalse);
      expect(s.credentialStatus.missing, ['clientId']);
      expect(s.credentialStatus.helpUrl.toString(), 'https://developer.spotify.com/dashboard');
      expect(s.authState.status, SourceConnectionStatus.credentialsMissing);
      expect(s.isReady, isFalse);
      for (final call in <Future<Object?> Function()>[
        () => s.searchTracks('x'),
        () => s.lookupByIsrc('USUM71703861'),
        () => s.getTrack('11dFghVXANMlKmJXsNCbNl'),
        () => s.getPlaylist('https://open.spotify.com/playlist/3cEYpjA9oz9GiPac4AsH4n'),
        () => s.userPlaylists(),
        () => s.userLikedTracks(),
        () => s.connect(),
      ]) {
        await expectLater(call(), throwsA(isA<MissingCredentialsException>()));
      }
      expect(h.net.requests, isEmpty);
    });

    test('configured but not connected: calls need a connection and make no request', () async {
      final h = _Harness();
      await h.source.init();
      expect(h.source.authState.status, SourceConnectionStatus.notConnected);
      expect(h.source.isReady, isFalse);
      await expectLater(h.source.searchTracks('x'), throwsA(isA<AuthRequiredException>()));
      expect(h.net.requests, isEmpty);
    });
  });

  test('connect: PKCE without secret, documented scopes, account from /me', () async {
    final h = _Harness(credentials: const SourceCredentials(clientId: 'sp-id', clientSecret: 'never-sent'));
    final s = await h.connect();
    final config = h.oauth.lastConfig!;
    expect(config.authorizeEndpoint.toString(), 'https://accounts.spotify.com/authorize');
    expect(config.tokenEndpoint.toString(), 'https://accounts.spotify.com/api/token');
    expect(config.usePkce, isTrue);
    expect(config.clientSecret, isNull);
    expect(config.scopes, ['playlist-read-private', 'playlist-read-collaborative', 'user-library-read']);
    expect(h.oauth.redirectUriFor(config), 'http://127.0.0.1:43821/callback/spotify');
    expect(s.authState.status, SourceConnectionStatus.connected);
    expect(s.authState.accountName, 'Ada');
    expect(h.net.to('/v1/me').single.headers['Authorization'], 'Bearer user-1');
    expect(s.isReady, isTrue);
  });

  group('playlists', () {
    test('getPlaylist(URL) uses /playlists/{id}/items and maps tracks (isrc, explicit, album, duration, artists)', () async {
      final h = _Harness();
      const id = '3cEYpjA9oz9GiPac4AsH4n';
      h.routes['/v1/playlists/$id'] = (r) async => jsonResponse(spPlaylist());
      h.routes['/v1/playlists/$id/items'] = (r) async => r.url.queryParameters['offset'] == '0'
          ? jsonResponse(
              spPaging(
                [spPlaylistItem(spTrack(explicit: true)), spPlaylistItem(spEpisode()), spPlaylistItem(spLocalTrack())],
                total: 4,
                next: 'https://api.spotify.com/v1/playlists/$id/items?offset=3&limit=50',
              ),
            )
          : jsonResponse(spPaging([spPlaylistItem(spTrack(id: '0000000000000000000004', name: 'Four'))], total: 4, offset: 3));
      final s = await h.connect();

      final first = await s.getPlaylist('https://open.spotify.com/intl-de/playlist/$id?si=abc123');
      expect(first.playlist.id, 'spotify:$id');
      expect(first.playlist.name, 'Spotify Web API Testing playlist');
      expect(first.playlist.ownerName, 'Ada');
      expect(first.playlist.trackCount, 3);
      expect(first.tracks.total, 4);
      final t = first.tracks.items.first;
      expect(t.sourceTrackId, '11dFghVXANMlKmJXsNCbNl');
      expect(t.title, 'Cut To The Feeling');
      expect(t.artists.map((a) => a.name), ['Carly Rae Jepsen', 'Guest']);
      expect(t.artists.first.sourceArtistId, '6sFIWsNpZYqfjUpaCgueju');
      expect(t.album, 'Cut To The Feeling');
      expect(t.albumArtist, 'Carly Rae Jepsen');
      expect(t.duration, const Duration(milliseconds: 207959));
      expect(t.isrc, 'USUM71703861');
      expect(t.explicit, isTrue);
      expect(t.year, 2017);
      expect(t.artworkUrl.toString(), 'https://i.scdn.co/image/ab67616d0000b273-640');
      expect(t.availability.playback, PlaybackRights.externalOnly);
      expect(t.availability.offline, OfflineRights.unavailable);
      expect(t.extra[SpotifyMapper.extraAddedAt], '2026-01-02T03:04:05Z');
      // Episode skipped; local file kept for matching.
      expect(first.tracks.items, hasLength(2));
      final local = first.tracks.items[1];
      expect(local.sourceTrackId, startsWith('spotify:local:'));
      expect(local.availability.playback, PlaybackRights.unavailable);
      expect(s.externalPlaybackUri(local), isNull);

      final items = h.net.to('/v1/playlists/$id/items').single;
      expect(items.url.queryParameters, {'limit': '50', 'offset': '0', 'additional_types': 'track'});
      expect(h.net.requests.where((r) => r.url.path.endsWith('/tracks')), isEmpty);

      final second = await s.getPlaylist('ignored', cursor: first.tracks.nextCursor);
      expect(second.tracks.items.single.title, 'Four');
      expect(second.tracks.hasMore, isFalse);
      expect(h.net.to('/v1/playlists/$id/items').last.url.queryParameters['offset'], '3');
      expect(s.isImportable(first.playlist), isTrue);
    });

    test('playlists without items (not owned) explain the restriction without calling /items', () async {
      final h = _Harness();
      const id = '37i9dQZF1DXcBWIGoYBM5M';
      h.routes['/v1/playlists/$id'] = (r) async => jsonResponse(spPlaylist(id: id, ownerId: 'spotify', withItems: false));
      final s = await h.connect();
      await expectLater(
        s.getPlaylist('spotify:playlist:$id'),
        throwsA(isA<SpotifyPlaylistNotAccessibleException>()
            .having((e) => e.message, 'message', contains('created or collaborate'))
            .having((e) => e.code, 'code', 'unsupported_operation')),
      );
      expect(h.net.to('/v1/playlists/$id/items'), isEmpty);
    });

    test('a 403 from /items is explained too', () async {
      final h = _Harness();
      const id = '1111111111111111111111';
      h.routes['/v1/playlists/$id'] = (r) async => jsonResponse(spPlaylist(id: id));
      h.routes['/v1/playlists/$id/items'] = (r) async => jsonResponse(spError(403, 'Forbidden'), status: 403);
      final s = await h.connect();
      await expectLater(s.getPlaylist(id), throwsA(isA<SpotifyPlaylistNotAccessibleException>()));
    });

    test('userPlaylists pages and records which playlists are importable', () async {
      final h = _Harness();
      h.routes['/v1/me/playlists'] = (r) async => r.url.queryParameters['offset'] == '0'
          ? jsonResponse(
              spPaging(
                [spPlaylist(), spPlaylist(id: '2222222222222222222222', ownerId: 'other')],
                total: 3,
                next: 'https://api.spotify.com/v1/me/playlists?offset=2&limit=50',
              ),
            )
          : jsonResponse(
              spPaging([spPlaylist(id: '3333333333333333333333', ownerId: 'other', collaborative: true)], total: 3, offset: 2),
            );
      final s = await h.connect();
      final playlists = await s.userPlaylists();
      expect(playlists.map((p) => p.sourcePlaylistId), [
        '3cEYpjA9oz9GiPac4AsH4n',
        '2222222222222222222222',
        '3333333333333333333333',
      ]);
      expect(playlists.map(s.isImportable), [true, false, true]);
      expect(h.net.to('/v1/me/playlists').map((r) => r.url.queryParameters['offset']), ['0', '2']);
    });

    test('userLikedTracks pages with an offset cursor', () async {
      final h = _Harness();
      h.routes['/v1/me/tracks'] = (r) async => r.url.queryParameters['offset'] == '0'
          ? jsonResponse(
              spPaging(
                [{'added_at': '2026-02-02T00:00:00Z', 'track': spTrack()}],
                total: 2,
                limit: 1,
                next: 'https://api.spotify.com/v1/me/tracks?offset=1&limit=50',
              ),
            )
          : jsonResponse(spPaging([{'added_at': '2026-01-01T00:00:00Z', 'track': spTrack(id: '0000000000000000000009')}], total: 2, offset: 1));
      final s = await h.connect();
      final first = await s.userLikedTracks();
      expect(first.items.single.sourceTrackId, '11dFghVXANMlKmJXsNCbNl');
      expect(first.total, 2);
      final second = await s.userLikedTracks(cursor: first.nextCursor);
      expect(second.items.single.sourceTrackId, '0000000000000000000009');
      expect(second.hasMore, isFalse);
    });
  });

  group('search and ISRC', () {
    test('search caps the page at 10 and pages by offset', () async {
      final h = _Harness();
      h.routes['/v1/search'] = (r) async => jsonResponse({
        'tracks': spPaging([spTrack()], total: 25, limit: 10, next: 'https://api.spotify.com/v1/search?offset=10'),
      });
      final s = await h.connect();
      final page = await s.searchTracks('carly rae', limit: 30);
      final q = h.net.to('/v1/search').single.url.queryParameters;
      expect(q, {'q': 'carly rae', 'type': 'track', 'limit': '10', 'offset': '0'});
      expect(page.items.single.title, 'Cut To The Feeling');
      await s.searchTracks('carly rae', cursor: page.nextCursor);
      expect(h.net.to('/v1/search').last.url.queryParameters['offset'], '1');
    });

    test('lookupByIsrc queries isrc:<code> and returns the exact match', () async {
      final h = _Harness();
      h.routes['/v1/search'] = (r) async => jsonResponse({
        'tracks': spPaging([spTrack(id: '0000000000000000000001', isrc: 'GBAAA0000001'), spTrack()], total: 2),
      });
      final s = await h.connect();
      final t = await s.lookupByIsrc('us-um7-17-03861');
      expect(h.net.to('/v1/search').single.url.queryParameters['q'], 'isrc:USUM71703861');
      expect(t?.sourceTrackId, '11dFghVXANMlKmJXsNCbNl');
      expect(await s.lookupByIsrc('not an isrc'), isNull);
      expect(h.net.to('/v1/search'), hasLength(1));
    });

    test('getTrack by URI; unknown → null', () async {
      final h = _Harness();
      h.routes['/v1/tracks/11dFghVXANMlKmJXsNCbNl'] = (r) async => jsonResponse(spTrack());
      final s = await h.connect();
      expect((await s.getTrack('spotify:track:11dFghVXANMlKmJXsNCbNl'))?.isrc, 'USUM71703861');
      expect(await s.getTrack('0000000000000000000000'), isNull);
    });
  });

  group('errors', () {
    test('401 → refresh → retry through the OAuth session', () async {
      final h = _Harness();
      h.routes['/v1/me/tracks'] = (r) async => jsonResponse(spPaging([], total: 0));
      final s = await h.connect();
      h.accepted.remove('user-1');
      await s.userLikedTracks();
      expect(h.oauth.refreshCalls, 1);
      expect(h.net.to('/v1/me/tracks').map((r) => r.headers['Authorization']), ['Bearer user-1', 'Bearer user-2']);
    });

    test('429 → RateLimitedException with Retry-After', () async {
      final h = _Harness();
      h.routes['/v1/search'] = (r) async => jsonResponse(
        {'error': {'status': 429, 'message': 'Too many requests', 'reason': 'QUOTA_EXCEEDED'}},
        status: 429,
        headers: {'retry-after': '3600'},
      );
      final s = await h.connect();
      await expectLater(
        s.searchTracks('x'),
        throwsA(isA<RateLimitedException>().having((e) => e.retryAfter, 'retryAfter', const Duration(hours: 1))),
      );
    });

    test('a dev-mode 403 is explained', () async {
      final h = _Harness();
      h.routes['/v1/me/tracks'] = (r) async => jsonResponse(spError(403, 'Forbidden'), status: 403);
      final s = await h.connect();
      await expectLater(
        s.userLikedTracks(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('User Management'))),
      );
    });
  });

  group('playback', () {
    test('external only: resolveStream refuses, open.spotify.com link, never downloadable', () async {
      final h = _Harness();
      final s = await h.connect();
      final t = SpotifyMapper.track(spTrack())!;
      await expectLater(
        s.resolveStream(t),
        throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.externalOnly)),
      );
      expect(s.externalPlaybackUri(t).toString(), 'https://open.spotify.com/track/11dFghVXANMlKmJXsNCbNl');
      expect(await s.authorizeDownload(t), isNull);
      expect(s.capabilities, contains(SourceCapability.externalPlayback));
      expect(s.capabilities, isNot(contains(SourceCapability.stream)));
      expect(s.limitationsNote, contains('does not permit third-party apps to play'));
      expect(s.limitationsNote, contains('Premium'));
    });
  });

  group('links', () {
    test('playlist ids from URLs, URIs and ids', () {
      const id = '3cEYpjA9oz9GiPac4AsH4n';
      for (final input in [
        id,
        'spotify:playlist:$id',
        'spotify:user:ada:playlist:$id',
        'https://open.spotify.com/playlist/$id?si=0123abcd',
        'open.spotify.com/playlist/$id',
        'https://open.spotify.com/intl-pt-BR/playlist/$id',
        'https://open.spotify.com/embed/playlist/$id',
        'https://open.spotify.com/user/ada/playlist/$id',
      ]) {
        expect(SpotifyLinks.playlistId(input), id, reason: input);
      }
      expect(SpotifyLinks.playlistId('https://open.spotify.com/track/$id'), isNull);
      expect(SpotifyLinks.playlistId('https://example.com/playlist/$id'), isNull);
      expect(SpotifyLinks.trackId('https://open.spotify.com/track/$id'), id);
      expect(SpotifyLinks.isShortLink('https://spotify.link/AbCdEf'), isTrue);
    });

    test('spotify.link short links are followed to open.spotify.com', () async {
      const id = '3cEYpjA9oz9GiPac4AsH4n';
      final net = RecordingHttp((r) async {
        if (r.url.host == 'spotify.link') {
          return http.Response('', 307, headers: {'location': 'https://open.spotify.com/playlist/$id?si=x'});
        }
        return http.Response('<html>', 200);
      });
      final link = await SpotifyLinks.resolve(net.fermata, 'https://spotify.link/AbCdEf');
      expect(link, const SpotifyLink(SpotifyLinkKind.playlist, id));
      expect(net.requests.map((r) => r.url.host), ['spotify.link']);
    });
  });
}
