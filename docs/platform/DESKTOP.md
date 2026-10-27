# Fermata on the desktop: window, tray, media keys, hotkeys, startup

How Fermata behaves on Linux and Windows desktops. Build and packaging
details: `docs/platform/LINUX.md`. Code: `lib/platform/desktop`,
`lib/platform/linux`, `lib/platform/windows` (see the README there).

## Closing the window does not stop the music

| Situation | Close button (×) | How to get the window back |
|---|---|---|
| Tray icon shown (default) | Window is hidden; music keeps playing | Tray icon → **Show Fermata** (Windows: left click), media controls of the desktop (MPRIS **Raise**), or start Fermata again |
| No tray available (see below) or tray icon turned off | Window is **minimized** instead, so it stays in the taskbar/dock | Taskbar/dock, MPRIS Raise, or start Fermata again |
| Settings → System tray & window → "Ask" | A dialog offers "Keep playing in background" / "Quit", optionally remembered | as above |
| "Quit when closed" | Fermata quits | — |

**Quit Fermata** (tray menu, app menu, MPRIS `Quit`) stops playback, saves the
queue, settings and window position, removes the tray icon, releases media
keys and exits. If the tray icon disappears while the window is hidden (the
setting is switched off or the panel crashes), the window is shown again so
Fermata never becomes unreachable.

