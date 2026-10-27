import 'package:fermata/core/contracts/platform.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/actions/command_registry.dart';
import 'package:fermata/ui/pages/settings/sections/shortcuts_section.dart';
import 'package:fermata/ui/pages/settings/settings_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'settings_harness.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('keyboard shortcuts', () {
    testWidgets('records a new binding from key events and stores it', (tester) async {
      final kit = await pumpSettings(tester, section: 'shortcuts');
      expect(find.descendant(of: find.byKey(const ValueKey('settings.shortcut.like.change')), matching: find.text('Ctrl+L')), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('settings.shortcut.like.change')));
      expect(find.text(l10n.settingsShortcutWaiting), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(find.descendant(of: find.byKey(const ValueKey('settings.shortcutRecorder.value')), matching: find.text('Ctrl+Shift+J')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings.shortcutRecorder.save')));
      await pumpFrames(tester);
      expect(kit.settingsStore.current.shortcuts.bindingFor('like'), 'ctrl+shift+j');
    });

    testWidgets('Escape cancels recording', (tester) async {
      final kit = await pumpSettings(tester, section: 'shortcuts');
      await tapVisible(tester, find.byKey(const ValueKey('settings.shortcut.queue.change')));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumpFrames(tester);
      expect(find.text(l10n.settingsShortcutWaiting), findsNothing);
      expect(kit.settingsStore.current.shortcuts.bindingFor('queue'), 'ctrl+q');
    });

    testWidgets('conflicts are highlighted and can be reset', (tester) async {
      final bindings = Map<String, String>.of(ShortcutActions.defaults)..['like'] = 'ctrl+k';
      final kit = FakeKit(settings: AppSettings(onboardingCompleted: true, shortcuts: ShortcutSettings(bindings: bindings)));
      await pumpSettings(tester, kit: kit, section: 'shortcuts');
      final likeProblem = find.byKey(const ValueKey('settings.shortcut.like.problem'));
      expect(likeProblem, findsOneWidget);
      expect(tester.widget<Text>(likeProblem).data, l10n.settingsShortcutConflict(CommandRegistry.labelFor(l10n, 'commandPalette')));
      expect(find.byKey(const ValueKey('settings.shortcut.commandPalette.problem')), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('settings.shortcut.like.menu')));
      await tester.tap(find.text(l10n.settingsShortcutReset));
      await pumpFrames(tester);
      expect(kit.settingsStore.current.shortcuts.bindingFor('like'), 'ctrl+l');
      expect(find.byKey(const ValueKey('settings.shortcut.like.problem')), findsNothing);
    });

    test('conflict detection compares canonical bindings', () {
      const s = ShortcutSettings(bindings: {'playPause': 'Ctrl+K', 'commandPalette': 'ctrl+k', 'like': ''});
      final c = shortcutConflicts(s, ['playPause', 'commandPalette', 'like']);
      expect(c['playPause'], ['commandPalette']);
      expect(c.containsKey('like'), isFalse);
      expect(canonicalBinding('Shift+Ctrl+A'), 'ctrl+shift+a');
      expect(canonicalBinding(''), isNull);
    });

    testWidgets('global hotkeys: toggle applies, registration errors are shown, global needs a modifier', (tester) async {
      final kit = FakeKit();
      kit.hotkeys.registrationErrors = {'global.next': 'Couldn’t register “Ctrl+Alt+→”.'};
      await pumpSettings(tester, kit: kit, section: 'shortcuts');
      await scrollTo(tester, find.byKey(const ValueKey('settings.shortcut.global.next')));
      expect(find.text('Couldn’t register “Ctrl+Alt+→”.'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('setting.globalHotkeys')));
      expect(kit.settingsStore.current.shortcuts.globalHotkeysEnabled, isFalse);
      expect(kit.hotkeys.appliedEnabled, isFalse);

      await tapVisible(tester, find.byKey(const ValueKey('setting.globalHotkeys')));
      expect(kit.hotkeys.appliedEnabled, isTrue);
      await tapVisible(tester, find.byKey(const ValueKey('settings.shortcut.global.playPause.change')));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      expect(find.text(l10n.settingsShortcutNeedsModifier), findsOneWidget);
      expect(tester.widget<FilledButton>(find.descendant(of: find.byKey(const ValueKey('settings.shortcutRecorder.save')), matching: find.byType(FilledButton))).onPressed, isNull);
    });

    testWidgets('unsupported global hotkeys are disabled with the reason', (tester) async {
      final kit = FakeKit();
      kit.hotkeys.isSupported = false;
      await pumpSettings(tester, kit: kit, section: 'shortcuts', env: const {'XDG_SESSION_TYPE': 'wayland'});
      await scrollTo(tester, find.byKey(const ValueKey('setting.globalHotkeys')));
      expect(find.text(l10n.desktopHotkeysUnsupportedWayland), findsOneWidget);
      expect(tester.widget<Switch>(find.descendant(of: find.byKey(const ValueKey('setting.globalHotkeys')), matching: find.byType(Switch))).onChanged, isNull);
    });
  });

  group('tray, window and startup', () {
    testWidgets('tray unavailable notice uses the hook reason; close behaviour persists', (tester) async {
      final kit = FakeKit();
      kit.lifecycle.trayAvailable = false;
      await pumpSettings(tester, kit: kit, section: 'desktop', hooks: SettingsHooks(trayUnavailableReason: () => 'No tray here.'));
      expect(find.text('No tray here.'), findsOneWidget);
      final dropdown = find.descendant(of: find.byKey(const ValueKey('setting.closeBehavior')), matching: find.byType(DropdownButton<CloseBehavior>));
      // Without a tray the option says "minimized".
      expect(find.descendant(of: dropdown, matching: find.text(l10n.settingsCloseMinimize)), findsOneWidget);
      await tester.tap(dropdown);
      await pumpFrames(tester, count: 3);
      await tester.tap(find.text(l10n.settingsCloseAsk).last);
      await pumpFrames(tester, count: 3);
      expect(kit.settingsStore.current.desktop.closeBehavior, CloseBehavior.ask);
    });

    testWidgets('GNOME fallback reason without a hook', (tester) async {
      final kit = FakeKit();
      kit.lifecycle.trayAvailable = false;
      await pumpSettings(tester, kit: kit, section: 'desktop', env: const {'XDG_CURRENT_DESKTOP': 'ubuntu:GNOME'});
      expect(find.text(l10n.desktopTrayUnavailableGnome), findsOneWidget);
    });

    testWidgets('launch at login calls the StartupManager and start minimized rewrites the entry', (tester) async {
      final kit = FakeKit();
      await pumpSettings(tester, kit: kit, section: 'startup');
      await tapVisible(tester, find.byKey(const ValueKey('setting.launchAtLogin')));
      expect(kit.startup.enabled, isTrue);
      expect(kit.settingsStore.current.desktop.launchAtLogin, isTrue);
      await tapVisible(tester, find.byKey(const ValueKey('setting.startMinimized')));
      expect(kit.startup.startMinimized, isTrue);
      expect(kit.settingsStore.current.desktop.startMinimized, isTrue);
    });

    testWidgets('startup is disabled with an explanation when unsupported', (tester) async {
      final kit = FakeKit();
      kit.startup.isSupported = false;
      await pumpSettings(tester, kit: kit, section: 'startup');
      expect(find.text(l10n.settingsLaunchAtLoginUnsupported), findsOneWidget);
    });
  });

  group('Android background & notifications', () {
    testWidgets('battery optimization opt-in and notification permission request', (tester) async {
      final kit = FakeKit(os: HostOs.android);
      kit.androidSystem
        ..isSupported = true
        ..notifications = false;
      await pumpSettings(tester, kit: kit, section: 'background', size: TestSizes.compact, hooks: SettingsHooks(androidRestartRequired: () => true));
      expect(find.text(l10n.settingsRestartRequired), findsOneWidget);
      expect(find.text(l10n.settingsBatteryOptimized), findsOneWidget);
      expect(kit.androidSystem.calls, isEmpty, reason: 'nothing is requested without a tap');
      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.batteryOptimization')), matching: find.text(l10n.settingsAllowBackground)));
      expect(kit.androidSystem.calls, ['requestIgnoreBatteryOptimizations']);
      await pumpFrames(tester);
      expect(find.text(l10n.settingsBatteryUnrestricted), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('setting.stopForegroundOnPause')));
      expect(kit.settingsStore.current.android.stopForegroundOnPause, isFalse);

      await pumpSettings(tester, kit: kit, section: 'notifications', size: TestSizes.compact);
      expect(find.text(l10n.settingsNotificationPermissionMissing), findsOneWidget);
      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.notificationPermission')), matching: find.text(l10n.settingsAllow)));
      expect(kit.androidSystem.calls, contains('requestNotificationPermission'));
      await pumpFrames(tester);
      expect(find.text(l10n.settingsPermissionAllowed), findsOneWidget);
    });

    testWidgets('desktop explains that closing the window keeps music playing', (tester) async {
      await pumpSettings(tester, section: 'background');
      expect(find.byKey(const ValueKey('settings.backgroundDesktop')), findsOneWidget);
      expect(find.byKey(const ValueKey('setting.stopForegroundOnPause')), findsNothing);
    });

    testWidgets('notification toggles are disabled with an explanation when unsupported', (tester) async {
      final kit = FakeKit();
      kit.notifier.isSupported = false;
      await pumpSettings(tester, kit: kit, section: 'notifications');
      expect(find.text(l10n.settingsNotificationsUnsupported), findsNWidgets(2));
    });
  });
}
