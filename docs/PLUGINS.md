# Writing a music source ("provider plugin")

Every provider — Local files, Audius, Deezer, SoundCloud, Spotify, YouTube,
Jamendo — implements the same contract, `MusicSource`
(`lib/core/contracts/music_source.dart`), usually by extending
**`MusicSourceBase`** (`lib/sources/base/`). Search, artist/album pages,
playlist import, matching, the stream resolver and the download manager only
talk to that contract, so a new provider shows up everywhere once it is
registered.

> **Providers are compiled in.** Fermata is built ahead-of-time (AOT) for
> Android, Linux and Windows; Flutter release builds cannot load Dart code at
> runtime, so there is no drop-in plugin folder. "Plugin" means a module in
> `lib/sources/<id>/` that is registered in `lib/app/bootstrap.dart` and
> shipped with the app. Adding one requires a rebuild.

## 1. Decide what the provider allows

Read the provider's current API terms first and write the answers into
`docs/research/API_NOTES.md` / `docs/COMPLIANCE.md`:

* Can third-party apps stream full tracks, only previews, or nothing?
* May anything be downloaded/stored offline? Only on explicit user action?
* Is an app registration (client id/secret, API key) required? Can users
  connect an account (OAuth), and which redirect URIs are accepted?
* Rate limits, attribution and branding rules.

Behaviour that the rest of the app must enforce (silos, download policy,
preview URL lifetime) lives in `SourcePolicies`
(`lib/core/sources/source_policies.dart`, owned by the core maintainers —
ask for an entry; unknown ids get the most restrictive defaults).

## 2. Implement the source

```
lib/sources/<id>/
  <id>_api.dart      request building + error mapping (FermataHttp only)
  <id>_mapper.dart   JSON → Track / Artist / Album / Playlist + availability
  <id>_source.dart   class <Name>Source extends MusicSourceBase
```

### Identity and capabilities

```dart
@override String get id => 'examplefm';          // lowercase ASCII, no ':'
@override String get displayName => 'Example FM';
@override Set<SourceCapability> get capabilities => const {
  SourceCapability.searchTracks, SourceCapability.stream, SourceCapability.trending,
};
@override String get limitationsNote => 'One honest paragraph: what works, what does not, and why.';
@override Uri? get termsUrl => Uri.parse('https://example.fm/api-terms');
```

The UI only offers what `capabilities` declares. Everything you do not
override throws `UnsupportedSourceOperation` (from `MusicSourceBase`), so
declare a capability only together with its implementation:

| Capability | Methods |
|---|---|
| `searchTracks` / `searchArtists` / `searchAlbums` / `searchPlaylists` | `searchTracks` … `searchPlaylists` |
| `stream` / `previewOnly` | `resolveStream` |
| `externalPlayback` | `externalPlaybackUri` (default: the track's `permalink`) |
| `download` | `authorizeDownload` (default: `null` = not permitted) |
| `artistPages` | `getArtist`, `artistTopTracks`, `relatedArtists` |
| `albumPages` | `albumTracks` |
| `playlistImport` | `getPlaylist(idOrUrl)` — accept ids **and** share URLs |
| `userLibrary` (+ `oauth`) | `userPlaylists`, `userLikedTracks` |
| `isrcLookup`, `relatedTracks`, `trending`, `genres`, `newReleases` | same-named methods |

### Rules (enforced in review)

* **Never fabricate.** No placeholder results, no fake "success". If the API
  cannot be reached throw `NetworkException`; unexpected responses
  `ApiException`; 429 / quota → `RateLimitedException`; missing developer
  credentials → `MissingCredentialsException` (before any request!);
  expired sessions → `AuthRequiredException` (`lib/core/errors.dart`).
* **Network only through `FermataHttp`** (timeouts, retries, 429
  `Retry-After`, cancellation, User-Agent). Pass the `CancelToken` down.
  Short links: `resolveRedirects()` (`lib/sources/base/redirects.dart`).
  Client-side rate limits: `TokenBucketRateLimiter`.
* **Map restrictions faithfully** into `TrackAvailability` with the helpers
  in `Availabilities` (`stream`, `preview`, `externalOnly`, `unavailable`)
  and the `AvailabilityReason` codes — the UI explains them to the user.
  `OfflineRights.downloadable` only when the provider explicitly permits
  downloading that track.
* `resolveStream` re-checks stale availability (`Availabilities.isStale`)
  and throws `UnplayableTrackException(track.id, reason)`; set
  `PlayableSource.expiresAt` for signed URLs.
* `authorizeDownload` returns a `DownloadAuthorization` only when the track
  is downloadable *right now* (re-fetch it); otherwise `null`.
* Pagination: return opaque cursors via `PageCursor` (`encodeOffset`,
  `encodeToken`, `offsetPage`); never expose provider URLs as cursors
  directly.
* Artwork: `ArtworkSizing.pick` (target `ArtworkSizing.standard` = 500 px).
* Ids: `Track.sourceTrackId` is the provider's stable id (`Track.id` becomes
  `<sourceId>:<sourceTrackId>`). Put provider extras (URNs, handles) in
  `Track.extra` with a `<sourceId>.` prefix.
* Attribution: always fill `permalink` (track) and artist/playlist
  `permalink`s.
