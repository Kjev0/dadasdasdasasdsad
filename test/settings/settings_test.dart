import 'dart:convert';
import 'dart:io';

import 'package:fermata/core/contracts/platform.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/performance_profiles.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('Liquid Glass is disabled by default', () {
      expect(const AppSettings().appearance.liquidGlass, isFalse);
    });

    test('defaults: balanced mode, minimize to tray, dark theme', () {
      const s = AppSettings();
      expect(s.performance.mode, PerformanceMode.balanced);
      expect(s.desktop.closeBehavior, CloseBehavior.minimizeToTray);
      expect(s.appearance.themeMode, AppThemeMode.dark);
    });

    test('JSON round-trip preserves every group', () {
      final s = const AppSettings().copyWith(
        appearance: const AppearanceSettings(liquidGlass: true, glassIntensity: 0.3, themeMode: AppThemeMode.light),
        playback: const PlaybackSettings(crossfadeSeconds: 4, speed: 1.25, outputDeviceId: 'dev1'),
        desktop: const DesktopSettings(closeBehavior: CloseBehavior.ask, launchAtLogin: true),
        localeCode: 'da',
        onboardingCompleted: true,
      );
      final decoded = AppSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
      expect(decoded.appearance.liquidGlass, isTrue);
      expect(decoded.appearance.glassIntensity, 0.3);
      expect(decoded.appearance.themeMode, AppThemeMode.light);
      expect(decoded.playback.crossfadeSeconds, 4);
      expect(decoded.playback.speed, 1.25);
      expect(decoded.playback.outputDeviceId, 'dev1');
      expect(decoded.desktop.closeBehavior, CloseBehavior.ask);
      expect(decoded.desktop.launchAtLogin, isTrue);
      expect(decoded.localeCode, 'da');
      expect(decoded.onboardingCompleted, isTrue);
    });

    test('unknown / invalid values fall back to defaults and are clamped', () {
      final s = AppSettings.fromJson({
        'appearance': {'themeMode': 'neon', 'glassIntensity': 7},
        'playback': {'speed': 9, 'crossfadeSeconds': -3},
        'services': {'providerOrder': ['spotify']},
      });
      expect(s.appearance.themeMode, AppThemeMode.dark);
      expect(s.appearance.glassIntensity, 1.0);
      expect(s.playback.speed, 2.0);
      expect(s.playback.crossfadeSeconds, 0);
      // New built-in sources are appended after the user's order.
      expect(s.services.providerOrder.first, 'spotify');
      expect(s.services.providerOrder, contains('soundcloud'));
    });
  });

  group('PerformanceProfiles', () {
    test('battery saver disables expensive effects and background work', () {
      final s = PerformanceProfiles.apply(const AppSettings(), PerformanceMode.batterySaver);
      expect(s.performance.animations, AnimationLevel.off);
      expect(s.performance.blur, isFalse);
      expect(s.performance.preloadNext, isFalse);
      expect(s.performance.backgroundSync, isFalse);
      expect(s.performance.artworkQuality, ArtworkQuality.low);
    });

    test('data saver lowers streaming quality and forces Wi-Fi-only downloads', () {
      final s = PerformanceProfiles.apply(
        const AppSettings(downloads: DownloadSettings(wifiOnly: false)),
        PerformanceMode.dataSaver,
      );
      expect(s.audioQuality.streaming, AudioQuality.low);
      expect(s.downloads.wifiOnly, isTrue);
      expect(s.performance.preloadNext, isFalse);
    });

    test('visual quality enables high artwork + blur', () {
      final s = PerformanceProfiles.apply(const AppSettings(), PerformanceMode.visualQuality);
      expect(s.performance.artworkQuality, ArtworkQuality.high);
      expect(s.performance.blur, isTrue);
    });

    test('effective visuals respect reduce-motion and blur preferences', () {
      final s = PerformanceProfiles.apply(const AppSettings(), PerformanceMode.balanced);
      final v = EffectiveVisuals.from(s, systemReduceMotion: true, platformSupportsBlur: true);
      expect(v.animate, isFalse);
      final noBlur = EffectiveVisuals.from(
        s.copyWith(performance: s.performance.copyWith(blur: false)),
        systemReduceMotion: false,
        platformSupportsBlur: true,
      );
      expect(noBlur.blur, isFalse);
    });
  });

  group('SettingsStore', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('fermata_settings'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('persists across reloads (restart) and restores defaults', () async {
      final file = File('${tmp.path}/settings.json');
      final store = await SettingsStore.load(file);
      await store.update((s) => s.copyWith(appearance: s.appearance.copyWith(liquidGlass: true)));
      await store.flush();

      final reloaded = await SettingsStore.load(file);
      expect(reloaded.current.appearance.liquidGlass, isTrue);

      await reloaded.restoreDefaults();
      expect(reloaded.current.appearance.liquidGlass, isFalse);
      await reloaded.dispose();
      await store.dispose();
    });

    test('granular performance change switches mode to custom', () async {
      final store = SettingsStore.inMemory();
      await store.applyPerformanceMode(PerformanceMode.performance);
      expect(store.current.performance.mode, PerformanceMode.performance);
      await store.updatePerformance((p) => p.copyWith(blur: true));
      expect(store.current.performance.mode, PerformanceMode.custom);
    });

    test('corrupt file falls back to backup', () async {
      final file = File('${tmp.path}/settings.json');
      final store = await SettingsStore.load(file);
      await store.update((s) => s.copyWith(localeCode: 'da'));
      await store.flush();
      await store.update((s) => s.copyWith(onboardingCompleted: true));
      await store.flush(); // creates .bak containing localeCode=da
      file.writeAsStringSync('{not json');
      final recovered = await SettingsStore.load(file);
      expect(recovered.current.localeCode, 'da');
    });

    test('export/import round-trip', () async {
      final store = SettingsStore.inMemory(const AppSettings(localeCode: 'da'));
      final path = '${tmp.path}/export.json';
      await store.exportTo(path);
      final other = SettingsStore.inMemory();
      await other.importFrom(path);
      expect(other.current.localeCode, 'da');
    });
  });
}
