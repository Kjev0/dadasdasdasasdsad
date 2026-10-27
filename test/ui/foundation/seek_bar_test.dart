import 'package:fermata/ui/player/seek_bar.dart';
import 'package:fermata/ui/widgets/tracks/track_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

class _Host extends StatefulWidget {
  const _Host({required this.onSeek, this.duration = const Duration(minutes: 4)});

  final ValueChanged<Duration> onSeek;
  final Duration? duration;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Duration position = const Duration(minutes: 1);

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 500,
          child: SeekBar(
            position: position,
            duration: widget.duration,
            onSeek: (d) {
              widget.onSeek(d);
              setState(() => position = d);
            },
          ),
        ),
      );
}

String _label(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  test('formatDuration', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(seconds: 65)), '1:05');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(formatDuration(const Duration(seconds: -5)), '0:00');
  });

  group('SeekBar', () {
    testWidgets('shows elapsed / remaining with tabular figures', (tester) async {
      await pumpInApp(tester, _Host(onSeek: (_) {}));
      expect(_label(tester, 'seek-elapsed'), '1:00');
      expect(_label(tester, 'seek-remaining'), '-3:00');
      final style = tester.widget<Text>(find.byKey(const ValueKey('seek-elapsed'))).style!;
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('drag previews the target and seeks once on release', (tester) async {
      final seeks = <Duration>[];
      await pumpInApp(tester, _Host(onSeek: seeks.add));
      final bar = find.byType(CustomPaint).last;
      final rect = tester.getRect(find.descendant(of: find.byType(SeekBar), matching: find.byType(GestureDetector)).first);

      final gesture = await tester.startGesture(rect.centerLeft + const Offset(10, 0));
      await gesture.moveTo(rect.centerLeft + Offset(rect.width * 0.25, 0));
      await tester.pump();
      await gesture.moveTo(rect.centerLeft + Offset(rect.width * 0.75, 0));
      await tester.pump();
      // Preview: labels follow the drag, nothing sought yet.
      expect(_label(tester, 'seek-elapsed'), '3:00');
      expect(_label(tester, 'seek-remaining'), '-1:00');
      expect(seeks, isEmpty);
      await gesture.up();
      await tester.pump();
      expect(seeks, hasLength(1));
      expect(seeks.single.inSeconds, closeTo(180, 1));
      expect(bar, findsOneWidget);
    });

    testWidgets('tap seeks to the tapped position', (tester) async {
      final seeks = <Duration>[];
      await pumpInApp(tester, _Host(onSeek: seeks.add));
      final rect = tester.getRect(find.descendant(of: find.byType(SeekBar), matching: find.byType(GestureDetector)).first);
      await tester.tapAt(rect.centerLeft + Offset(rect.width / 2, 0));
      await tester.pump();
      expect(seeks.single.inSeconds, closeTo(120, 1));
    });

    testWidgets('keyboard: arrows step 5 s, Home/End jump', (tester) async {
      final seeks = <Duration>[];
      await pumpInApp(tester, _Host(onSeek: seeks.add));
      final focus = find.descendant(of: find.byType(SeekBar), matching: find.byType(Focus)).first;
      tester.widget<Focus>(focus).focusNode!.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(seeks.last, const Duration(minutes: 1, seconds: 5));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(seeks.last, const Duration(minutes: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(seeks.last, Duration.zero);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(seeks.last, const Duration(minutes: 3, seconds: 59));
    });

    testWidgets('exposes slider semantics with increase/decrease', (tester) async {
      final handle = tester.ensureSemantics();
      final seeks = <Duration>[];
      await pumpInApp(tester, _Host(onSeek: seeks.add));
      final node = tester.getSemantics(find.bySemanticsLabel('Playback position'));
      expect(node.value, '1:00');
      tester.semantics.increase(find.semantics.byLabel('Playback position'));
      await tester.pump();
      expect(seeks.last, const Duration(minutes: 1, seconds: 5));
      handle.dispose();
    });

    testWidgets('disabled when the duration is unknown', (tester) async {
      final seeks = <Duration>[];
      await pumpInApp(tester, _Host(onSeek: seeks.add, duration: null));
      final rect = tester.getRect(find.byType(SeekBar));
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(seeks, isEmpty);
      expect(_label(tester, 'seek-remaining'), '--:--');
    });
  });
}
