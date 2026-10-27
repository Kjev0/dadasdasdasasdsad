import 'dart:io';

import 'package:fermata/app/providers.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'settings_harness.dart';

/// Scrolls to the switch row [key] and taps it.
Future<void> toggle(WidgetTester tester, String key) async {
  final row = find.byKey(ValueKey(key));
  await scrollTo(tester, row);
  await tapVisible(tester, row);
}

void main() {
  final l10n = AppLocalizationsEn();
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('fermata-settings-test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Every switch below must change exactly one stored value. Each entry is
  /// (section, row key, reader).
  final switches = <(String, String, bool Function(AppSettings))>[
    ('appearance', 'setting.artworkBackdrop', (s) => s.appearance.artworkBackdrop),
    ('appearance', 'setting.highContrast', (s) => s.accessibility.highContrast),
    ('glass', 'setting.liquidGlass', (s) => s.appearance.liquidGlass),
    ('playback', 'setting.gapless', (s) => s.playback.gapless),
    ('playback', 'setting.normalize', (s) => s.playback.normalizeVolume),
    ('playback', 'setting.restoreQueue', (s) => s.playback.restoreQueueOnStartup),
    ('playback', 'setting.smartQueue', (s) => s.playback.smartQueue),
    ('playback', 'setting.skipUnplayable', (s) => s.playback.skipUnplayable),
    ('playback', 'setting.sleepFade', (s) => s.playback.sleepTimerFadeOut),
    ('playback', 'setting.lyrics', (s) => s.playback.lyricsEnabled),
    ('downloads', 'setting.wifiOnly', (s) => s.downloads.wifiOnly),
    ('downloads', 'setting.verifyIntegrity', (s) => s.downloads.verifyIntegrity),
    ('downloads', 'setting.notifyComplete', (s) => s.downloads.notifyOnComplete),
    ('performance', 'setting.blur', (s) => s.performance.blur),
    ('performance', 'setting.preloadNext', (s) => s.performance.preloadNext),
    ('performance', 'setting.prefetchArtwork', (s) => s.performance.prefetchArtwork),
    ('performance', 'setting.backgroundSync', (s) => s.performance.backgroundSync),
    ('import', 'setting.skipUnavailable', (s) => s.import.skipUnavailable),
    ('import', 'setting.allowPreviewOnly', (s) => s.import.allowPreviewOnly),
    ('notifications', 'setting.notifyTrackChange', (s) => s.notifications.trackChange),
    ('notifications', 'setting.notifyDownloads', (s) => s.notifications.downloads),
    ('desktop', 'setting.showTrayIcon', (s) => s.desktop.showTrayIcon),
    ('desktop', 'setting.rememberWindow', (s) => s.desktop.rememberWindowBounds),
    ('privacy', 'setting.recordHistory', (s) => s.privacy.recordHistory),
    ('privacy', 'setting.personalized', (s) => s.privacy.personalizedRecommendations),
    ('privacy', 'setting.saveSearches', (s) => s.privacy.saveSearchHistory),
    ('accessibility', 'setting.largerTargets', (s) => s.accessibility.largerTargets),
    ('shortcuts', 'setting.globalHotkeys', (s) => s.shortcuts.globalHotkeysEnabled),
  ];

  for (final (section, key, read) in switches) {
    testWidgets('$key persists and survives a store reload', (tester) async {
      final file = File('${tmp.path}/settings.json');
      final store = await tester.runAsync(() => SettingsStore.load(file));
      final kit = FakeKit();
      await pumpSettings(tester, kit: kit, section: section, overrides: [settingsStoreProvider.overrideWithValue(store!)]);
      final before = read(store.current);
      await toggle(tester, key);
      expect(read(store.current), !before, reason: '$key did not change the store');
      await tester.runAsync(store.flush);
      final reloaded = await tester.runAsync(() => SettingsStore.load(file));
      expect(read(reloaded!.current), !before, reason: '$key was not written to disk');
    });
  }

  testWidgets('choices and sliders persist (theme, accent, quality, motion, language)', (tester) async {
    final kit = await pumpSettings(tester, section: 'appearance');
    final store = kit.settingsStore;
    await tester.tap(find.text(l10n.settingsThemeLight));
    await pumpFrames(tester, count: 3);
    expect(store.current.appearance.themeMode, AppThemeMode.light);
    await tester.tap(find.byKey(const ValueKey('setting.accent.mint')));
    await pumpFrames(tester, count: 3);
    expect(store.current.appearance.accent, AccentChoice.mint);
    await tester.tap(find.text(l10n.settingsDensityCompact));
    await pumpFrames(tester, count: 3);
    expect(store.current.appearance.density, UiDensity.compact);

    await openSection(tester, 'audioQuality');
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('setting.streamingQuality')), matching: find.byType(DropdownButton<AudioQuality>)));
    await pumpFrames(tester, count: 3);
    await tester.tap(find.text(l10n.settingsValueLossless).last);
    await pumpFrames(tester, count: 3);
    expect(store.current.audioQuality.streaming, AudioQuality.lossless);

    await openSection(tester, 'accessibility');
    await tester.tap(find.text(l10n.settingsMotionReduce));
    await pumpFrames(tester, count: 3);
    expect(store.current.accessibility.motion, MotionPreference.reduce);

    await openSection(tester, 'language');
    await tester.tap(find.byKey(const ValueKey('setting.language.da')));
    await pumpFrames(tester, count: 3);
    expect(store.current.localeCode, 'da');
    // The UI switches to Danish immediately (localeProvider is not used by
    // pumpInApp, so only the stored value is checked here).
    await tester.tap(find.byKey(const ValueKey('setting.language.system')));
    await pumpFrames(tester, count: 3);
    expect(store.current.localeCode, isNull);
  });

  testWidgets('crossfade slider commits once and disables gapless with a note', (tester) async {
    final kit = await pumpSettings(tester, section: 'playback');
    final slider = find.descendant(of: find.byKey(const ValueKey('setting.crossfade')), matching: find.byType(Slider));
    await tester.drag(slider, const Offset(200, 0));
    await pumpFrames(tester, count: 3);
    expect(kit.settingsStore.current.playback.crossfadeSeconds, greaterThan(0));
    expect(find.text(l10n.settingsGaplessCrossfadeNote), findsOneWidget);
    final gapless = tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('setting.gapless')), matching: find.byType(Switch)));
    expect(gapless.onChanged, isNull);
  });

  testWidgets('speed default is applied to the player and stored', (tester) async {
    final kit = await pumpSettings(tester, section: 'playback');
    final slider = find.descendant(of: find.byKey(const ValueKey('setting.speed')), matching: find.byType(Slider));
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(150, 0));
    await pumpFrames(tester, count: 3);
    expect(kit.settingsStore.current.playback.speed, greaterThan(1.0));
    expect(kit.playback.called('setSpeed'), isTrue);
  });

  testWidgets('loudness normalization is only offered on desktop', (tester) async {
    final android = FakeKit(os: HostOs.android, settings: const AppSettings(onboardingCompleted: true, playback: PlaybackSettings(normalizeVolume: true)));
    await pumpSettings(tester, kit: android, section: 'playback', size: TestSizes.compact);
    final dropdown = find.descendant(of: find.byKey(const ValueKey('setting.normalizationMode')), matching: find.byType(DropdownButton<NormalizationMode>));
    await tester.ensureVisible(dropdown);
    await tester.pump();
    await tester.tap(dropdown);
    await pumpFrames(tester, count: 3);
    // The menu is open (the album option is listed in the menu and the button).
    expect(find.text(l10n.settingsNormalizationAlbum), findsWidgets);
    expect(find.text(l10n.settingsNormalizationLoudness), findsNothing);
  });

  testWidgets('interruption settings exist on Android only', (tester) async {
    await pumpSettings(tester, section: 'playback');
    expect(find.byKey(const ValueKey('setting.pauseOnDisconnect'), skipOffstage: false), findsNothing);
  });

  testWidgets('output device list comes from the player and switching calls it', (tester) async {
    final kit = await pumpSettings(tester, section: 'audioQuality');
    expect(kit.playback.called('outputDevices'), isTrue);
    final dropdown = find.descendant(of: find.byKey(const ValueKey('setting.outputDevice')), matching: find.byType(DropdownButton<String>));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await pumpFrames(tester, count: 3);
    final second = kit.playback.devices[1];
    await tester.tap(find.text(second.isDefault ? l10n.settingsOutputDeviceDefault(second.name) : second.name).last);
    await pumpFrames(tester, count: 3);
    expect(kit.playback.called('setOutputDevice'), isTrue);
  });

  group('restore defaults per section', () {
    final cases = <(String, AppSettings, bool Function(AppSettings))>[
      (
        'appearance',
        const AppSettings(appearance: AppearanceSettings(themeMode: AppThemeMode.light, accent: AccentChoice.ice, liquidGlass: true)),
        // Glass belongs to its own section and is kept.
        (s) => s.appearance.themeMode == AppThemeMode.dark && s.appearance.accent == AccentChoice.gold && s.appearance.liquidGlass,
      ),
      ('glass', const AppSettings(appearance: AppearanceSettings(liquidGlass: true, glassIntensity: 0.2)), (s) => !s.appearance.liquidGlass && s.appearance.glassIntensity == 0.6),
      ('playback', const AppSettings(playback: PlaybackSettings(crossfadeSeconds: 6, smartQueue: false, volume: 0.3)), (s) => s.playback.crossfadeSeconds == 0 && s.playback.smartQueue && s.playback.volume == 0.3),
      ('audioQuality', const AppSettings(audioQuality: AudioQualitySettings(streaming: AudioQuality.low)), (s) => s.audioQuality.streaming == AudioQuality.high),
      ('downloads', const AppSettings(downloads: DownloadSettings(directory: '/x', wifiOnly: false, maxConcurrent: 5)), (s) => s.downloads.directory == '/x' && s.downloads.wifiOnly && s.downloads.maxConcurrent == 2),
      ('storage', const AppSettings(storage: StorageSettings(downloadLimitMb: 1024, autoCleanup: false)), (s) => s.storage.downloadLimitMb == 0 && s.storage.autoCleanup),
      ('performance', const AppSettings(performance: PerformanceSettings(mode: PerformanceMode.custom, blur: false)), (s) => s.performance.mode == PerformanceMode.balanced && s.performance.blur),
      ('services', AppSettings(services: const ServicesSettings(preferSoundCloudInDiscovery: false, disabledSources: {'deezer'})), (s) => s.services.preferSoundCloudInDiscovery && s.services.disabledSources.isEmpty),
      ('import', const AppSettings(import: ImportSettings(skipUnavailable: true, autoAcceptThreshold: 0.7)), (s) => !s.import.skipUnavailable && s.import.autoAcceptThreshold == 0.88),
      ('notifications', const AppSettings(notifications: NotificationSettings(trackChange: true, downloads: false)), (s) => !s.notifications.trackChange && s.notifications.downloads),
      ('desktop', const AppSettings(desktop: DesktopSettings(showTrayIcon: false, launchAtLogin: true)), (s) => s.desktop.showTrayIcon && s.desktop.launchAtLogin),
      ('shortcuts', const AppSettings(shortcuts: ShortcutSettings(globalHotkeysEnabled: false, bindings: {'playPause': 'ctrl+j'})), (s) => s.shortcuts.globalHotkeysEnabled && s.shortcuts.bindingFor('playPause') == 'space'),
      ('privacy', const AppSettings(privacy: PrivacySettings(recordHistory: false)), (s) => s.privacy.recordHistory),
      ('language', const AppSettings(localeCode: 'da'), (s) => s.localeCode == null),
      ('accessibility', const AppSettings(accessibility: AccessibilitySettings(textScale: 1.4, largerTargets: true)), (s) => s.accessibility.textScale == 1.0 && !s.accessibility.largerTargets),
    ];
    for (final (section, initial, check) in cases) {
      testWidgets(section, (tester) async {
        final kit = FakeKit(settings: initial.copyWith(onboardingCompleted: true));
        await pumpSettings(tester, kit: kit, section: section);
        await tapVisible(tester, find.byKey(const ValueKey('settings.restoreSection')));
        await tester.tap(find.text(l10n.actionRestoreDefaults));
        await pumpFrames(tester);
        expect(check(kit.settingsStore.current), isTrue, reason: 'restore defaults of $section');
        expect(kit.settingsStore.current.onboardingCompleted, isTrue);
      });
    }

    testWidgets('startup resets the login entry too', (tester) async {
      final kit = FakeKit(settings: const AppSettings(onboardingCompleted: true, desktop: DesktopSettings(launchAtLogin: true, startMinimized: true)));
      kit.startup.enabled = true;
      await pumpSettings(tester, kit: kit, section: 'startup');
      await tapVisible(tester, find.byKey(const ValueKey('settings.restoreSection')));
      await tester.tap(find.text(l10n.actionRestoreDefaults));
      await pumpFrames(tester);
      expect(kit.startup.enabled, isFalse);
      expect(kit.settingsStore.current.desktop.launchAtLogin, isFalse);
      expect(kit.settingsStore.current.desktop.startMinimized, isFalse);
    });
  });
}
