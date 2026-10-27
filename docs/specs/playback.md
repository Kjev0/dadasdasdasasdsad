# Spec: Playback engine (`lib/playback/**`, `test/playback/**`)

Priority #1 of the product: reliable audio. Must never stop because of UI
navigation; must survive window hide / app background (it lives outside the
widget tree).

## Implement
1. **Audio backend abstraction** `lib/playback/backend/audio_backend.dart`:
   an `AudioBackend` (factory for `AudioDeck`s + device/normalization
   capabilities) and `AudioDeck` (one player: open(PlayableSource, start,
   autoplay), play, pause, stop, seek, setVolume, setSpeed, preload/next for
   gapless, streams for position, buffered, duration, playing, processing
   state, completion, errors; dispose). Design it so the engine is fully
   testable with a `FakeAudioBackend` (put the fake in `test/playback/`).
2. **`MediaKitBackend`** (desktop: Linux/Windows) using `media_kit`
   (`MediaKit.ensureInitialized()` must be called once — expose a static
   `ensureInitialized()` that bootstrap calls). Use `PlayerConfiguration`
   appropriately (no video output: `vo=null`/audio-only; set `title`
   "Fermata"; buffer sizes sensible). Support: output device list and
   selection (`player.state.audioDevices`, `setAudioDevice`), speed,
   gapless via mpv `gapless-audio`/`prefetch-playlist` on a 2-item playlist or
   via deck preloading, ReplayGain (`replaygain`, `replaygain-preamp`,
   `replaygain-clip`) and optional EBU R128 `af=lavfi=[loudnorm=I=-16:TP=-1.5:LRA=11]`
   for `NormalizationMode.loudness`. Read the media_kit sources for the
   NativePlayer `setProperty` API.
3. **`JustAudioBackend`** (Android) using `just_audio` (ExoPlayer). Audio
   focus & interruptions via `audio_session` (`AudioSessionConfiguration.music()`):
   pause on focus loss, duck on transient-may-duck (setting
   `duckOnTransientInterruption`), resume after transient loss if it was
   playing and `resumeAfterInterruption`, pause on `becomingNoisyEventStream`
   when `pauseOnHeadphonesDisconnect`. Use `handleInterruptions: false` on the
   players so this policy is ours. Gapless via just_audio playlists
   (`setAudioSources`/ConcatenatingAudioSource equivalent in 0.10.x — read
   the package) or preloading. ReplayGain: apply as volume attenuation
   (never > 1.0) from `Track.replayGainTrackDb/AlbumDb` + preamp.
   HTTP headers from `PlayableSource.headers` must be passed.
4. **Queue model** `lib/playback/queue/`: pure-Dart, exhaustively unit-tested:
   play order vs original order, shuffle on/off preserving the current item
   (Fisher–Yates; manual "play next" items stay right after current),
   repeat off/all/one, next/previous semantics, enqueue, playNext, remove,
   move (drag-and-drop indices), clear(keepCurrent), skipToIndex, unique uids
   (uuid), origin labels.
5. **`PlaybackControllerImpl implements PlaybackController`**
   `lib/playback/playback_controller_impl.dart`. Constructor:
   `PlaybackControllerImpl({required AudioBackend backend, required StreamResolver resolver, required SettingsStore settings, required File stateFile, Future<List<Track>> Function(List<Track> recent)? smartQueueProvider, PlatformInfo? platform})`.
   * Snapshots: emit on every change and ~4 Hz while playing (throttled; no
     emission storm). `snapshot`/`queue` getters always current.
   * Events: TrackStarted, TrackEnded(listened excludes paused time,
     completed), PlaybackFailed(skipped), QueueEnded.
   * Resolution through `StreamResolver`; on `UnplayableTrackException` emit
     PlaybackFailed and, if `skipUnplayable`, advance (guard against infinite
     loops: stop after one full pass of failures). Show `errorMessage`.
   * Signed URLs: if `PlayableSource.expiresAt` has passed when resuming or
     seeking, re-resolve and continue at the same position.
   * Preload/prefetch the next item when `performance.preloadNext` is true
     (resolve its stream ~15 s before the end; gapless when `gapless` and no
     crossfade).
   * Crossfade (`crossfadeSeconds` > 0): dual-deck with equal-power volume
     ramps; disabled for repeat-one and for previews; never crossfade on a
     manual skip shorter than 1 s into a track (just switch).
   * Previous: restart if position > `previousRestartThresholdSeconds`.
   * Volume/speed persisted to settings (`playback.volume`, `playback.speed`)
     debounced; normalization updates when settings change.
   * Sleep timer: duration or end-of-track; fade out over the last 8 s when
     `sleepTimerFadeOut`; then pause (not stop) and clear timer.
   * Smart queue: when the queue ends and `playback.smartQueue`, call
     `smartQueueProvider` with recent tracks and append (origin
     `smart-queue`); otherwise emit QueueEnded and stop at the end.
   * Persistence: queue items, original order, current index, position,
     shuffle, repeat, origin label → `stateFile` JSON (atomic write, debounced
     ~2 s, plus on pause/track change and `saveState()`); restored in
     `init()` (paused, at saved position) when `restoreQueueOnStartup`; when
     `autoPlayOnStartup` start playing.
   * Output devices (desktop only) — persist `playback.outputDeviceId`; fall
     back to default when the saved device is gone.
   * `dispose()`: stop, persist, release backends.
6. **`StreamResolverImpl implements StreamResolver`**
   `lib/playback/stream_resolver_impl.dart`, constructor
   `StreamResolverImpl({required SourceRegistry sources, required DownloadManager downloads, required TrackLinkRepository links, required SettingsStore settings, Future<bool> Function()? isMetered})`.
   Order: verified download → local file (check it exists; else
   `fileMissing`) → source stream (respect `availability`; quality from
   settings, mobile quality when metered) → linked tracks in provider
   preference order (skip preview-only links unless nothing else, mark
   `isPreview`) → `UnplayableTrackException` with the most informative reason.
7. **Real-audio integration test** (Linux, headless): generate short WAV/FLAC
   files with ffmpeg (sine tones) in a temp dir during the test and play them
   through `MediaKitBackend` with mpv `ao=null` (no sound card in CI). Verify
   position advances, seek works, completion fires, next track starts,
   pause/resume. If media_kit cannot initialize inside `flutter test`, run it
   as `integration_test` under `xvfb-run flutter test integration_test/... -d linux`
   and document the command. Put it under `test/playback/` or
   `integration_test/playback_test.dart` (you own that file).

## Acceptance (write tests for each)
* Local file plays; play/pause/seek/next/previous work.
* Queue edits are reflected in `queueStream` immediately and in playback.
* Shuffle keeps current item; unshuffle restores original order position.
* Repeat one/all/off at queue end; previous-restart threshold.
* Unplayable item is skipped with an event; all-unplayable queue stops.
* State persists and restores across a simulated restart (new controller,
  same file).
* Sleep timer pauses; end-of-track mode pauses at the boundary.
* Crossfade ramps volumes (fake backend records volume calls).
* Stream re-resolution after expiry.
