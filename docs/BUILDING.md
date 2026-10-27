# Building Fermata

How to build and package Fermata for Linux, Windows and Android. Installing
the result is described in [INSTALL.md](INSTALL.md), publishing a release in
[RELEASING.md](RELEASING.md).

## Toolchain

| Tool | Version | Needed for |
|---|---|---|
| Flutter (stable) | **3.47.8** (Dart 3.13.7) | everything |
| clang, CMake, Ninja, pkg-config, GTK 3 headers | distribution packages | Linux |
| Visual Studio 2022 or newer, "Desktop development with C++" workload | | Windows |
| Rust (`rustup`, stable) | | Windows (`smtc_windows` builds Rust code through cargokit) |
| Inno Setup | 6.3 or newer | Windows installer |
| JDK | 17 or newer | Android (Android Gradle Plugin 9.1, Gradle 9.3) |
| Android SDK | platform 37, build-tools, NDK 28.2 | Android |

## Common steps

```sh
flutter pub get
dart run tool/merge_arb.dart      # merge lib/l10n/fragments/*.arb into lib/l10n/arb/
flutter gen-l10n
flutter analyze
flutter test
```

### Developer credentials (`--dart-define-from-file`)

Online sources that need registered client IDs read them at runtime (entered
in the app or `credentials.json`) or from build-time defines. To compile them
in, put them in `dart_defines.json` in the project root (git-ignored; format
and keys in [CREDENTIALS.md](CREDENTIALS.md)) and pass the file to the build:

```sh
flutter build linux --release --dart-define-from-file=dart_defines.json
tool/package_linux.sh --dart-define-from-file dart_defines.json
tool/build_android.sh --dart-define-from-file dart_defines.json
```

```powershell
.\tool\package_windows.ps1 -DartDefineFromFile dart_defines.json
```

All three packaging scripts also read the path from the environment variable
`FERMATA_DART_DEFINES_FILE`. Anything compiled into a binary can be extracted
from it: never compile client **secrets** into builds you publish (see
[CREDENTIALS.md](CREDENTIALS.md)).

---

## Linux

Build machine packages (Debian/Ubuntu names):

```sh
sudo apt install clang cmake ninja-build pkg-config \
  libgtk-3-dev libx11-dev libxi-dev libsecret-1-dev libkeybinder-3.0-dev libmpv-dev
# optional, used by tool/package_linux.sh when present:
sudo apt install desktop-file-utils appstream shellcheck
```

Build only:

```sh
flutter build linux --release
# -> build/linux/x64/release/bundle/  (fermata, lib/, data/)
```

Build and package:

```sh
tool/package_linux.sh                 # flutter build linux --release + packaging
tool/package_linux.sh --skip-build    # package the existing bundle
```

| Output | |
|---|---|
| `dist/setup.sh` | Self-extracting installer (bash header + tar.gz payload) |
| `dist/fermata-<version>-linux-x64.tar.gz` | Portable archive |

`<version>` is the `version:` in `pubspec.yaml` without the `+build` suffix.
The packager:

1. checks the bundle (`fermata`, `lib/libapp.so`, `lib/libflutter_linux_gtk.so`,
   `data/`),
2. validates `packaging/linux/app.fermata.player.desktop`
   (`desktop-file-validate`) and `app.fermata.player.metainfo.xml`
   (`appstreamcli validate --no-net`),
3. requires the icons in `packaging/linux/icons/hicolor/<size>/apps/app.fermata.player.{png,svg}`
   (`--allow-missing-assets` downgrades missing icons/metadata to a warning for local tests),
4. stages the payload: the bundle at the top level, `share/applications/`,
   `share/metainfo/`, `share/icons/hicolor/`, `share/fermata/uninstall.sh`
   and `share/fermata/VERSION`,
5. builds reproducible archives (sorted, owner 0:0, mtime = last commit),
6. writes `dist/setup.sh` from `packaging/linux/setup.sh` with
   `packaging/linux/lib/common.sh` inlined and the version, payload size and
   payload SHA-256 filled in, then appends the payload,
