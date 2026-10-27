import 'package:flutter/material.dart';

import '../../design/context_ext.dart';

enum FermataButtonVariant {
  /// Accent fill — one per view at most.
  primary,

  /// Neutral raised fill.
  secondary,

  /// Text only.
  ghost,

  /// Destructive confirmation.
  danger,
}

/// Standard button with variants, optional leading icon and a busy state.
class FermataButton extends StatelessWidget {
  const FermataButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = FermataButtonVariant.primary,
    this.busy = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final FermataButtonVariant variant;

  /// Shows a spinner and disables the button.
  final bool busy;

  /// Stretch to the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (variant) {
      FermataButtonVariant.primary => (c.accent, c.onAccent),
      FermataButtonVariant.secondary => (c.surfaceHigh, c.textPrimary),
      FermataButtonVariant.ghost => (Colors.transparent, c.accentText),
      FermataButtonVariant.danger => (c.danger, c.isDark ? const Color(0xFF1A0B09) : Colors.white),
    };
    final enabled = onPressed != null && !busy;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (icon != null)
          Icon(icon, size: 18),
        if (busy || icon != null) const SizedBox(width: 8),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1)),
      ],
    );
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? (variant == FermataButtonVariant.ghost ? Colors.transparent : c.surfaceHigh)
              : s.contains(WidgetState.hovered) && variant == FermataButtonVariant.primary
                  ? c.accentHover
                  : bg,
        ),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.textTertiary : fg),
        overlayColor: WidgetStatePropertyAll(fg.withValues(alpha: 0.08)),
        side: variant == FermataButtonVariant.ghost ? null : WidgetStatePropertyAll(BorderSide.none),
      ),
      child: child,
    );
  }
}
