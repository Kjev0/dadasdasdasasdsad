# Fermata — Architecture

Fermata is a premium, local-first music player for **Android, Linux and Windows**
built from one Flutter/Dart codebase with platform-specific native integrations
where they matter (background audio, media sessions, tray).

## Technology decisions

| Concern | Choice | Why |
|---|---|---|
| UI / shared code | Flutter 3.47 (Dart 3.13) | One codebase for 3 targets, native AOT performance, first-class desktop. |
| State / DI | Riverpod 3 (no codegen) | Services are plain Dart objects created in a composition root and injected via provider overrides. |
| Audio — Android | just_audio (ExoPlayer/Media3) | Battle-tested with audio_service; gapless; audio focus via audio_session. |
| Audio — desktop | media_kit (libmpv) | Robust decoding of every format, gapless, output-device selection, ReplayGain + EBU R128 loudnorm filters. |
| Android background | audio_service foreground `mediaPlayback` service + MediaSession | Persistent media notification, lock screen, Bluetooth/headset buttons. |
| Linux media keys | Own MPRIS server via `dbus` | Full control, testable with `playerctl`/`dbus-send`. |
| Windows media keys | `smtc_windows` (System Media Transport Controls) | Media overlay + hardware media keys. |
| Tray / window | tray_manager + window_manager | Close-to-tray, tray menu with now-playing. |
| Database | SQLite via sqflite (Android) / sqflite_common_ffi (desktop) | Same async API everywhere, migrations. |
| Secrets | flutter_secure_storage (Keystore / Windows Credential storage / libsecret) | Tokens never in plain files. |
| OAuth | Own PKCE client: loopback redirect on desktop (RFC 8252), custom-scheme deep link (`fermata://oauth/<source>`) via app_links on Android | No embedded webviews; user signs in on the provider's own page. |
| Localization | gen-l10n, English + Danish, ARB fragments merged by `tool/merge_arb.dart` | Parallel-friendly. |

## Module map (`lib/`)

```
lib/
  main.dart                 entry point → app/bootstrap.dart
  app/                      composition root, router, app widget, Riverpod providers
    services.dart           AppServices container (all long-lived services)
    providers.dart          Riverpod providers (overridden from AppServices) + derived state
    bootstrap.dart          creates services in dependency order
  core/                     FROZEN shared contracts (models, interfaces, errors, net, logging, paths)
    models/                 Track, Playlist, Queue/Playback, Library, Download, Matching, Auth
    contracts/              MusicSource (plugin API), PlaybackController, StreamResolver,
                            repositories, DownloadManager, matching, auth, discovery, platform
    net/http_client.dart    FermataHttp: timeouts, retries, 429 Retry-After, cancellation
    logging/logging.dart    structured JSON-lines log file + console
    platform/               AppPaths, PlatformInfo
  settings/                 AppSettings (grouped), SettingsStore (atomic JSON), performance profiles
  playback/                 engine (queue, shuffle, repeat, crossfade, gapless, normalization,
                            sleep timer, persistence), audio backends (just_audio / media_kit),
                            stream resolver
  platform/
    android/                audio_service handler adapter, permissions, battery helper
    desktop/                window/close-to-tray, tray menu, hotkeys, startup-on-login, single instance
    linux/                  MPRIS server
    windows/                SMTC adapter
  library/                  SQLite schema + migrations, repositories, local scanner, folder
                            watcher, tag reading/writing, smart playlists, M3U, backup
  sources/                  provider plugins: soundcloud, audius, deezer, spotify, youtube,
                            jamendo, local; auth (OAuth PKCE, token store, credentials)
  matching/                 normalizer, version detector, scorer, matcher, playlist import
  downloads/                download queue, resumable transfers, integrity, storage limits
  discovery/                recommendations, mixes, lyrics (LRCLIB)
  ui/                       design system, shell, pages, widgets
  l10n/                     fragments/ (edited) → arb/ (merged) → gen/ (generated)
```

### Dependency rule

`core` depends on nothing in the app. Feature modules depend on `core` and
`settings` only, never on each other's internals, and never on `ui`.
`app/bootstrap.dart` is the only place that wires concrete classes together.
The UI talks to services exclusively through `app/providers.dart`.

### Contracts are frozen

`lib/core/**` is shared by every module. Changing a contract requires
updating all implementations; prefer adding a new method with a sensible
default in an implementation-side base class.

## Runtime flow

1. `main()` → `bootstrap()`:
   logging → paths → settings → HTTP → database & repositories → credentials &
   tokens → sources registry → download manager → stream resolver → playback
   controller (restores queue) → matching/import → discovery → platform
   integrations (Android media session / MPRIS / SMTC / tray / hotkeys) →
   `runApp(ProviderScope(overrides: serviceOverrides(services)))`.
2. The `PlaybackController` lives for the whole process; pages only observe it.
   Closing the desktop window hides it (tray) — the Flutter engine and audio keep
   running. On Android the engine is shared with the foreground service
   (`AudioServiceActivity`), so leaving the activity keeps audio alive.
3. Explicit **Quit** (tray menu / app menu) → `AppLifecycleController.quit()`:
   stop playback, persist queue/settings, dispose services, exit.

## Playback resolution

`StreamResolver.resolve(track)`:
1. a completed, integrity-verified download of the track,
2. a user-owned local file,
3. the source's authorized stream (`MusicSource.resolveStream`), respecting
   `TrackAvailability`,
4. a linked match on another source (from playlist migration), in provider
   preference order — e.g. an imported Spotify track plays its confirmed
   SoundCloud match.

Otherwise `UnplayableTrackException(reason)`; the engine skips to the next
playable item (setting) and the UI shows the localized reason.

## Offline categories

Provider terms are encoded in `lib/core/sources/source_policies.dart` and
explained in `docs/COMPLIANCE.md` (e.g. SoundCloud streams play in their own
queue "silo" and are never downloadable).

Every track maps to exactly one of: **user-owned file**, **downloadable**
(source explicitly authorizes it), **stream-only**, **unavailable offline**
(`OfflineRights`). Stream URLs are never persisted as downloads; DRM and
subscription restrictions are never bypassed.

## Rules for contributors (and for agents)

* No fabricated API data, credentials, or "success" states. Missing developer
  credentials → `MissingCredentialsException` → explained in the UI.
* All network calls go through `FermataHttp`.
* Logging: `final _log = Logger('area.sub');` — never log tokens.
* Strings: add to `lib/l10n/fragments/<area>_en.arb` **and** `<area>_da.arb`,
  then `dart run tool/merge_arb.dart && flutter gen-l10n`. Import with
  `import 'package:fermata/l10n/gen/app_localizations.dart';`.
* Tests live in `test/<module>/`; fakes are fine in tests, never in app code.
* Build environment: `source /opt/sdk/env.sh` (dev container only).
