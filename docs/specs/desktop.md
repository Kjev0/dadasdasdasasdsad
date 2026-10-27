# Spec: Desktop integration — Windows & Linux (`lib/platform/desktop/**`, `lib/platform/linux/**`, `lib/platform/windows/**`, `test/platform/desktop/**`, `test/platform/linux/**`)

Goal: closing the window must NOT stop music (minimize to tray by default),
tray icon with controls, OS media integration (MPRIS on Linux, SMTC on
Windows), global hotkeys, optional start-on-login, graceful behaviour when no
tray exists.

## Implement
1. **`DesktopLifecycleController implements AppLifecycleController`**
   (window_manager). Constructor gets `PlaybackController`, `SettingsStore`,
   `AppPaths`, `PlatformInfo`, a `Future<void> Function() disposeAll` used by
   `quit()`, and the tray (below).
   * `init()`: `windowManager.ensureInitialized()`, `setPreventClose(true)`,
     title "Fermata", min size 380×600, restore saved bounds from
     `AppPaths.windowStateFile` (validate they are on-screen via
     `screen_retriever` if available as transitive dep — otherwise clamp to
     sane values), honour `desktop.startMinimized` / `--minimized` CLI flag
     (start hidden to tray, or minimized if no tray), save bounds on
     move/resize (debounced).
   * `onWindowClose` → per `desktop.closeBehavior`: minimizeToTray → hide
     (if tray unavailable → minimize so the app stays reachable via
     taskbar/dock + MPRIS Raise); ask → call `closeDecisionDelegate` (if none
     registered, default to minimize) and persist "remember" choice; exit →
     `quit()`.
   * `quit()`: guard re-entrancy; `playback.dispose()` (persists queue),
     `settings.flush()`, destroy tray, unregister hotkeys, stop MPRIS/SMTC,
     `disposeAll()`, `windowManager.setPreventClose(false)` + `destroy()`, then
     `exit(0)` as last resort after a timeout.
2. **Tray** (`tray_manager`): icon `assets/branding/tray_icon.png` on Linux
   (or `tray_icon_mono.png` if dark panel is detectable — default color) and
   `assets/branding/tray_icon.ico` on Windows (the branding agent creates
   them; if missing at runtime log a warning and skip the tray). Tooltip
   "Fermata — Title · Artist". Context menu: current "Title — Artist"
   (disabled label) or "Not playing", separator, Play/Pause (label reflects
   state), Previous, Next, separator, Show Fermata, Quit Fermata. Rebuild the
   menu only when track/playing changes (debounced). Left click (Windows) →
   show window; right click → menu. Menu labels localized via
   `lookupAppLocalizations(locale)` from `package:fermata/l10n/gen/app_localizations.dart`
   — add your strings to `lib/l10n/fragments/desktop_en.arb` and
   `desktop_da.arb` (you own those two files) and run
   `dart run tool/merge_arb.dart && flutter gen-l10n`.
   `desktop.showTrayIcon` toggles the tray live.
3. **Tray availability on Linux**: check the session bus for
   `org.kde.StatusNotifierWatcher` (name has owner) with the `dbus` package.
   GNOME without the AppIndicator extension → `trayAvailable == false` → close
   minimizes instead of hiding; Settings explains why (expose a
   `trayUnavailableReason`).
4. **Single instance**: `SingleInstance.ensure(AppPaths, args)` called before
   `runApp`: bind a loopback TCP server on an ephemeral port, write the port
   to `AppPaths.instanceLockFile`; a second instance connects, sends
   `show` (or `play-pause` etc. for CLI flags `--play-pause --next
   --previous`), and exits(0). Stale lock files must not block startup.
   Expose a `Stream<String> commands` the lifecycle controller listens to.
