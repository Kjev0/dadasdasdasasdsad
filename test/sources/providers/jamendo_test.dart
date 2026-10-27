import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/sources/jamendo/jamendo_links.dart';
import 'package:fermata/sources/jamendo/jamendo_mapper.dart';
import 'package:fermata/sources/jamendo/jamendo_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixtures/jamendo_fixtures.dart';
import 'support/helpers.dart';

typedef Route = Future<http.Response> Function(http.Request request);

class _Harness {
  _Harness({SourceCredentials? credentials = const SourceCredentials(clientId: 'jm-id')})
    : credentials = FakeCredentialsStore({'jamendo': ?credentials}) {
    net = RecordingHttp((r) async {
      final handler = routes[r.url.path.replaceFirst('/v3.0/', '')];
      if (handler == null) return jsonResponse(jmError(7, 'Method Not Found'));
      return handler(r);
    });
    source = JamendoSource(http: net.fermata, credentials: this.credentials);
  }

  final FakeCredentialsStore credentials;
  late final RecordingHttp net;
  late final JamendoSource source;
  final Map<String, Route> routes = {};

  Future<JamendoSource> init() async {
    await source.init();
    return source;
  }
}

Track _fresh({bool downloadAllowed = true, String format = 'mp32'}) =>
    JamendoMapper.track(jmTrack(downloadAllowed: downloadAllowed, format: format), audioFormat: format)!;

