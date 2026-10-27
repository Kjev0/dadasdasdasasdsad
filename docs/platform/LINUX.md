# Fermata on Linux

Native configuration for the Linux (GTK 3) build: build prerequisites, the
release bundle, runtime dependencies per distribution (the installer checks
these), desktop integration files and known platform limitations.

Desktop behaviour (tray, MPRIS, close-to-tray, hotkeys per desktop
environment) is described in `docs/platform/DESKTOP.md`.

| Item | Value |
|---|---|
| Application ID | `app.fermata.player` (`APPLICATION_ID` in `linux/CMakeLists.txt`) |
| Binary | `fermata` (`BINARY_NAME`) |
| X11 `WM_CLASS` | `"app.fermata.player", "App.fermata.player"` (verified with `xprop`; the runner calls `g_set_prgname(APPLICATION_ID)`) |
| Wayland `app_id` / `_GTK_APPLICATION_ID` | `app.fermata.player` |
| Desktop entry | `packaging/linux/app.fermata.player.desktop` |
| AppStream metadata | `packaging/linux/app.fermata.player.metainfo.xml` |
| Icon name | `app.fermata.player` (hicolor theme; files in `packaging/linux/icons/`, owned by branding) |
| MPRIS bus name | `org.mpris.MediaPlayer2.fermata` (`DesktopEntry` = `app.fermata.player`) |

## Building

