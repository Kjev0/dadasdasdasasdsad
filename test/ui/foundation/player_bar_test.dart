import 'package:fermata/core/models/playback.dart';
import 'package:fermata/ui/player/mini_mode.dart';
import 'package:fermata/ui/player/now_playing_page.dart';
import 'package:fermata/ui/player/player_bar.dart';
import 'package:fermata/ui/player/queue_page.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

Finder _bar(Finder f) => find.descendant(of: find.byType(PlayerBar), matching: f);

Future<FakeKit> _pumpPlaying(WidgetTester tester, {Size size = TestSizes.expanded, bool playing = true}) async {
  final kit = FakeKit(tracks: testTracks(3));
  kit.playback.load(kit.tracks.all, index: 1, playing: playing, position: const Duration(seconds: 30));
  await pumpFermata(tester, kit: kit, size: size);
  return kit;
}

void main() {
  group('player bar', () {
    testWidgets('shows the current track and calls the controller for transport', (tester) async {
      final kit = await _pumpPlaying(tester);
      final p = kit.playback;
      expect(_bar(find.text('Song 2')), findsOneWidget);
      expect(_bar(find.text('Artist 2')), findsOneWidget);

      await tester.tap(_bar(find.byTooltip('Pause')));
      await tester.pump();
      expect(p.called('togglePlayPause'), isTrue);
      expect(_bar(find.byTooltip('Play')), findsOneWidget);

      await tester.tap(_bar(find.byTooltip('Next')));
      await tester.pump();
      expect(p.called('next'), isTrue);
      expect(_bar(find.text('Song 3')), findsOneWidget);

      await tester.tap(_bar(find.byTooltip('Previous')));
      await tester.pump();
      expect(p.called('previous'), isTrue);

      await tester.tap(_bar(find.byTooltip('Shuffle is off')));
      await tester.pump();
      expect(p.argsOf('setShuffle'), [true]);
      expect(_bar(find.byTooltip('Shuffle is on')), findsOneWidget);
    });

    testWidgets('repeat cycles off → all → one with matching states', (tester) async {
      final kit = await _pumpPlaying(tester);
      await tester.tap(_bar(find.byTooltip('Repeat is off')));
      await tester.pump();
      expect(kit.playback.snapshot.repeat, RepeatMode.all);
      expect(_bar(find.byIcon(Icons.repeat_on_rounded)), findsOneWidget);
      await tester.tap(_bar(find.byTooltip('Repeating all')));
      await tester.pump();
      expect(kit.playback.snapshot.repeat, RepeatMode.one);
      expect(_bar(find.byIcon(Icons.repeat_one_on_rounded)), findsOneWidget);
      expect(kit.playback.countOf('cycleRepeat'), 2);
    });

    testWidgets('like toggles the favorite', (tester) async {
      final kit = await _pumpPlaying(tester);
      await tester.tap(_bar(find.byTooltip('Like')));
      await pumpFrames(tester);
      expect(kit.favorites.ids, contains(kit.tracks.all[1].id));
      expect(_bar(find.byTooltip('Remove from Liked songs')), findsOneWidget);
    });

    testWidgets('mute and volume slider', (tester) async {
      final kit = await _pumpPlaying(tester);
      await tester.tap(_bar(find.byTooltip('Mute')));
      await tester.pump();
      expect(kit.playback.argsOf('setVolume'), [0.0]);
      await tester.tap(_bar(find.byTooltip('Unmute')));
      await tester.pump();
      expect(kit.playback.snapshot.volume, greaterThan(0));

      final slider = _bar(find.byType(Slider));
      await tester.tapAt(tester.getTopLeft(slider) + Offset(tester.getSize(slider).width * 0.25, tester.getSize(slider).height / 2));
      await tester.pump();
      expect(kit.playback.snapshot.volume, lessThan(0.6));
    });

    testWidgets('speed, sleep timer and output device menus', (tester) async {
      final kit = await _pumpPlaying(tester);

      await tester.tap(_bar(find.byIcon(Icons.speed_rounded)));
      await pumpFrames(tester);
      await tester.tap(find.text('1.5×').last);
      await pumpFrames(tester);
      expect(kit.playback.argsOf('setSpeed'), [1.5]);

      await tester.tap(_bar(find.byTooltip('Sleep timer')));
      await pumpFrames(tester);
      await tester.tap(find.text('15 minutes').last);
      await pumpFrames(tester);
      expect(kit.playback.argsOf('setSleepTimer'), [const Duration(minutes: 15), false]);
      // Active timer: highlighted icon and remaining time in the tooltip.
      expect(_bar(find.byTooltip(RegExp(r'^Pauses in '))), findsOneWidget);

      await tester.tap(_bar(find.byIcon(Icons.bedtime_rounded)));
      await pumpFrames(tester);
      await tester.tap(find.text('End of track').last);
      await pumpFrames(tester);
      expect(kit.playback.argsOf('setSleepTimer'), [null, true]);

      await tester.tap(_bar(find.byTooltip('Output device')));
      await pumpFrames(tester);
      await tester.tap(find.text('USB DAC').last);
      await pumpFrames(tester);
      expect(kit.playback.argsOf('setOutputDevice'), ['usb']);
    });

    testWidgets('speed / output device hidden when unsupported', (tester) async {
      final kit = FakeKit(tracks: testTracks(1));
      kit.playback
        ..supportsSpeed = false
        ..supportsOutputDeviceSelection = false
        ..load(kit.tracks.all);
      await pumpFermata(tester, kit: kit);
      expect(_bar(find.byIcon(Icons.speed_rounded)), findsNothing);
      expect(_bar(find.byTooltip('Output device')), findsNothing);
    });

    testWidgets('artwork opens now playing; queue button opens the queue', (tester) async {
      await _pumpPlaying(tester);
      await tester.tap(_bar(find.byTooltip('Queue')));
      await pumpFrames(tester);
      expect(find.byType(QueuePage), findsOneWidget);

      await tester.tap(_bar(find.bySemanticsLabel('Open now playing')));
      await pumpFrames(tester);
      expect(find.byType(NowPlayingPage), findsOneWidget);
    });

    testWidgets('lyrics button opens now playing on the lyrics panel', (tester) async {
      await _pumpPlaying(tester);
      await tester.tap(_bar(find.byTooltip('Lyrics')));
      await pumpFrames(tester);
      expect(tester.widget<NowPlayingPage>(find.byType(NowPlayingPage)).initialPanel, NowPlayingPanel.lyrics);
    });

    testWidgets('mini player: enter resizes the window, view shows, exit restores', (tester) async {
      final kit = await _pumpPlaying(tester);
      await tester.tap(_bar(find.byTooltip('Mini player')));
      await pumpFrames(tester);
      expect(kit.miniWindow.changes.last, (true, true));
      expect(find.byType(MiniModeView), findsOneWidget);

      // Shrink like the real window would and check the compact view fits.
      setTestWindowSize(tester, miniWindowSize);
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Keep on top'));
      await pumpFrames(tester);
      expect(kit.miniWindow.changes.last, (true, false));

      await tester.tap(find.byTooltip('Back to full window'));
      // The real window controller restores the previous bounds.
      setTestWindowSize(tester, TestSizes.expanded);
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
      expect(kit.miniWindow.changes.last.$1, isFalse);
      expect(find.byType(MiniModeView), findsNothing);
    });

    testWidgets('medium layout uses a compact cluster with an overflow menu', (tester) async {
      final kit = await _pumpPlaying(tester, size: TestSizes.medium);
      expect(tester.takeException(), isNull);
      await tester.tap(_bar(find.byTooltip('More')));
      await pumpFrames(tester);
      await tester.tap(find.text('Playback speed').last);
      await pumpFrames(tester);
      await tester.tap(find.text('0.75×').last);
      await pumpFrames(tester);
      expect(kit.playback.argsOf('setSpeed'), [0.75]);
    });

    testWidgets('idle: shows "Nothing playing" and disables transport', (tester) async {
      final kit = FakeKit();
      await pumpFermata(tester, kit: kit);
      expect(_bar(find.text('Nothing playing')), findsOneWidget);
      await tester.tap(_bar(find.byTooltip('Next')), warnIfMissed: false);
      await tester.pump();
      expect(kit.playback.called('next'), isFalse);
    });
  });
}
