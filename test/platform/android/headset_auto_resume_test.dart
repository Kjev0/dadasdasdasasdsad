// AudioDeviceType is @experimental in audio_session.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/platform/android/headset_auto_resume.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class FakeRouteEvents implements AudioRouteEvents {
  final noisy = StreamController<void>.broadcast(sync: true);
  final devices = StreamController<AudioDevicesChangedEvent>.broadcast(sync: true);

  @override
  Stream<void> get becomingNoisy => noisy.stream;

  @override
  Stream<AudioDevicesChangedEvent> get devicesChanged => devices.stream;

  void connect(AudioDeviceType type, {bool output = true}) => devices.add(AudioDevicesChangedEvent(
        devicesAdded: {AudioDevice(id: '${type.name}-1', name: type.name, isInput: !output, isOutput: output, type: type)},
      ));
}

void main() {
  final current = qi('u1', track('a'));
  late FakePlaybackController playback;
  late SettingsStore settings;
  late FakeRouteEvents events;
  late TestClock clock;
  late HeadsetAutoResume resume;

  PlaybackSnapshot snap({required bool playing}) =>
      PlaybackSnapshot(current: current, playing: playing, status: PlayerStatus.ready);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Simulates the playback module: noisy event, then the engine pauses.
  void unplugWhilePlaying() {
    events.noisy.add(null);
    playback.emitSnapshot(snap(playing: false));
  }

  setUp(() {
    playback = FakePlaybackController(snapshot: snap(playing: true));
    settings = SettingsStore.inMemory(const AppSettings(android: AndroidSettings(resumeOnHeadsetConnect: true)));
    events = FakeRouteEvents();
    clock = TestClock();
    resume = HeadsetAutoResume(playback: playback, settings: settings, events: events, now: clock.call)..start();
  });

  tearDown(() => resume.dispose());

  test('reconnecting Bluetooth A2DP within 5 minutes of a noisy pause resumes', () async {
    unplugWhilePlaying();
    expect(resume.armed, isTrue);
    clock.advance(const Duration(minutes: 4, seconds: 59));
    events.connect(AudioDeviceType.bluetoothA2dp);
    await settle();
    expect(playback.calls, ['play']);
    expect(resume.armed, isFalse);
  });

  test('wired headphones and headsets count; speakers, SCO and inputs do not', () async {
    unplugWhilePlaying();
    events.connect(AudioDeviceType.builtInSpeaker);
    events.connect(AudioDeviceType.bluetoothSco);
    events.connect(AudioDeviceType.wiredHeadset, output: false);
    await settle();
    expect(playback.calls, isEmpty);
    events.connect(AudioDeviceType.wiredHeadphones);
    await settle();
    expect(playback.calls, ['play']);
  });

  test('no resume after the 5 minute window', () async {
    unplugWhilePlaying();
    clock.advance(const Duration(minutes: 5, seconds: 1));
    events.connect(AudioDeviceType.bluetoothA2dp);
    await settle();
    expect(playback.calls, isEmpty);
  });

  test('no resume when the setting is off (read live)', () async {
    await settings.update((s) => s.copyWith(android: s.android.copyWith(resumeOnHeadsetConnect: false)));
    unplugWhilePlaying();
    events.connect(AudioDeviceType.bluetoothA2dp);
    await settle();
    expect(playback.calls, isEmpty);
  });

  test('no resume when playback was already paused before the unplug', () async {
    playback.emitSnapshot(snap(playing: false));
    clock.advance(const Duration(minutes: 1));
    events.noisy.add(null);
    events.connect(AudioDeviceType.bluetoothA2dp);
    await settle();
    expect(playback.calls, isEmpty);
  });

  test('pause racing ahead of the noisy event still arms (grace period)', () async {
    playback.emitSnapshot(snap(playing: false));
    clock.advance(const Duration(milliseconds: 500));
    events.noisy.add(null);
    expect(resume.armed, isTrue);
  });

  test('manual resume in between disarms', () async {
    unplugWhilePlaying();
    playback.emitSnapshot(snap(playing: true)); // user pressed play on the speaker
    playback.emitSnapshot(snap(playing: false));
    events.connect(AudioDeviceType.bluetoothA2dp);
    await settle();
    expect(playback.calls, isEmpty);
  });

  test('a playing tick that arrives just after the noisy event does not disarm', () async {
    events.noisy.add(null);
    playback.emitSnapshot(snap(playing: true)); // stale 4 Hz tick
    playback.emitSnapshot(snap(playing: false));
    events.connect(AudioDeviceType.bluetoothA2dp);
    await settle();
    expect(playback.calls, ['play']);
  });

  test('nothing to resume without a current item', () async {
    unplugWhilePlaying();
    playback.emitSnapshot(const PlaybackSnapshot());
    events.connect(AudioDeviceType.bluetoothA2dp);
    await settle();
    expect(playback.calls, isEmpty);
  });

  test('resumes only once per noisy pause', () async {
    unplugWhilePlaying();
    events.connect(AudioDeviceType.bluetoothA2dp);
    events.connect(AudioDeviceType.bluetoothA2dp);
    await settle();
    expect(playback.calls, ['play']);
  });
}
