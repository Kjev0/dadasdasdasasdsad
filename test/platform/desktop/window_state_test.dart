import 'dart:io';
import 'dart:ui';

import 'package:fermata/platform/desktop/window/window_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const fullHd = Rect.fromLTWH(0, 0, 1920, 1040);
  const rightMonitor = Rect.fromLTWH(1920, 0, 2560, 1400);

  group('fitWindowBounds', () {
    test('keeps bounds that are on a screen', () {
      const saved = WindowBounds(rect: Rect.fromLTWH(200, 100, 1000, 700));
      expect(fitWindowBounds(saved, [fullHd]), saved);
    });

    test('keeps bounds on a secondary monitor', () {
      const saved = WindowBounds(rect: Rect.fromLTWH(2200, 200, 1200, 800), maximized: true);
      expect(fitWindowBounds(saved, [fullHd, rightMonitor]), saved);
    });

    test('recenters on the primary display when the monitor is gone', () {
      const saved = WindowBounds(rect: Rect.fromLTWH(2200, 200, 1200, 800));
      final fitted = fitWindowBounds(saved, [fullHd]);
      expect(fitted.rect, Rect.fromLTWH((1920 - 1200) / 2, (1040 - 800) / 2, 1200, 800));
    });

    test('recenters when only a sliver of the title bar would be reachable', () {
      const saved = WindowBounds(rect: Rect.fromLTWH(1900, 100, 800, 700));
      final fitted = fitWindowBounds(saved, [fullHd]);
      expect(fullHd.contains(fitted.rect.topLeft), isTrue);
      expect(fitted.rect.size, const Size(800, 700));
    });

    test('recenters a window whose title bar is above the screen', () {
      const saved = WindowBounds(rect: Rect.fromLTWH(100, -500, 800, 700));
      expect(fitWindowBounds(saved, [fullHd]).rect.top, greaterThanOrEqualTo(0));
    });

    test('clamps the size to the minimum and to the largest screen', () {
      expect(fitWindowBounds(const WindowBounds(rect: Rect.fromLTWH(10, 10, 100, 100)), [fullHd]).rect.size,
          kMinWindowSize);
      final huge = fitWindowBounds(const WindowBounds(rect: Rect.fromLTWH(0, 0, 9000, 9000)), [fullHd]).rect;
      expect(huge.size, const Size(1920, 1040));
    });

    test('without display information clamps to sane values', () {
      final r = fitWindowBounds(const WindowBounds(rect: Rect.fromLTWH(-99999, 50, 100, 20000)), const []).rect;
      expect(r.left, 0);
      expect(r.top, 50);
      expect(r.width, kMinWindowSize.width);
      expect(r.height, 8192);
    });

    test('default bounds are centered and fit small screens', () {
      final d = defaultWindowBounds([const Rect.fromLTWH(0, 0, 1024, 600)])!.rect;
      expect(d.width, lessThanOrEqualTo(1024));
      expect(d.height, lessThanOrEqualTo(600));
      expect(d.center.dx, closeTo(512, 1));
      expect(defaultWindowBounds(const []), isNull);
    });
  });

  group('WindowStateStore', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('fermata-window-'));
    tearDown(() async => tmp.delete(recursive: true));

    test('round-trips bounds', () async {
      final store = WindowStateStore(File(p.join(tmp.path, 'window_state.json')));
      expect(await store.load(), isNull);
      const b = WindowBounds(rect: Rect.fromLTWH(12, 34, 900, 650), maximized: true);
      await store.save(b);
      expect(await store.load(), b);
    });

    test('ignores corrupt or nonsensical files', () async {
      final f = File(p.join(tmp.path, 'window_state.json'));
      final store = WindowStateStore(f);
      await f.writeAsString('{"x": 1');
      expect(await store.load(), isNull);
      await f.writeAsString('{"x": 1, "y": 2, "width": -5, "height": 100}');
      expect(await store.load(), isNull);
      await f.writeAsString('[1,2,3]');
      expect(await store.load(), isNull);
    });
  });
}
