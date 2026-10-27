import 'package:fermata/app/app.dart';
import 'package:fermata/app/router.dart';
import 'package:fermata/app/services.dart';
import 'package:fermata/l10n/gen/app_localizations.dart';
import 'package:fermata/ui/design/theme.dart';
import 'package:fermata/ui/widgets/util/async_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_kit.dart';

/// Standard test window sizes.
abstract final class TestSizes {
  static const compact = Size(360, 640);
  static const medium = Size(800, 600);
  static const expanded = Size(1440, 900);
}

/// Pumps the full app (`FermataApp` + router + shell) with fake services.
///
/// * [kit] — the fakes (a fresh [FakeKit] when omitted); returned for
///   assertions.
/// * [services] — use a custom `AppServices` instead of `kit.services`.
/// * [initialRoute] — location to open (default `/home`).
/// * [size] — logical window size (device pixel ratio 1).
/// * [overrides] — extra provider overrides.
///
/// Pumps ~600 ms of frames instead of `pumpAndSettle` so continuous
/// animations (e.g. a playing equalizer glyph) can't hang the test.
Future<FakeKit> pumpFermata(
  WidgetTester tester, {
  FakeKit? kit,
  AppServices? services,
  String initialRoute = '/home',
  Size size = TestSizes.expanded,
  List<Override> overrides = const [],
}) async {
  final k = kit ?? FakeKit();
  setTestWindowSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...k.overrides(services: services),
        initialLocationProvider.overrideWithValue(initialRoute),
        ...overrides,
      ],
      retry: noRetry,
      child: const FermataApp(),
    ),
  );
  await pumpFrames(tester);
  return k;
}

/// Sets the logical test window size (DPR 1); reset after the test.
void setTestWindowSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Pumps [count] frames of [step] (default ~600 ms total).
Future<void> pumpFrames(WidgetTester tester, {int count = 12, Duration step = const Duration(milliseconds: 50)}) async {
  await tester.pump();
  for (var i = 0; i < count; i++) {
    await tester.pump(step);
  }
}

/// The app's router (to navigate in tests): `appRouter(tester).go('/queue')`.
GoRouter appRouter(WidgetTester tester) {
  final element = tester.element(find.byType(FermataApp));
  return ProviderScope.containerOf(element).read(routerProvider);
}

/// Navigates and pumps frames.
Future<void> goTo(WidgetTester tester, String location) async {
  appRouter(tester).go(location);
  await pumpFrames(tester);
}

/// Pumps a single widget inside a themed, localized `MaterialApp` with the
/// kit's provider overrides (no router/shell). Returns the kit.
Future<FakeKit> pumpInApp(
  WidgetTester tester,
  Widget child, {
  FakeKit? kit,
  Size size = TestSizes.expanded,
  Brightness brightness = Brightness.dark,
  List<Override> overrides = const [],
}) async {
  final k = kit ?? FakeKit();
  setTestWindowSize(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...k.overrides(), ...overrides],
      retry: noRetry,
      child: MaterialApp(
        theme: buildFermataTheme(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await pumpFrames(tester);
  return k;
}

/// The test's provider container.
ProviderContainer appContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FermataApp)));
