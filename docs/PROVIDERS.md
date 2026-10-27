# Credentialed providers: SoundCloud, Spotify, YouTube, Jamendo

What each integration does, what it deliberately does not do (and why), and
what you need to register. Facts verified on 2026-10-27; sources, quotes and
open questions are in `docs/research/API_NOTES.md`, the resulting product
rules in `docs/COMPLIANCE.md` (encoded in `lib/core/sources/source_policies.dart`).
Code: `lib/sources/{soundcloud,spotify,youtube,jamendo}/`. Wiring:
`lib/sources/PROVIDERS_WIRING.md`. Where credentials are entered and which
redirect URIs to register: `docs/CREDENTIALS.md`.

> Not legal advice. Where terms are ambiguous the code implements the more
> restrictive reading and says so below.

## Without credentials

Every source here needs developer credentials that Fermata does not ship.
Until they are configured a source reports:

* `credentialStatus.configured == false`, with the missing fields listed and
  the provider's developer portal as `helpUrl`;
* `authState.status == credentialsMissing` and `isReady == false`;
* `MissingCredentialsException` from every call, before any network request.

No fake or cached results are produced. The *Connected services* page explains
what to configure.

## Summary

| | SoundCloud | Spotify | YouTube / YT Music | Jamendo |
|---|---|---|---|---|
| Source id | `soundcloud` | `spotify` | `youtube` | `jamendo` |
| Credentials | `clientId` + `clientSecret` | `clientId` | `apiKey` and/or `clientId` (+ `clientSecret` that Google issues to Desktop clients) | `clientId` |
| Account sign-in | OAuth 2.1 code + PKCE (optional for browsing) | OAuth code + PKCE, no secret | Google OAuth, desktop only | none |
| In-app playback | Yes, siloed queue | No (open in Spotify) | No (open in YouTube Music) | Yes |
| Downloads | Never | Never | Never | Single tracks, user-initiated, when `audiodownload_allowed` |
| Playback rights | `streamOnly` / `preview` / `unavailable` | `externalOnly` | `externalOnly` | `streamOnly` or `downloadable` |
| Main limit | ~1,500 stream resolutions/day/app | Dev mode: 5 users, owner needs Premium | 100 searches/day/project | 35,000 requests/month (non-commercial) |

## SoundCloud (`SoundCloudSource`)

### What works
* Search tracks, users and playlists (`linked_partitioning=true`; the cursor
  wraps SoundCloud's `next_href` and is only followed on `api.soundcloud.com`).
* Track, user, uploader's tracks (`userTracks`, also `artistTopTracks`),
  related tracks, related users, playlists with all tracks (200 per page).
* Share links via `/resolve`: `soundcloud.com/...`, private
  `.../s-<token>` links (the secret token is kept with the track) and
  `on.soundcloud.com/<code>` short links (`resolveShareUrl`, and `getTrack` /
  `getPlaylist` accept links).
* With a connected account: `/me`, liked tracks, own playlists (blocked
  tracks are kept in imports and marked unavailable).
* Public browsing and streaming without connecting: an app token from the
  `client_credentials` grant (HTTP Basic, cached in memory and in the token
  store, renewed before a new grant because of the 50 tokens/12 h limit).
* Ids are URNs (`soundcloud:tracks:123`); legacy numeric ids and API URLs
  are converted. Numeric parts are never parsed out of URNs.
* Streaming: `/tracks/{urn}/streams`, preferring `hls_aac_160_url` →
  `hls_aac_96_url` → `hls_mp3_128_url` (low quality prefers AAC 96);
  `preview_mp3_128_url` for preview-only tracks. The stream URL needs the
  token, so `resolveStream` follows the authorized 302 itself and returns the
  signed CDN URL (plus headers if the API answers 200 instead). media_kit and
  ExoPlayer play HLS. Resolved URLs are cached only for their lifetime.
* Availability from `access` (playable / preview / blocked), `streamable`,
  `policy`, deleted (404), private (403) and region-restricted tracks;
  stale availability is re-checked before playback.
* Attribution: `Track.permalink` (the track on soundcloud.com),
  `extra['soundcloud.uploader']`, `extra['soundcloud.uploaderUrl']`.
* `externalPlaybackUri` returns the soundcloud.com page ("Open in SoundCloud").

### What does not, and why
* **No downloads or offline, ever.** The API Terms forbid file-save, caching
  and offline access "regardless of whether Uploaders have set that User
  Content as allowed to be downloaded". Tracks get `OfflineRights.streamOnly`
  even when `downloadable` is true (kept only as
  `extra['soundcloud.uploaderDownloadable']` for display), the `download`
  capability is not declared, and `authorizeDownload` returns null. Only the
  stream URL is cached, in memory.
* **Siloed playback.** The terms forbid playback experiences that combine
  SoundCloud with other services. `SourcePolicies` marks SoundCloud as
  `siloedPlayback`; the playback engine keeps SoundCloud streams out of open
  queues. Written confirmation from SoundCloud is advisable before shipping
  publicly (`docs/COMPLIANCE.md`).
* **No trending.** The API has no trending endpoint, so the capability is not
  declared.
* **Registration is restricted.** SoundCloud currently issues API keys only
  to Artist Pro subscribers, one app per person, so users bring their own
  credentials (`limitationsNote` says so). The secret is required for every
  token request, so it cannot be embedded in a public binary.
* Likes, reposts, follows and comments are not implemented (the terms allow
  them only when explicitly user-initiated).

### Credentials and registration
* Register at https://soundcloud.com/you/apps (or SoundCloud's `sc-api-auth`
  CLI): copy the Client ID and Client Secret.
