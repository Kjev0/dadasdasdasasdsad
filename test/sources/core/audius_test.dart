import 'dart:convert';
import 'dart:io';

import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/sources/audius/audius_mapper.dart';
import 'package:fermata/sources/audius/audius_source.dart';
import 'package:fermata/sources/auth/credentials_store_impl.dart';
import 'package:fermata/sources/auth/secure_storage.dart';
import 'package:fermata/sources/base/paging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

/// Routes Audius API paths to the recorded fixtures (real responses
/// captured 2026-10-27).
Future<http.Response> _audius(http.Request r) async {
  final p = r.url.path;
  final q = r.url.queryParameters;
  String? name;
  if (p == '/v1/tracks/search') name = 'audius_search_tracks.json';
  if (p == '/v1/users/search') name = 'audius_search_users.json';
  if (p == '/v1/playlists/search') name = 'audius_search_playlists.json';
  if (p == '/v1/search/full') name = 'audius_search_albums.json';
  if (p == '/v1/tracks' && q.containsKey('isrc')) {
    return q['isrc'] == 'QZQAY2630197' ? jsonResponse(fixture('audius_tracks_isrc.json')) : jsonResponse('{"data":[]}');
  }
  if (p == '/v1/tracks' && q.containsKey('id')) name = 'audius_tracks_bulk.json';
  if (p == '/v1/tracks/2jyld83') name = 'audius_track.json';
  if (p == '/v1/tracks/zzzzzzz') return jsonResponse(fixture('audius_error_not_found.json'), status: 400);
  if (p == '/v1/tracks/trending') name = 'audius_trending.json';
  if (p == '/v1/genres/popular') name = 'audius_genres.json';
  if (p == '/v1/playlists/DOPRl') name = 'audius_playlist.json';
  if (p == '/v1/playlists/DOPRl/tracks') name = 'audius_playlist_tracks.json';
  if (p == '/v1/playlists/new-releases') name = 'audius_new_releases.json';
  if (p == '/v1/resolve') name = 'audius_playlist.json'; // the client follows the 302 transparently
  if (p == '/v1/users/BR1QY') name = 'audius_user.json';
  if (p == '/v1/users/BR1QY/related') name = 'audius_related_users.json';
  if (RegExp(r'^/v1/users/[^/]+/tracks$').hasMatch(p)) name = 'audius_user_tracks.json';
  if (name == null) return jsonResponse('{"code":404,"error":"not mocked: $p"}', status: 404);
  return jsonResponse(fixture(name));
}

