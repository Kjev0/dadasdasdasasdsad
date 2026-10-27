# Installing Fermata

Fermata is distributed on the project's GitHub **Releases** page:

| Platform | File | What it is |
|---|---|---|
| Windows 10/11 (x64) | `setup.exe` | Installer (per-user by default, no administrator rights needed) |
| Linux (x86_64) | `setup.sh` | Self-extracting installer (per-user by default, no root needed) |
| Linux (x86_64) | `fermata-<version>-linux-x64.tar.gz` | Portable archive, nothing is installed |
| Android 7.0+ | `app.apk` | App package for sideloading |
| all | `SHA256SUMS` | SHA-256 checksums of the files above |

## Check your download

Compare the checksum of the file you downloaded with the line in
`SHA256SUMS` from the same release:

```sh
# Linux (in the download folder; ignores files you did not download)
sha256sum --check --ignore-missing SHA256SUMS
```

```powershell
# Windows (PowerShell)
Get-FileHash .\setup.exe -Algorithm SHA256
```

`setup.sh` also checks itself: it carries a SHA-256 checksum of its embedded
payload and refuses to install (exit code 3) if the file is damaged or was
modified.

---

## Windows

**Requirements:** Windows 10 or 11, 64-bit (x64; Windows 11 on Arm runs the x64
build through emulation).

### Install

1. Run `setup.exe`.
2. **"Windows protected your PC" (SmartScreen).** Release builds of Fermata are
   not code-signed unless the release notes say otherwise, so Windows warns
   about an "unrecognized app". If the checksum matches `SHA256SUMS`, click
   **More info → Run anyway**.
3. Choose **Install for me only** (recommended, no administrator rights;
   installs to `%LOCALAPPDATA%\Programs\Fermata`) or **Install for all users**
   (needs administrator rights; installs to `C:\Program Files\Fermata`).
