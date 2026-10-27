# Developer credentials

Some providers only answer apps that are registered with them. Fermata never
ships anybody's credentials in the repository and never fabricates results
when they are missing: such a source reports `credentialStatus.configured ==
false`, its state is `credentialsMissing`, every call throws
`MissingCredentialsException`, and *Connected services* explains what to
configure and links to the provider's developer portal.

Credentials are **developer** credentials (client id / client secret / API
key) — never user passwords. User accounts are connected with OAuth in the
provider's own sign-in page (see `docs/PLUGINS.md` → Auth).

Implementation: `CredentialsStoreImpl` (`lib/sources/auth/credentials_store_impl.dart`).

## Where credentials come from (precedence)

For each source the **first** origin that has a client id or an API key wins
(the record is used as a whole; fields are not mixed across origins):

| # | Origin | Where | Shown as |
|---|---|---|---|
| 1 | Entered in the app | *Settings → Connected services → Developer credentials*; stored in the OS secure storage under `fermata.credentials.<sourceId>` | `userEntered` |
| 2 | Config file | `<appSupport>/credentials.json` | `configFile` |
| 3 | Build time | `--dart-define` / `--dart-define-from-file` | `buildTime` |

A record that only has a `clientSecret` is ignored (it cannot be used on its
own). Removing user-entered credentials falls back to the next origin.

### Secure storage

User-entered credentials and OAuth tokens use `flutter_secure_storage`:
Android Keystore-backed encrypted storage, Windows Credential Manager (DPAPI),
Linux Secret Service (GNOME Keyring, KWallet via libsecret).

On Linux without a running Secret Service / unlocked keyring (headless or
minimal desktops) Fermata detects this at startup with a write/read probe
(≤ 4 s) and keeps tokens and user-entered credentials **in memory only** for
that session (`TokenStore.isPersistent == false`). It never falls back to
plain files; the UI explains that you need to reconnect after a restart.
Installing and unlocking `gnome-keyring` (or another Secret Service provider)
fixes it.

## `credentials.json`

Location (`AppPaths.credentialsFile`):

| Platform | Path |
|---|---|
| Linux | `~/.local/share/app.fermata.player/credentials.json` |
| Windows | `%APPDATA%\Fermata\Fermata\credentials.json` |
| Android | app-private storage — use in-app entry instead |

Format (camelCase keys; snake_case such as `client_id` is accepted too):

```json
{
  "soundcloud": { "clientId": "…", "clientSecret": "…" },
  "spotify":    { "clientId": "…" },
  "youtube":    { "clientId": "….apps.googleusercontent.com", "clientSecret": "…", "apiKey": "…" },
  "jamendo":    { "clientId": "…" },
  "audius":     { "apiKey": "…" }
}
```

Optional per source: `"redirectUri": "…"` overrides the default redirect URI
(it must match what you registered exactly). The file is read at startup;
invalid JSON is ignored with a warning in the log. It is listed in
`.gitignore` — keep it out of version control.

## Build-time values (`--dart-define`)

Create `dart_defines.json` in the project root (ignored by git via
`dart_defines*.json`):

```json
{
  "FERMATA_SOUNDCLOUD_CLIENT_ID": "…",
  "FERMATA_SOUNDCLOUD_CLIENT_SECRET": "…",
  "FERMATA_SPOTIFY_CLIENT_ID": "…",
  "FERMATA_YOUTUBE_CLIENT_ID": "…",
  "FERMATA_YOUTUBE_CLIENT_SECRET": "…",
  "FERMATA_YOUTUBE_API_KEY": "…",
  "FERMATA_JAMENDO_CLIENT_ID": "…",
  "FERMATA_AUDIUS_API_KEY": "…"
}
```

```sh
flutter run   --dart-define-from-file=dart_defines.json
flutter build linux   --release --dart-define-from-file=dart_defines.json
flutter build windows --release --dart-define-from-file=dart_defines.json
flutter build apk     --release --dart-define-from-file=dart_defines.json
```