void main() {
  late RecordingHttp net;
  late AudiusSource source;

  setUp(() {
    net = RecordingHttp(_audius);
    source = AudiusSource(http: net.fermata);
  });
  tearDown(() => source.dispose());

  test('open API: no account, always ready, honest capabilities', () {
    expect(source.id, 'audius');
    expect(source.isReady, isTrue);
    expect(source.authState.status, SourceConnectionStatus.notRequired);
    expect(source.credentialStatus.configured, isTrue);
    expect(source.supports(SourceCapability.stream), isTrue);
    expect(source.supports(SourceCapability.download), isTrue);
    expect(source.supports(SourceCapability.userLibrary), isFalse);
    expect(source.supports(SourceCapability.oauth), isFalse);
    expect(source.limitationsNote, isNotEmpty);
  });

  group('request building', () {
    test('base URL, app_name on every request, offset/limit paging', () async {
      final page = await source.searchTracks(' lofi ', limit: 3);
      final u = net.last;
      expect(u.scheme, 'https');
      expect(u.host, 'api.audius.co');
      expect(u.path, '/v1/tracks/search');
      expect(u.queryParameters, {'query': 'lofi', 'limit': '3', 'offset': '0', 'app_name': 'Fermata'});
      expect(net.requests.last.headers.containsKey('x-api-key'), isFalse);
      expect(page.items, hasLength(3));
      expect(page.hasMore, isTrue, reason: 'a full page implies more');
      await source.searchTracks('lofi', cursor: page.nextCursor, limit: 3);
      expect(net.last.queryParameters['offset'], '3');
    });

    test('optional API key from credentials → x-api-key header and stream api_key', () async {
      final tmp = await Directory.systemTemp.createTemp('fermata_audius');
      addTearDown(() => tmp.delete(recursive: true));
      final creds = CredentialsStoreImpl(
        configFile: File('${tmp.path}/c.json'),
        secureStorage: InMemoryKeyValueStore(),
        buildTime: const {},
      );
      await creds.init();
      await creds.setUserCredentials('audius', const SourceCredentials(apiKey: 'my-key'));
      final keyed = AudiusSource(http: net.fermata, credentials: creds);
      await keyed.searchTracks('lofi');
      expect(net.requests.last.headers['x-api-key'], 'my-key');
      expect(keyed.credentialStatus.origin, CredentialOrigin.userEntered);
      final track = (await keyed.getTrack('2jyld83'))!;
      final stream = await keyed.resolveStream(track);
      expect(stream.uri.queryParameters['api_key'], 'my-key');
      final dl = await keyed.authorizeDownload(track);
      expect(dl!.headers['x-api-key'], 'my-key');
    });

    test('albums via full search, users, playlists', () async {
      final albums = await source.searchAlbums('ep', limit: 3);
      expect(net.last.path, '/v1/search/full');
      expect(net.last.queryParameters['kind'], 'albums');
      expect(albums.items.map((a) => a.title), ['REBUILD (EP)', 'Never Enough - EP', 'Things. EP']);
      expect(albums.items[1].artists.single.name, 'Disclosure');

      final users = await source.searchArtists('lofi', limit: 3);
      final drel = users.items.first;
      expect(drel.sourceArtistId, 'BR1QY');
      expect(drel.name, 'LoFi DREL');
      expect(drel.permalink.toString(), 'https://audius.co/lofi_drel');
      expect(drel.followers, 69);
      expect(drel.avatarUrl.toString(), endsWith('480x480.jpg'));

      final pls = await source.searchPlaylists('chill', limit: 3);
      expect(pls.items.first.id, 'audius:Dv9QV');
      expect(pls.items.first.name, 'MONKEYS CHILL');
      expect(pls.items.first.trackCount, 10);
    });
  });

  group('mapping', () {
    late Map<String, Track> byId;
    setUp(() {
      byId = {
        for (final t in AudiusMapper.tracks((fixtureJson('audius_tracks_bulk.json') as Map)['data']))
          t.sourceTrackId: t,
      };
    });

    test('track fields, artwork size, permalink attribution', () {
      final t = byId['2jyld83']!;
      expect(t.id, 'audius:2jyld83');
      expect(t.title, 'D3PRT  - This ones for you');
      expect(t.artists.single, const ArtistRef('Electronyze Me', sourceArtistId: 'DBJ1j'));
      expect(t.duration, const Duration(seconds: 279));
      expect(t.genre, 'Dubstep');
      expect(t.year, 2026);
      expect(t.artworkUrl.toString(), endsWith('/480x480.jpg'));
      expect(t.permalink.toString(), 'https://audius.co/ElectronyzeMe/d3prt-this-ones-for-you');
      expect(byId['mzXmz1']!.isrc, 'QZQAY2630197');
      expect(byId['3AmB2yE']!.isrc, isNull, reason: 'empty strings are not ISRCs');
      expect(
        AudiusMapper.artworkOf({'150x150': 'https://a/1', '1000x1000': 'https://a/3'}, targetPx: 1000).toString(),
        'https://a/3',
      );
    });

    test('availability: artist-enabled download → downloadable', () {
      final a = byId['2jyld83']!.availability;
      expect(a.playback, PlaybackRights.full);
      expect(a.offline, OfflineRights.downloadable);
      expect(byId['2jyld83']!.extra[AudiusMapper.extraOrigExt], 'wav');
    });

    test('availability: download-gated → stream only', () {
      final a = byId['zz0MEGP']!.availability;
      expect(a.playback, PlaybackRights.full);
      expect(a.offline, OfflineRights.streamOnly);
      expect(byId['oRJBNg7']!.availability.offline, OfflineRights.streamOnly);
      expect(byId['mzXmz1']!.availability.offline, OfflineRights.streamOnly, reason: 'not marked downloadable');
    });

    test('availability: purchase-gated stream → preview / subscription_required', () {
      final a = byId['3AmB2yE']!.availability;
      expect(a.playback, PlaybackRights.preview);
      expect(a.reason, AvailabilityReason.subscriptionRequired);
      expect(a.previewDuration, const Duration(seconds: 30));
      expect(a.offline, OfflineRights.unavailable);
      final noPreview = AudiusMapper.availabilityOf({
        'is_stream_gated': true,
        'access': {'stream': false, 'download': false},
        'stream_conditions': {'follow_user_id': 1},
      });
      expect(noPreview.playback, PlaybackRights.unavailable);
      expect(noPreview.reason, AvailabilityReason.subscriptionRequired);
    });

    test('availability: deactivated uploader / deleted / not streamable → unavailable', () {
      final a = byId['95wro']!.availability;
      expect(a.playback, PlaybackRights.unavailable);
      expect(a.reason, AvailabilityReason.deleted);
      expect(AudiusMapper.availabilityOf({'is_delete': true}).reason, AvailabilityReason.deleted);
      expect(AudiusMapper.availabilityOf({'is_available': false}).reason, AvailabilityReason.deleted);
      final ns = AudiusMapper.availabilityOf({
        'is_streamable': false,
        'access': {'stream': true, 'download': false},
      });
      expect(ns.playback, PlaybackRights.unavailable);
      expect(ns.reason, AvailabilityReason.notStreamable);
    });

    test('playlists and albums', () {
      final pl = AudiusMapper.playlist(((fixtureJson('audius_playlist.json') as Map)['data'] as List).first)!;
      expect(pl.id, 'audius:DOPRl');
      expect(pl.name, 'Hot & New on Audius🔥');
      expect(pl.ownerName, isNotEmpty);
      expect(pl.permalink!.host, 'audius.co');
      expect(pl.trackCount, 20);
    });
  });

  group('catalog', () {
    test('getTrack and not-found', () async {
      expect((await source.getTrack('2jyld83'))!.title, startsWith('D3PRT'));
      expect(await source.getTrack('zzzzzzz'), isNull);
    });

    test('trending with genre, genres, new releases', () async {
      final t = await source.trending(genre: 'Electronic', limit: 3);
      expect(net.last.queryParameters, containsPair('genre', 'Electronic'));
      expect(t.every((x) => x.genre == 'Electronic'), isTrue);
      expect(await source.genres(), containsAll(['Electronic', 'Hip-Hop/Rap', 'Ambient']));
      final releases = await source.newReleases(limit: 3);
      expect(net.last.queryParameters['type'], 'album');
      expect(releases.map((a) => a.title), contains('CHAOS EP'));
    });

    test('artist page: user, top tracks by plays, related artists', () async {
      expect((await source.getArtist('BR1QY'))!.name, 'LoFi DREL');
      final top = await source.artistTopTracks('BR1QY', limit: 3);
      expect(net.last.path, '/v1/users/BR1QY/tracks');
      expect(net.last.queryParameters['sort'], 'plays');
      expect(top.items.map((t) => t.sourceTrackId), ['ORvZZ', 'Q0PP4', 'J7AVz']);
      final related = await source.relatedArtists('BR1QY', limit: 3);
      expect(related.map((a) => a.name), ['The Waiting List', 'Sebastian Kamae', 'BYERA']);
    });

    test('playlist by id and by URL (resolve)', () async {
      final byId = await source.getPlaylist('DOPRl');
      expect(byId.playlist.name, 'Hot & New on Audius🔥');
      expect(byId.tracks.items, hasLength(20));
      expect(byId.tracks.hasMore, isFalse);
      final byUrl = await source.getPlaylist('https://audius.co/Audius/playlist/hot-new-on-audius');
      expect(net.last.path, '/v1/resolve');
      expect(net.last.queryParameters['url'], 'https://audius.co/Audius/playlist/hot-new-on-audius');
      expect(byUrl.playlist.sourcePlaylistId, 'DOPRl');
      final album = await source.albumTracks('DOPRl');
      expect(net.last.path, '/v1/playlists/DOPRl/tracks');
      expect(album.items.first.sourceTrackId, 'zz0MEGP');
    });

    test('ISRC lookup', () async {
      final t = await source.lookupByIsrc('qzqay2630197');
      expect(net.last.queryParameters['isrc'], 'QZQAY2630197');
      expect(t!.sourceTrackId, 'mzXmz1');
      expect(await source.lookupByIsrc('XX0000000000'), isNull);
    });

    test('related tracks via related artists (no related-tracks endpoint)', () async {
      // The fixture user BR1QY is the uploader of nothing in audius_track.json,
      // so serve a track whose user is BR1QY.
      final net2 = RecordingHttp((r) async {
        if (r.url.path == '/v1/tracks/seed') {
          return jsonResponse('{"data":{"id":"seed","title":"Seed","user":{"id":"BR1QY","name":"LoFi DREL"}}}');
        }
        return _audius(r);
      });
      final s = AudiusSource(http: net2.fermata);
      final related = await s.relatedTracks('seed', limit: 5);
      expect(net2.requests.map((r) => r.url.path), containsAll(['/v1/tracks/seed', '/v1/users/BR1QY/related']));
      expect(related, isNotEmpty);
      expect(related.length, lessThanOrEqualTo(5));
      expect(related.every((t) => t.availability.isPlayableInApp), isTrue);
    });
  });

  group('playback and downloads', () {
    test('stream URL is the 302 endpoint with app_name', () async {
      final track = (await source.getTrack('2jyld83'))!;
      final s = await source.resolveStream(track);
      expect(s.uri.toString(), 'https://api.audius.co/v1/tracks/2jyld83/stream?app_name=Fermata');
      expect(s.isPreview, isFalse);
      expect(s.mimeType, 'audio/mpeg');
    });

    test('stale availability is re-checked; deleted tracks are unplayable', () async {
      final stale = const Track(sourceId: 'audius', sourceTrackId: 'zzzzzzz', title: 'gone');
      await expectLater(
        source.resolveStream(stale),
        throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.deleted)),
      );
      expect(net.last.path, '/v1/tracks/zzzzzzz');
    });

    test('gated tracks play the preview; unavailable tracks throw with reason', () async {
      final byId = {
        for (final t
            in await source.api
                .getData(
                  'tracks',
                  query: {
                    'id': ['3AmB2yE', '95wro'],
                  },
                )
                .then(AudiusMapper.tracks))
          t.sourceTrackId: t,
      };
      final preview = await source.resolveStream(byId['3AmB2yE']!);
      expect(preview.isPreview, isTrue);
      expect(preview.uri.queryParameters['preview'], 'true');
      await expectLater(
        source.resolveStream(byId['95wro']!),
        throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.deleted)),
      );
    });

    test('downloads only for artist-enabled tracks, via the official endpoint', () async {
      final ok = await source.authorizeDownload(const Track(sourceId: 'audius', sourceTrackId: '2jyld83', title: 'x'));
      expect(ok!.uri.toString(), 'https://api.audius.co/v1/tracks/2jyld83/download?app_name=Fermata');
      expect(ok.suggestedFileExtension, 'wav');
      expect(net.last.path, '/v1/tracks/2jyld83', reason: 'rights are re-checked before authorizing');

      final net2 = RecordingHttp((r) async {
        if (r.url.path == '/v1/tracks/zz0MEGP') {
          final all = (fixtureJson('audius_tracks_bulk.json') as Map)['data'] as List;
          final t = all.firstWhere((e) => (e as Map)['id'] == 'zz0MEGP');
          return jsonResponse(jsonEncode({'data': t}));
        }
        return _audius(r);
      });
      final s = AudiusSource(http: net2.fermata);
      expect(
        await s.authorizeDownload(const Track(sourceId: 'audius', sourceTrackId: 'zz0MEGP', title: 'x')),
        isNull,
        reason: 'download-gated (403 at the endpoint) is never authorized',
      );
      expect(
        await source.authorizeDownload(const Track(sourceId: 'audius', sourceTrackId: 'zzzzzzz', title: 'x')),
        isNull,
      );
    });

    test('external playback opens the permalink', () async {
      final t = (await source.getTrack('2jyld83'))!;
      expect(source.externalPlaybackUri(t), t.permalink);
    });
  });

  test('cursor round trip for paging', () {
    expect(PageCursor.decodeOffset(PageCursor.encodeOffset(30)), 30);
  });
}
