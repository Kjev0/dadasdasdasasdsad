import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/performance_profiles.dart';
import 'package:fermata/ui/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('palette tokens', () {
    test('dark tokens match the brand spec', () {
      final c = FermataColors.resolve(brightness: Brightness.dark);
      expect(c.bg, const Color(0xFF0C0C0E));
      expect(c.surface, const Color(0xFF141417));
      expect(c.surfaceRaised, const Color(0xFF1B1B20));
      expect(c.surfaceHigh, const Color(0xFF24242B));
      expect(c.outline, const Color(0xFF2E2E36));
      expect(c.outlineSubtle, const Color(0xFF232329));
      expect(c.textPrimary, const Color(0xFFF3F1EC));
      expect(c.textSecondary, const Color(0xFFA9A7A1));
      expect(c.textTertiary, const Color(0xFF6E6C68));
      expect(c.accent, const Color(0xFFE9B44C));
      expect(c.accentHover, const Color(0xFFF2C25E));
      expect(c.onAccent, const Color(0xFF17130A));
      expect(c.success, const Color(0xFF6BCB8B));
      expect(c.warning, const Color(0xFFE9A23B));
      expect(c.danger, const Color(0xFFEF6B5F));
    });

    test('light tokens match the brand spec', () {
      final c = FermataColors.resolve(brightness: Brightness.light);
      expect(c.bg, const Color(0xFFF6F4EF));
      expect(c.surface, const Color(0xFFFFFFFF));
      expect(c.surfaceRaised, const Color(0xFFFBFAF7));
      expect(c.surfaceHigh, const Color(0xFFEFEDE7));
      expect(c.outline, const Color(0xFFDEDAD2));
      expect(c.textPrimary, const Color(0xFF17161A));
      expect(c.textSecondary, const Color(0xFF57544F));
      expect(c.textTertiary, const Color(0xFF8A867F));
      expect(c.accent, const Color(0xFF8C6210));
      expect(c.onAccent, const Color(0xFFFFFFFF));
    });

    test('alternative accents use the brand values in dark mode', () {
      expect(FermataColors.resolve(brightness: Brightness.dark, accent: AccentChoice.coral).accent, const Color(0xFFFF8A6B));
      expect(FermataColors.resolve(brightness: Brightness.dark, accent: AccentChoice.mint).accent, const Color(0xFF6BD6B0));
      expect(FermataColors.resolve(brightness: Brightness.dark, accent: AccentChoice.ice).accent, const Color(0xFF8CC8FF));
      final mono = FermataColors.resolve(brightness: Brightness.dark, accent: AccentChoice.mono);
      expect(mono.accent, mono.textPrimary);
    });
  });

  group('contrast (WCAG)', () {
    test('ratio helper matches known values', () {
      expect(Contrast.ratio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(Contrast.ratio(Colors.white, Colors.white), closeTo(1, 0.001));
    });

    for (final brightness in Brightness.values) {
      for (final hc in [false, true]) {
        for (final accent in AccentChoice.values) {
          test('$brightness accent=${accent.name} highContrast=$hc', () {
            final c = FermataColors.resolve(brightness: brightness, accent: accent, highContrast: hc);
            final textMin = hc ? 7.0 : 4.5;
            for (final s in c.surfaces) {
              expect(Contrast.ratio(c.textPrimary, s), greaterThanOrEqualTo(textMin), reason: 'textPrimary on $s');
              expect(Contrast.ratio(c.textSecondary, s), greaterThanOrEqualTo(4.5), reason: 'textSecondary on $s');
              // Tertiary (captions/disabled) is only used on bg/surface/
              // surfaceRaised; in high contrast it must work everywhere.
              if (hc || s != c.surfaceHigh) {
                expect(Contrast.ratio(c.textTertiary, s), greaterThanOrEqualTo(hc ? 4.5 : 3.0), reason: 'textTertiary on $s');
              }
              expect(Contrast.ratio(c.accentText, s), greaterThanOrEqualTo(hc ? 7.0 : 4.5), reason: 'accentText on $s');
              for (final status in [c.success, c.warning, c.danger]) {
                expect(Contrast.ratio(status, s), greaterThanOrEqualTo(4.5), reason: 'status $status on $s');
              }
            }
            expect(Contrast.ratio(c.onAccent, c.accent), greaterThanOrEqualTo(4.5), reason: 'onAccent on accent');
          });
        }
      }
    }

    test('light-mode accents are derived for ≥ 4.5:1 text on surfaces', () {
      for (final accent in [AccentChoice.coral, AccentChoice.mint, AccentChoice.ice]) {
        final c = FermataColors.resolve(brightness: Brightness.light, accent: accent);
        for (final s in c.surfaces) {
          expect(Contrast.ratio(c.accent, s), greaterThanOrEqualTo(4.5), reason: '$accent on $s');
        }
      }
    });

    test('high contrast raises text and outline contrast', () {
      for (final b in Brightness.values) {
        final normal = FermataColors.resolve(brightness: b);
        final hc = FermataColors.resolve(brightness: b, highContrast: true);
        expect(Contrast.ratio(hc.textSecondary, hc.bg), greaterThan(Contrast.ratio(normal.textSecondary, normal.bg)));
        expect(Contrast.ratio(hc.textTertiary, hc.bg), greaterThan(Contrast.ratio(normal.textTertiary, normal.bg)));
        expect(Contrast.ratio(hc.outline, hc.bg), greaterThan(Contrast.ratio(normal.outline, normal.bg)));
      }
    });

    test('ensure() moves colours until the target is met', () {
      final c = Contrast.ensure(const Color(0xFF777777), Colors.white, 7);
      expect(Contrast.ratio(c, Colors.white), greaterThanOrEqualTo(7));
      final d = Contrast.ensure(const Color(0xFF444444), Colors.black, 7);
      expect(Contrast.ratio(d, Colors.black), greaterThanOrEqualTo(7));
    });
  });

  group('buildFermataTheme', () {
    test('installs every design extension', () {
      final t = buildFermataTheme(brightness: Brightness.dark);
      expect(t.extension<FermataColors>(), isNotNull);
      expect(t.extension<FermataSpacing>(), isNotNull);
      expect(t.extension<FermataRadii>(), isNotNull);
      expect(t.extension<FermataMotion>(), isNotNull);
      expect(t.extension<FermataTypography>(), isNotNull);
      expect(t.scaffoldBackgroundColor, const Color(0xFF0C0C0E));
      expect(t.colorScheme.primary, const Color(0xFFE9B44C));
    });

    test('type scale follows the spec (Manrope, sizes, weights, tracking)', () {
      final type = buildFermataTheme(brightness: Brightness.dark).extension<FermataTypography>()!;
      void check(TextStyle s, double size, double height, FontWeight w, double spacing) {
        expect(s.fontFamily, 'Manrope');
        expect(s.fontSize, size);
        expect(s.height! * size, closeTo(height, 0.01));
        expect(s.fontWeight, w);
        expect(s.letterSpacing, spacing);
      }

      check(type.display, 40, 44, FontWeight.w700, -1.0);
      check(type.headline, 28, 34, FontWeight.w700, -0.4);
      check(type.title, 20, 26, FontWeight.w600, 0);
      check(type.titleSmall, 16, 22, FontWeight.w600, 0);
      check(type.body, 15, 22, FontWeight.w500, 0);
      check(type.bodySmall, 13, 18, FontWeight.w500, 0);
      check(type.label, 13, 16, FontWeight.w600, 0.2);
      check(type.caption, 12, 16, FontWeight.w500, 0);
      expect(FermataTypography.tabular(type.caption).fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    test('textScale scales the type scale', () {
      final t = buildFermataTheme(brightness: Brightness.light, textScale: 1.5);
      expect(t.extension<FermataTypography>()!.body.fontSize, 22.5);
    });

    test('radii, spacing grid and density', () {
      const r = FermataRadii();
      expect([r.xs, r.sm, r.md, r.lg, r.xl], [6, 10, 14, 20, 28]);
      expect(FermataSpacing.grid, [4, 8, 12, 16, 20, 24, 32, 40, 56, 72]);
      expect(FermataSpacing.forDensity(UiDensity.compact).rowHeight, lessThan(FermataSpacing.forDensity(UiDensity.comfortable).rowHeight));
      expect(buildFermataTheme(brightness: Brightness.dark, density: UiDensity.compact).visualDensity, VisualDensity.compact);
    });

    test('motion tokens are scaled by EffectiveVisuals', () {
      expect(const FermataMotion().standard, const Duration(milliseconds: 220));
      expect(FermataMotion.baseMicro, const Duration(milliseconds: 120));
      expect(FermataMotion.baseEmphasis, const Duration(milliseconds: 360));

      EffectiveVisuals visuals(AppSettings s, {bool system = false}) =>
          EffectiveVisuals.from(s, systemReduceMotion: system, platformSupportsBlur: true);

      final full = FermataMotion.from(visuals(const AppSettings()));
      expect(full.standard, const Duration(milliseconds: 220));
      expect(full.curve, Curves.easeOutCubic);

      final reduced = FermataMotion.from(visuals(const AppSettings(), system: true));
      expect(reduced.animate, isFalse);

      const halfSettings = AppSettings(performance: PerformanceSettings(animations: AnimationLevel.reduced));
      expect(FermataMotion.from(visuals(halfSettings)).standard, const Duration(milliseconds: 110));

      const off = AppSettings(performance: PerformanceSettings(animations: AnimationLevel.off));
      final offMotion = FermataMotion.from(visuals(off));
      expect(offMotion.emphasis, Duration.zero);
      expect(offMotion.animate, isFalse);
    });

    test('lerp interpolates colours (theme animation)', () {
      final a = FermataColors.resolve(brightness: Brightness.dark);
      final b = FermataColors.resolve(brightness: Brightness.light);
      expect(a.lerp(b, 0).bg, a.bg);
      expect(a.lerp(b, 1).bg, b.bg);
    });
  });
}
