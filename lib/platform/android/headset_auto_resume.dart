// AudioDeviceType is marked @experimental in audio_session 0.2.x but is the
// only way to tell headphones from other outputs in devicesChangedEventStream.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:logging/logging.dart';

import '../../core/contracts/playback.dart';
import '../../core/models/playback.dart';
import '../../settings/settings_store.dart';

final _log = Logger('platform.android.headset');

/// Audio route events needed by [HeadsetAutoResume]; abstracted so the
/// logic can be tested without platform channels.
abstract class AudioRouteEvents {
  /// Fires when audio is about to become "noisy" (headphones unplugged,
  /// Bluetooth output disconnected).
  Stream<void> get becomingNoisy;

  Stream<AudioDevicesChangedEvent> get devicesChanged;
}

/// [AudioRouteEvents] backed by the shared `audio_session` instance.
class AudioSessionRouteEvents implements AudioRouteEvents {
  AudioSessionRouteEvents(this._session);

  final AudioSession _session;

  @override
  Stream<void> get becomingNoisy => _session.becomingNoisyEventStream;

  @override
  Stream<AudioDevicesChangedEvent> get devicesChanged => _session.devicesChangedEventStream;
}

/// Output device types that count as "headphones" for auto-resume.
const headsetDeviceTypes = {
  AudioDeviceType.wiredHeadset,
  AudioDeviceType.wiredHeadphones,
  AudioDeviceType.bluetoothA2dp,
  AudioDeviceType.bluetoothLe,
  AudioDeviceType.usbAudio,
  AudioDeviceType.hearingAid,
};

/// Resumes playback when headphones (wired, USB or Bluetooth A2DP/LE) are
/// connected again shortly after they were disconnected while playing.
///
/// The becoming-noisy pause itself is done by the playback module; this
/// class only remembers that it happened. Playback resumes when all hold:
/// * setting `android.resumeOnHeadsetConnect` is on (read live),
/// * a headset-type *output* was added within [window] (5 min) of a
///   becoming-noisy event that interrupted active playback,
/// * playback is still paused and has a current item,
/// * the user did not resume or start playback manually in between.
class HeadsetAutoResume {
  HeadsetAutoResume({
    required this._playback,
    required this._settings,
    required this._events,
    this.window = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PlaybackController _playback;
  final SettingsStore _settings;
  final AudioRouteEvents _events;
  final DateTime Function() _now;

  /// How long after a noisy pause a reconnect still resumes.
  final Duration window;

  /// Grace period for the race between the noisy event and the pause: the
  /// playback module may already have paused when the event reaches us.
  static const _playingGrace = Duration(seconds: 3);

  final _subscriptions = <StreamSubscription<Object?>>[];
  DateTime? _noisyPauseAt;
  DateTime? _lastPlayingAt;
  bool _wasPlaying = false;

  /// True while a reconnect would resume playback (for tests/diagnostics).
  bool get armed {
    final at = _noisyPauseAt;
    return at != null && _now().difference(at) <= window;
  }

  void start() {
    if (_subscriptions.isNotEmpty) return;
    _wasPlaying = _playback.snapshot.playing;
    if (_wasPlaying) _lastPlayingAt = _now();
    _subscriptions
      ..add(_playback.snapshots.listen(_onSnapshot, onError: _onError))
      ..add(_events.becomingNoisy.listen((_) => _onNoisy(), onError: _onError))
      ..add(_events.devicesChanged.listen(_onDevicesChanged, onError: _onError));
  }

  void _onError(Object error, StackTrace st) => _log.warning('Audio route stream error', error, st);

  void _onSnapshot(PlaybackSnapshot s) {
    if (s.playing) {
      _lastPlayingAt = _now();
      // Playback (re)started after the noisy pause — by the user or by us.
      if (!_wasPlaying) _noisyPauseAt = null;
    }
    _wasPlaying = s.playing;
  }

  void _onNoisy() {
    final now = _now();
    final last = _lastPlayingAt;
    final wasPlaying = _playback.snapshot.playing || (last != null && now.difference(last) <= _playingGrace);
    if (!wasPlaying) return;
    _noisyPauseAt = now;
    _log.fine('Output became noisy during playback; waiting for a headset to reconnect');
  }

  Future<void> _onDevicesChanged(AudioDevicesChangedEvent event) async {
    final headset = event.devicesAdded.any((d) => d.isOutput && headsetDeviceTypes.contains(d.type));
    if (!headset || !armed) return;
    if (!_settings.current.android.resumeOnHeadsetConnect) return;
    final snapshot = _playback.snapshot;
    if (snapshot.playing || (snapshot.current ?? _playback.queue.current) == null) return;
    _noisyPauseAt = null;
    _log.info('Headset reconnected; resuming playback');
    try {
      await _playback.play();
    } catch (e, st) {
      _log.warning('Auto-resume failed', e, st);
    }
  }

  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }
}
