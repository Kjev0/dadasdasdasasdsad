import 'package:fermata/core/contracts/auth.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/sources/auth/auth.dart';
import 'package:fermata/sources/youtube/youtube_api.dart';
import 'package:fermata/sources/youtube/youtube_links.dart';
import 'package:fermata/sources/youtube/youtube_mapper.dart';
import 'package:fermata/sources/youtube/youtube_metadata.dart';
import 'package:fermata/sources/youtube/youtube_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixtures/youtube_fixtures.dart';
import 'support/helpers.dart';

typedef Route = Future<http.Response> Function(http.Request request);

const _keyOnly = SourceCredentials(apiKey: 'yt-key');
const _oauthOnly = SourceCredentials(clientId: 'yt-client.apps.googleusercontent.com', clientSecret: 'yt-secret');
const _both = SourceCredentials(clientId: 'yt-client.apps.googleusercontent.com', clientSecret: 'yt-secret', apiKey: 'yt-key');

const _v1 = 'aaaaaaaaaa1';
const _v2 = 'bbbbbbbbbb2';
const _v3 = 'ccccccccccc';

class _Harness {
  _Harness({SourceCredentials? credentials = _keyOnly, HostOs os = HostOs.linux, int searchCallsPerDay = 100})
    : credentials = FakeCredentialsStore({'youtube': ?credentials}) {
    net = RecordingHttp(_route);
    source = YouTubeSource(
      http: net.fermata,
      oauth: oauth,
      tokens: tokens,
      credentials: this.credentials,
      platform: PlatformInfo(os: os),
      searchCallsPerDay: searchCallsPerDay,
    );
  }

  final FakeCredentialsStore credentials;
  final tokens = InMemoryTokenStore();
  final oauth = FakeOAuthClient();
  late final RecordingHttp net;
  late final YouTubeSource source;
  final Map<String, Route> routes = {};
  final accepted = <String>{'user-1', 'user-2'};

  Future<http.Response> _route(http.Request r) async {
    final auth = r.headers['Authorization'];
    if (auth != null && !accepted.contains(auth.replaceFirst('Bearer ', ''))) {
      return jsonResponse({'error': {'code': 401, 'message': 'Invalid Credentials'}}, status: 401);
    }
    if (auth == null && r.url.queryParameters['key'] != 'yt-key') {
      return jsonResponse(ytError(400, 'badRequest', domain: 'global'), status: 400);
    }
    final handler = routes[r.url.path.replaceFirst('/youtube/v3/', '')];
    if (handler == null) return jsonResponse(ytError(404, 'notFound', domain: 'youtube.common'), status: 404);
    return handler(r);
  }

  void videosRoute(Map<String, Map<String, Object?>> videos) {
    routes['videos'] = (r) async {
      final ids = r.url.queryParameters['id']!.split(',');
      return jsonResponse(ytList('videoListResponse', [for (final id in ids) ?videos[id]]));
    };
  }

  Future<YouTubeSource> connect() async {
    routes.putIfAbsent('channels', () => (r) async => jsonResponse(ytMyChannel()));
    await source.init();
    await source.connect();
    return source;
  }
}

