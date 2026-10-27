import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2.x colour helpers used by the design tokens, the glass surfaces and
/// the contrast unit tests.
abstract final class Contrast {
  /// WCAG contrast ratio between two opaque colours (1..21).
  static double ratio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Source-over composite of [top] (with its alpha) on an opaque [bottom].
  static Color composite(Color top, Color bottom) {
    final a = top.a;
    return Color.from(
      alpha: 1,
      red: top.r * a + bottom.r * (1 - a),
      green: top.g * a + bottom.g * (1 - a),
      blue: top.b * a + bottom.b * (1 - a),
    );
  }

  /// Moves [color] away from [background] in HSL lightness until the
  /// contrast ratio reaches [target]. Lightens on dark backgrounds and darkens
  /// on light ones. Returns the closest achievable colour.
  static Color ensure(Color color, Color background, double target) {
    if (ratio(color, background) >= target) return color;
    final darkBg = background.computeLuminance() < 0.5;
    var hsl = HSLColor.fromColor(color);
    for (var i = 0; i < 100; i++) {
      final l = darkBg ? hsl.lightness + 0.01 : hsl.lightness - 0.01;
      hsl = hsl.withLightness(l.clamp(0.0, 1.0));
      final c = hsl.toColor();
      if (ratio(c, background) >= target) return c;
      if (l <= 0 || l >= 1) break;
    }
    return hsl.toColor();
  }

  /// Picks whichever of [dark] / [light] reads better on [background].
  static Color bestOn(Color background, {required Color dark, required Color light}) =>
      ratio(dark, background) >= ratio(light, background) ? dark : light;
}
