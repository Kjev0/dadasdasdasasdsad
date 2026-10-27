import 'package:fermata/app/providers.dart';
import 'package:fermata/core/contracts/platform.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/design/design.dart';
import 'package:fermata/ui/pages/home/home_page.dart';
import 'package:fermata/ui/shell/sidebar.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

BuildContext _pageContext(WidgetTester tester) => tester.element(find.byType(HomePage));

void main() {
  group('FermataApp', () {
    testWidgets('dark theme by default, light and system from settings', (tester) async {
      final kit = await pumpFermata(tester);
      expect(Theme.of(_pageContext(tester)).brightness, Brightness.dark);
      expect(_pageContext(tester).colors.bg, FermataPalette.darkBg);

      await kit.settingsStore.update((s) => s.copyWith(appearance: s.appearance.copyWith(themeMode: AppThemeMode.light)));
      await pumpFrames(tester);
      expect(Theme.of(_pageContext(tester)).brightness, Brightness.light);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await kit.settingsStore.update((s) => s.copyWith(appearance: s.appearance.copyWith(themeMode: AppThemeMode.system)));
      await pumpFrames(tester);
      expect(Theme.of(_pageContext(tester)).brightness, Brightness.dark);
    });

    testWidgets('accent and high contrast come from settings', (tester) async {
      final kit = await pumpFermata(tester);
      await kit.settingsStore.update((s) => s.copyWith(
            appearance: s.appearance.copyWith(accent: AccentChoice.mint),
            accessibility: s.accessibility.copyWith(highContrast: true),
          ));
      await pumpFrames(tester);
      final c = _pageContext(tester).colors;
      expect(c.accent, FermataPalette.mint);
      expect(c.textPrimary, const Color(0xFFFFFFFF));
    });

    testWidgets('locale follows settings (Danish)', (tester) async {
      final kit = await pumpFermata(tester);
      expect(find.descendant(of: find.byType(Sidebar), matching: find.text('Home')), findsOneWidget);
      await kit.settingsStore.update((s) => s.copyWith(localeCode: 'da'));
      await pumpFrames(tester);
      expect(find.descendant(of: find.byType(Sidebar), matching: find.text('Hjem')), findsOneWidget);
      expect(find.descendant(of: find.byType(Sidebar), matching: find.text('Synes godt om')), findsOneWidget);
    });

    testWidgets('text scale combines the setting with the system scale', (tester) async {
      final kit = await pumpFermata(tester);
      expect(MediaQuery.textScalerOf(_pageContext(tester)).scale(10), closeTo(10, 0.001));
      await kit.settingsStore.update((s) => s.copyWith(accessibility: s.accessibility.copyWith(textScale: 1.4)));
      await pumpFrames(tester);
      expect(MediaQuery.textScalerOf(_pageContext(tester)).scale(10), closeTo(14, 0.001));

      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpFrames(tester);
      expect(MediaQuery.textScalerOf(_pageContext(tester)).scale(10), closeTo(21, 0.001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text (2.1×) reflows at every breakpoint without overflow', (tester) async {
      final kit = FakeKit(
        tracks: testTracks(3),
        settings: const AppSettings(onboardingCompleted: true, accessibility: AccessibilitySettings(textScale: 1.4)),
      );
      kit.playlists.add(testPlaylist('p1', name: 'A playlist with a rather long name'));
      kit.playback.load(kit.tracks.all, playing: true);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpFermata(tester, kit: kit);
      for (final size in [TestSizes.expanded, TestSizes.medium, TestSizes.compact]) {
        setTestWindowSize(tester, size);
        for (final route in ['/home', '/queue', '/now-playing']) {
          await goTo(tester, route);
          expect(tester.takeException(), isNull, reason: '$route at $size');
        }
      }
    });

    testWidgets('OS reduce-motion updates systemReduceMotionProvider', (tester) async {
      await pumpFermata(tester);
      final container = appContainer(tester);
      expect(container.read(systemReduceMotionProvider), isFalse);
      expect(container.read(effectiveVisualsProvider).animate, isTrue);

      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpFrames(tester);
      expect(container.read(systemReduceMotionProvider), isTrue);
      expect(container.read(effectiveVisualsProvider).animate, isFalse);
    });

    testWidgets('registers the close-to-tray dialog with the lifecycle controller', (tester) async {
      final kit = await pumpFermata(tester);
      expect(kit.lifecycle.delegate, isNotNull);
      final choice = kit.lifecycle.delegate!();
      await pumpFrames(tester);
      expect(find.text('Close Fermata?'), findsOneWidget);
      await tester.tap(find.text('Remember my choice'));
      await tester.pump();
      await tester.tap(find.text('Keep playing in tray'));
      await pumpFrames(tester);
      expect(await choice, (CloseChoice.minimizeToTray, true));

      final second = kit.lifecycle.delegate!();
      await pumpFrames(tester);
      await tester.tap(find.text('Quit'));
      await pumpFrames(tester);
      expect(await second, (CloseChoice.quit, false));
    });

    testWidgets('a skipped unplayable track shows a toast with the reason', (tester) async {
      final kit = FakeKit(tracks: testTracks(2));
      kit.playback.load(kit.tracks.all, playing: true);
      await pumpFermata(tester, kit: kit);
      kit.playback.emitEvent(PlaybackFailed(
        kit.playback.queue.items.first,
        UnplayableTrackException(kit.tracks.all.first.id, AvailabilityReason.deleted),
        skipped: true,
      ));
      await pumpFrames(tester);
      expect(find.text("Skipped a track that can't be played: This track was deleted."), findsOneWidget);
    });
  });
}
