import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PhysicalKeyboardKey;

/// Modifiers in canonical order.
enum AcceleratorModifier { ctrl, alt, shift, meta }

/// A parsed key combination in the format documented by `ShortcutActions`:
/// `ctrl+alt+space` — modifiers `ctrl`, `alt`, `shift`, `meta` (aliases:
/// control, option, super, win, cmd), then exactly one key: letters,
/// digits, `space`, `left`/`right`/`up`/`down`, `f1`..`f12`,
/// `mediaPlayPause`, `mediaNext`, `mediaPrevious`, `mediaStop`, plus a few
/// extras (`comma`, `period`, `enter`, `tab`, `escape`, `home`, `end`,
/// `pageUp`, `pageDown`, `insert`, `delete`, `backspace`, `minus`, `equal`,
/// `slash`, `semicolon`). Case-insensitive; whitespace around parts ignored.
@immutable
class Accelerator {
  const Accelerator(this.modifiers, this.key);

  final Set<AcceleratorModifier> modifiers;

  /// Canonical key name (e.g. `space`, `a`, `7`, `f5`, `mediaPlayPause`).
  final String key;

  static const _modifierAliases = <String, AcceleratorModifier>{
    'ctrl': AcceleratorModifier.ctrl,
    'control': AcceleratorModifier.ctrl,
    'alt': AcceleratorModifier.alt,
    'option': AcceleratorModifier.alt,
    'shift': AcceleratorModifier.shift,
    'meta': AcceleratorModifier.meta,
    'super': AcceleratorModifier.meta,
    'win': AcceleratorModifier.meta,
    'cmd': AcceleratorModifier.meta,
    'command': AcceleratorModifier.meta,
  };

  static final _keys = <String, PhysicalKeyboardKey>{
    for (var i = 0; i < 26; i++) String.fromCharCode(0x61 + i): _letter(i),
    '0': PhysicalKeyboardKey.digit0,
    '1': PhysicalKeyboardKey.digit1,
    '2': PhysicalKeyboardKey.digit2,
    '3': PhysicalKeyboardKey.digit3,
    '4': PhysicalKeyboardKey.digit4,
    '5': PhysicalKeyboardKey.digit5,
    '6': PhysicalKeyboardKey.digit6,
    '7': PhysicalKeyboardKey.digit7,
    '8': PhysicalKeyboardKey.digit8,
    '9': PhysicalKeyboardKey.digit9,
    'space': PhysicalKeyboardKey.space,
    'left': PhysicalKeyboardKey.arrowLeft,
    'right': PhysicalKeyboardKey.arrowRight,
    'up': PhysicalKeyboardKey.arrowUp,
    'down': PhysicalKeyboardKey.arrowDown,
    'f1': PhysicalKeyboardKey.f1,
    'f2': PhysicalKeyboardKey.f2,
    'f3': PhysicalKeyboardKey.f3,
    'f4': PhysicalKeyboardKey.f4,
    'f5': PhysicalKeyboardKey.f5,
    'f6': PhysicalKeyboardKey.f6,
    'f7': PhysicalKeyboardKey.f7,
    'f8': PhysicalKeyboardKey.f8,
    'f9': PhysicalKeyboardKey.f9,
    'f10': PhysicalKeyboardKey.f10,
    'f11': PhysicalKeyboardKey.f11,
    'f12': PhysicalKeyboardKey.f12,
    'mediaPlayPause': PhysicalKeyboardKey.mediaPlayPause,
    'mediaNext': PhysicalKeyboardKey.mediaTrackNext,
    'mediaPrevious': PhysicalKeyboardKey.mediaTrackPrevious,
    'mediaStop': PhysicalKeyboardKey.mediaStop,
    'comma': PhysicalKeyboardKey.comma,
    'period': PhysicalKeyboardKey.period,
    'enter': PhysicalKeyboardKey.enter,
    'tab': PhysicalKeyboardKey.tab,
    'escape': PhysicalKeyboardKey.escape,
    'home': PhysicalKeyboardKey.home,
    'end': PhysicalKeyboardKey.end,
    'pageUp': PhysicalKeyboardKey.pageUp,
    'pageDown': PhysicalKeyboardKey.pageDown,
    'insert': PhysicalKeyboardKey.insert,
    'delete': PhysicalKeyboardKey.delete,
    'backspace': PhysicalKeyboardKey.backspace,
    'minus': PhysicalKeyboardKey.minus,
    'equal': PhysicalKeyboardKey.equal,
    'slash': PhysicalKeyboardKey.slash,
    'semicolon': PhysicalKeyboardKey.semicolon,
  };

