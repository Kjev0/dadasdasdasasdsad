import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../settings/app_settings.dart';
import '../../../actions/command_registry.dart';
import '../../../actions/shortcut_binding.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../settings_hooks.dart';
import '../widgets/section_frame.dart';
import '../widgets/setting_tiles.dart';

/// Canonical form of an accelerator (`Ctrl+K` and `ctrl+k` compare equal);
/// null for empty/invalid bindings.
String? canonicalBinding(String? accelerator) {
  final parsed = ShortcutBinding.parse(accelerator);
  return parsed == null ? null : ShortcutBinding.serialize(parsed);
}

/// For every action, the other actions bound to the same keys. Global
/// hotkeys conflict with in-app shortcuts too (they take the key first).
Map<String, List<String>> shortcutConflicts(ShortcutSettings s, Iterable<String> actions) {
  final byKey = <String, List<String>>{};
  for (final a in actions) {
    final key = canonicalBinding(s.bindingFor(a));
    if (key != null) byKey.putIfAbsent(key, () => []).add(a);
  }
  return {
    for (final group in byKey.values)
      if (group.length > 1)
        for (final a in group) a: [for (final other in group) if (other != a) other],
  };
}

/// Settings → Keyboard shortcuts (in-app shortcuts and global hotkeys).
class ShortcutsSection extends ConsumerStatefulWidget {
  const ShortcutsSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  ConsumerState<ShortcutsSection> createState() => _ShortcutsSectionState();
}

class _ShortcutsSectionState extends ConsumerState<ShortcutsSection> {
  /// Re-applies global hotkeys after a change and refreshes the
  /// registration errors shown below each global action.
  Future<void> _applyHotkeys() async {
    final hotkeys = ref.read(globalHotkeysProvider);
    if (!hotkeys.isSupported) return;
    final s = ref.read(settingsStoreProvider).current.shortcuts;
    await hotkeys.apply(s.bindings, enabled: s.globalHotkeysEnabled);
    if (mounted) setState(() {});
  }

  Future<void> _setBinding(String action, String? accelerator) async {
    await updateSettings(ref, (s) {
      final next = {...s.shortcuts.bindings};
      if (accelerator == null) {
        next[action] = ShortcutActions.defaults[action] ?? '';
      } else {
        next[action] = accelerator;
      }
      return s.copyWith(shortcuts: s.shortcuts.copyWith(bindings: next));
    });
    if (ShortcutActions.isGlobal(action)) await _applyHotkeys();
  }

