import 'package:flutter/material.dart';

import '../../design/context_ext.dart';

/// Shows a short, unobtrusive message (floating snack bar styled with the
/// design tokens). Safe to call from any context below `MaterialApp`; does
/// nothing when no `ScaffoldMessenger` is available.
void showFermataToast(
  BuildContext context,
  String message, {
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final c = context.colors;
  final width = MediaQuery.sizeOf(context).width;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        width: width >= 600 ? 420 : null,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            if (icon != null || isError) ...[
              Icon(icon ?? Icons.error_outline_rounded, size: 20, color: isError ? c.danger : c.accentText),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel == null || onAction == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}
