import 'package:fermata/app/providers.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/performance_profiles.dart';
import 'package:fermata/ui/pages/settings/sections/performance_section.dart';
import 'package:fermata/ui/pages/settings/settings_format.dart';
import 'package:fermata/ui/widgets/glass/glass_preview.dart';
import 'package:fermata/ui/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'settings_harness.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('Liquid Glass', () {
    testWidgets('is off by default and the live preview reacts to the toggle', (tester) async {
      final kit = await pumpSettings(tester, section: 'glass');
      expect(kit.settingsStore.current.appearance.liquidGlass, isFalse);
      expect(switchValue(tester, 'setting.liquidGlass'), isFalse);
      expect(find.byType(GlassPreview), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.shellGlassModeSolid), findsOneWidget);
      // Intensity is disabled with an explanation while glass is off.
      expect(find.text(l10n.settingsGlassIntensityDisabled), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('setting.liquidGlass')));
      await pumpFrames(tester);
      expect(kit.settingsStore.current.appearance.liquidGlass, isTrue);
      expect(find.bySemanticsLabel(l10n.shellGlassModeBlurred), findsOneWidget);
      expect(find.text(l10n.settingsGlassIntensityDisabled), findsNothing);
    });

    testWidgets('preview follows the intensity slider while dragging; the value is stored on release', (tester) async {
      final kit = FakeKit(settings: const AppSettings(onboardingCompleted: true, appearance: AppearanceSettings(liquidGlass: true)));
      await pumpSettings(tester, kit: kit, section: 'glass');
      final slider = find.descendant(of: find.byKey(const ValueKey('setting.glassIntensity')), matching: find.byType(Slider));
      final gesture = await tester.startGesture(tester.getCenter(slider));
      await gesture.moveBy(const Offset(-150, 0));
      await tester.pump();
      final preview = tester.widget<GlassPreview>(find.byType(GlassPreview));
      expect(preview.intensity, isNotNull);
      expect(preview.intensity!, lessThan(0.6));
      expect(kit.settingsStore.current.appearance.glassIntensity, 0.6, reason: 'not committed while dragging');
      await gesture.up();
      await pumpFrames(tester, count: 3);
      expect(kit.settingsStore.current.appearance.glassIntensity, lessThan(0.6));
      expect(tester.widget<GlassPreview>(find.byType(GlassPreview)).intensity, isNull);
    });

    testWidgets('notes the lighter translucent style when the performance mode disables blur', (tester) async {
      final kit = FakeKit(settings: const AppSettings(onboardingCompleted: true, appearance: AppearanceSettings(liquidGlass: true)));
      await pumpSettings(tester, kit: kit, section: 'glass');
      expect(find.byKey(const ValueKey('settings.glassBlurOffNote')), findsNothing);
      await tester.runAsync(() => kit.settingsStore.applyPerformanceMode(PerformanceMode.batterySaver));
      await pumpFrames(tester);
      expect(find.byKey(const ValueKey('settings.glassBlurOffNote')), findsOneWidget);
      expect(find.text(l10n.settingsGlassBlurOff), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.shellGlassModeTranslucent), findsOneWidget);
    });
  });

  group('Performance', () {
    testWidgets('mode cards list the concrete effects and selecting one applies the preset', (tester) async {
      final kit = await pumpSettings(tester, section: 'performance');
      // Effects text from PerformanceProfiles.effectsOf.
      expect(find.text(effectsSummary(l10n, PerformanceMode.batterySaver)), findsOneWidget);
      expect(effectsSummary(l10n, PerformanceMode.performance), contains('${l10n.settingAnimations}: ${l10n.settingsValueReduced}'));
      expect(effectsSummary(l10n, PerformanceMode.performance), contains('${l10n.settingBlur}: ${l10n.settingsOff}'));

      await tapVisible(tester, find.byKey(const ValueKey('settings.mode.batterySaver')));
      final p = kit.settingsStore.current.performance;
      expect(p.mode, PerformanceMode.batterySaver);
      expect(p.animations, AnimationLevel.off);
      expect(p.blur, isFalse);
      expect(p.backgroundSync, isFalse);
      expect(find.text(l10n.settingsActiveNow(l10n.settingsModeBatterySaver)), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('settings.mode.dataSaver')));
      expect(kit.settingsStore.current.audioQuality.streaming.name, 'low');
      expect(kit.settingsStore.current.downloads.wifiOnly, isTrue);
    });

    testWidgets('a granular change flips the mode to Custom', (tester) async {
      final kit = await pumpSettings(tester, section: 'performance');
      expect(kit.settingsStore.current.performance.mode, PerformanceMode.balanced);
      final row = find.byKey(const ValueKey('setting.prefetchArtwork'));
      await scrollTo(tester, row);
      await tapVisible(tester, row);
      final p = kit.settingsStore.current.performance;
      expect(p.mode, PerformanceMode.custom);
      expect(p.prefetchArtwork, isFalse);
      expect(p.blur, isTrue, reason: 'other values are kept');
    });

    testWidgets('"Active now" reflects the OS reduce-motion preference', (tester) async {
      final kit = await pumpSettings(tester, section: 'performance');
      final container = ProviderScope.containerOf(tester.element(find.byType(SettingsPage)));
      container.read(systemReduceMotionProvider.notifier).set(true);
      await pumpFrames(tester);
      expect(find.text(l10n.settingsActiveNowReducedMotion), findsOneWidget);
      expect(kit.settingsStore.current.performance.animations, AnimationLevel.full);
    });

    testWidgets('wording never promises measured gains', (tester) async {
      for (final m in PerformanceMode.values) {
        final text = '${performanceModeDescription(l10n, m)} ${effectsSummary(l10n, m)}';
        expect(text, isNot(matches(RegExp(r'\d+\s*%|faster|longer battery', caseSensitive: false))), reason: m.name);
      }
    });

    testWidgets('battery & data saver shortcuts apply and release the presets', (tester) async {
      final kit = FakeKit(os: HostOs.android);
      await pumpSettings(tester, kit: kit, section: 'savers', size: TestSizes.compact);
      expect(find.text(l10n.settingsSaversAndroidNote), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('settings.saver.batterySaver')));
      expect(kit.settingsStore.current.performance.mode, PerformanceMode.batterySaver);
      expect(find.text(l10n.settingsSaverTurnOff), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('settings.saver.batterySaver')));
      expect(kit.settingsStore.current.performance.mode, PerformanceMode.balanced);
    });
  });

  test('effect labels are localized for every preset', () {
    for (final m in PerformanceMode.values) {
      for (final e in PerformanceProfiles.effectsOf(m)) {
        expect(effectSettingLabel(l10n, e.settingKey), isNot(e.settingKey), reason: e.settingKey);
        expect(effectValueLabel(l10n, e.valueLabel), isNot(e.valueLabel), reason: e.valueLabel);
      }
    }
  });

  test('byte and interval formatting', () {
    expect(formatBytes(0, locale: 'en'), '0 B');
    expect(formatBytes(1536, locale: 'en'), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024 * 1024, locale: 'en'), '5.0 GB');
    expect(formatBytes(1536, locale: 'da'), '1,5 KB');
    expect(intervalLabel(l10n, 30), '30 min');
    expect(intervalLabel(l10n, 120), '2 h');
  });
}
