import 'dart:convert';

import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/sources/auth/auth.dart';
import 'package:fermata/sources/base/paging.dart';
import 'package:fermata/sources/soundcloud/soundcloud_app_token.dart';
import 'package:fermata/sources/soundcloud/soundcloud_mapper.dart';
import 'package:fermata/sources/soundcloud/soundcloud_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixtures/soundcloud_fixtures.dart';
import 'support/helpers.dart';

typedef Route = Future<http.Response> Function(http.Request request);

const _creds = SourceCredentials(clientId: 'sc-id', clientSecret: 'sc-secret');

/// Wires a [SoundCloudSource] to a MockClient router. Token-endpoint calls
/// are answered here (client credentials → `app-N`, refresh → `app-r-N`);
/// API paths go to [routes] (keyed by path) or [fallback].
class _Harness {
  _Harness({
    SourceCredentials? credentials = _creds,
    this.os = HostOs.linux,
    this.dailyStreamLimit = 1500,
  }) : credentials = FakeCredentialsStore({'soundcloud': ?credentials}) {
    net = RecordingHttp(_route);
    source = SoundCloudSource(
      http: net.fermata,
      oauth: oauth,
      tokens: tokens,
      credentials: this.credentials,
      platform: PlatformInfo(os: os),
      dailyStreamLimit: dailyStreamLimit,
    );
  }

  final HostOs os;
  final int dailyStreamLimit;
  final FakeCredentialsStore credentials;
  final tokens = InMemoryTokenStore();
  final oauth = FakeOAuthClient();
  late final RecordingHttp net;
  late final SoundCloudSource source;
  final Map<String, Route> routes = {};
  Route? fallback;
  int grants = 0;
  int appRefreshes = 0;

  /// Access tokens the API accepts (app tokens are added as they are issued).
  final accepted = <String>{'user-1', 'user-2'};

  Future<http.Response> _route(http.Request r) async {
    if (r.url.host == 'secure.soundcloud.com' && r.url.path == '/oauth/token') {
      final grant = r.bodyFields['grant_type'];
      if (grant == 'client_credentials') {
        grants++;
        final token = 'app-$grants';
        accepted.add(token);
        return jsonResponse(scToken(token));
      }
      if (grant == 'refresh_token') {
        appRefreshes++;
        final token = 'app-r-$appRefreshes';
        accepted.add(token);
        return jsonResponse(scToken(token, refresh: 'app-refresh-$appRefreshes'));
      }
      return jsonResponse({'error': 'unsupported_grant_type'}, status: 400);
    }
    final auth = r.headers['Authorization'] ?? '';
    final token = auth.startsWith('OAuth ') ? auth.substring(6) : null;
    if (r.url.host == 'api.soundcloud.com' && (token == null || !accepted.contains(token))) {
      return jsonResponse(scError(401), status: 401);
    }
    final handler = routes[r.url.path] ?? fallback;
    if (handler == null) return jsonResponse(scError(404), status: 404);
    return handler(r);
  }

  Future<SoundCloudSource> init() async {
    await source.init();
    return source;
  }

  /// Connects through the (fake) OAuth flow: token `user-1`, `/me` → ada.
  Future<void> connectUser() async {
    routes.putIfAbsent('/me', () => (r) async => jsonResponse(scUser(username: 'ada')));
    await source.init();
    await source.connect();
  }

  List<http.Request> get api => [
    for (final r in net.requests)
      if (r.url.host == 'api.soundcloud.com') r,
  ];
}

Track _playable(String urn, {String access = 'playable'}) => SoundCloudMapper.track(
  scTrack(urn: urn, access: access),
  now: DateTime.now(),
)!;