* Redirect URIs: `http://127.0.0.1:43821/callback/soundcloud` (Linux,
  Windows) and `fermata://oauth/soundcloud` (Android, sent with
  `display=popup`).
* Endpoints: authorize `https://secure.soundcloud.com/authorize`, token
  `https://secure.soundcloud.com/oauth/token`. Header
  `Authorization: OAuth <token>` (not `Bearer`). No scopes are documented.
  Disconnect calls `POST /disconnect` and deletes the local token; the app
  token is dropped when the credentials change.

### Limits
* About 100 requests/minute per `client_id`; search 3,000/hour; likes
  500/day; playback `/streams` **1,500/day** (the docs also mention 15,000;
  Fermata designs for the smaller number). The budget is shared by everyone
  using the same `client_id`.
* `SoundCloudRateGate` blocks a group after a 429 (or `X-RateLimit-Remaining: 0`)
  until `Retry-After` / `X-RateLimit-Reset` and throws `RateLimitedException`
  without sending requests; it also caps stream resolutions at 1,500 per
  rolling 24 hours (in memory).
* Callers must not prefetch streams speculatively: resolve the current track
  and at most one track ahead.

### Attribution
Show the uploader as the creator, credit SoundCloud with its logo (7-bar
Cloudmark, black on `#FF5500` or white on `#121212`, at least 30 px) and link
to `permalink`; for private tracks link to the uploader's profile. Do not use
"SoundCloud" in the app name.

### Uncertain
* Whether `Authorization` headers apply to HLS sub-requests in each player is
  unverified; the signed CDN URL avoids the question.
* Format of `available_country_codes` is undocumented; region blocks are
  detected from `access` and from `/streams` errors instead.
* Staff have said app-token (anonymous) playback "might deprecate"; connecting
  an account is the fallback if SoundCloud ends it.

## Spotify (`SpotifySource`)

### What works
* OAuth authorization code + PKCE, no client secret (a configured secret is
  never sent). Scopes: `playlist-read-private playlist-read-collaborative
  user-library-read`.
* `userPlaylists` (all pages), `getPlaylist` by id, `spotify:playlist:` URI,
  `open.spotify.com/playlist/...` link or `spotify.link` short link,
  `userLikedTracks` (50 per page), `searchTracks`, `getTrack`.
* Playlist items come from `GET /playlists/{id}/items` (the Feb 2026
  replacement of `/tracks`).
* `lookupByIsrc` uses `search?q=isrc:<CODE>&type=track` and prefers an exact
  `external_ids.isrc` match.
* Mapped: ISRC, explicit, album, duration, artists, artwork, `permalink`
  (`open.spotify.com/track/<id>`).

### What does not, and why
* **No audio.** `PlaybackRights.externalOnly`: `externalPlaybackUri` is
  `https://open.spotify.com/track/<id>`; `resolveStream` throws
  `UnplayableTrackException(externalOnly)`; never downloadable
  (`authorizeDownload` is null). Spotify's terms do not permit third-party
  playback, caching or ripping; tracks are matched to other sources instead.
