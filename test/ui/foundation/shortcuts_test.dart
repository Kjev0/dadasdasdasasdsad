import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/actions/command_registry.dart';
import 'package:fermata/ui/actions/shortcut_binding.dart';
import 'package:fermata/ui/pages/search/search_page.dart';
import 'package:fermata/ui/pages/settings/settings_page.dart';
import 'package:fermata/ui/player/now_playing_page.dart';
import 'package:fermata/ui/player/queue_page.dart';
import 'package:fermata/ui/shell/command_palette.dart';
import 'package:fermata/ui/shell/fermata_shortcuts.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

Future<FakeKit> _pump(WidgetTester tester, {AppSettings? settings}) async {
  final kit = FakeKit(
    tracks: testTracks(3),
    settings: settings ?? const AppSettings(onboardingCompleted: true),
  );
  kit.playback.load(kit.tracks.all, playing: false);
  await pumpFermata(tester, kit: kit);
  return kit;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key, {bool ctrl = false, bool shift = false}) async {
  if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await pumpFrames(tester, count: 4);
}

void main() {
  group('ShortcutBinding', () {
    test('parses and serializes accelerators', () {
      final s = ShortcutBinding.parse('ctrl+alt+space')!;
      expect(s.key, LogicalKeyboardKey.space);
      expect(s.control && s.alt && !s.shift && !s.meta, isTrue);
      expect(ShortcutBinding.serialize(s), 'ctrl+alt+space');
      expect(ShortcutBinding.parse('Ctrl+K')!.key, LogicalKeyboardKey.keyK);
      expect(ShortcutBinding.parse('shift+right')!.key, LogicalKeyboardKey.arrowRight);
      expect(ShortcutBinding.parse('ctrl+comma')!.key, LogicalKeyboardKey.comma);
      expect(ShortcutBinding.parse('f5')!.key, LogicalKeyboardKey.f5);
      expect(ShortcutBinding.parse('mediaPlayPause')!.key, LogicalKeyboardKey.mediaPlayPause);
      expect(ShortcutBinding.parse('ctrl+7')!.key, LogicalKeyboardKey.digit7);
    });

    test('rejects invalid accelerators', () {
      expect(ShortcutBinding.parse(''), isNull);
      expect(ShortcutBinding.parse('ctrl+'), isNull);
      expect(ShortcutBinding.parse('ctrl+a+b'), isNull);
      expect(ShortcutBinding.parse('hyper+x'), isNull);
    });

    test('formats for display', () {
      expect(ShortcutBinding.format('ctrl+k'), 'Ctrl+K');
      expect(ShortcutBinding.format('shift+right'), 'Shift+→');
      expect(ShortcutBinding.format('space'), 'Space');
      expect(ShortcutBinding.format('ctrl+alt+f'), 'Ctrl+Alt+F');
    });

    test('text-field safety', () {
      expect(ShortcutBinding.allowedInTextField(ShortcutBinding.parse('space')!), isFalse);
      expect(ShortcutBinding.allowedInTextField(ShortcutBinding.parse('shift+right')!), isFalse);
      expect(ShortcutBinding.allowedInTextField(ShortcutBinding.parse('ctrl+right')!), isFalse);
      expect(ShortcutBinding.allowedInTextField(ShortcutBinding.parse('ctrl+a')!), isFalse);
      expect(ShortcutBinding.allowedInTextField(ShortcutBinding.parse('ctrl+k')!), isTrue);
    });

    test('every default in-app binding parses and has a label', () {
      final l10n = AppLocalizationsEn();
      for (final action in ShortcutActions.defaults.keys) {
        expect(ShortcutBinding.parse(ShortcutActions.defaults[action]), isNotNull, reason: action);
        expect(CommandRegistry.labelFor(l10n, action), isNot(action), reason: action);
      }
      expect(CommandRegistry.shortcutActions, isNot(contains(ShortcutActions.globalPlayPause)));
    });

    test('buildShortcutMap uses custom bindings and skips invalid ones', () {
      final map = buildShortcutMap(ShortcutSettings(bindings: {
        ...ShortcutActions.defaults,
        ShortcutActions.next: 'ctrl+n',
        ShortcutActions.previous: 'nonsense',
      }));
      final intents = map.values.cast<FermataCommandIntent>();
      expect(intents.map((i) => i.actionId), isNot(contains(ShortcutActions.previous)));
      final next = map.entries.firstWhere((e) => (e.value as FermataCommandIntent).actionId == ShortcutActions.next);
      expect((next.key as SingleActivator).trigger, LogicalKeyboardKey.keyN);
    });
  });

  group('in-app shortcuts', () {
    testWidgets('space toggles play/pause', (tester) async {
      final kit = await _pump(tester);
      await _press(tester, LogicalKeyboardKey.space);
      expect(kit.playback.countOf('togglePlayPause'), 1);
    });

    testWidgets('space does not fire while typing in a text field', (tester) async {
      final kit = await _pump(tester);
      final rootContext = tester.element(find.byType(SearchPage).evaluate().isEmpty ? find.text('Home').last : find.byType(SearchPage));
      showDialog<void>(context: rootContext, builder: (_) => const Dialog(child: TextField(autofocus: true)));
      await pumpFrames(tester);
      await tester.enterText(find.byType(TextField), 'hello');
      await _press(tester, LogicalKeyboardKey.space);
      await _press(tester, LogicalKeyboardKey.arrowLeft, shift: true);
      expect(kit.playback.called('togglePlayPause'), isFalse);
      expect(kit.playback.called('seekRelative'), isFalse);
    });

    testWidgets('player shortcuts call the controller', (tester) async {
      final kit = await _pump(tester);
      await _press(tester, LogicalKeyboardKey.arrowRight, ctrl: true);
      expect(kit.playback.called('next'), isTrue);
      await _press(tester, LogicalKeyboardKey.arrowLeft, ctrl: true);
      expect(kit.playback.called('previous'), isTrue);
      await _press(tester, LogicalKeyboardKey.arrowRight, shift: true);
      expect(kit.playback.argsOf('seekRelative'), [const Duration(seconds: 10)]);
      await _press(tester, LogicalKeyboardKey.arrowLeft, shift: true);
      expect(kit.playback.argsOf('seekRelative'), [const Duration(seconds: -10)]);
      await _press(tester, LogicalKeyboardKey.arrowDown, ctrl: true);
      expect(kit.playback.argsOf('setVolume').single as double, closeTo(0.95, 0.001));
      await _press(tester, LogicalKeyboardKey.keyS, ctrl: true);
      expect(kit.playback.argsOf('setShuffle'), [true]);
      await _press(tester, LogicalKeyboardKey.keyR, ctrl: true);
      expect(kit.playback.called('cycleRepeat'), isTrue);
      await _press(tester, LogicalKeyboardKey.keyL, ctrl: true);
      expect(kit.favorites.ids, contains(kit.playback.snapshot.track!.id));
    });

    testWidgets('navigation shortcuts', (tester) async {
      await _pump(tester);
      await _press(tester, LogicalKeyboardKey.keyQ, ctrl: true);
      expect(find.byType(QueuePage), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.comma, ctrl: true);
      expect(find.byType(SettingsPage), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.keyF, ctrl: true);
      expect(find.byType(SearchPage), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.keyP, ctrl: true);
      expect(find.byType(NowPlayingPage), findsOneWidget);
    });

    testWidgets('bindings come from settings and update live', (tester) async {
      final kit = await _pump(tester);
      await kit.settingsStore.update((s) => s.copyWith(
            shortcuts: s.shortcuts.copyWith(bindings: {...s.shortcuts.bindings, ShortcutActions.next: 'ctrl+n'}),
          ));
      await pumpFrames(tester);
      await _press(tester, LogicalKeyboardKey.arrowRight, ctrl: true);
      expect(kit.playback.called('next'), isFalse);
      await _press(tester, LogicalKeyboardKey.keyN, ctrl: true);
      expect(kit.playback.called('next'), isTrue);
    });

    testWidgets('Ctrl+K opens the command palette (also from a text field)', (tester) async {
      await _pump(tester);
      await _press(tester, LogicalKeyboardKey.keyK, ctrl: true);
      expect(find.byType(CommandPalette), findsOneWidget);
      // Second press while the palette's search field is focused is a no-op.
      await _press(tester, LogicalKeyboardKey.keyK, ctrl: true);
      expect(find.byType(CommandPalette), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(CommandPalette), findsNothing);
    });
  });
}
