# Fermata on Android

Native configuration of the Android app: identifiers, permissions (with the
user-facing explanations the onboarding / permission UI uses), background
playback behaviour and its limits, signing, building, installing and the
OAuth deep link.

The Dart side of background playback (audio handler, notification content,
lifecycle table, Danish rationale texts) is documented in
`docs/platform/ANDROID_BACKGROUND.md`.

| Item | Value | Where |
|---|---|---|
| Application ID / namespace | `app.fermata.player` | `android/app/build.gradle.kts` |
| Launcher label | Fermata | `AndroidManifest.xml` |
| minSdk | 24 (Android 7.0). The highest minimum among the plugins: app_links, audio_session, flutter_secure_storage, permission_handler_android, shared_preferences_android and url_launcher_android all require 24 | `build.gradle.kts` |
| targetSdk | 36 (Android 16): runtime behaviour | `build.gradle.kts` |
| compileSdk | 37: compile-time API visibility only. Required because permission_handler_android 14.1.0 declares `minCompileSdk 37` in its AAR metadata | `build.gradle.kts` |
| Activity | `app.fermata.player.MainActivity` extends `com.ryanheise.audioservice.AudioServiceActivity`, so the UI and the playback service share one cached Flutter engine and playback survives the activity being destroyed | `android/app/src/main/kotlin/app/fermata/player/MainActivity.kt` |
| Playback service | `com.ryanheise.audioservice.AudioService`, `foregroundServiceType="mediaPlayback"`, exported, `MediaBrowserService` intent filter | manifest |
| Media buttons | `com.ryanheise.audioservice.MediaButtonReceiver` (`MEDIA_BUTTON`) | manifest |
| Deep link | `fermata://oauth/<provider>` (handled by app_links) | manifest |
| Java / Kotlin target | 17 | `build.gradle.kts` |

## Permissions

"Normal" permissions are granted at install time and never prompt. Only the
two runtime permissions below show a system dialog, and Fermata asks for each
one only when the user reaches the feature that needs it.

| Permission | Kind | Why Fermata needs it |
|---|---|---|
| `INTERNET` | normal | Stream music, sign in to streaming services, fetch artwork and lyrics. |
| `ACCESS_NETWORK_STATE` | normal | Know when you are offline or on mobile data, so Fermata can pause downloads, honour "stream on Wi-Fi only" and show offline mode. |
| `WAKE_LOCK` | normal | Keep the CPU awake while music plays with the screen off. |
| `FOREGROUND_SERVICE` | normal | Keep playing after you leave the app, with the playback notification. |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | normal (Android 14+) | Required by Android 14+ to declare that this background service plays media. |
| `POST_NOTIFICATIONS` | **runtime**, Android 13+ | Show notifications such as "download finished" or playback errors. The playback controls notification is exempt on Android 13+ (it is a media-session notification), so playback, lock screen and Bluetooth controls work even if you deny this. |
| `READ_MEDIA_AUDIO` | **runtime**, Android 13+ | Find and play the music files stored on your device. Fermata only reads audio files; it cannot see your photos, videos or documents. |
| `READ_EXTERNAL_STORAGE` (`maxSdkVersion="32"`) | **runtime**, Android 7 to 12L | The same as above on Android 12L and older, where there is no audio-only permission. Not requested on Android 13+. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | normal (lets the app show a system dialog) | **Only when you turn it on in Fermata's settings.** Lets Fermata ask Android to stop "optimizing" its battery use, so that resuming from headphones or a car after a long pause keeps working on aggressive devices. Never requested at startup. |

Suggested UI copy (short form, for the permission sheet):

* **Notifications**: "Get notified when downloads finish or something goes
  wrong. Playback controls work without this."
* **Music on this device**: "Let Fermata find the songs stored on your phone.
  Fermata only reads audio files."
* **Unrestricted battery** (opt-in): "Lets Fermata resume from your headphones
  or car even after a long pause. Uses a little more battery while paused."

