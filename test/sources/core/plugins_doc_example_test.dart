// Keeps the examples in docs/PLUGINS.md honest: the code below is copied
// from the guide and must compile and work.
import 'package:fermata/core/contracts/auth.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/net/http_client.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/sources/auth/auth.dart';
import 'package:fermata/sources/base/base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class ExampleFmSource extends MusicSourceBase {
  ExampleFmSource({required this._http});

  final FermataHttp _http;
  static final _base = Uri.parse('https://api.example.fm/v1');

  @override
  String get id => 'examplefm';

  @override
  String get displayName => 'Example FM';

  @override
  Set<SourceCapability> get capabilities => const {SourceCapability.searchTracks, SourceCapability.stream};

  @override
  String get limitationsNote => 'Full-length streams of Creative Commons tracks. No downloads, no accounts.';

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    final offset = PageCursor.decodeOffset(cursor);
    final uri = _base.replace(
      path: '${_base.path}/tracks',
      queryParameters: {'q': query.trim(), 'offset': '$offset', 'limit': '$limit'},
    );
    final json = asJsonMap(await _http.getJson(uri, cancel: cancel));
    final raw = asJsonMapList(json['tracks']);
    return PageCursor.offsetPage(
      [for (final t in raw) ?_track(t)],
      offset: offset,
      limit: limit,
      total: jsonInt(json['total']),
      consumed: raw.length,
    );
  }

  Track? _track(Map<String, Object?> t) {
    final id = jsonString(t['id']);
    final title = jsonString(t['title']);
    if (id == null || title == null) return null; // never invent data
    final seconds = jsonInt(t['duration']);
    return Track(
      sourceId: this.id,
      sourceTrackId: id,
      title: title,
      artists: [if (jsonString(t['artist']) != null) ArtistRef(jsonString(t['artist'])!)],
      duration: seconds == null ? null : Duration(seconds: seconds),
      artworkUrl: ArtworkSizing.pick({200: t['image_small'], 600: t['image_large']}),
      permalink: jsonHttpUri(t['url']),
      availability: jsonBool(t['streamable']) == false
          ? Availabilities.unavailable(AvailabilityReason.notStreamable)
          : Availabilities.stream(),
      extra: {'examplefm.audio': ?jsonString(t['audio'])},
    );
  }

  @override
  Future<PlayableSource> resolveStream(
    Track track, {
    AudioQuality quality = AudioQuality.high,
    CancelToken? cancel,
  }) async {
    checkOwnTrack(track);
    Availabilities.ensurePlayable(track);
    final audio = track.extra['examplefm.audio'];
    if (audio == null) throw UnplayableTrackException(track.id, AvailabilityReason.notStreamable);
    return PlayableSource(uri: Uri.parse(audio), mimeType: 'audio/mpeg');
  }
}

class AcmeSource extends MusicSourceBase with OAuthSourceMixin {
  AcmeSource({
    required FermataHttp http,
    required OAuthClient oauth,
    required TokenStore tokens,
    required CredentialsStore credentials,
  }) : oauthSession = OAuthSession(
         sourceId: 'acme',
         displayName: 'Acme',
         client: oauth,
         tokens: tokens,
         credentials: credentials,
         http: http,
         requiredCredentialFields: const ['clientId'],
         credentialsHelpUrl: Uri.parse('https://developer.acme.example/apps'),
         headerStyle: AuthHeaderStyle.bearer,
         buildConfig: (c) => OAuthConfig(
           sourceId: 'acme',
           authorizeEndpoint: Uri.parse('https://accounts.acme.example/authorize'),
           tokenEndpoint: Uri.parse('https://accounts.acme.example/token'),
           clientId: c.clientId!,
           clientSecret: c.clientSecret,
           scopes: const ['library-read'],
           redirectUriOverride: c.redirectUri,
         ),
         fetchAccount: (session, cancel) async {
           final me = asJsonMap(
             await session.authorizedGetJson(Uri.parse('https://api.acme.example/me'), cancel: cancel),
           );
           return OAuthAccount(name: jsonString(me['display_name']) ?? 'Acme user');
         },
       );

  @override
  final OAuthSession oauthSession;

  @override
  String get id => 'acme';

  @override
  String get displayName => 'Acme';

  @override
  Set<SourceCapability> get capabilities => const {SourceCapability.userLibrary, SourceCapability.oauth};

  @override
  String get limitationsNote => 'Imports your Acme playlists.';

  @override
  Future<List<Playlist>> userPlaylists({CancelToken? cancel}) async {
    ensureCredentials();
    await oauthSession.authorizedGetJson(Uri.parse('https://api.acme.example/me/playlists'), cancel: cancel);
    return const [];
  }
}

void main() {
  test('ExampleFmSource from docs/PLUGINS.md works', () async {
    final net = RecordingHttp(
      (r) async => jsonResponse('''
      {"total": 2, "tracks": [
        {"id": "1", "title": "Song", "artist": "Band", "duration": 200, "streamable": true,
         "audio": "https://cdn.example.fm/1.mp3", "url": "https://example.fm/t/1", "image_large": "https://i.example.fm/1.jpg"},
        {"id": "2", "title": "Gone", "streamable": false}
      ]}'''),
    );
    final source = ExampleFmSource(http: net.fermata);
    final page = await source.searchTracks('song', limit: 2);
    expect(net.last.queryParameters, {'q': 'song', 'offset': '0', 'limit': '2'});
    expect(page.items.first.artworkUrl.toString(), 'https://i.example.fm/1.jpg');
    expect(page.hasMore, isFalse);
    final stream = await source.resolveStream(page.items.first);
    expect(stream.uri.toString(), 'https://cdn.example.fm/1.mp3');
    await expectLater(source.resolveStream(page.items[1]), throwsA(isA<UnplayableTrackException>()));
    await expectLater(source.trending(), throwsA(isA<UnsupportedSourceOperation>()));
  });

  test('AcmeSource from docs/PLUGINS.md reports missing credentials', () async {
    final net = RecordingHttp((r) async => jsonResponse('{}'));
    final source = AcmeSource(
      http: net.fermata,
      oauth: OAuthClientImpl(http: net.fermata),
      tokens: InMemoryTokenStore(),
      credentials: _NoCredentials(),
    );
    await source.init();
    expect(source.authState.status, SourceConnectionStatus.credentialsMissing);
    expect(source.credentialStatus.missing, ['clientId']);
    await expectLater(source.userPlaylists(), throwsA(isA<MissingCredentialsException>()));
    expect(net.requests, isEmpty);
  });
}

class _NoCredentials implements CredentialsStore {
  @override
  Stream<String> get changes => const Stream.empty();
  @override
  String get configFilePath => '/dev/null';
  @override
  SourceCredentials? get(String sourceId) => null;
  @override
  Future<void> init() async {}
  @override
  CredentialOrigin originOf(String sourceId) => CredentialOrigin.none;
  @override
  Future<void> setUserCredentials(String sourceId, SourceCredentials? credentials) async {}
}