  Future<void> _record(String action) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => ShortcutRecorderDialog(action: action, requireModifier: ShortcutActions.isGlobal(action)),
    );
    if (result != null) await _setBinding(action, result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider.select((s) => s.shortcuts));
    final hotkeys = ref.watch(globalHotkeysProvider);
    final platform = ref.watch(platformInfoProvider);
    final hooks = ref.watch(settingsHooksProvider);
    final env = ref.watch(desktopEnvironmentProvider);
    final inApp = CommandRegistry.shortcutActions;
    final global = [for (final a in ShortcutActions.defaults.keys) if (ShortcutActions.isGlobal(a)) a];
    final conflicts = shortcutConflicts(s, [...inApp, if (s.globalHotkeysEnabled && hotkeys.isSupported) ...global]);
    final errors = hotkeys.registrationErrors;

    Widget row(String action, {bool enabled = true}) => _ShortcutRow(
          action: action,
          binding: s.bindingFor(action),
          conflicts: conflicts[action] ?? const [],
          error: ShortcutActions.isGlobal(action) ? errors[action] : null,
          enabled: enabled,
          onChange: () => _record(action),
          onReset: canonicalBinding(s.bindingFor(action)) == canonicalBinding(ShortcutActions.defaults[action])
              ? null
              : () => _setBinding(action, null),
          onRemove: (s.bindingFor(action) ?? '').isEmpty ? null : () => _setBinding(action, ''),
        );

    final unsupportedReason = hotkeys.isSupported
        ? null
        : hooks.hotkeysUnsupportedReason?.call() ??
            ((env['XDG_SESSION_TYPE'] ?? '').toLowerCase() == 'wayland' && platform.isLinux
                ? l10n.desktopHotkeysUnsupportedWayland
                : l10n.desktopHotkeysUnsupportedPlatform);

    return SectionFrame(
      title: l10n.shellSectionShortcuts,
      intro: l10n.settingsShortcutsIntro,
      showHeading: widget.showHeading,
      onRestoreDefaults: () async {
        await updateSettings(ref, (s) => s.copyWith(shortcuts: const ShortcutSettings()));
        await _applyHotkeys();
      },
      children: [
        SettingsGroup(title: l10n.settingsShortcutsInApp, children: [for (final a in inApp) row(a)]),
        if (platform.isDesktop) ...[
          SettingsGroup(title: l10n.settingsShortcutsGlobal, description: l10n.settingsShortcutsGlobalHint, children: [
            SettingSwitch(
              key: const ValueKey('setting.globalHotkeys'),
              title: l10n.settingsGlobalHotkeys,
              subtitle: l10n.settingsGlobalHotkeysHint,
              value: s.globalHotkeysEnabled && hotkeys.isSupported,
              disabledReason: unsupportedReason,
              onChanged: hotkeys.isSupported
                  ? (v) async {
                      await updateSettings(ref, (s) => s.copyWith(shortcuts: s.shortcuts.copyWith(globalHotkeysEnabled: v)));
                      await _applyHotkeys();
                    }
                  : null,
            ),
            for (final a in global) row(a, enabled: hotkeys.isSupported && s.globalHotkeysEnabled),
          ]),
        ],
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.action,
    required this.binding,
    required this.conflicts,
    required this.error,
    required this.enabled,
    required this.onChange,
    required this.onReset,
    required this.onRemove,
  });

  final String action;
  final String? binding;
  final List<String> conflicts;
  final String? error;
  final bool enabled;
  final VoidCallback onChange;
  final VoidCallback? onReset;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final label = CommandRegistry.labelFor(l10n, action);
    final hasBinding = (binding ?? '').isNotEmpty;
    final display = hasBinding ? ShortcutBinding.format(binding) : l10n.settingsShortcutNone;
    final problem = conflicts.isNotEmpty
        ? l10n.settingsShortcutConflict(conflicts.map((a) => CommandRegistry.labelFor(l10n, a)).join(', '))
        : error;
    return Padding(
      key: ValueKey('settings.shortcut.$action'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.type.body.copyWith(color: enabled ? c.textPrimary : c.textTertiary)),
                if (problem != null)
                  Text(problem,
                      key: ValueKey('settings.shortcut.$action.problem'),
                      style: context.type.caption.copyWith(color: c.danger)),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: l10n.settingsShortcutChangeSemantics(label, display),
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('settings.shortcut.$action.change'),
              borderRadius: context.radii.smAll,
              onTap: enabled ? onChange : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: context.radii.smAll,
                  border: Border.all(color: problem != null ? c.danger : c.outlineSubtle),
                ),
                child: Text(display, style: context.type.label.copyWith(color: hasBinding ? c.textPrimary : c.textTertiary)),
              ),
            ),
          ),
          PopupMenuButton<String>(
            key: ValueKey('settings.shortcut.$action.menu'),
            enabled: enabled,
            tooltip: l10n.settingsShortcutMore,
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (v) => switch (v) {
              'change' => onChange(),
              'reset' => onReset?.call(),
              'remove' => onRemove?.call(),
              _ => null,
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'change', child: Text(l10n.settingsShortcutChange)),
              PopupMenuItem(value: 'reset', enabled: onReset != null, child: Text(l10n.settingsShortcutReset)),
              PopupMenuItem(value: 'remove', enabled: onRemove != null, child: Text(l10n.settingsShortcutRemove)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Captures the next key combination. Returns the accelerator string
/// (settings format) or null when canceled. Plain Escape cancels.
class ShortcutRecorderDialog extends StatefulWidget {
  const ShortcutRecorderDialog({super.key, required this.action, this.requireModifier = false});

  final String action;

  /// Global hotkeys need Ctrl/Alt/Shift/Super so they don't block typing.
  final bool requireModifier;

  @override
  State<ShortcutRecorderDialog> createState() => _ShortcutRecorderDialogState();
}

class _ShortcutRecorderDialogState extends State<ShortcutRecorderDialog> {
  String? _captured;
  String? _error;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final kb = HardwareKeyboard.instance;
    final anyModifier = kb.isControlPressed || kb.isAltPressed || kb.isShiftPressed || kb.isMetaPressed;
    if (event.logicalKey == LogicalKeyboardKey.escape && !anyModifier) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    final binding = ShortcutBinding.fromKeyEvent(event);
    if (binding == null) return KeyEventResult.handled; // modifier only / unsupported key
    final parsed = ShortcutBinding.parse(binding)!;
    setState(() {
      _captured = binding;
      _error = widget.requireModifier && !(parsed.hasCommandModifier || parsed.shift)
          ? context.l10n.settingsShortcutNeedsModifier
          : null;
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    return AlertDialog(
      title: Text(l10n.settingsShortcutRecordTitle(CommandRegistry.labelFor(l10n, widget.action))),
      content: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.settingsShortcutRecordHint, style: context.type.bodySmall),
              const SizedBox(height: 16),
              Container(
                key: const ValueKey('settings.shortcutRecorder.value'),
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: context.radii.smAll,
                  border: Border.all(color: _error != null ? c.danger : c.accent),
                ),
                child: Text(
                  _captured == null ? l10n.settingsShortcutWaiting : ShortcutBinding.format(_captured),
                  style: context.type.titleSmall,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: context.type.bodySmall.copyWith(color: c.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FermataButton(label: l10n.actionCancel, variant: FermataButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
        FermataButton(
          key: const ValueKey('settings.shortcutRecorder.save'),
          label: l10n.actionSave,
          onPressed: _captured == null || _error != null ? null : () => Navigator.of(context).pop(_captured),
        ),
      ],
    );
  }
}
