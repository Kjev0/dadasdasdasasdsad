# Android: background playback, media session and permissions

This is the Dart side of Android background playback
(`lib/platform/android/`). Manifest entries, `MainActivity`
(`AudioServiceActivity`), the service/receiver declarations and the
notification icon `drawable/ic_stat_fermata` are described in
[ANDROID.md](ANDROID.md).

## How it works

* `AndroidMediaSession.start()` runs once during bootstrap, after the
  `PlaybackController` restored the queue. It calls `AudioService.init`
  with Fermata's configuration and registers `FermataAudioHandler`.
* `MainActivity` extends `AudioServiceActivity`, so the activity and the
  `AudioService` foreground service share one Flutter engine. Closing or
  destroying the activity does not stop the Dart isolate; the
  `PlaybackController` keeps running inside the service.
* The `PlaybackController` is the single source of truth. The handler only
  mirrors snapshots and the queue into the MediaSession (notification, lock
  screen, Bluetooth/AVRCP, Wear OS, Android Auto) and forwards every command
  back to the controller.
* The service is in the **foreground** (ongoing notification, cannot be
  killed for memory) while `playing` is true. When playback pauses, it leaves
  the foreground if *Stop foreground on pause* is on (default). When the
  controller reports `idle` (stop), audio_service stops the service and
  removes the notification.
* Position is not streamed: the session publishes a new state only on real
  changes (play/pause, buffering, seek, track change, shuffle/repeat, speed,
  like) and the system extrapolates the position. The controller's 4 Hz ticks
  never reach the platform channel.
* Only a window of the queue (10 before, 50 after the current track) is
  published to the session, so huge queues never flood the platform channel
  or trigger artwork downloads for thousands of tracks.

### Notification and controls

| Element | Value |
| --- | --- |
| Channel | `app.fermata.player.playback`, name "Playback" / "Afspilning" |
| Small icon | `drawable/ic_stat_fermata`, accent colour `#E9B44C` |
| Buttons | previous · play/pause · next (compact view shows all three) |
| Like button | heart custom action, **only** when the like drawables are bundled (see below) |
| Seek bar | enabled (needs the track duration; shown once the engine knows it) |
| Artwork | `http(s)`, `file://` and `content://` URIs, downscaled to 512×512 |
| Artwork preloading | on, except in Battery saver / Data saver or with artwork prefetch off |
| Fast-forward / rewind | ±15 s (Wear OS, cars, some lock screens) |

Like button: pass `LikeControlIcons(liked: 'drawable/ic_fermata_favorite',
notLiked: 'drawable/ic_fermata_favorite_border')` to
`AndroidMediaSession.start` once those two white 24 dp drawables exist in
`android/app/src/main/res/drawable*`. A missing drawable would break the
notification, so the button is omitted by default.

### Headset, Bluetooth and car buttons

| Input | Action |
| --- | --- |
| Single press (headset button / play-pause key) | play / pause |
| Double press | next track |
| Triple press | previous track (restarts the track when > 3 s in) |
| Dedicated next / previous keys (Bluetooth, car) | next / previous immediately |
| Fast-forward / rewind keys | ±15 s |

