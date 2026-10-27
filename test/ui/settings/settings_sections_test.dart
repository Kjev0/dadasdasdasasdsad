import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/actions/command_registry.dart';
import 'package:fermata/ui/actions/routes.dart';
import 'package:fermata/ui/pages/settings/settings_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'settings_harness.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('every section renders', () {
    for (final id in SettingsSections.all) {
      testWidgets('$id on Linux (two-pane)', (tester) async {
        final kit = FakeKit(sources: [oauthSource('soundcloud', name: 'SoundCloud')]);
        await pumpSettings(tester, kit: kit, section: id);
        expect(tester.takeException(), isNull);
        expect(find.byKey(ValueKey('settings.body.$id')), findsOneWidget);
        // Title in the list and as the section heading.
        expect(find.text(CommandRegistry.sectionLabel(l10n, id)), findsWidgets);
      });

      testWidgets('$id on Android (single pane)', (tester) async {
        final kit = FakeKit(os: HostOs.android, sources: [oauthSource('soundcloud', name: 'SoundCloud')]);
        kit.androidSystem.isSupported = true;
        await pumpSettings(tester, kit: kit, section: id, size: TestSizes.compact);
        expect(tester.takeException(), isNull);
        // App bar title.
        expect(find.widgetWithText(AppBar, CommandRegistry.sectionLabel(l10n, id)), findsOneWidget);
        final info = settingsSectionById(id)!;
        if (info.desktopOnly) {
          expect(find.text(l10n.settingsSectionUnavailable), findsOneWidget);
        }
      });
    }
  });

  testWidgets('section list hides desktop-only sections on Android', (tester) async {
    final kit = FakeKit(os: HostOs.android);
    await pumpSettings(tester, kit: kit, size: TestSizes.compact);
    expect(find.byKey(const ValueKey('settings.section.appearance')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings.section.desktop')), findsNothing);
    expect(find.byKey(const ValueKey('settings.section.startup')), findsNothing);
    expect(find.byKey(const ValueKey('settings.section.shortcuts')), findsNothing);
  });

  testWidgets('two-pane: selecting a section shows it without navigation', (tester) async {
    await pumpSettings(tester);
    expect(find.byKey(const ValueKey('settings.body.appearance')), findsOneWidget);
    await openSection(tester, 'privacy');
    expect(find.byKey(const ValueKey('settings.body.privacy')), findsOneWidget);
    expect(find.text(l10n.settingsNoTrackingTitle), findsOneWidget);
  });

  testWidgets('search filters settings and opens the matching section', (tester) async {
    await pumpSettings(tester);
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('settings.search')), matching: find.byType(TextField)), 'crossf');
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('settings.section.appearance')), findsNothing);
    final hit = find.byKey(ValueKey('settings.hit.playback.${l10n.settingsCrossfade}'));
    expect(hit, findsOneWidget);
    await tester.tap(hit);
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('settings.body.playback')), findsOneWidget);

    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('settings.search')), matching: find.byType(TextField)), 'zzzz');
    await pumpFrames(tester);
    expect(find.text(l10n.settingsSearchNoResults('zzzz')), findsOneWidget);
  });

  test('search is case- and accent-insensitive', () {
    const linux = PlatformInfo(os: HostOs.linux);
    expect(searchSettings(l10n, linux, 'LIQUID').map((h) => h.section.id), contains(SettingsSections.glass));
    expect(foldForSearch('Café Æble'), 'cafe æble');
    expect(searchSettings(l10n, const PlatformInfo(os: HostOs.android), 'tray'), isEmpty);
  });

  testWidgets('restore all defaults (confirmed) resets everything but onboarding and the download folder', (tester) async {
    final kit = FakeKit(
      settings: const AppSettings(
        onboardingCompleted: true,
        appearance: AppearanceSettings(liquidGlass: true, themeMode: AppThemeMode.light),
        downloads: DownloadSettings(directory: '/music/dl', wifiOnly: false),
        desktop: DesktopSettings(launchAtLogin: true),
        playback: PlaybackSettings(speed: 1.5, volume: 0.4),
      ),
    );
    kit.startup.enabled = true;
    await pumpSettings(tester, kit: kit);
    await tapVisible(tester, find.byKey(const ValueKey('settings.restoreAll')));
    expect(find.text(l10n.settingsRestoreAllTitle), findsOneWidget);
    await tester.tap(find.text(l10n.actionRestoreDefaults));
    await pumpFrames(tester);
    final s = kit.settingsStore.current;
    expect(s.onboardingCompleted, isTrue);
    expect(s.appearance.liquidGlass, isFalse);
    expect(s.appearance.themeMode, AppThemeMode.dark);
    expect(s.downloads.directory, '/music/dl');
    expect(s.downloads.wifiOnly, isTrue);
    expect(s.playback.volume, 0.4);
    expect(s.playback.speed, 1.0);
    expect(kit.startup.enabled, isFalse);
    expect(kit.hotkeys.appliedEnabled, isTrue);
    expect(kit.playback.called('setSpeed'), isTrue);
  });

  testWidgets('narrow list navigates to /settings/<section> and back', (tester) async {
    final kit = await pumpFermata(tester, initialRoute: '/settings', size: TestSizes.compact, overrides: settingsOverrides());
    expect(find.byKey(const ValueKey('settings.section.playback')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings.section.playback')));
    await pumpFrames(tester);
    expect(appRouter(tester).routerDelegate.currentConfiguration.uri.path, '/settings/playback');
    expect(find.widgetWithText(AppBar, l10n.shellSectionPlayback), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.settingsBack));
    await pumpFrames(tester);
    expect(appRouter(tester).routerDelegate.currentConfiguration.uri.path, '/settings');
    expect(kit.playback.called('pause'), isFalse);
  });
}
