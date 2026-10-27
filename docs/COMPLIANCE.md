# Provider terms → product behaviour

Fermata only does what each provider's current terms allow (verified
2026-10-27; sources and quotes in `docs/research/API_NOTES.md`). These rules
are encoded in `lib/core/sources/source_policies.dart` and enforced in code.

| Provider | In-app playback | Downloads / offline | Other rules |
|---|---|---|---|
| Local files | Full | User-owned (always offline) | — |
| SoundCloud | Full stream (with credentials) — **siloed**: never mixed with other streaming services in one queue | **None** (terms forbid in-app download/offline even for uploader-downloadable tracks); session caching only | App registration currently limited (Artist Pro, 1 app/person); `client_secret` required → users/developers bring their own credentials; `Authorization: OAuth <token>`; design for 1,500 stream requests/day; attribution links to track + uploader |
| Audius | Full stream (licence grants music-player apps streaming) | User-initiated, single tracks the artist made downloadable (official endpoint) | No related-tracks endpoint (related users only); gated tracks → 403 |
| Jamendo | Full stream (client_id) | User-initiated when `audiodownload_allowed`; no app-designed offline caching | Non-commercial tier; `type=single albumtrack` |
| Deezer | 30 s previews only (signed URLs expire ≈ 15 min → re-resolve) | Forbidden | Public API, non-commercial; best ISRC resolver for matching |
| Spotify | External only (open in Spotify) | None | Metadata transfer of the user's playlists to another service is permitted; dev-mode apps: owner needs Premium, 5 allow-listed users; `/playlists/{id}/items` only for owned/collaborative playlists |
| YouTube / YT Music | External only (open in YouTube Music) | None | No YT Music API; Data API search quota 100 calls/day/project; Android OAuth needs Google's AuthorizationClient (not supported → desktop-only import); never embed API credentials in the repo |
| LRCLIB | Lyrics text | Cache 30 days | App-identifying User-Agent; honour Retry-After |

## SoundCloud silo (queue rule)
* A queue whose stream sources include SoundCloud is a **SoundCloud queue**:
  only SoundCloud streams and the user's own local files/downloads play in it.
* Any other queue is an **open queue**: SoundCloud streams (including
  SoundCloud matches linked to imported tracks) are not used in it.
* Adding a SoundCloud track to an open queue (or another service's track to
  a SoundCloud queue) asks the user to start a new queue instead.
* Playlist migration may target SoundCloud; playing such a playlist builds a
  SoundCloud queue from the SoundCloud matches (tracks without a SoundCloud
  match are skipped with a notice), or an open queue from the other
  providers' matches, chosen by provider preference.

Shipping SoundCloud support publicly should be preceded by written
confirmation from SoundCloud that this siloed design is acceptable.

## Automatic downloads
Auto-download playlists only ever download tracks whose source policy has
`automaticDownloads` (currently: none of the remote providers). The UI says
so instead of pretending the feature works for streams.
