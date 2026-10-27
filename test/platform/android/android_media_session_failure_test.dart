// A failing AudioService.init must not crash bootstrap. Separate file:
// audio_service can only be initialised once per isolate.
import 'dart:async';
import 'dart:io';

import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/platform/android/android_media_session.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Makes the handler builder throw inside AudioService.init.
class _BrokenController extends FakePlaybackController {
  @override
  PlaybackSnapshot get snapshot => throw StateError('engine not ready');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('when audio_service cannot start, the session is inactive instead of fatal', () async {
    final temp = Directory.systemTemp.createTempSync('fermata_android_session_failure');
    addTearDown(() => temp.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    AndroidMediaSession.resetForTesting();

    // audio_service 0.18.19 additionally reports a builder failure to the
    // zone's uncaught-error handler (besides throwing from init); in the app
    // that lands in the global error log. Capture it here so the assertion
    // is about our behavior: start() completes with an inactive session.
    final leaked = <Object>[];
    final result = Completer<AndroidMediaSession>();
    runZonedGuarded(() async {
      result.complete(await AndroidMediaSession.start(
        playback: _BrokenController(),
        settings: SettingsStore.inMemory(),
        platform: const PlatformInfo(os: HostOs.android),
      ));
    }, (e, st) => leaked.add(e));

    final session = await result.future;
    expect(session.isActive, isFalse);
    expect(session.handler, isNull);
    expect(session.restartRequiredForSettings, isFalse);
    expect(leaked.every((e) => e is StateError), isTrue);
  });
}
