import 'package:fermata/core/contracts/playback.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/playback/backend/audio_backend.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fakes.dart';
import 'fakes/harness.dart';

Duration s(int n) => Duration(seconds: n);

PlayableSource remote(String name, {DateTime? expiresAt}) =>
    PlayableSource(uri: Uri.parse('https://cdn.example/$name.mp3'), expiresAt: expiresAt, headers: const {'Authorization': 'OAuth x'});

void main() {
  group('unplayable items', () {
    test('are skipped with a PlaybackFailed(skipped) event', () {
      fake((async) {
        final h = Harness(async)..init();
        final list = h.tracks(3);
        h.resolver.unplayable(list[1]);
        h.playAll(list);
        h.elapse(s(11));
        final failed = h.eventsOf<PlaybackFailed>().single;
        expect(failed.item.track, list[1]);
        expect(failed.skipped, isTrue);
        expect(failed.error, isA<UnplayableTrackException>());
        expect(h.currentId, 't2');
        expect(h.snap.playing, isTrue);
        expect(h.startedIds(), ['t0', 't2']);
      });
    });

    test('the error code is shown until the next track starts', () {
      fake((async) {
        final h = Harness(async, settings: withPlayback((p) => p.copyWith(skipUnplayable: false)))..init();
        final list = h.tracks(2);
        h.resolver.unplayable(list[0], AvailabilityReason.subscriptionRequired);
        h.playAll(list);
        expect(h.snap.errorMessage, AvailabilityReason.subscriptionRequired);
        expect(h.snap.status, PlayerStatus.error);
        expect(h.snap.playing, isFalse);
        expect(h.eventsOf<PlaybackFailed>().single.skipped, isFalse);
        expect(h.currentId, 't0', reason: 'skipUnplayable off: stays on the failed item');
        h.settle(h.controller.next());
        h.settle(h.controller.play());
        expect(h.snap.errorMessage, isNull);
        expect(h.snap.status, PlayerStatus.ready);
      });
    });

    test('an all-unplayable queue stops after one pass (no infinite loop)', () {
      fake((async) {
        final h = Harness(async)..init();
        h.settle(h.controller.setRepeat(RepeatMode.all));
        final list = h.tracks(3);
        for (final t in list) {
          h.resolver.unplayable(t);
        }
        h.playAll(list);
        h.elapse(s(5));
        final failed = h.eventsOf<PlaybackFailed>();
        expect(failed, hasLength(3));
        expect(failed.map((e) => e.skipped), [true, true, false]);
        expect(h.resolver.calls, hasLength(3));
        expect(h.snap.playing, isFalse);
        expect(h.snap.status, PlayerStatus.error);
        expect(h.snap.errorMessage, AvailabilityReason.regionRestricted);
        expect(h.backend.allOpens, isEmpty);
      });
    });

    test('the last unplayable item without repeat ends the queue', () {
      fake((async) {
        final h = Harness(async)..init();
        final list = h.tracks(2);
        h.resolver.unplayable(list[1]);
        h.playAll(list);
        h.elapse(s(11));
        expect(h.eventsOf<PlaybackFailed>().single.skipped, isFalse);
        expect(h.eventsOf<QueueEnded>(), hasLength(1));
        expect(h.snap.playing, isFalse);
      });
    });

    test('a deck that cannot open the file is treated like an unplayable item', () {
      fake((async) {
        final h = Harness(async)..init();
        final list = h.tracks(2);
        h.backend.failOpen.add(uriOf(list[0]));
        h.playAll(list);
        final failed = h.eventsOf<PlaybackFailed>().single;
        expect(failed.item.track, list[0]);
        expect(failed.skipped, isTrue);
        expect(h.currentId, 't1');
        expect(h.snap.playing, isTrue);
      });
    });

    test('a fatal decoder error on a local file skips to the next item', () {
      fake((async) {
        final h = Harness(async)..init();
        final list = h.tracks(2);
        h.backend.errorAfterOpen.add(uriOf(list[0]));
        h.playAll(list);
        async.flushMicrotasks();
        expect(h.eventsOf<PlaybackFailed>().single.error, isA<DeckError>());
        expect(h.currentId, 't1');
      });
    });

    test('non-fatal deck errors are ignored', () {
      fake((async) {
        final h = Harness(async)..init();
        h.playAll(h.tracks(2));
        h.backend.decks.single.emitError(const DeckError('glitch', fatal: false));
        async.flushMicrotasks();
        expect(h.eventsOf<PlaybackFailed>(), isEmpty);
        expect(h.currentId, 't0');
      });
    });
  });

  group('signed URL expiry', () {
    test('resume after expiry re-resolves and continues at the same position', () {
      fake((async) {
        final h = Harness(async, trackLength: const Duration(minutes: 4))..init();
        final t = track('r', source: 'soundcloud');
        h.resolver.onResolve = (tr, call) => remote('r$call', expiresAt: h.now().add(const Duration(minutes: 2)));
        h.playAll([t]);
        h.elapse(s(30));
        h.settle(h.controller.pause());
        final pausedAt = h.snap.position;
        h.elapse(const Duration(minutes: 5)); // URL expired meanwhile
        h.settle(h.controller.play());
        expect(h.resolver.callsFor(t.id), 2);
        final open = h.backend.allOpens.last;
        expect(open.uri, 'https://cdn.example/r2.mp3');
        expect(open.start, pausedAt);
        expect(open.source.headers['Authorization'], 'OAuth x');
        expect(h.snap.playing, isTrue);
        expect(h.eventsOf<TrackStarted>(), hasLength(1), reason: 'same listening session');
        expect(h.eventsOf<TrackEnded>(), isEmpty);
      });
    });

    test('seek after expiry re-resolves and opens at the seek target', () {
      fake((async) {
        final h = Harness(async, trackLength: const Duration(minutes: 10))..init();
        final t = track('r', source: 'soundcloud');
        h.resolver.onResolve = (tr, call) => remote('r$call', expiresAt: h.now().add(const Duration(seconds: 60)));
        h.playAll([t]);
        h.elapse(s(70));
        h.settle(h.controller.seek(s(200)));
        expect(h.resolver.callsFor(t.id), 2);
        expect(h.backend.allOpens.last.start, s(200));
        expect(h.snap.playing, isTrue);
      });
    });

    test('no re-resolution before expiry', () {
      fake((async) {
        final h = Harness(async, trackLength: const Duration(minutes: 10))..init();
        final t = track('r', source: 'soundcloud');
        h.resolver.onResolve = (tr, call) => remote('r$call', expiresAt: h.now().add(const Duration(hours: 1)));
        h.playAll([t]);
        h.elapse(s(5));
        h.settle(h.controller.seek(s(100)));
        h.settle(h.controller.pause());
        h.settle(h.controller.play());
        expect(h.resolver.callsFor(t.id), 1);
        expect(h.backend.allOpens, hasLength(1));
      });
    });

    test('a stream error mid-way on a remote source re-resolves once at the position', () {
      fake((async) {
        final h = Harness(async, trackLength: const Duration(minutes: 10))..init();
        final list = [track('r', source: 'soundcloud'), track('next')];
        h.resolver.onResolve = (tr, call) => tr.sourceTrackId == 'r' ? remote('r$call') : null;
        h.playAll(list);
        h.elapse(s(42));
        final deck = h.backend.decks.single;
        deck.emitError(const DeckError('HTTP 403'));
        async.flushMicrotasks();
        expect(h.resolver.callsFor(list[0].id), 2);
        expect(h.backend.allOpens.last.start, s(42));
        expect(h.currentId, 'r');
        expect(h.eventsOf<PlaybackFailed>(), isEmpty);

        // A second failure is final: skip.
        h.elapse(s(1));
        deck.emitError(const DeckError('HTTP 403'));
        async.flushMicrotasks();
        expect(h.eventsOf<PlaybackFailed>().single.skipped, isTrue);
        expect(h.currentId, 'next');
      });
    });

    test('preview sources are flagged in the snapshot', () {
      fake((async) {
        final h = Harness(async)..init();
        final t = track('p', source: 'deezer');
        h.resolver.results[t.id] = ResolvedStream(
          source: PlayableSource(uri: Uri.parse('https://cdn.example/preview.mp3'), isPreview: true),
          playedTrack: t,
        );
        h.playAll([t]);
        expect(h.snap.isPreview, isTrue);
      });
    });
  });
}
