// Real-audio integration test for the playback engine on the Linux desktop
// embedder (libmpv through media_kit, `ao=null` so no sound card is needed).
//
// Run (headless):
//   source /opt/sdk/env.sh
//   xvfb-run -a flutter test integration_test/playback_test.dart -d linux
//
// The same engine paths also run without the embedder in
// `flutter test test/playback/media_kit_backend_test.dart`.
import 'dart:io';

import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/playback/backend/media_kit_backend.dart';
import 'package:fermata/playback/playback_controller_impl.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/playback/support/real_audio.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final skip = realAudioSkipReason();

  late Directory dir;
  late File a;
  late File b;
  late File c;

  setUpAll(() async {
    if (skip != null) return;
    MediaKitBackend.ensureInitialized();
    dir = await Directory.systemTemp.createTemp('fermata_it_');
    a = await sineTone(dir, 'a.flac', seconds: 4, frequency: 440);
    b = await sineTone(dir, 'b.wav', seconds: 3, frequency: 550);
    c = await sineTone(dir, 'c.flac', seconds: 3, frequency: 660);
  });

  tearDownAll(() async {
    if (skip == null) await dir.delete(recursive: true);
  });

  PlaybackControllerImpl engine(SettingsStore settings, File state, MediaKitBackend backend) => PlaybackControllerImpl(
        backend: backend,
        resolver: LocalFileResolver(),
        settings: settings,
        stateFile: state,
        platform: const PlatformInfo(os: HostOs.linux),
      );

  testWidgets('plays a queue gaplessly: position, seek, pause/resume, next, completion', (tester) async {
    final backend = MediaKitBackend(extraMpvOptions: const {'ao': 'null'});
    final controller = engine(SettingsStore.inMemory(), File('${dir.path}/s1.json'), backend);
    final events = <PlaybackEvent>[];
    controller.events.listen(events.add);
    await controller.init();
    await controller.playTracks([fileTrack(a), fileTrack(b), fileTrack(c)]);

    await waitFor(() => controller.snapshot.position > const Duration(milliseconds: 400), reason: 'position advances');
    await controller.seek(const Duration(milliseconds: 2500));
    await waitFor(() => controller.snapshot.position >= const Duration(milliseconds: 2500), reason: 'seek');
    await controller.pause();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final paused = controller.snapshot.position;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect((controller.snapshot.position - paused).inMilliseconds.abs(), lessThan(80));
    await controller.play();

    await waitFor(() => events.whereType<TrackStarted>().length == 2, reason: 'b starts', timeout: const Duration(seconds: 8));
    expect(controller.queue.current!.track.title, 'b.wav');
    expect(events.whereType<TrackEnded>().first.completed, isTrue);
    await waitFor(() => events.whereType<QueueEnded>().isNotEmpty, reason: 'queue end', timeout: const Duration(seconds: 12));
    expect(events.whereType<TrackStarted>().map((e) => e.item.track.title), ['a.flac', 'b.wav', 'c.flac']);
    expect(controller.snapshot.playing, isFalse);
    await controller.dispose();
  }, skip: skip != null);

  testWidgets('crossfades across two real decks', (tester) async {
    final settings = SettingsStore.inMemory(
        const AppSettings().copyWith(playback: const PlaybackSettings(crossfadeSeconds: 1.5)));
    final backend = MediaKitBackend(extraMpvOptions: const {'ao': 'null'});
    final controller = engine(settings, File('${dir.path}/s2.json'), backend);
    final events = <PlaybackEvent>[];
    controller.events.listen(events.add);
    await controller.init();
    await controller.playTracks([fileTrack(a), fileTrack(b)]);
    await waitFor(() => events.whereType<TrackStarted>().length == 2, reason: 'crossfade start', timeout: const Duration(seconds: 8));
    // The incoming track starts before the outgoing one reached its end.
    final firstEnd = events.whereType<TrackEnded>().first;
    expect(firstEnd.completed, isTrue);
    expect(firstEnd.listened, lessThan(const Duration(milliseconds: 3900)));
    await waitFor(() => events.whereType<QueueEnded>().isNotEmpty, reason: 'queue end', timeout: const Duration(seconds: 10));
    await controller.dispose();
  }, skip: skip != null);

  testWidgets('restores the queue and position after a restart', (tester) async {
    final state = File('${dir.path}/s3.json');
    final settings = SettingsStore.inMemory();
    final first = engine(settings, state, MediaKitBackend(extraMpvOptions: const {'ao': 'null'}));
    await first.init();
    await first.playTracks([fileTrack(b), fileTrack(a)], startIndex: 1);
    await first.pause();
    await first.seek(const Duration(seconds: 2));
    await first.dispose();

    final second = engine(settings, state, MediaKitBackend(extraMpvOptions: const {'ao': 'null'}));
    await second.init();
    expect(second.queue.current!.track.title, 'a.flac');
    expect(second.snapshot.position, const Duration(seconds: 2));
    expect(second.snapshot.playing, isFalse);
    await second.play();
    await waitFor(() => second.snapshot.position > const Duration(milliseconds: 2100), reason: 'resumes at position');
    await second.dispose();
  }, skip: skip != null);
}
