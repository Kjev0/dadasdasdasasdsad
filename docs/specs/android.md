# Spec: Android media session & system helpers (`lib/platform/android/**`, `test/platform/android/**`)

Goal: playback continues when the user leaves the app, locks the screen or
switches apps; a persistent media notification with artwork/title/artist and
controls; lock-screen and Bluetooth/headset button control.

The native side (manifest, `AudioServiceActivity`, service/receiver
declarations, notification small icon `drawable/ic_stat_fermata`) is handled
by another agent; you write the Dart side. Read the audio_service 0.18.19
README and example in the pub cache carefully.

## Implement
1. **`FermataAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler`**
   adapting the app-wide `PlaybackController` (contract in
   `lib/core/contracts/playback.dart`) — the controller is the source of
   truth; the handler only mirrors and forwards:
   * `mediaItem` from the current `QueueItem` (id = queue uid, title, artist
     line, album, duration, `artUri` http(s) or `file://` — for content that
     needs headers, still pass the URL; `extras` with track id/source).
   * `queue` from `QueueState`.
   * `playbackState`: controls [skipToPrevious, play/pause, skipToNext, and a
     custom "like/unlike" action using a heart drawable if available — only
     add custom actions whose drawables exist; otherwise omit],
     `androidCompactActionIndices: [0,1,2]`, systemActions {seek, seekForward,
     seekBackward, skipToQueueItem, setShuffleMode, setRepeatMode,
     setSpeed}, processingState mapping from `PlayerStatus`, `playing`,
     `updatePosition`, `bufferedPosition`, `speed`, `queueIndex`,
     shuffle/repeat modes. Update at state changes only (audio_service
     extrapolates position) — do not spam updates at 4 Hz.
   * Forward play, pause, stop, seek, skipToNext/Previous, skipToQueueItem,
     setShuffleMode, setRepeatMode, setSpeed, fastForward/rewind (±15 s),
     `onTaskRemoved` (keep playing if playing; stop if paused — document),
     `onNotificationDeleted` (stop), `click(MediaButton)` for headset
     single/double/triple press (play/pause, next, previous) — audio_service
     handles the default mapping; verify and keep it.
   * Android Auto / media browser (optional but valuable): `getChildren` for
     root → [Recently played, Playlists, Favorites] using repositories passed
     in the constructor; `playFromMediaId`.
2. **`AndroidMediaSession`** — a facade with
   `static Future<AndroidMediaSession> start({required PlaybackController playback, required SettingsStore settings, TrackRepository? tracks, PlaylistRepository? playlists, HistoryRepository? history, FavoritesRepository? favorites})`
   calling `AudioService.init` with `AudioServiceConfig(androidNotificationChannelId: 'app.fermata.player.playback', androidNotificationChannelName: 'Playback', androidNotificationIcon: 'drawable/ic_stat_fermata', androidStopForegroundOnPause: settings.android.stopForegroundOnPause, notificationColor: Color(0xFFE9B44C), preloadArtwork: !batterySaver/!dataSaver, artDownscaleWidth/Height: 512, fastForwardInterval/rewindInterval: 15 s)`.
   Note `androidStopForegroundOnPause` is read at init — document that the
   setting applies after restart, and show it that way.
   Must be a no-op on non-Android platforms.
3. **Headset auto-resume** (setting `android.resumeOnHeadsetConnect`): use
   `audio_session`'s `devicesChangedEventStream`; when a headset/Bluetooth A2DP
   output is added within 5 minutes of a noisy-pause, resume. (The
   becoming-noisy pause itself is handled by the playback module.)
4. **`AndroidSystemHelperImpl implements AndroidSystemHelper`** using
   `permission_handler` + `device_info_plus`: notification permission
   (Android 13+), audio library permission (`Permission.audio` on 33+,
   `Permission.storage` below), battery-optimization status/request
   (`Permission.ignoreBatteryOptimizations`, only when the user opts in),
   `openAppSettings`. Non-Android: `isSupported == false`, safe defaults.
5. **`AndroidNotifier implements SystemNotifier`** for "download finished"
   notifications. Only if feasible without a new heavy dependency: you may
   `flutter pub add flutter_local_notifications` (read its README for
   Android setup; any manifest changes needed must be listed in your report
   for the lead — do not edit android/ yourself). Channel
   `app.fermata.player.downloads`, small icon `ic_stat_fermata`.
   If you decide against it, implement `isSupported == false` and explain.
6. Tests: unit-test the handler mapping with a fake PlaybackController
   (state → PlaybackState/MediaItem mapping, controls, compact indices,
   commands forwarded, no update storm). audio_service platform channels
   cannot run in unit tests — test pure mapping functions extracted into
   their own file.
7. `docs/platform/ANDROID_BACKGROUND.md`: lifecycle behavior table
   (background, screen lock, app switch, swipe from recents while playing /
   paused, notification dismissed, force-stop, OEM battery killers, Doze),
   permission rationale texts (EN + DA), honest limitations.
