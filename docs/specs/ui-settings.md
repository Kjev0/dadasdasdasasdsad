# Spec: Settings, connected services, import & review, onboarding
(`lib/ui/pages/settings/**`, `lib/ui/pages/import/**`, `lib/ui/pages/onboarding/**`, `lib/l10n/fragments/settings_*.arb`, `lib/l10n/fragments/import_*.arb`, `lib/l10n/fragments/onboarding_*.arb`, `test/ui/settings/**`)

Built on the ui-foundation module (read `lib/ui/design/README.md`; reuse its
components; fake kit in `test/ui/fakes/`). Replace the
`// STUB(ui-settings)` files (keep class names/constructors). Every setting
must persist (via `SettingsStore`) and actually drive behavior (the services
read the same store) — never show a toggle that does nothing on the current
platform: hide or disable it with an explanation.

## Settings (`SettingsPage({String? section})`)
Desktop: two-pane (section list + content); mobile: list → section page.
Search box filtering settings. Each section has "Restore defaults" for that
section; a global "Restore all defaults" (confirm). Clear descriptions for
advanced options. Sections (map to `AppSettings` groups):
1. **Appearance & Theme**: theme mode, accent (swatches), density, artwork
   backdrop, high contrast (also in Accessibility).
2. **Liquid Glass**: toggle (default OFF), intensity slider, **live preview**
   (`GlassPreview` from ui-foundation), note when blur is disabled by the
   active performance mode ("Glass will use a lighter translucent style").
3. **Playback**: crossfade (0–12 s; disables gapless note), gapless, volume
   normalization + mode (loudness only on desktop), preamp, speed default,
   restore queue on startup, autoplay on startup, smart queue, skip
   unplayable, previous-restart threshold, sleep-timer fade, lyrics on/off.
4. **Audio quality**: streaming / mobile streaming / download quality
   (explain that providers decide what is actually available), output device
   (desktop: list from `PlaybackController.outputDevices()`).
5. **Downloads**: directory (picker; `changeDownloadDirectory` with
   progress), Wi-Fi only, warn on mobile data, max concurrent, verify
   integrity, notify when complete; explanation of the four offline
   categories.
6. **Storage & cache**: usage breakdown (`storageUsage()`), download limit
   (0 = unlimited), artwork cache size, auto cleanup, "Clean up now",
   "Clear artwork cache", "Verify downloads".
7. **Performance**: mode cards (Balanced, Performance, Battery saver, Data
   saver, Visual quality, Custom) with the concrete effects list from
   `PerformanceProfiles.effectsOf()` ("Animations: reduced · Blur: off …");
   granular controls (animations, blur, artwork quality, preload next,
   prefetch artwork, background sync + interval) which switch the mode to
   Custom (`SettingsStore.updatePerformance`); an "Active now" summary. Wording
   must not promise measured gains ("reduces …", not "x% faster").
8. **Battery saver / Data saver**: shortcuts into the same performance
   presets with platform-specific notes (Android battery optimization).
