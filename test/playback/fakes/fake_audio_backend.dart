import 'dart:async';

import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/playback/backend/audio_backend.dart';

/// Record of one [FakeAudioDeck.open] call.
class OpenCall {
  OpenCall(this.source, this.start, this.autoplay, this.track);
  final PlayableSource source;
  final Duration start;
  final bool autoplay;
  final Track? track;

  String get uri => source.uri.toString();
}

/// In-memory [AudioBackend] for engine tests. Decks simulate playback with
/// timers (deterministic under `fakeAsync`).
class FakeAudioBackend implements AudioBackend {
  FakeAudioBackend({
    Map<String, Duration>? durations,
    this.defaultDuration = const Duration(seconds: 180),
    this.gapless = true,
    this.outputSelection = true,
    this.loudness = true,
    List<AudioOutputDevice>? devices,
  })  : durations = durations ?? {},
        devices = devices ??
            const [
              AudioOutputDevice(id: 'auto', name: 'System default', isDefault: true),
              AudioOutputDevice(id: 'pulse/usb-dac', name: 'USB DAC'),
            ];

  /// Media duration per URI (string form); [defaultDuration] otherwise.
  final Map<String, Duration> durations;
  final Duration defaultDuration;
  final bool gapless;
  final bool outputSelection;
  final bool loudness;
  List<AudioOutputDevice> devices;

  final decks = <FakeAudioDeck>[];

  /// `open()` throws for these URIs.
  final failOpen = <String>{};

  /// A fatal [DeckError] is emitted right after `open()` for these URIs.
  final errorAfterOpen = <String>{};

  bool initialized = false;
  bool disposed = false;
  NormalizationConfig normalization = const NormalizationConfig.off();
  final normalizationCalls = <NormalizationConfig>[];
  String? selectedDevice;
  final deviceCalls = <String?>[];

  final _devicesCtrl = StreamController<List<AudioOutputDevice>>.broadcast();
  final _interruptCtrl = StreamController<AudioInterruption>.broadcast();

  Duration durationOf(String uri) => durations[uri] ?? defaultDuration;

  void emitInterruption(AudioInterruption e) => _interruptCtrl.add(e);

  void setDevices(List<AudioOutputDevice> list) {
    devices = list;
    _devicesCtrl.add(list);
  }

  /// All volume values ever set on any deck, in order.
  List<double> get allVolumes => [for (final d in decks) ...d.volumes];

  /// The deck that is currently playing (or the last one that opened).
  FakeAudioDeck get activeDeck =>
      decks.firstWhere((d) => d.playing, orElse: () => decks.lastWhere((d) => d.source != null, orElse: () => decks.first));

  List<OpenCall> get allOpens => [for (final d in decks) ...d.opens];

  @override
  Future<void> init() async => initialized = true;

  @override
  AudioDeck createDeck() {
    final deck = FakeAudioDeck(this, decks.length);
    decks.add(deck);
    return deck;
  }

  @override
  bool get supportsSpeed => true;

  @override
  bool get supportsOutputDeviceSelection => outputSelection;

  @override
  bool get supportsLoudnessNormalization => loudness;

  @override
  Future<List<AudioOutputDevice>> outputDevices() async => devices;

  @override
  Stream<List<AudioOutputDevice>> get outputDevicesChanges => _devicesCtrl.stream;

  @override
  Future<void> setOutputDevice(String? deviceId) async {
    selectedDevice = deviceId;
    deviceCalls.add(deviceId);
  }

  @override
  Future<void> setNormalization(NormalizationConfig config) async {
    normalization = config;
    normalizationCalls.add(config);
  }

  @override
  Stream<AudioInterruption> get interruptions => _interruptCtrl.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    for (final d in decks) {
      await d.dispose();
    }
    unawaited(_devicesCtrl.close());
    unawaited(_interruptCtrl.close());
  }
}

class FakeAudioDeck implements AudioDeck {
  FakeAudioDeck(this.backend, this.index);

  final FakeAudioBackend backend;
  final int index;
  static const step = Duration(milliseconds: 50);

  PlayableSource? source;
  PlayableSource? preloaded;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _playing = false;
  DeckState _state = DeckState.idle;
  double volume = 1.0;
  double speed = 1.0;
  bool disposed = false;
  Timer? _clock;

  /// Simulates real backends that report a new position only a little
  /// after a seek/open.
  Duration positionLag = Duration.zero;

