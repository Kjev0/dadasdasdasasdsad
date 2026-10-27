import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/performance_profiles.dart';
import 'package:fermata/ui/design/design.dart';
import 'package:fermata/ui/player/player_bar.dart';
import 'package:fermata/ui/shell/sidebar.dart';
import 'package:fermata/ui/widgets/glass/ambient_backdrop.dart';
import 'package:fermata/ui/widgets/glass/glass_preview.dart';
import 'package:fermata/ui/widgets/glass/glass_spec.dart';
import 'package:fermata/ui/widgets/glass/glass_surface.dart';
import 'package:fermata/ui/widgets/tracks/track_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

AppSettings _settings({required bool glass, bool blur = true, AnimationLevel animations = AnimationLevel.full, double intensity = 0.6}) =>
    AppSettings(
      onboardingCompleted: true,
      appearance: AppearanceSettings(liquidGlass: glass, glassIntensity: intensity),
      performance: PerformanceSettings(blur: blur, animations: animations),
    );

EffectiveVisuals _visuals(AppSettings s) => EffectiveVisuals.from(s, systemReduceMotion: false, platformSupportsBlur: true);

Finder _inSidebar(Finder f) => find.descendant(of: find.byType(Sidebar), matching: f);
Finder _inPlayerBar(Finder f) => find.descendant(of: find.byType(PlayerBar), matching: f);

