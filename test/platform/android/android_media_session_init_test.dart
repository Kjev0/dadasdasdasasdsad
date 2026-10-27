// Runs the real AudioService.init (audio_service's no-op platform on a
// Linux test host) to verify the Android wiring end to end: config handed
// to audio_service, handler registered, controller mirrored. audio_service
// can only be initialised once per isolate, so this file holds one init.
import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/platform/android/android_media_session.dart';
import 'package:fermata/platform/android/headset_auto_resume.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class _NoRouteEvents implements AudioRouteEvents {
  @override
  Stream<void> get becomingNoisy => const Stream.empty();

  @override
  Stream<AudioDevicesChangedEvent> get devicesChanged => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUpAll(() {
    // audio_service creates flutter_cache_manager's DefaultCacheManager,
    // which asks path_provider for its directories.
    temp = Directory.systemTemp.createTempSync('fermata_android_session_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
  });

  tearDownAll(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('on Android: initialises audio_service with Fermata config and mirrors the controller', () async {
    AndroidMediaSession.resetForTesting();
    final current = qi('u1', track('a', title: 'Alpha', duration: const Duration(minutes: 3)));
    final playback = FakePlaybackController(
      snapshot: PlaybackSnapshot(current: current, playing: true, status: PlayerStatus.ready),
      queue: QueueState(items: [current], currentIndex: 0),
    );
    final settings = SettingsStore.inMemory(const AppSettings(android: AndroidSettings(stopForegroundOnPause: false)));

    final session = await AndroidMediaSession.start(
      playback: playback,
      settings: settings,
      platform: const PlatformInfo(os: HostOs.android),
      routeEvents: _NoRouteEvents(),
    );
    await Future<void>.delayed(Duration.zero);

    expect(session.isActive, isTrue);
    expect(session.headsetAutoResume, isNotNull);
    expect(session.stopForegroundOnPause, isFalse);

    final config = AudioService.config;
    expect(config.androidNotificationChannelId, 'app.fermata.player.playback');
    expect(config.androidNotificationIcon, 'drawable/ic_stat_fermata');
    expect(config.androidStopForegroundOnPause, isFalse);
    expect(config.fastForwardInterval, const Duration(seconds: 15));

    final handler = session.handler!;
    expect(handler.mediaItem.value!.id, 'u1');
    expect(handler.playbackState.value.playing, isTrue);
    expect(handler.playbackState.value.androidCompactActionIndices, [0, 1, 2]);

    // Commands from the session reach the controller.
    await handler.pause();
    expect(playback.calls, ['pause']);

    // Changing a start-time-only setting is reported as "applies after restart".
    expect(session.restartRequiredForSettings, isFalse);
    await settings.update((s) => s.copyWith(android: s.android.copyWith(stopForegroundOnPause: true)));
    expect(session.restartRequiredForSettings, isTrue);

    // A second start returns the running session instead of re-initialising.
    final again = await AndroidMediaSession.start(
      playback: playback,
      settings: settings,
      platform: const PlatformInfo(os: HostOs.android),
    );
    expect(identical(again, session), isTrue);

    await session.dispose();
    // After dispose audio_service cannot be initialised again in-process.
    final afterDispose = await AndroidMediaSession.start(
      playback: playback,
      settings: settings,
      platform: const PlatformInfo(os: HostOs.android),
    );
    expect(afterDispose.isActive, isFalse);
  });
}
