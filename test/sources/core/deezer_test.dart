import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/sources/base/paging.dart';
import 'package:fermata/sources/base/rate_limiter.dart';
import 'package:fermata/sources/deezer/deezer_links.dart';
import 'package:fermata/sources/deezer/deezer_mapper.dart';
import 'package:fermata/sources/deezer/deezer_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

const _quota = '{"error":{"type":"Exception","message":"Quota limit exceeded","code":4}}';

/// Routes public Deezer API paths to recorded fixtures (real responses
/// captured 2026-10-27) and simulates share-link redirects.
Future<http.Response> _deezer(http.Request r) async {
  final u = r.url;
  if (u.host == 'link.deezer.com') {
    if (u.path == '/s/abc') {
      return http.Response('', 302, headers: {'location': 'https://www.deezer.com/us/playlist/908622995?utm_source=x'});
    }
    if (u.path == '/s/profile') {
      return http.Response('', 302, headers: {'location': 'https://www.deezer.com/fr/profile/1687950'});
    }
    return http.Response('', 302, headers: {'location': 'https://www.deezer.com/deezer-links-404'});
  }
  if (u.host == 'deezer.page.link') {
    return http.Response('', 301, headers: {'location': 'https://link.deezer.com/s/abc'});
  }
  if (u.host == 'www.deezer.com') return http.Response('<html>page</html>', 200);
  final p = u.path;
  const routes = {
    '/search': 'deezer_search_tracks.json',
    '/search/artist': 'deezer_search_artists.json',
    '/search/album': 'deezer_search_albums.json',
    '/search/playlist': 'deezer_search_playlists.json',
    '/track/3135556': 'deezer_track.json',
    '/track/isrc:GBDUW0000059': 'deezer_track_isrc.json',
    '/artist/27': 'deezer_artist.json',
    '/artist/27/top': 'deezer_artist_top.json',
    '/artist/27/related': 'deezer_artist_related.json',
    '/artist/27/radio': 'deezer_artist_radio.json',
    '/album/302127': 'deezer_album.json',
    '/album/302127/tracks': 'deezer_album_tracks.json',
    '/playlist/908622995': 'deezer_playlist.json',
    '/playlist/908622995/tracks': 'deezer_playlist_tracks.json',
    '/chart/0/tracks': 'deezer_chart_tracks.json',
    '/chart/132/tracks': 'deezer_chart_tracks.json',
    '/genre': 'deezer_genres.json',
    '/editorial/0/releases': 'deezer_editorial_releases.json',
    '/editorial/0/selection': 'deezer_editorial_selection.json',
    '/user/1687950/playlists': 'deezer_user_playlists.json',
    '/user/me': 'deezer_error_oauth.json',
  };
  final name = routes[p];
  // Deezer answers "not found" with HTTP 200 + error body.
  return jsonResponse(fixture(name ?? 'deezer_error_not_found.json'));
}

/// Virtual time for the rate limiter.
class _FakeTime {
  DateTime now = DateTime.utc(2026, 10, 27, 16, 40);
  Duration slept = Duration.zero;
  DateTime clock() => now;
  Future<void> sleep(Duration d) async {
    slept += d;
    now = now.add(d);
  }
}