audio_service delivers each press of the single headset button separately
(it overrides the framework's `onMediaButtonEvent`, which also disables
Android's own double-tap handling), so Fermata counts presses itself: presses
within 400 ms form one gesture; a single press therefore acts after ~0.4 s.

### Headset auto-resume (opt-in)

Setting *Resume when headphones connect* (`android.resumeOnHeadsetConnect`).
When headphones are unplugged or a Bluetooth output disconnects while
playing, the playback module pauses ("becoming noisy"). If a wired,
USB, Bluetooth A2DP/LE headset or hearing aid output is connected again within
**5 minutes** and playback is still paused, Fermata resumes. Starting playback
manually in between cancels it. The setting is read at the moment of the
reconnect, so toggling it applies immediately.

### Android Auto, Wear OS, Assistant and media resumption

* Browse tree: **Recently played**, **Playlists** (each playlist), **Favorites**.
  Picking a track queues its folder starting at that track. Only tracks that
  can be played in the app are listed; lists are capped at 300 entries.
* Voice/search ("play Coldplay on Fermata") searches the local library; an
  empty request plays the favorites shuffled, or recently played.
* Media resumption card (Android 11+): shows the current queue item, or the
  most recently played track; *play* resumes the restored queue.

## Lifecycle behavior

| Situation | While playing | While paused |
| --- | --- | --- |
| Leave the app (Home, back gesture) | Keeps playing; notification stays. | Notification stays (swipeable when *Stop foreground on pause* is on). |
| Screen lock | Keeps playing; lock-screen controls and artwork. | Lock-screen controls remain while the session exists. |
| Switch to another app | Keeps playing. Another app taking audio focus (call, video, navigation) pauses or ducks it; that is handled by the playback module. | No change. |
| Swipe Fermata away from Recents | **Keeps playing**; the notification stays and reopens the app. | **Stops**: the queue and position are saved, the service stops, the notification disappears. Reopening the app restores the queue. |
| Notification swiped away | Not possible while playing (foreground notification). | Stops playback and the service (queue kept). Only possible when *Stop foreground on pause* is on. |
| Force stop (Settings → Apps → Force stop) | Everything stops immediately; Android gives the app no callback. The queue is as of the last automatic save. | Same. |
| Headphones unplugged / Bluetooth disconnects | Pauses (playback module). Optionally resumes on reconnect within 5 min. | — |
| Doze (screen off, device idle) | Keeps playing: the app runs a foreground service, which Android's power-management rules list as having no network restriction, so streaming continues (local files and downloads are unaffected anyway). Aggressive OEM variants of Doze are covered under "Limitations". | The service is not in the foreground: network access is deferred to maintenance windows and Android may stop the process during long idle periods. Pressing play (notification, headset, app) restores the queue. |
| OEM battery killers (Xiaomi, Huawei, Samsung, OnePlus, …) | Some vendors kill even foreground services; see "Limitations". | Paused services are killed sooner on these devices. |
| Process killed while paused, then media button | Android may restart the app in the background; `main()` initialises the session and the restored queue resumes. | — |

### "Stop foreground on pause" applies after restart

`AudioServiceConfig.androidStopForegroundOnPause` is read only once, in
`AudioService.init` at app start (audio_service cannot be re-configured in a
running process). The settings UI must therefore label this setting
**"Takes effect after restarting Fermata"** and can show a hint while
`AndroidMediaSession.restartRequiredForSettings` is true (it is also true when
the performance mode changed artwork preloading).

* **On (default)**: while paused the notification can be swiped away and the
  service may be stopped by Android. Saves battery; best practice.
* **Off**: the notification stays while paused and the service keeps its
  foreground priority, so resuming from a headset or car after a long pause is
  more reliable. Costs a little battery.

## Permission rationale texts

Show these before the system prompt. All permissions are optional;
playback, the media notification, the lock screen and Bluetooth controls work
without any of them.

### Notifications (Android 13+, `POST_NOTIFICATIONS`)

* **EN** — *Allow notifications?* Fermata can tell you when downloads finish
  or when something needs your attention. Playback controls in the
  notification shade work even if you say no.
* **DA** — *Tillad notifikationer?* Fermata kan give besked, når downloads er
  færdige, eller når noget kræver din opmærksomhed. Afspilningsknapperne i
  notifikationspanelet virker, selv hvis du siger nej.

Below Android 13 there is no prompt: notifications are on unless the user
turned them off, in which case the app settings must be opened
(`AndroidSystemHelper.openAppSettings`).

### Music on this device (`READ_MEDIA_AUDIO`, Android 12L and older: storage)

* **EN** — *Find music on this device?* Fermata needs access to your audio
  files to add them to your library. Only audio is read; nothing is uploaded.
* **DA** — *Find musik på enheden?* Fermata skal have adgang til dine
  lydfiler for at føje dem til dit bibliotek. Der læses kun lyd, og intet
  bliver uploadet.

If the user denied it permanently, explain and offer *Open settings*:
* **EN** — Access to music files is turned off. You can turn it on in
  Fermata's app settings under Permissions.
* **DA** — Adgang til musikfiler er slået fra. Du kan slå den til under
  Tilladelser i Fermatas appindstillinger.

### Unrestricted battery use (opt-in only)

Requested only when the user turns it on in Settings → Background playback;
never at startup.

* **EN** — *Allow Fermata to run without battery restrictions?* This helps
  Fermata resume from your headphones or car after a long pause, and stops
  some phones from closing it in the background. It can use a little more
  battery while paused.
* **DA** — *Tillad Fermata at køre uden batteribegrænsninger?* Det hjælper
  Fermata med at fortsætte fra dine hovedtelefoner eller din bil efter en
  lang pause og forhindrer nogle telefoner i at lukke appen i baggrunden. Det
  kan bruge lidt mere strøm, mens musikken er sat på pause.

## Limitations (honest)

* **Resuming from the background on Android 12+.** When the service left the
  foreground on pause, Android 12+ only lets it return to the foreground from
  the background in response to the user (notification, media buttons,
  lock screen). Headset auto-resume is triggered by a device connection, not
  by the user, so on some devices it is blocked unless *Unrestricted battery*
  is allowed or *Stop foreground on pause* is off.
* **OEM battery managers** (MIUI/HyperOS, EMUI, One UI "deep sleeping apps",
  ColorOS, …) may kill the app even while playing. Fermata cannot override
  this; the user has to exempt the app (Autostart / Unrestricted battery /
  "Don't optimise"). See [ANDROID.md](ANDROID.md) for per-vendor steps and
  dontkillmyapp.com.
* **Force stop** cannot be intercepted; state is as of the last automatic
  save (the playback module saves regularly).
* **Single-press latency.** Single presses of the headset button act after
  ~400 ms because double/triple presses must be distinguished.
* **Queue window.** Android Auto and the system queue view show at most
  61 entries around the current track; the full queue is in the app.
* **Queue edits from session clients** are limited: removing entries and
  "play next" / "add to queue" work; reordering or replacing the whole queue
  from a car or watch is ignored (the in-app queue is authoritative).
* **Artwork that needs request headers** is passed by URL only; providers
  that require auth headers for artwork show no notification artwork.
* **Download notifications are not implemented on Android in this build**
  (`AndroidNotifier.isSupported == false`, the UI shows in-app messages).
  Enabling them needs `flutter_local_notifications`, which requires core
  library desugaring in `android/app/build.gradle.kts`
  (`isCoreLibraryDesugaringEnabled = true` and
  `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`),
  compiles a native C++/WinRT library into the Windows build, and adds a
  second Linux notification path. Reserved channel id:
  `app.fermata.player.downloads`, small icon `ic_stat_fermata`.
