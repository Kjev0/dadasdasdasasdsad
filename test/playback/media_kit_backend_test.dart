import 'dart:io';

import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/playback/backend/audio_backend.dart';
import 'package:fermata/playback/backend/media_kit_backend.dart';
import 'package:fermata/playback/playback_controller_impl.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' as mk;

import 'support/real_audio.dart';

void main() {
  group('MediaKitBackend mappings (no audio)', () {
    test('normalization maps to mpv properties', () {
      expect(MediaKitBackend.normalizationProperties(const NormalizationConfig.off()), {'replaygain': 'no', 'af': ''});
      expect(
        MediaKitBackend.normalizationProperties(
            const NormalizationConfig(enabled: true, mode: NormalizationMode.replayGainAlbum, preampDb: -2.5)),
        {'replaygain': 'album', 'replaygain-preamp': '-2.50', 'replaygain-clip': 'yes', 'af': ''},
      );
      expect(
        MediaKitBackend.normalizationProperties(const NormalizationConfig(enabled: true, mode: NormalizationMode.loudness)),
        {'replaygain': 'no', 'af': 'lavfi=[loudnorm=I=-16:TP=-1.5:LRA=11]'},
      );
    });

    test('linear gain maps through mpv\'s cubic volume curve', () {
      expect(MediaKitDeck.mpvVolumeFor(1), closeTo(100, 1e-9));
      expect(MediaKitDeck.mpvVolumeFor(0.125), closeTo(50, 1e-9));
      expect(MediaKitDeck.mpvVolumeFor(0), 0);
      expect(MediaKitDeck.mpvVolumeFor(4), closeTo(100, 1e-9), reason: 'never amplifies');
    });

    test('resources: local paths vs URLs; devices', () {
      expect(MediaKitDeck.resource(PlayableSource(uri: Uri.file('/m/a b.flac'), isLocalFile: true)), '/m/a b.flac');
      expect(MediaKitDeck.resource(PlayableSource(uri: Uri.parse('https://x.example/s.mp3?sig=1'))),
          'https://x.example/s.mp3?sig=1');
      final auto = MediaKitBackend.mapDevice(mk.AudioDevice.auto());
      expect(auto.isDefault, isTrue);
      expect(auto.id, 'auto');
      final usb = MediaKitBackend.mapDevice(const mk.AudioDevice('pulse/usb', 'USB DAC'));
      expect((usb.id, usb.name, usb.isDefault), ('pulse/usb', 'USB DAC', false));
    });

    test('player configuration is audio-only and titled Fermata', () {
      const c = MediaKitBackend.defaultConfiguration;
      expect(c.title, 'Fermata');
      expect(c.vo, 'null');
      expect(c.bufferSize, lessThanOrEqualTo(32 * 1024 * 1024));
      expect(MediaKitBackend.baseMpvOptions['gapless-audio'], 'yes');
      expect(MediaKitBackend.baseMpvOptions['prefetch-playlist'], 'yes');
      expect(MediaKitBackend.baseMpvOptions['cache-on-disk'], 'no');
    });
  });

  final skip = realAudioSkipReason();

  group('MediaKitBackend real audio (libmpv, ao=null)', () {
    late Directory dir;
    late File a;
    late File b;
    late File c;
    late MediaKitBackend backend;

    setUpAll(() async {
      MediaKitBackend.ensureInitialized();
      dir = await Directory.systemTemp.createTemp('fermata_mpv_');
      a = await sineTone(dir, 'a.wav', seconds: 3, frequency: 440);
      b = await sineTone(dir, 'b.flac', seconds: 2, frequency: 660);
      c = await sineTone(dir, 'c.flac', seconds: 2, frequency: 880);
    });
    tearDownAll(() => dir.delete(recursive: true));

    setUp(() => backend = MediaKitBackend(extraMpvOptions: const {'ao': 'null'}));
    tearDown(() => backend.dispose());

    PlayableSource src(File f) => PlayableSource(uri: Uri.file(f.path), isLocalFile: true);

    test('deck: position advances, seek, pause/resume, completion', () async {
      final deck = backend.createDeck();
      var completions = 0;
      deck.completions.listen((_) => completions++);
      final errors = <DeckError>[];
      deck.errors.listen(errors.add);

      await deck.open(src(a));
      await waitFor(() => deck.position > const Duration(milliseconds: 300), reason: 'position advances');
      expect(deck.duration, isNotNull);
      expect(deck.duration!.inMilliseconds, closeTo(3000, 150));
      expect(deck.state, isIn([DeckState.ready, DeckState.buffering]));

      await deck.pause();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final paused = deck.position;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect((deck.position - paused).inMilliseconds.abs(), lessThan(60), reason: 'paused position is stable');
      expect(deck.playing, isFalse);

      await deck.seek(const Duration(milliseconds: 2000));
      await waitFor(() => (deck.position - const Duration(seconds: 2)).inMilliseconds.abs() < 150, reason: 'seek');

      await deck.play();
      await waitFor(() => completions == 1, reason: 'completion');
      expect(deck.state, DeckState.completed);
      expect(errors, isEmpty);
    });

    test('deck: start position and gapless advance to the preloaded item', () async {
      final deck = backend.createDeck();
      var advanced = 0;
      var completions = 0;
      deck.advancedToPreloaded.listen((_) => advanced++);
      deck.completions.listen((_) => completions++);

      await deck.open(src(a), start: const Duration(milliseconds: 2200));
      await waitFor(() => deck.position >= const Duration(milliseconds: 2200), reason: 'starts at offset');
      await deck.preloadNext(src(b));
      expect(deck.hasPreloaded, isTrue);
      await waitFor(() => advanced == 1, reason: 'gapless transition');
      expect(completions, 0, reason: 'a gapless advance is not a completion');
      await waitFor(() => deck.duration != null && deck.duration!.inMilliseconds < 2500, reason: 'b duration');
      await waitFor(() => completions == 1, reason: 'end of b');
    });

    test('deck: missing file reports a fatal error', () async {
      final deck = backend.createDeck();
      final errors = <DeckError>[];
      deck.errors.listen(errors.add);
      await deck.open(PlayableSource(uri: Uri.file('${dir.path}/missing.flac'), isLocalFile: true));
      await waitFor(() => errors.isNotEmpty, reason: 'error');
      expect(errors.first.fatal, isTrue);
    });

    test('normalization and output device reach mpv', () async {
      final deck = backend.createDeck() as MediaKitDeck;
      await backend.setNormalization(
          const NormalizationConfig(enabled: true, mode: NormalizationMode.replayGainTrack, preampDb: -3));
      final native = (await _playerOf(deck)).platform! as mk.NativePlayer;
      expect(await native.getProperty('replaygain'), 'track');
      expect(double.parse(await native.getProperty('replaygain-preamp')), closeTo(-3, 1e-6));
      await backend.setNormalization(const NormalizationConfig(enabled: true, mode: NormalizationMode.loudness));
      expect(await native.getProperty('af'), contains('loudnorm'));
      expect(await native.getProperty('audio-client-name'), 'Fermata');

      final devices = await backend.outputDevices();
      expect(devices.where((d) => d.isDefault), hasLength(1));
      await backend.setOutputDevice(devices.first.id);
      await backend.setOutputDevice(null);
      expect(await native.getProperty('audio-device'), 'auto');
    });

    test('controller end-to-end: play, seek, pause/resume, next track, queue end', () async {
      final stateDir = await Directory.systemTemp.createTemp('fermata_mpv_state_');
      addTearDown(() => stateDir.delete(recursive: true));
      final controller = PlaybackControllerImpl(
        backend: backend,
        resolver: LocalFileResolver(),
        settings: SettingsStore.inMemory(),
        stateFile: File('${stateDir.path}/state.json'),
        platform: const PlatformInfo(os: HostOs.linux),
      );
      final events = <PlaybackEvent>[];
      controller.events.listen(events.add);
      await controller.init();
      await controller.playTracks([fileTrack(a), fileTrack(b), fileTrack(c)]);

      await waitFor(() => controller.snapshot.position > const Duration(milliseconds: 300), reason: 'position');
      expect(controller.snapshot.playing, isTrue);
      expect(events.whereType<TrackStarted>().single.item.track.title, 'a.wav');

      await controller.seek(const Duration(milliseconds: 1500));
      await waitFor(() => controller.snapshot.position >= const Duration(milliseconds: 1500), reason: 'seek');

      await controller.pause();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final paused = controller.snapshot.position;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect((controller.snapshot.position - paused).inMilliseconds.abs(), lessThan(60));
      await controller.play();

      await waitFor(() => events.whereType<TrackStarted>().length == 2, reason: 'next track starts');
      expect(controller.queue.current!.track.title, 'b.flac');
      expect(events.whereType<TrackEnded>().first.completed, isTrue);

      await controller.next();
      await waitFor(() => controller.queue.current!.track.title == 'c.flac' && controller.snapshot.playing,
          reason: 'manual next');
      await waitFor(() => events.whereType<QueueEnded>().isNotEmpty, reason: 'queue end');
      expect(controller.snapshot.playing, isFalse);
      await controller.dispose();
    });

    test('controller restart restores queue and position (real mpv)', () async {
      final stateDir = await Directory.systemTemp.createTemp('fermata_mpv_restart_');
      addTearDown(() => stateDir.delete(recursive: true));
      final settings = SettingsStore.inMemory();
      final state = File('${stateDir.path}/state.json');
      final first = PlaybackControllerImpl(
        backend: backend,
        resolver: LocalFileResolver(),
        settings: settings,
        stateFile: state,
        platform: const PlatformInfo(os: HostOs.linux),
      );
      await first.init();
      await first.playTracks([fileTrack(b), fileTrack(a)], startIndex: 1);
      await first.pause();
      await first.seek(const Duration(milliseconds: 1500));
      expect(first.snapshot.position, const Duration(milliseconds: 1500));
      await first.dispose();

      final backend2 = MediaKitBackend(extraMpvOptions: const {'ao': 'null'});
      final second = PlaybackControllerImpl(
        backend: backend2,
        resolver: LocalFileResolver(),
        settings: settings,
        stateFile: state,
        platform: const PlatformInfo(os: HostOs.linux),
      );
      await second.init();
      expect(second.queue.current!.track.title, 'a.wav');
      expect(second.snapshot.position, const Duration(milliseconds: 1500));
      expect(second.snapshot.playing, isFalse);
      await second.play();
      await waitFor(() => second.snapshot.position > const Duration(milliseconds: 1600), reason: 'resumes at position');
      await second.dispose();
    });
  }, skip: skip);
}

Future<mk.Player> _playerOf(MediaKitDeck deck) async => deck.debugPlayer;