Window size and position are restored on the next start (Settings → "Remember
window size"); a position on a monitor that is no longer connected is moved
back onto the primary screen.

## Tray icon by desktop

On Linux the tray icon is a *StatusNotifierItem* over D-Bus. It is only
visible when the panel runs a StatusNotifier host
(`org.kde.StatusNotifierWatcher` on the session bus); Fermata checks this at
start and whenever the host appears or disappears.

| Desktop | Tray icon | Media controls (MPRIS) | Notifications |
|---|---|---|---|
| **GNOME** (Fedora, Debian, Arch) | Not shown by default. Install/enable the *AppIndicator and KStatusNotifierItem Support* extension (`gnome-shell-extension-appindicator`); Fermata picks it up without a restart. Until then close = minimize, and Settings explains why. | Date/notification menu player, lock screen; media keys via gnome-settings-daemon | GNOME Shell |
| **Ubuntu** (GNOME) | Shown: Ubuntu enables its AppIndicators extension by default | as GNOME | GNOME Shell |
| **KDE Plasma** 5/6 | Shown (system tray) | Media player applet in the tray, lock screen, KDE Connect; media keys | Plasma |
| **XFCE** 4.16+ | Shown via the *Status Tray Plugin* (add it to the panel if missing) | PulseAudio panel plugin can control players ("Control playback of media players"); media keys via that plugin | xfce4-notifyd |
| **Cinnamon** | Shown (xapp-sn-watcher) | Sound applet shows player controls; media keys | Cinnamon |
| MATE, Budgie, LXQt, sway/Hyprland + waybar | Shown when the panel/bar has an SNI tray (waybar `tray` module) | Panel players; `playerctl` for bars | mako, dunst, ... |

Tray menu: the current "Title — Artist" (or "Not playing"), Play/Pause,
Previous, Next, **Show Fermata**, **Quit Fermata**. The tooltip shows
"Fermata — Title · Artist". Labels follow the app language. On Linux the
panel decides what clicking the icon does (usually opens the menu).

Icon files come from the app bundle (`data/flutter_assets/assets/branding/`):
`tray_icon.png` (Linux, colour), `tray_icon_mono.png` (Linux, used when the
desktop reports a dark colour scheme through the XDG portal),
`tray_icon.ico` (Windows). If they are missing the tray is skipped with a
warning in the log and Settings says so.

## Media keys and system media controls

* **Linux — MPRIS.** Fermata owns `org.mpris.MediaPlayer2.fermata` (a second
  copy uses `...fermata.instance<pid>`) at `/org/mpris/MediaPlayer2` with
  `DesktopEntry=app.fermata.player`. Supported: play/pause/stop/next/previous,
  seek and set position, loop (None/Track/Playlist), shuffle, rate
  (0.5–2.0), volume, metadata (title, artists, album, album artist, length,
  artwork URL, `file://` URL for local files), Raise, Quit and opening
  `file://` URIs. Desktop media keys reach Fermata through MPRIS on every
  desktop above, including Wayland sessions. Test with
  `playerctl -p fermata status`, `playerctl -p fermata metadata`.
* **Windows — SMTC.** Fermata registers with the System Media Transport
  Controls: the media flyout (volume keys on Windows 10, Quick Settings media
  card on Windows 11) and the lock screen show title, artist, album and
  artwork (https or local file), play/pause/next/previous/stop work, and
  shuffle/repeat toggles are honoured. **Hardware media keys on Windows
  arrive through SMTC**, so they work without any global hotkey. The
  timeline is updated about once per second, and immediately after seeks.

## Global hotkeys

Settings → Keyboard shortcuts → "Global hotkeys" registers system-wide
bindings (defaults: `ctrl+alt+space` play/pause, `ctrl+alt+right` next,
`ctrl+alt+left` previous, `ctrl+alt+f` show window). Changes apply
immediately. Settings lists bindings that could not be registered: invalid
text, a binding used twice, a plain key without Ctrl/Alt/Shift/Super (it would
block typing everywhere; media and F-keys are allowed alone), or a
registration the system refused.

* **Windows:** `RegisterHotKey`. Bindings to media keys are skipped because
  SMTC already delivers them (registering both would trigger twice).
* **Linux X11:** keybinder (X11 key grabs).
* **Linux Wayland:** applications cannot grab keys globally, and the X11
  method does not apply to GTK running on Wayland, so the switch is shown as
  unavailable with an explanation. Use the desktop's own keyboard settings
  instead and bind a custom shortcut to a command, e.g.
  `playerctl -p fermata play-pause` or `fermata --play-pause` (forwarded to
  the running instance). Media keys keep working through MPRIS.
* Neither platform tells an application when a combination is already taken
  by another program; in that case the system silently keeps the other
  program's binding.

## Single instance and command line

Starting Fermata while it is running brings the existing window to the front
instead of opening a second copy. Command-line flags are forwarded to the
running instance:

| Command | Effect |
|---|---|
| `fermata` | Show the window |
| `fermata --play-pause` / `--next` / `--previous` | Control playback (useful for custom shortcuts) |
| `fermata <file>` / `fermata file:///…` | Play that local file and show the window |
| `fermata --minimized` | Start hidden to the tray (minimized when there is no tray); does nothing if already running |

The running instance listens on a loopback port recorded, together with a
random token, in `instance.lock` in the app's data directory (owner-only).
A lock left behind by a crash is detected and replaced automatically.

## Start on login

Settings → Startup → "Launch at login", optionally "Start minimized".

* **Linux:** writes `~/.config/autostart/app.fermata.player.desktop`
  (`$XDG_CONFIG_HOME` respected). `Exec` uses the `fermata` launcher on `PATH`
  when it points at the installed bundle, otherwise the binary itself, plus
  `--minimized` when chosen. Honoured by GNOME, KDE Plasma, XFCE, Cinnamon,
  MATE and LXQt. An entry disabled by the desktop (`Hidden=true`) counts as
  off.
* **Windows:** `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, value
  `Fermata` = `"<path>\fermata.exe" [--minimized]`; no administrator rights.
  The entry appears in Settings → Apps → Startup and in Task Manager;
  switching it off there is respected, switching it on in Fermata clears it.

## Notifications

With Settings → Notifications → "Track change" on, Linux shows a "now
playing" notification for each new track (replacing the previous one, kept
out of the notification history) through `org.freedesktop.Notifications`.
Downloads use the same service. Without a notification server, or on
Windows, Fermata shows in-app messages instead.

## Limitations

* GNOME without the AppIndicator extension has no tray; Fermata minimizes
  instead of hiding.
* Global hotkeys do not work in Wayland sessions (see above).
* The stock Flutter runners show the window when the first frame is drawn;
  when starting minimized Fermata hides it again immediately, so the window
  can flash briefly at login.
* Windows notifications (toasts) are not implemented.
* The Windows code (tray, SMTC, Run key) is written against the package
  sources and is compiled by the Windows CI build, not in the Linux
  development container.