Deliberately **not** requested:

* `BLUETOOTH_CONNECT`: headset, Bluetooth and car buttons arrive through the
  MediaSession and need no Bluetooth permission. Headset connect/disconnect
  detection (`audio_session` device events) works without it.
* `RECORD_AUDIO`, location, `MANAGE_EXTERNAL_STORAGE`, `READ_MEDIA_IMAGES`.
  Album art is read from the audio files themselves. Folders picked with the
  system folder picker (Storage Access Framework) need no permission at all.
* Plugin-merged extras: the merged manifest gains only
  `ACCESS_NETWORK_STATE` (connectivity_plus, already declared) and the
  AndroidX-generated, non-exported `app.fermata.player.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`
  signature permission.

Google Play note on `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: Play restricts
this permission to apps whose core function breaks under Doze / App Standby
and may require a declaration or reject the app. If Fermata is published on
Play, either justify it (background music playback that must resume from
media buttons) or remove it and send users to
`Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`, which needs no
permission. Sideloaded builds are unaffected.

## Background playback: behaviour and honest limitations

How it works: while music plays, `AudioService` runs as a **foreground
service** of type `mediaPlayback` with a media-style notification
(artwork, title, artist, previous / play-pause / next). That keeps the process
at foreground priority, so Android does not kill it for memory or battery.
The MediaSession drives the lock screen, quick-settings media player,
Bluetooth / wired headset buttons, Android Auto and Wear OS.

| Situation | What happens |
|---|---|
| Home button, app switch, screen lock | Keeps playing. |
| Activity destroyed (rotation, memory pressure, "Don't keep activities") | Keeps playing; reopening the app re-attaches to the same engine. |
| Swiped away from Recents while **playing** | Keeps playing (notification stays). |
| Swiped away from Recents while **paused** | Playback stops and the notification goes away (the Dart handler's `onTaskRemoved` policy). |
| Paused for a while | By default the service leaves the foreground on pause (`androidStopForegroundOnPause`) so the notification can be swiped away. Android may then kill the paused process after some time; tapping play in the app restores the queue. |
| Notification swiped away (normally only possible while paused) | Playback stops. |
| **Force stop** (Settings > Apps > Fermata > Force stop) | Everything stops immediately. Android also blocks media buttons and other external triggers until the user opens Fermata again. Nothing an app can do about this. |
| Doze (screen off, idle, unplugged) | Does not stop an active foreground media-playback service. While paused and not in the foreground, Doze/App Standby can defer network access and background work. |

Limitations to communicate honestly:

* **Resuming from headphones or the car after a long pause (Android 12+).**
  Android 12+ restricts starting a foreground service from the background.
  User actions (notification buttons, lock screen, media buttons dispatched
  by the system) normally get a temporary exemption, but the audio_service
  README warns that returning a demoted service to the foreground can still
  throw `ForegroundServiceStartNotAllowedException` on some devices, and
  non-user triggers such as headset auto-resume are not exempt. Remedies,
  both user choices in Settings: keep the notification while paused (sets
  `androidStopForegroundOnPause = false`, takes effect after restarting the
  app), or allow unrestricted battery use (the opt-in permission above).
  Tapping the notification or opening the app always works.
* **OEM battery killers.** Some vendors kill foreground services that stock
  Android would keep, typically after the screen has been off for a while.
  Users have to exempt Fermata manually:
  * Xiaomi / Redmi / POCO (MIUI, HyperOS): enable *Autostart*, set *Battery
    saver* to *No restrictions*, and lock Fermata in Recents.
  * Samsung (One UI): Settings > Battery > *Background usage limits*: make
    sure Fermata is not in *Sleeping apps* / *Deep sleeping apps*, add it to
    *Never sleeping apps*, and turn off *Put unused apps to sleep* (or exempt
    Fermata); set the app's battery mode to *Unrestricted*.
  * Huawei / Honor: *App launch*: manage manually, allow all three toggles.
  * OnePlus / OPPO / realme / vivo: battery optimization *Don't optimize* /
    *Allow background activity*.
  * https://dontkillmyapp.com has current per-device steps; link it from the
    in-app help.
* **Bluetooth auto-resume** on headset connect only works while Fermata's
  process is alive (it listens for device changes in the app).

## Network security

`android:usesCleartextTraffic="false"` plus `res/xml/network_security_config.xml`:
HTTPS only, system CAs only. The single exception is cleartext to
`127.0.0.1` / `localhost`, which just_audio needs for its local proxy (used
for request headers such as `Authorization` on stream URLs, caching and
stream sources). Any `http://` URL from a provider will fail to load; this is
intentional.