7. runs shellcheck on the generated scripts and a self-test
   (`setup.sh --extract`, compared with the build).

### Installer sources

| File | Role |
|---|---|
| `packaging/linux/setup.sh` | Installer template (install, `--system`, `--check`, `--extract`, `--uninstall`) |
| `packaging/linux/uninstall.sh` | Uninstaller, installed next to the install manifest |
| `packaging/linux/lib/common.sh` | Shared helpers, inlined into both at packaging time |

Run `shellcheck -x -P SCRIPTDIR packaging/linux/*.sh packaging/linux/lib/common.sh`
after changing them. The scripts need bash 4 or newer and run unchanged when
started with `sh` (they re-exec bash).

### Testing the installer locally

Use a throwaway home directory so nothing touches your real one:

```sh
export HOME="$(mktemp -d)"
./dist/setup.sh --yes --no-deps
ls -R ~/.local | head; cat ~/.local/lib/fermata/install-manifest
ldd ~/.local/lib/fermata/current/fermata | grep 'not found'      # expect nothing
timeout 15 xvfb-run -a ~/.local/bin/fermata; echo $?            # 124 = still running
./dist/setup.sh --uninstall
```

Test hooks (environment variables):

| Variable | Effect |
|---|---|
| `FERMATA_SETUP_FAKE_MISSING="libmpv.so.2 libsecret-1.so.0"` | Treat these sonames as missing (exercises the "missing packages" prompt and `--check` exit code 4) |
| `FERMATA_SETUP_OS_RELEASE=/path/to/os-release` | Pretend to be another distribution (shows its package command; never runs a package manager) |
| `NO_COLOR=1` | Plain output |

### Runtime dependencies and glibc

The bundle links GTK 3, libepoxy, Fontconfig, libstdc++, X11/Xi (tray),
libsecret and keybinder; libmpv is loaded at runtime. Details per
distribution: [platform/LINUX.md](platform/LINUX.md). `ldd` reports
`libjvm.so => not found` for `lib/libdartjni.so` (from `package:jni`, unused
on Linux); that is expected and the installer ignores it.

A Linux binary needs the glibc it was built against **or newer**. Release
builds are made on Ubuntu 22.04 (glibc 2.35) so they run on Ubuntu 22.04+,
Debian 12+ and every newer distribution. A build made on a newer system works
there but not on older ones; the installer detects that and reports the
required glibc version.

---

## Windows

Prerequisites: Flutter 3.47.8, Visual Studio with the C++ workload, Rust
(`rustup`, stable toolchain), Inno Setup 6.3+:

```powershell
winget install JRSoftware.InnoSetup      # or: choco install innosetup -y
```

Build and package:

```powershell
.\tool\package_windows.ps1                 # flutter build windows --release + setup.exe
.\tool\package_windows.ps1 -SkipBuild      # package build\windows\x64\runner\Release
```

Output: `dist\setup.exe`. The script

1. reads the version from `pubspec.yaml` (`1.2.3+45` becomes `AppVersion=1.2.3`
   and the numeric file version `1.2.3.45`),
