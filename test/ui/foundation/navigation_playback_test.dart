import 'package:fermata/ui/player/now_playing_page.dart';
import 'package:fermata/ui/shell/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

const _routes = [
  '/home',
  '/search',
  '/explore',
  '/library',
  '/library?tab=albums',
  '/playlists',
  '/playlists/p1',
  '/artist/audius/a1',
  '/album/audius/al1',
  '/downloads',
  '/favorites',
  '/history',
  '/queue',
  '/now-playing',
  '/settings',
  '/settings/playback',
  '/import',
  '/import/s1',
  '/onboarding',
  '/home',
];

void main() {
  for (final size in [TestSizes.compact, TestSizes.medium, TestSizes.expanded]) {
    testWidgets('navigating everywhere never touches playback ($size)', (tester) async {
      final kit = FakeKit(tracks: testTracks(3));
      kit.playback.load(kit.tracks.all, playing: true);
      await pumpFermata(tester, kit: kit, size: size);
      final before = kit.playback.calls.length;

      for (final route in _routes) {
        await goTo(tester, route);
        expect(tester.takeException(), isNull, reason: route);
      }
      // Push + pop the full-screen player too.
      appRouter(tester).push('/now-playing');
      await pumpFrames(tester);
      expect(find.byType(NowPlayingPage), findsOneWidget);
      appRouter(tester).pop();
      await pumpFrames(tester);

      final during = kit.playback.calls.skip(before).map((c) => c.method).toList();
      expect(during, isNot(anyOf(contains('stop'), contains('pause'), contains('togglePlayPause'), contains('playTracks'), contains('dispose'))));
      expect(kit.playback.snapshot.playing, isTrue);
    });
  }

  testWidgets('sidebar clicks keep playing', (tester) async {
    final kit = FakeKit(tracks: testTracks(2));
    kit.playback.load(kit.tracks.all, playing: true);
    await pumpFermata(tester, kit: kit);
    for (final label in ['Search', 'Explore', 'Library', 'Playlists', 'Downloads', 'Liked songs', 'History', 'Queue', 'Settings', 'Home']) {
      await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text(label)));
      await pumpFrames(tester);
    }
    expect(kit.playback.methods.where((m) => m == 'stop' || m == 'pause' || m == 'togglePlayPause'), isEmpty);
  });

  testWidgets('bottom navigation keeps playing (compact)', (tester) async {
    final kit = FakeKit(tracks: testTracks(2));
    kit.playback.load(kit.tracks.all, playing: true);
    await pumpFermata(tester, kit: kit, size: TestSizes.compact);
    for (final label in ['Search', 'Explore', 'Library', 'Settings', 'Home']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
      await pumpFrames(tester);
    }
    expect(kit.playback.methods.where((m) => m == 'stop' || m == 'pause' || m == 'togglePlayPause'), isEmpty);
  });
}
