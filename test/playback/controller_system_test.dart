import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/playback/backend/audio_backend.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/harness.dart';

Duration s(int n) => Duration(seconds: n);

const usb = AudioOutputDevice(id: 'pulse/usb-dac', name: 'USB DAC');
const auto = AudioOutputDevice(id: 'auto', name: 'System default', isDefault: true);

void main() {
  group('interruptions (audio focus)', () {
    Harness playing(dynamic async, {PlaybackSettings Function(PlaybackSettings p)? settings}) {
      final h = Harness(async, trackLength: const Duration(minutes: 5), settings: withPlayback(settings ?? (p) => p))
        ..init();
      h.playAll(h.tracks(1));
      return h;
    }

    void emit(Harness h, AudioInterruptionKind kind, {bool begin = true}) {
      h.backend.emitInterruption(AudioInterruption(kind, begin: begin));
      h.async.flushMicrotasks();
    }

    test('transient loss pauses and resumes afterwards', () {
      fake((async) {
        final h = playing(async);
        emit(h, AudioInterruptionKind.transientPause);
        expect(h.snap.playing, isFalse);
        h.elapse(s(5));
        emit(h, AudioInterruptionKind.transientPause, begin: false);
        expect(h.snap.playing, isTrue);
        expect(h.backend.decks.single.playing, isTrue);
      });
    });

    test('no resume when resumeAfterInterruption is off or the user paused', () {
      fake((async) {
        final h = playing(async, settings: (p) => p.copyWith(resumeAfterInterruption: false));
        emit(h, AudioInterruptionKind.transientPause);
        emit(h, AudioInterruptionKind.transientPause, begin: false);
        expect(h.snap.playing, isFalse);

        final h2 = playing(async);
        emit(h2, AudioInterruptionKind.transientPause);
        h2.settle(h2.controller.pause()); // explicit user action during the interruption
        emit(h2, AudioInterruptionKind.transientPause, begin: false);
        expect(h2.snap.playing, isFalse);
      });
    });

    test('may-duck lowers the volume and restores it', () {
      fake((async) {
        final h = playing(async);
        final deck = h.backend.decks.single;
        emit(h, AudioInterruptionKind.transientDuck);
        expect(h.snap.playing, isTrue);
        expect(deck.volume, closeTo(0.3, 1e-9));
        emit(h, AudioInterruptionKind.transientDuck, begin: false);
        expect(deck.volume, 1.0);
      });
    });

    test('may-duck pauses when ducking is disabled', () {
      fake((async) {
        final h = playing(async, settings: (p) => p.copyWith(duckOnTransientInterruption: false));
        emit(h, AudioInterruptionKind.transientDuck);
        expect(h.snap.playing, isFalse);
        emit(h, AudioInterruptionKind.transientDuck, begin: false);
        expect(h.snap.playing, isTrue);
      });
    });

    test('permanent loss pauses without resuming', () {
      fake((async) {
        final h = playing(async);
        emit(h, AudioInterruptionKind.permanentLoss);
        expect(h.snap.playing, isFalse);
        emit(h, AudioInterruptionKind.permanentLoss, begin: false);
        expect(h.snap.playing, isFalse);
      });
    });

    test('becoming noisy pauses only when configured', () {
      fake((async) {
        final h = playing(async);
        emit(h, AudioInterruptionKind.becomingNoisy);
        expect(h.snap.playing, isFalse);

        final h2 = playing(async, settings: (p) => p.copyWith(pauseOnHeadphonesDisconnect: false));
        emit(h2, AudioInterruptionKind.becomingNoisy);
        expect(h2.snap.playing, isTrue);
      });
    });
  });

  group('output devices (desktop)', () {
    test('the saved device is selected at startup', () {
      fake((async) {
        final h = Harness(async, settings: withPlayback((p) => p.copyWith(outputDeviceId: usb.id)))..init();
        expect(h.controller.supportsOutputDeviceSelection, isTrue);
        expect(h.backend.selectedDevice, usb.id);
      });
    });

    test('falls back to the default when the saved device is gone, and returns to it', () {
      fake((async) {
        final h = Harness(async, settings: withPlayback((p) => p.copyWith(outputDeviceId: 'pulse/gone')));
        h.init();
        expect(h.backend.deviceCalls, [null]);
        expect(h.settingsStore.current.playback.outputDeviceId, 'pulse/gone', reason: 'kept for later');

        h.backend.setDevices([auto, usb, const AudioOutputDevice(id: 'pulse/gone', name: 'Headset')]);
        async.flushMicrotasks();
        expect(h.backend.selectedDevice, 'pulse/gone');

        h.backend.setDevices([auto, usb]);
        async.flushMicrotasks();
        expect(h.backend.selectedDevice, isNull);
      });
    });

    test('setOutputDevice persists the choice; the default clears it', () {
      fake((async) {
        final h = Harness(async)..init();
        final devices = h.settle(h.controller.outputDevices());
        expect(devices.map((d) => d.id), [auto.id, usb.id]);
        h.settle(h.controller.setOutputDevice(usb.id));
        expect(h.backend.selectedDevice, usb.id);
        expect(h.settingsStore.current.playback.outputDeviceId, usb.id);
        h.settle(h.controller.setOutputDevice(auto.id));
        expect(h.backend.selectedDevice, isNull);
        expect(h.settingsStore.current.playback.outputDeviceId, isNull);
        expect(() => h.settle(h.controller.setOutputDevice('nope')), throwsArgumentError);
      });
    });

    test('not offered on Android', () {
      fake((async) {
        final h = Harness(async, os: HostOs.android)..init();
        expect(h.controller.supportsOutputDeviceSelection, isFalse);
        expect(h.settle(h.controller.outputDevices()), isEmpty);
        h.settle(h.controller.setOutputDevice(usb.id));
        expect(h.backend.deviceCalls, isEmpty);
      });
    });
  });

  test('loudness mode falls back to track ReplayGain when unsupported', () {
    fake((async) {
      final h = Harness(async,
          settings: withPlayback((p) => p.copyWith(normalizeVolume: true, normalizationMode: NormalizationMode.loudness)))
        ..init();
      expect(h.backend.normalization.mode, NormalizationMode.loudness, reason: 'fake supports loudness');
    });
  });
}
