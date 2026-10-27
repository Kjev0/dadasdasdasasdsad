import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/pages/import/import_review_page.dart';
import 'package:fermata/ui/pages/playlists/playlist_detail_page.dart';
import 'package:fermata/ui/pages/search/search_results.dart';
import 'package:fermata/ui/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'support/page_harness.dart';

FakeMusicSource _sc({Duration delay = Duration.zero, List<Track>? tracks}) => FakeMusicSource(
      id: SourceIds.soundcloud,
      displayName: 'SoundCloud',
      searchDelay: delay,
      tracks: tracks ??
          [
            testTrack('s1', sourceId: SourceIds.soundcloud, title: 'Song from SC one'),
            testTrack('s2', sourceId: SourceIds.soundcloud, title: 'Song from SC two'),
          ],
    );

FakeMusicSource _au({Duration delay = Duration.zero, List<Track>? tracks, Object? error}) => FakeMusicSource(
      id: SourceIds.audius,
      displayName: 'Audius',
      searchDelay: delay,
      searchError: error,
      tracks: tracks ?? [testTrack('a1', title: 'Song from Audius one'), testTrack('a2', title: 'Song from Audius two')],
      artists: const [Artist(sourceId: SourceIds.audius, sourceArtistId: 'ar1', name: 'Song Artist')],
    );

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pump();
}