Single values work too: `--dart-define=FERMATA_JAMENDO_CLIENT_ID=abc`.
Empty values count as "not set".

> **Warning:** values compiled into a binary can be extracted from it. Only
> embed credentials in builds you do not distribute publicly, and never embed
> a client **secret** in a public release (SoundCloud's secret in particular —
> see below). Public builds should leave credentials to the user (in-app entry
> or `credentials.json`).

## Redirect URIs to register

Fermata signs in with the OAuth 2 authorization-code flow + PKCE (RFC 7636)
following RFC 8252 for native apps:

| Platform | Redirect URI | How it is received |
|---|---|---|
| Linux, Windows | `http://127.0.0.1:43821/callback/<sourceId>` | one-shot HTTP server on the IPv4 loopback, system browser |
| Android | `fermata://oauth/<sourceId>` | deep link (`app_links`) from a Custom Tab |

`<sourceId>` is `soundcloud`, `spotify`, `youtube`, … (see
`lib/core/sources/source_ids.dart`). Register **both** URIs when the
provider and your app type allow it. Port 43821 is fixed because most
providers require an exact match; if another program uses it, Fermata says
so instead of picking another port. Providers that accept any loopback port
(Spotify, Google "Desktop app" clients) can be configured by the source with
`loopbackPort: 0` (ephemeral port) — then register the URI without a port,
e.g. `http://127.0.0.1/callback/spotify`. Never register `localhost`: Spotify
rejects it and it can resolve to IPv6.

## Registering an app per provider

Facts below were verified on 2026-10-27; see `docs/research/API_NOTES.md`
for sources and `docs/PROVIDERS.md` for what each integration does.

| Provider | Needed | Register at | Notes |
|---|---|---|---|
| SoundCloud | `clientId` + `clientSecret` | https://soundcloud.com/you/apps (or SoundCloud's `sc-api-auth` CLI) | Registration requires a SoundCloud **Artist Pro** subscription; one app per person. The token endpoint requires the client secret, so a secret cannot be shipped in a public binary — bring your own app. Redirect URIs as above. |
| Spotify | `clientId` | https://developer.spotify.com/dashboard | PKCE without secret. Development mode: the app owner needs Premium; at most 5 allow-listed users (add them under *User Management*). Register `http://127.0.0.1:43821/callback/spotify` (no `localhost`) and, for Android, `fermata://oauth/spotify` (custom schemes may be rejected by the dashboard — test early). |
| YouTube | OAuth `clientId` (+ `clientSecret` that Google issues to desktop clients) and/or `apiKey` | https://console.cloud.google.com/apis/credentials — enable *YouTube Data API v3*, create an OAuth client of type **Desktop app** | Desktop clients accept any loopback port; Android sign-in is not supported (Google rejects custom schemes and loopback for Android clients). Search has its own bucket of 100 calls per day per project (since June 2026); other endpoints share 10 000 units/day. |
| Jamendo | `clientId` | https://devportal.jamendo.com/ | Free, non-commercial use. No user sign-in needed. |
| Audius | optional `apiKey` | https://api.audius.co/plans (or audius.co → Settings → Manage your apps) | Works without a key; a key raises rate limits and unlocks tracks restricted to specific API keys. Only the read **API key** is used — never put an API **secret** in Fermata. |
| Deezer | nothing | — | Public API without registration. New app registration for user-library OAuth is currently closed, so Fermata does not offer Deezer sign-in. |

## Checklist when something does not work

* *Connected services* shows **Credentials missing** → none of the three
  origins provides the required fields; the card lists which ones.
* Sign-in fails with *redirect_uri mismatch* → the registered URI differs
  from the one shown in *Connected services* (case, port and trailing slash
  matter).
* **Port 43821 is in use** → close the other program (or the other Fermata
  instance) and try again.
* Tokens are forgotten after restart on Linux → no Secret Service; see
  *Secure storage* above.
