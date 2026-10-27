import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/platform/desktop/desktop_l10n.dart';
import 'package:fermata/platform/desktop/hotkeys/accelerator.dart';
import 'package:fermata/platform/desktop/hotkeys/global_hotkey_service.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import 'fakes.dart';

void main() {
  group('Accelerator.parse', () {
    test('parses the documented format', () {
      final a = Accelerator.parse('ctrl+alt+space');
      expect(a.modifiers, {AcceleratorModifier.ctrl, AcceleratorModifier.alt});
      expect(a.key, 'space');
      expect(a.physicalKey, PhysicalKeyboardKey.space);
      expect(a.canonical, 'ctrl+alt+space');
    });

    test('all default bindings parse', () {
      for (final e in ShortcutActions.defaults.entries) {
        expect(Accelerator.tryParse(e.value), isNotNull, reason: '${e.key}=${e.value}');
      }
    });

    test('case-insensitive, whitespace-tolerant, aliases, canonical order', () {
      expect(Accelerator.parse(' Shift + CTRL + Left ').canonical, 'ctrl+shift+left');
      expect(Accelerator.parse('control+option+super+k').canonical, 'ctrl+alt+meta+k');
      expect(Accelerator.parse('win+f5').canonical, 'meta+f5');
      expect(Accelerator.parse('esc').key, 'escape');
      expect(Accelerator.parse('MEDIAPLAYPAUSE').key, 'mediaPlayPause');
      expect(Accelerator.parse('ctrl+pageup').key, 'pageUp');
      expect(Accelerator.parse('alt+shift+9').physicalKey, PhysicalKeyboardKey.digit9);
      expect(Accelerator.parse('ctrl+comma').physicalKey, PhysicalKeyboardKey.comma);
      expect(Accelerator.parse('alt+ctrl+x'), Accelerator.parse('ctrl+alt+x'));
    });

    test('maps keys to physical keys', () {
      expect(Accelerator.parse('a').physicalKey, PhysicalKeyboardKey.keyA);
      expect(Accelerator.parse('z').physicalKey, PhysicalKeyboardKey.keyZ);
      expect(Accelerator.parse('f12').physicalKey, PhysicalKeyboardKey.f12);
      expect(Accelerator.parse('right').physicalKey, PhysicalKeyboardKey.arrowRight);
      expect(Accelerator.parse('mediaNext').physicalKey, PhysicalKeyboardKey.mediaTrackNext);
      expect(Accelerator.parse('mediaPrevious').physicalKey, PhysicalKeyboardKey.mediaTrackPrevious);
      expect(Accelerator.parse('mediaStop').physicalKey, PhysicalKeyboardKey.mediaStop);
    });

    test('rejects malformed input', () {
      for (final bad in ['', '   ', 'ctrl+', '+a', 'ctrl++a', 'ctrl+alt', 'ctrl+ctrl+a', 'a+b', 'ctrl+banana', 'f13', 'hyper+a']) {
        expect(() => Accelerator.parse(bad), throwsFormatException, reason: '"$bad"');
        expect(Accelerator.tryParse(bad), isNull);
      }
    });

    test('global safety: plain letters need a modifier, media/function keys do not', () {
      expect(Accelerator.parse('a').isSafeAsGlobal, isFalse);
      expect(Accelerator.parse('space').isSafeAsGlobal, isFalse);
      expect(Accelerator.parse('shift+a').isSafeAsGlobal, isTrue);
      expect(Accelerator.parse('mediaPlayPause').isSafeAsGlobal, isTrue);
      expect(Accelerator.parse('f9').isSafeAsGlobal, isTrue);
    });
  });

  group('HotkeyManagerBackend', () {
    test('builds system-scope HotKeys with the right modifiers', () {
      final hk = HotkeyManagerBackend.toHotKey('global.playPause', Accelerator.parse('ctrl+alt+space'));
      expect(hk.identifier, 'global.playPause');
      expect(hk.scope, HotKeyScope.system);
      expect(hk.physicalKey, PhysicalKeyboardKey.space);
      expect(hk.modifiers, [HotKeyModifier.control, HotKeyModifier.alt]);
    });

    test('every supported key has a native key code on Windows and Linux', () {
      final keys = [
        ...'abcdefghijklmnopqrstuvwxyz0123456789'.split(''),
        'space', 'left', 'right', 'up', 'down',
        for (var i = 1; i <= 12; i++) 'f$i',
        'mediaPlayPause', 'mediaNext', 'mediaPrevious', 'mediaStop',
        'comma', 'period', 'enter', 'tab', 'escape', 'home', 'end', 'pageUp', 'pageDown',
        'insert', 'delete', 'backspace', 'minus', 'equal', 'slash', 'semicolon',
      ];
      for (final k in keys) {
        final a = Accelerator.parse('ctrl+$k');
        // Media keys are never registered on Windows (SMTC delivers them).
        if (!a.isMediaKey) {
          expect(HotkeyManagerBackend.nativeKeyCode(a, const PlatformInfo(os: HostOs.windows)), isNotNull,
              reason: 'windows $k');
        }
        expect(HotkeyManagerBackend.nativeKeyCode(a, const PlatformInfo(os: HostOs.linux)), isNotNull,
            reason: 'linux $k');
      }
    });
  });

  group('GlobalHotkeyServiceImpl', () {
    late FakeHotkeyBackend backend;
    late List<String> invoked;
    late SettingsStore settings;

    GlobalHotkeyServiceImpl service({HostOs os = HostOs.linux, Map<String, String> env = const {}}) =>
        GlobalHotkeyServiceImpl(
          backend: backend,
          actions: {
            for (final a in [
              ShortcutActions.globalPlayPause,
              ShortcutActions.globalNext,
              ShortcutActions.globalPrevious,
              ShortcutActions.globalShowWindow,
            ])
              a: () async => invoked.add(a),
          },
          platform: PlatformInfo(os: os),
          strings: desktopStringsFor(settings),
          environment: env,
        );

    setUp(() {
      backend = FakeHotkeyBackend();
      invoked = [];
      settings = SettingsStore.inMemory();
    });

    test('registers the global.* defaults and dispatches presses', () async {
      final s = service();
      expect(s.isSupported, isTrue);
      await s.apply(ShortcutActions.defaults, enabled: true);
      expect(backend.registered.keys, unorderedEquals([
        ShortcutActions.globalPlayPause,
        ShortcutActions.globalNext,
        ShortcutActions.globalPrevious,
        ShortcutActions.globalShowWindow,
      ]));
      expect(backend.registered[ShortcutActions.globalPlayPause]!.canonical, 'ctrl+alt+space');
      expect(s.registrationErrors, isEmpty);
      backend.handlers[ShortcutActions.globalNext]!();
      await settle();
      expect(invoked, [ShortcutActions.globalNext]);
    });

    test('disabled → everything unregistered', () async {
      final s = service();
      await s.apply(ShortcutActions.defaults, enabled: true);
      await s.apply(ShortcutActions.defaults, enabled: false);
      expect(backend.registered, isEmpty);
      expect(backend.unregisterAllCount, 1);
    });

    test('collects localized errors: invalid, unsafe, duplicate, refused', () async {
      backend.failFor.add('ctrl+alt+f');
      final s = service();
      await s.apply({
        ...ShortcutActions.defaults,
        ShortcutActions.globalPlayPause: 'ctrl+alt+banana',
        ShortcutActions.globalNext: 'n',
        ShortcutActions.globalPrevious: 'ctrl+alt+right',
        ShortcutActions.globalShowWindow: 'ctrl+alt+f',
        // in-app shortcuts are never registered globally
        ShortcutActions.search: 'ctrl+alt+right',
      }, enabled: true);
      final e = s.registrationErrors;
      expect(e[ShortcutActions.globalPlayPause], contains('ctrl+alt+banana'));
      expect(e[ShortcutActions.globalPlayPause], contains("isn't a valid shortcut"));
      expect(e[ShortcutActions.globalNext], contains('needs Ctrl, Alt, Shift or Super'));
      expect(e[ShortcutActions.globalShowWindow], contains('Another app'));
      expect(e.containsKey(ShortcutActions.globalPrevious), isFalse);
      expect(backend.registered.keys, [ShortcutActions.globalPrevious]);
    });

    test('duplicate bindings: the first action keeps it', () async {
      final s = service();
      await s.apply({
        ShortcutActions.globalNext: 'ctrl+alt+n',
        ShortcutActions.globalPrevious: 'alt+ctrl+n',
        ShortcutActions.globalPlayPause: '',
        ShortcutActions.globalShowWindow: '',
      }, enabled: true);
      expect(backend.registered.keys, [ShortcutActions.globalNext]);
      expect(s.registrationErrors[ShortcutActions.globalPrevious], contains('already used'));
    });

    test('errors follow the app language', () async {
      await settings.update((s) => s.copyWith(localeCode: 'da'));
      final s = service();
      await s.apply({ShortcutActions.globalNext: 'q'}, enabled: true);
      expect(s.registrationErrors[ShortcutActions.globalNext], contains('skal bruge Ctrl'));
    });

    test('re-applies when shortcut settings change (and only then)', () async {
      final s = service();
      await s.bindToSettings(settings);
      expect(backend.registered, hasLength(4));
      final before = backend.unregisterAllCount;

      await settings.update((x) => x.copyWith(localeCode: 'da')); // unrelated change
      await settle();
      expect(backend.unregisterAllCount, before);

      await settings.update((x) => x.copyWith(
            shortcuts: x.shortcuts.copyWith(bindings: {...x.shortcuts.bindings, ShortcutActions.globalNext: 'ctrl+shift+n'}),
          ));
      await settle();
      expect(backend.registered[ShortcutActions.globalNext]!.canonical, 'ctrl+shift+n');

      await settings.update((x) => x.copyWith(shortcuts: x.shortcuts.copyWith(globalHotkeysEnabled: false)));
      await settle();
      expect(backend.registered, isEmpty);

      await s.dispose();
    });

    test('media keys are left to SMTC on Windows, registered on Linux', () async {
      final bindings = {
        ShortcutActions.globalPlayPause: 'mediaPlayPause',
        ShortcutActions.globalNext: 'mediaNext',
        ShortcutActions.globalPrevious: 'ctrl+alt+left',
        ShortcutActions.globalShowWindow: '',
      };
      final win = service(os: HostOs.windows);
      await win.apply(bindings, enabled: true);
      expect(backend.registered.keys, [ShortcutActions.globalPrevious]);
      expect(win.registrationErrors, isEmpty);

      final linux = service();
      await linux.apply(bindings, enabled: true);
      expect(backend.registered.keys, unorderedEquals([
        ShortcutActions.globalPlayPause,
        ShortcutActions.globalNext,
        ShortcutActions.globalPrevious,
      ]));
    });

    test('unsupported under pure Wayland, supported with GDK_BACKEND=x11 and on Windows', () async {
      final wayland = service(env: const {'XDG_SESSION_TYPE': 'wayland', 'WAYLAND_DISPLAY': 'wayland-0'});
      expect(wayland.isSupported, isFalse);
      expect(wayland.unsupportedReason, contains('Wayland'));
      await wayland.apply(ShortcutActions.defaults, enabled: true);
      expect(backend.registered, isEmpty);
      expect(wayland.registrationErrors, isEmpty);

      expect(service(env: const {'XDG_SESSION_TYPE': 'wayland', 'GDK_BACKEND': 'x11'}).isSupported, isTrue);
      expect(service(env: const {'XDG_SESSION_TYPE': 'x11', 'DISPLAY': ':0'}).isSupported, isTrue);
      expect(service(os: HostOs.windows, env: const {'XDG_SESSION_TYPE': 'wayland'}).isSupported, isTrue);
      expect(service(os: HostOs.android).isSupported, isFalse);
      expect(service().unsupportedReason, isNull);
    });
  });
}
