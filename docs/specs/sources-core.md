# Spec: Sources core — plugin base, registry, auth, Local, Audius, Deezer
(`lib/sources/base/**`, `lib/sources/registry/**`, `lib/sources/auth/**`, `lib/sources/local/**`, `lib/sources/audius/**`, `lib/sources/deezer/**`, `test/sources/core/**`, `docs/PLUGINS.md`)

A second agent will build SoundCloud, Spotify, YouTube and Jamendo on top of
your base classes **after** you finish — make the base APIs clean, documented
and stable.

## Implement
1. **`MusicSourceBase`** (`lib/sources/base/music_source_base.dart`):
   abstract class implementing `MusicSource` where every catalog/playback
   method throws `UnsupportedSourceOperation` by default, auth defaults to
   `SourceAuthState.notRequired()`, a protected `emitAuthState()` helper with
   a broadcast stream, `isReady` default, `CredentialStatus.notNeeded()`.
   Also shared helpers: pagination cursor encode/decode, image URL sizing
   helper, common availability mappers.
2. **`OAuthSourceMixin` / `OAuthSession`** (`lib/sources/base/` or
   `lib/sources/auth/`): wraps `OAuthClient` + `TokenStore` +
   `CredentialsStore` for a source: `connect()` (authorize → store token →
   fetch account name via a callback → connected), automatic refresh before
   expiry, on 401 refresh once and retry, then `expired` state; `disconnect()`
   revokes when supported and deletes tokens; credentials changes re-evaluate
   state (`credentialsMissing` ↔ `notConnected`). An authorized-request
   helper `Future<Object?> authorizedGetJson(Uri, {...})` that applies the
   provider's header format (`Bearer` vs SoundCloud's `OAuth <token>`).
3. **`OAuthClientImpl implements OAuthClient`** (`lib/sources/auth/`):
   authorization code + PKCE (S256, 64-byte verifier, `state` CSRF check),
   * desktop: loopback `HttpServer.bind(InternetAddress.loopbackIPv4, port)`
     at `http://127.0.0.1:<port>/callback/<sourceId>`, opens the system
     browser with `url_launcher` (`LaunchMode.externalApplication`), serves a
     small branded HTML "You can close this tab" page (EN/DA neutral icons,
     no external assets), times out after 5 minutes, closes the server
     always (also on error/cancel). Port busy → clear error.
   * Android: `fermata://oauth/<sourceId>` via `app_links` `uriLinkStream`
     + Custom Tabs (`LaunchMode.inAppBrowserView` or externalApplication);
     per-config override to loopback for providers that reject custom
     schemes.
   * token exchange / refresh (`grant_type=refresh_token`, keep old refresh
     token if not rotated) / revoke; client secret only when configured;
     `clientAuthInHeader` → HTTP Basic.
   * Unit tests with a fake browser launcher (inject a
     `Future<void> Function(Uri)` launcher) that simulates the provider by
     calling the loopback URL with code/state; token endpoint served by a
     local HttpServer.
4. **`SecureTokenStore implements TokenStore`** with
   `flutter_secure_storage` (keys `fermata.token.<sourceId>`, JSON). On Linux
   the Secret Service may be unavailable (headless, no keyring): detect by a
   guarded write/read probe at init; then fall back to in-memory only,
   `isPersistent = false`, and log a warning — never write tokens to plain
   files. Tests use an in-memory implementation behind the same interface.