  static const _keyAliases = <String, String>{
    'esc': 'escape',
    'return': 'enter',
    'arrowleft': 'left',
    'arrowright': 'right',
    'arrowup': 'up',
    'arrowdown': 'down',
    'pgup': 'pageUp',
    'pgdn': 'pageDown',
    'del': 'delete',
    'playpause': 'mediaPlayPause',
    'mediatracknext': 'mediaNext',
    'mediatrackprevious': 'mediaPrevious',
  };

  /// Lower-cased lookup for keys whose canonical name is camelCase.
  static final _byLower = {for (final k in _keys.keys) k.toLowerCase(): k};

  static PhysicalKeyboardKey _letter(int i) => const [
        PhysicalKeyboardKey.keyA, PhysicalKeyboardKey.keyB, PhysicalKeyboardKey.keyC, //
        PhysicalKeyboardKey.keyD, PhysicalKeyboardKey.keyE, PhysicalKeyboardKey.keyF,
        PhysicalKeyboardKey.keyG, PhysicalKeyboardKey.keyH, PhysicalKeyboardKey.keyI,
        PhysicalKeyboardKey.keyJ, PhysicalKeyboardKey.keyK, PhysicalKeyboardKey.keyL,
        PhysicalKeyboardKey.keyM, PhysicalKeyboardKey.keyN, PhysicalKeyboardKey.keyO,
        PhysicalKeyboardKey.keyP, PhysicalKeyboardKey.keyQ, PhysicalKeyboardKey.keyR,
        PhysicalKeyboardKey.keyS, PhysicalKeyboardKey.keyT, PhysicalKeyboardKey.keyU,
        PhysicalKeyboardKey.keyV, PhysicalKeyboardKey.keyW, PhysicalKeyboardKey.keyX,
        PhysicalKeyboardKey.keyY, PhysicalKeyboardKey.keyZ,
      ][i];

  /// Parses [input]; throws [FormatException] with a developer-facing
  /// message when it is not a valid accelerator.
  static Accelerator parse(String input) {
    final text = input.trim();
    if (text.isEmpty) throw const FormatException('Empty accelerator');
    final parts = text.split('+').map((s) => s.trim()).toList();
    if (parts.any((s) => s.isEmpty)) throw FormatException('Empty part in "$input"');
    final modifiers = <AcceleratorModifier>{};
    String? key;
    for (final raw in parts) {
      final lower = raw.toLowerCase();
      final modifier = _modifierAliases[lower];
      if (modifier != null) {
        if (!modifiers.add(modifier)) throw FormatException('Duplicate modifier "$raw" in "$input"');
        continue;
      }
      if (key != null) throw FormatException('More than one key in "$input"');
      final canonical = _byLower[_keyAliases[lower]?.toLowerCase() ?? lower];
      if (canonical == null) throw FormatException('Unknown key "$raw" in "$input"');
      key = canonical;
    }
    if (key == null) throw FormatException('No key in "$input" (only modifiers)');
    return Accelerator(Set.unmodifiable(modifiers), key);
  }

  static Accelerator? tryParse(String input) {
    try {
      return parse(input);
    } on FormatException {
      return null;
    }
  }

  PhysicalKeyboardKey get physicalKey => _keys[key]!;

  bool get isMediaKey => key.startsWith('media');

  bool get isFunctionKey => RegExp(r'^f([1-9]|1[0-2])$').hasMatch(key);

  /// System-wide bindings without a modifier would swallow normal typing in
  /// every application; only media and function keys may stand alone.
  bool get isSafeAsGlobal => modifiers.isNotEmpty || isMediaKey || isFunctionKey;

  /// Canonical text form, e.g. `ctrl+alt+space` (modifiers in
  /// ctrl, alt, shift, meta order).
  String get canonical => [
        for (final m in AcceleratorModifier.values)
          if (modifiers.contains(m)) m.name,
        key,
      ].join('+');

  @override
  bool operator ==(Object other) => other is Accelerator && other.canonical == canonical;

  @override
  int get hashCode => canonical.hashCode;

  @override
  String toString() => canonical;
}
