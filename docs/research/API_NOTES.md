# Fermata: music-provider API research notes

Research date: **2026-10-27**. Every claim below links to the official source it was checked against on that date.
"**Docs silent**" means the official documentation does not answer the question; treat any implementation there as unverified.
"**Probed**" means a live unauthenticated `curl` against the public endpoint on 2026-10-27.

> Not legal advice. Where a clause is quoted, the quote is verbatim from the linked page; the "what Fermata may do" lines are an engineering reading of those clauses.

---

## 1. SoundCloud (highest priority)

### 1.1 Sources checked

| Source | Version / date visible |
|---|---|
| API Guide: https://developers.soundcloud.com/docs/api/guide | no date on page |
| Get an API key: https://developers.soundcloud.com/docs/api/register-app | no date on page |
| Rate Limits: https://developers.soundcloud.com/docs/api/rate-limits | no date on page |
| API Terms of Use: https://developers.soundcloud.com/docs/api/terms-of-use | "Effective Date: 30 March 2024" |
| Buttons & Logos: https://developers.soundcloud.com/docs/api/buttons-logos | no date on page |
| LLM context: https://developers.soundcloud.com/docs/llm-context | no date on page |
| OpenAPI spec: https://developers.soundcloud.com/docs/api/explorer/api.json (same as https://raw.githubusercontent.com/soundcloud/api/master/openapi/api.yaml) | `info.version: 1.0.0`, fetched 2026-10-27 |
| Release notes: https://github.com/soundcloud/api/releases | latest tag `2026-09-30` |
| Repo guide for agents: https://github.com/soundcloud/api/blob/master/Agents.md | fetched 2026-10-27 |
| Blog "Vibe Coding with SoundCloud" (self-serve keys): https://developers.soundcloud.com/blog/vibe-coding-ai-agent-docs-self-serve-api-keys | May 18, 2026 |
| Blog "API Credentials from Your Terminal, and OpenAPI on GitHub": https://developers.soundcloud.com/blog/api-credentials-cli-openapi-github | Jun 16, 2026 |
| Blog "Moving to Modern Streaming: AAC HLS [Deadline Extended]": https://developers.soundcloud.com/blog/api-streaming-urls | Sep 15, 2025 |
| Blog "Upcoming Update to SoundCloud API id fields" (URN): https://developers.soundcloud.com/blog/urn-num-to-string | Apr 29, 2025 |
| Blog "Upcoming changes to SoundCloud Access Tokens" (JWT): https://developers.soundcloud.com/blog/access-token-changes | Dec 2, 2024 |
| Blog "Migration to OAuth 2.1": https://developers.soundcloud.com/blog/oauth-migration | Apr 23, 2024 |
| Blog "New artist name field on our API": https://developers.soundcloud.com/blog/api-artist-metadata | Apr 3, 2025 |
| GitHub issue #441 (MP3/Opus deprecation, staff comments): https://github.com/soundcloud/api/issues/441 | comments up to Sep 29, 2026 |
| GitHub issue #478 (stream URLs need auth): https://github.com/soundcloud/api/issues/478 | Nov 2025, closed Jan 27, 2026 |

### 1.2 App registration in 2026

- **Registration is open again, but only for SoundCloud Artist Pro subscribers.** The register-app page says: "You need a SoundCloud Artist Pro subscription to register API applications and receive credentials." The May 18, 2026 blog post says: "If you have a SoundCloud Artist-Pro subscription, you can now instantly generate your own Client ID and Client Secret via our fully self-service portal." The same post says the portal "was closed for years" and that in 2025 access went through a chatbot ("Otto") review.
- **How to register:**
  - Browser: https://soundcloud.com/you/apps, then create an app with name, description and optional website, accept the terms, and copy the Client ID and Client Secret. The redirect URI is also edited on that page.
  - CLI (recommended by SoundCloud): `scripts/sc-api-auth.mjs` from https://github.com/soundcloud/api (Node 18+). `--remote` prints a pairing URL on `secure.soundcloud.com/activate/`. If an app already exists, the CLI returns its credentials instead of creating a second one.
- **One app per person:** Agents.md says "Currently, SoundCloud limits credentials to **one application per person**." The API ToU also says: "You must not attempt to obtain more client IDs than you reasonably require".
- **Inactive apps get revoked:** the repo README says "it's possible your API keys were revoked as unused for some time".
- **Docs silent:** whether non-Artist-Pro developers can register at all, and whether a key survives if the Artist Pro subscription lapses.
- **Implication for Fermata:** the client secret must stay off the client (see 1.3), so a shipped open-source/desktop binary cannot embed it. Choose one of these designs:
  - (a) Run a small Fermata-operated token proxy that holds the secret and performs the code exchange and refresh, or
  - (b) Use a "bring your own credentials" model, where an Artist Pro user registers their own app and pastes their `client_id`/`client_secret` into Fermata. That user is then the "developer" bound by the API ToU.

### 1.3 OAuth 2.1 flows and URLs

| Item | Value | Source |
|---|---|---|
| Authorize URL | `https://secure.soundcloud.com/authorize?client_id=…&redirect_uri=…&response_type=code&code_challenge=…&code_challenge_method=S256&state=…` | Guide, OpenAPI `securitySchemes.oAuth2_1` |
| Token URL (code exchange, refresh, client credentials) | `POST https://secure.soundcloud.com/oauth/token` (form-urlencoded) | Guide, OpenAPI |
| Legacy token URL | `api.soundcloud.com/oauth2/token`: **do not use** ("deprecated and does not support OAuth 2.1") | Agents.md |
| PKCE | **Required** (S256). OAuth 2.0 without PKCE was turned off after Oct 1, 2024 | Guide; OAuth 2.1 blog |
| `client_secret` on code exchange | **Required.** The documented body is `grant_type=authorization_code, client_id, client_secret, redirect_uri, code_verifier, code`, and the OpenAPI `OAuthToken` schema marks `client_secret` as required | Guide; OpenAPI |
| `client_secret` on refresh | **Required.** Body: `grant_type=refresh_token, client_id, client_secret, refresh_token` | Guide |
| Public-client support | **None.** "All clients are currently treated as confidential rather than public, meaning a secret is required to obtain a token." | Guide |
| Client Credentials | Supported, for public resources only ("search, playback, URL resolution"). Credentials go **only** in HTTP Basic: `Authorization: Basic base64(client_id:client_secret)`, body `grant_type=client_credentials`. "Sending credentials in the request body is not supported." | Guide |
| Client Credentials token limits | "50 tokens per 12 hours per application" and "30 tokens per 1 hour per IP address". Reuse tokens and refresh them instead of re-requesting | Guide |
| Access token lifetime | ~1 hour (`expires_in`). Tokens are JWTs since late 2024, with no size guarantee, so do not store them in a 255-char column | Guide; access-token blog |
| Refresh tokens | **Single-use.** Persist the new `refresh_token` from every refresh response | Guide |
| Token response fields | `access_token`, `refresh_token`, `expires_in`, `scope` | Guide |
| Scopes | The OpenAPI lists `scopes: {}`, so no scopes are documented | OpenAPI |
| API request header | `Authorization: OAuth ACCESS_TOKEN`. The scheme word is **`OAuth`, not `Bearer`**. Every request needs it, including public ones, otherwise the API returns 401 | Guide; OpenAPI `AuthHeader` |
| Mobile/desktop redirect | "Use a custom protocol scheme for the redirect_uri (e.g., `my-app://soundcloud/callback`)". Add `display=popup` for the mobile-optimised connect screen | Guide, "Mobile and Desktop Applications" |
| Disconnect | `POST https://api.soundcloud.com/disconnect` returns 204 and revokes the app's tokens for that user. The ToU requires an easy disconnect mechanism and deletion of the user's data within 7 days | Guide; ToU "Account Linking" |
| Sign-out | `POST https://api.soundcloud.com/sign-out` ends the user's SoundCloud session as well. Do not use it for "disconnect" | Guide |

- **Probed:** `GET https://api.soundcloud.com/tracks?q=test` without auth returned `401` with body `{"code":401,"message":"","link":"https://developers.soundcloud.com/docs/api/explorer/open-api","status":"401 - Unauthorized","errors":[],"error":null}`.
- **No anonymous `client_id=` query access is documented.**
- **ToU wording conflicts with the guide on the OAuth UI.** The ToU (2024) still says: "All requests for authenticated access to a user's SoundCloud account (other than your own account) must be made via the 'Connect with SoundCloud' webview OAuth process, unless we've made a separate arrangement with you." The current guide instead describes a browser redirect with a custom-scheme `redirect_uri`. Engineering reading: a Custom Tab or system browser showing SoundCloud's own login page satisfies the intent, since the user authenticates on SoundCloud's page. The docs do not explicitly reconcile the two wordings.

### 1.4 ID to URN migration