## Backup

`android:allowBackup="false"` disables cloud backup.
`res/xml/data_extraction_rules.xml` also excludes all SharedPreferences from
Android 12+ device-to-device transfer. flutter_secure_storage keeps OAuth
tokens there, encrypted with Android Keystore keys that never leave the
device; restoring them elsewhere would fail with
`InvalidKeyException: Failed to unwrap key`. After moving to a new phone,
users reconnect their streaming accounts. The library database and
DataStore-backed settings are still transferred device-to-device.

## Building

```sh
source /opt/sdk/env.sh                 # CI/dev container only
flutter build apk --debug              # build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release            # build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release --split-per-abi   # one smaller APK per ABI
flutter build appbundle --release      # .aab for Play
```

Release builds run R8 (code shrinking and obfuscation) and resource
shrinking. `android/app/proguard-rules.pro` keeps the audio_service /
just_audio / audio_session / flutter_secure_storage plugin classes and the
media_kit JNI helper; media3 (ExoPlayer), androidx.media and package:jni ship
their own consumer rules. `res/raw/fermata_keep.xml` keeps all drawables,
because notification icons (`drawable/ic_stat_fermata`) are referenced only
by name from Dart. The R8 mapping for deobfuscating Java stack traces is at
`build/app/outputs/mapping/release/mapping.txt`; keep it with every release.

### APK size

Measured on 2026-10-27 (universal APKs: arm64-v8a, armeabi-v7a, x86_64;
native libraries are stored uncompressed and page-aligned, so the APK size
is close to the installed size):

| Build | Size |
|---|---|
| `app-debug.apk` | 195.6 MB (JIT engine + Vulkan validation layers) |
| `app-release.apk` | 74.8 MB |

Release native libraries per ABI (arm64-v8a): `libflutter.so` 11.8 MB,
`libapp.so` (Dart AOT) 3.3 MB, and about 9.7 MB that Android never uses:

* `libmpv.so` 6.2 MB + `libmediakitandroidhelper.so` 0.4 MB, from
  `media_kit_libs_audio` (Android uses just_audio, not media_kit). Fix in
  `pubspec.yaml`: depend on `media_kit_libs_linux` and
  `media_kit_libs_windows_audio` instead of the all-platform
  `media_kit_libs_audio`. That saves about 20 MB on the universal APK; the
  Dart side must then never call `MediaKit.ensureInitialized()` on Android.
* `libcnativeapi.so` 1.3 MB: `tray_manager` 0.8's native code, which its
  build hook also compiles for Android. There is no opt-out today.
* `libsqlite3.so` 1.75 MB: package `sqlite3`'s bundled SQLite (sqflite uses
  the system SQLite on Android). Only needed if `sqlite3` /
  `sqflite_common_ffi` is used on Android.

`flutter build apk --split-per-abi` produces one APK per ABI (about a third of
the universal size each) for sideloading; Play serves per-ABI splits from an
`.aab` automatically.

## Signing

Release signing is configured in `android/app/build.gradle.kts` and resolved
in this order:

1. `android/key.properties` (gitignored; template in
   `android/key.properties.example`):

   ```properties
   # storeFile: absolute, or relative to the android/ directory.
   # (.properties files have no inline comments: keep comments on their own line.)
   storeFile=/home/you/fermata-release.jks
   storePassword=...
   keyAlias=fermata
   keyPassword=...
   ```

2. Environment variables (for CI): `FERMATA_KEYSTORE_PATH`,
   `FERMATA_KEYSTORE_PASSWORD`, `FERMATA_KEY_ALIAS`, `FERMATA_KEY_PASSWORD`.
3. Neither present: the release APK is signed with the **debug key** so that
   `flutter build apk --release` still produces an installable APK, and Gradle
   prints `WARNING: No release signing configuration found ...`. Fine for local
   testing, never for distribution.

A partial configuration (a value missing, or the keystore file not found) is
a hard build error, so a misconfigured release is never silently
debug-signed.

Create the keystore once:

```sh
keytool -genkeypair -v -keystore ~/fermata-release.jks -storetype PKCS12 \
  -keyalg RSA -keysize 4096 -validity 10000 -alias fermata
```

Back up the keystore and both passwords somewhere safe. **If they are lost,
existing installs can never be updated in place**; users would have to
uninstall (losing their data) and reinstall. `key.properties`, `*.jks` and
`*.keystore` are gitignored in `android/.gitignore`; never commit them.

Certificate fingerprints (needed e.g. when registering an Android OAuth
client with a provider that pins the signing certificate):

```sh
keytool -list -v -keystore ~/fermata-release.jks -alias fermata
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

(`apksigner` lives in `$ANDROID_HOME/build-tools/<version>/`.)

## Installing and updating (sideload)

From a computer, with USB debugging enabled on the phone (Settings > About
phone > tap *Build number* 7 times, then Settings > System > Developer
options > *USB debugging*):

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk   # -r keeps app data on update
```

Directly on the phone: open the APK from Files or the browser. Since Android
8, "unknown sources" is a per-app permission. The first time, Android asks
to allow *Install unknown apps* for that app (Settings > Apps > Special app
access > Install unknown apps > Files / Chrome > Allow).

Updating rules (Android enforces these):

* The update must be signed with the **same certificate**. A debug-signed
  build and a release-signed build cannot replace each other
  (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`): uninstall first, which deletes
  app data.
* `versionCode` (the `+N` in `pubspec.yaml`'s `version: 1.0.0+N`) must not
  go down. `adb install -r -d` allows a downgrade only for debuggable builds.

## OAuth deep link

The OAuth redirect URI on Android is `fermata://oauth/<provider>`, for example
`fermata://oauth/soundcloud?code=...&state=...`. The intent filter on
`MainActivity` accepts scheme `fermata` with host `oauth` and any path.
`flutter_deeplinking_enabled=false` hands the link to app_links
(`AppLinks().uriLinkStream`) instead of Flutter's router.

Test without a provider:

```sh
adb shell am start -a android.intent.action.VIEW \
  -d "fermata://oauth/soundcloud?code=test\&state=abc" app.fermata.player
```

Launch mode: `MainActivity` keeps Flutter's default `singleTop`. When the
sign-in page is opened in the **external browser**
(`LaunchMode.externalApplication`), the redirect brings Fermata's existing
task forward and delivers the link to the running activity (`onNewIntent`
then app_links). With a **Custom Tab** (`LaunchMode.inAppBrowserView`), the
tab sits on top of `MainActivity` in Fermata's task, so a `singleTop`
activity is not on top. Android would then start a second `MainActivity`
above the tab, and both would share the one cached engine. So use the
external browser for OAuth, or switch the activity to `singleTask` if Custom
Tabs are required.

Package-visibility `<queries>` declare `https` VIEW intents and the Custom
Tabs service, so `canLaunchUrl` / `supportsLaunchMode` give correct answers
on Android 11+.