void main() {
  late RecordingHttp net;
  late _FakeTime time;
  late DeezerSource source;

  DeezerSource make(RecordingHttp n) => DeezerSource(
    http: n.fermata,
    clock: time.clock,
    limiter: TokenBucketRateLimiter(
      capacity: 50,
      period: const Duration(seconds: 5),
      clock: time.clock,
      sleep: time.sleep,
    ),
  );

  setUp(() {
    time = _FakeTime();
    net = RecordingHttp(_deezer);
    source = make(net);
  });
  tearDown(() => source.dispose());

  test('public, account-less, preview-only source', () {
    expect(source.id, 'deezer');
    expect(source.isReady, isTrue);
    expect(source.authState.status, SourceConnectionStatus.notRequired);
    expect(source.supports(SourceCapability.previewOnly), isTrue);
    expect(source.supports(SourceCapability.externalPlayback), isTrue);
    expect(source.supports(SourceCapability.isrcLookup), isTrue);
    expect(source.supports(SourceCapability.stream), isFalse);
    expect(source.supports(SourceCapability.download), isFalse);
    expect(source.supports(SourceCapability.userLibrary), isFalse, reason: 'new app registration is closed');
    expect(source.limitationsNote, contains('30-second previews'));
    expect(source.limitationsNote, contains('does not accept new developer apps'));
  });

  group('search and paging', () {
    test('tracks: plain query, index/limit, next → cursor, total', () async {
      final page = await source.searchTracks('daft punk', limit: 3);
      expect(net.last.toString(), 'https://api.deezer.com/search?q=daft+punk&index=0&limit=3');
      expect(page.items.map((t) => t.title), [
        'Instant Crush (feat. Julian Casablancas)',
        'Starboy',
        'I Feel It Coming',
      ]);
      expect(page.total, 181);
      expect(page.hasMore, isTrue);
      await source.searchTracks('daft punk', cursor: page.nextCursor, limit: 3);
      expect(net.last.queryParameters['index'], '3');
    });

    test('artists, albums, playlists', () async {
      final artists = await source.searchArtists('daft punk', limit: 3);
      expect(net.last.path, '/search/artist');
      expect(artists.items.first.name, 'Daft Punk');
      expect(artists.items.first.followers, 5227681);
      expect(artists.items.first.permalink.toString(), 'https://www.deezer.com/artist/27');

      final albums = await source.searchAlbums('discovery daft punk', limit: 3);
      expect(net.last.path, '/search/album');
      expect(albums.items.first.title, 'Discovery');
      expect(albums.hasMore, isFalse, reason: 'no "next" in the response');

      final pls = await source.searchPlaylists('chill', limit: 3);
      expect(net.last.path, '/search/playlist');
      expect(pls.items.first.id, 'deezer:1925105902');
      expect(pls.items.first.trackCount, 50);
      expect(pls.items.first.ownerName, isNotEmpty);
    });
  });

  group('mapping', () {
    test('track details, contributors, artwork, attribution link', () async {
      final t = (await source.getTrack('3135556'))!;
      expect(t.id, 'deezer:3135556');
      expect(t.title, 'Harder, Better, Faster, Stronger');
      expect(t.isrc, 'GBDUW0000059');
      expect(t.primaryArtist, 'Daft Punk');
      expect(t.artists, hasLength(1), reason: 'contributors are de-duplicated');
      expect(t.album, 'Discovery');
      expect(t.duration, const Duration(seconds: 226));
      expect(t.trackNumber, 4);
      expect(t.discNumber, 1);
      expect(t.year, 2001);
      expect(t.explicit, isFalse);
      expect(t.artworkUrl.toString(), contains('500x500'));
      expect(t.permalink.toString(), 'https://www.deezer.com/track/3135556');
    });

    test('availability: preview / external only / region restricted; never downloadable', () {
      final p = DeezerMapper.availabilityOf({'readable': true, 'preview': 'https://cdnt-preview.dzcdn.net/x.mp3'});
      expect(p.playback, PlaybackRights.preview);
      expect(p.previewDuration, const Duration(seconds: 30));
      expect(p.offline, OfflineRights.unavailable);
      final e = DeezerMapper.availabilityOf({'readable': true, 'preview': ''});
      expect(e.playback, PlaybackRights.externalOnly);
      expect(e.reason, AvailabilityReason.externalOnly);
      final r = DeezerMapper.availabilityOf({'readable': false, 'preview': 'https://x/y.mp3'});
      expect(r.playback, PlaybackRights.unavailable);
      expect(r.reason, AvailabilityReason.regionRestricted);
    });

    test('playlist artwork from picture fields', () async {
      final detail = await source.getPlaylist('908622995');
      expect(detail.playlist.name, 'En mode 60');
      expect(detail.playlist.artworkUrl.toString(), contains('/images/playlist/'));
      expect(detail.playlist.ownerName, 'Alexandre - Pop & Hits Editor');
      expect(detail.playlist.createdAt, DateTime(2014, 6, 27, 4, 9, 31));
      expect(detail.tracks.total, 50);
    });
  });

  group('catalog', () {
    test('ISRC lookup and not-found handling (error in HTTP 200)', () async {
      final t = await source.lookupByIsrc('gbduw0000059');
      expect(net.last.path, '/track/isrc:GBDUW0000059');
      expect(t!.sourceTrackId, '3135556');
      expect(await source.lookupByIsrc('XX0000000000'), isNull);
      expect(await source.lookupByIsrc('not an isrc'), isNull);
      expect(await source.getTrack('999999999999'), isNull);
      expect(() => source.getTrack('../x'), throwsFormatException);
    });

    test('album tracks are enriched with album metadata', () async {
      final page = await source.albumTracks('302127');
      expect(page.items.map((t) => t.title).take(3), ['One More Time', 'Aerodynamic', 'Digital Love']);
      expect(page.items.first.album, 'Discovery');
      expect(page.items.first.year, 2001);
      expect(page.items.first.artworkUrl, isNotNull);
      expect(page.total, 14);
      expect(page.hasMore, isTrue);
      final paths = net.requests.map((r) => r.url.path).toSet();
      expect(paths, containsAll(['/album/302127', '/album/302127/tracks']));
      // Album metadata is cached for the next page.
      final before = net.requests.length;
      await source.albumTracks('302127', cursor: page.nextCursor);
      expect(net.requests.length - before, 1);
    });

    test('artist top, related artists, related tracks via artist radio', () async {
      final top = await source.artistTopTracks('27', limit: 3);
      expect(net.last.path, '/artist/27/top');
      expect(top.items, hasLength(3));
      final related = await source.relatedArtists('27', limit: 3);
      expect(related.map((a) => a.name), ['Justice', 'Cassius', 'The Chemical Brothers']);
      final similar = await source.relatedTracks('3135556', limit: 3);
      expect(net.last.path, '/artist/27/radio');
      expect(similar.map((t) => t.title), contains('Aloha'));
      expect(similar.length, 3);
    });

    test('chart, genre chart by name, unknown genre', () async {
      final chart = await source.trending(limit: 3);
      expect(net.last.path, '/chart/0/tracks');
      expect(chart.first.title, 'Dracula (with JENNIE)');
      await source.trending(genre: 'pop', limit: 3);
      expect(net.last.path, '/chart/132/tracks');
      expect(await source.genres(), isNot(contains('All')));
      expect(await source.genres(), containsAll(['Pop', 'Rap/Hip Hop']));
      await expectLater(source.trending(genre: 'Polka-Metal'), throwsA(isA<UnsupportedSourceOperation>()));
    });

    test('new releases fall back to the editorial selection when empty', () async {
      final albums = await source.newReleases(limit: 3);
      expect(
        net.requests.map((r) => r.url.path),
        containsAllInOrder(['/editorial/0/releases', '/editorial/0/selection']),
      );
      expect(albums.map((a) => a.title), ['Altered State Police', 'Tranquilo II', 'Kira Krash']);
    });
  });

  group('playlist links', () {
    test('direct link forms', () {
      expect(
        DeezerLinks.parse('https://www.deezer.com/en/playlist/908622995'),
        const DeezerLink(DeezerLinkKind.playlist, '908622995'),
      );
      expect(
        DeezerLinks.parse('www.deezer.com/playlist/908622995?utm=x'),
        const DeezerLink(DeezerLinkKind.playlist, '908622995'),
      );
      expect(DeezerLinks.parse('deezer://www.deezer.com/playlist/1'), const DeezerLink(DeezerLinkKind.playlist, '1'));
      expect(DeezerLinks.parse('https://api.deezer.com/playlist/7'), const DeezerLink(DeezerLinkKind.playlist, '7'));
      expect(
        DeezerLinks.parse('https://www.deezer.com/pt-br/track/3135556'),
        const DeezerLink(DeezerLinkKind.track, '3135556'),
      );
      expect(
        DeezerLinks.parse('https://www.deezer.com/fr/profile/1687950'),
        const DeezerLink(DeezerLinkKind.profile, '1687950'),
      );
      expect(DeezerLinks.parse('https://open.spotify.com/playlist/1'), isNull);
      expect(DeezerLinks.parse('https://evil-deezer.com/playlist/1'), isNull);
    });

    test('getPlaylist by id, page URL and short links (redirects followed)', () async {
      for (final input in [
        '908622995',
        'https://www.deezer.com/us/playlist/908622995',
        'https://link.deezer.com/s/abc',
        'https://deezer.page.link/legacy',
      ]) {
        final d = await source.getPlaylist(input);
        expect(d.playlist.sourcePlaylistId, '908622995', reason: input);
        expect(d.tracks.items, hasLength(3));
        expect(d.tracks.hasMore, isTrue);
      }
      expect(net.requests.where((r) => r.url.host == 'link.deezer.com'), isNotEmpty);
      expect(
        net.requests.where((r) => r.url.host == 'www.deezer.com'),
        isEmpty,
        reason: 'the final page itself is not needed when the id is in the redirect',
      );
    });

    test('dead short links and non-playlist links are rejected', () async {
      await expectLater(source.getPlaylist('https://link.deezer.com/s/dead'), throwsFormatException);
      await expectLater(source.getPlaylist('https://www.deezer.com/track/1'), throwsFormatException);
      await expectLater(source.getPlaylist('hello'), throwsFormatException);
    });

    test('public playlists of a profile, by URL or id (no OAuth)', () async {
      final pls = await source.publicUserPlaylists('https://link.deezer.com/s/profile', max: 3);
      expect(net.last.path, '/user/1687950/playlists');
      expect(pls.map((p) => p.name), ['2024 By Alexandre', '2025 By Alexandre', '2025 Deezer Streams']);
      final byId = await source.publicUserPlaylists('1687950', max: 3);
      expect(byId, hasLength(3));
      await expectLater(source.publicUserPlaylists('https://www.deezer.com/playlist/1'), throwsFormatException);
    });
  });

  group('playback', () {
    test('resolveStream re-fetches the track for a fresh signed preview', () async {
      final stale = const Track(
        sourceId: 'deezer',
        sourceTrackId: '3135556',
        title: 'old',
        extra: {DeezerMapper.extraPreview: 'https://cdnt-preview.dzcdn.net/expired.mp3'},
      );
      final s = await source.resolveStream(stale);
      expect(net.last.path, '/track/3135556');
      expect(s.isPreview, isTrue);
      expect(s.uri.host, 'cdnt-preview.dzcdn.net');
      expect(s.uri.toString(), isNot(contains('expired')));
      expect(s.mimeType, 'audio/mpeg');
      // Clock 16:40 + 12 min policy TTL = 16:52, earlier than the signed 16:53.
      expect(s.expiresAt, DateTime.utc(2026, 10, 27, 16, 52));
    });

    test('preview expiry follows the signed exp when it is earlier', () {
      time.now = DateTime.utc(2026, 10, 27, 16, 45);
      final uri = Uri.parse('https://cdnt-preview.dzcdn.net/a.mp3?hdnea=exp=1793119980~acl=/x~hmac=y');
      expect(source.previewExpiry(uri), DateTime.utc(2026, 10, 27, 16, 53));
      expect(source.previewExpiry(Uri.parse('https://x/a.mp3')), DateTime.utc(2026, 10, 27, 16, 57));
    });

    test('deleted track, external only, never downloadable', () async {
      await expectLater(
        source.resolveStream(const Track(sourceId: 'deezer', sourceTrackId: '1', title: 'x')),
        throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.deleted)),
      );
      final noPreview = RecordingHttp(
        (r) async => jsonResponse(
          '{"id":5,"title":"No preview","readable":true,"preview":"","link":"https://www.deezer.com/track/5"}',
        ),
      );
      final s2 = make(noPreview);
      await expectLater(
        s2.resolveStream(const Track(sourceId: 'deezer', sourceTrackId: '5', title: 'x')),
        throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.externalOnly)),
      );
      final t = (await source.getTrack('3135556'))!;
      expect(source.externalPlaybackUri(t).toString(), 'https://www.deezer.com/track/3135556');
      expect(
        source.externalPlaybackUri(const Track(sourceId: 'deezer', sourceTrackId: '9', title: 'x')).toString(),
        'https://www.deezer.com/track/9',
      );
      expect(await source.authorizeDownload(t), isNull);
    });
  });

  group('error-in-200 and rate limiting', () {
    test('quota error (code 4) backs off and retries, then succeeds', () async {
      var calls = 0;
      final flaky = RecordingHttp((r) async {
        calls++;
        if (calls <= 2) return jsonResponse(_quota);
        return _deezer(r);
      });
      final s = make(flaky);
      final t = await s.getTrack('3135556');
      expect(t, isNotNull);
      expect(calls, 3);
      expect(time.slept, greaterThanOrEqualTo(const Duration(seconds: 10)), reason: '2 × 5 s backoff');
    });

    test('persistent quota error → RateLimitedException', () async {
      final s = make(RecordingHttp((r) async => jsonResponse(_quota)));
      await expectLater(
        s.searchTracks('x'),
        throwsA(isA<RateLimitedException>().having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 5))),
      );
    });

    test('other errors map to ApiException with an HTTP-like status', () async {
      final s = make(RecordingHttp((r) async => jsonResponse(fixture('deezer_error_oauth.json'))));
      await expectLater(s.searchTracks('x'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
      final busy = RecordingHttp(
        (r) async => jsonResponse('{"error":{"type":"Exception","message":"The service is busy","code":700}}'),
      );
      await expectLater(
        make(busy).searchTracks('x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
      );
      expect(busy.requests, hasLength(2), reason: 'busy is retried once');
    });

    test('client-side token bucket keeps ≤ 50 requests per 5 s', () async {
      final start = time.now;
      for (var i = 0; i < 60; i++) {
        await source.api.get('genre');
      }
      expect(net.requests, hasLength(60));
      // 10 requests beyond the burst need ≥ 10 × 100 ms.
      expect(time.now.difference(start), greaterThanOrEqualTo(const Duration(milliseconds: 999)));
    });

    test('cancellation propagates', () async {
      final cancel = CancelToken()..cancel();
      await expectLater(source.searchTracks('x', cancel: cancel), throwsA(isA<OperationCanceledException>()));
    });
  });

  test('cursor helper is shared with other sources', () {
    expect(PageCursor.decodeOffset(PageCursor.encodeOffset(100)), 100);
  });
}
