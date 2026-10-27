# Playback engine (`lib/playback/`)

Reliable audio for Fermata. The engine is a plain Dart service created once in
`bootstrap.dart`; it lives outside the widget tree, so page navigation, window
hide (tray) or app backgrounding never stop playback. Platform adapters
(Android `audio_service`, MPRIS, SMTC, tray, hotkeys) observe
`snapshots`/`queueStream`/`events` and call the transport methods.

## Public API (`package:fermata/playback/playback.dart`)

| Class | Purpose |
|---|---|
| `PlaybackControllerImpl implements PlaybackController` | Queue, transport, crossfade/gapless, normalization, sleep timer, interruptions, persistence. |
| `StreamResolverImpl implements StreamResolver` | Download → local file → source stream → linked tracks. |
| `AudioBackend` / `AudioDeck` | Backend abstraction (one deck = one player; the engine uses two for crossfades). |
| `MediaKitBackend` | Linux/Windows backend on libmpv (`media_kit`). |
| `JustAudioBackend` | Android backend on ExoPlayer (`just_audio` + `audio_session`). |
| `createPlatformAudioBackend(PlatformInfo)` | Picks the right backend. |
| `PlaybackTuning` | Timing constants (defaults are production values). |
| `smartQueueOrigin` | `'smart-queue'` origin of items appended by the smart queue. |

Constructors:

```dart
PlaybackControllerImpl({
  required AudioBackend backend,
  required StreamResolver resolver,
  required SettingsStore settings,
  required File stateFile,
  Future<List<Track>> Function(List<Track> recent)? smartQueueProvider,
  PlatformInfo? platform,
  PlaybackTuning tuning = const PlaybackTuning(),   // tests only
  QueueStateStore? stateStore,                      // tests only
  DateTime Function()? now,                         // tests only
  math.Random? random,                              // tests only
})

StreamResolverImpl({
  required SourceRegistry sources,
  required DownloadManager downloads,
  required TrackLinkRepository links,
  required SettingsStore settings,
  Future<bool> Function()? isMetered,
})

MediaKitBackend({PlayerConfiguration configuration = MediaKitBackend.defaultConfiguration,
                 Map<String, String> extraMpvOptions = const {}})
JustAudioBackend({AudioLoadConfiguration? loadConfiguration})
```

## Bootstrap wiring (exact order)

```dart
import 'package:fermata/playback/playback.dart';

// 1. First thing on desktop, before any Player exists:
if (platform.isDesktop) MediaKitBackend.ensureInitialized();

// ... settings, http, repositories (links), sources registry, downloads ...

// 2. Stream resolver (needs sources, downloads, links, settings).
final streamResolver = StreamResolverImpl(
  sources: sources,
  downloads: downloads,
  links: links,
  settings: settings,
  isMetered: () async {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.mobile) &&
        !r.contains(ConnectivityResult.wifi) &&
        !r.contains(ConnectivityResult.ethernet);
  },
);

// 3. Playback controller (restores the queue in init()).
late final RecommendationService recommendations; // created later (discovery)
final playback = PlaybackControllerImpl(
  backend: createPlatformAudioBackend(platform),
  resolver: streamResolver,
  settings: settings,
  stateFile: File(p.join(paths.supportDir.path, 'playback_state.json')),
  smartQueueProvider: (recent) => recommendations.smartQueueContinuation(recent),
  platform: platform,
);
await playback.init();

// On explicit Quit (AppLifecycleController.quit): await playback.dispose();
```

`init()` configures the audio session (Android), applies normalization,
selects the saved output device (desktop) and restores the saved queue
(paused, at the saved position, nothing loaded until `play()`), or starts
playing when `autoPlayOnStartup` is on. History recording should listen to
`events` for `TrackEnded` (its `listened` excludes paused time).

## Behaviour summary

* **Snapshots** are emitted on every state change (coalesced per event-loop
  turn) and at ~4 Hz while playing; `snapshot`/`queue` getters are always
  current. `errorMessage` carries a localizable code: an
  `AvailabilityReason` (e.g. `region_restricted`) or a `FermataException.code`
  (`playback_error` for decoder/stream failures).
* **Events:** `TrackStarted`, `TrackEnded(listened, completed)`,
  `PlaybackFailed(skipped)`, `QueueEnded`.
