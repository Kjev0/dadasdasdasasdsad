# Spec: Credentialed sources — SoundCloud (first-class), Spotify, YouTube, Jamendo
(`lib/sources/soundcloud/**`, `lib/sources/spotify/**`, `lib/sources/youtube/**`, `lib/sources/jamendo/**`, `test/sources/providers/**`, `docs/PROVIDERS.md`)

Build on the base classes from the sources-core module (`lib/sources/base`,
`lib/sources/auth`) — read them first; do not modify them (report gaps).
Read `docs/research/API_NOTES.md` if present and verify critical facts against
the official docs (WebSearch/WebFetch). Never fabricate endpoints: if docs
are ambiguous, implement the documented behavior and note uncertainty in
`docs/PROVIDERS.md`.

Without credentials each source must report `credentialStatus.configured ==
false` (missing fields listed, help URL to the provider's developer portal),
`authState.status == credentialsMissing`, `isReady == false`, and every call
throws `MissingCredentialsException` — the UI explains it. No fake results.

## SoundCloud (`SourceIds.soundcloud`) — first-class
* OAuth 2.1 authorization code + PKCE at `https://secure.soundcloud.com/authorize`
  / `https://secure.soundcloud.com/oauth/token` (client secret required for the
  token exchange per current docs — verify), header `Authorization: OAuth <token>`.
  Also `client_credentials` for public browsing when a secret is configured
  but the user has not connected (optional; cache the app token).
* Search tracks/users/playlists with `linked_partitioning=true` (cursor =
  `next_href`), `/me`, `/me/likes/tracks`, `/me/playlists`, playlist with
  tracks, `/resolve?url=` for share URLs (soundcloud.com/... and
  on.soundcloud.com short links), user tracks, `/tracks/{id}/related`,
  `/tracks/{id}/streams` (choose `http_mp3_128_url` or HLS AAC/Opus by quality
  — media_kit and ExoPlayer both play HLS; check what exists), handle URNs
  (`soundcloud:tracks:123`) per current docs.
* Availability: `access` playable/preview/blocked, `streamable`, `policy`
  (e.g. SNIP/BLOCK/MONETIZE), deleted (404) / private (403) /
  region-restricted (`blocked`), `downloadable` + `download_url` →
  `OfflineRights.downloadable` and `authorizeDownload` via the download
  endpoint (only when downloadable and authorized). Everything else stream-only.
  Respect API terms: no caching of stream audio; attribution via
  `permalink` (track) and the uploader's permalink.
* Rate limits: honour 429 + documented play limits; surface `RateLimitedException`.
* Recommendations helpers: related tracks, user tracks, trending — if the
  API has no trending endpoint, implement `trending` via a documented
  search/sort or omit the capability.

## Spotify (`SourceIds.spotify`) — import + metadata, no audio
* PKCE without secret, loopback `http://127.0.0.1:43821/callback/spotify`
  (Spotify forbids `localhost`), custom scheme on Android. Scopes:
  `playlist-read-private playlist-read-collaborative user-library-read`.
* `userPlaylists`, `getPlaylist` (by id or `open.spotify.com/playlist/...`
  URL; use the CURRENT playlist items endpoint — verify whether
  `/playlists/{id}/tracks` was replaced), `userLikedTracks`, search (for
  matching targets), `lookupByIsrc` via `search?q=isrc:XXX&type=track`.
  Map `external_ids.isrc`, explicit, album, duration, artists.
* Playback: `PlaybackRights.externalOnly` (`externalPlaybackUri` =
  `https://open.spotify.com/track/<id>`), never streamable or downloadable.
  `limitationsNote` explains that Spotify does not permit third-party
  playback; tracks are matched to other sources instead.

## YouTube / YouTube Music (`SourceIds.youtube`)
* There is no official YouTube Music API. Use YouTube Data API v3: OAuth
  (Google, scope `https://www.googleapis.com/auth/youtube.readonly`,
  loopback redirect on all platforms if Google rejects custom schemes for
  this client type — verify) and/or API key for search.
* `userPlaylists` (`playlists?mine=true`), `getPlaylist`
  (`playlistItems`, by id or youtube.com / music.youtube.com URL), search
  (`type=video&videoCategoryId=10`), `getTrack` via `videos`.
  Parse "Artist - Title (Official Video)" style titles and channel names
  ("Artist - Topic", "ArtistVEVO") into clean metadata for matching. Duration
  from `contentDetails.duration` (ISO 8601).
* Playback: `externalOnly` (`https://music.youtube.com/watch?v=<id>`). No
  audio extraction (ToS). Note quota costs in `docs/PROVIDERS.md`.

## Jamendo (`SourceIds.jamendo`) — CC-licensed, legal downloads
* `client_id` required (free registration). API v3 `https://api.jamendo.com/v3.0/`.
  Search tracks/artists/albums/playlists, track, album tracks, artist
  tracks, popular (trending) by tag/genre. Stream via the track `audio`
  field (format mp32/mp31/ogg/flac by quality where offered). Download only
  when `audiodownload_allowed` is true via `audiodownload`. Store license
  (`license_ccurl`) in `extra` and show attribution.

## Tests (`test/sources/providers/`)
MockClient fixtures (hand-written from the official docs' documented
response shapes; mark them as such in a header comment), covering mapping,
pagination cursors, availability/offline mapping (playable/preview/blocked,
downloadable), share-URL parsing, ISRC lookup, missing-credentials behavior
(no network calls made), 401 → refresh → retry via the base mixin, 429.

## Docs
`docs/PROVIDERS.md`: for each provider — what works, what does not and why
(terms), credentials needed, how to register an app (URL), exact redirect
URIs, scopes, rate limits/quotas, attribution requirements.
