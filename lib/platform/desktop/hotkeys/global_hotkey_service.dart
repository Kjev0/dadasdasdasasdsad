import 'dart:async';

import 'package:flutter/services.dart' show LogicalKeyboardKey, kGtkToLogicalKey, kWindowsToLogicalKey;
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:logging/logging.dart';

import '../../../core/contracts/platform.dart';
import '../../../core/platform/platform_info.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../settings/app_settings.dart';
import '../../../settings/settings_store.dart';
import 'accelerator.dart';

final _log = Logger('desktop.hotkeys');

/// Registers system-wide key bindings. Abstracted for tests;
/// [HotkeyManagerBackend] is the production implementation.
abstract class HotkeyBackend {
  Future<void> register(String id, Accelerator accelerator, void Function() onPressed);
  Future<void> unregisterAll();
}

/// [HotkeyBackend] using `hotkey_manager` (X11 keybinder on Linux,
/// `RegisterHotKey` on Windows).
///
/// Note: neither native plugin reports a combination that is already taken
/// by another application — the OS silently ignores it. Errors that are
/// detected (invalid key, plugin failure) are reported.
class HotkeyManagerBackend implements HotkeyBackend {
  HotkeyManagerBackend({required this._platform, HotKeyManager? manager})
      : _manager = manager ?? HotKeyManager.instance;

  final PlatformInfo _platform;
  final HotKeyManager _manager;

  static const _modifierMap = {
    AcceleratorModifier.ctrl: HotKeyModifier.control,
    AcceleratorModifier.alt: HotKeyModifier.alt,
    AcceleratorModifier.shift: HotKeyModifier.shift,
    AcceleratorModifier.meta: HotKeyModifier.meta,
  };

  /// The `hotkey_manager` representation of [a].
  static HotKey toHotKey(String id, Accelerator a) => HotKey(
        identifier: id,
        key: a.physicalKey,
        modifiers: [
          for (final m in AcceleratorModifier.values)
            if (a.modifiers.contains(m)) _modifierMap[m]!,
        ],
        scope: HotKeyScope.system,
      );

  /// The key code the native plugin will receive, or null when the key has
  /// none on [platform] (the Windows plugin would crash on a null code, so
  /// such keys are rejected before reaching it).
  static int? nativeKeyCode(Accelerator a, PlatformInfo platform) {
    final LogicalKeyboardKey logical;
    try {
      logical = toHotKey('probe', a).logicalKey;
    } catch (_) {
      return null;
    }
    if (platform.isWindows) {
      for (final e in kWindowsToLogicalKey.entries) {
        if (e.value == logical) return e.key;
      }
      return null;
    }
    if (platform.isLinux) {
      for (final e in kGtkToLogicalKey.entries) {
        if (e.value == logical) return e.key;
      }
      return logical.keyId;
    }
    return null;
  }

  @override
  Future<void> register(String id, Accelerator accelerator, void Function() onPressed) async {
    if (nativeKeyCode(accelerator, _platform) == null) {
      throw UnsupportedError('No native key code for "${accelerator.key}" on this platform');
    }
    await _manager.register(toHotKey(id, accelerator), keyDownHandler: (_) => onPressed());
  }

  @override
  Future<void> unregisterAll() => _manager.unregisterAll();
}

/// [GlobalHotkeyService] for Linux (X11) and Windows. Registers the
/// `global.*` actions from `ShortcutSettings`, re-applies them when the
/// settings change and collects localized per-action errors.
class GlobalHotkeyServiceImpl implements GlobalHotkeyService {
  GlobalHotkeyServiceImpl({
    required this._backend,
    required this._actions,
    required this._platform,
    required this._strings,
    Map<String, String> environment = const {},
  }) : _supported = _platform.isWindows || (_platform.isLinux && !isWaylandOnly(environment));

  final HotkeyBackend _backend;
  final Map<String, Future<void> Function()> _actions;
  final AppLocalizations Function() _strings;
  final PlatformInfo _platform;
  final bool _supported;
  final _errors = <String, String>{};
  StreamSubscription<AppSettings>? _settingsSub;
  ShortcutSettings? _applied;
  Future<void> _chain = Future.value();
  bool _registered = false;

  /// True for Wayland sessions where GTK talks Wayland: keybinder (X11) can
  /// not grab keys there. XWayland-forced GTK (`GDK_BACKEND=x11`) works.
  static bool isWaylandOnly(Map<String, String> env) {
    final session = env['XDG_SESSION_TYPE']?.toLowerCase();
    final gdk = env['GDK_BACKEND']?.toLowerCase() ?? '';
    final wayland = session == 'wayland' || (env['WAYLAND_DISPLAY']?.isNotEmpty ?? false);
    if (!wayland) return false;
    return !gdk.startsWith('x11');
  }

