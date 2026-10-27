import 'package:fermata/core/contracts/playback.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fakes.dart';
import 'fakes/harness.dart';

Duration s(num n) => Duration(milliseconds: (n * 1000).round());

void expectMonotonic(List<double> values, {required bool increasing}) {
  for (var i = 1; i < values.length; i++) {
    if (increasing) {
      expect(values[i], greaterThanOrEqualTo(values[i - 1] - 1e-9), reason: 'index $i of $values');
    } else {
      expect(values[i], lessThanOrEqualTo(values[i - 1] + 1e-9), reason: 'index $i of $values');
    }
  }
}

void main() {
  group('crossfade', () {
    test('ramps volumes with equal-power curves across two decks', () {
      fake((async) {
        final h = Harness(async, settings: withPlayback((p) => p.copyWith(crossfadeSeconds: 4)))..init();
        h.playAll(h.tracks(2));
        h.elapse(s(5.5));
        expect(h.backend.decks, hasLength(1), reason: 'no crossfade yet');
        h.elapse(s(1));
        expect(h.backend.decks, hasLength(2));
        expect(h.startedIds(), ['t0', 't1'], reason: 'the incoming track is current once the fade starts');
        expect(h.eventsOf<TrackEnded>().single.completed, isTrue);
        h.elapse(s(5));

        final outgoing = h.backend.decks[0];
        final incoming = h.backend.decks[1];
        expect(incoming.opens.single.uri, uriOf(track('t1')));
        expect(incoming.volumes.first, 0.0, reason: 'incoming deck starts silent');
        final outRamp = outgoing.volumes.sublist(1);
        final inRamp = incoming.volumes.sublist(1);
        expect(outRamp.length, inRamp.length);
        expect(outRamp.length, greaterThan(40), reason: '~4 s in 50 ms steps');
        expectMonotonic(outRamp, increasing: false);
        expectMonotonic(inRamp, increasing: true);
        for (var i = 0; i < outRamp.length; i++) {
          expect(outRamp[i] * outRamp[i] + inRamp[i] * inRamp[i], closeTo(1.0, 1e-6), reason: 'equal power at $i');
        }
        expect(outRamp.last, 0.0);
        expect(inRamp.last, 1.0);
        expect(outgoing.source, isNull, reason: 'outgoing deck stopped after the fade');
        expect(outgoing.preloads, isEmpty, reason: 'no gapless preload while crossfading');
        expect(h.snap.playing, isTrue);
        expect(h.currentId, 't1');
      });
    });

    test('ramps are scaled by the user volume', () {
      fake((async) {
        final h = Harness(async, settings: withPlayback((p) => p.copyWith(crossfadeSeconds: 2, volume: 0.5)))..init();
        h.playAll(h.tracks(2));
        h.elapse(s(11));
        final incoming = h.backend.decks[1];
        expect(incoming.volumes.last, closeTo(0.125, 1e-9));
        expect(incoming.volumes.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(0.125 + 1e-9));
      });
    });

    test('is disabled for repeat-one', () {
      fake((async) {
        final h = Harness(async, settings: withPlayback((p) => p.copyWith(crossfadeSeconds: 4)))..init();
        h.settle(h.controller.setRepeat(RepeatMode.one));
        h.playAll(h.tracks(2));
        h.elapse(s(12));
        expect(h.backend.decks, hasLength(1));
        expect(h.startedIds(), ['t0', 't0']);
      });
    });

    test('is disabled for previews', () {
      fake((async) {
        final h = Harness(async, settings: withPlayback((p) => p.copyWith(crossfadeSeconds: 4)))..init();
        final list = h.tracks(2);
        h.resolver.results[list[1].id] = ResolvedStream(
          source: PlayableSource(uri: Uri.parse('https://cdn.example/preview.mp3'), isPreview: true),
          playedTrack: list[1],
        );
        h.playAll(list);
        h.elapse(s(11));
        expect(h.backend.decks, hasLength(1));
        expect(h.currentId, 't1');
        expect(h.snap.isPreview, isTrue);
      });
    });

    test('manual skip less than 1 s into a track just switches', () {
      fake((async) {
        final h = Harness(async, settings: withPlayback((p) => p.copyWith(crossfadeSeconds: 4)))..init();
        h.playAll(h.tracks(3));
        h.elapse(s(0.5));
        h.settle(h.controller.next());
        expect(h.backend.decks, hasLength(1));
        expect(h.backend.decks[0].opens.last.uri, uriOf(track('t1')));
        expect(h.backend.decks[0].volumes.last, 1.0);
      });
    });

    test('manual skip later in a track crossfades; pausing finishes the fade', () {
      fake((async) {
        final h = Harness(async, trackLength: s(60), settings: withPlayback((p) => p.copyWith(crossfadeSeconds: 4)))
          ..init();
        h.playAll(h.tracks(3));
        h.elapse(s(3));
        h.settle(h.controller.next());
        expect(h.backend.decks, hasLength(2));
        final outgoing = h.backend.decks[0];
        final incoming = h.backend.decks[1];
        expect(incoming.opens.single.uri, uriOf(track('t1')));
        expect(outgoing.playing, isTrue, reason: 'outgoing still fading');
        h.elapse(s(1));
        expect(incoming.volume, inExclusiveRange(0.0, 1.0));
        h.settle(h.controller.pause());
        expect(outgoing.source, isNull, reason: 'fade completed immediately');
        expect(incoming.volume, 1.0);
        expect(incoming.playing, isFalse);
      });
    });
  });

  group('prefetch and gapless', () {
    test('resolves the next item ~15 s before the end and preloads it gaplessly', () {
      fake((async) {
        final h = Harness(async, trackLength: s(30))..init();
        h.playAll(h.tracks(3));
        h.elapse(s(14.5));
        expect(h.resolver.calls, [track('t0').id]);
        h.elapse(s(1));
        expect(h.resolver.calls, [track('t0').id, track('t1').id]);
        final deck = h.backend.decks.single;
        expect(deck.preloads.single.uri.toString(), uriOf(track('t1')));

        h.elapse(s(15));
        expect(h.currentId, 't1');
        expect(deck.opens, hasLength(1), reason: 'gapless transition, no reopen');
        expect(h.startedIds(), ['t0', 't1']);
        expect(h.eventsOf<TrackEnded>().single.completed, isTrue);
        expect(h.snap.position, lessThan(s(1)));
      });
    });

    test('queue edits drop a stale gapless preload', () {
      fake((async) {
        final h = Harness(async, trackLength: s(30))..init();
        h.playAll(h.tracks(3));
        h.elapse(s(20));
        final deck = h.backend.decks.single;
        expect(deck.preloads.single.uri.toString(), uriOf(track('t1')));
        h.settle(h.controller.playNext([track('x')]));
        expect(deck.clearPreloadCount, 1);
        h.elapse(s(1));
        expect(deck.preloads.last.uri.toString(), uriOf(track('x')));
        h.elapse(s(10));
        expect(h.currentId, 'x');
        expect(deck.opens, hasLength(1));
      });
    });

    test('without gapless the prefetched stream is reused at the end', () {
      fake((async) {
        final h = Harness(async, trackLength: s(30), settings: withPlayback((p) => p.copyWith(gapless: false)))..init();
        h.playAll(h.tracks(2));
        h.elapse(s(31));
        final deck = h.backend.decks.single;
        expect(deck.preloads, isEmpty);
        expect(deck.opens, hasLength(2));
        expect(h.resolver.callsFor(track('t1').id), 1);
        expect(h.currentId, 't1');
      });
    });

    test('preloadNext off: the next item is resolved only when needed', () {
      fake((async) {
        final h = Harness(async, trackLength: s(30), settings: withPlayback((p) => p, preloadNext: false))..init();
        h.playAll(h.tracks(2));
        h.elapse(s(29));
        expect(h.resolver.calls, [track('t0').id]);
        h.elapse(s(2));
        expect(h.resolver.calls, [track('t0').id, track('t1').id]);
        expect(h.currentId, 't1');
        expect(h.backend.decks.single.preloads, isEmpty);
      });
    });
  });

  group('sleep timer', () {
    test('fades out over the last 8 s, then pauses and clears the timer', () {
      fake((async) {
        final h = Harness(async, trackLength: const Duration(minutes: 5))..init();
        h.playAll(h.tracks(1));
        final deck = h.backend.decks.single;
        h.settle(h.controller.setSleepTimer(s(30)));
        expect(h.snap.sleepTimerEndsAt, h.now().add(s(30)));
        h.elapse(s(21.9));
        expect(deck.volume, 1.0);
        final before = deck.volumes.length;
        h.elapse(s(4));
        expect(deck.volume, inExclusiveRange(0.0, 1.0));
        h.elapse(s(4.2));
        final fade = deck.volumes.sublist(before);
        expect(fade.length, greaterThan(100));
        expectMonotonic(fade.sublist(0, fade.length - 1), increasing: false);
        expect(h.snap.playing, isFalse);
        expect(deck.playing, isFalse, reason: 'paused, not stopped');
        expect(deck.source, isNotNull);
        expect(h.snap.sleepTimerEndsAt, isNull);
        expect(deck.volume, 1.0, reason: 'gain restored after pausing');
        // resume plays at full volume
        h.settle(h.controller.play());
        expect(deck.playing, isTrue);
      });
    });

    test('without fade-out it just pauses at the deadline; null cancels', () {
      fake((async) {
        final h = Harness(async,
            trackLength: const Duration(minutes: 5),
            settings: withPlayback((p) => p.copyWith(sleepTimerFadeOut: false)))
          ..init();
        h.playAll(h.tracks(1));
        final deck = h.backend.decks.single;
        h.settle(h.controller.setSleepTimer(s(10)));
        final volumesBefore = deck.volumes.length;
        h.elapse(s(9.9));
        expect(h.snap.playing, isTrue);
        h.elapse(s(0.2));
        expect(h.snap.playing, isFalse);
        expect(deck.volumes.length, volumesBefore);

        h.settle(h.controller.play());
        h.settle(h.controller.setSleepTimer(s(10)));
        h.settle(h.controller.setSleepTimer(null));
        expect(h.snap.sleepTimerEndsAt, isNull);
        h.elapse(s(20));
        expect(h.snap.playing, isTrue);
      });
    });

    test('end-of-track mode pauses at the track boundary', () {
      fake((async) {
        final h = Harness(async, trackLength: s(20))..init();
        h.playAll(h.tracks(2));
        h.elapse(s(2));
        h.settle(h.controller.setSleepTimer(null, endOfTrack: true));
        expect(h.snap.sleepAtEndOfTrack, isTrue);
        final deck = h.backend.decks.single;
        h.elapse(s(10));
        expect(deck.preloads, isEmpty, reason: 'no gapless transition past the boundary');
        expect(deck.volume, 1.0);
        h.elapse(s(5));
        expect(deck.volume, inExclusiveRange(0.0, 1.0), reason: 'fading over the last 8 s');
        h.elapse(s(3.5));
        expect(h.snap.playing, isFalse);
        expect(h.currentId, 't1', reason: 'next item ready, paused');
        expect(h.startedIds(), ['t0']);
        expect(h.eventsOf<TrackEnded>().single.completed, isTrue);
        expect(h.snap.sleepAtEndOfTrack, isFalse);
        h.settle(h.controller.play());
        expect(h.startedIds(), ['t0', 't1']);
        expect(h.backend.decks.single.volume, 1.0);
      });
    });

    test('end-of-track mode set after a gapless preload drops it', () {
      fake((async) {
        final h = Harness(async, trackLength: s(20))..init();
        h.playAll(h.tracks(2));
        h.elapse(s(10));
        final deck = h.backend.decks.single;
        expect(deck.preloads, hasLength(1));
        h.settle(h.controller.setSleepTimer(null, endOfTrack: true));
        expect(deck.hasPreloaded, isFalse);
        h.elapse(s(11));
        expect(h.snap.playing, isFalse);
        expect(h.currentId, 't1');
      });
    });
  });
}