5. **`CredentialsStoreImpl implements CredentialsStore`**: precedence
   user-entered (secure storage key `fermata.credentials.<sourceId>`) >
   `<support>/credentials.json` (`{ "soundcloud": {"clientId": "...",
   "clientSecret": "..."}, ... }`) > build-time `String.fromEnvironment`
   (`FERMATA_SOUNDCLOUD_CLIENT_ID`, `FERMATA_SOUNDCLOUD_CLIENT_SECRET`,
   `FERMATA_SPOTIFY_CLIENT_ID`, `FERMATA_YOUTUBE_CLIENT_ID`,
   `FERMATA_YOUTUBE_CLIENT_SECRET`, `FERMATA_YOUTUBE_API_KEY`,
   `FERMATA_JAMENDO_CLIENT_ID`). Document in `docs/CREDENTIALS.md` (file
   format, dart-define usage with `--dart-define-from-file=dart_defines.json`
   (gitignored), where to register each app, redirect URIs to register:
   `http://127.0.0.1:43821/callback/<sourceId>` and
   `fermata://oauth/<sourceId>`).
6. **`SourceRegistryImpl implements SourceRegistry`**: ordered by
   `services.providerOrder`, excludes `services.disabledSources`, `changes`
   merges every source's `authStateChanges` + settings order changes;
   `searchAll` runs ready sources concurrently with a per-source timeout
   (10 s), yields each source's `SourceSearchResults` as it completes (with
   `error` set on failure), honours `CancelToken`.
7. **`LocalSource`** (`SourceIds.local`): search/browse over
   `TrackRepository` (local files only), `resolveStream` → `file://` (check
   existence → `fileMissing`), `authorizeDownload` → null (already local),
   capabilities: searchTracks, stream, artistPages/albumPages via library
   queries where sensible.
8. **`AudiusSource`** (`SourceIds.audius`) — open API, no account: base
   `https://api.audius.co/v1`, query param `app_name=Fermata` on every
   request (verify current requirements; if a host-discovery step is needed
   use it with caching). Search tracks/users/playlists, trending (with
   genre), track, user tracks, playlist + tracks, stream URL
   (`/tracks/{id}/stream?app_name=…` — the player follows the 302), downloads
   only when the track is marked downloadable (`is_downloadable` /
   `download` fields — verify) via the official download endpoint. Map
   artwork sizes (150x150/480x480/1000x1000), `permalink`, genre, duration,
   availability (`is_streamable == false`, delisted/deleted → unavailable;
   stream gated/premium → `subscriptionRequired`). Attribution: permalink.
9. **`DeezerSource`** (`SourceIds.deezer`) — public API without auth
   (`https://api.deezer.com`): search tracks/artists/albums/playlists
   (index/limit pagination), track, `track/isrc:<ISRC>` lookup, album
   tracks, artist top + related, playlist by id or share URL (resolve
   `deezer.page.link`/`link.deezer.com` short links by following redirects;
   `www.deezer.com/<lang>/playlist/<id>`), chart (trending), genres, editorial
   releases (new releases). Playback: `preview` (30 s MP3) → `PlaybackRights.preview`
   with `previewDuration` 30 s; full track → `externalOnly` with
   `externalPlaybackUri` = track link. Never downloadable. Respect the public
   rate limit (token bucket, e.g. ≤ 50 requests / 5 s) and handle Deezer's
   error-in-200 JSON (`{"error": {...}}`, code 4 = quota → RateLimited).
   Deezer user-library OAuth: implement only if new app registration is
   currently possible per API_NOTES/official docs; otherwise capability
   `userLibrary` is absent and `limitationsNote` explains it.
10. Tests (`test/sources/core/`): base defaults, registry ordering/disable/
    searchAll partial failure & timeout, OAuth PKCE (verifier/challenge
    vectors from RFC 7636 appendix B), loopback flow end-to-end with fakes,
    state mismatch rejected, refresh flow, 401→refresh→retry, secure token
    store fallback logic, credentials precedence, Audius/Deezer mappers and
    request building with MockClient fixtures — record REAL public responses
    with curl into `test/sources/core/fixtures/*.json` (they are public data)
    — Deezer error-in-200 handling, rate limiter.
11. `docs/PLUGINS.md`: how to write a new provider (implement
    `MusicSourceBase`, capabilities, availability mapping, auth, register in
    bootstrap, tests), with a minimal example. Be honest that Flutter AOT
    builds cannot load Dart plugins at runtime — providers are compiled in.