* **Only owned or collaborative playlists can be imported.** For others,
  Spotify omits the items (or answers 403) and Fermata throws
  `SpotifyPlaylistNotAccessibleException` with an explanation. `userPlaylists`
  still lists them and `isImportable(playlist)` tells which can be imported.
* **Search pages hold at most 10 tracks** (Feb 2026), offsets up to 1000.
* Related artists, recommendations, audio features and batch "Get Several"
  endpoints are gone for new apps and are not used.
* Treat Spotify as a one-shot, user-initiated import: do not keep a mirror of
  Spotify metadata or artwork, and delete Spotify-derived personal data when
  the user disconnects.

### Credentials and registration
* Register your own app at https://developer.spotify.com/dashboard.
  **Development mode** (the only realistic mode for individuals): the app
  owner needs an active Premium subscription and up to 5 users can sign in;
  add each one under *User Management* (others get 403).
* Redirect URIs: `http://127.0.0.1:43821/callback/spotify` (Linux, Windows;
  `localhost` is forbidden) and `fermata://oauth/spotify` (Android; the
  dashboard may reject custom schemes: test early).
* Authorize `https://accounts.spotify.com/authorize`, token
  `https://accounts.spotify.com/api/token`, header `Authorization: Bearer`.

### Limits
* App-wide rolling 30-second rate limit (size undocumented) and a separate
  dev-mode quota counted per developer account; both answer 429 with
  `Retry-After` (surfaced as `RateLimitedException`).

### Attribution
Show Spotify content as supplied by Spotify with the Spotify logo and a link
back to the track or playlist (`permalink`); artwork unmodified. The app name
must not begin with "Spot".

### Uncertain
* Whether Spotify postponed the Feb 2026 endpoint changes for existing
  dev-mode apps is unconfirmed; new apps get the restricted set either way.
* The `spotify.link` redirect chain is undocumented; a link that does not end
  on `open.spotify.com` fails with an explanation.

## YouTube / YouTube Music (`YouTubeSource`)

### What works
* YouTube Data API v3 (there is no YouTube Music API). Either credential is
  enough to be "configured": an **API key** (search, public playlists,
  videos) and/or a **Google OAuth Desktop client** (the user's playlists and
  liked music; scope `https://www.googleapis.com/auth/youtube.readonly`).
* `searchTracks` (`type=video`, `videoCategoryId=10` Music, then one `videos`
  call for durations), `getTrack` (id, youtube.com, music.youtube.com or
  youtu.be link), `getPlaylist` (id or link; `playlistItems` 50 per page with
  `pageToken` cursors; deleted and private entries are marked unavailable),
  `userPlaylists` (`mine=true`), `userLikedTracks` (the account's likes
  playlist, Music category only).
* Titles such as "Artist - Title (Official Video)" and channel names
  ("Artist - Topic", "ArtistVEVO") are parsed into clean title and artist for
  matching; duration comes from `contentDetails.duration` (ISO 8601).

### What does not, and why
* **External playback only.** `PlaybackRights.externalOnly`,
  `https://music.youtube.com/watch?v=<id>`. YouTube's policies forbid audio
  extraction, background players, caching and offline use, so nothing is
  routed through Fermata's audio engine. `resolveStream` throws;
  `authorizeDownload` is null.
* **Connecting an account is desktop-only.** Google does not accept custom
  URI schemes or loopback redirects for Android clients and requires its
  Play-services `AuthorizationClient`, which Fermata does not use. On Android
  `connect()` throws `UnsupportedSourceOperation` with an explanation; an API
  key still gives search and public playlists.
* **Mixes (`RD...` playlists) and other generated lists** cannot be read
  through the API and get an explanation.
* **No credentials in the repository.** Google's terms forbid embedding API
  credentials in open-source projects: enter them in the app, in
  `credentials.json`, or in a private build (`docs/CREDENTIALS.md`).

### Credentials and registration
* https://console.cloud.google.com/apis/credentials: enable *YouTube Data
  API v3*, create an API key and/or an OAuth client of type **Desktop app**.
* Redirect URI: `http://127.0.0.1:43821/callback/youtube` (Desktop clients
  accept loopback redirects without registering them). Authorize
  `https://accounts.google.com/o/oauth2/v2/auth`, token
  `https://oauth2.googleapis.com/token`, PKCE S256.