4. Optional tasks:
   * **Create a desktop shortcut**
   * **Start Fermata when I sign in** (starts minimized to the tray; you can
     change this later in Fermata's settings).
5. The installer adds Fermata to the Start menu and can start it at the end.

The installer is available in English and Danish (chosen from your Windows
display language).

Unattended install (for administrators):

```bat
setup.exe /VERYSILENT /CURRENTUSER /TASKS="desktopicon,autostart"
setup.exe /VERYSILENT /ALLUSERS
```

### Update

Download and run the newer `setup.exe`. It replaces the installed version in
place and keeps your library, playlists, settings and sign-ins. If Fermata is
running (also when it is only in the tray), the installer closes it first.

### Uninstall

**Settings → Apps → Installed apps → Fermata → Uninstall** (or *Control Panel
→ Programs and Features*). The uninstaller closes Fermata if it is running and
then asks **"Do you also want to remove your Fermata data?"**:

* **No** (default) keeps your library and settings, so a later reinstall picks
  up where you left off.
* **Yes** also deletes the data folders listed below.

Music you downloaded to `Music\Fermata` is never deleted by the uninstaller.

Unattended uninstall (keeps data unless `/REMOVEUSERDATA` is given):

```bat
"%LOCALAPPDATA%\Programs\Fermata\unins000.exe" /VERYSILENT
"%LOCALAPPDATA%\Programs\Fermata\unins000.exe" /VERYSILENT /REMOVEUSERDATA
```

### Where Fermata keeps its files (Windows)

| What | Where |
|---|---|
| Program | `%LOCALAPPDATA%\Programs\Fermata` (per user) or `C:\Program Files\Fermata` |
| Library database, playlists, settings, logs, encrypted sign-ins | `%APPDATA%\Fermata\Fermata` |
| Cache (artwork, partial downloads) | `%LOCALAPPDATA%\Fermata\Fermata` |
| Downloaded music | `%USERPROFILE%\Music\Fermata` (changeable in settings) |
| Start on sign-in | registry value `Fermata` in `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` |

---

## Linux

**Requirements:** a 64-bit x86 (x86_64) system with glibc 2.35 or newer:
Ubuntu 22.04+, Debian 12+, Linux Mint 21+, Fedora 36+, Arch Linux / Manjaro,
openSUSE Tumbleweed or Leap 15.6, and most other current distributions.

### Install

```sh
chmod +x setup.sh
./setup.sh            # or: bash setup.sh
```

This installs Fermata **for your user only, without root**:

| Installed file | Location |
|---|---|
| Application | `~/.local/lib/fermata/<version>/` (and a `current` symlink) |
| `fermata` command | `~/.local/bin/fermata` |
| Menu entry | `~/.local/share/applications/app.fermata.player.desktop` |
| Icons | `~/.local/share/icons/hicolor/…/apps/app.fermata.player.*` |
| AppStream metadata | `~/.local/share/metainfo/app.fermata.player.metainfo.xml` |
| Uninstaller | `~/.local/lib/fermata/uninstall.sh` |

Fermata then appears in your application menu. To start it from a terminal,
run `fermata` (if `~/.local/bin` is not on your `PATH`, the installer tells
you how to add it).

**For all users:** `./setup.sh --system` installs to `/opt/fermata`,
`/usr/local/bin/fermata` and `/usr/share/…`. The installer runs as your user
and uses `sudo` only for the copy steps (it says so before asking for your
password).

Installer options:

| Option | Effect |
|---|---|
| `--system` | Install for all users (see above) |
| `--check` | Only check the runtime libraries; exit code 4 if some are missing |
| `--no-deps` | Skip the library check |
| `-y`, `--yes` | Answer yes to every question (unattended installs) |
| `--extract DIR` | Unpack the portable application into `DIR` and exit |
| `--uninstall` | Remove Fermata (keeps your data) |
| `--uninstall --purge` | Remove Fermata and, after confirmation, your data |
| `--version`, `--help` | |

Exit codes: 0 success, 1 error, 2 wrong usage, 3 damaged installer,
4 missing libraries, 5 not installed (`--uninstall`), 6 cancelled.

### Runtime libraries

The installer checks the libraries Fermata needs and, if some are missing,
shows the exact command for your distribution and asks before running it
with `sudo` (answer `y`, or pass `--yes`). You can also install them
yourself:

```sh
# Ubuntu 24.04+, Debian 13+, Linux Mint 22+
sudo apt install libgtk-3-0t64 libmpv2 libsecret-1-0 libkeybinder-3.0-0 libx11-6 libxi6 libepoxy0
# Debian 12
sudo apt install libgtk-3-0 libmpv2 libsecret-1-0 libkeybinder-3.0-0 libx11-6 libxi6 libepoxy0
# Ubuntu 22.04, Linux Mint 21
sudo apt install libgtk-3-0 libmpv1 libsecret-1-0 libkeybinder-3.0-0 libx11-6 libxi6 libepoxy0

# Fedora
sudo dnf install gtk3 mpv-libs libsecret keybinder3 libX11 libXi libepoxy

# Arch Linux, Manjaro
sudo pacman -S --needed gtk3 mpv libsecret libkeybinder3 libx11 libxi libepoxy

# openSUSE
sudo zypper install libgtk-3-0 'libmpv.so.2()(64bit)' libsecret-1-0 'libkeybinder-3.0.so.0()(64bit)' libX11-6 libXi6 libepoxy0
```

| Library | Needed for |
|---|---|
| GTK 3, libepoxy, Fontconfig, X11/Xi | Starting Fermata at all (user interface, tray icon) |
| libsecret | Keeping your streaming-service sign-ins in the system keyring |
| keybinder 3 | Global keyboard shortcuts |
| libmpv (`libmpv.so.2` or `.1`) | Playing audio (Fermata starts without it but cannot play) |
| EGL (optional) | GPU rendering; without it Fermata draws in software |

RHEL, Rocky Linux and AlmaLinux need the EPEL and RPM Fusion repositories for
`mpv-libs` and `keybinder3`.

### Portable use

```sh
tar -xzf fermata-<version>-linux-x64.tar.gz
./fermata-<version>-linux-x64/fermata
# or, from the installer:
./setup.sh --extract ~/Apps/fermata && ~/Apps/fermata/fermata
```

The portable copy uses the same data folders as an installed one. The
desktop entry and icons are included in `share/` if you want to integrate it
yourself.

### Update

Run the newer `setup.sh` the same way you installed (add `--system` for a
system-wide installation). It installs the new version next to the old one,
switches `current` over, removes the old version and keeps your data and
settings. If Fermata is running, the installer asks you to quit it first
(tray icon or menu → **Quit**); if you continue anyway, the old version is
kept until the next update or uninstall so the running copy keeps working.

### Uninstall

```sh
~/.local/lib/fermata/uninstall.sh           # or: ./setup.sh --uninstall
sudo /opt/fermata/uninstall.sh              # system-wide installation
```

The uninstaller removes exactly the files the installer created (listed in
`~/.local/lib/fermata/install-manifest`) and a "start on login" entry that
points at the removed program. Your library and settings are kept. To delete
them too:

```sh
~/.local/lib/fermata/uninstall.sh --purge    # asks before deleting anything
```

`--purge` removes `~/.local/share/app.fermata.player`,
`~/.cache/app.fermata.player`, `~/.config/autostart/app.fermata.player.desktop`
and the sign-ins Fermata stored in your keyring. Downloaded music in
`~/Music/Fermata` is never deleted.

### Where Fermata keeps its files (Linux)

| What | Where |
|---|---|
| Library database, playlists, settings, logs | `~/.local/share/app.fermata.player/` (`$XDG_DATA_HOME`) |
| Cache (artwork, partial downloads) | `~/.cache/app.fermata.player/` (`$XDG_CACHE_HOME`) |
| Sign-in tokens | Your keyring (GNOME Keyring, KWallet, KeePassXC), never in files |
| Downloaded music | `~/Music/Fermata` (your XDG music folder; changeable in settings) |
| Start on login | `~/.config/autostart/app.fermata.player.desktop` |

---

## Android

**Requirements:** Android 7.0 or newer.

### Install

1. Download `app.apk` on the phone (or copy it there).
2. Open it from the browser's downloads or the **Files** app.
3. The first time, Android asks you to allow this app (browser or Files) to
   **install unknown apps**: tap **Settings**, turn on **Allow from this
   source**, go back and tap **Install**. (Settings → Apps → Special app access
   → Install unknown apps.)
4. Google Play Protect may say it does not recognize the developer. Tap **More
   details → Install anyway** if the checksum matches `SHA256SUMS`.

Fermata asks for permissions only when you use the feature that needs them:
**Music and audio** (to find songs stored on the phone) and **Notifications**
(download and error notices; playback controls work without it).

### Keep playback running in the background

Playback runs as a media service with a notification, which normally keeps it
alive. Some phones stop background apps aggressively anyway. If music stops
with the screen off, or headphone/car buttons stop working after a long pause:

* In Fermata's settings, allow **unrestricted battery use** (or set
  Settings → Apps → Fermata → Battery → **Unrestricted**).
