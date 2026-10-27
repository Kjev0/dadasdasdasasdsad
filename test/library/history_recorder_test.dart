import 'dart:async';

import 'package:fermata/core/contracts/playback.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/library/history_recorder.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

class _MockPlayback extends Mock implements PlaybackController {}

void main() {
  late TestLibrary lib;
  late StreamController<PlaybackEvent> events;
  late SettingsStore settings;
  late PlaybackHistoryRecorder recorder;

  setUp(() async {
    lib = await openTestLibrary();
    events = StreamController<PlaybackEvent>.broadcast();
    final playback = _MockPlayback();
    when(() => playback.events).thenAnswer((_) => events.stream);
    settings = SettingsStore.inMemory();
    recorder = lib.module.createHistoryRecorder(playback, settings)..start();
  });

  tearDown(() async {
    await recorder.dispose();
    await events.close();
    await lib.dispose();
  });

  TrackEnded ended(String id, {int? durationS, required int listenedS, bool completed = false}) => TrackEnded(
        item: QueueItem(uid: 'u$id', track: remoteTrack(id, seconds: durationS), origin: 'playlist:p1'),
        startedAt: DateTime(2024, 6, 1, 10),
        listened: Duration(seconds: listenedS),
        completed: completed,
      );

  Future<List<String>> recorded() async {
    await pumpEventQueue();
    await recorder.flush();
    return (await lib.module.history.history()).map((r) => r.track.id).toList();
  }

  test('records plays of >= 30 s, >= 50 % or completed; upserts the track', () async {
    events.add(ended('long', durationS: 300, listenedS: 31)); // >= 30 s
    events.add(ended('half', durationS: 40, listenedS: 20)); // 50 %
    events.add(ended('done', durationS: 300, listenedS: 5, completed: true)); // completed
    events.add(ended('skip', durationS: 300, listenedS: 29)); // too short
    events.add(ended('nodur', listenedS: 10)); // unknown duration, short
    events.add(const QueueEnded());
    expect((await recorded()).toSet(), {'soundcloud:long', 'soundcloud:half', 'soundcloud:done'});
    final rec = (await lib.module.history.history()).firstWhere((r) => r.track.id == 'soundcloud:half');
    expect(rec.origin, 'playlist:p1');
    expect(rec.listened, const Duration(seconds: 20));
    expect(rec.playedAt, DateTime(2024, 6, 1, 10));
    expect(await lib.module.tracks.getTrack('soundcloud:done'), isNotNull);
    expect(await lib.module.tracks.getTrack('soundcloud:skip'), isNull);
  });

  test('honors privacy.recordHistory', () async {
    await settings.update((s) => s.copyWith(privacy: const PrivacySettings(recordHistory: false)));
    events.add(ended('a', durationS: 100, listenedS: 100, completed: true));
    expect(await recorded(), isEmpty);
    await settings.update((s) => s.copyWith(privacy: const PrivacySettings(recordHistory: true)));
    events.add(ended('b', durationS: 100, listenedS: 100, completed: true));
    expect(await recorded(), ['soundcloud:b']);
  });

  test('stops after dispose', () async {
    await recorder.dispose();
    events.add(ended('late', durationS: 100, listenedS: 100, completed: true));
    expect(await recorded(), isEmpty);
    expect(recorder.isRunning, isFalse);
  });
}