void main() {
  group('without credentials', () {
    test('reports credentialsMissing, lists missing fields and makes no request', () async {
      final h = _Harness(credentials: null);
      final s = await h.init();
      expect(s.credentialStatus.configured, isFalse);
      expect(s.credentialStatus.missing, ['clientId', 'clientSecret']);
      expect(s.credentialStatus.helpUrl, SoundCloudSource.helpUrl);
      expect(s.authState.status, SourceConnectionStatus.credentialsMissing);
      expect(s.isReady, isFalse);

      final calls = <Future<Object?> Function()>[
        () => s.searchTracks('x'),
        () => s.searchArtists('x'),
        () => s.searchPlaylists('x'),
        () => s.getTrack('soundcloud:tracks:1'),
        () => s.getArtist('soundcloud:users:1'),
        () => s.artistTopTracks('soundcloud:users:1'),
        () => s.relatedArtists('soundcloud:users:1'),
        () => s.relatedTracks('soundcloud:tracks:1'),
        () => s.getPlaylist('https://soundcloud.com/a/sets/b'),
        () => s.resolveShareUrl('https://soundcloud.com/a/b'),
        () => s.userPlaylists(),
        () => s.userLikedTracks(),
        () => s.resolveStream(_playable('soundcloud:tracks:1')),
        () => s.connect(),
      ];
      for (final call in calls) {
        await expectLater(call(), throwsA(isA<MissingCredentialsException>()));
      }
      expect(h.net.requests, isEmpty);
    });

    test('a client id without the secret is still incomplete', () async {
      final h = _Harness(credentials: const SourceCredentials(clientId: 'only-id'));
      final s = await h.init();
      expect(s.credentialStatus.missing, ['clientSecret']);
      expect(s.isReady, isFalse);
      await expectLater(s.searchTracks('x'), throwsA(isA<MissingCredentialsException>()));
      expect(h.net.requests, isEmpty);
    });
  });

  group('public browsing with an app token', () {
    test('client-credentials grant uses HTTP Basic, is cached, persisted and sent as "OAuth"', () async {
      final h = _Harness();
      h.routes['/tracks'] = (r) async => jsonResponse(scCollection([scTrack()]));
      final s = await h.init();
      expect(s.isReady, isTrue);
      expect(s.authState.status, SourceConnectionStatus.notConnected);

      await s.searchTracks('daft punk');
      await s.searchTracks('justice');

      final tokenCalls = h.net.to('/oauth/token');
      expect(tokenCalls, hasLength(1));
      final grant = tokenCalls.single;
      expect(grant.headers['Authorization'], 'Basic ${base64.encode(utf8.encode('sc-id:sc-secret'))}');
      expect(grant.bodyFields, {'grant_type': 'client_credentials'});
      final search = h.net.to('/tracks').first;
      expect(search.headers['Authorization'], 'OAuth app-1');
      expect(search.url.queryParameters, {
        'q': 'daft punk',
        'access': 'playable,preview',
        'limit': '30',
        'linked_partitioning': 'true',
      });
      expect((await h.tokens.read(SoundCloudAppTokens.storeKey))?.accessToken, 'app-1');
    });

    test('a 401 on the app token renews it with the refresh token and retries once', () async {
      final h = _Harness();
      h.routes['/tracks'] = (r) async => jsonResponse(scCollection([scTrack()]));
      final s = await h.init();
      await s.searchTracks('a');
      h.accepted.remove('app-1'); // SoundCloud revoked/expired it
      final page = await s.searchTracks('b');
      expect(page.items, hasLength(1));
      expect(h.appRefreshes, 1);
      final refresh = h.net.to('/oauth/token').last;
      expect(refresh.bodyFields['grant_type'], 'refresh_token');
      expect(refresh.bodyFields['client_secret'], 'sc-secret');
      expect(h.net.to('/tracks').last.headers['Authorization'], 'OAuth app-r-1');
    });

    test('a stored app token is reused after a restart', () async {
      final h = _Harness();
      await h.tokens.write(
        SoundCloudAppTokens.storeKey,
        OAuthToken(accessToken: 'app-stored', expiresAt: DateTime.now().add(const Duration(hours: 1))),
      );
      h.accepted.add('app-stored');
      h.routes['/tracks'] = (r) async => jsonResponse(scCollection([]));
      await (await h.init()).searchTracks('x');
      expect(h.grants, 0);
      expect(h.net.to('/tracks').single.headers['Authorization'], 'OAuth app-stored');
    });

    test('changed credentials drop the app token', () async {
      final h = _Harness();
      h.routes['/tracks'] = (r) async => jsonResponse(scCollection([]));
      final s = await h.init();
      await s.searchTracks('x');
      await h.credentials.setUserCredentials(
        'soundcloud',
        const SourceCredentials(clientId: 'new-id', clientSecret: 'new-secret'),
      );
      await settle();
      await s.searchTracks('y');
      expect(h.grants, 2);
      expect(h.net.to('/oauth/token').last.headers['Authorization'], contains(base64.encode(utf8.encode('new-id:new-secret'))));
    });
  });

  group('mapping and pagination', () {
    test('search maps tracks and follows next_href through an opaque cursor', () async {
      final h = _Harness();
      const next = 'https://api.soundcloud.com/tracks?q=x&page_size=1&cursor=1234567&linked_partitioning=true';
      h.routes['/tracks'] = (r) async => r.url.queryParameters['cursor'] == null
          ? jsonResponse(scCollection([scTrack(isrc: 'usum71703861')], nextHref: next))
          : jsonResponse(scCollection([scTrack(urn: 'soundcloud:tracks:2', title: 'Two')]));
      final s = await h.init();

      final first = await s.searchTracks('x', limit: 1);
      final t = first.items.single;
      expect(t.id, 'soundcloud:soundcloud:tracks:1234');
      expect(t.sourceTrackId, 'soundcloud:tracks:1234');
      expect(t.title, 'Some title');
      expect(t.artists.map((a) => a.name), ['Metro Boomin', 'The Weeknd', '21 Savage']);
      expect(t.artists.first.sourceArtistId, 'soundcloud:users:12345');
      expect(t.duration, const Duration(seconds: 40));
      expect(t.isrc, 'USUM71703861');
      expect(t.year, 2019);
      expect(t.genre, 'Rock');
      expect(t.artworkUrl.toString(), 'https://i1.sndcdn.com/artworks-000-t500x500.jpg');
      expect(t.permalink.toString(), 'https://soundcloud.com/userPermalink/trackPermalink');
      expect(t.extra[SoundCloudMapper.extraUploader], 'some.user');
      expect(t.extra[SoundCloudMapper.extraUploaderUrl], 'https://soundcloud.com/permalink');
      expect(first.nextCursor, isNotNull);
      expect(first.nextCursor, isNot(contains('api.soundcloud.com')));

      final second = await s.searchTracks('x', cursor: first.nextCursor);
      expect(second.items.single.title, 'Two');
      expect(second.hasMore, isFalse);
      expect(h.net.to('/tracks').last.url.toString(), next);
    });

    test('the uploader is the artist when there is no metadata_artist', () async {
      final t = SoundCloudMapper.track(scTrack(metadataArtist: null))!;
      expect(t.artists.single.name, 'some.user');
      expect(t.artists.single.sourceArtistId, 'soundcloud:users:12345');
    });

    test('a cursor pointing at another host is rejected without a request', () async {
      final h = _Harness();
      final s = await h.init();
      final evil = PageCursor.encodeToken('https://evil.example/steal?cursor=1');
      await expectLater(s.searchTracks('x', cursor: evil), throwsA(isA<FormatException>()));
      expect(h.api, isEmpty);
    });

    test('availability: playable / preview / blocked / policy / streamable', () {
      TrackAvailability a(Map<String, Object?> json) => SoundCloudMapper.availability(json);
      expect(a(scTrack()).playback, PlaybackRights.full);
      expect(a(scTrack()).offline, OfflineRights.streamOnly);
      final preview = a(scTrack(access: 'preview'));
      expect(preview.playback, PlaybackRights.preview);
      expect(preview.previewDuration, const Duration(seconds: 30));
      final blocked = a(scTrack(access: 'blocked'));
      expect(blocked.playback, PlaybackRights.unavailable);
      expect(blocked.reason, AvailabilityReason.regionRestricted);
      expect(blocked.offline, OfflineRights.unavailable);
      expect(a(scTrack(access: null, policy: 'BLOCK')).reason, AvailabilityReason.regionRestricted);
      expect(a(scTrack(access: null, policy: 'SNIP')).playback, PlaybackRights.preview);
      expect(a(scTrack(access: null, streamable: false)).reason, AvailabilityReason.notStreamable);
      expect(a(scTrack(access: null)).playback, PlaybackRights.full);
    });

    test('uploader-downloadable tracks stay stream-only and authorizeDownload is null', () async {
      final h = _Harness();
      final s = await h.init();
      final t = SoundCloudMapper.track(scTrack(downloadable: true))!;
      expect(t.availability.offline, OfflineRights.streamOnly);
      expect(t.extra[SoundCloudMapper.extraUploaderAllowsDownload], 'true');
      expect(await s.authorizeDownload(t), isNull);
      expect(s.capabilities, isNot(contains(SourceCapability.download)));
      expect(h.net.requests, isEmpty);
    });

    test('getTrack builds the URN path from a numeric id; 404 means deleted', () async {
      final h = _Harness();
      h.routes['/tracks/soundcloud:tracks:308946187'] = (r) async => jsonResponse(scError(404), status: 404);
      h.routes['/tracks/soundcloud:tracks:1234'] = (r) async => jsonResponse(scTrack());
      final s = await h.init();
      expect(await s.getTrack('308946187'), isNull);
      expect((await s.getTrack('soundcloud:tracks:1234'))?.title, 'Some title');
      expect(h.api.first.url.toString(), 'https://api.soundcloud.com/tracks/soundcloud:tracks:308946187');
    });

    test('artist pages: user, uploads, related users', () async {
      final h = _Harness();
      h.routes['/users/soundcloud:users:5'] = (r) async => jsonResponse(scUser(urn: 'soundcloud:users:5'));
      h.routes['/users/soundcloud:users:5/tracks'] = (r) async => jsonResponse(scCollection([scTrack()]));
      h.routes['/users/soundcloud:users:5/related'] = (r) async =>
          jsonResponse(scCollection([scUser(urn: 'soundcloud:users:6', username: 'other')]));
      final s = await h.init();
      final artist = await s.getArtist('soundcloud:users:5');
      expect(artist?.name, 'some.user');
      expect(artist?.followers, 42);
      expect(artist?.permalink.toString(), 'https://soundcloud.com/permalink');
      expect((await s.artistTopTracks('5')).items, hasLength(1));
      expect(h.net.to('/users/soundcloud:users:5/tracks').single.url.queryParameters['access'], 'playable,preview');
      expect((await s.relatedArtists('soundcloud:users:5')).single.name, 'other');
    });

    test('related tracks', () async {
      final h = _Harness();
      h.routes['/tracks/soundcloud:tracks:1/related'] = (r) async => jsonResponse(
        scCollection([scTrack(urn: 'soundcloud:tracks:2'), scTrack(urn: 'soundcloud:tracks:3')]),
      );
      final s = await h.init();
      final related = await s.relatedTracks('soundcloud:tracks:1', limit: 1);
      expect(related.map((t) => t.sourceTrackId), ['soundcloud:tracks:2']);
      expect(h.net.to('/tracks/soundcloud:tracks:1/related').single.url.queryParameters['limit'], '1');
    });
  });

  group('share links', () {
    test('/resolve follows the 302 to the API resource with the same token', () async {
      final h = _Harness();
      h.routes['/resolve'] = (r) async => http.Response(
        jsonEncode({'status': '302 - Found', 'location': 'https://api.soundcloud.com/tracks/soundcloud:tracks:1234'}),
        302,
        headers: {'location': 'https://api.soundcloud.com/tracks/soundcloud:tracks:1234'},
      );
      h.routes['/tracks/soundcloud:tracks:1234'] = (r) async => jsonResponse(scTrack());
      final s = await h.init();
      final resolved = await s.resolveShareUrl('https://m.soundcloud.com/userPermalink/trackPermalink/?si=abc&utm_source=x');
      expect(resolved?.track?.sourceTrackId, 'soundcloud:tracks:1234');
      final resolve = h.net.to('/resolve').single;
      expect(resolve.url.queryParameters['url'], 'https://soundcloud.com/userPermalink/trackPermalink');
      expect(h.net.to('/tracks/soundcloud:tracks:1234').single.headers['Authorization'], 'OAuth app-1');
    });

    test('on.soundcloud.com short links are passed to /resolve unchanged (Found body without header)', () async {
      final h = _Harness();
      h.routes['/resolve'] = (r) async =>
          jsonResponse({'status': '302 - Found', 'location': 'https://api.soundcloud.com/users/soundcloud:users:9'}, status: 302);
      h.routes['/users/soundcloud:users:9'] = (r) async => jsonResponse(scUser(urn: 'soundcloud:users:9'));
      final s = await h.init();
      final resolved = await s.resolveShareUrl('on.soundcloud.com/AbCdEf');
      expect(resolved?.artist?.sourceArtistId, 'soundcloud:users:9');
      expect(h.net.to('/resolve').single.url.queryParameters['url'], 'https://on.soundcloud.com/AbCdEf');
    });

    test('redirects to other hosts are not followed', () async {
      final h = _Harness();
      h.routes['/resolve'] = (r) async => http.Response('', 302, headers: {'location': 'https://evil.example/x'});
      final s = await h.init();
      await expectLater(s.resolveShareUrl('https://soundcloud.com/a/b'), throwsA(isA<ApiException>()));
      expect(h.net.requests.where((r) => r.url.host == 'evil.example'), isEmpty);
    });

    test('getPlaylist from a private share link pages through tracks with the secret token', () async {
      final h = _Harness();
      const urn = 'soundcloud:playlists:777';
      const next = 'https://api.soundcloud.com/playlists/soundcloud:playlists:777/tracks?cursor=2&linked_partitioning=true';
      h.routes['/resolve'] = (r) async => jsonResponse(scPlaylist(urn: urn, title: 'Secret mix', trackCount: 3));
      h.routes['/playlists/$urn'] = (r) async => jsonResponse(scPlaylist(urn: urn, title: 'Secret mix', trackCount: 3));
      h.routes['/playlists/$urn/tracks'] = (r) async => r.url.queryParameters['cursor'] == null
          ? jsonResponse(
              scCollection([
                scTrack(urn: 'soundcloud:tracks:1'),
                scTrack(urn: 'soundcloud:tracks:2', access: 'blocked'),
              ], nextHref: next),
            )
          : jsonResponse(scCollection([scTrack(urn: 'soundcloud:tracks:3')]));
      final s = await h.init();

      final first = await s.getPlaylist('https://soundcloud.com/userPermalink/sets/secret-mix/s-AbC123');
      expect(first.playlist.id, 'soundcloud:$urn');
      expect(first.playlist.name, 'Secret mix');
      expect(first.playlist.ownerName, 'some.user');
      expect(first.tracks.total, 3);
      expect(first.tracks.items, hasLength(2));
      expect(first.tracks.items[1].availability.reason, AvailabilityReason.regionRestricted);
      final tracksCall = h.net.to('/playlists/$urn/tracks').single;
      expect(tracksCall.url.queryParameters['secret_token'], 's-AbC123');
      expect(tracksCall.url.queryParameters['access'], 'playable,preview,blocked');

      final second = await s.getPlaylist('ignored when a cursor is given', cursor: first.tracks.nextCursor);
      expect(second.tracks.items.single.sourceTrackId, 'soundcloud:tracks:3');
      expect(second.tracks.hasMore, isFalse);
      expect(h.net.to('/playlists/$urn').single.url.queryParameters['secret_token'], 's-AbC123');
      expect(h.net.to('/resolve'), hasLength(1));
    });

    test('getPlaylist by URN', () async {
      final h = _Harness();
      h.routes['/playlists/soundcloud:playlists:12345'] = (r) async => jsonResponse(scPlaylist());
      h.routes['/playlists/soundcloud:playlists:12345/tracks'] = (r) async => jsonResponse(scCollection([scTrack()]));
      final s = await h.init();
      final detail = await s.getPlaylist('soundcloud:playlists:12345');
      expect(detail.tracks.items.single.title, 'Some title');
      expect(h.net.to('/playlists/soundcloud:playlists:12345').single.url.queryParameters['show_tracks'], 'false');
    });
  });

  group('streaming', () {
    void streamRoutes(_Harness h, {Map<String, Object?>? streams, int signStatus = 302}) {
      h.routes['/tracks/soundcloud:tracks:1/streams'] = (r) async => jsonResponse(streams ?? scStreams());
      h.fallback = (r) async {
        if (r.url.path.startsWith('/tracks/urn/streams/')) {
          final variant = r.url.pathSegments[3];
          if (signStatus != 302) return http.Response('#EXTM3U', signStatus);
          return http.Response('', 302, headers: {
            'location': 'https://cf-hls-media.sndcdn.com/playlist/$variant.m3u8?Policy=p&Signature=s&Expires=1900000000',
          });
        }
        return jsonResponse(scError(404), status: 404);
      };
    }

    test('picks AAC 160 HLS, follows the authorized 302 and caches the signed URL', () async {
      final h = _Harness();
      streamRoutes(h);
      final s = await h.init();
      final track = _playable('soundcloud:tracks:1');

      final source = await s.resolveStream(track);
      expect(source.uri.host, 'cf-hls-media.sndcdn.com');
      expect(source.uri.path, '/playlist/aac160.m3u8');
      expect(source.headers, isEmpty);
      expect(source.isPreview, isFalse);
      expect(source.mimeType, 'application/vnd.apple.mpegurl');
      expect(source.expiresAt, DateTime.fromMillisecondsSinceEpoch(1900000000 * 1000, isUtc: true));
      final sign = h.net.requests.firstWhere((r) => r.url.path == '/tracks/urn/streams/aac160/');
      expect(sign.followRedirects, isFalse);
      expect(sign.headers['Authorization'], 'OAuth app-1');

      final again = await s.resolveStream(track);
      expect(again.uri, source.uri);
      expect(h.net.to('/tracks/soundcloud:tracks:1/streams'), hasLength(1));
      expect(s.gate.streamResolutionsInWindow, 1);
    });

    test('low quality prefers AAC 96, then MP3 HLS', () async {
      final h = _Harness();
      streamRoutes(h, streams: scStreams(aac96: true));
      final s = await h.init();
      expect((await s.resolveStream(_playable('soundcloud:tracks:1'), quality: AudioQuality.low)).uri.path, '/playlist/aac96.m3u8');
    });

    test('preview tracks play the 30 s preview', () async {
      final h = _Harness();
      streamRoutes(h);
      final s = await h.init();
      final source = await s.resolveStream(_playable('soundcloud:tracks:1', access: 'preview'));
      expect(source.isPreview, isTrue);
      expect(source.uri.path, '/playlist/preview.m3u8');
    });

    test('a 200 from the stream URL is played with the Authorization header', () async {
      final h = _Harness();
      streamRoutes(h, signStatus: 200);
      final s = await h.init();
      final source = await s.resolveStream(_playable('soundcloud:tracks:1'));
      expect(source.uri.toString(), 'https://api.soundcloud.com/tracks/urn/streams/aac160/');
      expect(source.headers['Authorization'], 'OAuth app-1');
    });

    test('blocked tracks are refused without any request', () async {
      final h = _Harness();
      final s = await h.init();
      await expectLater(
        s.resolveStream(_playable('soundcloud:tracks:1', access: 'blocked')),
        throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.regionRestricted)),
      );
      expect(h.net.requests, isEmpty);
    });

    test('stale availability is re-checked: 404 → deleted, 403 → private', () async {
      final h = _Harness();
      h.routes['/tracks/soundcloud:tracks:404'] = (r) async => jsonResponse(scError(404), status: 404);
      h.routes['/tracks/soundcloud:tracks:403'] = (r) async => jsonResponse(scError(403), status: 403);
      final s = await h.init();
      Track stale(String urn) => Track(sourceId: 'soundcloud', sourceTrackId: urn, title: 't');
      await expectLater(
        s.resolveStream(stale('soundcloud:tracks:404')),
        throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.deleted)),
      );
      await expectLater(
        s.resolveStream(stale('soundcloud:tracks:403')),
        throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.private)),
      );
    });

    test('stale availability is re-checked: now blocked', () async {
      final h = _Harness();
      h.routes['/tracks/soundcloud:tracks:1'] = (r) async => jsonResponse(scTrack(urn: 'soundcloud:tracks:1', access: 'blocked'));
      final s = await h.init();
      await expectLater(
        s.resolveStream(const Track(sourceId: 'soundcloud', sourceTrackId: 'soundcloud:tracks:1', title: 't')),
        throwsA(isA<UnplayableTrackException>()),
      );
      expect(h.net.to('/tracks/soundcloud:tracks:1/streams'), isEmpty);
    });

    test('the daily stream budget is enforced locally', () async {
      final h = _Harness(dailyStreamLimit: 1);
      streamRoutes(h);
      h.routes['/tracks/soundcloud:tracks:2/streams'] = h.routes['/tracks/soundcloud:tracks:1/streams']!;
      final s = await h.init();
      await s.resolveStream(_playable('soundcloud:tracks:1'));
      final before = h.net.requests.length;
      await expectLater(s.resolveStream(_playable('soundcloud:tracks:2')), throwsA(isA<RateLimitedException>()));
      expect(h.net.requests.length, before);
    });
  });

  group('rate limits', () {
    test('429 surfaces RateLimitedException and blocks the group without further requests', () async {
      final h = _Harness();
      h.routes['/tracks'] = (r) async => jsonResponse(scError(429), status: 429, headers: {'retry-after': '120'});
      final s = await h.init();
      await expectLater(
        s.searchTracks('x'),
        throwsA(isA<RateLimitedException>().having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 120))),
      );
      final count = h.api.length;
      await expectLater(s.searchTracks('y'), throwsA(isA<RateLimitedException>()));
      expect(h.api.length, count);
    });

    test('X-RateLimit-Remaining: 0 blocks until X-RateLimit-Reset', () async {
      final h = _Harness();
      final reset = DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000;
      h.routes['/users'] = (r) async => jsonResponse(
        scCollection([]),
        headers: {'x-ratelimit-remaining': '0', 'x-ratelimit-reset': '$reset'},
      );
      final s = await h.init();
      await s.searchArtists('x');
      await expectLater(s.searchArtists('y'), throwsA(isA<RateLimitedException>()));
      expect(h.net.to('/users'), hasLength(1));
    });
  });

  group('connected account', () {
    test('user endpoints need a connection (no request otherwise)', () async {
      final h = _Harness();
      final s = await h.init();
      await expectLater(s.userLikedTracks(), throwsA(isA<AuthRequiredException>()));
      await expectLater(s.userPlaylists(), throwsA(isA<AuthRequiredException>()));
      expect(h.net.requests, isEmpty);
    });

    test('likes use the user token and the documented access filter', () async {
      final h = _Harness();
      h.routes['/me/likes/tracks'] = (r) async =>
          jsonResponse(scCollection([scTrack(), scTrack(urn: 'soundcloud:tracks:9', access: 'blocked')]));
      await h.connectUser();
      final page = await h.source.userLikedTracks();
      expect(page.items, hasLength(2));
      final call = h.net.to('/me/likes/tracks').single;
      expect(call.headers['Authorization'], 'OAuth user-1');
      expect(call.url.queryParameters['access'], 'playable,preview,blocked');
      expect(h.grants, 0, reason: 'no app token is needed while connected');
    });

    test('401 → refresh → retry via the OAuth session', () async {
      final h = _Harness();
      h.routes['/me/playlists'] = (r) async => jsonResponse(scCollection([scPlaylist()]));
      await h.connectUser();
      h.accepted.remove('user-1'); // the access token expired server-side
      final playlists = await h.source.userPlaylists();
      expect(playlists.single.sourcePlaylistId, 'soundcloud:playlists:12345');
      expect(h.oauth.refreshCalls, 1);
      final calls = h.net.to('/me/playlists');
      expect(calls.map((r) => r.headers['Authorization']), ['OAuth user-1', 'OAuth user-2']);
      expect(h.source.authState.status, SourceConnectionStatus.connected);
    });

    test('userPlaylists follows every page', () async {
      final h = _Harness();
      const next = 'https://api.soundcloud.com/me/playlists?cursor=2&linked_partitioning=true';
      h.routes['/me/playlists'] = (r) async => r.url.queryParameters['cursor'] == null
          ? jsonResponse(scCollection([scPlaylist()], nextHref: next))
          : jsonResponse(scCollection([scPlaylist(urn: 'soundcloud:playlists:2')]));
      await h.connectUser();
      expect((await h.source.userPlaylists()).map((p) => p.sourcePlaylistId), [
        'soundcloud:playlists:12345',
        'soundcloud:playlists:2',
      ]);
    });

    test('connect uses the OAuth 2.1 config (secret + PKCE, popup on Android) and fetches /me', () async {
      final h = _Harness(os: HostOs.android);
      h.routes['/me'] = (r) async => jsonResponse(scUser(username: 'ada'));
      final s = await h.init();
      await s.connect();
      final config = h.oauth.lastConfig!;
      expect(config.authorizeEndpoint.toString(), 'https://secure.soundcloud.com/authorize');
      expect(config.tokenEndpoint.toString(), 'https://secure.soundcloud.com/oauth/token');
      expect(config.clientSecret, 'sc-secret');
      expect(config.usePkce, isTrue);
      expect(config.extraAuthorizeParams, {'display': 'popup'});
      expect(s.authState.status, SourceConnectionStatus.connected);
      expect(s.authState.accountName, 'ada');
      expect(h.net.to('/me').single.headers['Authorization'], 'OAuth user-1');
    });

    test('disconnect revokes with POST /disconnect and deletes the token', () async {
      final h = _Harness();
      h.routes['/disconnect'] = (r) async => http.Response('', 204);
      await h.connectUser();
      await h.source.disconnect();
      final call = h.net.to('/disconnect').single;
      expect(call.method, 'POST');
      expect(call.headers['Authorization'], 'OAuth user-1');
      expect(await h.tokens.read('soundcloud'), isNull);
      expect(h.source.authState.status, SourceConnectionStatus.notConnected);
      expect(h.source.isReady, isTrue, reason: 'public browsing still works with the app token');
    });
  });

  test('declares what it implements and explains its limits', () async {
    final h = _Harness();
    final s = await h.init();
    expect(s.id, 'soundcloud');
    expect(s.capabilities, containsAll([SourceCapability.stream, SourceCapability.playlistImport, SourceCapability.oauth]));
    expect(s.capabilities, isNot(contains(SourceCapability.trending)));
    expect(s.limitationsNote, contains('Artist Pro'));
    expect(s.limitationsNote, contains('own queue'));
    expect(s.externalPlaybackUri(_playable('soundcloud:tracks:1')).toString(),
        'https://soundcloud.com/userPermalink/trackPermalink');
    await expectLater(s.trending(), throwsA(isA<UnsupportedSourceOperation>()));
    await s.dispose();
  });
}
