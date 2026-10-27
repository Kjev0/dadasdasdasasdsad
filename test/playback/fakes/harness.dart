import 'dart:io';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/playback/engine/playback_tuning.dart';
import 'package:fermata/playback/playback_controller_impl.dart';
import 'package:fermata/playback/queue/queue_state_store.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Engine + fakes wired together under [FakeAsync].
class Harness {
  Harness(
    this.async, {
    AppSettings settings = const AppSettings(),
    Duration trackLength = const Duration(seconds: 10),
    bool gapless = true,
    bool loudness = true,
    HostOs os = HostOs.linux,
    this.smartQueue,
    QueueStateStore? store,
    PlaybackTuning tuning = const PlaybackTuning(),
  }) : memoryStore = store == null ? MemoryQueueStateStore() : null {
    now = async.getClock(DateTime(2026, 3, 1, 12)).now;
    backend = FakeAudioBackend(defaultDuration: trackLength, gapless: gapless, loudness: loudness);
    resolver = FakeStreamResolver();
    settingsStore = SettingsStore.inMemory(settings);
    controller = PlaybackControllerImpl(
      backend: backend,
      resolver: resolver,
      settings: settingsStore,
      stateFile: File('/nonexistent/state.json'),
      stateStore: store ?? memoryStore,
      smartQueueProvider: smartQueue == null
          ? null
          : (recent) {
              smartQueueCalls.add(recent);
              return smartQueue!(recent);
            },
      platform: PlatformInfo(os: os),
      tuning: tuning,
      now: now,
      random: math.Random(1),
    );
    controller.events.listen(events.add);
    controller.snapshots.listen(snapshots.add);
    controller.queueStream.listen(queues.add);
  }

  final FakeAsync async;
  late final DateTime Function() now;
  late final FakeAudioBackend backend;
  late final FakeStreamResolver resolver;
  late final SettingsStore settingsStore;
  late final PlaybackControllerImpl controller;
  final MemoryQueueStateStore? memoryStore;
  final Future<List<Track>> Function(List<Track> recent)? smartQueue;
  final smartQueueCalls = <List<Track>>[];

  final events = <PlaybackEvent>[];
  final snapshots = <PlaybackSnapshot>[];
  final queues = <QueueState>[];

  /// Runs [f] to completion inside fake time.
  T settle<T>(Future<T> f) {
    late T value;
    Object? error;
    StackTrace? stack;
    var done = false;
    f.then((v) {
      value = v;
      done = true;
    }, onError: (Object e, StackTrace st) {
      error = e;
      stack = st;
      done = true;
    });
    async.flushMicrotasks();
    if (!done) async.elapse(Duration.zero);
    if (error != null) Error.throwWithStackTrace(error!, stack!);
    expect(done, isTrue, reason: 'future did not complete');
    return value;
  }

  void init() => settle(controller.init());

  void elapse(Duration d) => async.elapse(d);

  PlaybackSnapshot get snap => controller.snapshot;

  String? get currentId => controller.queue.current?.track.sourceTrackId;

  List<T> eventsOf<T extends PlaybackEvent>() => events.whereType<T>().toList();

  List<String> startedIds() => [for (final e in eventsOf<TrackStarted>()) e.item.track.sourceTrackId];

  List<Track> tracks(int n, {String prefix = 't'}) => [for (var i = 0; i < n; i++) track('$prefix$i')];

  void playAll(List<Track> list, {int start = 0, bool shuffle = false, String? label}) =>
      settle(controller.playTracks(list, startIndex: start, shuffle: shuffle, originLabel: label, origin: 'test'));

  Future<void> dispose() => controller.dispose();
}

/// Shorthand for playback settings overrides.
AppSettings withPlayback(PlaybackSettings Function(PlaybackSettings p) f, {bool? preloadNext}) {
  const base = AppSettings();
  return base.copyWith(
    playback: f(base.playback),
    performance: preloadNext == null ? null : base.performance.copyWith(preloadNext: preloadNext),
  );
}

void fake(void Function(FakeAsync async) body) => fakeAsync(body);
