# Sources core

Plugin base, registry, OAuth/credentials, and the Local, Audius and Deezer
providers. Credentialed providers (SoundCloud, Spotify, YouTube, Jamendo)
build on these classes in their own folders. How to write a provider:
`docs/PLUGINS.md`. Credentials and redirect URIs: `docs/CREDENTIALS.md`.

| Folder | Contents |
|---|---|
| `base/` | `MusicSourceBase`, `PageCursor`, `ArtworkSizing`, `Availabilities`, JSON helpers, `TokenBucketRateLimiter`, `resolveRedirects` (barrel: `base.dart`) |
| `auth/` | `OAuthClientImpl`, `TokenEndpointClient`, `PkcePair`, `OAuthSession`, `OAuthSourceMixin`, `OAuthFlowException`, `ProbedSecureStorage`, `SecureTokenStore`, `InMemoryTokenStore`, `CredentialsStoreImpl`, `BuildTimeCredentials` (barrel: `auth.dart`) |
| `registry/` | `SourceRegistryImpl` |
| `local/` | `LocalSource` |
| `audius/` | `AudiusSource`, `AudiusApi`, `AudiusMapper` |
| `deezer/` | `DeezerSource`, `DeezerApi`, `DeezerMapper`, `DeezerLinks` |

## Public API (constructors)

```dart
// base
abstract class MusicSourceBase extends MusicSource { MusicSourceBase({SourceAuthState initialAuthState}); }
TokenBucketRateLimiter({required int capacity, required Duration period, Clock? clock, Sleeper? sleep});
Future<Uri> resolveRedirects(FermataHttp http, Uri uri, {int maxHops, CancelToken? cancel, Duration timeout, bool Function(Uri)? stopWhen});

// auth
static Future<ProbedSecureStorage> ProbedSecureStorage.open({SecureKeyValueStore? backend, Duration probeTimeout, Random? random});
SecureTokenStore(ProbedSecureStorage storage);            // implements TokenStore
CredentialsStoreImpl({required File configFile, required SecureKeyValueStore secureStorage, Map<String, SourceCredentials>? buildTime});
OAuthClientImpl({required FermataHttp http, PlatformInfo? platform, BrowserLauncher? launcher, DeepLinkStream? deepLinks,
                 Duration timeout = 5 min, String customScheme = 'fermata', String Function(String)? providerName, Random? random});
TokenEndpointClient(FermataHttp http, {DateTime Function()? clock});
OAuthSession({required sourceId, displayName, client, tokens, credentials, http, buildConfig, fetchAccount,
              requiredCredentialFields, credentialsHelpUrl, headerStyle, refreshLeeway, fetchAccountOnInit,
              supportsAndroidRedirect, androidUnsupportedExplanation, revoker, platform});
mixin OAuthSourceMixin on MusicSourceBase { OAuthSession get oauthSession; }

// registry & providers
SourceRegistryImpl({required SettingsStore settings, Duration searchTimeout = 10 s});
LocalSource({required TrackRepository tracks, Future<bool> Function(String path)? fileExists});
AudiusSource({required FermataHttp http, CredentialsStore? credentials, Uri? baseUri});
DeezerSource({required FermataHttp http, Uri? baseUri, TokenBucketRateLimiter? limiter, DateTime Function()? clock});
```

Extras beyond the frozen contracts:

* `SourceRegistryImpl.initAll()`, `.unregister(id)`, `.isEnabled(id)`, `.dispose()`.
* `OAuthClientImpl.authorizeWithCancel(config, cancel:)`, `.cancelPending()`,
  `.strategyFor(config)`, `.buildAuthorizeUrl(...)`, `.tokenEndpoint`.
* `CredentialsStoreImpl.reloadConfigFile()`, `.userCredentialsPersistent`, `.dispose()`.
* `DeezerSource.publicUserPlaylists(profileUrlOrId)` — public playlists of a
  Deezer profile without OAuth; `DeezerSource.resolvePlaylistId(idOrUrl)`.

## Bootstrap wiring (`lib/app/bootstrap.dart`)

Order: after `http`, `settings` and the library repositories; before the
download manager / stream resolver.

