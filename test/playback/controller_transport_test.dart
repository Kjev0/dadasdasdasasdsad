import 'package:fermata/core/models/playback.dart';
import 'package:fermata/playback/backend/audio_backend.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fakes.dart';
import 'fakes/harness.dart';

Duration s(int n) => Duration(seconds: n);

void main() {
  test('init is required before transport calls', () {
    fake((async) {
      final h = Harness(async);
      expect(() => h.controller.play(), throwsStateError);
      h.init();
      expect(h.backend.initialized, isTrue);
      expect(h.snap.status, PlayerStatus.idle);
      expect(h.snap.current, isNull);
    });
  });

  test('local file plays; play/pause/seek/next/previous work', () {
    fake((async) {
      final h = Harness(async, trackLength: const Duration(seconds: 30))..init();
      final list = h.tracks(3);
      h.playAll(list, label: 'My mix');

      final deck = h.backend.decks.single;
      expect(deck.opens.single.uri, uriOf(list[0]));
      expect(deck.opens.single.autoplay, isTrue);
      expect(deck.opens.single.source.isLocalFile, isTrue);
      expect(h.snap.playing, isTrue);
      expect(h.snap.status, PlayerStatus.ready);
      expect(h.snap.current!.track, list[0]);
      expect(h.controller.queue.originLabel, 'My mix');
      expect(h.startedIds(), ['t0']);

      h.elapse(s(2));
      expect(h.snap.position, closeTo2(s(2)));

      // pause
      h.settle(h.controller.pause());
      expect(h.snap.playing, isFalse);
      expect(deck.playing, isFalse);
      final pausedAt = h.snap.position;
      h.elapse(s(5));
      expect(h.snap.position, pausedAt);

      // resume
      h.settle(h.controller.play());
      expect(h.snap.playing, isTrue);
      h.elapse(s(1));
      expect(h.snap.position, closeTo2(s(3)));

      // seek
      h.settle(h.controller.seek(const Duration(seconds: 20)));
      expect(deck.seeks.last, const Duration(seconds: 20));
      expect(h.snap.position, const Duration(seconds: 20));
      h.settle(h.controller.seekRelative(const Duration(seconds: -5)));
      expect(h.snap.position, const Duration(seconds: 15));

      // next
      h.settle(h.controller.next());
      expect(h.currentId, 't1');
      expect(deck.opens.last.uri, uriOf(list[1]));
      expect(h.startedIds(), ['t0', 't1']);
      final ended = h.eventsOf<TrackEnded>().single;
      expect(ended.item.track, list[0]);
      expect(ended.completed, isFalse);

      // previous early in the track goes back
      h.elapse(s(1));
      h.settle(h.controller.previous());
      expect(h.currentId, 't0');
      expect(h.snap.playing, isTrue);

      // previous late in the track restarts it
      h.elapse(s(5));
      final opensBefore = deck.opens.length;
      h.settle(h.controller.previous());
      expect(h.currentId, 't0');
      expect(h.snap.position, Duration.zero);
      expect(deck.opens.length, opensBefore, reason: 'restart is a seek, not a reload');

      // natural completion advances
      h.elapse(s(31));
      expect(h.currentId, 't1');
      final completed = h.eventsOf<TrackEnded>().where((e) => e.completed).toList();
      expect(completed.single.item.track, list[0]);
      h.settle(h.dispose());
    });
  });

  test('togglePlayPause and stop keep the queue and resume at the position', () {
    fake((async) {
      final h = Harness(async, trackLength: const Duration(seconds: 60))..init();
      h.playAll(h.tracks(2));
      h.elapse(s(4));
      h.settle(h.controller.togglePlayPause());
      expect(h.snap.playing, isFalse);
      h.settle(h.controller.togglePlayPause());
      expect(h.snap.playing, isTrue);

      h.settle(h.controller.stop());
      final deck = h.backend.decks.single;
      expect(deck.source, isNull, reason: 'stop releases the deck');
      expect(h.snap.playing, isFalse);
      expect(h.snap.status, PlayerStatus.idle);
      expect(h.controller.queue.items, hasLength(2));
      expect(h.snap.position, closeTo2(s(4)));
      expect(h.eventsOf<TrackEnded>(), hasLength(1));

      h.settle(h.controller.play());
      expect(deck.opens.last.start, closeTo2(s(4)));
      expect(h.snap.playing, isTrue);
      expect(h.eventsOf<TrackStarted>(), hasLength(2));
    });
  });

  test('snapshots: emitted on change and ~4 Hz while playing, not more', () {
    fake((async) {
      final h = Harness(async, trackLength: const Duration(minutes: 5))..init();
      h.playAll(h.tracks(1));
      h.snapshots.clear();
      h.elapse(s(10));
      // 10 s at 4 Hz = 40 periodic emissions (+ a few state changes).
      expect(h.snapshots.length, inInclusiveRange(38, 46));
      final positions = h.snapshots.map((s) => s.position).toList();
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i] >= positions[i - 1], isTrue);
      }
      // Paused: no periodic emissions.
      h.settle(h.controller.pause());
      h.snapshots.clear();
      h.elapse(s(10));
      expect(h.snapshots.length, lessThanOrEqualTo(1));
      // A burst of synchronous changes is coalesced into one emission.
      h.snapshots.clear();
      h.controller.setVolume(0.2);
      h.controller.setVolume(0.3);
      h.controller.setVolume(0.4);
      async.flushMicrotasks();
      expect(h.snapshots, hasLength(1));
      expect(h.snapshots.single.volume, 0.4);
      expect(h.controller.snapshot.volume, 0.4, reason: 'getter is always current');
    });
  });

  test('TrackEnded.listened excludes paused time', () {
    fake((async) {
      final h = Harness(async, trackLength: const Duration(minutes: 5))..init();
      h.playAll(h.tracks(2));
      h.elapse(s(3));
      h.settle(h.controller.pause());
      h.elapse(s(10));
      h.settle(h.controller.play());
      h.elapse(s(2));
      h.settle(h.controller.next());
      final ended = h.eventsOf<TrackEnded>().single;
      expect(ended.listened, closeTo2(s(5)));
      expect(ended.completed, isFalse);
      expect(ended.startedAt, h.eventsOf<TrackStarted>().first.startedAt);
    });
  });

  test('volume uses a cubic curve and is persisted to settings (debounced)', () {
    fake((async) {
      final h = Harness(async, trackLength: const Duration(minutes: 5))..init();
      h.playAll(h.tracks(1));
      final deck = h.backend.decks.single;
      var settingsWrites = 0;
      h.settingsStore.changes.listen((_) => settingsWrites++);
      h.settle(h.controller.setVolume(0.9));
      h.settle(h.controller.setVolume(0.7));
      h.settle(h.controller.setVolume(0.5));
      expect(deck.volume, closeTo(0.125, 1e-9));
      expect(h.snap.volume, 0.5);
      expect(h.settingsStore.current.playback.volume, 1.0, reason: 'not yet written');
      h.elapse(const Duration(milliseconds: 600));
      expect(h.settingsStore.current.playback.volume, 0.5);
      expect(settingsWrites, 1);

      h.settle(h.controller.setSpeed(1.5));
      expect(deck.speed, 1.5);
      expect(h.snap.speed, 1.5);
      h.settle(h.controller.setSpeed(9));
      expect(h.snap.speed, 2.0, reason: 'clamped');
      h.elapse(s(1));
      expect(h.settingsStore.current.playback.speed, 2.0);
    });
  });

  test('external settings changes apply volume, speed and normalization', () {
    fake((async) {
      final h = Harness(async)..init();
      h.playAll(h.tracks(1));
      expect(h.backend.normalizationCalls.last, const NormalizationConfig.off());
      h.settle(h.settingsStore.update((s) => s.copyWith(
            playback: s.playback.copyWith(
              normalizeVolume: true,
              normalizationMode: NormalizationMode.replayGainAlbum,
              preampDb: -3,
              volume: 0.5,
              speed: 1.25,
            ),
          )));
      async.flushMicrotasks();
      expect(
        h.backend.normalization,
        const NormalizationConfig(enabled: true, mode: NormalizationMode.replayGainAlbum, preampDb: -3),
      );
      expect(h.snap.volume, 0.5);
      expect(h.snap.speed, 1.25);
      expect(h.backend.decks.single.speed, 1.25);
    });
  });

  test('settings volume/speed are used at startup', () {
    fake((async) {
      final h = Harness(async, settings: withPlayback((p) => p.copyWith(volume: 0.5, speed: 0.75)))..init();
      expect(h.snap.volume, 0.5);
      h.playAll(h.tracks(1));
      final deck = h.backend.decks.single;
      expect(deck.volumes.first, closeTo(0.125, 1e-9));
      expect(deck.speed, 0.75);
    });
  });

  test('a seek is reported (and persisted) before a lagging deck catches up', () {
    fake((async) {
      final h = Harness(async, trackLength: const Duration(minutes: 5))..init();
      h.playAll(h.tracks(1));
      h.settle(h.controller.pause());
      final deck = h.backend.decks.single..positionLag = const Duration(milliseconds: 300);
      h.settle(h.controller.seek(s(42)));
      expect(deck.position, Duration.zero, reason: 'deck has not caught up yet');
      expect(h.snap.position, s(42));
      h.settle(h.controller.saveState());
      expect(h.memoryStore!.saved!.position, s(42));
      h.elapse(const Duration(milliseconds: 400));
      expect(h.snap.position, s(42));
      // A deck that never reports the target falls back to its own value.
      deck.positionLag = const Duration(hours: 1);
      h.settle(h.controller.seek(s(100)));
      deck.jumpTo(s(7));
      h.elapse(s(4));
      expect(h.snap.position, s(7));
    });
  });

  test('dispose stops, persists and releases the backend', () {
    fake((async) {
      final h = Harness(async, trackLength: const Duration(minutes: 5))..init();
      h.playAll(h.tracks(2));
      h.elapse(s(7));
      h.settle(h.dispose());
      expect(h.backend.disposed, isTrue);
      expect(h.memoryStore!.saved!.position, closeTo2(s(7)));
      expect(h.eventsOf<TrackEnded>().single.completed, isFalse);
      // Calls after dispose are ignored.
      h.settle(h.controller.play());
      h.settle(h.controller.next());
    });
  });
}

Matcher closeTo2(Duration expected, {Duration tolerance = const Duration(milliseconds: 120)}) => predicate<Duration>(
      (d) => (d - expected).abs() <= tolerance,
      'within $tolerance of $expected',
    );
