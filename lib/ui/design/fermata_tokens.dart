import 'package:flutter/material.dart';

import '../../settings/app_settings.dart';
import '../../settings/performance_profiles.dart';

/// 4-pt spacing grid: 4, 8, 12, 16, 20, 24, 32, 40, 56, 72, plus
/// density-dependent component metrics.
@immutable
class FermataSpacing extends ThemeExtension<FermataSpacing> {
  const FermataSpacing({
    this.rowHeight = 56,
    this.controlHeight = 40,
    this.gutter = 24,
  });

  factory FermataSpacing.forDensity(UiDensity density) => density == UiDensity.compact
      ? const FermataSpacing(rowHeight: 48, controlHeight: 36, gutter: 16)
      : const FermataSpacing();

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s56 = 56;
  static const double s72 = 72;

  /// All grid steps, in order.
  static const grid = [s4, s8, s12, s16, s20, s24, s32, s40, s56, s72];

  /// Height of a track row / list tile.
  final double rowHeight;

  /// Height of buttons, inputs and segmented controls.
  final double controlHeight;

  /// Horizontal page padding on medium/expanded layouts (compact uses 16).
  final double gutter;

  /// Page padding for a given available width.
  EdgeInsets pagePadding(double width) =>
      EdgeInsets.symmetric(horizontal: width < 600 ? s16 : gutter, vertical: s16);

  @override
  FermataSpacing copyWith({double? rowHeight, double? controlHeight, double? gutter}) => FermataSpacing(
        rowHeight: rowHeight ?? this.rowHeight,
        controlHeight: controlHeight ?? this.controlHeight,
        gutter: gutter ?? this.gutter,
      );

  @override
  FermataSpacing lerp(FermataSpacing? other, double t) {
    if (other == null) return this;
    double l(double a, double b) => a + (b - a) * t;
    return FermataSpacing(
      rowHeight: l(rowHeight, other.rowHeight),
      controlHeight: l(controlHeight, other.controlHeight),
      gutter: l(gutter, other.gutter),
    );
  }
}

/// Corner radii: 6 / 10 / 14 / 20 / 28.
@immutable
class FermataRadii extends ThemeExtension<FermataRadii> {
  const FermataRadii({this.xs = 6, this.sm = 10, this.md = 14, this.lg = 20, this.xl = 28});

  /// Badges, small chips.
  final double xs;

  /// Buttons, inputs, list rows, small artwork.
  final double sm;

  /// Cards, menus, medium artwork.
  final double md;

  /// Dialogs, large artwork (now playing).
  final double lg;

  /// Bottom sheets, floating bars.
  final double xl;

  BorderRadius get xsAll => BorderRadius.circular(xs);
  BorderRadius get smAll => BorderRadius.circular(sm);
  BorderRadius get mdAll => BorderRadius.circular(md);
  BorderRadius get lgAll => BorderRadius.circular(lg);
  BorderRadius get xlAll => BorderRadius.circular(xl);

  @override
  FermataRadii copyWith({double? xs, double? sm, double? md, double? lg, double? xl}) =>
      FermataRadii(xs: xs ?? this.xs, sm: sm ?? this.sm, md: md ?? this.md, lg: lg ?? this.lg, xl: xl ?? this.xl);

  @override
  FermataRadii lerp(FermataRadii? other, double t) => other == null || t < 0.5 ? this : other;
}

/// Motion tokens. The exposed durations are already scaled by
/// [EffectiveVisuals.duration] (reduced motion halves them, "animations off"
/// makes them zero) — always use these instead of literal durations.
@immutable
class FermataMotion extends ThemeExtension<FermataMotion> {
  const FermataMotion({
    this.micro = baseMicro,
    this.standard = baseStandard,
    this.emphasis = baseEmphasis,
    this.curve = Curves.easeOutCubic,
    this.animate = true,
  });