Build machine packages (Debian/Ubuntu names; Flutter's own Linux
requirements plus what the plugins' CMake files and build hooks look for):

```sh
sudo apt install clang cmake ninja-build pkg-config \
  libgtk-3-dev libx11-dev libxi-dev \
  libsecret-1-dev libkeybinder-3.0-dev libmpv-dev
```

| Build dependency | Needed by |
|---|---|
| `libgtk-3-dev` | Flutter GTK embedder, every plugin |
| `libx11-dev`, `libxi-dev` | `tray_manager` 0.8 (its `cnativeapi` build hook runs `pkg-config` for GTK 3, X11 and Xi) |
| `libsecret-1-dev` (>= 0.18.4) | `flutter_secure_storage_linux` |
| `libkeybinder-3.0-dev` | `hotkey_manager_linux` |
| `libmpv-dev` | not linked at build time; installs `libmpv.so` for running from a dev machine |

`libayatana-appindicator3-dev` is **not** needed: `tray_manager` 0.8 talks
StatusNotifierItem over D-Bus itself. The `MIMALLOC_USE_STATIC_LIBS OFF`
block in `linux/CMakeLists.txt` stops `media_kit_libs_linux` from downloading
mimalloc from GitHub at configure time, so the build works offline.

```sh
source /opt/sdk/env.sh        # CI/dev container only
flutter build linux --release
```

Output: `build/linux/x64/release/bundle/` (about 26 MB), relocatable; the
binary finds its libraries through `RUNPATH=$ORIGIN/lib`:

```
bundle/
  fermata                       # launcher (24 KB)
  data/icudtl.dat
  data/flutter_assets/
  lib/libapp.so                 # AOT-compiled Dart code
  lib/libflutter_linux_gtk.so   # Flutter engine
  lib/lib*_plugin.so            # app_links, flutter_secure_storage, hotkey_manager,
                                # media_kit_libs_linux, screen_retriever, url_launcher,
                                # window_manager
  lib/libcnativeapi.so          # tray_manager native code (build hook)
  lib/libsqlite3.so             # bundled SQLite (sqlite3 build hook), no system dependency
  lib/libdartjni.so             # package:jni (transitive dependency, unused on Linux; see below)
```

Install the whole bundle directory (e.g. to `/opt/fermata/` or
`~/.local/lib/fermata/`) and put a `fermata` symlink or wrapper on `PATH`,
because the desktop entry runs `fermata %U`.

## Runtime dependencies

Collected from `readelf -d` (direct `NEEDED` entries) of the binary and every
bundled library, plus the libraries Fermata `dlopen()`s at runtime
(`/proc/<pid>/maps` of a running instance). The rest of the `ldd` tree
(pango, cairo, harfbuzz, gdk-pixbuf, atk, Wayland/X client libraries, ...) is
pulled in by the GTK 3 package.

### Shared libraries

| soname(s) | Used by | Debian / Ubuntu | Fedora | Arch |
|---|---|---|---|---|
| `libgtk-3.so.0`, `libgdk-3.so.0` | Flutter embedder, all plugins | `libgtk-3-0t64` (Ubuntu 24.04+, Debian 13+) or `libgtk-3-0` (older) | `gtk3` | `gtk3` |
| `libglib-2.0.so.0`, `libgio-2.0.so.0`, `libgobject-2.0.so.0` | everything (via GTK) | `libglib2.0-0t64` or `libglib2.0-0` | `glib2` | `glib2` |
| `libepoxy.so.0` | Flutter engine (GL loader) | `libepoxy0` | `libepoxy` | `libepoxy` |
| `libfontconfig.so.1` | Flutter engine | `libfontconfig1` | `fontconfig` | `fontconfig` |
| `libstdc++.so.6`, `libgcc_s.so.1` | C++ plugins and engine | `libstdc++6`, `libgcc-s1` | `libstdc++`, `libgcc` | `gcc-libs` |
| `libz.so.1` | GTK / plugins | `zlib1g` | `zlib-ng-compat` (or `zlib`) | `zlib` |
| `libX11.so.6`, `libXi.so.6` | tray (`libcnativeapi.so`) | `libx11-6`, `libxi6` | `libX11`, `libXi` | `libx11`, `libxi` |
| `libsecret-1.so.0` | secure token storage | `libsecret-1-0` | `libsecret` | `libsecret` |
| `libkeybinder-3.0.so.0` | global hotkeys | `libkeybinder-3.0-0` | `keybinder3` | `libkeybinder3` |
| `libmpv.so.2` (or `libmpv.so.1`): **`dlopen`ed**, not in `ldd` output | all audio playback (media_kit tries `libmpv.so`, `libmpv.so.2`, `libmpv.so.1`, or `$LIBMPV_LIBRARY_PATH`) | `libmpv2` (Debian 12+, Ubuntu 23.04+/24.04) or `libmpv1` (Ubuntu 22.04, Debian 11) | `mpv-libs` | `mpv` |
| `libEGL.so.1`, `libGLESv2.so.2` (+ Mesa or vendor driver): `dlopen`ed by libepoxy | GPU rendering (Impeller, OpenGL ES). Without them Flutter falls back to software rendering | `libegl1`, `libgles2`, `libegl-mesa0`, `libgl1-mesa-dri` | `libglvnd-egl`, `libglvnd-gles`, `mesa-libEGL`, `mesa-dri-drivers` | `libglvnd`, `mesa` |

Not runtime dependencies, even though older docs or `ldd` suggest them:

* **`libayatana-appindicator3-1` / `libappindicator3-1`**: not needed and
  not loaded (verified); the tray is a D-Bus StatusNotifierItem.
* **`libjvm.so`**: `lib/libdartjni.so` (from `package:jni`, a transitive
  dependency used only on Android) lists `libjvm.so` with a `RUNPATH` that
  points at the build machine's JDK. It is only loaded if Dart code calls
  `package:jni`, which Fermata never does on Linux. The installer must
  **ignore** it, and `ldd` reporting `libjvm.so => not found` for that one
  file is expected.
* `libdbus-1`: MPRIS, tray, notifications and portals use the pure-Dart
  `dbus` package over the session-bus socket.

Codecs: Fedora's `mpv-libs` is built against `ffmpeg-free`, which leaves out
some patent-encumbered decoders. If AAC/M4A files will not play there, users
can switch to RPM Fusion's full FFmpeg (`sudo dnf swap ffmpeg-free ffmpeg
--allowerasing`). Debian, Ubuntu and Arch ship full decoders.

### Install commands

```sh
# Ubuntu 24.04+, Debian 13+
sudo apt install libgtk-3-0t64 libmpv2 libsecret-1-0 libkeybinder-3.0-0 libx11-6 libxi6 libepoxy0
# Debian 12: libgtk-3-0 instead of libgtk-3-0t64
# Ubuntu 22.04, Debian 11: libgtk-3-0 and libmpv1

# Fedora
sudo dnf install gtk3 mpv-libs libsecret keybinder3 libX11 libXi libepoxy

# Arch
sudo pacman -S --needed gtk3 mpv libsecret libkeybinder3 libx11 libxi libepoxy
```

For a `.deb` `Depends:` line use alternatives for the `t64` renames:
`libgtk-3-0t64 | libgtk-3-0, libmpv2 | libmpv1, libsecret-1-0, libkeybinder-3.0-0, libx11-6, libxi6, libepoxy0`.
For an `.rpm`: `Requires: gtk3, mpv-libs, libsecret, keybinder3, libX11, libXi, libepoxy`.

### Desktop services (D-Bus, not libraries)

The app starts without these; only the matching feature degrades.

| Service | Needed for | Typical provider (Debian / Fedora / Arch package) |
|---|---|---|
| Session D-Bus | MPRIS, tray, notifications, portals, keyring | `dbus-user-session` or `dbus-broker` (part of every desktop install) |
| Secret Service (`org.freedesktop.secrets`) | storing streaming-account tokens | `gnome-keyring` on all three; KDE Plasma 6's KWallet, or KeePassXC with Secret Service enabled. Without it, signing in to online services fails with a keyring error; local playback is unaffected |
| StatusNotifierItem host (`org.kde.StatusNotifierWatcher`) | tray icon | KDE Plasma, XFCE, Cinnamon, MATE, Budgie, waybar... GNOME only with `gnome-shell-extension-appindicator` (Ubuntu enables it by default). Without a host, closing the window minimizes instead of hiding to tray |
| `xdg-desktop-portal` + a backend (`-gtk`, `-gnome` or `-kde`) | "Add music folder" / file dialogs (`file_picker` uses the FileChooser portal) | `xdg-desktop-portal` + `xdg-desktop-portal-gtk` (all three distros) |
| `org.freedesktop.Notifications` | track-change / download notifications | every desktop's notification daemon (`mako`, `dunst` on bare compositors) |
| NetworkManager | offline / metered detection (`connectivity_plus` talks to NetworkManager over D-Bus) | `network-manager` / `NetworkManager` / `networkmanager`. Without it `checkConnectivity()` throws, so the app must treat connectivity as unknown (assume online) |

### Installer check

POSIX `sh`, tested on Ubuntu 24.04 (pass, and fail with a missing soname):

```sh
#!/bin/sh
# Fermata runtime dependency check. Exit 1 if a hard dependency is missing.
LDCONFIG=$(command -v ldconfig || echo /sbin/ldconfig)
CACHE=$("$LDCONFIG" -p 2>/dev/null)
have() { printf '%s\n' "$CACHE" | grep -q "[[:space:]]$1 "; }
missing=""
for so in libgtk-3.so.0 libepoxy.so.0 libsecret-1.so.0 libkeybinder-3.0.so.0 libX11.so.6 libXi.so.6; do
  have "$so" || missing="$missing $so"
done
have libmpv.so.2 || have libmpv.so.1 || have libmpv.so || missing="$missing libmpv.so.2"
if [ -n "$missing" ]; then
  echo "Fermata: missing runtime libraries:$missing" >&2
  exit 1
fi
# Soft checks (features degrade, app still starts):
have libEGL.so.1 || echo "Fermata: no libEGL.so.1, falling back to software rendering" >&2
echo "Fermata: runtime dependencies OK"
```

## Desktop integration files

| File | Install to |
|---|---|
| `packaging/linux/app.fermata.player.desktop` | `/usr/share/applications/` (or `~/.local/share/applications/`) |
| `packaging/linux/app.fermata.player.metainfo.xml` | `/usr/share/metainfo/` |
| icons from `packaging/linux/icons/` (branding), named `app.fermata.player.png` / `.svg` | `/usr/share/icons/hicolor/<size>/apps/` (or `~/.local/share/icons/hicolor/<size>/apps/`) |

After installing, refresh the caches:

```sh
update-desktop-database ~/.local/share/applications      # or /usr/share/applications
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor  # or /usr/share/icons/hicolor
```

Validation (both pass):

```sh
desktop-file-validate packaging/linux/app.fermata.player.desktop
appstreamcli validate --no-net packaging/linux/app.fermata.player.metainfo.xml
#  W: url-homepage-missing  (add <url type="homepage"> once there is a site)
```

Notes on the desktop entry:

* The file name equals the application ID, so GNOME Shell, KDE and the MPRIS
  `DesktopEntry` property all match the running window to it.
  `StartupWMClass=app.fermata.player` matches the verified WM_CLASS instance
  name for docks that rely on it.
* `Exec=fermata %U`: Fermata may receive local paths, `file://` URIs and
  `fermata://` URIs as arguments (opening files from a file manager, see
  `MimeType=`). The Dart single-instance handler must forward them to the
  running instance.
* The autostart entry written by "Start on login"
  (`$XDG_CONFIG_HOME/autostart/app.fermata.player.desktop`) is generated at
  runtime by the desktop module, not by this file.

## Deep links / OAuth

On desktop, OAuth uses a **loopback redirect** (`http://127.0.0.1:<port>/...`,
RFC 8252), so no URL scheme registration is needed to sign in. The desktop
entry still declares `x-scheme-handler/fermata` so `fermata://` links open
Fermata. Make Fermata the handler while developing:

```sh
cp packaging/linux/app.fermata.player.desktop ~/.local/share/applications/
xdg-mime default app.fermata.player.desktop x-scheme-handler/fermata
xdg-open 'fermata://oauth/test'
```

`app_links_linux` delivers such a link to an already running instance only if
`linux/runner/my_application.cc` uses
`G_APPLICATION_HANDLES_COMMAND_LINE | G_APPLICATION_HANDLES_OPEN` instead of
`G_APPLICATION_NON_UNIQUE` (see the app_links Linux setup). That change is not
applied (the runner keeps Flutter's default), so a link or file opened while
Fermata runs starts a second process that hands over to the first through
Fermata's Dart single-instance mechanism. As specified, that mechanism
forwards `show` and the `--play-pause` / `--next` / `--previous` flags;
forwarding file paths and `fermata://` URIs has to be added there if those
should reach the running instance.

## Known limitations

* **Global hotkeys need X11.** `hotkey_manager` uses keybinder (X11 key
  grabs). In a Wayland session they do not fire. Users can bind keys in the
  desktop's own shortcut settings to `fermata --play-pause`, `--next` or
  `--previous` (forwarded to the running instance), and hardware media keys
  work through MPRIS everywhere.
* **Window position on Wayland.** Wayland compositors do not let clients
  place their own windows, so a saved window position is ignored there; the
  size is still restored.
* **No tray on stock GNOME** without the AppIndicator extension (see above).
* **Keyring.** On minimal window-manager setups without a Secret Service
  provider, online accounts cannot be connected.
