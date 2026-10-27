import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'fermata_colors.dart';
import 'fermata_tokens.dart';

/// Short accessors for design tokens and strings:
/// `context.colors.accent`, `context.type.title`, `context.motion.standard`,
/// `context.l10n.navHome`.
///
/// Falls back to default tokens when the theme was not built with
/// `buildFermataTheme` (e.g. in isolated widget tests).
extension FermataContext on BuildContext {
  ThemeData get _theme => Theme.of(this);

  FermataColors get colors =>
      _theme.extension<FermataColors>() ?? FermataColors.resolve(brightness: _theme.brightness);

  FermataSpacing get spacing => _theme.extension<FermataSpacing>() ?? const FermataSpacing();

  FermataRadii get radii => _theme.extension<FermataRadii>() ?? const FermataRadii();

  FermataMotion get motion => _theme.extension<FermataMotion>() ?? const FermataMotion();

  FermataTypography get type =>
      _theme.extension<FermataTypography>() ??
      FermataTypography.build(primary: colors.textPrimary, secondary: colors.textSecondary);

  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Height of a two-line list row (track / queue rows): the density's row
  /// height, grown with the text scale so large text never overflows.
  double get rowExtent {
    final scale = MediaQuery.textScalerOf(this).scale(100) / 100;
    final text = 42 * scale + 6;
    return text > spacing.rowHeight ? text : spacing.rowHeight;
  }
}
