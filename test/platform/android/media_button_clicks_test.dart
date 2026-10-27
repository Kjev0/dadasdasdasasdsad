import 'package:fermata/platform/android/media_button_clicks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late ManualTimers timers;
  late List<int> gestures;
  late MediaButtonClickDetector detector;

  setUp(() {
    timers = ManualTimers();
    gestures = [];
    detector = MediaButtonClickDetector(onGesture: gestures.add, timerFactory: timers.call);
  });

  test('single press is reported after the window', () {
    detector.press();
    expect(gestures, isEmpty);
    expect(timers.created.single.duration, const Duration(milliseconds: 400));
    timers.fireAll();
    expect(gestures, [1]);
  });

  test('double press within the window is one gesture of 2', () {
    detector
      ..press()
      ..press();
    expect(timers.active, 1, reason: 'the first timer is restarted');
    timers.fireAll();
    expect(gestures, [2]);
  });

  test('third press reports immediately; more presses start a new gesture', () {
    detector
      ..press()
      ..press()
      ..press();
    expect(gestures, [3]);
    expect(timers.active, 0);
    detector.press();
    timers.fireAll();
    expect(gestures, [3, 1]);
  });

  test('separate presses (window elapsed in between) are separate gestures', () {
    detector.press();
    timers.fireAll();
    detector.press();
    timers.fireAll();
    expect(gestures, [1, 1]);
  });

  test('dispose cancels a pending gesture', () {
    detector.press();
    detector.dispose();
    timers.fireAll();
    expect(gestures, isEmpty);
  });

  test('works with real timers', () async {
    final real = <int>[];
    final d = MediaButtonClickDetector(onGesture: real.add, window: const Duration(milliseconds: 20));
    d
      ..press()
      ..press();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(real, [2]);
  });
}
