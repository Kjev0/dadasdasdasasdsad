# Credentialed sources: bootstrap wiring

Exact constructor calls for registering SoundCloud, Spotify, YouTube and
Jamendo in `lib/app/bootstrap.dart`. Mirrored by
`test/sources/providers/wiring_test.dart`. What each source does and its
terms: `docs/PROVIDERS.md`. Credentials and redirect URIs: `docs/CREDENTIALS.md`.

## Constructors

```dart
SoundCloudSource({required FermataHttp http, required OAuthClient oauth, required TokenStore tokens,
                  required CredentialsStore credentials, PlatformInfo? platform, Uri? apiBaseUri,
                  int dailyStreamLimit = 1500, DateTime Function()? clock});
SpotifySource({required FermataHttp http, required OAuthClient oauth, required TokenStore tokens,
               required CredentialsStore credentials, PlatformInfo? platform, Uri? apiBaseUri,
               DateTime Function()? clock});
YouTubeSource({required FermataHttp http, required OAuthClient oauth, required TokenStore tokens,
               required CredentialsStore credentials, PlatformInfo? platform, Uri? apiBaseUri,
               DateTime Function()? clock, int searchCallsPerDay = 100});
JamendoSource({required FermataHttp http, required CredentialsStore credentials,
               Uri? apiBaseUri, DateTime Function()? clock});   // no OAuth, no tokens
```

`http`, `oauth`, `tokens`, `credentials` and `platform` are the values
`bootstrap()` already creates for the core sources. Pass the same
`platform` (`PlatformInfo.current()`) that `OAuthClientImpl` gets: SoundCloud
uses it for `display=popup` on Android and YouTube uses it to refuse
connecting on Android.

## Registration snippet

```dart
import '../sources/jamendo/jamendo_source.dart';
import '../sources/soundcloud/soundcloud_source.dart';
import '../sources/spotify/spotify_source.dart';
import '../sources/youtube/youtube_source.dart';

final sources = SourceRegistryImpl(settings: settings)
  ..register(LocalSource(tracks: library.tracks))
  ..register(AudiusSource(http: http, credentials: credentials))
  ..register(DeezerSource(http: http))
  ..register(SoundCloudSource(http: http, oauth: oauth, tokens: tokens, credentials: credentials, platform: platform))
  ..register(SpotifySource(http: http, oauth: oauth, tokens: tokens, credentials: credentials, platform: platform))
  ..register(YouTubeSource(http: http, oauth: oauth, tokens: tokens, credentials: credentials, platform: platform))
  ..register(JamendoSource(http: http, credentials: credentials));
await sources.initAll();   // never throws for missing credentials
```

## Init order and lifecycle

1. `credentials.init()` must complete **before** `sources.initAll()`: a
   source reads its developer credentials in the constructor and in `init()`.
2. `initAll()` calls each source's `init()`. Without credentials a source
   becomes `credentialsMissing` and makes no network call. With credentials,
   OAuth sources restore a stored token and refresh the account name in the
   background.
3. Adding or removing credentials at runtime (Settings →
   Developer credentials → `CredentialsStore.setUserCredentials`) updates
   every source through `CredentialsStore.changes`; no re-registration or
   restart is needed.
4. Shutdown: `for (final s in sources.all) await s.dispose();` then
   `await sources.dispose(); await credentials.dispose();` (as in
   `docs/PLUGINS.md`). `dispose()` cancels the credential subscriptions.

## What the rest of the app must do

* **SoundCloud queue silo**: enforced by the playback engine through
  `SourcePolicies.canJoinSilo`, not by the source. Never mix SoundCloud
  streams with other services' streams in one queue.
* **SoundCloud stream budget**: about 1,500 stream resolutions per day per
  `client_id`. Resolve the current track and at most one track ahead; do not
  prefetch speculatively. `SoundCloudSource.gate` exposes the counter.
* **YouTube search**: 100 `search.list` calls per day per project. Matching
  must prefer other targets (Deezer, Audius, SoundCloud) and never call
  `YouTubeSource.searchTracks` in a loop. `YouTubeSource.api.searchCallsRemaining`
  shows what is left.
* **Spotify, YouTube**: `resolveStream` always throws
  `UnplayableTrackException(externalOnly)`; use `externalPlaybackUri(track)`
  to open the track in the provider's app.
* **Downloads**: only `JamendoSource.authorizeDownload` can return a
  `DownloadAuthorization`, and only when Jamendo reports
  `audiodownload_allowed`. SoundCloud, Spotify and YouTube always return null.
* **Attribution**: show `Track.permalink` and the artist credit for
  SoundCloud, Spotify and Jamendo; show the licence from
  `track.extra[JamendoMapper.extraLicense]` for Jamendo.