void main() {
  test('without a client id: credentialsMissing, no requests, MissingCredentialsException', () async {
    final h = _Harness(credentials: null);
    final s = await h.init();
    expect(s.credentialStatus.configured, isFalse);
    expect(s.credentialStatus.missing, ['clientId']);
    expect(s.credentialStatus.helpUrl.toString(), 'https://devportal.jamendo.com/');
    expect(s.authState.status, SourceConnectionStatus.credentialsMissing);
    expect(s.isReady, isFalse);
    final t = _fresh();
    for (final call in <Future<Object?> Function()>[
      () => s.searchTracks('x'),
      () => s.searchArtists('x'),
      () => s.searchAlbums('x'),
      () => s.searchPlaylists('x'),
      () => s.getTrack('1'),
      () => s.getArtist('1'),
      () => s.artistTopTracks('1'),
      () => s.relatedArtists('1'),
      () => s.albumTracks('1'),
      () => s.getPlaylist('1'),
      () => s.relatedTracks('1'),
      () => s.trending(),
      () => s.newReleases(),
      () => s.genres(),
      () => s.resolveStream(t),
      () => s.authorizeDownload(t),
    ]) {
      await expectLater(call(), throwsA(isA<MissingCredentialsException>()));
    }
    expect(h.net.requests, isEmpty);
  });

  test('adding a client id makes the source ready (credentials change event)', () async {
    final h = _Harness(credentials: null);
    final s = await h.init();
    final states = <SourceConnectionStatus>[];
    s.authStateChanges.listen((e) => states.add(e.status));
    await h.credentials.setUserCredentials('jamendo', const SourceCredentials(clientId: 'new'));
    await settle();
    expect(states, [SourceConnectionStatus.notRequired]);
    expect(s.isReady, isTrue);
  });

  group('search & mapping', () {
    test('track search sends client_id, format, both track types, licences, audio format', () async {
      final h = _Harness();
      h.routes['tracks/'] = (r) async => jsonResponse(jmEnvelope([jmTrack(), jmTrack(id: '9', name: 'Single', single: true)]));
      final s = await h.init();
      final page = await s.searchTracks('we are fm', limit: 2);
      final req = h.net.requests.single;
      expect(req.url.toString(), startsWith('https://api.jamendo.com/v3.0/tracks/?'));
      expect(req.url.query, contains('type=single+albumtrack'));
      expect(req.url.query, contains('include=licenses+musicinfo'));
      expect(req.url.queryParameters, containsPair('client_id', 'jm-id'));
      expect(req.url.queryParameters, containsPair('format', 'json'));
      expect(req.url.queryParameters, containsPair('search', 'we are fm'));
      expect(req.url.queryParameters, containsPair('audioformat', 'mp32'));
      expect(req.url.queryParameters, containsPair('limit', '2'));
      expect(req.url.queryParameters, containsPair('offset', '0'));

      final t = page.items.first;
      expect(t.id, 'jamendo:887209');
      expect(t.title, 'Scene 5');
      expect(t.artists.single.name, 'WE ARE FM');
      expect(t.artists.single.sourceArtistId, '376782');
      expect(t.album, 'Season One');
      expect(t.duration, const Duration(seconds: 325));
      expect(t.year, 2011);
      expect(t.genre, 'electronic');
      expect(t.trackNumber, 5);
      expect(t.permalink.toString(), 'https://www.jamendo.com/track/887209');
      expect(t.extra[JamendoMapper.extraLicense], 'http://creativecommons.org/licenses/by-nc-sa/3.0/');
      expect(t.extra[JamendoMapper.extraArtistUrl], 'https://www.jamendo.com/artist/376782');
      expect(t.availability.playback, PlaybackRights.full);
      expect(t.availability.offline, OfflineRights.downloadable);
      final single = page.items[1];
      expect(single.album, isNull);
      expect(page.nextCursor, isNotNull);

      await s.searchTracks('we are fm', limit: 2, cursor: page.nextCursor);
      expect(h.net.requests.last.url.queryParameters['offset'], '2');
    });

    test('downloads are only offered when audiodownload_allowed', () {
      final allowed = _fresh();
      expect(allowed.availability.offline, OfflineRights.downloadable);
      expect(allowed.extra[JamendoMapper.extraDownload], isNotNull);
      final denied = _fresh(downloadAllowed: false);
      expect(denied.availability.playback, PlaybackRights.full);
      expect(denied.availability.offline, OfflineRights.streamOnly);
      expect(denied.extra[JamendoMapper.extraDownload], isNull);
      final silent = JamendoMapper.track({...jmTrack(), 'audio': ''})!;
      expect(silent.availability.reason, AvailabilityReason.notStreamable);
    });

    test('artists, albums, album tracks (documented samples)', () async {
      final h = _Harness();
      h.routes['artists/'] = (r) async => jsonResponse(jmArtists());
      h.routes['albums/'] = (r) async => jsonResponse(jmAlbums());
      h.routes['albums/tracks/'] = (r) async => jsonResponse(jmAlbumTracks());
      final s = await h.init();
      final artists = await s.searchArtists('we are');
      expect(artists.items.single.name, 'WE ARE FM');
      expect(artists.items.single.permalink.toString(), 'https://www.jamendo.com/artist/376782');
      expect(h.net.requests.last.url.queryParameters['namesearch'], 'we are');
      final albums = await s.searchAlbums('season');
      expect(albums.items.map((a) => a.title), ['Season One', 'Season One: Instrumental']);
      expect(albums.items.first.year, 2011);
      final tracks = await s.albumTracks('https://www.jamendo.com/list/a104336');
      expect(h.net.requests.last.url.queryParameters['id'], '104336');
      expect(tracks.items.map((t) => t.trackNumber), [2, 3, 10]);
      expect(tracks.items.first.album, 'Season One');
      expect(tracks.items.first.artists.single.name, 'WE ARE FM');
      expect(tracks.items[1].availability.offline, OfflineRights.streamOnly);
    });

    test('playlists by share link and short link', () async {
      final h = _Harness();
      h.routes['playlists/tracks/'] = (r) async => jsonResponse(jmPlaylistTracks());
      final s = await h.init();
      final detail = await s.getPlaylist('https://jamen.do/l/p218277');
      expect(h.net.requests.single.url.queryParameters['id'], '218277');
      expect(detail.playlist.id, 'jamendo:218277');
      expect(detail.playlist.ownerName, 'hywayace');
      expect(detail.playlist.permalink.toString(), 'https://www.jamendo.com/list/p218277');
      expect(detail.tracks.items.map((t) => t.title), ['One', 'Two']);
      expect(detail.tracks.items[1].availability.offline, OfflineRights.streamOnly);
    });

    test('trending, new releases, related, genres', () async {
      final h = _Harness();
      h.routes['tracks/'] = (r) async => jsonResponse(jmEnvelope([jmTrack()]));
      h.routes['albums/'] = (r) async => jsonResponse(jmAlbums());
      h.routes['tracks/similar/'] = (r) async => jsonResponse(jmEnvelope([jmTrack(id: '5'), jmTrack(id: '887209')]));
      final s = await h.init();
      await s.trending(genre: 'Rock');
      final q = h.net.requests.last.url.queryParameters;
      expect(q['order'], 'popularity_week');
      expect(q['tags'], 'rock');
      expect(q['groupby'], 'artist_id');
      await s.newReleases();
      expect(h.net.requests.last.url.queryParameters['order'], 'releasedate_desc');
      final related = await s.relatedTracks('887209');
      expect(related.map((t) => t.sourceTrackId), ['5']);
      expect(await s.genres(), contains('electronic'));
    });
  });

  group('streams & downloads', () {
    test('a fresh track in the right format streams without a request', () async {
      final h = _Harness();
      final s = await h.init();
      final source = await s.resolveStream(_fresh());
      expect(source.uri.queryParameters['format'], 'mp32');
      expect(source.mimeType, 'audio/mpeg');
      expect(h.net.requests, isEmpty);
    });

    test('another quality re-fetches with that audioformat', () async {
      final h = _Harness();
      h.routes['tracks/'] = (r) async => jsonResponse(
        jmEnvelope([jmTrack(format: r.url.queryParameters['audioformat']!)]),
      );
      final s = await h.init();
      final low = await s.resolveStream(_fresh(), quality: AudioQuality.low);
      expect(h.net.requests.single.url.queryParameters['audioformat'], 'mp31');
      expect(h.net.requests.single.url.queryParameters['id'], '887209');
      expect(low.uri.queryParameters['format'], 'mp31');
      final lossless = await s.resolveStream(_fresh(), quality: AudioQuality.lossless);
      expect(lossless.mimeType, 'audio/flac');
    });

    test('lossless falls back to mp32 when no flac is offered; deleted tracks are unplayable', () async {
      final h = _Harness();
      h.routes['tracks/'] = (r) async {
        if (r.url.queryParameters['id'] == '404') return jsonResponse(jmEnvelope([]));
        final f = r.url.queryParameters['audioformat']!;
        return jsonResponse(jmEnvelope([f == 'flac' ? {...jmTrack(), 'audio': ''} : jmTrack(format: f)]));
      };
      final s = await h.init();
      final source = await s.resolveStream(_fresh(), quality: AudioQuality.lossless);
      expect(source.uri.queryParameters['format'], 'mp32');
      expect(h.net.requests.map((r) => r.url.queryParameters['audioformat']), ['flac', 'mp32']);
      await expectLater(
        s.resolveStream(const Track(sourceId: 'jamendo', sourceTrackId: '404', title: 'gone')),
        throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.deleted)),
      );
    });

    test('authorizeDownload re-checks and returns audiodownload only when allowed', () async {
      final h = _Harness();
      var allowed = true;
      h.routes['tracks/'] = (r) async => jsonResponse(jmEnvelope([jmTrack(downloadAllowed: allowed)]));
      final s = await h.init();
      final auth = await s.authorizeDownload(_fresh());
      expect(auth?.uri.toString(), 'https://prod-1.storage.jamendo.com/download/track/887209/mp32/');
      expect(auth?.suggestedFileExtension, 'mp3');
      expect(h.net.requests.single.url.queryParameters['audiodlformat'], 'mp32');
      allowed = false; // the artist changed their mind
      expect(await s.authorizeDownload(_fresh()), isNull);
    });
  });

  group('errors', () {
    test('code 6 → RateLimitedException; code 5 → rejected client id', () async {
      final h = _Harness();
      var code = 6;
      h.routes['tracks/'] = (r) async => jsonResponse(jmError(code, 'Error'));
      final s = await h.init();
      await expectLater(s.searchTracks('x'), throwsA(isA<RateLimitedException>()));
      code = 5;
      await expectLater(
        s.searchTracks('x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    });

    test('error documents with an HTTP error status are mapped too', () async {
      final h = _Harness();
      h.routes['tracks/'] = (r) async => jsonResponse(jmError(6, 'Rate Limit Exceeded'), status: 429);
      final s = await h.init();
      await expectLater(s.searchTracks('x'), throwsA(isA<RateLimitedException>()));
    });
  });

  test('links', () {
    expect(JamendoLinks.parse('https://www.jamendo.com/track/1886257/one-more-time'), const JamendoLink(JamendoLinkKind.track, '1886257'));
    expect(JamendoLinks.parse('https://www.jamendo.com/en/album/104336/season-one'), const JamendoLink(JamendoLinkKind.album, '104336'));
    expect(JamendoLinks.parse('jamendo.com/artist/376782/we-are-fm'), const JamendoLink(JamendoLinkKind.artist, '376782'));
    expect(JamendoLinks.parse('https://www.jamendo.com/playlist/500608900/chill'), const JamendoLink(JamendoLinkKind.playlist, '500608900'));
    expect(JamendoLinks.parse('https://www.jamendo.com/list/p218277'), const JamendoLink(JamendoLinkKind.playlist, '218277'));
    expect(JamendoLinks.parse('https://jamen.do/l/a104336'), const JamendoLink(JamendoLinkKind.album, '104336'));
    expect(JamendoLinks.parse('https://jamen.do/a/376782'), const JamendoLink(JamendoLinkKind.artist, '376782'));
    expect(JamendoLinks.parse('https://jamen.do/t/887202'), const JamendoLink(JamendoLinkKind.track, '887202'));
    expect(JamendoLinks.parse('https://example.com/track/1'), isNull);
    expect(JamendoLinks.idOf('218277', JamendoLinkKind.playlist), '218277');
    expect(JamendoLinks.idOf('https://jamen.do/l/a104336', JamendoLinkKind.playlist), isNull);
  });

  test('capabilities and notes', () async {
    final s = await _Harness().init();
    expect(s.capabilities, containsAll([SourceCapability.stream, SourceCapability.download, SourceCapability.trending]));
    expect(s.capabilities, isNot(contains(SourceCapability.oauth)));
    expect(s.limitationsNote, contains('Creative Commons'));
    expect(s.externalPlaybackUri(_fresh()).toString(), 'https://www.jamendo.com/track/887209');
    await s.dispose();
  });
}
