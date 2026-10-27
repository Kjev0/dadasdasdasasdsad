import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/contracts/platform.dart';
import '../l10n/gen/app_localizations.dart';
import '../settings/app_settings.dart';
import '../ui/design/context_ext.dart';
import '../ui/design/theme.dart';
import '../ui/player/mini_mode.dart';
import '../ui/shell/fermata_shortcuts.dart';
import 'providers.dart';
import 'router.dart';

/// Root widget: `MaterialApp.router` with the Fermata themes (theme mode,
/// accent, high contrast, density from settings), locale, localization
/// delegates, combined text scaling (system × `accessibility.textScale`),
/// OS reduce-motion sync, app-wide keyboard shortcuts and desktop mini mode.
///
/// Must sit below a `ProviderScope` overridden with `serviceOverrides`.
class FermataApp extends ConsumerWidget {
  const FermataApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appearance = ref.watch(settingsProvider.select((s) => s.appearance));
    final highContrast = ref.watch(settingsProvider.select((s) => s.accessibility.highContrast));
    final largerTargets = ref.watch(settingsProvider.select((s) => s.accessibility.largerTargets));
    final visuals = ref.watch(effectiveVisualsProvider);
    final locale = ref.watch(localeProvider);

    ThemeData theme(Brightness brightness, {bool forceHighContrast = false}) => buildFermataTheme(
          brightness: brightness,
          accent: appearance.accent,
          highContrast: highContrast || forceHighContrast,
          density: appearance.density,
          largerTargets: largerTargets,
          visuals: visuals,
        );

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      highContrastTheme: theme(Brightness.light, forceHighContrast: true),
      highContrastDarkTheme: theme(Brightness.dark, forceHighContrast: true),
      themeMode: switch (appearance.themeMode) {
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.system => ThemeMode.system,
      },
      themeAnimationDuration: visuals.duration(const Duration(milliseconds: 220)),
      themeAnimationCurve: Curves.easeOutCubic,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppFrame(router: router, child: child ?? const SizedBox.shrink()),
    );
  }
}

/// App-wide wrapper inside `MaterialApp`: text scale, reduce-motion sync,
/// shortcuts, close-to-tray dialog delegate and mini mode.
class AppFrame extends ConsumerStatefulWidget {
  const AppFrame({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<AppFrame> createState() => _AppFrameState();
}

class _AppFrameState extends ConsumerState<AppFrame> {
  AppLifecycleController? _lifecycle;
  final _miniNavigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    try {
      final lifecycle = ref.read(appLifecycleProvider);
      lifecycle.closeDecisionDelegate = _askClose;
      _lifecycle = lifecycle;
    } catch (_) {
      // No lifecycle controller (e.g. isolated widget tests).
    }
  }

  @override
  void dispose() {
    _lifecycle?.closeDecisionDelegate = null;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.disableAnimationsOf(context);
    if (disable != ref.read(systemReduceMotionProvider)) {
      // Providers must not change during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(systemReduceMotionProvider.notifier).set(disable);
      });
    }
  }

  Future<(CloseChoice, bool)> _askClose() async {
    // In mini mode the router's navigator is offstage: ask in the mini
    // host's own navigator with a compact dialog that fits the tiny window.
    final mini = ref.read(miniModeProvider).active;
    final ctx = mini
        ? _miniNavigatorKey.currentContext
        : widget.router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return (CloseChoice.minimizeToTray, false);
    final result = await showDialog<(CloseChoice, bool)>(
      context: ctx,
      builder: (_) => CloseDialog(compact: mini),
    );
    return result ?? (CloseChoice.cancel, false);
  }

  @override
  Widget build(BuildContext context) {
    final textScale = ref.watch(settingsProvider.select((s) => s.accessibility.textScale));
    final mini = ref.watch(miniModeProvider.select((m) => m.active));
    final mq = MediaQuery.of(context);
    final systemFactor = mq.textScaler.scale(14) / 14;
    final scaled = mq.copyWith(textScaler: TextScaler.linear((systemFactor * textScale).clamp(0.8, 2.4)));

    return MediaQuery(
      data: scaled,
      child: FermataShortcuts(
        router: widget.router,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // While mini, the app stays mounted (state kept) but offstage and
            // laid out at a normal minimum size so it never overflows the
            // tiny window. The structure is identical in both modes.
            LayoutBuilder(
              builder: (context, c) {
                final w = mini ? math.max(c.maxWidth, 800.0) : c.maxWidth;
                final h = mini ? math.max(c.maxHeight, 600.0) : c.maxHeight;
                return OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: w,
                  maxWidth: w,
                  minHeight: h,
                  maxHeight: h,
                  child: Offstage(offstage: mini, child: TickerMode(enabled: !mini, child: widget.child)),
                );
              },
            ),
            if (mini) _MiniModeHost(navigatorKey: _miniNavigatorKey),
          ],
        ),
      ),
    );
  }
}

/// Hosts [MiniModeView] in its own [Navigator] (it sits above the router's
/// navigator, so tooltips, menus and dialogs need an overlay of their own).
class _MiniModeHost extends StatelessWidget {
  const _MiniModeHost({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) => Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) => PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const MiniModeView(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
}

/// "Close Fermata?" — keep playing in the tray, quit, or cancel; with
/// "Remember my choice".
class CloseDialog extends StatefulWidget {
  const CloseDialog({super.key, this.compact = false});

  /// Dense layout for the mini player's tiny window.
  final bool compact;

  @override
  State<CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends State<CloseDialog> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.compact) return _buildCompact(context);
    return AlertDialog(
      title: Text(l10n.shellCloseTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.shellCloseMessage),
          const SizedBox(height: 12),
          CheckboxListTile(
            // Focus a control so Space / Enter act on the dialog, never on
            // the app-wide playback shortcuts behind it.
            autofocus: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _remember,
            title: Text(l10n.shellCloseRemember),
            onChanged: (v) => setState(() => _remember = v ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop((CloseChoice.cancel, false)), child: Text(l10n.actionCancel)),
        TextButton(onPressed: () => Navigator.of(context).pop((CloseChoice.quit, _remember)), child: Text(l10n.shellCloseQuit)),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((CloseChoice.minimizeToTray, _remember)),
          child: Text(l10n.shellCloseMinimize),
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    void pop(CloseChoice c, bool remember) => Navigator.of(context).pop((c, remember));
    return Dialog(
      insetPadding: const EdgeInsets.all(4),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.shellCloseTitle, style: text.titleSmall),
            Text(l10n.shellCloseMessage, style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            InkWell(
              onTap: () => setState(() => _remember = !_remember),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: _remember,
                      autofocus: true,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                    ),
                  ),
                  Expanded(child: Text(l10n.shellCloseRemember, style: text.bodySmall, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(onPressed: () => pop(CloseChoice.cancel, false), child: Text(l10n.actionCancel)),
                TextButton(onPressed: () => pop(CloseChoice.quit, _remember), child: Text(l10n.shellCloseQuit)),
                TextButton(onPressed: () => pop(CloseChoice.minimizeToTray, _remember), child: Text(l10n.shellCloseMinimize)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
