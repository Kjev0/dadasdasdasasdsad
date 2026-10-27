import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../settings/app_settings.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/dialogs/dialogs.dart';
import '../../../widgets/feedback/toast.dart';

/// Writes a settings change through the store (the single source of truth
/// that services read as well).
Future<void> updateSettings(WidgetRef ref, AppSettings Function(AppSettings s) change) =>
    ref.read(settingsStoreProvider).update(change);

/// Body of one settings section: heading, optional intro, the groups, and a
/// "Restore defaults" action for just this section.
class SectionFrame extends StatelessWidget {
  const SectionFrame({
    super.key,
    required this.title,
    this.intro,
    required this.children,
    this.onRestoreDefaults,
    this.showHeading = true,
  });

  final String title;
  final String? intro;
  final List<Widget> children;

  /// Resets the section; a confirmation is shown first. Null hides the
  /// action (sections without settings).
  final Future<void> Function()? onRestoreDefaults;

  /// False when the surrounding page already shows the title (mobile app bar).
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    return LayoutBuilder(builder: (context, constraints) {
      final pad = constraints.maxWidth < 600 ? 16.0 : 32.0;
      return ListView(
        key: const ValueKey('settings.sectionBody'),
        padding: EdgeInsets.fromLTRB(pad, showHeading ? 24 : 12, pad, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHeading) ...[
                    Semantics(header: true, child: Text(title, style: context.type.headline)),
                    const SizedBox(height: 8),
                  ],
                  if (intro != null) ...[
                    Text(intro!, style: context.type.body.copyWith(color: c.textSecondary)),
                    const SizedBox(height: 20),
                  ] else if (showHeading)
                    const SizedBox(height: 12),
                  ...children,
                  if (onRestoreDefaults != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FermataButton(
                        key: const ValueKey('settings.restoreSection'),
                        label: l10n.settingsRestoreSection,
                        icon: Icons.restart_alt_rounded,
                        variant: FermataButtonVariant.ghost,
                        onPressed: () async {
                          final ok = await ConfirmDialog.show(
                            context,
                            title: l10n.settingsRestoreSectionTitle(title),
                            message: l10n.settingsRestoreSectionBody,
                            confirmLabel: l10n.actionRestoreDefaults,
                          );
                          if (!ok) return;
                          await onRestoreDefaults!();
                          if (context.mounted) showFermataToast(context, l10n.settingsRestoredToast, icon: Icons.check_rounded);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Runs [task] and reports failures as a toast (localized when possible).
Future<T?> runWithToast<T>(BuildContext context, Future<T> Function() task, {String? errorMessage}) async {
  try {
    return await task();
  } catch (e) {
    if (context.mounted) showFermataToast(context, errorMessage ?? context.l10n.errorGeneric, isError: true);
    return null;
  }
}