void main() {
  group('GlassMode', () {
    test('defaults to off (solid)', () {
      expect(const AppSettings().appearance.liquidGlass, isFalse);
      expect(GlassMode.of(_visuals(const AppSettings())), GlassMode.solid);
    });

    test('maps glass + blur settings', () {
      expect(GlassMode.of(_visuals(_settings(glass: true))), GlassMode.blurred);
      expect(GlassMode.of(_visuals(_settings(glass: true, blur: false))), GlassMode.translucent);
      expect(GlassMode.of(_visuals(_settings(glass: false))), GlassMode.solid);
      // Performance / battery presets disable blur → translucent glass.
      final battery = PerformanceProfiles.apply(_settings(glass: true), PerformanceMode.batterySaver);
      expect(GlassMode.of(_visuals(battery)), GlassMode.translucent);
    });
  });

  group('GlassSpec', () {
    test('blur sigma 18–28 and fill alpha 0.55–0.78 scale with intensity', () {
      final c = FermataColors.resolve(brightness: Brightness.dark);
      final low = GlassSpec.resolve(c, GlassMode.blurred, 0);
      final high = GlassSpec.resolve(c, GlassMode.blurred, 1);
      expect(low.sigma, 18);
      expect(high.sigma, 28);
      expect(low.fill.a, closeTo(0.78, 0.011));
      expect(high.fill.a, inInclusiveRange(0.55, 0.78));
      expect(high.fill.a, lessThan(low.fill.a));
    });

    test('solid mode is the opaque surface; translucent has no blur', () {
      final c = FermataColors.resolve(brightness: Brightness.light);
      final solid = GlassSpec.resolve(c, GlassMode.solid, 0.6);
      expect(solid.fill, c.surface);
      expect(solid.sigma, 0);
      final translucent = GlassSpec.resolve(c, GlassMode.translucent, 0.6);
      expect(translucent.sigma, 0);
      expect(translucent.fill.a, lessThan(1));
    });

    for (final b in Brightness.values) {
      for (final accent in AccentChoice.values) {
        test('text stays ≥ 4.5:1 over glass ($b, ${accent.name})', () {
          final c = FermataColors.resolve(brightness: b, accent: accent);
          for (final mode in GlassMode.values) {
            for (final intensity in [0.0, 0.5, 1.0]) {
              for (final base in [c.surface, c.surfaceRaised]) {
                final spec = GlassSpec.resolve(c, mode, intensity, base: base);
                for (final fill in spec.effectiveFills(c)) {
                  expect(Contrast.ratio(c.textPrimary, fill), greaterThanOrEqualTo(4.5), reason: '$mode $intensity primary');
                  expect(Contrast.ratio(c.textSecondary, fill), greaterThanOrEqualTo(4.5), reason: '$mode $intensity secondary');
                }
              }
            }
          }
        });
      }
    }
  });

  group('GlassSurface rendering', () {
    testWidgets('glass on + blur → BackdropFilter in sidebar and player bar', (tester) async {
      await pumpFermata(tester, kit: FakeKit(settings: _settings(glass: true)));
      expect(_inSidebar(find.byType(BackdropFilter)), findsOneWidget);
      expect(_inPlayerBar(find.byType(BackdropFilter)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('glass on + blur disabled → translucent fill, no BackdropFilter', (tester) async {
      await pumpFermata(tester, kit: FakeKit(settings: _settings(glass: true, blur: false)));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(GlassSurface), findsWidgets);
    });

    testWidgets('glass off → solid surfaces, no BackdropFilter', (tester) async {
      await pumpFermata(tester, kit: FakeKit(settings: _settings(glass: false)));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('compact layout: bottom nav + mini-player use glass', (tester) async {
      final kit = FakeKit(settings: _settings(glass: true), tracks: testTracks(1));
      kit.playback.load(kit.tracks.all);
      await pumpFermata(tester, kit: kit, size: TestSizes.compact);
      expect(find.descendant(of: find.byType(NavigationBar).hitTestable(), matching: find.byType(BackdropFilter)), findsNothing);
      // One for the bottom navigation, one for the mini-player.
      expect(find.byType(BackdropFilter), findsNWidgets(2));
    });

    testWidgets('toggling glass cross-fades between modes and settles', (tester) async {
      final kit = FakeKit(settings: _settings(glass: false));
      await pumpFermata(tester, kit: kit);
      expect(find.byType(BackdropFilter), findsNothing);

      await kit.settingsStore.update((s) => s.copyWith(appearance: s.appearance.copyWith(liquidGlass: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Mid cross-fade both layers exist (FadeTransition from AnimatedSwitcher).
      expect(_inSidebar(find.byType(BackdropFilter)), findsOneWidget);
      expect(_inSidebar(find.byType(FadeTransition)), findsWidgets);
      await pumpFrames(tester);
      expect(_inSidebar(find.byType(BackdropFilter)), findsOneWidget);

      await kit.settingsStore.update((s) => s.copyWith(appearance: s.appearance.copyWith(liquidGlass: false)));
      await pumpFrames(tester);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('animations off → mode switches instantly', (tester) async {
      final kit = FakeKit(settings: _settings(glass: false, animations: AnimationLevel.off));
      await pumpFermata(tester, kit: kit);
      await kit.settingsStore.update((s) => s.copyWith(appearance: s.appearance.copyWith(liquidGlass: true)));
      await tester.pump();
      await tester.pump();
      expect(_inSidebar(find.byType(BackdropFilter)), findsOneWidget);
    });
  });

  group('GlassPreview & ambient backdrop', () {
    testWidgets('GlassPreview follows overrides and live settings', (tester) async {
      final kit = FakeKit(settings: _settings(glass: false));
      await pumpFermata(tester, kit: kit, initialRoute: '/settings');
      final settingsContext = tester.element(find.text('Settings').last);

      Future<void> showPreview({GlassMode? mode}) async {
        showDialog<void>(
          context: settingsContext,
          builder: (_) => Dialog(child: SizedBox(width: 320, child: GlassPreview(mode: mode))),
        );
        await pumpFrames(tester);
      }

      await showPreview();
      expect(find.descendant(of: find.byType(GlassPreview), matching: find.byType(BackdropFilter)), findsNothing);
      expect(find.bySemanticsLabel('Solid surfaces'), findsOneWidget);

      // Live: turning glass on in settings updates the open preview.
      await kit.settingsStore.update((s) => s.copyWith(appearance: s.appearance.copyWith(liquidGlass: true)));
      await pumpFrames(tester);
      expect(find.descendant(of: find.byType(GlassPreview), matching: find.byType(BackdropFilter)), findsNWidgets(2));
      expect(find.bySemanticsLabel('Translucent with blur'), findsOneWidget);
      Navigator.of(settingsContext, rootNavigator: true).pop();
      await pumpFrames(tester);

      await showPreview(mode: GlassMode.translucent);
      expect(find.descendant(of: find.byType(GlassPreview), matching: find.byType(BackdropFilter)), findsNothing);
      expect(find.bySemanticsLabel('Translucent, no blur'), findsOneWidget);
    });

    testWidgets('shell paints an ambient backdrop behind the glass', (tester) async {
      final kit = FakeKit(settings: _settings(glass: true), tracks: [testTrack('a', artworkUrl: Uri.parse('https://img.invalid/a.jpg'))]);
      kit.playback.load(kit.tracks.all);
      await pumpFermata(tester, kit: kit);
      final backdrop = tester.widget<AmbientBackdrop>(find.byType(AmbientBackdrop).first);
      expect(backdrop.artworkUrl, Uri.parse('https://img.invalid/a.jpg'));
      // Blur allowed + artwork → heavily blurred artwork layer.
      expect(find.descendant(of: find.byType(AmbientBackdrop).first, matching: find.byType(ImageFiltered)), findsOneWidget);
    });

    testWidgets('blur off → cheap gradient backdrop (no ImageFiltered)', (tester) async {
      final kit = FakeKit(settings: _settings(glass: true, blur: false), tracks: [testTrack('a', artworkUrl: Uri.parse('https://img.invalid/a.jpg'))]);
      kit.playback.load(kit.tracks.all);
      await pumpFermata(tester, kit: kit);
      expect(find.descendant(of: find.byType(AmbientBackdrop).first, matching: find.byType(ImageFiltered)), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AmbientBackdrop).first,
          matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).gradient != null),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('sheets use glass when enabled', (tester) async {
    final kit = FakeKit(settings: _settings(glass: true), tracks: testTracks(1));
    await pumpInApp(tester, TrackTile(track: kit.tracks.all.single), kit: kit, size: TestSizes.compact);
    await tester.longPress(find.text('Song 1'));
    await pumpFrames(tester);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(BackdropFilter)), findsOneWidget);
  });
}
