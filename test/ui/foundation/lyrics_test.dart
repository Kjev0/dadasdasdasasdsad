import 'package:fermata/core/contracts/discovery.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/player/lyrics_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<AnimatedDefaultTextStyle>(find.ancestor(of: find.text(text), matching: find.byType(AnimatedDefaultTextStyle))).style;

void main() {
  group('activeLyricIndex', () {
    final lines = [
      const LyricsLine(Duration(seconds: 5), 'a'),
      const LyricsLine(Duration(seconds: 10), 'b'),
      const LyricsLine(Duration(seconds: 20), 'c'),
    ];

    test('before the first line → -1', () => expect(activeLyricIndex(lines, const Duration(seconds: 2)), -1));
    test('exact start time is active', () => expect(activeLyricIndex(lines, const Duration(seconds: 10)), 1));
    test('between lines → previous line', () => expect(activeLyricIndex(lines, const Duration(seconds: 15)), 1));
    test('after the last line → last', () => expect(activeLyricIndex(lines, const Duration(minutes: 5)), 2));
    test('empty → -1', () => expect(activeLyricIndex(const [], Duration.zero), -1));
  });

  group('LyricsView', () {
    Future<FakeKit> pumpLyrics(WidgetTester tester, {Lyrics? lyrics, Object? error, AppSettings? settings}) async {
      final kit = FakeKit(tracks: testTracks(1), settings: settings ?? const AppSettings(onboardingCompleted: true));
      final track = kit.tracks.all.single;
      if (lyrics != null) kit.lyrics.lyrics[track.id] = lyrics;
      kit.lyrics.error = error;
      kit.playback.load([track], position: const Duration(seconds: 12));
      await pumpInApp(tester, SizedBox(height: 600, child: LyricsView(track: track)), kit: kit);
      return kit;
    }

    testWidgets('highlights the current line and follows the position', (tester) async {
      final kit = await pumpLyrics(tester, lyrics: testSyncedLyrics(['One', 'Two', 'Three', 'Four']));
      // 12 s with 10 s steps → line index 1 ("Two").
      expect(_styleOf(tester, 'Two').fontWeight, FontWeight.w700);
      expect(_styleOf(tester, 'Three').fontWeight, FontWeight.w600);

      kit.playback.emit(kit.playback.snapshot.copyWith(position: const Duration(seconds: 31)));
      await pumpFrames(tester);
      expect(_styleOf(tester, 'Four').fontWeight, FontWeight.w700);
      expect(_styleOf(tester, 'Two').fontWeight, FontWeight.w600);
    });

    testWidgets('tapping a line seeks to it', (tester) async {
      final kit = await pumpLyrics(tester, lyrics: testSyncedLyrics(['One', 'Two', 'Three']));
      await tester.tap(find.text('Three'));
      await tester.pump();
      expect(kit.playback.argsOf('seek'), [const Duration(seconds: 20)]);
    });

    testWidgets('auto-scrolls to the active line', (tester) async {
      final lines = [for (var i = 0; i < 60; i++) 'Line $i'];
      final kit = await pumpLyrics(tester, lyrics: testSyncedLyrics(lines, step: const Duration(seconds: 2)));
      kit.playback.emit(kit.playback.snapshot.copyWith(position: const Duration(seconds: 100)));
      await pumpFrames(tester);
      final y = tester.getCenter(find.text('Line 50')).dy;
      expect(y, inInclusiveRange(0, 600));
    });

    testWidgets('plain lyrics fallback with attribution', (tester) async {
      await pumpLyrics(tester, lyrics: const Lyrics(plain: 'Only plain words', provider: 'LRCLIB'));
      expect(find.text('Only plain words'), findsOneWidget);
      expect(find.text('Lyrics: LRCLIB'), findsOneWidget);
    });

    testWidgets('synced lyrics are attributed too', (tester) async {
      await pumpLyrics(tester, lyrics: testSyncedLyrics(['A']));
      expect(find.text('Lyrics: LRCLIB'), findsOneWidget);
    });

    testWidgets('not found, instrumental, error and disabled states', (tester) async {
      await pumpLyrics(tester);
      expect(find.text('No lyrics found for this track.'), findsOneWidget);

      await pumpLyrics(tester, lyrics: const Lyrics(instrumental: true, provider: 'LRCLIB'));
      expect(find.text('Instrumental'), findsOneWidget);

      await pumpLyrics(tester, error: const NetworkException('down'));
      expect(find.text("Couldn't load lyrics."), findsOneWidget);
      expect(find.text("You're offline. Check your connection and try again."), findsOneWidget);

      await pumpLyrics(tester, settings: const AppSettings(playback: PlaybackSettings(lyricsEnabled: false)));
      expect(find.text('Lyrics are turned off in Settings.'), findsOneWidget);
    });

    testWidgets('unused snapshot field sanity', (tester) async {
      expect(const PlaybackSnapshot().position, Duration.zero);
    });
  });
}
