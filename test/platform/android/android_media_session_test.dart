import 'package:audio_service/audio_service.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/platform/android/android_media_session.dart';
import 'package:fermata/platform/android/android_notifier.dart';
import 'package:fermata/platform/android/media_session_config.dart';
import 'package:fermata/platform/android/media_session_labels.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/performance_profiles.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('AudioServiceConfig', () {
    test('matches the spec for default settings', () {
      final config = buildAudioServiceConfig(const AppSettings());
      expect(config.androidNotificationChannelId, 'app.fermata.player.playback');
      expect(config.androidNotificationChannelName, 'Playback');
      expect(config.androidNotificationIcon, 'drawable/ic_stat_fermata');
      expect(config.androidStopForegroundOnPause, isTrue);
      expect(config.notificationColor, const Color(0xFFE9B44C));
      expect(config.preloadArtwork, isTrue);
      expect(config.artDownscaleWidth, 512);
      expect(config.artDownscaleHeight, 512);
      expect(config.fastForwardInterval, const Duration(seconds: 15));
      expect(config.rewindInterval, const Duration(seconds: 15));
      expect(config.androidNotificationOngoing, isFalse);
      expect(config.androidBrowsableRootExtras![AndroidContentStyle.supportedKey], isTrue);
    });

    test('stopForegroundOnPause follows the Android setting', () {
      const keep = AppSettings(android: AndroidSettings(stopForegroundOnPause: false));
      expect(buildAudioServiceConfig(keep).androidStopForegroundOnPause, isFalse);
    });

    test('artwork preloading is off in Battery saver and Data saver', () {
      for (final mode in PerformanceMode.values) {
        final s = PerformanceProfiles.apply(const AppSettings(), mode);
        final expected = mode != PerformanceMode.batterySaver && mode != PerformanceMode.dataSaver && s.performance.prefetchArtwork;
        expect(buildAudioServiceConfig(s).preloadArtwork, expected, reason: mode.name);
      }
      expect(preloadArtworkFor(PerformanceProfiles.apply(const AppSettings(), PerformanceMode.batterySaver)), isFalse);
      expect(preloadArtworkFor(PerformanceProfiles.apply(const AppSettings(), PerformanceMode.dataSaver)), isFalse);
    });

    test('Danish channel name', () {
      expect(buildAudioServiceConfig(const AppSettings(), labels: MediaSessionLabels.da).androidNotificationChannelName,
          'Afspilning');
    });
  });

  group('AndroidMediaSession', () {
    setUp(AndroidMediaSession.resetForTesting);

    test('is a no-op on Linux and Windows', () async {
      for (final os in [HostOs.linux, HostOs.windows]) {
        final playback = FakePlaybackController();
        final session = await AndroidMediaSession.start(
          playback: playback,
          settings: SettingsStore.inMemory(),
          platform: PlatformInfo(os: os),
        );
        expect(session.isActive, isFalse);
        expect(session.handler, isNull);
        expect(session.headsetAutoResume, isNull);
        expect(session.restartRequiredForSettings, isFalse);
        expect(playback.calls, isEmpty);
        await session.dispose();
      }
    });

    test('restartRequired detects start-time-only settings', () {
      const base = AppSettings();
      expect(AndroidMediaSession.restartRequired(base, base), isFalse);
      expect(
        AndroidMediaSession.restartRequired(base, base.copyWith(android: const AndroidSettings(stopForegroundOnPause: false))),
        isTrue,
      );
      expect(
        AndroidMediaSession.restartRequired(base, PerformanceProfiles.apply(base, PerformanceMode.batterySaver)),
        isTrue,
      );
      expect(
        AndroidMediaSession.restartRequired(base, base.copyWith(android: const AndroidSettings(resumeOnHeadsetConnect: true))),
        isFalse,
        reason: 'headset auto-resume reads the setting live',
      );
    });

    test('inactive session reports the settings it was configured with', () async {
      final settings = SettingsStore.inMemory(const AppSettings(android: AndroidSettings(stopForegroundOnPause: false)));
      final session = await AndroidMediaSession.start(
        playback: FakePlaybackController(),
        settings: settings,
        platform: const PlatformInfo(os: HostOs.linux),
      );
      expect(session.stopForegroundOnPause, isFalse);
    });
  });

  test('AndroidNotifier is explicitly unsupported and never throws', () async {
    const notifier = AndroidNotifier();
    expect(notifier.isSupported, isFalse);
    await notifier.show(id: 'dl-1', title: 'Download finished');
    expect(AndroidNotifier.downloadsChannelId, 'app.fermata.player.downloads');
  });
}