- **Since Apr 29, 2025, `id` is deprecated and `urn` is the identifier.** Examples: `soundcloud:tracks:12345678`, `soundcloud:playlists:98765432`, `soundcloud:users:948745750`, `soundcloud:comments:…`. The blog says: "By June 30th, 2025: Clients must switch to using the urn field. After June 30th: Services relying on the id field may experience degraded behavior."
- **Endpoints take URNs in the path,** for example `GET https://api.soundcloud.com/tracks/soundcloud:tracks:12345678`. The OpenAPI path params are `{track_urn}`, `{playlist_urn}` and `{user_urn}`, e.g. `soundcloud:tracks:308946187`. The blog says "All the endpoints are ready to take either id or urn", but "Accessing via id is deprecated". Use URNs only.
- **Treat the URN as an opaque primary key.** SoundCloud "strongly discourage[s]" parsing the numeric part out of it.
- **Other URN-shaped fields:** `station_urn` (`soundcloud:system-playlists:track-stations:{id}`) and `Playlist.user_urn`.
- **Search filter by URN:** the `urns` query parameter on `GET /tracks` and `GET /users`. The guide still shows the older `ids=1,2,3` in examples.

### 1.5 Endpoints Fermata needs

Base URL `https://api.soundcloud.com`. Every request sends `Authorization: OAuth <token>`.

| Purpose | Endpoint | Token type | Notes |
|---|---|---|---|
| Search tracks | `GET /tracks?q=&access=playable,preview&limit=&linked_partitioning=true` | client-credentials or user | Filters: `genres`, `tags`, `bpm[from]/[to]`, `duration[from]/[to]`, `created_at`, `urns`, `access`. `offset` is deprecated |
| Search users | `GET /users?q=&limit=&linked_partitioning=true` | either | |
| Search playlists | `GET /playlists?q=&show_tracks=false&access=&limit=&linked_partitioning=true` | either | Use `show_tracks=false` for result lists |
| Current user | `GET /me` | user (auth code) | Returns the `Me` schema |
| Liked tracks | `GET /me/likes/tracks?limit=&linked_partitioning=true&access=` | user | `access` defaults to `playable,preview,blocked` here |
| Liked playlists | `GET /me/likes/playlists` | user | |
| User's own playlists | `GET /me/playlists?show_tracks=false&linked_partitioning=true&limit=` | user | "Returns playlist info, playlist tracks and tracks owner info" |
| Recently played | `GET /me/recently-played/tracks` | user | Up to 25 tracks, no pagination (release 2026-06-15) |
| Playlist | `GET /playlists/{playlist_urn}?show_tracks=true\|false&access=&secret_token=` | either | `show_tracks` defaults to `true` |
| Playlist tracks (paged) | `GET /playlists/{playlist_urn}/tracks?linked_partitioning=true&access=` | either | Use this for long playlists |
| Resolve permalink | `GET /resolve?url=https://soundcloud.com/...` | either | Returns **302** to the API resource URL. Also resolves `on.soundcloud.com` short links and station permalinks |
| Track | `GET /tracks/{track_urn}?secret_token=` | either | |
| Stream URLs | `GET /tracks/{track_urn}/streams?secret_token=` | either (see 1.6) | Returns the `Streams` object |
| Preview | `GET /tracks/{track_urn}/preview` | either | Returns 302 to a preview |
| Related tracks | `GET /tracks/{track_urn}/related?access=&limit=&linked_partitioning=true` | either | |
| Related artists | `GET /users/{user_urn}/related?limit=&linked_partitioning=true` | either | |
| User's tracks | `GET /users/{user_urn}/tracks?limit=&linked_partitioning=true&sort=asc\|desc` | either | `sort` added 2026-07-19 |
| User's playlists | `GET /users/{user_urn}/playlists` | either | |
| Station | `GET /system-playlists/{id}` | either | Added 2026-09-16 |
| Like / unlike | `POST` / `DELETE /likes/tracks/{track_urn}` | user | Only when the user initiates it (ToU) |
| Download | **Not in the OpenAPI spec.** The Rate Limits page names `GET /tracks/:id/download` (limit 10/min), and `Track.download_url` is "URL to download a track. Omitted or null when track is not downloadable." | n/a | **Fermata must not use this in-app. See 1.8** |

**Pagination.** Collections default to 50 items, maximum 200 (`limit`). With `linked_partitioning=true` the response is `{ "collection": [...], "next_href": "https://api.soundcloud.com/...&cursor=..." }`. Follow `next_href`; when it is absent there are no more pages. Unpaged list responses are deprecated.

**Track fields** (OpenAPI `Track` schema):
- Identity and links: `urn`, `kind`, `title`, `permalink_url` (needed for attribution), `uri`, `secret_uri`.
- Credits: `user` (User object), `metadata_artist` (artist name when it differs from the uploader), `label_name`.
- Media: `artwork_url`, `waveform_url`, `duration` (ms).
- Catalogue metadata: `genre`, `tag_list`, `bpm`, `key_signature`, `isrc`, `release`, `release_day`, `release_month`, `release_year`, `license`, `purchase_url`, `purchase_title`, `created_at`, `description`.
- Availability: **`access`**, **`streamable`**, **`downloadable`**, **`download_url`**, **`available_country_codes`**, `sharing` (public/private), `station_urn`.
- Counts and visibility: `playback_count`, `favoritings_count`, `comment_count`, `reposts_count`, `download_count`, `reveal_stats`, `reveal_comments`, `user_favorite`.
- `stream_url` is deprecated and documented as "URL to stream (preview only)".

**Playlist fields:** `urn`, `title`, `user`, `user_urn`, `artwork_url`, `duration`, `track_count`, `tracks`, `tracks_uri`, `permalink_url`, `sharing`, `playlist_type`, `type`, `release*`, `streamable`, `downloadable`, `likes_count`, `tag_list`, `genre`, `label_name`, `ean`.

**User fields:** `urn`, `username`, `full_name`, `avatar_url`, `permalink_url`, `followers_count`, `followings_count`, `track_count`, `playlist_count`, `public_favorites_count`, `city`, `country`, `plan`, `station_urn`, `subscriptions`.

### 1.6 Streaming formats (`/tracks/{urn}/streams`)

- **Current `Streams` schema** in the OpenAPI spec (fetched 2026-10-27): `hls_aac_160_url`, `hls_mp3_128_url`, `preview_mp3_128_url`.
- **Field-by-field status:**

| Field | Status | Source |
|---|---|---|
| `hls_aac_160_url` | **Preferred** | Blog Sep 15, 2025 |
| `hls_aac_96_url` | Fallback "where available". Staff (Apr 2026) call it the "preferred solution going forward" for low-bitrate sources. Not in the OpenAPI `Streams` schema | Blog; issue #441 |
| `hls_mp3_128_url` | Still returned. Staff, Aug 17, 2026: "hls mp3 we will keep until all (most) tracks have been migrated to aac". Some tracks may stay MP3-only "for up to a year" | Issue #441 |
| `http_mp3_128_url` (progressive) | **Removed.** Release `2026-08-12`/`2026-08-14`: "no longer returns `http_mp3_128_url`" | Releases |
| `hls_opus_64_url` | Announced for removal. Staff: "Opus is not even officially supported via HLS". **Docs silent** on whether it is already gone, and it is not in the schema. Do not rely on it | Blog; issue #441 |
| `preview_mp3_128_url` | Kept "for preview use cases" (30 s snippet) | Blog |

- **Player selection order:** `hls_aac_160_url` → `hls_aac_96_url` → `hls_mp3_128_url` → (preview only if `access == preview`) `preview_mp3_128_url`. Staff say "look for AAC first and MP3 second" and "AAC is the only streaming format we're supporting going forward" (Sep 29, 2026).
- **The URLs returned by `/streams` need the token too.** They look like `https://api.soundcloud.com/tracks/<urn>/streams/<uuid>/...`. Staff, Nov 14, 2025: "The calls to the streaming endpoint you get from `/streams` still need to stay authenticated (with a valid token)." An authenticated request answers with a 302 to a signed CDN URL (`expires=`) that plays without auth. Practical consequences:
  - Pass `Authorization: OAuth …` as a header to the player (media_kit/just_audio both support headers), **or**
  - resolve the 302 yourself just before playback. Never cache the signed URL for long.
- **Anonymous playback may go away.** Staff (Nov 20, 2025) said anonymous (client-credentials) playback "might deprecate in the future" and suggested user login. This is an unofficial comment.
- **DRM:** none mentioned. **Docs silent.**
- **Guide inconsistency:** the guide still shows `stream_url` and `/tracks/TRACK_ID/stream`, while Agents.md and the skills say "Use `/tracks/{track_urn}/streams` (not legacy `/stream`)". Use `/streams`.
- **Access levels** (`access` field, nullable): `playable` (full track), `preview` (snippet only), `blocked` (metadata only: "Restricted tracks have no stream_url and their access field is set to blocked. Calling /tracks/:id/streams for a blocked track returns an error."). Tracks may be "restricted by the creator, paywalled, or geo-blocked." The `access` query filter on search and lists defaults to `playable,preview` (search) or `playable,preview,blocked` (`/me/likes/tracks`).
- **Region signals:** `access` (evaluated for the caller), `available_country_codes` (string), and an error from `/streams`. **Docs silent** on the exact format of `available_country_codes`.
- **`streamable` (boolean):** documented only as "Is streamable." Treat `access` as authoritative for playback decisions.

### 1.7 Rate limits

Source: the Rate Limits page.
- **General budget:** about 100 requests/minute per `client_id`, on a rolling 1-minute window.
- **Stricter endpoint groups (typical defaults):**

