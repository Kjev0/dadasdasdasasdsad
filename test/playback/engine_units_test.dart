import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart' as session;
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/playback/backend/audio_backend.dart';
import 'package:fermata/playback/backend/just_audio_backend.dart';
import 'package:fermata/playback/backend/media_kit_backend.dart';
import 'package:fermata/playback/backend/platform_audio_backend.dart';
import 'package:fermata/playback/engine/gain.dart';
import 'package:fermata/playback/engine/interruption_policy.dart';
import 'package:fermata/playback/engine/listen_clock.dart';
import 'package:fermata/playback/queue/queue_state_store.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;

import 'fakes/fakes.dart';

void main() {
  group('Gain', () {
    test('user volume uses a cubic curve', () {
      expect(Gain.fromUserVolume(1), 1);
      expect(Gain.fromUserVolume(0.5), closeTo(0.125, 1e-12));
      expect(Gain.fromUserVolume(0), 0);
      expect(Gain.fromUserVolume(2), 1, reason: 'clamped');
    });

    test('equal-power curves keep constant power', () {
      for (var i = 0; i <= 20; i++) {
        final (out, inc) = Gain.equalPower(i / 20);
        expect(out * out + inc * inc, closeTo(1, 1e-12));
      }
      expect(Gain.equalPower(0), (1.0, 0.0));
      final (o, n) = Gain.equalPower(1);
      expect(o, closeTo(0, 1e-12));
      expect(n, closeTo(1, 1e-12));
    });

    test('ReplayGain as attenuation, never above 1.0', () {
      const off = NormalizationConfig.off();
      const trackMode = NormalizationConfig(enabled: true);
      const albumMode = NormalizationConfig(enabled: true, mode: NormalizationMode.replayGainAlbum);
      final t = track('a', rgTrack: -6, rgAlbum: -9);
      expect(Gain.replayGainFactor(t, off), 1);
      expect(Gain.replayGainFactor(t, trackMode), closeTo(math.pow(10, -6 / 20), 1e-12));
      expect(Gain.replayGainFactor(t, albumMode), closeTo(math.pow(10, -9 / 20), 1e-12));
      expect(Gain.replayGainFactor(track('loud', rgTrack: 4), trackMode), 1.0, reason: 'positive gain is clipped');
      expect(Gain.replayGainFactor(track('b', rgTrack: -3), albumMode), closeTo(math.pow(10, -3 / 20), 1e-12),
          reason: 'album falls back to track gain');
      expect(Gain.replayGainFactor(track('untagged'), trackMode), 1.0);
      expect(
        Gain.replayGainFactor(track('untagged'), const NormalizationConfig(enabled: true, preampDb: -6)),
        closeTo(math.pow(10, -6 / 20), 1e-12),
      );
      expect(
        Gain.replayGainFactor(t, const NormalizationConfig(enabled: true, mode: NormalizationMode.loudness)),
        closeTo(math.pow(10, -6 / 20), 1e-12),
        reason: 'loudness falls back to track ReplayGain where unsupported',
      );
    });

    test('NormalizationConfig from settings', () {
      final c = NormalizationConfig.fromSettings(
          const PlaybackSettings(normalizeVolume: true, normalizationMode: NormalizationMode.loudness, preampDb: 2));
      expect(c, const NormalizationConfig(enabled: true, mode: NormalizationMode.loudness, preampDb: 2));
    });
  });

  group('InterruptionPolicy', () {
    const settings = PlaybackSettings();
    AudioInterruption begin(AudioInterruptionKind k) => AudioInterruption(k, begin: true);
    AudioInterruption end(AudioInterruptionKind k) => AudioInterruption(k, begin: false);

    test('transient pause → pause, then resume', () {
      final p = InterruptionPolicy();
      expect(p.handle(begin(AudioInterruptionKind.transientPause), isPlaying: true, settings: settings),
          [InterruptionAction.pause]);
      expect(p.willResume, isTrue);
      expect(p.handle(end(AudioInterruptionKind.transientPause), isPlaying: false, settings: settings),
          [InterruptionAction.resume]);
    });

    test('not playing → nothing to resume', () {
      final p = InterruptionPolicy();
      expect(p.handle(begin(AudioInterruptionKind.transientPause), isPlaying: false, settings: settings), isEmpty);
      expect(p.handle(end(AudioInterruptionKind.transientPause), isPlaying: false, settings: settings), isEmpty);
    });

    test('duck and unduck; duck disabled behaves like a transient pause', () {
      final p = InterruptionPolicy();
      expect(p.handle(begin(AudioInterruptionKind.transientDuck), isPlaying: true, settings: settings),
          [InterruptionAction.duck]);
      expect(p.ducked, isTrue);
      expect(p.handle(end(AudioInterruptionKind.transientDuck), isPlaying: true, settings: settings),
          [InterruptionAction.unduck]);
      const noDuck = PlaybackSettings(duckOnTransientInterruption: false);
      expect(p.handle(begin(AudioInterruptionKind.transientDuck), isPlaying: true, settings: noDuck),
          [InterruptionAction.pause]);
      expect(p.handle(end(AudioInterruptionKind.transientDuck), isPlaying: false, settings: noDuck),
          [InterruptionAction.resume]);
    });

    test('permanent loss and user control cancel resume', () {
      final p = InterruptionPolicy();
      expect(p.handle(begin(AudioInterruptionKind.permanentLoss), isPlaying: true, settings: settings),
          [InterruptionAction.pause]);
      expect(p.handle(end(AudioInterruptionKind.permanentLoss), isPlaying: false, settings: settings), isEmpty);
      p.handle(begin(AudioInterruptionKind.transientPause), isPlaying: true, settings: settings);
      p.userTookControl();
      expect(p.handle(end(AudioInterruptionKind.transientPause), isPlaying: false, settings: settings), isEmpty);
    });

    test('becoming noisy honours pauseOnHeadphonesDisconnect', () {
      final p = InterruptionPolicy();
      expect(p.handle(begin(AudioInterruptionKind.becomingNoisy), isPlaying: true, settings: settings),
          [InterruptionAction.pause]);
      expect(
        p.handle(begin(AudioInterruptionKind.becomingNoisy),
            isPlaying: true, settings: const PlaybackSettings(pauseOnHeadphonesDisconnect: false)),
        isEmpty,
      );
    });
  });

  group('JustAudioBackend mappings', () {
    test('audio_session interruptions map to engine events', () {
      AudioInterruption map(session.AudioInterruptionType t, bool b) =>
          JustAudioBackend.mapInterruption(session.AudioInterruptionEvent(b, t));
      expect(map(session.AudioInterruptionType.pause, true).kind, AudioInterruptionKind.transientPause);
      expect(map(session.AudioInterruptionType.duck, true).kind, AudioInterruptionKind.transientDuck);
      expect(map(session.AudioInterruptionType.unknown, true).kind, AudioInterruptionKind.permanentLoss);
      expect(map(session.AudioInterruptionType.pause, false).begin, isFalse);
    });

    test('processing states map to deck states', () {
      expect(JustAudioDeck.mapState(ja.ProcessingState.idle), DeckState.idle);
      expect(JustAudioDeck.mapState(ja.ProcessingState.loading), DeckState.loading);
      expect(JustAudioDeck.mapState(ja.ProcessingState.buffering), DeckState.buffering);
      expect(JustAudioDeck.mapState(ja.ProcessingState.ready), DeckState.ready);
      expect(JustAudioDeck.mapState(ja.ProcessingState.completed), DeckState.completed);
    });

    test('capabilities: no device selection, no loudness, speed ok', () {
      final b = JustAudioBackend();
      expect(b.supportsOutputDeviceSelection, isFalse);
      expect(b.supportsLoudnessNormalization, isFalse);
      expect(b.supportsSpeed, isTrue);
    });
  });

  test('platform backend selection', () {
    expect(createPlatformAudioBackend(const PlatformInfo(os: HostOs.android)), isA<JustAudioBackend>());
    expect(createPlatformAudioBackend(const PlatformInfo(os: HostOs.linux)), isA<MediaKitBackend>());
    expect(createPlatformAudioBackend(const PlatformInfo(os: HostOs.windows)), isA<MediaKitBackend>());
    expect(() => createPlatformAudioBackend(const PlatformInfo(os: HostOs.other)), throwsUnsupportedError);
  });

  test('ListenClock accumulates only running time', () {
    var now = DateTime(2026);
    final c = ListenClock(() => now);
    c.start();
    now = now.add(const Duration(seconds: 3));
    c.pause();
    now = now.add(const Duration(seconds: 10));
    expect(c.elapsed, const Duration(seconds: 3));
    c.start();
    c.start(); // idempotent
    now = now.add(const Duration(seconds: 2));
    expect(c.elapsed, const Duration(seconds: 5));
    expect(c.running, isTrue);
  });

  group('QueueStateStore', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('fermata_store_'));
    tearDown(() => dir.delete(recursive: true));

    test('atomic writes, serialized, round-trip', () async {
      final store = QueueStateStore(File('${dir.path}/nested/state.json'));
      expect(await store.read(), isNull);
      final writes = [
        for (var i = 0; i < 20; i++)
          store.write(PersistedPlaybackState(queue: {'n': i}, position: Duration(seconds: i))),
      ];
      await Future.wait(writes);
      final read = await store.read();
      expect(read!.queue['n'], 19, reason: 'last write wins');
      expect(read.position, const Duration(seconds: 19));
      expect(File('${dir.path}/nested/state.json.tmp').existsSync(), isFalse);
      final raw = jsonDecode(File('${dir.path}/nested/state.json').readAsStringSync()) as Map;
      expect(raw['version'], PersistedPlaybackState.version);
    });

    test('pre-encoded queue fields produce the same document', () {
      final queue = {
        'items': [
          {'uid': 'u1'},
        ],
        'original': ['u1'],
        'index': 0,
        'shuffle': false,
      };
      final plain = PersistedPlaybackState(queue: queue, position: const Duration(seconds: 3), savedAt: DateTime.utc(2026));
      final fast = PersistedPlaybackState(
        queue: {'index': 0, 'shuffle': false},
        encodedQueueFields: {'items': jsonEncode(queue['items']), 'original': jsonEncode(queue['original'])},
        position: const Duration(seconds: 3),
        savedAt: DateTime.utc(2026),
      );
      expect(jsonDecode(fast.encode()), jsonDecode(plain.encode()));
      expect(fast.toJson()['queue'], queue);
    });

    test('rejects malformed content', () {
      expect(PersistedPlaybackState.fromJson('x'), isNull);
      expect(PersistedPlaybackState.fromJson({'queue': 1}), isNull);
      expect(PersistedPlaybackState.fromJson({'queue': {}, 'positionMs': -5})!.position, Duration.zero);
    });
  });
}
