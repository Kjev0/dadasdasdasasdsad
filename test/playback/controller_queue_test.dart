import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/playback/queue/play_queue.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fakes.dart';
import 'fakes/harness.dart';

Duration s(int n) => Duration(seconds: n);

List<String> queueIds(QueueState q) => [for (final i in q.items) i.track.sourceTrackId];

void main() {
  group('queue edits', () {
    test('are reflected in queueStream immediately and in playback', () {
      fake((async) {
        final h = Harness(async)..init();
        h.playAll(h.tracks(3)); // t0 t1 t2, 10 s each
        h.queues.clear();

        h.settle(h.controller.enqueue([track('e1')], origin: 'search'));
        expect(queueIds(h.queues.last), ['t0', 't1', 't2', 'e1']);
        h.settle(h.controller.playNext([track('n1')]));
        expect(queueIds(h.queues.last), ['t0', 'n1', 't1', 't2', 'e1']);
        expect(h.controller.queue.items[1].addedManually, isTrue);

        // remove an upcoming item → it never plays
        final t1 = h.controller.queue.items.firstWhere((i) => i.track.sourceTrackId == 't1');
        h.settle(h.controller.removeFromQueue(t1.uid));
        expect(queueIds(h.queues.last), ['t0', 'n1', 't2', 'e1']);

        // move: e1 before t2
        h.settle(h.controller.moveQueueItem(3, 2));
        expect(queueIds(h.queues.last), ['t0', 'n1', 'e1', 't2']);

        h.elapse(s(41));
        expect(h.startedIds(), ['t0', 'n1', 'e1', 't2']);
        expect(h.eventsOf<QueueEnded>(), hasLength(1));
      });
    });

    test('removing the current item starts the following one', () {
      fake((async) {
        final h = Harness(async)..init();
        h.playAll(h.tracks(3));
        h.elapse(s(2));
        h.settle(h.controller.removeFromQueue(h.controller.queue.current!.uid));
        expect(h.currentId, 't1');
        expect(h.snap.playing, isTrue);
        expect(h.backend.allOpens.last.uri, uriOf(track('t1')));
        expect(h.eventsOf<TrackEnded>().single.completed, isFalse);
      });
    });

    test('clearQueue keeps the current item or stops', () {
      fake((async) {
        final h = Harness(async)..init();
        h.playAll(h.tracks(4), start: 1);
        h.settle(h.controller.clearQueue());
        expect(queueIds(h.controller.queue), ['t1']);
        expect(h.snap.playing, isTrue);
        h.elapse(s(11));
        expect(h.eventsOf<QueueEnded>(), hasLength(1));

        h.playAll(h.tracks(2));
        h.settle(h.controller.clearQueue(keepCurrent: false));
        expect(h.controller.queue.isEmpty, isTrue);
        expect(h.snap.current, isNull);
        expect(h.snap.playing, isFalse);
      });
    });

    test('enqueue into an empty or ended queue makes the new item current', () {
      fake((async) {
        final h = Harness(async)..init();
        h.settle(h.controller.enqueue([track('a'), track('b')]));
        expect(h.currentId, 'a');
        expect(h.snap.playing, isFalse);
        h.settle(h.controller.play());
        expect(h.snap.playing, isTrue);
        h.elapse(s(21));
        expect(h.snap.status, PlayerStatus.completed);
        h.settle(h.controller.enqueue([track('c')]));
        expect(h.currentId, 'c');
        h.settle(h.controller.play());
        expect(h.backend.allOpens.last.uri, uriOf(track('c')));
      });
    });

    test('skipToIndex plays the chosen item', () {
      fake((async) {
        final h = Harness(async)..init();
        h.playAll(h.tracks(5));
        h.settle(h.controller.skipToIndex(3));
        expect(h.currentId, 't3');
        expect(h.snap.playing, isTrue);
        h.settle(h.controller.skipToIndex(42)); // ignored
        expect(h.currentId, 't3');
      });
    });
  });

  group('shuffle', () {
    test('keeps the current item; unshuffle restores the original order position', () {
      fake((async) {
        final h = Harness(async)..init();
        h.playAll(h.tracks(10), start: 4);
        h.elapse(s(3));
        final current = h.controller.queue.current;
        final opens = h.backend.allOpens.length;
        h.settle(h.controller.setShuffle(true));
        expect(h.snap.shuffle, isTrue);
        expect(h.controller.queue.current, current);
        expect(h.controller.queue.currentIndex, 0);
        expect(h.backend.allOpens.length, opens, reason: 'playback is not interrupted');
        expect(h.snap.position, greaterThan(s(2)));

        h.settle(h.controller.next());
        h.settle(h.controller.next());
        final playing = h.controller.queue.current!;
        h.settle(h.controller.setShuffle(false));
        expect(queueIds(h.controller.queue), [for (var i = 0; i < 10; i++) 't$i']);
        expect(h.controller.queue.current, playing);
        expect(h.controller.queue.currentIndex, h.controller.queue.items.indexOf(playing));
      });
    });

    test('playTracks(shuffle: true) starts at the chosen track', () {
      fake((async) {
        final h = Harness(async)..init();
        h.playAll(h.tracks(8), start: 5, shuffle: true);
        expect(h.currentId, 't5');
        expect(h.snap.shuffle, isTrue);
        expect(h.backend.allOpens.single.uri, uriOf(track('t5')));
      });
    });
  });

  group('repeat at queue end', () {
    test('off: queue ends, playback stops with QueueEnded', () {
      fake((async) {
        final h = Harness(async)..init();
        h.playAll(h.tracks(2));
        h.elapse(s(21));
        expect(h.startedIds(), ['t0', 't1']);
        expect(h.eventsOf<QueueEnded>(), hasLength(1));
        expect(h.snap.playing, isFalse);
        expect(h.snap.status, PlayerStatus.completed);
        expect(h.currentId, 't1');
        // play() afterwards replays the current item from the start
        h.settle(h.controller.play());
        expect(h.backend.allOpens.last.uri, uriOf(track('t1')));
        expect(h.backend.allOpens.last.start, Duration.zero);
      });
    });

    test('all: wraps to the first item', () {
      fake((async) {
        final h = Harness(async)..init();
        h.settle(h.controller.setRepeat(RepeatMode.all));
        h.playAll(h.tracks(2));
        h.elapse(s(25));
        expect(h.startedIds(), ['t0', 't1', 't0']);
        expect(h.eventsOf<QueueEnded>(), isEmpty);
        expect(h.snap.repeat, RepeatMode.all);
      });
    });

    test('one: repeats the current item; manual next still moves on', () {
      fake((async) {
        final h = Harness(async)..init();
        h.playAll(h.tracks(2));
        h.settle(h.controller.setRepeat(RepeatMode.one));
        h.elapse(s(25));
        expect(h.startedIds(), ['t0', 't0', 't0']);
        expect(h.resolver.callsFor(track('t0').id), 1, reason: 'the stream is reused');
        h.settle(h.controller.next());
        expect(h.currentId, 't1');
      });
    });

    test('cycleRepeat goes off → all → one → off', () {
      fake((async) {
        final h = Harness(async)..init();
        final seen = <RepeatMode>[];
        for (var i = 0; i < 3; i++) {
          h.settle(h.controller.cycleRepeat());
          seen.add(h.snap.repeat);
        }
        expect(seen, [RepeatMode.all, RepeatMode.one, RepeatMode.off]);
      });
    });
  });

  group('previous', () {
    test('restarts when past the threshold, otherwise goes back', () {
      fake((async) {
        final h = Harness(async,
            trackLength: s(60), settings: withPlayback((p) => p.copyWith(previousRestartThresholdSeconds: 5)))
          ..init();
        h.playAll(h.tracks(3), start: 1);
        h.elapse(s(6));
        h.settle(h.controller.previous());
        expect(h.currentId, 't1', reason: '6 s > 5 s → restart');
        expect(h.snap.position, Duration.zero);
        h.elapse(s(4));
        h.settle(h.controller.previous());
        expect(h.currentId, 't0', reason: '4 s ≤ 5 s → previous item');
        h.elapse(s(1));
        h.settle(h.controller.previous());
        expect(h.currentId, 't0', reason: 'no previous item → restart');
        expect(h.snap.position, Duration.zero);
      });
    });

    test('while paused, next/previous move without loading', () {
      fake((async) {
        final h = Harness(async)..init();
        h.playAll(h.tracks(3));
        h.settle(h.controller.pause());
        final opens = h.backend.allOpens.length;
        h.settle(h.controller.next());
        expect(h.currentId, 't1');
        expect(h.snap.playing, isFalse);
        expect(h.backend.allOpens.length, opens);
        h.settle(h.controller.play());
        expect(h.backend.allOpens.last.uri, uriOf(track('t1')));
      });
    });
  });

  group('smart queue', () {
    test('appends suggestions with origin smart-queue when the queue ends', () {
      fake((async) {
        final h = Harness(async, smartQueue: (recent) async => [track('s1'), track('s2')])..init();
        h.playAll(h.tracks(2));
        h.elapse(s(21));
        expect(h.smartQueueCalls.single.map((t) => t.sourceTrackId), ['t0', 't1']);
        expect(h.currentId, 's1');
        expect(h.controller.queue.current!.origin, smartQueueOrigin);
        expect(h.controller.queue.current!.addedManually, isFalse);
        expect(h.snap.playing, isTrue);
        expect(h.eventsOf<QueueEnded>(), isEmpty);
      });
    });

    test('disabled or empty suggestions: QueueEnded and stop', () {
      fake((async) {
        final h = Harness(async,
            smartQueue: (recent) async => [track('s1')], settings: withPlayback((p) => p.copyWith(smartQueue: false)))
          ..init();
        h.playAll(h.tracks(1));
        h.elapse(s(11));
        expect(h.smartQueueCalls, isEmpty);
        expect(h.eventsOf<QueueEnded>(), hasLength(1));

        final h2 = Harness(async, smartQueue: (recent) async => const <Track>[])..init();
        h2.playAll(h2.tracks(1));
        h2.elapse(s(11));
        expect(h2.smartQueueCalls, hasLength(1));
        expect(h2.eventsOf<QueueEnded>(), hasLength(1));
        expect(h2.snap.playing, isFalse);
      });
    });

    test('a failing provider falls back to QueueEnded', () {
      fake((async) {
        final h = Harness(async, smartQueue: (recent) async => throw StateError('offline'))..init();
        h.playAll(h.tracks(1));
        h.elapse(s(11));
        expect(h.eventsOf<QueueEnded>(), hasLength(1));
      });
    });
  });
}