  final opens = <OpenCall>[];
  final volumes = <double>[];
  final seeks = <Duration>[];
  final preloads = <PlayableSource>[];
  int stopCount = 0;
  int pauseCount = 0;
  int playCount = 0;
  int clearPreloadCount = 0;

  final _positionCtrl = StreamController<Duration>.broadcast();
  final _bufferedCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration?>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _stateCtrl = StreamController<DeckState>.broadcast();
  final _completionsCtrl = StreamController<void>.broadcast();
  final _advancedCtrl = StreamController<void>.broadcast();
  final _errorsCtrl = StreamController<DeckError>.broadcast();

  void _setState(DeckState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void _setPlaying(bool p) {
    if (_playing == p) return;
    _playing = p;
    _playingCtrl.add(p);
    if (p) {
      _clock ??= Timer.periodic(step, (_) => _tick());
    } else {
      _clock?.cancel();
      _clock = null;
    }
  }

  void _tick() {
    final d = _duration;
    if (!_playing || d == null) return;
    _position += step * speed;
    if (_position >= d) {
      _position = d;
      _reachedEnd();
    }
  }

  void _reachedEnd() {
    final next = preloaded;
    if (next != null) {
      preloaded = null;
      source = next;
      _position = Duration.zero;
      _duration = backend.durationOf(next.uri.toString());
      _durationCtrl.add(_duration);
      _advancedCtrl.add(null);
      return;
    }
    _setPlaying(false);
    _setState(DeckState.completed);
    _completionsCtrl.add(null);
  }

  /// Test hook: jump the playback position (no seek recorded).
  void jumpTo(Duration position) => _position = position;

  /// Test hook: emit an error.
  void emitError(DeckError error) => _errorsCtrl.add(error);

  @override
  Future<void> open(PlayableSource source, {Duration start = Duration.zero, bool autoplay = true, Track? track}) async {
    opens.add(OpenCall(source, start, autoplay, track));
    final uri = source.uri.toString();
    this.source = source;
    preloaded = null;
    _setPlaying(false);
    _setState(DeckState.loading);
    if (backend.failOpen.contains(uri)) {
      _setState(DeckState.idle);
      this.source = null;
      throw StateError('cannot open $uri');
    }
    _duration = backend.durationOf(uri);
    _durationCtrl.add(_duration);
    _position = start;
    _setState(DeckState.ready);
    if (autoplay) _setPlaying(true);
    if (backend.errorAfterOpen.contains(uri)) {
      scheduleMicrotask(() => _errorsCtrl.add(DeckError('decoder failed for $uri')));
    }
  }

  @override
  Future<void> play() async {
    playCount++;
    if (source == null) return;
    if (_state == DeckState.completed) {
      _position = Duration.zero;
      _setState(DeckState.ready);
    }
    _setPlaying(true);
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    _setPlaying(false);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _setPlaying(false);
    source = null;
    preloaded = null;
    _position = Duration.zero;
    _duration = null;
    _setState(DeckState.idle);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    if (positionLag > Duration.zero) {
      Timer(positionLag, () => _position = position);
    } else {
      _position = position;
    }
    if (_state == DeckState.completed) _setState(DeckState.ready);
  }

  @override
  Future<void> setVolume(double gain) async {
    volume = gain;
    volumes.add(gain);
  }

  @override
  Future<void> setSpeed(double speed) async => this.speed = speed;

  @override
  bool get supportsGapless => backend.gapless;

  @override
  Future<void> preloadNext(PlayableSource source, {Track? track}) async {
    preloads.add(source);
    preloaded = source;
  }

  @override
  Future<void> clearPreloaded() async {
    clearPreloadCount++;
    preloaded = null;
  }

  @override
  bool get hasPreloaded => preloaded != null;

  @override
  Duration get position => _position;

  @override
  Duration get bufferedPosition => _duration ?? Duration.zero;

  @override
  Duration? get duration => _duration;

  @override
  bool get playing => _playing;

  @override
  DeckState get state => _state;

  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;

  @override
  Stream<Duration> get bufferedPositionStream => _bufferedCtrl.stream;

  @override
  Stream<Duration?> get durationStream => _durationCtrl.stream;

  @override
  Stream<bool> get playingStream => _playingCtrl.stream;

  @override
  Stream<DeckState> get stateStream => _stateCtrl.stream;

  @override
  Stream<void> get completions => _completionsCtrl.stream;

  @override
  Stream<void> get advancedToPreloaded => _advancedCtrl.stream;

  @override
  Stream<DeckError> get errors => _errorsCtrl.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    _clock?.cancel();
  }
}