| Area | Window | Limit |
|---|---|---|
| Playback (`GET /tracks/:id/stream(s)`) | 24 h | 1,500 |
| Search | 1 h | 3,000 |
| Downloads (`GET /tracks/:id/download`) | 1 min | 10 |
| Reposts | 24 h | 500 |
| Likes, including listing likes | 24 h | 500 |

- Approved "higher production access" apps "may receive up to 10× these limits".
- **Headers:** `X-Ratelimit-Limit`, `X-Ratelimit-Remaining`, `X-Ratelimit-Reset` (unix seconds). Over a limit the API returns **429** with `Retry-After` when present.
- **Conflict:** the LLM-context page and the repo skills say "15,000 play-stream requests per 24h per client_id", which is 10× the Rate Limits page. Design for **1,500/day per client_id**. That budget is shared by *all* Fermata users if Fermata ships one client_id, which is another argument for bring-your-own-credentials.
- Token endpoint limits: see 1.3.
- **Probed:** an anonymous request to `/tracks/{urn}` returned `429`, so the anonymous budget is already exhausted by other callers. Do not rely on unauthenticated calls.

### 1.8 API Terms of Use: what Fermata may and may not do

Source: https://developers.soundcloud.com/docs/api/terms-of-use (Effective Date: 30 March 2024).

**Attribution** (ToU "Attribution and Branding"; Buttons & Logos page; Guide "Streaming Tracks").

The ToU says: "When displaying or streaming User Content, you must ensure that your app:
- credits the Uploader as the creator of that User Content;
- credits SoundCloud as the source of that User Content; and
- includes (in the case of web pages and mobile web pages) clearly visible backlinks from the relevant sounds within your app to the URL for the relevant sound on soundcloud.com (permalink_url)."

For custom players, the Guide and the Buttons & Logos page add:
- "Credit the uploader as the creator of the track"
- "Credit SoundCloud as the source by including one of the logos"
- "Link to the SoundCloud URL containing the work"
- "If the track is private, link to the profile of the creator"

What this means for Fermata's UI:
- Show `user.username` (or `metadata_artist`) as the creator, plus a SoundCloud logo that links to `permalink_url`, on the now-playing screen and on lists showing SoundCloud data.
- "Place these logos where SoundCloud data is displayed. The logo must link back to the data source (e.g. SoundCloud profile, track, or playlist page)."
- "If a substantial portion of your app or site's functionality depends on the SoundCloud API, include one of these logos on screens where the API is used. The logo should link to soundcloud.com."

**Logo rules** (Buttons & Logos):
- Use the 7-bar Cloudmark only. The 13-bar or legacy orange logo is not allowed.
- Black logo on orange `#FF5500`, or white logo on black `#121212`.
- Minimum 30 px wide. No recolouring or distortion.
- "Connect with SoundCloud" button assets come in 24, 36 and 44 px heights.

**Naming:**
- Do not use "SoundCloud" in the app name, icon or domain.
- In descriptions, write "SoundCloud" or "SOUNDCLOUD".
- Do not imply endorsement.

**Offline storage and caching** (ToU "Caching and Downloading", verbatim): "Your app must not include file-save functionality, or otherwise designed to cache, download or persistently store any User Content. Your app may employ session-based caching, but only to the extent reasonably necessary for the operation of your app during that session, and any cached content must cease to be available, accessible or playable within your app at the end of that session. [...] Except for session-based caching referred to above, your app must not offer offline access to any User Content including, in the case of audio User Content, as permanent downloads or temporary downloads for offline listening, **regardless of whether Uploaders have set that User Content as allowed to be downloaded on the SoundCloud platform**."

- **MAY:** stream with HLS buffering, and hold an in-memory or temporary cache that is wiped at the end of the session. Cache metadata only as needed, and reflect uploader changes such as deletion or API access disabled "as soon as reasonably possible".
- **MAY NOT:**
  - offer a download button or offline mode for SoundCloud audio, even when `downloadable == true` and `download_url` is present;
  - write SoundCloud audio to persistent storage;
  - keep the audio cache across app restarts.
- **Suggested compliant alternative for downloadable tracks:** an "Open on SoundCloud" link to `permalink_url`, where the user can download on soundcloud.com. That reading is ours; the ToU does not address external links to the download page.
- The ToU also bans "stream ripping, stream capture or similar applications designed to make permanent copies".

**Aggregation with other services** (critical for a multi-provider player). The ToU says: "Regardless of any permissions set by any Uploader [...] you must not use the SoundCloud API, or any User Content accessible via the SoundCloud API, for any of the following purposes: [...] except wherever the aforementioned acts are explicitly licensed for such use, to create any kind of alternative digital content service, including: any service that aggregates and streams User Content from multiple users into an on-demand listening service, **or any playback experience which aggregates and streams User Content with content from other services (e.g. SoundCloud with YouTube)**".

- **Engineering reading:** mixing SoundCloud streams with other providers in one queue, playlist or "universal search → play" experience is expressly prohibited without a licence from SoundCloud.
- The first clause, on aggregating multiple users into an on-demand service, is broad enough that even a SoundCloud-only player could be argued to fall under it. **The ToU does not define the boundary; get written confirmation from SoundCloud before shipping SoundCloud playback.**
- **Lower-risk alternative:** SoundCloud as a separate, siloed source with no cross-provider queues, or only search plus "open in SoundCloud" or the official embedded widget.

**Other relevant restrictions:**
- Only "content [...] for which API access has not been enabled by the Uploader" is off-limits. Respect `access`.
- "attempt to circumvent any time or territorial restrictions" is forbidden.
- Do not access SoundCloud Go (subscriber-only) content.
- Do not "replicate a substantial number of features and/or the overall experience of SoundCloud", and do not copy the SoundCloud look and feel.
- No ads or sponsorship around User Content, and no in-app purchases for content or features available on SoundCloud.
- Likes, comments, follows and plays only when "specifically and deliberately initiated by the user".
- No use of User Content for AI training, fingerprinting, or as AI input such as source separation. This bans running audio fingerprinting or "AI stem separation" on SoundCloud audio.
- **Privacy:** Fermata must have a privacy policy. It must allow disconnect and delete the user's SoundCloud data within 7 days of disconnect.
- **Commercial use** is limited to the listed acceptable cases. A paid or ad-supported general player using SoundCloud content would need case-by-case approval.

---

## 2. Spotify Web API

### 2.1 Sources checked

