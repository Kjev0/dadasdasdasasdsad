# Settings, connected services, playlist import & review, onboarding

UI module `ui-settings`: `lib/ui/pages/settings/**`, `lib/ui/pages/import/**`,
`lib/ui/pages/onboarding/**`, strings in `lib/l10n/fragments/settings_*`,
`import_*`, `onboarding_*` (prefixes `settings*` / `setting*`, `import*`,
`onboarding*`). Built on ui-foundation (`lib/ui/design/README.md`). Services
are only used through `lib/app/providers.dart`; every setting is written to
`SettingsStore`, which the services read.

## Pages (routes are defined in `lib/app/router.dart`)

| Class | Constructor | Route |
|---|---|---|
| `SettingsPage` | `const SettingsPage({Key? key, String? section})` | `/settings`, `/settings/<SettingsSections id>` |
| `ImportPage` | `const ImportPage({Key? key})` | `/import` (wizard) |
| `ImportReviewPage` | `const ImportReviewPage({Key? key, required String sessionId})` | `/import/<sessionId>` (progress → review → result) |
| `OnboardingPage` | `const OnboardingPage({Key? key})` | `/onboarding` |

* **Settings layout**: content width ≥ 760 → section list + section side by
  side (selection is local state; `/settings/<id>` deep-links); narrower →
  list at `/settings`, one section per route with a back button. Search
  filters section titles and the labels of the settings inside them
  (case/accent-insensitive). Each section has "Restore defaults"
  (confirmed); the list footer has "Restore all defaults" (confirmed; keeps
  onboarding state, download folder, volume, output device; re-applies
  login entry, global hotkeys and speed).
* **Sections** (`settings_catalog.dart`, ids from `SettingsSections`):
  appearance, glass (live `GlassPreview`, default off, blur-off note),
  playback, audioQuality (output devices from `PlaybackController`),
  downloads (folder move via `changeDownloadDirectory`, offline categories),
  storage (`storageUsage`, clean-up, artwork cache, verify), performance
  (mode cards with `PerformanceProfiles.effectsOf`, granular controls via
  `SettingsStore.updatePerformance` → Custom, "Active now"), savers,
  services (one `SourceCard` per `SourceRegistry.all`, credentials editor,
  provider order/enable, token-storage notice), import, notifications,
  background, desktop (tray/window), startup (`StartupManager`), shortcuts
  (recorder, conflicts, global hotkeys + `registrationErrors`), privacy
  (network statement, delete/export/import/backup/restore), language,
  accessibility, updates, about (licenses, attributions, log path, export
  diagnostics). Desktop-only: desktop, startup, shortcuts (hidden on
  Android; a deep link shows "not available on this device").
* Controls that do nothing on the current platform are hidden or disabled
  with the reason (e.g. loudness normalization only on desktop, interruption
  settings only on Android, notification toggles when the notifier is
  unsupported, launch at login when unsupported, global hotkeys on Wayland).
* **Import wizard**: source (sources with `playlistImport`/`userLibrary`,
  connect prompt, "set up" link when credentials are missing; plus M3U via
  `LocalLibraryService.importM3u`) → your playlists / liked tracks (all pages,
  cancelable, max 10 000) / pasted link → targets (usable sources in provider
  order, SoundCloud first by default; external-only and origin excluded;
  previews only when allowed; reorder/uncheck) + review mode, threshold,
  skip unavailable, preferred provider → `start` / `startWithTracks` →
  `/import/<id>`.
* **Review**: live progress (fetching/matching counts, cancel), summary chips
  that filter by decision, original vs match, source, confidence badge + %,
  duration delta, version-difference chips, availability, provider links
  (track + uploader, for attribution); accept / reject / skip / other
  candidates / manual search (`searchAlternatives`, cancelable) / "accept
  all high-confidence" (`acceptAllAtLeast(high)`). A candidate with a
  significant version difference is never proposed automatically — the user
  must pick it explicitly. Save → name → copyable missing-tracks report →
  navigates to the new playlist.
* **Onboarding**: welcome → music folders (suggested `XDG_MUSIC_DIR`/`~/Music`
  or `%USERPROFILE%\Music`; Android asks for the audio permission with a
  rationale first; folders are added and scanned) → connect services
  (optional, SoundCloud first and highlighted) → background playback
  (Android notification permission with rationale; desktop tray explanation
  + close behaviour) → sets `onboardingCompleted` → `/home`. Skippable.

## Public helpers / providers