* Unverified apps using the readonly scope are capped at 100 new users until
  the OAuth app is verified; this matters only for a shared client id.

### Quota
* `search.list` has its own bucket: **100 calls per day per project** (since
  June 2026), 1 unit each; every extra page is another call. All other list
  calls share 10,000 units/day at 1 unit each. A playlist page costs 3 units
  (`playlists`, `playlistItems`, `videos`); a search page
  costs 1 search call plus 1 unit. Daily quota resets at midnight Pacific Time.
* `YouTubeApi` counts searches locally (`searchCallsPerDay`, default 100;
  `searchCallsRemaining`), refuses further searches with
  `RateLimitedException`, and maps `quotaExceeded` to the same until the next
  Pacific-time reset.
* **Never use search in automatic matching loops**; matching should prefer
  other targets (Deezer, Audius, SoundCloud). Extra quota needs Google's
  quota-extension audit, or users supply their own project's key.
* Non-authorized API data may be cached at most 30 days; delete user data
  within 7 days of a revocation request.

### Attribution
Show YouTube metadata with YouTube branding and link to the video; open it
in YouTube Music or the browser for playback.

### Uncertain
* `videoCategoryId=10` is the usual Music category id but the docs do not
  list it; resolve with `videoCategories.list` if results look wrong.
* Whether `youtube.readonly` counts as a "sensitive" scope is not stated in
  the YouTube docs; expect to need verification before a public release.

## Jamendo (`JamendoSource`)

### What works
* API v3 at `https://api.jamendo.com/v3.0/` with a free `client_id`:
  search tracks, artists, albums and playlists; track, artist, album tracks,
  playlist tracks (ids or jamendo.com / jamen.do links); artist's popular
  tracks; related tracks (`tracks/similar`); related artists (derived from
  similar tracks); trending (`popularity_week`, one per artist, optional genre
  tag); new releases; the documented featured genre list.
* Track queries pass `type=single albumtrack` (the default would return album
  tracks only) and `include=licenses musicinfo`.
* Streaming from the track's `audio` URL; `audioformat` per quality: low
  `mp31` (96 kbps), normal/high `mp32` (VBR), lossless `flac` (falls back to
  `mp32` when not offered). Stale availability is re-checked first.
* Downloads: `authorizeDownload` re-fetches the track and returns the
  official `audiodownload` URL (`mp32`) **only when `audiodownload_allowed`
  is true**; otherwise null. `OfflineRights.downloadable` is set from the same
  flag. `SourcePolicies` allows user-initiated downloads only: never
  automatic or offline caching.
* License: `extra['jamendo.license']` is the Creative Commons URL
  (`license_ccurl`); `Track.permalink` links back to the track on jamendo.com.

### What does not, and why
* **No account sign-in.** Jamendo's OAuth needs a client secret held by a
  server and has no PKCE, so only public data is used.
* **Non-commercial only** on the free tier (`nonCommercialOnly` in
  `SourcePolicies`); commercial use needs a contract with Jamendo.
* Jamendo's 2013 terms say apps must not be designed to cache content or offer
  offline access, while its 2021 tracks reference allows offering downloads
  of tracks whose artists enable them. Fermata offers a user-initiated single
  download only, never a sync or auto-download.

### Credentials and registration
* https://devportal.jamendo.com/ (free developer account; one account per
  person, one client id per application). The shared test id from the docs is
  not used.

### Limits
* Non-commercial: up to 35,000 API requests per month. Errors arrive in the
  body (`headers.code`): 6 → `RateLimitedException`, 5 → rejected client id
  (401), 11 → suspended application (403). `limit` is capped at 200.

### Attribution
Credit the artist as creator, show the track's Creative Commons license, link
back to jamendo.com, and do not use "Jamendo" in the app's name.

### Uncertain
* Several track fields (`license_ccurl`, `shareurl`, `position`, …) were not
  confirmed against live responses (a `client_id` was not available during
  research); the mapper tolerates their absence. Verify with the first real
  response.

## Tests

`flutter test test/sources/providers` (MockClient fixtures hand-written from
the documented response shapes, marked in each fixture file): mapping,
pagination cursors, availability and offline rights, share-link parsing, ISRC
lookup, missing credentials (no requests made), 401 → refresh → retry, 429 /
quota handling, Android and desktop connect behaviour, and the bootstrap
wiring (`wiring_test.dart`).