5. **MPRIS** (`lib/platform/linux/mpris_server.dart`) with the `dbus`
   package: bus name `org.mpris.MediaPlayer2.fermata` (append `.instance<pid>`
   if taken), object `/org/mpris/MediaPlayer2`, interfaces
   `org.mpris.MediaPlayer2` (Identity "Fermata", DesktopEntry
   "app.fermata.player", CanRaise true → show window, CanQuit true → quit,
   CanSetFullscreen false, HasTrackList false, SupportedUriSchemes ["file"],
   SupportedMimeTypes common audio types) and `org.mpris.MediaPlayer2.Player`
   (PlaybackStatus, LoopStatus (None/Track/Playlist ↔ RepeatMode, settable),
   Rate (settable within MinimumRate 0.5 / MaximumRate 2.0), Shuffle
   (settable), Metadata (`mpris:trackid` as a valid object path derived from
   the queue uid, `mpris:length` µs, `xesam:title`, `xesam:artist` (as),
   `xesam:album`, `xesam:albumArtist`, `xesam:url`, `mpris:artUrl`),
   Volume (settable), Position (µs, read on demand, no PropertiesChanged),
   CanGoNext/CanGoPrevious/CanPlay/CanPause/CanSeek/CanControl; methods
   Next, Previous, Pause, PlayPause, Stop, Play, Seek(x µs), SetPosition(id,
   pos) (ignore if id mismatches), OpenUri (file:// → play local file via a
   callback); emit `PropertiesChanged` for changed props and `Seeked` on
   seeks/jumps). Use the dbus package's `DBusObject` API (read its source).
6. **MPRIS integration test** (must actually run here): start a private
   session bus (`dbus-daemon --session --print-address --fork` or
   `dbus-run-session`), run the MPRIS server against a fake
   PlaybackController, and verify with the dbus package client and/or
   `playerctl -p fermata metadata/status/play-pause/next`. Document the
   command in your README.
7. **Linux desktop notifications** — `LinuxNotifier implements SystemNotifier`
   via `org.freedesktop.Notifications.Notify` (app name Fermata, icon
   `app.fermata.player`); `isSupported` false if the service is absent.
   Track-change notifications when `notifications.trackChange` is on
   (desktop only; replace previous notification id).
8. **SMTC** (`lib/platform/windows/smtc_adapter.dart`) with `smtc_windows`
   1.1.0: initialize (read its README/source for the required
   `SMTCWindows.initialize()` / RustLib init), update metadata (title,
   artist, album, thumbnail URL or file), playback status, timeline
   (start/end/position, throttled to ~1 Hz), shuffle/repeat; handle
   `buttonPressStream` (play, pause, next, previous, stop) and
   shuffle/repeat change streams. Guard with `Platform.isWindows` so it is
   never touched on Linux. Hardware media keys on Windows are delivered
   through SMTC.
9. **Global hotkeys** — `GlobalHotkeyServiceImpl implements GlobalHotkeyService`
   with `hotkey_manager`: parse accelerators like `ctrl+alt+space` (format
   documented in `ShortcutActions`), register `global.*` actions when
   `shortcuts.globalHotkeysEnabled`, re-apply on settings change, collect
   registration errors. Unit-test the parser.
10. **Startup on login** — `StartupManagerImpl implements StartupManager`:
    Windows via `win32_registry` (HKCU `Software\Microsoft\Windows\CurrentVersion\Run`,
    value `Fermata` = `"<Platform.resolvedExecutable>" --minimized`), Linux via
    `$XDG_CONFIG_HOME/autostart/app.fermata.player.desktop` (Exec = installed
    launcher path if `/proc/self/exe` resolves into an install dir, plus
    `--minimized`). Unit-test the Linux file creation/removal with a temp
    XDG_CONFIG_HOME.
11. **`DesktopIntegration.start(...)`** facade that wires 1–10 for the
    current platform and returns objects for `AppServices` (lifecycle,
    startup, hotkeys, notifier). Non-desktop: returns no-op implementations
    (put the no-ops in `lib/platform/desktop/noop.dart` so Android can use
    them too for lifecycle/startup/hotkeys).
12. `docs/platform/DESKTOP.md`: behaviour per DE (GNOME with/without
    AppIndicator, KDE Plasma, XFCE, Cinnamon), Windows tray/SMTC notes,
    limitations (e.g. Wayland global shortcuts restrictions — hotkey_manager
    uses X11 keybinder on Linux; under pure Wayland global hotkeys may not
    work; MPRIS still provides media keys).