* Samsung: Settings → Battery → Background usage limits: add Fermata to
  **Never sleeping apps**.
* Xiaomi/Redmi/POCO: enable **Autostart** and set Battery saver to **No
  restrictions**. Huawei/Honor: App launch → manage manually, allow all.
* Per-device instructions: <https://dontkillmyapp.com>

### Update

Install the newer `app.apk` over the existing app; your data is kept. Android
only allows this if both versions are signed with the same key. If the update
fails with "App not installed" / "package conflicts", the installed copy was
signed differently (for example a test build): uninstall it first, which
deletes its data.

### Uninstall

Long-press Fermata → **Uninstall** (or Settings → Apps → Fermata →
Uninstall). Android deletes the app's data with it, **including music
downloaded inside Fermata** (stored in `Android/data/app.fermata.player/`).
Music files you added from elsewhere on the phone are not touched. Cloud
backup is turned off for Fermata, so a reinstall starts fresh; reconnect your
streaming accounts after moving to a new phone.

---

## Troubleshooting

**Linux: no tray icon (GNOME).** Stock GNOME has no system tray. Install and
enable the AppIndicator extension (package `gnome-shell-extension-appindicator`
on Debian/Ubuntu/Fedora/Arch/openSUSE, then log out and in; Ubuntu enables it
by default). Without a tray, Fermata still works: closing the window
minimizes it instead of hiding it to the tray. The installer warns when it
finds no tray host in your session.

**Linux: "fermata: command not found".** `~/.local/bin` is not on your `PATH`.
Start Fermata from the application menu, or add
`export PATH="$HOME/.local/bin:$PATH"` to `~/.profile` and log in again.

**Linux: Fermata does not start.** Run `./setup.sh --check` to find missing
libraries, then start `~/.local/bin/fermata` from a terminal to see its
messages. Logs are in `~/.local/share/app.fermata.player/logs/`.

**Linux: global shortcuts do nothing (Wayland).** Global hotkeys need an X11
session. On Wayland, bind keys in your desktop's keyboard settings to
`fermata --play-pause`, `fermata --next` and `fermata --previous`; hardware
media keys work everywhere through MPRIS.

**Linux: sign-ins are forgotten after a restart.** No keyring (Secret Service)
is running. Install `gnome-keyring` (or enable KeePassXC's Secret Service
integration) and make sure it is unlocked at login.

**Linux (Fedora): some AAC/M4A files do not play.** Fedora's `mpv-libs` uses
the reduced `ffmpeg-free`. Switch to RPM Fusion's full FFmpeg:
`sudo dnf swap ffmpeg-free ffmpeg --allowerasing`.

**Windows: SmartScreen blocks the installer.** See *Install*, step 2. Some
antivirus products also flag new, unsigned installers; compare the checksum
and allow the file.

**Windows: where is the tray icon?** New icons start in the hidden overflow
area (the `^` next to the clock). Drag Fermata's icon onto the taskbar, or
enable it under Settings → Personalization → Taskbar → Other system tray icons.

**Android: playback stops in the background.** See *Keep playback running in
the background*.
