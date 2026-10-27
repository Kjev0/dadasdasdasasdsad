import 'package:flutter/material.dart';

import '../../settings/app_settings.dart';
import 'contrast.dart';

/// Raw brand palette (see `lib/ui/design/README.md`). Widgets never use these
/// directly — read [FermataColors] from the theme instead.
abstract final class FermataPalette {
  // Dark (primary) theme.
  static const darkBg = Color(0xFF0C0C0E);
  static const darkSurface = Color(0xFF141417);
  static const darkSurfaceRaised = Color(0xFF1B1B20);
  static const darkSurfaceHigh = Color(0xFF24242B);
  static const darkOutline = Color(0xFF2E2E36);
  static const darkOutlineSubtle = Color(0xFF232329);
  static const darkTextPrimary = Color(0xFFF3F1EC);
  static const darkTextSecondary = Color(0xFFA9A7A1);
  static const darkTextTertiary = Color(0xFF6E6C68);
  static const darkSuccess = Color(0xFF6BCB8B);
  static const darkWarning = Color(0xFFE9A23B);
  static const darkDanger = Color(0xFFEF6B5F);

  // Light theme.
  static const lightBg = Color(0xFFF6F4EF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceRaised = Color(0xFFFBFAF7);
  static const lightSurfaceHigh = Color(0xFFEFEDE7);
  static const lightOutline = Color(0xFFDEDAD2);
  static const lightOutlineSubtle = Color(0xFFE9E6DF);
  static const lightTextPrimary = Color(0xFF17161A);
  static const lightTextSecondary = Color(0xFF57544F);
  static const lightTextTertiary = Color(0xFF8A867F);
  static const lightSuccess = Color(0xFF2F7A4C);
  static const lightWarning = Color(0xFF93590A);
  static const lightDanger = Color(0xFFB3362B);

  // Accents.
  static const gold = Color(0xFFE9B44C);
  static const goldHover = Color(0xFFF2C25E);
  static const goldOn = Color(0xFF17130A);
  static const goldLight = Color(0xFF8C6210);
  static const goldLightHover = Color(0xFF765209);
  static const coral = Color(0xFFFF8A6B);
  static const mint = Color(0xFF6BD6B0);
  static const ice = Color(0xFF8CC8FF);

  /// Dark text used on light accent fills.
  static const inkOnAccent = Color(0xFF17130A);
}

/// Semantic colour tokens of the Fermata design system.
///
/// Resolve with [FermataColors.resolve]; read in widgets with
/// `context.colors` (see `context_ext.dart`).
@immutable
class FermataColors extends ThemeExtension<FermataColors> {
  const FermataColors({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceHigh,
    required this.outline,
    required this.outlineSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentHover,
    required this.onAccent,
    required this.accentText,
    required this.success,
    required this.warning,
    required this.danger,
    required this.scrim,
    required this.shadow,
  });

  /// Builds the token set for a theme. Light-mode accents are darkened until
  /// they reach ≥ 4.5:1 on every light surface; high contrast raises text,
  /// outline and accent-text contrast.
  factory FermataColors.resolve({
    required Brightness brightness,
    AccentChoice accent = AccentChoice.gold,
    bool highContrast = false,
  }) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? FermataPalette.darkBg : FermataPalette.lightBg;
    final surface = dark ? FermataPalette.darkSurface : FermataPalette.lightSurface;
    final surfaceRaised = dark ? FermataPalette.darkSurfaceRaised : FermataPalette.lightSurfaceRaised;
    final surfaceHigh = dark ? FermataPalette.darkSurfaceHigh : FermataPalette.lightSurfaceHigh;

    Color textPrimary, textSecondary, textTertiary, outline, outlineSubtle;
    if (highContrast) {
      textPrimary = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
      textSecondary = dark ? const Color(0xFFD6D4CE) : const Color(0xFF2E2C29);
      textTertiary = dark ? const Color(0xFFB2B0AA) : const Color(0xFF4A4743);
      outline = dark ? const Color(0xFF6A6A78) : const Color(0xFF7A766F);
      outlineSubtle = dark ? const Color(0xFF4A4A55) : const Color(0xFFA8A49B);
    } else {
      textPrimary = dark ? FermataPalette.darkTextPrimary : FermataPalette.lightTextPrimary;
      textSecondary = dark ? FermataPalette.darkTextSecondary : FermataPalette.lightTextSecondary;
      textTertiary = dark ? FermataPalette.darkTextTertiary : FermataPalette.lightTextTertiary;
      outline = dark ? FermataPalette.darkOutline : FermataPalette.lightOutline;
      outlineSubtle = dark ? FermataPalette.darkOutlineSubtle : FermataPalette.lightOutlineSubtle;
    }

    // The "worst" (closest to text colour) surface a text may sit on.
    final textTarget = highContrast ? 7.0 : 4.5;

