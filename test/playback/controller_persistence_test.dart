import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/playback/playback_controller_impl.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fakes.dart';
import 'fakes/harness.dart';

const linux = PlatformInfo(os: HostOs.linux);

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fermata_playback_');
    file = File('${dir.path}/playback/state.json');
  });
  tearDown(() => dir.delete(recursive: true));

  PlaybackControllerImpl controller(FakeAudioBackend backend, SettingsStore settings) => PlaybackControllerImpl(
        backend: backend,
        resolver: FakeStreamResolver(),
        settings: settings,
        stateFile: file,
        platform: linux,
      );

  Future<QueueState> playSomethingAndQuit(SettingsStore settings) async {
    final c = controller(FakeAudioBackend(defaultDuration: const Duration(minutes: 3)), settings);
    await c.init();
    await c.playTracks([for (var i = 0; i < 5; i++) track('t$i')],
        startIndex: 2, origin: 'playlist:road', originLabel: 'Road trip');
    await c.setShuffle(true);
    await c.setRepeat(RepeatMode.all);
    await c.pause();
    await c.seek(const Duration(seconds: 42));
    final queue = c.queue;
    await c.dispose();
    return queue;
  }

  test('state persists and restores across a simulated restart', () async {
    final settings = SettingsStore.inMemory();
    final before = await playSomethingAndQuit(settings);

    expect(file.existsSync(), isTrue);
    expect(File('${file.path}.tmp').existsSync(), isFalse, reason: 'atomic write leaves no temp file');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    expect(json['positionMs'], 42000);

    final backend = FakeAudioBackend(defaultDuration: const Duration(minutes: 3));
    final c = controller(backend, settings);
    await c.init();
    expect([for (final i in c.queue.items) i.uid], [for (final i in before.items) i.uid]);
    expect(c.queue.currentIndex, before.currentIndex);
    expect(c.queue.current!.track.sourceTrackId, 't2');
    expect(c.queue.originLabel, 'Road trip');
    expect(c.queue.current!.origin, 'playlist:road');
    final snap = c.snapshot;
    expect(snap.shuffle, isTrue);
    expect(snap.repeat, RepeatMode.all);
    expect(snap.position, const Duration(seconds: 42));
    expect(snap.playing, isFalse, reason: 'restored paused');
    expect(backend.decks, isEmpty, reason: 'nothing is loaded until play');

    await c.setShuffle(false);
    expect([for (final i in c.queue.items) i.track.sourceTrackId], ['t0', 't1', 't2', 't3', 't4']);
    expect(c.queue.current!.track.sourceTrackId, 't2');

    await c.play();
    expect(backend.decks.single.opens.single.start, const Duration(seconds: 42));
    expect(c.snapshot.playing, isTrue);
    await c.dispose();
  });

  test('autoPlayOnStartup starts playing at the saved position', () async {
    final settings = SettingsStore.inMemory();
    await playSomethingAndQuit(settings);
    await settings.update((s) => s.copyWith(playback: s.playback.copyWith(autoPlayOnStartup: true)));

    final backend = FakeAudioBackend(defaultDuration: const Duration(minutes: 3));
    final c = controller(backend, settings);
    final started = c.events.firstWhere((e) => e is TrackStarted);
    await c.init();
    await started.timeout(const Duration(seconds: 5));
    expect(c.snapshot.playing, isTrue);
    expect(backend.decks.single.opens.single.start, const Duration(seconds: 42));
    await c.dispose();
  });

  test('restoreQueueOnStartup off starts with an empty queue', () async {
    final settings = SettingsStore.inMemory();
    await playSomethingAndQuit(settings);
    await settings.update((s) => s.copyWith(playback: s.playback.copyWith(restoreQueueOnStartup: false)));
    final c = controller(FakeAudioBackend(), settings);
    await c.init();
    expect(c.queue.isEmpty, isTrue);
    expect(c.snapshot.current, isNull);
    await c.dispose();
  });

  test('a corrupt state file is ignored', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('{not json');
    final c = controller(FakeAudioBackend(), SettingsStore.inMemory());
    await c.init();
    expect(c.queue.isEmpty, isTrue);
    await c.saveState();
    expect(jsonDecode(await file.readAsString()), isA<Map<String, Object?>>(), reason: 'rewritten valid');
    await c.dispose();
  });

  test('saveState writes immediately', () async {
    final c = controller(FakeAudioBackend(), SettingsStore.inMemory());
    await c.init();
    await c.enqueue([track('a'), track('b')]);
    await c.saveState();
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    final items = (json['queue'] as Map)['items'] as List;
    expect(items, hasLength(2));
    await c.dispose();
  });

  test('queue edits are persisted debounced (~2 s), pause and track change immediately', () {
    fake((async) {
      final h = Harness(async, trackLength: const Duration(minutes: 3))..init();
      final store = h.memoryStore!;
      h.playAll(h.tracks(3));
      final afterStart = store.writes;
      expect(afterStart, greaterThan(0), reason: 'track change persists');

      h.settle(h.controller.enqueue([track('x')]));
      h.settle(h.controller.moveQueueItem(3, 1));
      h.elapse(const Duration(milliseconds: 1900));
      expect(store.writes, afterStart);
      h.elapse(const Duration(milliseconds: 200));
      expect(store.writes, afterStart + 1);
      expect((store.saved!.queue['items'] as List), hasLength(4));

      final beforePause = store.writes;
      h.settle(h.controller.pause());
      expect(store.writes, beforePause + 1);

      // While playing, the position is saved periodically (not every tick).
      h.settle(h.controller.play());
      final beforePlaying = store.writes;
      h.elapse(const Duration(seconds: 30));
      expect(store.writes - beforePlaying, inInclusiveRange(2, 4));
      expect(store.saved!.position, greaterThan(const Duration(seconds: 15)));
    });
  });

  test('settings with defaults restore the queue (sanity of defaults)', () {
    expect(const AppSettings().playback.restoreQueueOnStartup, isTrue);
    expect(const AppSettings().playback.autoPlayOnStartup, isFalse);
  });

  test('unawaited background work does not leak after dispose', () async {
    final c = controller(FakeAudioBackend(), SettingsStore.inMemory());
    await c.init();
    await c.playTracks([track('a')]);
    await c.dispose();
    // Must be a no-op rather than throwing on closed controllers.
    await c.play();
    await c.saveState();
    unawaited(c.next());
  });
}
