import 'dart:convert';
import 'dart:math' as math;

import 'package:fermata/core/models/playback.dart';
import 'package:fermata/playback/queue/play_queue.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fakes.dart';

List<String> ids(PlayQueue q) => [for (final i in q.items) i.track.sourceTrackId];
List<String> originalIds(PlayQueue q) => [for (final i in q.originalOrder) i.track.sourceTrackId];

PlayQueue queueOf(int n, {int start = 0, int seed = 1}) {
  final q = PlayQueue(random: math.Random(seed));
  q.replace([for (var i = 0; i < n; i++) track('t$i')], startIndex: start, origin: 'album:x', originLabel: 'Album X');
  return q;
}

void main() {
  group('replace', () {
    test('sets play order, current index and origin label', () {
      final q = queueOf(5, start: 2);
      expect(ids(q), ['t0', 't1', 't2', 't3', 't4']);
      expect(q.currentIndex, 2);
      expect(q.current!.track.sourceTrackId, 't2');
      expect(q.state.originLabel, 'Album X');
      expect(q.items.every((i) => i.origin == 'album:x'), isTrue);
      expect(q.items.any((i) => i.addedManually), isFalse);
    });

    test('uids are unique even for duplicate tracks', () {
      final q = PlayQueue();
      q.replace([track('a'), track('a'), track('a')]);
      final uids = q.items.map((i) => i.uid).toSet();
      expect(uids, hasLength(3));
    });

    test('clamps start index and handles empty lists', () {
      final q = PlayQueue();
      q.replace([track('a'), track('b')], startIndex: 99);
      expect(q.currentIndex, 1);
      q.replace(const []);
      expect(q.currentIndex, -1);
      expect(q.current, isNull);
      expect(q.isEmpty, isTrue);
    });

    test('with shuffle the start item plays first', () {
      for (var seed = 0; seed < 20; seed++) {
        final q = PlayQueue(random: math.Random(seed));
        q.replace([for (var i = 0; i < 10; i++) track('t$i')], startIndex: 6, shuffle: true);
        expect(q.currentIndex, 0);
        expect(q.current!.track.sourceTrackId, 't6');
        expect(ids(q).toSet(), {for (var i = 0; i < 10; i++) 't$i'});
        expect(originalIds(q), [for (var i = 0; i < 10; i++) 't$i']);
      }
    });
  });

  group('shuffle', () {
    test('keeps the current item and contains every item exactly once', () {
      final q = queueOf(12, start: 4);
      final current = q.current;
      q.setShuffle(true);
      expect(q.shuffle, isTrue);
      expect(q.current, current);
      expect(q.currentIndex, 0);
      expect(ids(q), hasLength(12));
      expect(ids(q).toSet(), hasLength(12));
    });

    test('actually reorders (Fisher–Yates) and is seed-deterministic', () {
      final a = queueOf(20, seed: 7)..setShuffle(true);
      final b = queueOf(20, seed: 7)..setShuffle(true);
      expect(ids(a), ids(b));
      expect(ids(a), isNot([for (var i = 0; i < 20; i++) 't$i']));
    });

    test('manual "play next" items stay right after the current item', () {
      final q = queueOf(10, start: 3);
      q.playNext([track('n1'), track('n2')]);
      q.enqueue([track('e1')]);
      q.setShuffle(true);
      expect(ids(q).take(4), ['t3', 'n1', 'n2', 'e1']);
    });

    test('unshuffle restores the original order at the current item', () {
      final q = queueOf(10, start: 2);
      q.setShuffle(true);
      q.advance();
      q.advance();
      final current = q.current!;
      q.setShuffle(false);
      expect(ids(q), [for (var i = 0; i < 10; i++) 't$i']);
      expect(q.current, current);
      expect(q.currentIndex, q.items.indexOf(current));
    });

    test('play-next while shuffled lands after current in both orders', () {
      final q = queueOf(6, start: 1);
      q.setShuffle(true);
      final cur = q.current!;
      q.playNext([track('pn')]);
      expect(q.items[q.currentIndex + 1].track.sourceTrackId, 'pn');
      q.setShuffle(false);
      expect(q.current, cur);
      expect(ids(q), ['t0', 't1', 'pn', 't2', 't3', 't4', 't5']);
    });
  });

  group('navigation', () {
    test('repeat off: advance until the end, then null', () {
      final q = queueOf(3);
      expect(q.advance()!.track.sourceTrackId, 't1');
      expect(q.advance()!.track.sourceTrackId, 't2');
      expect(q.advance(), isNull);
      expect(q.currentIndex, 2, reason: 'position unchanged at the end');
      expect(q.peekNext(), isNull);
    });

    test('repeat all wraps to the start', () {
      final q = queueOf(3, start: 2)..repeat = RepeatMode.all;
      expect(q.peekNextIndex(), 0);
      expect(q.advance()!.track.sourceTrackId, 't0');
    });

    test('repeat one repeats on natural end but manual next moves on', () {
      final q = queueOf(3, start: 1)..repeat = RepeatMode.one;
      expect(q.advance()!.track.sourceTrackId, 't1');
      expect(q.advance(manual: true)!.track.sourceTrackId, 't2');
      expect(q.advance(manual: true)!.track.sourceTrackId, 't0', reason: 'manual next wraps under repeat-one');
    });

    test('previous: steps back; at the start only wraps with repeat', () {
      final q = queueOf(3, start: 1);
      expect(q.goPrevious()!.track.sourceTrackId, 't0');
      expect(q.goPrevious(), isNull);
      q.repeat = RepeatMode.all;
      expect(q.goPrevious()!.track.sourceTrackId, 't2');
    });

    test('skipToIndex validates bounds', () {
      final q = queueOf(3);
      expect(q.skipToIndex(2), isTrue);
      expect(q.current!.track.sourceTrackId, 't2');
      expect(q.skipToIndex(3), isFalse);
      expect(q.skipToIndex(-1), isFalse);
      expect(q.currentIndex, 2);
    });

    test('no current item: next is the first', () {
      final q = PlayQueue()..enqueue([track('a'), track('b')]);
      expect(q.current, isNull);
      expect(q.peekNextIndex(), 0);
      expect(q.advance()!.track.sourceTrackId, 'a');
    });

    test('recentTracks returns history up to the current item', () {
      final q = queueOf(30, start: 25);
      final recent = q.recentTracks(limit: 5);
      expect([for (final t in recent) t.sourceTrackId], ['t21', 't22', 't23', 't24', 't25']);
    });
  });

  group('editing', () {
    test('enqueue appends to both orders and marks manual', () {
      final q = queueOf(2);
      final added = q.enqueue([track('x')], origin: 'search');
      expect(ids(q), ['t0', 't1', 'x']);
      expect(originalIds(q), ['t0', 't1', 'x']);
      expect(added.single.addedManually, isTrue);
      expect(added.single.origin, 'search');
      final auto = q.enqueue([track('s')], origin: smartQueueOrigin, manual: false);
      expect(auto.single.addedManually, isFalse);
    });

    test('playNext inserts directly after the current item', () {
      final q = queueOf(4, start: 1);
      q.playNext([track('a'), track('b')]);
      expect(ids(q), ['t0', 't1', 'a', 'b', 't2', 't3']);
      expect(q.current!.track.sourceTrackId, 't1');
      expect(q.advance()!.track.sourceTrackId, 'a');
    });

    test('remove before current shifts the index; removing current reports it', () {
      final q = queueOf(5, start: 2);
      final before = q.remove(q.items[0].uid)!;
      expect(before.wasCurrent, isFalse);
      expect(q.current!.track.sourceTrackId, 't2');
      expect(q.currentIndex, 1);

      final cur = q.remove(q.current!.uid)!;
      expect(cur.wasCurrent, isTrue);
      expect(q.current!.track.sourceTrackId, 't3', reason: 'the following item becomes current');
      expect(originalIds(q), ['t1', 't3', 't4']);
    });

    test('removing the last current item selects the new last item', () {
      final q = queueOf(3, start: 2);
      q.remove(q.current!.uid);
      expect(q.current!.track.sourceTrackId, 't1');
      expect(q.remove('missing'), isNull);
    });

    test('removing everything empties the queue', () {
      final q = queueOf(1);
      q.remove(q.items.single.uid);
      expect(q.isEmpty, isTrue);
      expect(q.currentIndex, -1);
      expect(q.originLabel, isNull);
    });

    test('move keeps the current item tracked (drag-and-drop)', () {
      final q = queueOf(5, start: 2); // t2 current
      expect(q.move(0, 4), isTrue); // t0 to the end
      expect(ids(q), ['t1', 't2', 't3', 't4', 't0']);
      expect(q.current!.track.sourceTrackId, 't2');
      expect(q.move(4, 0), isTrue); // back to the front
      expect(ids(q), ['t0', 't1', 't2', 't3', 't4']);
      expect(q.current!.track.sourceTrackId, 't2');
      expect(q.move(2, 4), isTrue); // move the current item itself
      expect(q.currentIndex, 4);
      expect(q.current!.track.sourceTrackId, 't2');
      expect(originalIds(q), ids(q), reason: 'unshuffled: original follows play order');
      expect(q.move(0, 9), isFalse);
    });

    test('move while shuffled only changes the play order', () {
      final q = queueOf(5)..setShuffle(true);
      final original = originalIds(q);
      q.move(1, 3);
      expect(originalIds(q), original);
    });

    test('clear keeps the current item or empties completely', () {
      final q = queueOf(5, start: 3);
      q.clear(keepCurrent: true);
      expect(ids(q), ['t3']);
      expect(q.currentIndex, 0);
      expect(q.originLabel, 'Album X');
      q.clear(keepCurrent: false);
      expect(q.isEmpty, isTrue);
      expect(q.current, isNull);
      expect(q.originLabel, isNull);
    });
  });

  group('persistence', () {
    test('toJson/restoreJson round-trips order, original order and modes', () {
      final q = queueOf(8, start: 3, seed: 3)
        ..setShuffle(true)
        ..repeat = RepeatMode.all;
      q.playNext([track('pn')]);
      final json = jsonDecode(jsonEncode(q.toJson())) as Map<String, Object?>;

      final r = PlayQueue()..restoreJson(json);
      expect(ids(r), ids(q));
      expect(originalIds(r), originalIds(q));
      expect(r.currentIndex, q.currentIndex);
      expect(r.shuffle, isTrue);
      expect(r.repeat, RepeatMode.all);
      expect(r.originLabel, 'Album X');
      expect([for (final i in r.items) i.uid], [for (final i in q.items) i.uid]);
      expect(r.items.firstWhere((i) => i.track.sourceTrackId == 'pn').addedManually, isTrue);

      r.setShuffle(false);
      expect(ids(r).take(5), ['t0', 't1', 't2', 't3', 'pn']);
    });

    test('tolerates corrupt entries and inconsistent original order', () {
      final q = queueOf(3);
      final json = q.toJson();
      (json['items'] as List).add({'bogus': true});
      json['original'] = ['nope'];
      json['index'] = 99;
      final r = PlayQueue()..restoreJson(json);
      expect(ids(r), ['t0', 't1', 't2']);
      expect(originalIds(r), ['t0', 't1', 't2']);
      expect(r.shuffle, isFalse);
      expect(r.currentIndex, 2);
    });
  });
}