* Logging: `final _log = Logger('sources.<id>');` — never log tokens,
  secrets, auth codes or full signed URLs.
* Keep files under ~500 lines.

### Minimal example

A complete source for a fictional public API without accounts:

```dart
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/net/http_client.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/sources/base/base.dart';

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
  Future<PlayableSource> resolveStream(Track track, {AudioQuality quality = AudioQuality.high, CancelToken? cancel}) async {
    checkOwnTrack(track);
    Availabilities.ensurePlayable(track);
    final audio = track.extra['examplefm.audio'];
    if (audio == null) throw UnplayableTrackException(track.id, AvailabilityReason.notStreamable);
    return PlayableSource(uri: Uri.parse(audio), mimeType: 'audio/mpeg');
  }
}
```

## 3. Accounts (OAuth) and developer credentials

Sources with accounts mix in **`OAuthSourceMixin`** and create an
**`OAuthSession`** (`lib/sources/auth/`). The session implements the whole
state machine: `credentialsMissing ↔ notConnected → connecting → connected
→ expired`, connect (authorize → store token → fetch account), refresh
shortly before expiry, one refresh + retry on 401, `expired` after that,
disconnect (remote revoke when supported, local delete), and re-evaluation
when developer credentials change.

```dart
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
          requiredCredentialFields: const ['clientId'],        // + 'clientSecret' / 'apiKey'
          credentialsHelpUrl: Uri.parse('https://developer.acme.example/apps'),
          headerStyle: AuthHeaderStyle.bearer,                 // SoundCloud: AuthHeaderStyle.oauth
          buildConfig: (c) => OAuthConfig(
            sourceId: 'acme',
            authorizeEndpoint: Uri.parse('https://accounts.acme.example/authorize'),
            tokenEndpoint: Uri.parse('https://accounts.acme.example/token'),
            clientId: c.clientId!,
            clientSecret: c.clientSecret,                      // sent only when configured
            scopes: const ['library-read'],
            redirectUriOverride: c.redirectUri,
          ),
          fetchAccount: (session, cancel) async {
            final me = asJsonMap(await session.authorizedGetJson(Uri.parse('https://api.acme.example/me'), cancel: cancel));
            return OAuthAccount(name: jsonString(me['display_name']) ?? 'Acme user');
          },
          // supportsAndroidRedirect: false,  // e.g. Google: connect() then explains it is desktop-only
          // revoker: (session, token) => ..., // provider-specific disconnect endpoint
        );

  @override
  final OAuthSession oauthSession;

  // id, displayName, capabilities (+ SourceCapability.oauth / userLibrary), limitationsNote …

  @override
  Future<List<Playlist>> userPlaylists({CancelToken? cancel}) async {
    ensureCredentials(); // MissingCredentialsException before any request
    final json = await oauthSession.authorizedGetJson(Uri.parse('https://api.acme.example/me/playlists'), cancel: cancel);
    return /* map json */ const [];
  }
}
```

* `OAuthClientImpl` runs authorization code + PKCE (S256) with a `state`
  check. Desktop: loopback `http://127.0.0.1:43821/callback/<id>` and the
  system browser; Android: `fermata://oauth/<id>` via a Custom Tab. A config
  can force `RedirectStrategy.loopback`, set `loopbackPort: 0` for
  providers that accept any loopback port, use `clientAuthInHeader` (HTTP
  Basic) and `extraAuthorizeParams`. App-only tokens (client-credentials
  grant) are available through `TokenEndpointClient.clientCredentials`.
* Developer credentials come from `CredentialsStore` (user-entered > 
  `credentials.json` > `--dart-define`); see `docs/CREDENTIALS.md` and add
  your `FERMATA_<ID>_…` define to `BuildTimeCredentials`.
* Sources that also work without a user connection (e.g. public browsing
  with an app token) override `isReady`.

## 4. Register it

In `lib/app/bootstrap.dart` (the only place that wires concrete classes):

```dart
sources.register(ExampleFmSource(http: http));
// … after all registrations:
await sources.initAll();
```

Add the id to `SourceIds` and to the default provider order only if it is a
built-in; user preferences (`services.providerOrder`,
`services.disabledSources`) decide ordering and enabling at runtime —
sources not in the saved order are appended after the known ones.

## 5. Test it

Tests live in `test/sources/<module>/`. Use `package:http/testing.dart`'s
`MockClient` behind a `FermataHttp` and **recorded real responses**
(`curl` the public endpoint into `fixtures/*.json`) or, where an account is
needed, responses hand-written from the official docs (say so in a header
comment). Cover at least:

* mapping (ids, artists, duration, artwork, permalink) and availability for
  each restriction the provider has;
* request building (paths, query parameters, headers, paging cursors);
* error mapping (404 → `null` for `getTrack`, 429, provider error bodies);
* without credentials: `credentialsMissing`, `isReady == false`,
  `MissingCredentialsException` and **no request made**;
* OAuth: 401 → refresh → retry via the session.

`test/sources/core/` contains examples for all of these (Audius, Deezer,
OAuth session/client, registry). An opt-in live smoke test pattern is in
`test/sources/core/live_api_test.dart` (`FERMATA_LIVE_TESTS=1`).

Run: `dart analyze lib/sources/<id> test/sources/<id>` and
`flutter test test/sources/<id>`.