void main() {
  group('credentials', () {
    test('nothing configured: credentialsMissing, both alternatives listed, no requests', () async {
      final h = _Harness(credentials: null);
      final s = h.source;
      await s.init();
      expect(s.credentialStatus.configured, isFalse);
      expect(s.credentialStatus.missing, ['apiKey', 'clientId']);
      expect(s.credentialStatus.helpUrl.toString(), 'https://console.cloud.google.com/apis/credentials');
      expect(s.authState.status, SourceConnectionStatus.credentialsMissing);
      expect(s.isReady, isFalse);
      for (final call in <Future<Object?> Function()>[
        () => s.searchTracks('x'),
        () => s.getTrack(_v1),
        () => s.getPlaylist('PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf'),
        () => s.userPlaylists(),
        () => s.userLikedTracks(),
        () => s.connect(),
      ]) {
        await expectLater(call(), throwsA(isA<MissingCredentialsException>()));
      }
      expect(h.net.requests, isEmpty);
    });

    test('API key only: ready for search, not connected, library needs a client id', () async {
      final h = _Harness();
      final s = h.source;
      await s.init();
      expect(s.credentialStatus.configured, isTrue);
      expect(s.authState.status, SourceConnectionStatus.notConnected);
      expect(s.isReady, isTrue);
      await expectLater(s.userPlaylists(), throwsA(isA<MissingCredentialsException>()));
      expect(h.net.requests, isEmpty);
    });

    test('OAuth client only: library needs a connection; public calls need it too', () async {
      final h = _Harness(credentials: _oauthOnly);
      await h.source.init();
      expect(h.source.isReady, isFalse);
      await expectLater(h.source.userPlaylists(), throwsA(isA<AuthRequiredException>()));
      await expectLater(h.source.searchTracks('x'), throwsA(isA<AuthRequiredException>()));
      expect(h.net.requests, isEmpty);
    });

    test('connect is desktop-only: Android explains why', () async {
      final h = _Harness(credentials: _both, os: HostOs.android);
      await h.source.init();
      await expectLater(
        h.source.connect(),
        throwsA(isA<UnsupportedSourceOperation>().having((e) => e.message, 'message', contains('Android'))),
      );
      expect(h.oauth.authorizeCalls, 0);
    });

    test('connect on desktop: Google endpoints, youtube.readonly, loopback, PKCE', () async {
      final h = _Harness(credentials: _both);
      final s = await h.connect();
      final config = h.oauth.lastConfig!;
      expect(config.authorizeEndpoint.toString(), 'https://accounts.google.com/o/oauth2/v2/auth');
      expect(config.tokenEndpoint.toString(), 'https://oauth2.googleapis.com/token');
      expect(config.scopes, ['https://www.googleapis.com/auth/youtube.readonly']);
      expect(config.redirectStrategy, RedirectStrategy.loopback);
      expect(config.usePkce, isTrue);
      expect(config.clientSecret, 'yt-secret');
      expect(s.authState.accountName, 'Ada');
      expect(h.net.to('/youtube/v3/channels').single.headers['Authorization'], 'Bearer user-1');
    });
  });

  group('search', () {
    test('music-category video search with the API key, durations from videos', () async {
      final h = _Harness();
      h.routes['search'] = (r) async => jsonResponse(
        ytList(
          'searchListResponse',
          [ytSearchResult(_v1, title: 'Carly Rae Jepsen - Cut To The Feeling &amp; More'), ytSearchResult(_v2)],
          next: 'CAIQAA',
          total: 1000000,
        ),
      );
      h.videosRoute({_v1: ytVideo(_v1, duration: 'PT3M28S')});
      final s = h.source;
      await s.init();

      final page = await s.searchTracks('cut to the feeling', limit: 2);
      final q = h.net.to('/youtube/v3/search').single.url.queryParameters;
      expect(q, {
        'part': 'snippet',
        'type': 'video',
        'videoCategoryId': '10',
        'q': 'cut to the feeling',
        'maxResults': '2',
        'key': 'yt-key',
      });
      expect(h.net.to('/youtube/v3/videos').single.url.queryParameters['id'], '$_v1,$_v2');
      expect(page.items, hasLength(2));
      final first = page.items.first;
      expect(first.sourceTrackId, _v1);
      expect(first.title, 'Cut To The Feeling');
      expect(first.artists.single.name, 'Carly Rae Jepsen');
      expect(first.duration, const Duration(minutes: 3, seconds: 28));
      expect(first.availability.playback, PlaybackRights.externalOnly);
      expect(first.artworkUrl.toString(), 'https://i.ytimg.com/vi/$_v1/hqdefault.jpg', reason: '480 px serves a 500 px target');
      expect(first.permalink.toString(), 'https://www.youtube.com/watch?v=$_v1');
      // Not returned by videos → search snippet (unescaped), no duration.
      expect(page.items[1].duration, isNull);
      expect(page.total, 1000000);

      await s.searchTracks('cut to the feeling', cursor: page.nextCursor);
      expect(h.net.to('/youtube/v3/search').last.url.queryParameters['pageToken'], 'CAIQAA');
    });

    test('the daily search budget is enforced locally', () async {
      final h = _Harness(searchCallsPerDay: 1);
      h.routes['search'] = (r) async => jsonResponse(ytList('searchListResponse', []));
      await h.source.init();
      await h.source.searchTracks('a');
      expect(h.source.api.searchCallsRemaining, 0);
      await expectLater(h.source.searchTracks('b'), throwsA(isA<RateLimitedException>()));
      expect(h.net.to('/youtube/v3/search'), hasLength(1));
    });

    test('quotaExceeded → RateLimitedException until the Pacific-time reset, then no more requests', () async {
      final h = _Harness();
      h.routes['search'] = (r) async => jsonResponse(ytError(403, 'quotaExceeded'), status: 403);
      await h.source.init();
      await expectLater(
        h.source.searchTracks('x'),
        throwsA(isA<RateLimitedException>().having((e) => e.retryAfter, 'retryAfter', isNotNull)),
      );
      final count = h.net.requests.length;
      await expectLater(h.source.getTrack(_v1), throwsA(isA<RateLimitedException>()));
      expect(h.net.requests.length, count);
    });

    test('getTrack via a music.youtube.com link; unknown → null', () async {
      final h = _Harness();
      h.videosRoute({_v1: ytVideo(_v1)});
      await h.source.init();
      expect((await h.source.getTrack('https://music.youtube.com/watch?v=$_v1&feature=share'))?.sourceTrackId, _v1);
      expect(await h.source.getTrack(_v2), isNull);
      expect(await h.source.getTrack('not a video'), isNull);
    });
  });

  group('playlists', () {
    const list = 'PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf';

    test('getPlaylist pages with pageToken cursors; deleted/private entries are unavailable', () async {
      final h = _Harness();
      h.routes['playlists'] = (r) async => jsonResponse(ytList('playlistListResponse', [ytPlaylist(list, count: 4)]));
      h.routes['playlistItems'] = (r) async => r.url.queryParameters['pageToken'] == null
          ? jsonResponse(
              ytList('playlistItemListResponse', [
                ytPlaylistItem(_v1),
                ytPlaylistItem(_v2, title: 'Deleted video', owner: null, privacy: 'privacyStatusUnspecified'),
                ytPlaylistItem(_v3, title: 'Private video', owner: null, privacy: 'private'),
              ], next: 'EAAaBlBUOkNESQ', total: 4),
            )
          : jsonResponse(ytList('playlistItemListResponse', [ytPlaylistItem('ddddddddddd', title: 'Song')], total: 4));
      h.videosRoute({
        _v1: ytVideo(_v1, description: ytArtTrackDescription, channel: 'Carly Rae Jepsen - Topic', title: 'Cut To The Feeling'),
        'ddddddddddd': ytVideo('ddddddddddd', title: 'Daft Punk - One More Time (Official Audio)', channel: 'Daft Punk'),
      });
      final s = h.source;
      await s.init();

      final first = await s.getPlaylist('https://music.youtube.com/playlist?list=$list&si=abc');
      expect(first.playlist.id, 'youtube:$list');
      expect(first.playlist.name, 'Road trip');
      expect(first.playlist.trackCount, 4);
      expect(first.tracks.total, 4);
      final art = first.tracks.items[0];
      expect(art.title, 'Cut To The Feeling');
      expect(art.artists.single.name, 'Carly Rae Jepsen');
      expect(art.album, 'Cut To The Feeling');
      expect(art.year, 2017);
      expect(first.tracks.items[1].availability.reason, AvailabilityReason.deleted);
      expect(first.tracks.items[2].availability.reason, AvailabilityReason.private);
      expect(h.net.to('/youtube/v3/videos').first.url.queryParameters['id'], _v1);

      final second = await s.getPlaylist('ignored', cursor: first.tracks.nextCursor);
      expect(second.tracks.items.single.title, 'One More Time');
      expect(second.tracks.items.single.artists.single.name, 'Daft Punk');
      expect(second.tracks.hasMore, isFalse);
      expect(h.net.to('/youtube/v3/playlistItems').last.url.queryParameters['pageToken'], 'EAAaBlBUOkNESQ');
    });

    test('unknown playlist → 404 ApiException; mixes are explained', () async {
      final h = _Harness();
      h.routes['playlists'] = (r) async => jsonResponse(ytList('playlistListResponse', []));
      await h.source.init();
      await expectLater(h.source.getPlaylist(list), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
      await expectLater(
        h.source.getPlaylist('https://www.youtube.com/watch?v=$_v1&list=RD$_v1'),
        throwsA(isA<UnsupportedSourceOperation>()),
      );
    });

    test('connected: userPlaylists uses mine=true with the OAuth token (no key)', () async {
      final h = _Harness(credentials: _both);
      h.routes['playlists'] = (r) async => r.url.queryParameters['pageToken'] == null
          ? jsonResponse(ytList('playlistListResponse', [ytPlaylist(list)], next: 'NEXT'))
          : jsonResponse(ytList('playlistListResponse', [ytPlaylist('PL2222222222222222', title: 'Two')]));
      final s = await h.connect();
      final playlists = await s.userPlaylists();
      expect(playlists.map((p) => p.name), ['Road trip', 'Two']);
      final call = h.net.to('/youtube/v3/playlists').first;
      expect(call.url.queryParameters['mine'], 'true');
      expect(call.url.queryParameters.containsKey('key'), isFalse);
      expect(call.headers['Authorization'], 'Bearer user-1');
    });

    test('connected: liked music via the channel likes playlist, non-music videos skipped', () async {
      final h = _Harness(credentials: _both);
      h.routes['playlistItems'] = (r) async {
        expect(r.url.queryParameters['playlistId'], 'LL');
        return jsonResponse(ytList('playlistItemListResponse', [ytPlaylistItem(_v1, playlistId: 'LL'), ytPlaylistItem(_v2, playlistId: 'LL')]));
      };
      h.videosRoute({_v1: ytVideo(_v1), _v2: ytVideo(_v2, title: 'How to bake bread', categoryId: '26')});
      final s = await h.connect();
      final liked = await s.userLikedTracks();
      expect(liked.items.map((t) => t.sourceTrackId), [_v1]);
      expect(liked.hasMore, isFalse);
    });

    test('401 → refresh → retry via the OAuth session', () async {
      final h = _Harness(credentials: _both);
      h.routes['playlists'] = (r) async => jsonResponse(ytList('playlistListResponse', []));
      final s = await h.connect();
      h.accepted.remove('user-1');
      await s.userPlaylists();
      expect(h.oauth.refreshCalls, 1);
      expect(h.net.to('/youtube/v3/playlists').map((r) => r.headers['Authorization']), ['Bearer user-1', 'Bearer user-2']);
    });
  });

  test('playback is external only', () async {
    final h = _Harness();
    final s = h.source;
    final t = YouTubeMapper.video(ytVideo(_v1))!;
    expect(s.externalPlaybackUri(t).toString(), 'https://music.youtube.com/watch?v=$_v1');
    await expectLater(
      s.resolveStream(t),
      throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.externalOnly)),
    );
    expect(await s.authorizeDownload(t), isNull);
    expect(s.capabilities, isNot(contains(SourceCapability.stream)));
    expect(s.limitationsNote, contains('100 searches per day'));
  });

  group('metadata parsing', () {
    YouTubeVideoMetadata p(String title, [String channel = '']) => YouTubeMetadataParser.parse(title, channelTitle: channel);

    test('"Artist - Title (Official Video)" styles', () {
      final cases = <String, (String, List<String>)>{
        'Daft Punk - One More Time (Official Video)': ('One More Time', ['Daft Punk']),
        'Daft Punk – Around the World [Official Music Video]': ('Around the World', ['Daft Punk']),
        'Adele - Hello (Official Lyric Video) [4K]': ('Hello', ['Adele']),
        'Rihanna - Diamonds (Remix) (Official Audio)': ('Diamonds (Remix)', ['Rihanna']),
        'Oasis - Wonderwall (Live at Knebworth)': ('Wonderwall (Live at Knebworth)', ['Oasis']),
        'Calvin Harris - Feel So Close (feat. Someone)': ('Feel So Close', ['Calvin Harris', 'Someone']),
        'Major Lazer ft. MØ - Lean On | Official Video': ('Lean On', ['Major Lazer', 'MØ']),
        'Dua Lipa x BLACKPINK - Kiss and Make Up (Visualizer)': ('Kiss and Make Up', ['Dua Lipa', 'BLACKPINK']),
        'PSY "Gangnam Style" M/V': ('Gangnam Style', ['PSY']),
        'Coldplay - Yellow Official Video': ('Yellow', ['Coldplay']),
        'Bon Iver - Holocene HD': ('Holocene', ['Bon Iver']),
        'Simon & Garfunkel - The Sound of Silence (Audio)': ('The Sound of Silence', ['Simon & Garfunkel']),
      };
      cases.forEach((input, expected) {
        final m = p(input, 'Some Channel');
        expect(m.title, expected.$1, reason: input);
        expect(m.artists, expected.$2, reason: input);
      });
    });

    test('channel names: Topic, VEVO, Official', () {
      final topic = p('Cut To The Feeling', 'Carly Rae Jepsen - Topic');
      expect(topic.title, 'Cut To The Feeling');
      expect(topic.artists, ['Carly Rae Jepsen']);
      expect(topic.artistFromChannel, isTrue);
      expect(p('Shake It Off (Official Video)', 'TaylorSwiftVEVO').artists, ['Taylor Swift']);
      expect(p('Bad Guy', 'Billie Eilish Official').artists, ['Billie Eilish']);
      expect(YouTubeMetadataParser.channelArtist('ArianaGrandeVevo'), 'Ariana Grande');
    });

    test('auto-generated art track descriptions', () {
      final m = YouTubeMetadataParser.parse(
        'Cut To The Feeling',
        channelTitle: 'Carly Rae Jepsen - Topic',
        description: ytArtTrackDescription,
      );
      expect(m.title, 'Cut To The Feeling');
      expect(m.artists, ['Carly Rae Jepsen']);
      expect(m.album, 'Cut To The Feeling');
      expect(m.year, 2017);
    });

    test('ISO-8601 durations', () {
      expect(YouTubeMetadataParser.parseDuration('PT4M13S'), const Duration(minutes: 4, seconds: 13));
      expect(YouTubeMetadataParser.parseDuration('PT1H2M3S'), const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(YouTubeMetadataParser.parseDuration('PT45S'), const Duration(seconds: 45));
      expect(YouTubeMetadataParser.parseDuration('P1DT2H'), const Duration(days: 1, hours: 2));
      expect(YouTubeMetadataParser.parseDuration('P0D'), isNull);
      expect(YouTubeMetadataParser.parseDuration('PT'), isNull);
      expect(YouTubeMetadataParser.parseDuration('4:13'), isNull);
    });
  });

  group('links', () {
    test('video and playlist ids', () {
      expect(YouTubeLinks.videoId('https://www.youtube.com/watch?v=$_v1&t=42s'), _v1);
      expect(YouTubeLinks.videoId('https://youtu.be/$_v1?si=x'), _v1);
      expect(YouTubeLinks.videoId('https://music.youtube.com/watch?v=$_v1'), _v1);
      expect(YouTubeLinks.videoId('youtube.com/shorts/$_v1'), _v1);
      expect(YouTubeLinks.videoId(_v1), _v1);
      expect(YouTubeLinks.videoId('https://example.com/watch?v=$_v1'), isNull);
      const list = 'PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf';
      expect(YouTubeLinks.playlistId('https://www.youtube.com/playlist?list=$list'), list);
      expect(YouTubeLinks.playlistId('https://music.youtube.com/playlist?list=$list&si=abc'), list);
      expect(YouTubeLinks.playlistId('https://www.youtube.com/watch?v=$_v1&list=$list&index=2'), list);
      expect(YouTubeLinks.playlistId('https://music.youtube.com/browse/VL$list'), list);
      expect(YouTubeLinks.playlistId('OLAK5uy_kXyZ0123456789abcdefghijklmnopq'), 'OLAK5uy_kXyZ0123456789abcdefghijklmnopq');
      expect(YouTubeLinks.playlistId(list), list);
      expect(YouTubeLinks.playlistId(_v1), isNull, reason: 'an 11-character id is a video');
    });
  });

  test('Pacific-time quota reset', () {
    // 2026-10-27 12:00 UTC = 05:00 PDT → reset at 07:00 UTC next day (19 h).
    expect(YouTubeApi.untilPacificMidnight(DateTime.utc(2026, 10, 27, 12)), const Duration(hours: 19));
    // 2026-12-01 12:00 UTC = 04:00 PST → reset at 08:00 UTC next day (20 h).
    expect(YouTubeApi.untilPacificMidnight(DateTime.utc(2026, 12, 1, 12)), const Duration(hours: 20));
    expect(YouTubeApi.pacificDate(DateTime.utc(2026, 10, 28, 6, 59)), '2026-10-27');
    expect(YouTubeApi.pacificDate(DateTime.utc(2026, 10, 28, 7, 1)), '2026-10-28');
  });

  test('token store is never touched without a connection', () async {
    final tokens = _CountingTokens();
    final s = YouTubeSource(
      http: RecordingHttp((r) async => http.Response('', 500)).fermata,
      oauth: FakeOAuthClient(),
      tokens: tokens,
      credentials: FakeCredentialsStore(),
      platform: const PlatformInfo(os: HostOs.linux),
    );
    await s.init();
    expect(tokens.writes, 0);
  });
}

class _CountingTokens extends InMemoryTokenStore implements TokenStore {
  int writes = 0;

  @override
  Future<void> write(String sourceId, OAuthToken token) async {
    writes++;
    await super.write(sourceId, token);
  }
}
