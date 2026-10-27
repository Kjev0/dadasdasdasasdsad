import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import '../../app/providers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../actions/command_registry.dart';
import '../actions/shortcut_binding.dart';
import '../player/mini_mode.dart';
import 'command_palette.dart';

final _log = Logger('ui.shortcuts');

/// Intent carrying a `ShortcutActions` id.
class FermataCommandIntent extends Intent {
  const FermataCommandIntent(this.actionId, {this.allowInTextField = false, this.activationKey = false});

  final String actionId;

  /// Whether the binding may fire while a text field has focus.
  final bool allowInTextField;

  /// Plain Space / Enter binding: yields to a focused control that activates
  /// itself with that key (checkbox, switch, button, ...).
  final bool activationKey;
}

class _CommandAction extends Action<FermataCommandIntent> {
  _CommandAction(this.onInvoke);

  final void Function(String actionId) onInvoke;

  @override
  bool isEnabled(FermataCommandIntent intent) {
    if (intent.activationKey && _focusedControlActivates()) return false;
    return intent.allowInTextField || !ShortcutBinding.focusIsInTextField();
  }

  static bool _focusedControlActivates() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    final action = Actions.maybeFind<ActivateIntent>(ctx);
    return action != null && action is! DoNothingAction && action.isEnabled(const ActivateIntent());
  }

  @override
  Object? invoke(FermataCommandIntent intent) {
    onInvoke(intent.actionId);
    return null;
  }
}

/// Builds the activator → intent map from settings bindings (in-app
/// actions only; global hotkeys are registered by the platform module).
Map<ShortcutActivator, Intent> buildShortcutMap(ShortcutSettings settings) {
  final map = <ShortcutActivator, Intent>{};
  for (final action in CommandRegistry.shortcutActions) {
    final parsed = ShortcutBinding.parse(settings.bindingFor(action));
    if (parsed == null) continue;
    map[parsed.toActivator()] = FermataCommandIntent(
      action,
      allowInTextField: ShortcutBinding.allowedInTextField(parsed),
      activationKey: !parsed.hasCommandModifier &&
          (parsed.key == LogicalKeyboardKey.space || parsed.key == LogicalKeyboardKey.enter),
    );
  }
  return map;
}

/// App-wide keyboard shortcuts from `settings.shortcuts.bindings` plus the
/// command palette. Placed in `MaterialApp.builder` so it covers every
/// route. Plain-key bindings (e.g. Space) never fire while typing in a text
/// field.
class FermataShortcuts extends ConsumerStatefulWidget {
  const FermataShortcuts({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<FermataShortcuts> createState() => _FermataShortcutsState();
}

class _FermataShortcutsState extends ConsumerState<FermataShortcuts> {
  @override
  void initState() {
    super.initState();
    CommandRegistry.paletteOpener = showCommandPalette;
  }

  Future<void> _invoke(String actionId) async {
    final navContext = widget.router.routerDelegate.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    final ctx = CommandContext(
      container: ProviderScope.containerOf(context, listen: false),
      router: widget.router,
      context: navContext,
    );
    try {
      await CommandRegistry.runShortcut(
        actionId,
        ctx,
        AppLocalizations.of(navContext),
        miniPlayerSupported: ref.read(miniWindowControllerProvider) != null,
        onToggleMiniPlayer: (c) => c.read(miniModeProvider.notifier).toggle(),
      );
    } catch (e, st) {
      _log.warning('Shortcut $actionId failed', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = ref.watch(settingsProvider.select((s) => s.shortcuts));
    return Shortcuts(
      shortcuts: buildShortcutMap(shortcuts),
      child: Actions(
        actions: {FermataCommandIntent: _CommandAction(_invoke)},
        child: Focus(autofocus: true, skipTraversal: true, child: widget.child),
      ),
    );
  }
}