  factory FermataMotion.from(EffectiveVisuals? visuals) {
    if (visuals == null) return const FermataMotion();
    return FermataMotion(
      micro: visuals.duration(baseMicro),
      standard: visuals.duration(baseStandard),
      emphasis: visuals.duration(baseEmphasis),
      animate: visuals.animate,
    );
  }

  static const baseMicro = Duration(milliseconds: 120);
  static const baseStandard = Duration(milliseconds: 220);
  static const baseEmphasis = Duration(milliseconds: 360);

  /// Hover/press feedback.
  final Duration micro;

  /// Most transitions (cross-fades, page fades, expanding panels).
  final Duration standard;

  /// Large movements (now-playing sheet, glass mode change).
  final Duration emphasis;
  final Curve curve;

  /// False when animations are off — continuous animations must not run.
  final bool animate;

  @override
  FermataMotion copyWith({Duration? micro, Duration? standard, Duration? emphasis, Curve? curve, bool? animate}) =>
      FermataMotion(
        micro: micro ?? this.micro,
        standard: standard ?? this.standard,
        emphasis: emphasis ?? this.emphasis,
        curve: curve ?? this.curve,
        animate: animate ?? this.animate,
      );

  @override
  FermataMotion lerp(FermataMotion? other, double t) => other == null || t < 0.5 ? this : other;
}

/// Manrope type scale. `TextTheme` slots are mapped in `buildFermataTheme`;
/// use these named styles for anything outside Material components.
@immutable
class FermataTypography extends ThemeExtension<FermataTypography> {
  const FermataTypography({
    required this.display,
    required this.headline,
    required this.title,
    required this.titleSmall,
    required this.body,
    required this.bodySmall,
    required this.label,
    required this.caption,
  });

  factory FermataTypography.build({required Color primary, required Color secondary, double scale = 1.0}) {
    TextStyle s(double size, double height, FontWeight w, double spacing, Color c) => TextStyle(
          fontFamily: fontFamily,
          fontSize: size * scale,
          height: height / size,
          fontWeight: w,
          letterSpacing: spacing,
          color: c,
        );
    return FermataTypography(
      display: s(40, 44, FontWeight.w700, -1.0, primary),
      headline: s(28, 34, FontWeight.w700, -0.4, primary),
      title: s(20, 26, FontWeight.w600, 0, primary),
      titleSmall: s(16, 22, FontWeight.w600, 0, primary),
      body: s(15, 22, FontWeight.w500, 0, primary),
      bodySmall: s(13, 18, FontWeight.w500, 0, secondary),
      label: s(13, 16, FontWeight.w600, 0.2, primary),
      caption: s(12, 16, FontWeight.w500, 0, secondary),
    );
  }

  static const fontFamily = 'Manrope';

  /// Use for times, counters and anything that updates in place.
  static const tabularFigures = [FontFeature.tabularFigures()];

  final TextStyle display;
  final TextStyle headline;
  final TextStyle title;
  final TextStyle titleSmall;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle label;
  final TextStyle caption;

  /// [style] with tabular (fixed-width) digits.
  static TextStyle tabular(TextStyle style) => style.copyWith(fontFeatures: tabularFigures);

  @override
  FermataTypography copyWith({
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? titleSmall,
    TextStyle? body,
    TextStyle? bodySmall,
    TextStyle? label,
    TextStyle? caption,
  }) =>
      FermataTypography(
        display: display ?? this.display,
        headline: headline ?? this.headline,
        title: title ?? this.title,
        titleSmall: titleSmall ?? this.titleSmall,
        body: body ?? this.body,
        bodySmall: bodySmall ?? this.bodySmall,
        label: label ?? this.label,
        caption: caption ?? this.caption,
      );

  @override
  FermataTypography lerp(FermataTypography? other, double t) {
    if (other == null) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return FermataTypography(
      display: l(display, other.display),
      headline: l(headline, other.headline),
      title: l(title, other.title),
      titleSmall: l(titleSmall, other.titleSmall),
      body: l(body, other.body),
      bodySmall: l(bodySmall, other.bodySmall),
      label: l(label, other.label),
      caption: l(caption, other.caption),
    );
  }
}