2. copies `build\windows\x64\runner\Release` to
   `build\windows\x64\installer-stage` and adds the Visual C++ runtime DLLs
   (`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`, from Visual
   Studio's redistributable folder) next to `fermata.exe`, because Flutter does
   not ship them and a clean Windows installation may not have them,
3. reads `CompanyName`/`ProductName` from `windows\runner\Runner.rc` (they
   decide the data folder `%APPDATA%\<CompanyName>\<ProductName>` that the
   uninstaller's "remove my data" option deletes),
4. finds `ISCC.exe` (`-Iscc`, `%ISCC%`, `PATH`, `Program Files (x86)\Inno Setup 6`,
   `%LOCALAPPDATA%\Programs\Inno Setup 6`, or the uninstall registry key) and
   compiles `packaging\windows\fermata.iss`.

Compiling the script directly:

```bat
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DAppVersion=1.2.3 /DAppVersionNumeric=1.2.3.45 ^
  /DSourceDir=%CD%\build\windows\x64\installer-stage packaging\windows\fermata.iss
```

The installer script uses `packaging\windows\installer_icon.ico`,
`wizard_image.bmp` and `wizard_small.bmp` (branding). What it does: per-user
install by default (`PrivilegesRequired=lowest`, with a dialog to install for
all users), Start menu shortcut with AppUserModelID `app.fermata.player`,
optional desktop shortcut and "Start Fermata when I sign in" (HKCU `Run`
value `Fermata` = `"<app>\fermata.exe" --minimized`), closes a running Fermata
before upgrading or uninstalling, English and Danish, and asks on uninstall
whether to remove the user's data. Code signing: see
[RELEASING.md](RELEASING.md#code-signing).

---

## Android

Prerequisites: JDK 17+, Android SDK with platform 37, build-tools and NDK
28.2 (`flutter doctor` lists what is missing).

```sh
tool/build_android.sh                     # dist/app.apk (universal)
tool/build_android.sh --split-per-abi     # also dist/app-armeabi-v7a.apk, app-arm64-v8a.apk, app-x86_64.apk
tool/build_android.sh --skip-build        # verify/copy the APKs already in build/app/outputs/flutter-apk/
tool/build_android.sh --require-release-signing   # fail (exit 3) if debug-signed
```

The script runs `flutter build apk --release`, copies the APK(s) to `dist/`
and prints package name, versionName/versionCode (`aapt2`) and the signing
certificate (`apksigner verify --print-certs` from the newest build-tools in
`$ANDROID_HOME`). It warns loudly when the APK is signed with the Android
debug key.

### Signing

`android/app/build.gradle.kts` takes the release key from, in this order:

1. `android/key.properties` (git-ignored; template:
   `android/key.properties.example`): `storeFile`, `storePassword`,
   `keyAlias`, `keyPassword`;
2. environment variables `FERMATA_KEYSTORE_PATH`, `FERMATA_KEYSTORE_PASSWORD`,
   `FERMATA_KEY_ALIAS`, `FERMATA_KEY_PASSWORD`;
3. otherwise the **debug key** (with a Gradle warning). Such an APK is fine
   for testing but must not be distributed: it cannot be updated by a
   release-signed build.

A partial configuration (a value missing, keystore file not found) fails the
build. Create a keystore once and back it up together with its passwords:

```sh
keytool -genkeypair -v -keystore ~/fermata-release.jks -storetype PKCS12 \
  -keyalg RSA -keysize 4096 -validity 10000 -alias fermata
```

Check a signed APK yourself:

```sh
"$ANDROID_HOME"/build-tools/*/apksigner verify --print-certs dist/app.apk
```

Keep `build/app/outputs/mapping/release/mapping.txt` (R8) with every release
to deobfuscate Java stack traces. More platform details:
[platform/ANDROID.md](platform/ANDROID.md).

---

## Continuous integration

`.github/workflows/build.yml`: branch pushes and pull requests (except
docs-only changes) run only `test`; `v*` tags run everything and publish a
release; a manual run (*workflow_dispatch*) builds all packages as artifacts
without publishing.

| Job | Runner | Does |
|---|---|---|
| `test` | ubuntu-latest | shellcheck + desktop/AppStream validation, `merge_arb`, `gen-l10n`, `flutter analyze`, `flutter test`; on tags, checks that the tag equals `v<pubspec version>` |
| `linux` | ubuntu-22.04 | `tool/package_linux.sh`, installer smoke test (install into a temporary HOME, launch under Xvfb, uninstall); artifact `linux` |
| `windows` | windows-latest | Rust + `tool/package_windows.ps1` (Inno Setup is preinstalled on the image, else installed with Chocolatey); artifact `windows` |
| `android` | ubuntu-latest | JDK 17, keystore from secrets if present (else debug-signed), `tool/build_android.sh`; artifacts `android` and `android-r8-mapping` |
| `release` | ubuntu-latest | tags only: `SHA256SUMS`, release notes (install instructions, signing status) + GitHub Release |

Secrets and variables are listed in [RELEASING.md](RELEASING.md#ci-secrets-and-variables).