* **Queue:** play order vs original order; Fisher–Yates shuffle keeps the
  current item first and manually added upcoming items right after it;
  unshuffle restores the original order at the current item. Repeat
  off/all/one (repeat-one replays on natural end; manual next moves on).
  `moveQueueItem(from, to)` uses list semantics (`to` = final index; adjust
  `ReorderableListView`'s `newIndex` when it is greater than `oldIndex`).
  Editing an empty or ended queue makes the first new item current (paused).
* **Failures:** `UnplayableTrackException` (or a deck that cannot open/decode
  the file) emits `PlaybackFailed`; with `skipUnplayable` the engine moves on,
  stopping after one full pass of failures. A remote stream that dies
  mid-way is re-resolved once and continued at the same position.
* **Signed URLs:** when `expiresAt` has passed (10 s safety margin), resume
  and seek re-resolve and continue at the same position.
* **Prefetch/gapless:** with `performance.preloadNext` the next item is
  resolved ~15 s before the end; with `gapless` and no crossfade it is queued
  on the deck for a seamless transition.
* **Crossfade:** dual-deck equal-power ramps (50 ms steps). Disabled for
  repeat-one, previews and "sleep at end of track"; manual skips crossfade only
  when ≥ 1 s into the track; any manual action finishes a running fade.
* **Volume:** the slider is perceptual (cubic curve, same as mpv); decks get a
  linear gain. Volume/speed are written to `playback.volume/speed` after a
  500 ms debounce. Normalization follows settings live.
* **Sleep timer:** duration (fade over the last 8 s when `sleepTimerFadeOut`,
  then pause — not stop — and clear) or end of track (fades the last 8 s,
  pauses at the boundary with the next item ready).
* **Smart queue:** at queue end with `playback.smartQueue`, the provider gets
  up to 20 recent tracks; results are appended with origin `smart-queue`.
  Otherwise `QueueEnded` and stop.
* **Persistence:** queue items, original order, index, position, shuffle,
  repeat and origin label → `stateFile` (atomic temp+rename, serialized
  writes). Debounced 2 s after edits, immediately on pause/track change/
  `saveState()`/`dispose()`, and every 10 s while playing.
* **Interruptions (Android):** pause on focus loss; duck to 30 % on
  "may duck" (`duckOnTransientInterruption`), otherwise pause; resume after a
  transient loss when it was playing and `resumeAfterInterruption`; pause on
  becoming-noisy when `pauseOnHeadphonesDisconnect`. A user transport action
  during an interruption cancels the automatic resume.
* **Output devices (desktop):** `outputDevices()`/`setOutputDevice(id)`;
  persisted in `playback.outputDeviceId` (null = default). A missing saved
  device falls back to the default (setting kept) and is re-selected when it
  reappears.

## Platform notes

* **Linux/Windows (`MediaKitBackend`)**: `vo=null`/`vid=no`, title and
  PulseAudio client name "Fermata", 16 MB demuxer buffer per deck,
  `cache-on-disk=no` (stream audio never touches disk), ffmpeg HTTP reconnect.
  Gapless = 2-item mpv playlist (`gapless-audio=yes`, `prefetch-playlist=yes`).
  ReplayGain via `replaygain`, `replaygain-preamp`, `replaygain-clip=yes`;
  loudness via `af=lavfi=[loudnorm=I=-16:TP=-1.5:LRA=11]`. mpv sets
  `eof-reached` briefly before advancing a playlist, so completions are
  debounced (750 ms) around gapless transitions.
* **Android (`JustAudioBackend`)**: `AudioSessionConfiguration.music()`,
  players with `handleInterruptions: false`, `useProxyForRequestHeaders:
  false` (headers go to ExoPlayer natively; no cleartext proxy needed).
  ReplayGain is applied as attenuation only (never above 1.0); EBU R128 is not
  available (falls back to track ReplayGain). No output-device selection.

## Tests

* `flutter test test/playback` — unit/engine tests with `FakeAudioBackend`
  under `fake_async`, resolver tests, and real-audio libmpv tests
  (`media_kit_backend_test.dart`, generated sine tones, `ao=null`; skipped
  automatically without Linux/ffmpeg/libmpv).
* `xvfb-run -a flutter test integration_test/playback_test.dart -d linux` —
  the same engine on the real Linux embedder (gapless, dual-deck crossfade,
  restart). Requires `build/linux/x64/debug` to be configured with the
  default install prefix (delete its `CMakeCache.txt` if another tool
  configured `CMAKE_INSTALL_PREFIX`).

## Known limitations

* Gapless transitions on mpv need the next item's stream before the end;
  with `performance.preloadNext` off there is a short gap.
* Repeat-one replays by re-opening the same stream (not sample-accurate).
* Shuffle does not reshuffle when repeat-all wraps.
* The loudness filter target is fixed (−16 LUFS); `preampDb` applies to
  ReplayGain modes only.
