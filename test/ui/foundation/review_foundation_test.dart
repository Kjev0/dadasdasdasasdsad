// Reviewer tests: each one demonstrates a defect found in the UI foundation
// review. They are expected to FAIL until the defect is fixed.
import 'dart:async';

import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/ui/actions/track_actions.dart';
import 'package:fermata/ui/player/mini_mode.dart';
import 'package:fermata/ui/player/player_menus.dart';
import 'package:fermata/ui/widgets/media/shelf_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

void main() {
  group('review: SoundCloud silo', () {
    // PlaybackControllerImpl.enqueue/playNext never throw
    // UnsupportedSourceOperation('mix_queue') (grep: no "mix_queue" in
    // lib/playback). The fake's default (canJoin == null) behaves the same.
    // The UI relies solely on that exception, so with the real controller
    // the "Start a new queue?" dialog never appears.
    testWidgets('adding a SoundCloud track to an open (Audius) queue asks to start a new queue', (tester) async {
      final kit = FakeKit(tracks: testTracks(2));
      kit.playback.load(kit.tracks.all, playing: true);
      late WidgetRef ref;
      late BuildContext ctx;
      await pumpInApp(
        tester,
        Consumer(builder: (c, r, _) {
          ref = r;
          ctx = c;
          return const SizedBox();
        }),
        kit: kit,
      );
      final sc = testTrack('sc1', sourceId: SourceIds.soundcloud, title: 'Cloud song');
      unawaited(TrackActions(ctx, ref).addToQueue([sc]));
      await pumpFrames(tester);

      expect(find.text('Start a new queue?'), findsOneWidget, reason: 'compliance dialog must be shown');
      expect(kit.playback.called('enqueue'), isFalse, reason: 'must never silently add to a mixed queue');
    });
  });

  group('review: keyboard', () {
    testWidgets('Space on a focused checkbox toggles the checkbox, not playback', (tester) async {
      final kit = FakeKit(tracks: testTracks(1));
      kit.playback.load(kit.tracks.all, playing: true);
      await pumpFermata(tester, kit: kit);
      unawaited(kit.lifecycle.delegate!());
      await pumpFrames(tester);
      final paint = find.descendant(of: find.byType(Checkbox), matching: find.byType(CustomPaint)).first;
      Focus.of(tester.element(paint)).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await pumpFrames(tester);

      expect(kit.playback.called('togglePlayPause'), isFalse);
      expect(find.byWidgetPredicate((w) => w is Checkbox && w.value == true), findsOneWidget);
    });
  });

  group('review: mini mode', () {
    testWidgets('closing the window while in mini mode shows the close dialog', (tester) async {
      final kit = FakeKit(tracks: testTracks(1));
      kit.playback.load(kit.tracks.all, playing: true);
      await pumpFermata(tester, kit: kit);
      await appContainer(tester).read(miniModeProvider.notifier).enter();
      setTestWindowSize(tester, miniWindowSize);
      await pumpFrames(tester);
      expect(find.byType(MiniModeView), findsOneWidget);

      // The desktop lifecycle controller calls this when the user clicks
      // the window's close button (closeBehavior == ask).
      unawaited(kit.lifecycle.delegate!());
      await pumpFrames(tester);

      // The dialog is pushed on the offstage router navigator: invisible,
      // and DesktopLifecycleController._askingClose stays true.
      expect(find.text('Close Fermata?'), findsOneWidget);
    });

    test('fallback WindowManagerMiniWindow un-maximizes a maximized window before shrinking it', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final calls = <String>[];
      const channel = MethodChannel('window_manager');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'getBounds' => {'x': 0.0, 'y': 0.0, 'width': 1920.0, 'height': 1050.0},
          'isMaximized' => true,
          _ => null,
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await WindowManagerMiniWindow().setMiniMode(true);

      // A maximized GTK/Win32 window ignores setBounds, so mini mode would
      // leave a full-screen window showing the 380×132 mini view.
      expect(calls, contains(anyOf('unmaximize', 'restore')));
    });
  });

  group('review: shared widgets', () {
    testWidgets('ShelfRow re-enables the forward arrow when a resize makes the shelf overflow', (tester) async {
      await pumpInApp(
        tester,
        ShelfRow(
          title: 'Shelf',
          itemCount: 5,
          itemBuilder: (_, i) => SizedBox(width: 168, child: Text('item $i')),
        ),
      );
      IconButton forward() =>
          tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right_rounded));
      // 5 × 168 + 4 × 12 = 888 px fits in 1440 px: nothing to scroll.
      expect(forward().onPressed, isNull);

      // Desktop window made narrower: the shelf now overflows by ~88 px.
      setTestWindowSize(tester, const Size(800, 600));
      await pumpFrames(tester);
      expect(forward().onPressed, isNotNull, reason: 'items beyond the viewport are unreachable with the arrows');
    });

    testWidgets('sleep timer menu marks the running timer', (tester) async {
      final kit = FakeKit(tracks: testTracks(1));
      kit.playback.load(kit.tracks.all, playing: true);
      await pumpInApp(tester, const Center(child: SleepTimerButton()), kit: kit);
      await kit.playback.setSleepTimer(const Duration(minutes: 30));
      await pumpFrames(tester);
      expect(kit.playback.snapshot.sleepTimerEndsAt, isNotNull);

      await tester.tap(find.byType(SleepTimerButton));
      await pumpFrames(tester);
      expect(find.text('Off'), findsOneWidget, reason: 'menu is open');
      // "Off" is unchecked (a timer runs) and no preset is checked, so the
      // menu gives no indication of the active timer.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}
