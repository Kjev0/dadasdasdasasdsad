import 'package:flutter/material.dart';

import '../../../settings/performance_profiles.dart';
import '../../design/contrast.dart';
import '../../design/fermata_colors.dart';

/// How a [GlassSurface] renders.
enum GlassMode {
  /// Glass off: opaque surface colour.
  solid,

  /// Glass on but blur disabled (performance / battery modes): translucent
  /// tinted fill, no `BackdropFilter`.
  translucent,

  /// Glass on and blur allowed: `BackdropFilter` + translucent fill.
  blurred;

  static GlassMode of(EffectiveVisuals visuals) {
    if (!visuals.glass) return GlassMode.solid;
    return visuals.blur ? GlassMode.blurred : GlassMode.translucent;
  }
}

/// Resolved paint values for a glass surface. Pure — unit tested for
/// readability (≥ 4.5:1 for primary and secondary text over the fill on the
/// worst-case ambient backdrop).
@immutable
class GlassSpec {
  const GlassSpec({
    required this.mode,
    required this.fill,
    required this.sigma,
    required this.border,
    required this.highlight,
    required this.sheen,
  });

  /// [intensity] 0..1 (settings `appearance.glassIntensity`). [base] is the
  /// opaque surface colour the glass replaces (defaults to `surface`).
  factory GlassSpec.resolve(FermataColors c, GlassMode mode, double intensity, {Color? base}) {
    final t = intensity.clamp(0.0, 1.0);
    final surface = base ?? c.surface;
    switch (mode) {
      case GlassMode.solid:
        return GlassSpec(
          mode: mode,
          fill: surface,
          sigma: 0,
          border: c.outlineSubtle,
          highlight: Colors.transparent,
          sheen: Colors.transparent,
        );
      case GlassMode.blurred:
      case GlassMode.translucent:
        final blurred = mode == GlassMode.blurred;
        // More intensity = more see-through. Without blur the fill stays
        // denser so content behind it doesn't become noisy.
        final requested = blurred ? 0.78 - 0.23 * t : 0.92 - 0.14 * t;
        final tinted = blurred ? surface : Color.alphaBlend(c.accent.withValues(alpha: 0.04), surface);
        final alpha = _readableAlpha(c, tinted, requested);
        final light = !c.isDark;
        return GlassSpec(
          mode: mode,
          fill: tinted.withValues(alpha: alpha),
          sigma: blurred ? 18 + 10 * t : 0,
          border: light ? const Color(0x14000000) : const Color(0x17FFFFFF),
          highlight: light ? const Color(0x99FFFFFF) : const Color(0x26FFFFFF),
          sheen: light ? const Color(0x33FFFFFF) : const Color(0x0FFFFFFF),
        );
    }
  }

  final GlassMode mode;

  /// Fill colour (translucent for glass modes).
  final Color fill;

  /// Backdrop blur sigma (0 unless [GlassMode.blurred]).
  final double sigma;

  /// 1 px hairline.
  final Color border;

  /// Soft highlight along the top edge.
  final Color highlight;

  /// Diagonal inner sheen (start colour; fades to transparent).
  final Color sheen;

  /// Opacity of the ambient-backdrop scrim drawn over artwork behind glass.
  static double scrimAlpha(FermataColors c) => c.isDark ? 0.72 : 0.70;

  /// The most extreme backdrops glass can sit on: the scrimmed ambient
  /// backdrop over pure white and pure black artwork.
  static List<Color> worstCaseBackdrops(FermataColors c) {
    final scrim = c.bg.withValues(alpha: scrimAlpha(c));
    return [
      Contrast.composite(scrim, const Color(0xFFFFFFFF)),
      Contrast.composite(scrim, const Color(0xFF000000)),
    ];
  }

  /// Opaque colours the fill can produce on the worst-case backdrops.
  List<Color> effectiveFills(FermataColors c) => [
        for (final b in worstCaseBackdrops(c)) Contrast.composite(fill, b),
      ];

  /// Lowest alpha ≥ [requested] at which primary and secondary text stay
  /// ≥ 4.5:1 on every worst-case backdrop.
  static double _readableAlpha(FermataColors c, Color fill, double requested) {
    final backdrops = worstCaseBackdrops(c);
    for (var a = requested; a < 1.0; a += 0.01) {
      final ok = backdrops.every((b) {
        final composite = Contrast.composite(fill.withValues(alpha: a), b);
        return Contrast.ratio(c.textPrimary, composite) >= 4.5 && Contrast.ratio(c.textSecondary, composite) >= 4.5;
      });
      if (ok) return a;
    }
    return 1.0;
  }
}
