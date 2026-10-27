import 'package:fermata/core/models/playback.dart';
import 'package:fermata/ui/player/queue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

/// Queue: Song 1 (played), Song 2 (current), Song 3..Song 6 (up next).
Future<FakeKit> _pumpQueue(WidgetTester tester, {Size size = TestSizes.expanded}) async {
  final kit = FakeKit(tracks: testTracks(6));
  kit.playback.load(kit.tracks.all, index: 1, playing: false, originLabel: 'Road trip');
  await pumpFermata(tester, kit: kit, initialRoute: '/queue', size: size);
  return kit;
}

void main() {
  group('QueuePage', () {
    testWidgets('shows now playing, up next, history and the origin', (tester) async {
      await _pumpQueue(tester);
      expect(find.byType(QueuePage), findsOneWidget);
      expect(find.text('Now playing'), findsOneWidget);
      expect(find.text('Up next'), findsOneWidget);
      expect(find.text('4 tracks'), findsOneWidget);
      expect(find.text('Played earlier'), findsOneWidget);
      expect(find.text('Playing from Road trip'), findsOneWidget);
      for (final title in ['Song 1', 'Song 2', 'Song 3', 'Song 6']) {
        expect(find.descendant(of: find.byType(QueuePage), matching: find.text(title)), findsOneWidget, reason: title);
      }
    });

    testWidgets('drag-and-drop reorder calls moveQueueItem with queue indices', (tester) async {
      final kit = await _pumpQueue(tester);
      final rowHeight = tester.getSize(find.widgetWithText(QueueRow, 'Song 3')).height;
      final handle = find.descendant(of: find.widgetWithText(QueueRow, 'Song 3'), matching: find.byIcon(Icons.drag_handle_rounded));

      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(0, rowHeight * 0.25));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await pumpFrames(tester);

      // Song 3 (queue index 2) moved further down: indices are absolute
      // queue positions (current item at 1 → up next starts at 2).
      expect(kit.playback.called('moveQueueItem'), isTrue);
      final args = kit.playback.argsOf('moveQueueItem');
      expect(args[0], 2);
      final to = args[1]! as int;
      expect(to, greaterThan(2));
      final titles = [for (final i in kit.playback.queue.items) i.track.title];
      expect(titles[to], 'Song 3');
      expect(titles.take(2), ['Song 1', 'Song 2']);
      // The list on screen follows the new order.
      expect(tester.getTopLeft(find.widgetWithText(QueueRow, 'Song 3')).dy,
          greaterThan(tester.getTopLeft(find.widgetWithText(QueueRow, 'Song 4')).dy));
    });

    testWidgets('reorder index mapping (onReorderItem) accounts for the current item', (tester) async {
      final kit = await _pumpQueue(tester);
      final list = tester.widget<ReorderableListView>(find.byType(ReorderableListView));
      list.onReorderItem!(3, 0);
      expect(kit.playback.argsOf('moveQueueItem'), [5, 2]);
    });

    testWidgets('swipe removes an item', (tester) async {
      final kit = await _pumpQueue(tester);
      await tester.drag(find.widgetWithText(QueueRow, 'Song 4'), const Offset(-600, 0));
      await pumpFrames(tester);
      expect(kit.playback.called('removeFromQueue'), isTrue);
      expect(kit.playback.queue.items.map((i) => i.track.title), isNot(contains('Song 4')));
      expect(find.text('Removed from queue'), findsOneWidget);
    });

    testWidgets('item menu: play next and remove', (tester) async {
      final kit = await _pumpQueue(tester);
      await tester.tap(find.descendant(of: find.widgetWithText(QueueRow, 'Song 5'), matching: find.byTooltip('More options')));
      await pumpFrames(tester);
      await tester.tap(find.text('Play next').last);
      await pumpFrames(tester);
      expect(kit.playback.argsOf('moveQueueItem'), [4, 2]);

      await tester.tap(find.descendant(of: find.widgetWithText(QueueRow, 'Song 6'), matching: find.byTooltip('More options')));
      await pumpFrames(tester);
      await tester.tap(find.text('Remove from queue').last);
      await pumpFrames(tester);
      expect(kit.playback.called('removeFromQueue'), isTrue);
    });

    testWidgets('tapping an item skips to it; history items replay', (tester) async {
      final kit = await _pumpQueue(tester);
      await tester.tap(find.widgetWithText(QueueRow, 'Song 4'));
      await tester.pump();
      expect(kit.playback.argsOf('skipToIndex'), [3]);
      await tester.tap(find.widgetWithText(QueueRow, 'Song 1'));
      await tester.pump();
      expect(kit.playback.argsOf('skipToIndex'), [0]);
    });

    testWidgets('clear queue asks for confirmation and keeps the current track', (tester) async {
      final kit = await _pumpQueue(tester);
      await tester.tap(find.text('Clear queue'));
      await pumpFrames(tester);
      expect(find.text('Clear the queue?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Clear queue'));
      await pumpFrames(tester);
      expect(kit.playback.argsOf('clearQueue'), [true]);
      expect(kit.playback.queue.items.single.track.title, 'Song 2');
    });

    testWidgets('smart-queue items are labeled "Suggested"', (tester) async {
      final kit = FakeKit(tracks: testTracks(3));
      kit.playback.setQueue(QueueState(items: [
        QueueItem(uid: 'a', track: kit.tracks.all[0]),
        QueueItem(uid: 'b', track: kit.tracks.all[1], origin: smartQueueOrigin),
        QueueItem(uid: 'c', track: kit.tracks.all[2]),
      ], currentIndex: 0));
      await pumpFermata(tester, kit: kit, initialRoute: '/queue');
      expect(find.descendant(of: find.widgetWithText(QueueRow, 'Song 2'), matching: find.text('Suggested')), findsOneWidget);
      expect(find.text('Suggested'), findsOneWidget);
    });

    testWidgets('empty queue shows an empty state', (tester) async {
      await pumpFermata(tester, initialRoute: '/queue');
      expect(find.text('Your queue is empty'), findsOneWidget);
    });

    testWidgets('fits a phone screen', (tester) async {
      await _pumpQueue(tester, size: TestSizes.compact);
      expect(tester.takeException(), isNull);
    });
  });
}