| Symbol | File | Notes |
|---|---|---|
| `SettingsHooks({checkForUpdates, releasesPage, trayUnavailableReason, hotkeysUnsupportedReason, androidRestartRequired, cancelPendingSignIn})`, `settingsHooksProvider` | `settings_hooks.dart` | Optional capabilities outside the frozen contracts; default: none |
| `UpdateInfo({required status, required currentVersion, latestVersion, releaseNotesUrl})`, `UpdateInfoStatus` | `settings_hooks.dart` | UI-side mirror of the discovery module's `UpdateCheckResult` |
| `FileDialogs` / `PlatformFileDialogs()` / `PickedFile`, `fileDialogsProvider` | `settings_hooks.dart` | `file_picker` wrapper (pick folder/file, save bytes) — override in tests |
| `appVersionProvider` (`AppVersion`) | `settings_hooks.dart` | `package_info_plus` |
| `desktopEnvironmentProvider` | `settings_hooks.dart` | `Platform.environment` (GNOME/Wayland notes) |
| `suggestedMusicFolder(platform, env)`, `suggestedMusicFolderProvider` | `onboarding/music_folders.dart` | |
| `restoreAllSettings(WidgetRef)` | `settings_page.dart` | |
| `DataTransfer` | `data_transfer.dart` | settings JSON export/import, library backup encode/decode |
| `buildDiagnosticsReport(...)` | `diagnostics.dart` | never includes tokens, credentials or account names |
| `completeOnboarding(context, ref)` | `onboarding/onboarding_page.dart` | |
| `importSessionProvider(id)` | `import/import_review_page.dart` | |

## Bootstrap wiring

No service is created by this module. Optional hooks (everything works
without them; the UI then hides automatic update checks and uses generic
tray/hotkey notes):

```dart
// lib/app/bootstrap.dart
import '../discovery/discovery.dart';                         // UpdateChecker
import '../platform/desktop/hotkeys/global_hotkey_service.dart';
import '../platform/desktop/lifecycle_controller.dart';
import '../ui/pages/settings/settings_hooks.dart';

// after DesktopIntegration.start(...) (and AndroidMediaSession.start):
final updates = UpdateChecker(http, settings, paths, platform: platform);
unawaited(updates.checkIfDue().catchError((Object _) => null)); // opt-in, at most daily
final settingsHooks = SettingsHooks(
  checkForUpdates: () async {
    final r = await updates.checkNow();
    return UpdateInfo(
      status: switch (r.status) {
        UpdateStatus.upToDate => UpdateInfoStatus.upToDate,
        UpdateStatus.updateAvailable => UpdateInfoStatus.updateAvailable,
        UpdateStatus.noReleases => UpdateInfoStatus.noReleases,
      },
      currentVersion: r.currentVersion,
      latestVersion: r.latestVersion,
      releaseNotesUrl: r.releaseNotesUrl,
    );
  },
  trayUnavailableReason: () {
    final l = desktop.lifecycle;
    return l is DesktopLifecycleController ? l.trayUnavailableReason : null;
  },
  hotkeysUnsupportedReason: () {
    final h = desktop.hotkeys;
    return h is GlobalHotkeyServiceImpl ? h.unsupportedReason : null;
  },
  androidRestartRequired: () => androidSession?.restartRequiredForSettings ?? false,
  cancelPendingSignIn: oauth.cancelPending, // OAuthClientImpl
);
return Bootstrapped(services, artworkCache, settingsHooks); // add the field

// lib/main.dart
runApp(ProviderScope(
  overrides: [
    ...serviceOverrides(boot.services),
    settingsHooksProvider.overrideWithValue(boot.settingsHooks),
  ],
  child: const FermataApp(),
));
```

## Platform notes

* Desktop: file dialogs via `file_picker` (GTK portal on Linux). Android:
  `getDirectoryPath` may return a folder the app cannot write to under
  scoped storage; `changeDownloadDirectory` then fails and the old folder is
  kept (explained in a toast).
* Battery optimization and notification permission are only requested
  after an explicit tap (opt-in), through `AndroidSystemHelper`.
* "Stop service when paused" applies after a restart (said in the UI; with
  the `androidRestartRequired` hook a banner appears).

## Known limitations

* OAuth connect has no cancel in the `MusicSource` contract; "Cancel" calls
  the `cancelPendingSignIn` hook (or only stops waiting without it).
* Redirect URIs are computed with `OAuthClient.redirectUriFor` for the
  default loopback port (43821) and the Android deep link; `MusicSource`
  does not expose its own `OAuthConfig`.
* Import sessions live in memory (matching module); `/import/<id>` after a
  restart shows "no longer available".
* The update section shows manual update instructions unless the
  `checkForUpdates` hook is wired.

## Tests

`test/ui/settings/` (fake kit from `test/ui/fakes/`):
`flutter test test/ui/settings` — every section on Linux and Android,
persistence through a real settings file, restore defaults per section and
globally, Liquid Glass + preview, performance presets/Custom, services card
states + credentials editor + connect/cancel/disconnect + provider order,
shortcuts recorder/conflicts/global hotkeys, privacy data controls, updates
and diagnostics, import wizard (link, playlist, liked tracks, M3U) and review
actions, onboarding (skip, full flow, Android permissions, Danish).