| Source | Version / date visible |
|---|---|
| Quota modes: https://developer.spotify.com/documentation/web-api/concepts/quota-modes | fetched 2026-10-27 |
| Feb 2026 migration guide: https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide | Feb 11 / Mar 9, 2026 timeline, with a July 2026 note |
| Changelogs: https://developer.spotify.com/documentation/web-api/references/changes/february-2026, `/march-2026`, `/may-2026`, `/july-2026` | Feb–Jul 2026 |
| Redirect URIs: https://developer.spotify.com/documentation/web-api/concepts/redirect_uri | enforced for new apps from Apr 9, 2025; all apps by Nov 2025 |
| Blog "Increasing the security requirements…": https://developer.spotify.com/blog/2025-02-12-increasing-the-security-requirements-for-integrating-with-spotify | Feb 12, 2025 |
| Blog "Introducing some changes to our Web API": https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api | Nov 27, 2024 |
| PKCE tutorial: https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow | fetched 2026-10-27 |
| Scopes: https://developer.spotify.com/documentation/web-api/concepts/scopes | fetched 2026-10-27 |
| Rate limits: https://developer.spotify.com/documentation/web-api/concepts/rate-limits | fetched 2026-10-27 |
| Reference pages: get-playlists-items, get-users-saved-tracks, get-a-list-of-current-users-playlists, get-track (under https://developer.spotify.com/documentation/web-api/reference/) | fetched 2026-10-27 |
| Developer Terms: https://developer.spotify.com/terms | "Version 10, effective as of 15 May, 2025" |
| Developer Policy: https://developer.spotify.com/policy | "Effective as of 15 May, 2025" |
| Design & branding guidelines: https://developer.spotify.com/documentation/design | fetched 2026-10-27 |

### 2.2 Development mode rules (2026)

Source: Quota modes; Feb 2026 migration guide; July 2026 changelog.

- **The developer must have Premium.** "All Development Mode apps require the app owner to have an active Spotify Premium subscription. If the owner's Premium subscription lapses, the app will stop working." This applies to new apps since **Feb 11, 2026** and to existing dev-mode apps since **Mar 9, 2026**.
- **Users per app: 5.** "Up to 5 authenticated Spotify users can use an app that is in development mode". Each user must be added by name and email in Dashboard → app → Settings → **Users Management**. Users who are not on the allowlist can log in, but their API calls return **403**.
- **Client IDs per developer:** 1 from Feb 2026, **raised to 25 in July 2026**.
- **Quota.** Dev-mode quotas are counted **per developer account, not per Client ID** (July 2026). Exceeding one gives `429 {"error":{"status":429,"message":"Too many requests","reason":"QUOTA_EXCEEDED"}}`. Quota is separate from the app-wide rate limit, which uses a rolling 30-second window and is undocumented in size. Honour `Retry-After` on 429.
- **Extended quota mode is organisations only, since May 15, 2025:**
  - "Established Business Entity (legally registered business or organisation)"
  - "Operating an active, and Launched Service"
  - "at least 250k MAUs"
  - "Being available in key Spotify markets"
  - "Commercial Viability"
  - Review can take up to six weeks.
  - **Fermata, as an individual or small project, cannot realistically get extended quota.**
- **Practical consequence: bring your own app.** One shared Fermata client ID would serve at most 5 allow-listed users. A Spotify import feature is only viable if each Fermata user registers their **own** Spotify app with their own Premium account and enters the Client ID, adding themselves as the user.

### 2.3 OAuth (Authorization Code + PKCE)

| Item | Value |
|---|---|
| Authorize | `GET https://accounts.spotify.com/authorize?client_id=…&response_type=code&redirect_uri=…&code_challenge_method=S256&code_challenge=…&state=…&scope=…` |
| Token | `POST https://accounts.spotify.com/api/token` (form-urlencoded) with `grant_type=authorization_code, code, redirect_uri, client_id, code_verifier`. **No client secret** with PKCE, which is meant for apps "where the client secret can't be safely stored" |
| Refresh | Same token endpoint, `grant_type=refresh_token`, `refresh_token`, `client_id`. "the response might not include a new refresh token. If it does not, continue using the existing token." |
| Token response | `access_token`, `token_type` ("Bearer"), `scope`, `expires_in`, `refresh_token` |
| API header | `Authorization: Bearer <token>`; base `https://api.spotify.com/v1` |
| Implicit grant | Removed (migration deadline Nov 27, 2025) |

**Redirect URI rules** (Redirect URIs page; Feb 12, 2025 blog):
- "Use HTTPS for your redirect URI, unless you are using a loopback address, when HTTP is permitted."
- "If you are using a loopback address, use the explicit IPv4 or IPv6, like `http://127.0.0.1:PORT` or `http://[::1]:PORT`".
- "**localhost is not allowed** as redirect URI."
- **Ports:** "register your redirect URI with a loopback IP literal, but without any port number. You can add the dynamically assigned port number to the redirect URI in the authorization request." Dynamic ports work for loopback literals only.
- **Custom schemes:** the Feb 2025 blog says "Redirects using a custom scheme will still be supported" (e.g. `fermata://spotify-callback`). The current Redirect URIs page does not mention custom schemes at all. One community report (CommonsWare blog, Apr 2025) says some custom schemes were rejected by the dashboard. **Unverified**: test registering the exact scheme in the dashboard early.
- The registered URI must match exactly, including case and trailing slash, except for the loopback port.

**Recommended:**
- **Desktop (Linux/Windows):** loopback `http://127.0.0.1/callback`, registered without a port, with an ephemeral port at runtime.
- **Android:** custom scheme `com.example.fermata://spotify/callback` (reverse-DNS style) via Custom Tabs.

### 2.4 Scopes for import

| Need | Scope | Endpoint |
|---|---|---|
| List user's playlists (owned + followed) | `playlist-read-private` (and `playlist-read-collaborative` to include collaborative ones) | `GET /me/playlists?limit=50&offset=` |
| Read playlist items | `playlist-read-private` | `GET /playlists/{id}/items` |
| Saved ("Liked") tracks | `user-library-read` | `GET /me/tracks?limit=50&offset=` |
| Account linking id | none | `GET /me` → use **`account_id`** (added May 2026: "Use account_id rather than id when linking user accounts to your service") |

### 2.5 Endpoints and fields

- **`/playlists/{id}/tracks` has been replaced by `/playlists/{id}/items`.** This is confirmed by the Feb 2026 changelog: "[REMOVED] Get Playlist Items (GET /playlists/{id}/tracks) … Use GET /playlists/{id}/items instead".
  - Fields were renamed too: playlist `tracks` → `items`, `tracks.tracks` → `items.items`, `tracks.tracks.track` → `items.items.item`.
  - In playlist-item objects, `track` is a deprecated alias of `item`.
- **Big restriction (dev mode):** "Playlist contents (items) are only returned for playlists the user owns or collaborates on. For other playlists, only metadata is returned and the items field will be absent." The `GET /playlists/{id}/items` reference adds that other playlists return **403**. **Followed playlists made by other users or by Spotify cannot be imported.** Spotify-owned editorial and algorithmic playlists have been blocked for new apps since Nov 27, 2024.
- **`GET /playlists/{id}/items` parameters:** `market`, `fields` (e.g. `fields=next,total,items(added_at,is_local,item(name,uri,duration_ms,external_ids,artists(name),album(name)))`), `limit` (max 50, default 20), `offset`, `additional_types=track,episode`.
  - Item object: `added_at`, `added_by`, `is_local`, `item` (TrackObject or EpisodeObject).
  - Paging: `href`, `limit`, `next`, `offset`, `previous`, `total`.
- **`GET /me/tracks`:** limit max 50, items `{added_at, track}`.
- **TrackObject** (get-track reference):
  - Identity and links: `id`, `uri`, `external_urls.spotify` (needed for attribution and back-links).
  - Metadata: `name`, `artists[].name`, `album{name, images, release_date}`, `duration_ms`, `explicit`, `disc_number`, `track_number`, `is_local`.
  - Availability: `is_playable`, `restrictions.reason` (`market|product|explicit`).
  - **ISRC:** `external_ids.isrc` (also `ean`, `upc`). It was removed in Feb 2026 and **reinstated in March 2026** ("[REVERTED] external_ids … will continue to be available"). This is the key field for cross-service matching.
  - **Deprecated** (dev mode, Feb 2026): `popularity`, `available_markets`, `linked_from`, `preview_url`.
- **Search:** `GET /search?q=&type=track` with `limit` **max 10, default 5** (Feb 2026), and `offset` up to 1000. Field filters, per the Search reference: "`album`, `artist`, `track`, `year`, `upc`, `tag:hipster`, `tag:new`, `isrc`, and `genre`". So `q=isrc:USUM71703861` works for ISRC lookups (https://developer.spotify.com/documentation/web-api/reference/search).

**Removed or unavailable for new and dev-mode apps:**
- **Since Nov 27, 2024:**
  - Related Artists
  - Recommendations
  - Audio Features
  - Audio Analysis
  - Get Featured Playlists
  - Get Category's Playlists
  - 30-second preview URLs in multi-get responses
  - Algorithmic and Spotify-owned editorial playlists
- **Since Feb 2026:**
  - All batch "Get Several …" endpoints (`GET /tracks?ids=`, `/albums`, `/artists`, …)
  - `GET /artists/{id}/top-tracks`
  - `GET /browse/new-releases`, `/browse/categories*`
  - `GET /users/{id}`, `GET /users/{id}/playlists`, `GET /markets`
  - The per-type save/follow/contains endpoints, replaced by `PUT/DELETE /me/library` and `GET /me/library/contains` (Spotify URIs)
  - User fields `email`, `country`, `product`, `followers`, `explicit_content`
- A Spotify staff forum post (Feb 2026 update thread on community.spotify.com) said the endpoint changes for *existing* dev-mode apps were postponed. That is not reflected in the docs, and a **new** Fermata app gets the restricted set either way.

### 2.6 Audio: Fermata may not stream or download Spotify audio

- **The Web API returns no audio.**
- **Streaming definition.** The Developer Terms define "Streaming" as "using the Spotify Platform to enable playback of sound recordings available through the Spotify Service, including using the Spotify Platform to control a background Spotify application". Streaming is only possible through Spotify's own SDKs or Connect.
- **Premium only.** The Developer Policy IV says "Streaming of music sound recordings through the Spotify Platform shall only be made available to subscribers to the Premium Spotify Service."
- **No stream ripping.** The Terms IV forbid "facilitating 'stream ripping' or other functionalities that make it easier for users to capture or otherwise make permanent copies of Spotify Content".
- **No local audio caching.** The Terms say "Do not locally cache any Spotify Content, except … temporary caching of: metadata and cover art; or Conditional Downloads … only … to subscribers to the Premium Service."
- **No mixing.** Policy III: "Do not permit any device or system to segue, mix, re-mix, or overlap any Spotify Content with any other audio content".
- **Fermata scope:** metadata import plus "Open in Spotify" deep links (`external_urls.spotify` / `spotify:` URI) only. No in-app playback of Spotify tracks, and no preview playback, since `preview_url` is deprecated.

### 2.7 Cross-service matching / "playlist transfer": is it permitted?

Developer Policy §III ("Some prohibited applications"), verbatim:

> "Do not build an SDA that enables the transfer of data to another service, **except for the purpose of enabling a user to transfer their personal data, or the metadata of the user's playlists to another service.**"

**So:** importing the *user's own* playlist metadata (titles, artists, ISRCs) and finding equivalents on Deezer, YouTube and other services is **expressly carved out as permitted**.

The same section contains clauses Fermata must design around:

> "Do not create any product or service which is integrated with streams or content from another service."

> "Do not analyze the Spotify Content or the Spotify Service for any purpose, including without limitation, creating new or derived listenership metrics, benchmarking, functionality, usage statistics, user metrics, or building profiles of users…"

> "Do not build products or services that mimic, or replicate or attempt to replace a core user experience of Spotify … Your product or service must add independent value"

Developer Terms IV ("Storing Spotify Content"):

> "you may not store, aggregate or create compilations or databases of Spotify Content, other than as strictly necessary to operate your SDA … Do not store Spotify Content indefinitely."

Engineering reading:
- Treat Spotify as a **one-shot, user-initiated import source**. Fetch the user's playlists and saved tracks, match them on other providers, then store only the resulting non-Spotify references plus minimal provenance.
- Do **not** keep a persistent mirror of Spotify metadata or cover art.
- Do **not** display Spotify-branded items inside a queue that plays other services' streams, because of the "integrated with streams or content from another service" clause.
- Delete Spotify-derived personal data when the user disconnects (Policy I).
- The carve-out does not say whether ISRC matching counts as "analysis". We read the carve-out as covering it, because matching is inherent to "transfer … to another service".

### 2.8 Attribution / branding

- **Policy II:** "If you display any Spotify Content you must clearly attribute the content as being supplied and made available by Spotify, by using the Spotify Marks." Also: "Metadata, cover art and Audio Preview Clips must be accompanied by a link back to the applicable album, content or playlist on the Spotify Service."
- **Design guidelines:**
  - Use the full logo (icon + wordmark); the icon alone only when space is short.
  - Artwork stays unmodified: no crop, overlay or blur. Corner radius is 4 px on small and medium devices, 8 px on large.
  - Metadata must be shown as provided.
- **Naming:** the app name must not begin with "Spot" (Policy VI).

---

## 3. YouTube / YouTube Music

### 3.1 Sources checked

| Source | Version / date visible |
|---|---|
| YouTube developer products: https://developers.google.com/youtube | fetched 2026-10-27 |
| YouTube API Services Developer Policies: https://developers.google.com/youtube/terms/developer-policies | "Last updated 2026-10-15 UTC" |
| Required Minimum Functionality: https://developers.google.com/youtube/terms/required-minimum-functionality | "Last updated 2026-10-15 UTC" |
| YouTube API Services Terms of Service: https://developers.google.com/youtube/terms/api-services-terms-of-service | fetched 2026-10-27 |
| Data API Getting started: https://developers.google.com/youtube/v3/getting-started | "Last updated 2026-10-15 UTC" |
| Quota calculator: https://developers.google.com/youtube/v3/determine_quota_cost | "Last updated 2026-10-15 UTC" |
| Revision history: https://developers.google.com/youtube/v3/revision_history | entries to Oct 15, 2026 |
| `playlists.list`, `playlistItems.list`, `search.list`, `channels` reference: https://developers.google.com/youtube/v3/docs/ | fetched 2026-10-27 |
| OAuth 2.0 for installed apps (YouTube): https://developers.google.com/youtube/v3/guides/auth/installed-apps | fetched 2026-10-27 |
| Google OAuth for iOS & Desktop apps: https://developers.google.com/identity/protocols/oauth2/native-app | "Last updated 2026-10-16 UTC" |
| Android authorization (AuthorizationClient): https://developers.google.com/identity/authorization/android | "Last updated 2025-10-27 UTC" |
| Google unverified-app user cap FAQ: https://support.google.com/cloud/answer/13463817 | fetched 2026-10-27 |

### 3.2 YouTube Music has no official API (confirmed)

- **Google's YouTube developer product list has no Music product.** https://developers.google.com/youtube lists: embedded players (IFrame, iOS), the Data API, Analytics & Reporting, Subscribe Buttons, and Live Streaming. The page does not contain the word "music". No YouTube Music API exists in Google's developer documentation.
- **YouTube Music content is reachable only as ordinary YouTube videos and playlists** through the Data API. These are the same video IDs; `music.youtube.com/watch?v=ID` and `youtube.com/watch?v=ID` refer to the same video.
- **Unofficial libraries are not permitted.** Libraries such as `ytmusicapi` describe themselves as "not supported nor endorsed by Google" and emulate the web client with the user's cookies. The Developer Policies forbid that approach:
  - "You must not use undocumented APIs without express permission."
  - "use any technology other than YouTube API Services to access or retrieve API Data, including to access any portion of any YouTube audiovisual content".
  - Never collect the user's YouTube login or cookies: "API Clients must not … obtain, proxy, request, collect … cache, store, or use … YouTube user account login credentials".
- **Implication:** yt-dlp, NewPipe-extractor and ytmusicapi-style extraction is out of bounds for a compliant Fermata.

### 3.3 YouTube Data API v3

**Base URL:** `https://www.googleapis.com/youtube/v3/`

| Need | Call | Auth | Quota |
|---|---|---|---|
| Search (videos) | `GET search?part=snippet&q=…&type=video&maxResults=…&pageToken=…&key=API_KEY`. Optionally add `videoCategoryId=<Music category id>`, which requires `type=video`. The id is not listed in the docs fetched; look it up with `videoCategories.list?regionCode=…` (commonly `10`, unverified). Add `videoEmbeddable=true` to only return embeddable videos | API key | **Separate "Search Queries" bucket: default 100 calls/day, 1 unit per call** (since June 1, 2026) |
| User's playlists | `GET playlists?part=snippet,contentDetails&mine=true&maxResults=50&pageToken=…` | OAuth | 1 |
| Playlist contents | `GET playlistItems?part=snippet,contentDetails&playlistId=…&maxResults=50&pageToken=…` | API key for public playlists; OAuth for private ones | 1 |
| Liked videos | `GET channels?part=contentDetails&mine=true`, take `contentDetails.relatedPlaylists.likes`, then call `playlistItems` | OAuth | 1 + 1 |
| Video details (duration, embeddable, region) | `GET videos?part=snippet,contentDetails,status&id=a,b,c` | API key | 1 |

- **Pagination:** `maxResults` is 0–50 (default 5). Follow `nextPageToken` and pass it back as `pageToken`.
- **Default quota:** "Projects that enable the YouTube Data API have a default quota allocation of 100 search.list calls, 100 videos.insert calls, and 10,000 units per day combined for all other endpoints." Daily quotas reset at midnight Pacific Time. The **old 100-unit search cost no longer applies**. Instead there is a hard 100 searches/day per project (revision history, June 1, 2026). Extra pages each count as another call.
  - **Consequence:** a single shared API key cannot back in-app YouTube search for more than a handful of users. You must request a quota extension through the "Quota Extension Form" and pass the compliance audit, or have each user supply their own Google Cloud API key.
- **Scopes:** `https://www.googleapis.com/auth/youtube.readonly` ("View your YouTube account") covers `playlists?mine=true`, `channels?mine=true` and private `playlistItems`. Do not request `youtube` or `youtube.force-ssl` unless writing.
- **Scope classification:** the YouTube docs fetched do not state whether `youtube.readonly` is classified "sensitive" (**docs silent here**). Google's FAQ says unverified apps using sensitive or restricted scopes have a lifetime "100 new-user cap". Expect to need OAuth app verification before public release, and check the Data Access page in Cloud Console.
- **Credential secrecy:** "you must not … embed your API Credentials in open source projects." This is a direct constraint if Fermata's repo is public. Ship no API key or client ID/secret in source; use build-time injection or user-supplied keys.
- **Stored API data:**
  - Non-authorized data may be cached for at most **30 days**, then refreshed or deleted.
  - Authorized data: re-verify authorization every 30 days.
  - Delete a user's data within 7 days of a request or revocation.
  - The privacy policy must link https://security.google.com/settings/security/permissions.

### 3.4 Google OAuth for Fermata's platforms

Sources: native-app OAuth page; Android authorization page.

- **Desktop (Linux/Windows): use the "Desktop app" client type with a loopback redirect.**
  - The redirect is `http://127.0.0.1:PORT` or `http://[::1]:PORT`, on a random free port.
  - The loopback method is "the recommended mechanism" for "macOS, Linux, and Windows desktop apps". `localhost` is possible but "may cause issues with client firewalls".
  - Use PKCE (`code_challenge`, S256).
  - Auth endpoint: `https://accounts.google.com/o/oauth2/v2/auth`. Token endpoint: `https://oauth2.googleapis.com/token`.
  - The token-exchange table lists `client_secret` as "Optional". For Desktop clients Google issues a secret that cannot be kept confidential; the docs acknowledge "the client cannot keep the client_secret confidential".
- **Android: custom URI schemes are NOT accepted.**
  - "Custom URI schemes are no longer supported on Android and Chrome apps."
  - "The loopback IP address redirect option is DEPRECATED for Android, Chrome app and iOS OAuth client types."
  - Manual copy/paste (OOB) is deprecated.
  - Google's recommended path for Android is **`AuthorizationClient`** from Google Identity Services, using an Android client ID registered with package name and SHA-1. It needs no redirect URI but **requires Google Play services**.
  - Docs silent on a compliant path for Android devices without Play services. A "Web application" client with an https redirect would need a confidential secret, and therefore a backend.

### 3.5 Playback rules: audio-only, background, separating audio

The Developer Policies, §III.E ("Audiovisual Content") and §III.I ("Additional Prohibitions"), say API clients must not:
- "download, import, backup, cache, or store copies of YouTube audiovisual content without YouTube's prior written approval,"
- "make content available for offline playback,"
- "separate, isolate, or modify the audio or video components of any YouTube audiovisual content … For example, you must not apply alternate audio tracks to videos;"
- "promote separately the audio or video components of any YouTube audiovisual content"
- "create, include, or promote features that play content, including audio or video components, from a background player, meaning a player that is not displayed in the page, tab, or screen that the user is viewing;"
- "modify, build upon, or block any portion or functionality of a YouTube player;" and "modify, interfere with, replace, or block advertisements"
- "circumvent … any geographical restrictions"
- "mimic or replicate YouTube's core user experiences … unless they add significant independent value"

The Required Minimum Functionality page sets these rules for the embedded player:
- "Embedded players must have a viewport that is at least 200px by 200px". The recommended 16:9 minimum is 480×270.
- No autoplay until the player is "more than half … visible". Only one autoplaying player per screen.
- Playback-initiating thumbnails must be at least 120×70 px.
- **Identity via Referer.** In a WebView the app must set the HTTP Referer to `https://<app-id>`, for example `https://com.example.fermata` on Android. Use the Linux app ID (Flatpak/GNOME/Ubuntu ID) and the Windows package `Name`.
- WebView type on Android: "WebView or CustomTabs".

**Permitted:**
- Search and display YouTube metadata with YouTube branding (Branding Guidelines).
- Play videos **visibly** in the official IFrame/embedded player inside Fermata's foreground UI, at 200×200 px or larger, with ads and links intact.
- Hand off to the YouTube or YouTube Music app or the website.

**Not permitted:**
- Audio-only extraction or playing through Fermata's own audio engine.
- Background or locked-screen playback.
- Caching or downloading, offline mode.
- Ad blocking.
- Hiding the player.

**Recommended compliant integration:**
1. **Import:** read the user's YouTube playlists and likes (`youtube.readonly`) for matching and metadata only.
2. **Play:** either (a) embed the IFrame player in a visible webview pane (desktop: an OS WebView such as WebView2 or WebKitGTK; Android: `WebView`), with the Referer set; or (b) **open externally**. The default is (b) for a music player, because Fermata's background and queue model conflicts with the "no background player" rule. Deep links:
   - Video: `https://music.youtube.com/watch?v=VIDEO_ID` or `https://www.youtube.com/watch?v=VIDEO_ID`.
   - Playlist: `https://music.youtube.com/playlist?list=ID`.
   - On Android these are https App Links that the YouTube Music or YouTube app claim when installed; otherwise they open in the browser.
   Docs silent: Google publishes no official intent or deep-link spec for the YouTube Music app. The https URLs are the only stable public form.
3. **Never** route YouTube audio through just_audio, media_kit or similar.

---

## 4. Deezer

### 4.1 Sources checked

| Source | Version / date visible |
|---|---|
| Deezer for developers, Guidelines: https://developers.deezer.com/guidelines | no date |
| Deezer for developers, Terms of use: https://developers.deezer.com/termsofuse | no date (legacy "BLOGMUSIK" entity text) |
| API reference pages (https://developers.deezer.com/api, `/api/oauth`, `/api/search`, …) | **Login-gated**: "You have to login to accept the terms and conditions of the simple API." The reference could not be read without an account, so endpoint shapes below come from **live probes** |
| Live probes of `https://api.deezer.com/…` | 2026-10-27 |
| Community thread "Create developer app": https://en.deezercommunity.com/other-devices-49/create-developer-app-82800 | June 20, 2026 |

### 4.2 Public API (no auth). Probed 2026-10-27; all returned HTTP 200 with no key

Base URL: `https://api.deezer.com`. Collections are `{ "data": [...], "total": N, "next": "…&index=K" }`. Paginate with `index` and `limit`.

| Purpose | Endpoint | Probe result / key fields |
|---|---|---|
| Search tracks | `GET /search?q=…&limit=&index=` (also advanced syntax like `artist:"…" track:"…"`; that syntax is in the gated docs, not verified) | `data[]`: `id, readable, title, title_short, title_version, isrc, link, duration (s), rank, explicit_lyrics, explicit_content_lyrics, explicit_content_cover, preview, md5_image, artist{id,name,link,picture_*,tracklist}, album{id,title,cover_*,md5_image,tracklist}, type`, plus `total`, `next` |
| Search artists / playlists / albums | `GET /search/artist?q=`, `/search/playlist?q=`, `/search/album?q=` | artist `data[]`: `id, name, link, picture_*, nb_album, nb_fan, radio, tracklist`. Playlist `data[]`: `id, title, public, nb_tracks, link, picture_*, checksum, tracklist, creation_date, user` |
| Track | `GET /track/{id}` | `id, readable, title, isrc, link, share, duration, track_position, disk_number, rank, release_date, explicit_lyrics, preview, bpm, gain, available_countries[], contributors[], md5_image, track_token, artist{…}, album{…}` |
| **Track by ISRC** | `GET /track/isrc:{ISRC}` | **Works.** `track/isrc:GBDUW0000059` returned track `3135556` ("Harder, Better, Faster, Stronger") |
| Album | `GET /album/{id}` (also `/album/upc:{UPC}`, documented in the gated reference and not probed) | `id, title, upc, link, cover_*, genre_id, genres, label, nb_tracks, duration, fans, release_date, record_type, available, tracklist, contributors, artist, tracks` |
| Playlist | `GET /playlist/{id}`; tracks paged via `GET /playlist/{id}/tracks?index=&limit=` | Playlist: `id, title, description, duration, public, collaborative, nb_tracks, fans, link, picture_*, checksum, creator, tracks{data[], checksum}`. Note `tracks` embedded in `/playlist/{id}` held 50 items with no `next`. Use `/playlist/{id}/tracks`, which has `total` and `next`; items add `time_add` |
| Related artists | `GET /artist/{id}/related` | `data[]` artists, `total`, `next` |
| Artist top tracks | `GET /artist/{id}/top?limit=50` (returned in the `tracklist` field) | |
| Chart | `GET /chart` (keys `tracks, albums, artists, playlists, podcasts`); `GET /chart/0/tracks` | Chart track items add `position` |
| Genres | `GET /genre` | `data[]`: `id, name, picture_*` |
| Editorial | `GET /editorial` (28 entries: "All", "Pop", "Rap/Hip Hop", …); `GET /editorial/{id}/charts` | **`GET /editorial/0/releases?limit=2` returned `{"data":[],"total":0}`**: empty at probe time, so do not rely on it |
| Radio | `GET /radio`, `GET /radio/{id}/tracks` | Radio: `id, title, picture_*, tracklist, md5_image` |

- **Errors** come back in an HTTP 200 body:
  - Not found: `{"error":{"type":"DataException","message":"no data","code":800}}`.
  - `/user/me` without a token: `{"error":{"type":"OAuthException","message":"An active access token must be used to query information about the current user","code":200}}`.
  - Always check for an `error` key, not just the HTTP status.
- **Previews:** `preview` is an MP3 URL on `cdnt-preview.dzcdn.net` with a signed `hdnea=exp=…` token. In the probe, `exp` was about 900 s after the response's `utm_term` timestamp, so **preview URLs expire after roughly 15 minutes**. That is an inference from the probe, not documented. Re-fetch the track just before playing.
- **Rate limits:** **docs silent or gated.** The reference is behind login, and the responses carried no rate-limit headers. A commonly cited figure (50 requests/5 s, error code 4 "Quota limit exceeded") could not be verified against current official docs. Implement backoff on any `error.code` of 4 and keep request rates low.

### 4.3 Are 30-second previews permitted for third-party playback?

**Yes, within the terms.** The Guidelines ("Content access rules") table gives "API: 30s. extract" for Unlogged, Freemium and Premium users on both Mixes and Music on Demand. Its "Available tools" table says the API gives "Full data access, but no audio streaming available except 30s extracts." The Guidelines also say:
- "**Streaming URL privacy.** Except for 30s. extracts mp3s, full-length tracks URLs must never be accessible to the end-user from your application. As the owner of your application, you are responsible for not making any audio data downloadable for the end-user."
- "**Local Storage/Offline Storage** of audio data is strictly forbidden."

**Terms of use constraints:**
- **§IV Non-commercial:** "use of the Services is strictly limited for a non-commercial purpose and in a non-commercial environment … the Developer shall not perceive, receive, generate … any moneys, incomes, revenues, data or any other consideration". The Content must not be "associated, directly or indirectly with any trademark, brand name, or logo". The Fermata brand is arguably caught by this; the clause is ambiguous.
- **§IV Private use:** the developer must inform users "that the streaming of the recordings is limited to a strictly private use within a family scope."
- **§V DRM:** do not bypass DRM. Full tracks are only for Premium users via official plugins/SDKs, and those SDKs are web/legacy native. **Fermata cannot stream full Deezer tracks.**
- **§II:** the Trademark Guidelines referenced for logo use are mandatory. The linked page `deezer.com/developers/simpleapi` is legacy, and the logo section on `/guidelines` ("Graphical Guidelines / Logo") did not render any content in our fetch, so **the current logo rules are unverified**. Minimum practice: label content "from Deezer", link each item to its `link` (`https://www.deezer.com/track/{id}`), and do not alter the Deezer logo.

**What Fermata may do:**
- Search and metadata, used heavily for matching. `isrc` is on every track, and `/track/isrc:` is the best ISRC resolver available without auth.
- 30 s preview playback, streamed rather than stored, with a link back to Deezer.
- "Open in Deezer" via `link` (https App Link to the Deezer app) or the `deezer://www.deezer.com/track/{id}` scheme. That scheme is not documented in the readable docs; the https link is safer.

**What Fermata may not do:**
- Full-track playback.
- Downloads or offline caching of audio, including previews.
- Commercial use.

### 4.4 New app registration / OAuth for user libraries (2026)

- **New app creation appears closed.**
  - The `myapps` page and the API docs are login-gated, and we have no credentials to check them.
  - Community reports from Feb 2025 onward say "Deezer has turned off My apps in the developer portal".
  - A June 20, 2026 forum answer by a community "Superuser" (not staff) says: "There's no information on when they'll reopen registration for that, or if they'll reopen it at all."
  - **No official Deezer statement was found.** Treat user-library import (OAuth) as **unavailable for new developers**; existing app IDs may still work.
- **OAuth endpoints exist but their parameters cannot be verified.** Probes confirmed the hosts respond: `https://connect.deezer.com/oauth/auth.php` returns 200, and `https://connect.deezer.com/oauth/access_token.php` returns "wrong code" with dummy values. The parameter names (`app_id`, `redirect_uri`, `perms=basic_access,offline_access,manage_library…`; token exchange with `app_id`, `secret`, `code`, `output=json`) come from older docs and are **not verifiable**: the docs are login-gated. The flow needs the app **secret**, so it is not suitable for a public client without a backend. **Docs silent** on PKCE and custom-scheme redirects.
- **Fallback for importing a user's Deezer playlists:** a **public** playlist can be read without auth via `GET /playlist/{id}/tracks`. The user pastes a playlist URL and Fermata extracts the ID. A user's **public** playlists also come back without a token: **probed** `GET /user/1687950/playlists?limit=1`, which returned `data[]` with `id, title, duration, public, is_loved_track, collaborative, nb_tracks, fans, link, picture_*`. So "import my public Deezer playlists by profile URL / user ID" works without OAuth. Private playlists and the "Loved tracks" playlist, if private, still need OAuth.

---

## 5. Audius

### 5.1 Sources checked

| Source | Version / date visible |
|---|---|
| Docs (LLM bundle of all pages): https://docs.audius.co/llms-full.txt (index: https://docs.audius.co/llms.txt) | fetched 2026-10-27 (docs.audius.org redirects to docs.audius.co) |
| OpenAPI: https://api.audius.co/v1/swagger.yaml | `openapi: 3.0.1`, `version: "1.0"`, fetched 2026-10-27 |
| Agent guide: https://audius.co/agents.md | fetched 2026-10-27 |
| API Terms (PDF): https://audius.co/documents/ApiTerms.pdf | "Last Updated: 2 July, 2025" |
| Audius Open Music License (OML): https://openaudiofoundation.org/open-music-license.pdf | "Last Updated: 2 July, 2025" |
| Audius Standard Terms of Use (PDF): https://audius.co/documents/TermsOfUse.pdf | "Last Updated: October 5, 2025" |
| Blog "Audius Terms of Service Update": https://blog.audius.co/posts/audius-terms-of-service-update | fetched 2026-10-27 |
| Live probes of `https://api.audius.co/v1/…` | 2026-10-27 |

### 5.2 Base URL, `app_name`, and API key

- **Base:** `https://api.audius.co/v1`. The single gateway replaces the older practice of picking a discovery node.
- **Credentials are not required for reads.** The OpenAPI says: "**Read-only** — Most endpoints work without credentials. Use an API key for higher rate limits." and "**Writes** — Upload, favorite, repost, and other mutations require an API key and secret."
- **`app_name` is no longer documented as required.** It appears **0 times** as a parameter in the current OpenAPI. The OAuth guide mentions it only as a fallback ("use `app_name` instead if you only need read scope and don't have an API key").
- **Probed:** `/tracks/trending`, `/tracks/search`, `/users/search`, `/playlists/search` and `/playlists/trending` all returned 200 with no key and no `app_name`.
- **API plans** (docs, "API Plans"): Free is "10 requests/second, 500,000 requests/month"; Unlimited is by contact (api@audius.co). Keys come from https://api.audius.co/plans or audius.co/settings → Developer Apps.
  - "**API Key** — used in all contexts (frontend and backend). Safe to include in client-side code."
  - "**Bearer Token** — backend only … **Never expose this in browser or mobile code.**"
- **Docs silent:** the rate limit for keyless requests.
- **Recommendation:** ship a Fermata API key (it is public-safe) and send it as `api_key=` where supported. Never ship the bearer token or API secret.
- Some tracks restrict access to specific API keys: `/stream` takes `api_key`, "required for tracks that only allow specific API keys", and tracks carry `allowed_api_keys`.

### 5.3 Endpoints (from swagger.yaml; probed where marked)

| Purpose | Endpoint | Notes |
|---|---|---|
| Search tracks | `GET /tracks/search?query=&limit=&offset=&genre=&mood=&sort_method=&only_downloadable=&bpm_min=&bpm_max=&key=` | **Probed** |
| Search users | `GET /users/search?query=` | **Probed** |
| Search playlists | `GET /playlists/search?query=` | **Probed** |
| Trending | `GET /tracks/trending?genre=&time=`, `/tracks/trending/underground`, `/playlists/trending` | **Probed** |
| Track | `GET /tracks/{track_id}` | |
| **Stream** | `GET /tracks/{track_id}/stream` returns a **302** to a signed content-node URL (`…/tracks/cidstream/<cid>?signature=…`). `no_redirect=true` returns `{"data":"<url>"}` instead. Also accepts `Range`, `preview=true`, `skip_play_count`, `api_key`, plus `user_id`/`user_signature` for gated tracks | **Probed:** 302, `location: https://creatornode.audius.co/tracks/cidstream/…`. The spec describes it as an "mp3" stream |
| **Download** | `GET /tracks/{track_id}/download?filename=` downloads "the original or MP3 file" | **Probed:** ungated downloadable track `oWgXra7` gave **302** to `…/cidstream/…?filename=…mp3&signature=…`. Follow-gated track `QVpmB` (`download_conditions: {"follow_user_id":…}`) gave **403** |
| Stems | `GET /tracks/{track_id}/stems`, `/tracks/{track_id}/stems/download` | |
| User | `GET /users/{id}`, `/users/handle/{handle}` | |
| User's tracks | `GET /users/{id}/tracks?offset=&limit=&sort=…`, `/users/handle/{handle}/tracks` | |
| User's playlists / library | `GET /users/{id}/playlists`; `/users/{id}/library/tracks\|playlists\|albums` (OAuth `read` for the user's own); `/users/{id}/favorites` | |
| Playlist | `GET /playlists/{playlist_id}`, `GET /playlists/{playlist_id}/tracks` | |
| Related / similar | **No track-level related endpoint.** There is `GET /users/{id}/related` ("users that might be of interest to followers of this user"), plus `GET /tracks/recommended` and `/tracks/{track_id}/remixes` | |
| Resolve | `GET /resolve?url=https://audius.co/...` returns a redirect to the API resource | |
| Me (OAuth) | `GET /me` with `Authorization: Bearer ACCESS_TOKEN` | |

**Example fields (probed `/tracks/trending`, response `{ "data": [ … ] }`):**
- Identity and links: `id` (short hash string, e.g. `"mzXmz1"`), `track_id`, `title`, `permalink` (`"/ciaragraves/on-the-floor"`, so the web URL is `https://audius.co` + permalink), `slug`.
- Metadata: `duration` (s), `genre`, `mood`, `tags`, `bpm`, `musical_key`, `release_date`, `isrc` (e.g. `"QZQAY2630197"`), `iswc`, `license` (e.g. `"All rights reserved"`).
- Media: `artwork{150x150,480x480,1000x1000,mirrors?}`, `stream{url,…}` (pre-signed stream URL), `preview`, `preview_cid`, `preview_start_seconds`.
- Availability and permissions:
  - `is_streamable`, `is_downloadable`, `is_original_available`.
  - **`access`** (e.g. `{"stream": true, "download": true}`, evaluated for the caller).
  - `is_stream_gated`, `stream_conditions`, `is_download_gated`, `download_conditions` (e.g. `{"follow_user_id": 190321}`).
  - `download` (null unless available), `orig_filename`, `allowed_api_keys`, `is_unlisted`, `is_delete`, `is_available`.
- Social and user: `play_count`, `favorite_count`, `repost_count`, `comment_count`; `user{id, handle, name, is_verified, profile_picture, …}`.

**Playlist fields (probed):** `id, playlist_name, playlist_owner_id, is_album, is_private, track_count, total_play_count, playlist_contents, tracks, artwork, permalink, upc, access, stream_conditions, user`.

**OAuth ("Log In With Audius"):**
- Authorization Code + PKCE. "no backend server or client secret is required".
- **Authorize:** `https://api.audius.co/v1/oauth/authorize?response_type=code&scope=read|write&api_key=…&redirect_uri=…&state=…&code_challenge=…&code_challenge_method=S256` (plus optional `response_mode=fragment|query`, `display=popup|fullScreen`). The code comes back in the URL **fragment** by default; set `response_mode=query` for native apps.
- **Token:** `POST https://api.audius.co/v1/oauth/token` with JSON `{grant_type:"authorization_code", code, code_verifier, client_id: API_KEY, redirect_uri}`. The response is `{access_token, refresh_token}`.
- **Refresh:** `grant_type: "refresh_token"`. **Revoke:** `POST /v1/oauth/revoke`.
- **Redirect URIs (contradictory docs):** the validation rules say "Must use `http` or `https`; Hosts cannot be raw IP addresses (localhost IPs are allowed)". The same page says "**Mobile (React Native)**: register a custom URL scheme (e.g. `myapp://oauth/callback`)". **Test both** before committing.
  - Desktop: `http://127.0.0.1:PORT/…` or `http://localhost:PORT` should be accepted, per "localhost IPs are allowed".
  - **Docs silent** on dynamic-port matching.

### 5.4 Terms: is full streaming and downloading permitted?

**Full streaming: yes.**
- OML §1.2: "Licensor hereby grants to Music Players a worldwide, non-exclusive, royalty-free, perpetual, irrevocable right and license, with the right to sublicense, to reproduce, publicly perform, distribute, electronically or digitally transmit, stream, and otherwise use in whole or part, the Licensed Material, in connection with a Music Player's services."
- Terms of Use: "By default, Content you upload to the Audius Service is made available to third-party services via the Audius API and is subject to the Open Music License". Artists can opt out with an API-access toggle, and opted-out content won't be served.
- Respect gating: `stream_conditions` (USDC purchase, follow, NFT …) and `access.stream`.

**Download: ambiguous. The documents point in different directions:**
- The API exposes `/tracks/{id}/download`, and probes show it works for creator-enabled downloads.
- The Terms of Use contemplate creators choosing whether listeners may download ("permitting a Listener to stream certain Content but not download or share such Content off-Audius Service").
- **But** the API Terms §"Content and Data Protection" say: "In the event you use the API or App to use and/or store content or consumer data, you may only use session-based caching to the extent necessary for the operation of the API or App during that respective session; any cached content or consumer data must become inaccessible and unavailable upon termination of the respective session."

Engineering reading:
- **Do not** build an offline library or persistent audio cache for Audius.
- A user-initiated "Download file" for tracks where `is_downloadable && access.download == true` and `download_conditions` is satisfied is the creator-granted download, and is the most defensible reading of a download. Save it to a user-chosen location as a plain file, not into Fermata's managed cache.
- If in doubt, open `https://audius.co{permalink}` instead.
- **Get written confirmation from Audius (api@audius.co) before shipping in-app downloads.**

**Attribution:**
- No attribution or logo requirement is stated in the API Terms or docs (docs silent).
- OML §1.5 applies **only for commercial use**: "the Licensee must retain: (a) identification of the Licensor … (b) a copyright notice … (c) a notice that refers to this OML; (d) a URI or hyperlink to the Licensed Material".
- **Recommended regardless:** show artist `user.name`/`handle`, link to `https://audius.co{permalink}`, and mention "via Audius".

**Other API Terms restrictions:**
- No making "the functionality of the API available to any third party", so no re-exposing it as an API.
- No benchmarking.
- No scraping ("use any scraping, data harvesting, web crawlers…").
- No AI training on content.
- "You agree to provide the users of your App(s) … with the Audius Privacy Policy and these API Terms." Link both in Fermata's About/Legal screen.
- Honour user setting changes "promptly".

---

## 6. Jamendo

### 6.1 Sources checked

| Source | Version / date visible |
|---|---|
| Developer landing: https://developer.jamendo.com/v3.0 | fetched 2026-10-27 |
| Authentication / OAuth2: https://developer.jamendo.com/v3.0/authentication | fetched 2026-10-27 |
| `GET /v3.0/tracks` reference: https://developer.jamendo.com/v3.0/tracks | mentions changes of Aug 2020 / Feb 2021 |
| API Terms of Use: https://devportal.jamendo.com/api_terms_of_use | "last modified on September 17, 2013" |
| Probe of `https://api.jamendo.com/v3.0/tracks/` without `client_id` | 2026-10-27 |

### 6.2 `client_id` requirement

- "**Every api call needs the 'client_id' GET parameter.** To get your client_id, you have to sign up for a developer account on our Developer Portal" (https://devportal.jamendo.com).
- **Probed without it:** `{"headers":{"status":"failed","code":5,"error_message":"Jamendo Api Invalid Client Id Error: Your credential is not authorized..",…},"results":[]}`. Errors arrive as `headers.status/code/error_message` in the body; check `headers.code == 0`.
- The docs publish a shared test id "ONLY for TESTING the read api". We did not use it. Fermata must register its own.
- **Account limit:** the ToU §2 allows "one account only per natural or legal person … Each application must be registered with a unique Client ID". The application "description" field "must contain the direct link toward the published application(s)".
- **Plans** (landing page): Non-Commercial apps get "Up to 35,000 API requests per month". Commercial apps get "Unlimited" by contract (talk-to-us@jamendo.com / licensing@jamendo.com).
- **Docs silent:** per-second rate limits.

### 6.3 Endpoints (base `https://api.jamendo.com/v3.0/`; add `client_id=…&format=json` to every call)

| Purpose | Endpoint / params |
|---|---|
| Track search | `tracks/?search=<free text>` or `namesearch=`, `tags=`, `fuzzytags=`, `artist_name=`, `album_name=`, `id=` (multiple), `order=relevance\|popularity_month\|…`, `boost=`, `groupby=artist_id`, `include=licenses+musicinfo+stats+lyrics`, `type=single+albumtrack`, `limit` (default 10, **max 200**), `offset`, `fullcount=true` (adds `headers.results_fullcount`) |
| Audio format | `audioformat=mp31\|mp32\|ogg\|flac` for the `audio` stream URL (default `mp31` = 96 kbps). `audiodlformat=…` for `audiodownload` (default `mp32` VBR) |
| License filters | `ccsa`, `ccnd`, `ccnc` booleans |
| Other read methods (docs index) | `albums`, `albums/tracks`, `artists`, `artists/tracks`, `artists/albums`, `artists/locations`, `autocomplete`, `feeds`, `playlists`, `playlists/tracks`, `radios`, `radios/stream`, `reviews/*`, `tracks/file` (file/stream redirect), `tracks/similar`, `users/*` |
| OAuth (user favourites/playlists) | Authorize: `GET https://api.jamendo.com/v3.0/oauth/authorize?client_id=…&redirect_uri=…&scope=music&response_type=code&state=…`. Grant: `POST https://api.jamendo.com/v3.0/oauth/grant` with `client_secret` ("This client_secret MUST stay SECRET!"), `grant_type`, `code`, `redirect_uri`. Access token valid "2 hours"; refresh tokens rotate. The `redirect_uri` must share the registered URL's prefix (example uses `http://yourdomain.com/yourapp/ANYTHING`). **No PKCE**, and the docs don't mention custom schemes, so treat as https-only with a backend holding the secret |

**Track fields named in the docs** (we could not probe without a client_id): `audio` (stream URL), `audiodownload` (download URL), **`audiodownload_allowed`** (boolean), `album_id`, `album_name`, `album_image`, `image`, `artist_name`, plus license info via `include=licenses`.
- Singles have empty `album_*` fields.
- The docs say: "in August 2020, the content of the field 'audiodownload' returned in this api will become an empty string if 'audiodownload_allowed' is false."
- Other common fields (`id`, `name`, `duration`, `artist_id`, `license_ccurl`, `shareurl`, `shorturl`, `releasedate`, `position`, `waveform`) **were not confirmed** in the reference text we could read. Verify with the first real response.

### 6.4 Licensing and download terms

- **Content licence.** API ToU §3.1: "Each Content available through the API is published on the JAMENDO Platform under a Creative Commons license." Every licence used requires attribution; NC variants forbid commercial use and ND variants forbid derivatives. Show the track's CC licence, for example via `include=licenses` or the licence URL field.
- **Downloads in app: allowed only when `audiodownload_allowed == true`, but the documents conflict.**
  - The tracks reference (Feb 2021 note) says: "'audiodownload_allowed' … [is] a boolean to know if you can propose or not the possibility to download the track through your application. Indeed, now Jamendo artists can choose if they want to allow or not the download of their tracks."
  - The ToU (2013) §3.3 says: "Applications must not be specifically designed to cache the content nor offering an offline access to the content. Caching system may only be used to the extent reasonably necessary for the operation of the Application."
  - Engineering reading: a **user-initiated "Download" of a track whose `audiodownload_allowed` is true** is sanctioned by the newer reference, and the CC licence permits copying. Do **not** build an automatic offline cache or sync. The two documents are not reconciled; ask api@jamendo.com if downloads are a headline feature.
- **Commercial use.** §3.3: "The API may be used freely for non-commercial uses. For any other type of use including but not limited to commercial uses please contact … licensing@jamendo.com". Commercial means any "commercial advantage or any monetary compensation, including any revenue arising from affiliation programs or advertising".
- **Attribution.** §4.1: "the Application credits the JAMENDO Members as the creators of the Content, credits JAMENDO as the provider of the Content and provide a direct backlink from each Content in the Application to the relevant Content's page on the JAMENDO Platform." Do not use "Jamendo" in the app name or branding (§4.2).
- **Other.** Do not replicate "the overall experience of JAMENDO services". Reflect content changes promptly. A privacy policy is required.

---