  @override
  bool get isSupported => _supported;

  /// Localized reason when [isSupported] is false.
  String? get unsupportedReason {
    if (_supported) return null;
    final l10n = _strings();
    return _platform.isLinux ? l10n.desktopHotkeysUnsupportedWayland : l10n.desktopHotkeysUnsupportedPlatform;
  }

  @override
  Map<String, String> get registrationErrors => Map.unmodifiable(_errors);

  /// Applies the current shortcut settings and re-applies on every change.
  Future<void> bindToSettings(SettingsStore settings) async {
    await _settingsSub?.cancel();
    _settingsSub = settings.changes.listen((s) {
      if (!_sameShortcuts(s.shortcuts, _applied)) {
        unawaited(apply(s.shortcuts.bindings, enabled: s.shortcuts.globalHotkeysEnabled));
      }
    });
    final s = settings.current.shortcuts;
    await apply(s.bindings, enabled: s.globalHotkeysEnabled);
  }

  static bool _sameShortcuts(ShortcutSettings a, ShortcutSettings? b) {
    if (b == null || a.globalHotkeysEnabled != b.globalHotkeysEnabled) return false;
    for (final action in a.bindings.keys.followedBy(b.bindings.keys)) {
      if (ShortcutActions.isGlobal(action) && a.bindingFor(action) != b.bindingFor(action)) return false;
    }
    return true;
  }

  @override
  Future<void> apply(Map<String, String> bindings, {required bool enabled}) {
    return _chain = _chain.then((_) => _apply(bindings, enabled)).catchError((Object e, StackTrace st) {
      _log.warning('Applying global hotkeys failed', e, st);
    });
  }

  Future<void> _apply(Map<String, String> bindings, bool enabled) async {
    _applied = ShortcutSettings(globalHotkeysEnabled: enabled, bindings: bindings);
    _errors.clear();
    if (!_supported) return;
    if (_registered) {
      await _backend.unregisterAll();
      _registered = false;
    }
    if (!enabled) return;

    final l10n = _strings();
    final used = <Accelerator, String>{};
    final actionIds = _actions.keys.where(ShortcutActions.isGlobal).toList()..sort();
    for (final action in actionIds) {
      final binding = (bindings[action] ?? ShortcutActions.defaults[action])?.trim();
      if (binding == null || binding.isEmpty) continue; // unbound by the user
      final accel = Accelerator.tryParse(binding);
      if (accel == null) {
        _errors[action] = l10n.desktopHotkeyErrorInvalid(binding);
        continue;
      }
      if (!accel.isSafeAsGlobal) {
        _errors[action] = l10n.desktopHotkeyErrorNeedsModifier(binding);
        continue;
      }
      if (used.containsKey(accel)) {
        _errors[action] = l10n.desktopHotkeyErrorDuplicate(binding);
        continue;
      }
      try {
        final run = _actions[action]!;
        await _backend.register(action, accel, () => _invoke(action, run));
        _registered = true;
        used[accel] = action;
      } catch (e) {
        _log.warning('Could not register global hotkey $action=$binding: $e');
        _errors[action] = l10n.desktopHotkeyErrorFailed(binding);
      }
    }
    if (_errors.isNotEmpty) _log.info('Global hotkey problems: ${_errors.keys.join(', ')}');
  }

  void _invoke(String action, Future<void> Function() run) {
    unawaited(Future.sync(run).catchError((Object e, StackTrace st) {
      _log.warning('Global hotkey action $action failed', e, st);
    }));
  }

  /// Unregisters everything (part of quit).
  Future<void> dispose() async {
    await _settingsSub?.cancel();
    _settingsSub = null;
    await _chain;
    if (_registered) {
      try {
        await _backend.unregisterAll();
      } catch (e) {
        _log.fine('unregisterAll failed: $e');
      }
      _registered = false;
    }
  }
}

/// Default action table for [GlobalHotkeyServiceImpl].
Map<String, Future<void> Function()> defaultGlobalHotkeyActions({
  required Future<void> Function() playPause,
  required Future<void> Function() next,
  required Future<void> Function() previous,
  required Future<void> Function() showWindow,
}) =>
    {
      ShortcutActions.globalPlayPause: playPause,
      ShortcutActions.globalNext: next,
      ShortcutActions.globalPrevious: previous,
      ShortcutActions.globalShowWindow: showWindow,
    };