    Color accentColor;
    Color accentHover;
    switch (accent) {
      case AccentChoice.gold:
        accentColor = dark ? FermataPalette.gold : FermataPalette.goldLight;
        accentHover = dark ? FermataPalette.goldHover : FermataPalette.goldLightHover;
      case AccentChoice.mono:
        accentColor = textPrimary;
        accentHover = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
      case AccentChoice.coral || AccentChoice.mint || AccentChoice.ice:
        final base = switch (accent) {
          AccentChoice.coral => FermataPalette.coral,
          AccentChoice.mint => FermataPalette.mint,
          _ => FermataPalette.ice,
        };
        accentColor = dark ? base : Contrast.ensure(base, surfaceHigh, 4.5);
        final hsl = HSLColor.fromColor(accentColor);
        accentHover = hsl.withLightness((hsl.lightness + (dark ? 0.06 : -0.06)).clamp(0.0, 1.0)).toColor();
    }

    final onAccent = switch (accent) {
      AccentChoice.mono => bg,
      AccentChoice.gold => dark ? FermataPalette.goldOn : const Color(0xFFFFFFFF),
      _ => Contrast.bestOn(accentColor, dark: FermataPalette.inkOnAccent, light: const Color(0xFFFFFFFF)),
    };

    Color statusColor(Color c) => Contrast.ensure(c, surfaceHigh, 4.5);

    return FermataColors(
      brightness: brightness,
      bg: bg,
      surface: surface,
      surfaceRaised: surfaceRaised,
      surfaceHigh: surfaceHigh,
      outline: outline,
      outlineSubtle: outlineSubtle,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textTertiary: textTertiary,
      accent: accentColor,
      accentHover: accentHover,
      onAccent: onAccent,
      accentText: Contrast.ensure(accentColor, surfaceHigh, textTarget),
      success: statusColor(dark ? FermataPalette.darkSuccess : FermataPalette.lightSuccess),
      warning: statusColor(dark ? FermataPalette.darkWarning : FermataPalette.lightWarning),
      danger: statusColor(dark ? FermataPalette.darkDanger : FermataPalette.lightDanger),
      scrim: dark ? const Color(0x99000000) : const Color(0x52000000),
      shadow: dark ? const Color(0x73000000) : const Color(0x1F000000),
    );
  }

  final Brightness brightness;

  /// App background (behind everything).
  final Color bg;

  /// Default content surface (cards, sidebar when glass is off).
  final Color surface;

  /// Surfaces raised one step (menus, dialogs, sheets).
  final Color surfaceRaised;

  /// Highest surface (inputs, hover fills, chips).
  final Color surfaceHigh;
  final Color outline;
  final Color outlineSubtle;
  final Color textPrimary;
  final Color textSecondary;

  /// Captions / disabled text only (≥ 3:1). Never for body copy.
  final Color textTertiary;

  /// Accent fill colour (buttons, active indicators, slider tracks).
  final Color accent;
  final Color accentHover;

  /// Text/icons drawn on [accent] fills.
  final Color onAccent;

  /// Accent variant guaranteed ≥ 4.5:1 (7:1 in high contrast) on every
  /// surface — use for accent-coloured text and small icons.
  final Color accentText;
  final Color success;
  final Color warning;
  final Color danger;

  /// Modal barrier colour.
  final Color scrim;

  /// Soft shadow colour (floating surfaces only).
  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  /// The surfaces text may be placed on (used by the contrast tests).
  List<Color> get surfaces => [bg, surface, surfaceRaised, surfaceHigh];

  @override
  FermataColors copyWith({
    Brightness? brightness,
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceHigh,
    Color? outline,
    Color? outlineSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentHover,
    Color? onAccent,
    Color? accentText,
    Color? success,
    Color? warning,
    Color? danger,
    Color? scrim,
    Color? shadow,
  }) =>
      FermataColors(
        brightness: brightness ?? this.brightness,
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surfaceRaised: surfaceRaised ?? this.surfaceRaised,
        surfaceHigh: surfaceHigh ?? this.surfaceHigh,
        outline: outline ?? this.outline,
        outlineSubtle: outlineSubtle ?? this.outlineSubtle,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        accent: accent ?? this.accent,
        accentHover: accentHover ?? this.accentHover,
        onAccent: onAccent ?? this.onAccent,
        accentText: accentText ?? this.accentText,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        scrim: scrim ?? this.scrim,
        shadow: shadow ?? this.shadow,
      );

  @override
  FermataColors lerp(FermataColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FermataColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      outline: l(outline, other.outline),
      outlineSubtle: l(outlineSubtle, other.outlineSubtle),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      accent: l(accent, other.accent),
      accentHover: l(accentHover, other.accentHover),
      onAccent: l(onAccent, other.onAccent),
      accentText: l(accentText, other.accentText),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      scrim: l(scrim, other.scrim),
      shadow: l(shadow, other.shadow),
    );
  }
}
