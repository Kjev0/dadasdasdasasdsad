# Rules for every module agent

You are a senior engineer implementing one module of **Fermata**, a premium
cross-platform music player (Flutter 3.47.8 / Dart 3.13.7; targets Android,
Linux, Windows). Repository: `/home/user/dadasdasdasasdsad`.

## Environment
* Run `source /opt/sdk/env.sh` before any `flutter`/`dart` command.
* Linux desktop deps (libmpv, GTK, appindicator, libsecret, keybinder, dbus,
  xvfb, playerctl, ffmpeg) are installed. Android SDK at /opt/android-sdk.
  Windows cannot be built here (no MSVC) — Windows code must be written
  carefully against the package sources in `~/.pub-cache/hosted/pub.dev/`.
* Outbound HTTPS works. github.com/codeload are blocked; pub.dev, Google,
  Deezer, Audius, LRCLIB, SoundCloud websites are reachable.
* Read package APIs from the pub cache (`~/.pub-cache/hosted/pub.dev/<pkg>-<ver>/`)
  instead of guessing. Exact versions are in `pubspec.lock`.

## Read first
`docs/ARCHITECTURE.md`, everything under `lib/core/` (frozen contracts),
`lib/settings/`, `lib/app/providers.dart`, `lib/app/services.dart`, and your
module spec in `docs/specs/`. If `docs/research/API_NOTES.md` exists it holds
verified 2026 API facts — prefer it over memory, and verify anything critical
against official docs (WebSearch/WebFetch are available).

## Ownership — other agents work in the same tree at the same time
* Edit ONLY the paths your spec says you own (plus new files inside them).
* `lib/core/**`, `lib/settings/**`, `lib/app/**` are frozen. If a contract is
  insufficient, solve it inside your module and report the gap.
* Never hand-edit `pubspec.yaml`. If you truly need a package, run
  `flutter pub add <pkg>` (it is atomic) and list it in your report.
* Do not touch `android/`, `windows/`, `linux/`, `assets/`, `branding/`,
  `packaging/` unless your spec says so.
* Do NOT commit or push. The lead integrates and commits.
* If the analyzer shows errors in files you don't own (another agent is mid-
  edit), ignore them; analyze/test only your paths.

## Engineering rules
* Implement real behavior. No placeholder buttons, fake API responses or
  fabricated "success" in app code. Tests may use fakes/mocks freely
  (`package:http/testing.dart` MockClient, in-test fake classes, mocktail).
* Network only through `FermataHttp` (lib/core/net/http_client.dart).
* Errors: throw the typed exceptions in `lib/core/errors.dart`.
* Logging: `final _log = Logger('<module>.<sub>');`. Never log tokens/secrets.
* Cancel obsolete async work with `CancelToken`.
* Keep files focused (< ~500 lines each); split by responsibility.
* Public classes get dartdoc comments; non-obvious logic gets brief comments.
* Services are plain Dart classes with constructor injection (no Riverpod
  inside services). Each module must expose a clear constructor/factory so
  `lib/app/bootstrap.dart` can wire it.
* Platform-specific code must be guarded (`PlatformInfo`/`Platform.isX`) and
  must not crash on other platforms (e.g. MPRIS code never runs on Windows).

## Done means
* `dart analyze <your lib paths> <your test paths>` → **No issues found**.
* `flutter test test/<your module>` → all pass. Write meaningful tests for
  the acceptance criteria in your spec (unit + integration where feasible).
* A short `lib/<module>/README.md` documenting the public API, bootstrap
  wiring (exact constructor calls + init order), platform notes and known
  limitations.

## Final answer (returned to the lead — not shown to the user)
Concise: files created; public API (class names + constructor signatures);
bootstrap wiring snippet; tests run + results; analyzer result; packages
added; contract gaps; anything not done and why.
