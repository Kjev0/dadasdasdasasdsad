import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../design/context_ext.dart';
import '../controls/fermata_button.dart';
import 'messages.dart';

/// Calm empty state: icon, title, message and up to two actions.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Smaller variant for inline use (inside a section).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 48 : 64,
                height: compact ? 48 : 64,
                decoration: BoxDecoration(color: c.surfaceHigh, shape: BoxShape.circle),
                child: Icon(icon, size: compact ? 24 : 30, color: c.textSecondary),
              ),
              SizedBox(height: compact ? 12 : 20),
              Text(title, textAlign: TextAlign.center, style: compact ? context.type.titleSmall : context.type.title),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, textAlign: TextAlign.center, style: context.type.body.copyWith(color: c.textSecondary)),
              ],
              if (actionLabel != null || secondaryLabel != null) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (actionLabel != null) FermataButton(label: actionLabel!, onPressed: onAction),
                    if (secondaryLabel != null)
                      FermataButton(label: secondaryLabel!, onPressed: onSecondary, variant: FermataButtonVariant.secondary),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state that maps [error] (`FermataException.code`) to a localized
/// message and offers a retry.
class ErrorState extends ConsumerWidget {
  const ErrorState({super.key, required this.error, this.onRetry, this.compact = false, this.title});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  /// Optional heading above the message.
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final registry = ref.watch(sourceRegistryProvider);
    final message = errorMessageFor(l10n, error, sourceName: (id) => registry.byId(id)?.displayName ?? id) ?? l10n.errorGeneric;
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: title ?? message,
      message: title == null ? null : message,
      actionLabel: onRetry == null ? null : l10n.actionRetry,
      onAction: onRetry,
      compact: compact,
    );
  }
}