9. **Connected services**: one card per source from `SourceRegistry.all`:
   status (`SourceAuthState`), account name, granted scopes, capabilities
   (what Fermata can/can't do), `limitationsNote`, terms link, Connect /
   Disconnect (OAuth via `MusicSource.connect()`; show progress + cancel),
   "Developer credentials" editor when `credentialStatus.configured == false`
   or user wants to override (fields from `missing`; stored via
   `CredentialsStore.setUserCredentials`; shows origin; link to
   `helpUrl`; shows the exact redirect URIs from `OAuthClient.redirectUriFor`
   to register). Provider order (drag to reorder `services.providerOrder`),
   enable/disable a source, "prefer SoundCloud in discovery". Token storage
   notice when `TokenStore.isPersistent == false` (Linux without keyring).
   Never ask for passwords.
10. **Playlist import & matching**: review mode, auto-accept threshold,
    skip unavailable, preferred provider, allow preview-only matches;
    "Import a playlist" button.
11. **Notifications**: track change (desktop), downloads; Android
    notification permission status + request.
12. **Background playback**: Android: stop foreground service on pause
    (applies after restart — say so), resume on headset connect, battery
    optimization status + "Allow background activity" (opt-in, via
    `AndroidSystemHelper`), OEM note; desktop: explanation that closing the
    window keeps music playing.
13. **System tray & window** (desktop): close behavior (minimize to tray /
    ask / exit), show tray icon, tray availability notice (e.g. GNOME
    without AppIndicator), remember window size.
14. **Startup**: launch at login (`StartupManager`), start minimized.
15. **Keyboard shortcuts**: list of actions with bindings, record-a-new-
    binding capture field, conflicts highlighted, reset; global hotkeys
    toggle + registration errors from `GlobalHotkeyService.registrationErrors`.
16. **Privacy**: record history, personalized recommendations, save search
    history, "No analytics or tracking" statement with the documented
    network behavior (link to docs/NETWORK.md content shown in-app),
    delete history, clear search history, **delete all data** (confirm with
    typed word), export/import settings, backup/restore library
    (`LibraryMaintenance.exportBackup/importBackup` → file picker).
17. **Language**: System / English / Dansk.
18. **Accessibility**: motion (system/reduce/full), high contrast, text
    scale slider with preview, larger touch targets.
19. **Updates**: current version (`package_info_plus`), opt-in update check,
    manual "Check now" (UpdateChecker from lib/discovery if present —
    otherwise show install/update instructions), release notes link.
20. **About & diagnostics**: logo, version/build, platform, licenses
    (`showLicensePage`), attributions (SoundCloud, Deezer, Audius, LRCLIB,
    Jamendo per their terms — text only), log file path, "Export
    diagnostics" (writes recent logs + non-secret environment summary to a
    file the user picks), credits.

## Playlist import (`ImportPage`, `ImportReviewPage`)
Wizard: choose source (only those with `playlistImport`/`userLibrary`,
showing connect prompts), pick one of the user's playlists / liked tracks /
paste a URL / pick an M3U file; choose target sources (ordered, default
SoundCloud first), review mode, threshold, skip unavailable, preferred
provider → start (`PlaylistImportService.start/startWithTracks`) → live
progress (fetching/matching counts, cancel). Review screen: summary chips
(auto-accepted, needs review, not found, skipped); list of rows showing
original track vs matched track, source, confidence (badge + %), duration
difference (± s), version differences as chips (Remix, Live, Acoustic,
Extended, Explicit mismatch…), availability; actions: accept, reject, skip,
choose another candidate, manual search (query field → `searchAlternatives`),
"accept all high-confidence", filter by decision; never auto-select a
candidate with a significant version difference. Save → creates playlist →
navigate to it; report of missing tracks (copyable).

## Onboarding (`OnboardingPage`)
3–4 calm screens: welcome (logo, value prop), add music (pick folders —
desktop default Music folder suggestion; Android requests audio permission
with rationale), connect services (optional; SoundCloud highlighted; can
skip), background playback & notifications (Android notification
permission rationale; desktop tray explanation), finish → sets
`onboardingCompleted` → `/home`. Skippable; accessible; localized.

## Tests (`test/ui/settings/`)
Each section renders; toggles persist to the store (and survive a store
reload with a temp file); Liquid Glass default off + preview reacts;
performance mode selection applies presets and a granular change flips to
Custom; restore defaults per section; connected-services card states
(credentials missing / not connected / connected / expired / error) with a
fake source; credentials editor saves; import wizard flow with fakes;
review actions update decisions; onboarding completes and redirects.

## Compliance addendum (binding — see docs/COMPLIANCE.md)
* SoundCloud playback is siloed: when the user adds a track that cannot join
  the current queue (`canEnqueue` false / `UnsupportedSourceOperation` with
  operation `mix_queue`), show a dialog: "SoundCloud tracks play in their own
  queue (SoundCloud's terms). Start a new queue?" — never silently mix.
* Never show a download action for SoundCloud, Deezer, Spotify or YouTube
  tracks; Audius/Jamendo downloads are per-track, user-initiated. Auto-download
  toggles explain that only user-owned/permitted sources are downloaded
  automatically (currently none of the streaming providers).
* Provider attribution: SoundCloud tracks link to the track and uploader;
  Deezer previews labeled "30-second preview · Deezer".