void main() {
  testWidgets('debounces typing (300 ms) and searches once', (tester) async {
    final au = _au();
    final kit = FakeKit(sources: [au]);
    await pumpPage(tester, kit: kit, route: '/search');
    await _type(tester, 's');
    await tester.pump(const Duration(milliseconds: 100));
    await _type(tester, 'so');
    await tester.pump(const Duration(milliseconds: 100));
    await _type(tester, 'song');
    await tester.pump(const Duration(milliseconds: 250));
    expect(au.calls.where((c) => c == 'searchTracks'), isEmpty);
    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester);
    expect(au.calls.where((c) => c == 'searchTracks').length, 1);
    expect(find.text('Song from Audius two'), findsOneWidget);
  });

  testWidgets('results stream in per source and are ordered SoundCloud first', (tester) async {
    final kit = FakeKit(sources: [_au(), _sc(delay: const Duration(milliseconds: 400))]);
    await pumpPage(tester, kit: kit, route: '/search');
    await _type(tester, 'song');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 50));
    // Audius arrived first and is shown while SoundCloud is still searching.
    expect(find.text('Song from Audius two'), findsOneWidget);
    expect(find.text('Song from SC two'), findsNothing);
    // The fake searches tracks, artists, albums and playlists one after the
    // other (400 ms each).
    await tester.pump(const Duration(milliseconds: 1700));
    await settle(tester);
    // SoundCloud moves to the front: it is the top result and leads the tracks.
    expect(find.descendant(of: find.byKey(const ValueKey('top-result')), matching: find.text('Song from SC one')), findsOneWidget);
    final sc = tester.getTopLeft(find.byKey(const ValueKey('result-soundcloud:s2'))).dy;
    final au = tester.getTopLeft(find.byKey(const ValueKey('result-audius:a1'))).dy;
    expect(sc, lessThan(au));
  });

  testWidgets('provider order from settings decides the merge order', (tester) async {
    final kit = FakeKit(
      sources: [_au(), _sc()],
      settings: const AppSettings(
        onboardingCompleted: true,
        services: ServicesSettings(providerOrder: [SourceIds.audius, SourceIds.soundcloud, SourceIds.local]),
      ),
    );
    await pumpPage(tester, kit: kit, route: '/search');
    await _type(tester, 'song from');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(find.descendant(of: find.byKey(const ValueKey('top-result')), matching: find.text('Song from Audius one')), findsOneWidget);
    final au = tester.getTopLeft(find.byKey(const ValueKey('result-audius:a2'))).dy;
    final sc = tester.getTopLeft(find.byKey(const ValueKey('result-soundcloud:s1'))).dy;
    expect(au, lessThan(sc));
  });

  testWidgets('a newer query cancels the previous search; stale results never show', (tester) async {
    final au = _au(
      delay: const Duration(milliseconds: 500),
      tracks: [testTrack('x1', title: 'alpha one'), testTrack('x2', title: 'beta two')],
    );
    final kit = FakeKit(sources: [au]);
    await pumpPage(tester, kit: kit, route: '/search');
    await _type(tester, 'alpha');
    await tester.pump(const Duration(milliseconds: 350)); // first search running
    await _type(tester, 'beta');
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('alpha one'), findsNothing);
    }
    await settle(tester);
    expect(au.calls.where((c) => c == 'searchTracks').length, 2);
    expect(find.text('beta two'), findsOneWidget);
    expect(find.text('alpha one'), findsNothing);
  });

  testWidgets('a SoundCloud result plays in its own queue', (tester) async {
    final kit = FakeKit(sources: [_au(), _sc()]);
    await pumpPage(tester, kit: kit, route: '/search');
    await _type(tester, 'song from');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    await tester.tap(find.text('Song from SC two'));
    await settle(tester);
    final queued = kit.playback.argsOf('playTracks')[0] as List<Track>;
    expect(queued.map((t) => t.sourceId).toSet(), {SourceIds.soundcloud});
    await tester.tap(find.text('Song from Audius two'));
    await settle(tester);
    final open = kit.playback.argsOf('playTracks')[0] as List<Track>;
    expect(open.map((t) => t.sourceId).toSet(), {SourceIds.audius});
  });

  testWidgets('source chips filter results', (tester) async {
    final kit = FakeKit(sources: [_au(), _sc()]);
    await pumpPage(tester, kit: kit, route: '/search');
    await _type(tester, 'song from');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Audius'));
    await settle(tester);
    expect(find.text('Song from SC two'), findsNothing);
    expect(find.text('Song from Audius two'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await settle(tester);
    expect(find.text('Song from SC two'), findsOneWidget);
  });

  testWidgets('no results → empty state', (tester) async {
    final kit = FakeKit(sources: [_au()]);
    await pumpPage(tester, kit: kit, route: '/search');
    await _type(tester, 'nothing like this');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester);
    expect(find.text('No results for "nothing like this"'), findsOneWidget);
  });

  group('per-source notices', () {
    testWidgets('credentials missing / not connected sources link to Connected services', (tester) async {
      final sc = FakeMusicSource(
        id: SourceIds.soundcloud,
        displayName: 'SoundCloud',
        ready: false,
        credentialStatus: const CredentialStatus(configured: false, origin: CredentialOrigin.none, missing: ['client_id']),
      );
      final yt = FakeMusicSource(
        id: SourceIds.youtube,
        displayName: 'YouTube Music',
        ready: false,
        authState: const SourceAuthState(status: SourceConnectionStatus.notConnected),
      );
      final kit = FakeKit(sources: [_au(), sc, yt]);
      await pumpPage(tester, kit: kit, route: '/search');
      await _type(tester, 'song');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester);
      expect(find.text('Not searched: SoundCloud (needs setup), YouTube Music (not connected)'), findsOneWidget);
      // A chip for a source that couldn't search explains why.
      await tester.tap(find.widgetWithText(ChoiceChip, 'SoundCloud'));
      await settle(tester);
      expect(find.text('SoundCloud needs developer credentials before it can be used.'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Connected services'));
      await settle(tester);
      expect(tester.widget<SettingsPage>(find.byType(SettingsPage)).section, 'services');
    });

    testWidgets('a failing source shows an inline error; others still show', (tester) async {
      final kit = FakeKit(sources: [_au(error: const AuthRequiredException(SourceIds.audius, 'expired')), _sc()]);
      await pumpPage(tester, kit: kit, route: '/search');
      await _type(tester, 'song');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester);
      expect(find.text('Reconnect your Audius account to continue.'), findsOneWidget);
      expect(find.text('Song from SC two'), findsOneWidget);
    });

    testWidgets('network errors offer retry', (tester) async {
      final au = _au(error: const NetworkException('down'));
      final kit = FakeKit(sources: [au]);
      await pumpPage(tester, kit: kit, route: '/search');
      await _type(tester, 'song');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester);
      expect(find.text("You're offline. Check your connection and try again."), findsOneWidget);
      au.searchError = null;
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await settle(tester);
      expect(find.text('Song from Audius two'), findsOneWidget);
    });
  });

  group('recent searches', () {
    testWidgets('listed, re-run, removed and cleared', (tester) async {
      final au = _au();
      final kit = FakeKit(sources: [au]);
      kit.searchHistory.queries.addAll(['song from', 'older']);
      await pumpPage(tester, kit: kit, route: '/search');
      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.byKey(const ValueKey('recent-older')), findsOneWidget);
      await tester.tap(find.byTooltip('Remove "older"'));
      await settle(tester);
      expect(kit.searchHistory.queries, ['song from']);
      await tester.tap(find.text('song from'));
      await settle(tester);
      expect(find.text('Song from Audius two'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '');
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await settle(tester);
      expect(kit.searchHistory.queries, isEmpty);
      expect(find.text('Recent searches'), findsNothing);
    });

    testWidgets('submitting saves the search', (tester) async {
      final kit = FakeKit(sources: [_au()]);
      await pumpPage(tester, kit: kit, route: '/search');
      await _type(tester, 'song');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(kit.searchHistory.queries, ['song']);
    });

    testWidgets('with search history off nothing is saved and a notice explains it', (tester) async {
      final kit = FakeKit(
        sources: [_au()],
        settings: const AppSettings(onboardingCompleted: true, privacy: PrivacySettings(saveSearchHistory: false)),
      );
      kit.searchHistory.queries.add('secret');
      await pumpPage(tester, kit: kit, route: '/search');
      expect(find.text('Search history is turned off, so searches are not saved.'), findsOneWidget);
      expect(find.text('secret'), findsNothing);
      await _type(tester, 'song');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(kit.searchHistory.queries, ['secret']);
      expect(kit.searchHistory.called('add'), isFalse);
    });

    testWidgets('suggestions while typing: recent matches and library tracks', (tester) async {
      final kit = FakeKit(sources: [_au()], tracks: [testTrack('l9', sourceId: SourceIds.local, title: 'Song in my library')]);
      kit.searchHistory.queries.add('song from audius');
      await pumpPage(tester, kit: kit, route: '/search');
      await _type(tester, 'song');
      await settle(tester, count: 2);
      expect(find.byKey(const ValueKey('suggest-recent-song from audius')), findsOneWidget);
      expect(find.text('In your library'), findsOneWidget);
      expect(find.text('Song in my library'), findsOneWidget);
    });
  });

  group('share links', () {
    FakeMusicSource spotify() => FakeMusicSource(
          id: SourceIds.spotify,
          displayName: 'Spotify',
          capabilities: const {SourceCapability.searchTracks, SourceCapability.playlistImport, SourceCapability.externalPlayback},
          playlists: const [
            Playlist(id: 'spotify:37i9', name: 'Hits on Spotify', kind: PlaylistKind.remote, sourceId: SourceIds.spotify, sourcePlaylistId: '37i9'),
          ],
          tracks: [testTrack('sp1', sourceId: SourceIds.spotify, playback: PlaybackRights.externalOnly, title: 'Spotify song')],
        );

    testWidgets('a playlist link offers open and import & match', (tester) async {
      final sp = spotify();
      final kit = FakeKit(sources: [sp]);
      await pumpPage(tester, kit: kit, route: '/search');
      await _type(tester, 'https://open.spotify.com/playlist/37i9?si=abc');
      await settle(tester);
      expect(find.text('Spotify playlist link'), findsOneWidget);
      expect(sp.calls.where((c) => c.startsWith('search')), isEmpty);
      await tester.tap(find.text('Import & match'));
      await settle(tester);
      expect(kit.imports.calls, contains('start'));
      expect(tester.widget<ImportReviewPage>(find.byType(ImportReviewPage)).sessionId, 's1');
    });

    testWidgets('open playlist shows the remote playlist', (tester) async {
      final kit = FakeKit(sources: [spotify()]);
      await pumpPage(tester, kit: kit, route: '/search');
      await _type(tester, 'https://open.spotify.com/playlist/37i9');
      await settle(tester);
      await tester.tap(find.text('Open playlist'));
      await settle(tester);
      expect(tester.widget<PlaylistDetailPage>(find.byType(PlaylistDetailPage)).playlistId, 'spotify:37i9');
      expect(find.text('Hits on Spotify'), findsOneWidget);
    });

    testWidgets('a track link resolves the track', (tester) async {
      final deezer = FakeMusicSource(
        id: SourceIds.deezer,
        displayName: 'Deezer',
        tracks: [testTrack('3135556', sourceId: SourceIds.deezer, title: 'Harder Better', playback: PlaybackRights.preview)],
      );
      final kit = FakeKit(sources: [deezer]);
      await pumpPage(tester, kit: kit, route: '/search');
      await _type(tester, 'https://www.deezer.com/en/track/3135556');
      await settle(tester);
      expect(find.text('Deezer track link'), findsOneWidget);
      expect(find.text('Harder Better'), findsOneWidget);
    });

    testWidgets('a link to a service that is not set up explains it', (tester) async {
      final sc = FakeMusicSource(
        id: SourceIds.soundcloud,
        displayName: 'SoundCloud',
        ready: false,
        credentialStatus: const CredentialStatus(configured: false, origin: CredentialOrigin.none),
      );
      final kit = FakeKit(sources: [sc]);
      await pumpPage(tester, kit: kit, route: '/search');
      await _type(tester, 'https://soundcloud.com/someone/sets/mix');
      await settle(tester);
      expect(find.text('SoundCloud needs developer credentials before it can be used.'), findsOneWidget);
      await tester.tap(find.text('Open on SoundCloud'));
      await settle(tester);
      expect(kit.openedLinks.single.toString(), 'https://soundcloud.com/someone/sets/mix');
    });
  });

  test('remote playlist ids', () {
    const p = Playlist(id: 'abc', name: 'x', kind: PlaylistKind.remote, sourceId: 'audius', sourcePlaylistId: 'abc');
    expect(remotePlaylistId(p), 'audius:abc');
    const q = Playlist(id: 'audius:abc', name: 'x', kind: PlaylistKind.remote, sourceId: 'audius', sourcePlaylistId: 'abc');
    expect(remotePlaylistId(q), 'audius:abc');
  });
}
