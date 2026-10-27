# `lib/platform/android` — Android media session & system helpers

Background playback, media notification, lock screen, Bluetooth/headset
buttons, Android Auto / Wear OS browsing, headset auto-resume, permissions.
Behavior and lifecycle: [`docs/platform/ANDROID_BACKGROUND.md`](../../../docs/platform/ANDROID_BACKGROUND.md).

Import everything from `package:fermata/platform/android/android_platform.dart`.

## Public API

| Class | Role |
| --- | --- |
| `AndroidMediaSession` | Facade. `static Future<AndroidMediaSession> start({required PlaybackController playback, required SettingsStore settings, TrackRepository? tracks, PlaylistRepository? playlists, HistoryRepository? history, FavoritesRepository? favorites, PlatformInfo? platform, LikeControlIcons? likeIcons, AudioRouteEvents? routeEvents})`. No-op (inactive) on non-Android; never throws. Getters `isActive`, `handler`, `headsetAutoResume`, `stopForegroundOnPause`, `restartRequiredForSettings`; `dispose()`. |
| `FermataAudioHandler` | `BaseAudioHandler with QueueHandler, SeekHandler` adapting `PlaybackController`. Created by `AndroidMediaSession`; constructor `FermataAudioHandler({required PlaybackController playback, MediaLibraryBrowser? browser, FavoritesRepository? favorites, TrackRepository? tracks, LikeControlIcons? likeIcons, MediaSessionLabels labels, Duration seekInterval, Duration multiPressWindow, TimerFactory? timerFactory, DateTime Function()? now, int queueWindowBefore, int queueWindowAfter})`. |
| `HeadsetAutoResume` | Resume on headset reconnect within 5 min of a noisy pause. `HeadsetAutoResume({required PlaybackController playback, required SettingsStore settings, required AudioRouteEvents events, Duration window, DateTime Function()? now})`, `start()`, `dispose()`. |
| `AndroidSystemHelperImpl implements AndroidSystemHelper` | Permissions + battery optimization. `AndroidSystemHelperImpl({PlatformInfo? platform, PermissionGateway? permissions, SdkIntReader? sdkInt})`. |
| `AndroidNotifier implements SystemNotifier` | `const AndroidNotifier()`; `isSupported == false` in this build (see below). |
| `MediaLibraryBrowser` | Browse tree / search for Auto, Wear, Assistant. |
| `MediaButtonClickDetector` | Single/double/triple press detection. |
| `media_session_mapping.dart` | Pure mapping functions (`playbackStateFor`, `mediaItemForQueueItem`, `processingStateFor`, `shouldPublishState`, `QueueWindow`, …). |
| `buildAudioServiceConfig(AppSettings, {labels})` | The `AudioServiceConfig` (channel, icon, colour, stop-foreground, artwork, ±15 s). |

## Bootstrap wiring

Order: after `settings`, repositories and the `PlaybackController`
(`await playback.init()` restores the queue), before `runApp`.

```dart
import 'package:fermata/platform/android/android_platform.dart';

// ...after `await playback.init();`
final androidSession = await AndroidMediaSession.start(
  playback: playback,
  settings: settings,
  tracks: tracks,
  playlists: playlists,
  history: history,
  favorites: favorites,
  platform: platform,
  // likeIcons: const LikeControlIcons(
  //   liked: 'drawable/ic_fermata_favorite',
  //   notLiked: 'drawable/ic_fermata_favorite_border',
  // ), // only once these drawables are bundled
);
final AndroidSystemHelper androidSystem = AndroidSystemHelperImpl(platform: platform);
final SystemNotifier notifier = platform.isAndroid ? const AndroidNotifier() : desktopNotifier;

// On explicit Quit (AppLifecycleController.quit):
//   await playback.stop(); await playback.saveState();
//   await androidSession.dispose();
```

`androidSession` is not part of `AppServices`; keep a reference in bootstrap
(or the lifecycle controller) for `dispose()` and for the settings UI's
"applies after restart" hint (`restartRequiredForSettings`).

## Platform notes

* Only `AndroidMediaSession.start` touches audio_service / audio_session, and
  only on Android. `AndroidSystemHelperImpl` returns safe defaults without
  plugin calls elsewhere.
* `AudioService.init` can run once per process; `start()` returns the
  running session on repeated calls.
* `androidStopForegroundOnPause` is read at start only → the setting applies
  after restart.
* Strings for the session (button labels, channel name, browse folders) are
  in `MediaSessionLabels` (EN/DA) because the session can exist before any
  widget/`AppLocalizations`.

## Known limitations

See "Limitations" in `docs/platform/ANDROID_BACKGROUND.md`. In short:
download notifications are not implemented on Android
(`flutter_local_notifications` would need gradle desugaring + a Windows
native build); the like button needs drawables the branding step must add;
headset auto-resume can be blocked by Android 12+ background-start rules
unless battery optimization is disabled or the service stays in the
foreground while paused.
