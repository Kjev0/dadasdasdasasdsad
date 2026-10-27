import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A parsed accelerator such as `ctrl+shift+k`.
@immutable
class ParsedShortcut {
  const ParsedShortcut(this.key, {this.control = false, this.alt = false, this.shift = false, this.meta = false});

  final LogicalKeyboardKey key;
  final bool control;
  final bool alt;
  final bool shift;
  final bool meta;

  SingleActivator toActivator() => SingleActivator(key, control: control, alt: alt, shift: shift, meta: meta);

  /// Ctrl / Alt / Meta held (Shift alone doesn't count).
  bool get hasCommandModifier => control || alt || meta;

  @override
  bool operator ==(Object other) =>
      other is ParsedShortcut &&
      other.key == key &&
      other.control == control &&
      other.alt == alt &&
      other.shift == shift &&
      other.meta == meta;

  @override
  int get hashCode => Object.hash(key, control, alt, shift, meta);
}

/// Accelerator strings shared by in-app shortcuts and global hotkeys
/// (format documented on `ShortcutActions`): parse, display, record.
abstract final class ShortcutBinding {
  static final Map<String, LogicalKeyboardKey> _keys = {
    for (var i = 0; i < 26; i++)
      String.fromCharCode(97 + i): LogicalKeyboardKey(LogicalKeyboardKey.keyA.keyId + i),
    for (var i = 0; i < 10; i++) '$i': LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + i),
    'space': LogicalKeyboardKey.space,
    'left': LogicalKeyboardKey.arrowLeft,
    'right': LogicalKeyboardKey.arrowRight,
    'up': LogicalKeyboardKey.arrowUp,
    'down': LogicalKeyboardKey.arrowDown,
    'comma': LogicalKeyboardKey.comma,
    'period': LogicalKeyboardKey.period,
    'slash': LogicalKeyboardKey.slash,
    'minus': LogicalKeyboardKey.minus,
    'equal': LogicalKeyboardKey.equal,
    'enter': LogicalKeyboardKey.enter,
    'escape': LogicalKeyboardKey.escape,
    'tab': LogicalKeyboardKey.tab,
    'backspace': LogicalKeyboardKey.backspace,
    'delete': LogicalKeyboardKey.delete,
    'home': LogicalKeyboardKey.home,
    'end': LogicalKeyboardKey.end,
    'pageup': LogicalKeyboardKey.pageUp,
    'pagedown': LogicalKeyboardKey.pageDown,
    'f1': LogicalKeyboardKey.f1,
    'f2': LogicalKeyboardKey.f2,
    'f3': LogicalKeyboardKey.f3,
    'f4': LogicalKeyboardKey.f4,
    'f5': LogicalKeyboardKey.f5,
    'f6': LogicalKeyboardKey.f6,
    'f7': LogicalKeyboardKey.f7,
    'f8': LogicalKeyboardKey.f8,
    'f9': LogicalKeyboardKey.f9,
    'f10': LogicalKeyboardKey.f10,
    'f11': LogicalKeyboardKey.f11,
    'f12': LogicalKeyboardKey.f12,
    'mediaplaypause': LogicalKeyboardKey.mediaPlayPause,
    'medianext': LogicalKeyboardKey.mediaTrackNext,
    'mediaprevious': LogicalKeyboardKey.mediaTrackPrevious,
    'mediastop': LogicalKeyboardKey.mediaStop,
  };

  static final Map<LogicalKeyboardKey, String> _names = {for (final e in _keys.entries) e.value: e.key};

  static const _display = {
    'space': 'Space',
    'left': '←',
    'right': '→',
    'up': '↑',
    'down': '↓',
    'comma': ',',
    'period': '.',
    'slash': '/',
    'minus': '-',
    'equal': '=',
    'enter': 'Enter',
    'escape': 'Esc',
    'tab': 'Tab',
    'backspace': 'Backspace',
    'delete': 'Delete',
    'home': 'Home',
    'end': 'End',
    'pageup': 'Page Up',
    'pagedown': 'Page Down',
    'mediaplaypause': 'Play/Pause',
    'medianext': 'Next track',
    'mediaprevious': 'Previous track',
    'mediastop': 'Stop',
  };

  /// Keys that edit text; a shortcut using them must not fire while a text
  /// field has focus.
  static final Set<LogicalKeyboardKey> _editingKeys = {
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.backspace,
    LogicalKeyboardKey.delete,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyC,
    LogicalKeyboardKey.keyV,
    LogicalKeyboardKey.keyX,
    LogicalKeyboardKey.keyY,
    LogicalKeyboardKey.keyZ,
  };

  /// Parses `ctrl+alt+space`; returns null for invalid strings.
  static ParsedShortcut? parse(String? accelerator) {
    if (accelerator == null || accelerator.trim().isEmpty) return null;
    var control = false, alt = false, shift = false, meta = false;
    LogicalKeyboardKey? key;
    for (final raw in accelerator.toLowerCase().split('+')) {
      final part = raw.trim();
      switch (part) {
        case 'ctrl' || 'control':
          control = true;
        case 'alt':
          alt = true;
        case 'shift':
          shift = true;
        case 'meta' || 'cmd' || 'super':
          meta = true;
        default:
          if (key != null) return null;
          key = _keys[part];
          if (key == null) return null;
      }
    }
    if (key == null) return null;
    return ParsedShortcut(key, control: control, alt: alt, shift: shift, meta: meta);
  }

  /// Serializes back to the settings format (modifiers in canonical order).
  static String serialize(ParsedShortcut s) => [
        if (s.control) 'ctrl',
        if (s.alt) 'alt',
        if (s.shift) 'shift',
        if (s.meta) 'meta',
        _names[s.key] ?? s.key.keyLabel.toLowerCase(),
      ].join('+');

  /// Human-readable label, e.g. `Ctrl+K`, `Shift+→`.
  static String format(String? accelerator) {
    final s = parse(accelerator);
    if (s == null) return accelerator ?? '';
    final name = _names[s.key] ?? s.key.keyLabel;
    final keyLabel = _display[name] ?? name.toUpperCase();
    return [
      if (s.control) 'Ctrl',
      if (s.alt) 'Alt',
      if (s.shift) 'Shift',
      if (s.meta) 'Super',
      keyLabel,
    ].join('+');
  }

  /// Records a binding from a key-down event (for the settings shortcut
  /// recorder). Returns null for modifier-only presses or unsupported keys.
  static String? fromKeyEvent(KeyEvent event, {HardwareKeyboard? keyboard}) {
    if (event is! KeyDownEvent) return null;
    final key = event.logicalKey;
    if (!_names.containsKey(key)) return null;
    final kb = keyboard ?? HardwareKeyboard.instance;
    return serialize(ParsedShortcut(
      key,
      control: kb.isControlPressed,
      alt: kb.isAltPressed,
      shift: kb.isShiftPressed,
      meta: kb.isMetaPressed,
    ));
  }

  /// Whether a shortcut may fire while a text field is focused (it needs a
  /// Ctrl/Alt/Meta modifier and must not be a text-editing combination).
  static bool allowedInTextField(ParsedShortcut s) => s.hasCommandModifier && !_editingKeys.contains(s.key);

  /// True when keyboard focus is inside an editable text field.
  static bool focusIsInTextField() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
  }
}
