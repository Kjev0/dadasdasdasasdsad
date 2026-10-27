# UI fake kit

In-memory fakes for every service in `AppServices`, wired into a real
`AppServices` by `FakeKit`. Import `fakes.dart`.

```dart
testWidgets('example', (tester) async {
  final kit = FakeKit(tracks: testTracks(3));          // settings default: onboardingCompleted
  kit.playback.load(kit.tracks.all, playing: true);    // queue + snapshot
  kit.playlists.add(testPlaylist('p1', name: 'Mix'));  // add BEFORE pumping (no change event)
  await pumpFermata(tester, kit: kit, initialRoute: '/queue', size: TestSizes.compact);
  await goTo(tester, '/home');                         // navigate + pump
  expect(kit.playback.called('pause'), isFalse);
});
```

* `pumpFermata(tester, {kit, services, initialRoute = '/home', size, overrides})`
  — full app (router + shell). Pumps ~600 ms of frames (no `pumpAndSettle`,
  so a playing equalizer glyph can't hang tests).
* `pumpInApp(tester, widget, {kit, size, brightness, overrides})` — one
  widget in a themed, localized `MaterialApp` with the kit's overrides.
* `pumpFrames`, `goTo`, `appRouter`, `appContainer`, `setTestWindowSize`,
  `TestSizes.compact/medium/expanded` (360×640, 800×600, 1440×900).
* Fixtures: `testTrack(sid, sourceId:, playback:, offline:, …)`,
  `testTracks(n)`, `testPlaylist`, `testSyncedLyrics`.

Fakes (all record calls; most have `throwOn['method'] = error`):
`FakePlaybackController` (`calls`, `called`, `argsOf`, `emit`, `setQueue`,
`emitEvent`, `load`, `canJoin` for the SoundCloud silo), repositories
(`FakeTrackRepository`, `FakePlaylistRepository.entries`,
`FakeFavoritesRepository.ids`, history, links, search history, local
library, maintenance, `FakeLibraryChangeBus.emit`), `FakeSourceRegistry` +
`FakeMusicSource` (search delay/error, auth state, `externalBase`),
`FakeDownloadManager` (`eligibility`, `downloaded`, `complete`),
`FakeLyricsService`, `FakeRecommendationService`, matching/import fakes,
platform fakes, `FakeMiniWindow`. `kit.openedLinks` records URLs opened via
the link launcher; artwork resolves to placeholders (no network).