```dart
import '../sources/audius/audius_source.dart';
import '../sources/auth/auth.dart';
import '../sources/deezer/deezer_source.dart';
import '../sources/local/local_source.dart';
import '../sources/registry/source_registry_impl.dart';

// Credentials & tokens — one probed secure storage shared by both stores.
final secureStorage = await ProbedSecureStorage.open();        // ≤ 4 s probe; memory fallback on Linux w/o keyring
final tokens = SecureTokenStore(secureStorage);
final credentials = CredentialsStoreImpl(
  configFile: paths.credentialsFile,
  secureStorage: secureStorage,
);
await credentials.init();
final oauth = OAuthClientImpl(http: http, platform: platform);

// Sources registry
final sources = SourceRegistryImpl(settings: settings);
sources
  ..register(LocalSource(tracks: tracks))
  ..register(AudiusSource(http: http, credentials: credentials))
  ..register(DeezerSource(http: http));
// Credentialed providers are registered here too (see docs/PROVIDERS.md),
// constructed with (http, oauth, tokens, credentials).
await sources.initAll();                                        // never throws for missing credentials

// AppServices(..., tokens: tokens, credentials: credentials, oauth: oauth, sources: sources, ...)
```

Shutdown (`AppLifecycleController.quit()`): `for (final s in sources.all) await s.dispose();`
then `await sources.dispose(); await credentials.dispose();`.

## Platform notes

* **Desktop OAuth**: loopback server on `127.0.0.1:43821` (fixed; providers
  require exact redirect URIs), system browser via `url_launcher`
  (`LaunchMode.externalApplication`), 5-minute timeout, server always
  closed. Port busy → `OAuthFlowException(portInUse)` with a clear message.
* **Android OAuth**: `fermata://oauth/<sourceId>` through `app_links`
  (`AppLinks().uriLinkStream`) and a Custom Tab
  (`LaunchMode.inAppBrowserView`). Requires an intent filter in
  `AndroidManifest.xml` for scheme `fermata`, host `oauth` on the main
  activity (owned by the native-platform module). Sources can force
  loopback (`OAuthConfig.redirectStrategy`) or opt out of Android
  (`OAuthSession.supportsAndroidRedirect = false`).
* **Linux secure storage**: probed at startup; without a Secret Service the
  stores are memory-only (`TokenStore.isPersistent == false`), never plain
  files.
* Windows code paths are the same Dart code (`HttpServer`, `url_launcher`,
  `flutter_secure_storage_windows`); not executable in this dev container.

## Provider notes (verified 2026-10-27)

* **Audius** — `https://api.audius.co/v1`, no host discovery needed (the
  root lists only `api.audius.co`; discovery nodes are deprecated).
  `app_name=Fermata` is optional but sent. Optional API key → `x-api-key`
  header (+ `api_key` on stream URLs). Availability: deleted / deactivated
  uploader / `is_available == false` → `deleted`; stream-gated without
  access → 30 s preview when one exists, else `subscription_required`;
  `is_streamable == false` → `not_streamable`; downloadable only when
  `is_downloadable` **and** `access.download` (download-gated tracks return
  403 at the endpoint). No related-tracks endpoint: `relatedTracks` uses the
  top tracks of related artists. Albums only appear in `/search/full?kind=albums`.
* **Deezer** — public API; errors arrive in HTTP 200 bodies (`800` no data →
  `null`/404, `4` quota → bucket penalty + 2 retries → `RateLimitedException`,
  `700` busy → one retry). Client-side bucket 50 req / 5 s. Previews are
  signed and expire: `resolveStream` always re-fetches the track and sets
  `expiresAt` from `SourcePolicies.of('deezer').previewUrlTtl` (or the URL's
  own `exp`). `link.deezer.com/s/…` short links resolve via `Location`
  headers; `deezer.page.link` (Firebase Dynamic Links) is followed too but
  is mostly dead since 2025. `/editorial/0/releases` was empty at research
  time; `newReleases` then falls back to `/editorial/0/selection`. No
  `userLibrary` (new app registration closed).
* **Local** — answers from `TrackRepository` with `localFilesOnly`; artist
  ids are names, album ids are opaque (artist, title) tokens
  (`LocalSource.encodeAlbumId`).

## Known limitations

* OAuth token refresh is lazy-proactive (refreshed on the first request
  within `refreshLeeway` of expiry) rather than timer-driven.
* `OAuthSession` cannot persist the account name across restarts (the
  `TokenStore` contract stores only the token); it is re-fetched in the
  background after `init()`.
* `SourceSearchResults` has a single `error`: when some search types of a
  source fail and others succeed, the partial results are returned and the
  failure is only logged.
* The Secret Service probe may delay startup by up to 4 s on Linux systems
  where D-Bus does not answer.

## Tests

`flutter test test/sources/core` (143+ tests: base defaults, cursors,
rate limiter, PKCE RFC 7636 vectors, loopback/custom-scheme OAuth end to end
with a fake browser and a local token server, session refresh/401/expired,
secure-storage fallback, credentials precedence, registry ordering/timeout/
cancel, Local, and Audius/Deezer against recorded real responses in
`test/sources/core/fixtures/`). Live API smoke test:
`FERMATA_LIVE_TESTS=1 flutter test test/sources/core/live_api_test.dart`.
