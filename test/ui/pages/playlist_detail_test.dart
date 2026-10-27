import 'package:fermata/app/services.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/matching.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/ui/actions/routes.dart';
import 'package:fermata/ui/pages/import/import_review_page.dart';
import 'package:fermata/ui/pages/playlists/playlist_detail_page.dart';
import 'package:fermata/ui/pages/playlists/playlist_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'support/page_harness.dart';

(FakeKit, RecordingPlaylistRepository, AppServices) _setup({List<Track> tracks = const [], List<MusicSource> sources = const []}) {
  final kit = FakeKit(tracks: tracks, sources: sources);
  final playlists = RecordingPlaylistRepository(kit.libraryChanges, kit.trackRepo);
  return (kit, playlists, servicesWith(kit, playlists: playlists));
}

Finder _inPage(Finder f) => find.descendant(of: find.byType(PlaylistDetailPage), matching: f);

double _y(WidgetTester tester, String text) => tester.getTopLeft(_inPage(find.text(text))).dy;

void main() {
  test('remote ids', () {
    expect(isRemotePlaylistId('audius:pl9', {'audius'}), isTrue);
    expect(isRemotePlaylistId('9b1f-uuid', {'audius'}), isFalse);
    expect(isRemotePlaylistId('other:1', {'audius'}), isFalse);
    expect(splitRemotePlaylistId('soundcloud:https://soundcloud.com/a/sets/b'), ('soundcloud', 'https://soundcloud.com/a/sets/b'));
  });

  testWidgets('header with stats; reorder by dragging the handle', (tester) async {
    final (kit, repo, services) = _setup(tracks: testTracks(3));
    repo.add(testPlaylist('p1', name: 'Morning'), trackIds: ['audius:t1', 'audius:t2', 'audius:t3']);
    await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('p1'));
    expect(_inPage(find.text('Morning')), findsOneWidget);
    expect(find.text('3 tracks · 10 min'), findsOneWidget);
    expect(_y(tester, 'Song 1'), lessThan(_y(tester, 'Song 2')));

    final handle = find.byIcon(Icons.drag_indicator_rounded).first;
    final row = tester.getSize(find.byKey(const ValueKey('entry-0-audius:t1'))).height;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 7; i++) {
      await gesture.moveBy(Offset(0, row * 0.5));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await settle(tester);
    expect(repo.moves, [(0, 2)]);
    expect(repo.entries['p1'], ['audius:t2', 'audius:t3', 'audius:t1']);
    expect(_y(tester, 'Song 2'), lessThan(_y(tester, 'Song 1')));
  });

  testWidgets('bulk select → remove from playlist', (tester) async {
    final (kit, repo, services) = _setup(tracks: testTracks(3));
    repo.add(testPlaylist('p1', name: 'Morning'), trackIds: ['audius:t1', 'audius:t2', 'audius:t3']);
    await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('p1'));
    await tester.longPress(_inPage(find.text('Song 2')));
    await settle(tester);
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove from playlist'));
    await settle(tester);
    expect(repo.entries['p1'], ['audius:t1', 'audius:t3']);
    expect(_inPage(find.text('Song 2')), findsNothing);
    expect(find.text('Removed 1 track'), findsOneWidget);
  });

  testWidgets('bulk add to queue uses the shared selection bar', (tester) async {
    final (kit, repo, services) = _setup(tracks: testTracks(2));
    repo.add(testPlaylist('p1'), trackIds: ['audius:t1', 'audius:t2']);
    await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('p1'));
    await tester.longPress(_inPage(find.text('Song 1')));
    await settle(tester);
    await tester.tap(find.byTooltip('Add to queue'));
    await settle(tester);
    expect((kit.playback.argsOf('enqueue')[0] as List<Track>).single.sourceTrackId, 't1');
  });

  testWidgets('unavailable tracks are greyed; external imports offer alternatives and link a match', (tester) async {
    final spotify = testTrack('sp1', sourceId: SourceIds.spotify, title: 'Imported hit', playback: PlaybackRights.externalOnly);
    final gone = testTrack('x1', title: 'Gone track', playback: PlaybackRights.unavailable, reason: AvailabilityReason.deleted);
    final candidate = testTrack('a9', title: 'Imported hit');
    final audius = FakeMusicSource(id: SourceIds.audius, displayName: 'Audius', tracks: [candidate]);
    final (kit, repo, services) = _setup(tracks: [spotify, gone, ...testTracks(1)], sources: [audius]);
    kit.matcher.results[spotify.id] = TrackMatchResult(
      original: spotify,
      decision: MatchDecision.needsReview,
      candidates: [MatchCandidate(candidate: candidate, score: 0.93, confidence: MatchConfidence.high)],
    );
    repo.add(const Playlist(id: 'p1', name: 'From Spotify', kind: PlaylistKind.local, sourceId: SourceIds.spotify, sourcePlaylistId: 'abc'),
        trackIds: [spotify.id, gone.id, 'audius:t1']);
    await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('p1'));
    expect(find.text('Imported from Spotify'.toUpperCase()), findsOneWidget);
    final opacity = tester.widget<Opacity>(find.ancestor(of: _inPage(find.text('Gone track')), matching: find.byType(Opacity)).first);
    expect(opacity.opacity, 0.5);

    await tester.tap(find.byKey(ValueKey('alternatives-${spotify.id}')));
    await settle(tester);
    expect(find.text('Alternatives'), findsOneWidget);
    expect(find.text('93% · very likely'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Use'));
    await settle(tester);
    final link = kit.links.links.single;
    expect((link.trackId, link.linkedTrackId, link.userConfirmed), (spotify.id, candidate.id, true));
    expect(find.text('Linked — plays from Audius'), findsOneWidget);
    Navigator.of(tester.element(find.text('Alternatives'))).pop();
    await settle(tester);
    expect(find.text('Alternatives'), findsNothing);
    expect(find.byTooltip('Plays via Audius — change'), findsOneWidget);

    // Play queues the linked import (the stream resolver plays the match)
    // but not the unavailable track.
    await tester.tap(_inPage(find.widgetWithText(FilledButton, 'Play')));
    await settle(tester);
    final queued = kit.playback.argsOf('playTracks')[0] as List<Track>;
    expect(queued.map((t) => t.id), [spotify.id, 'audius:t1']);
  });

  testWidgets('smart playlists show "Edit rules" and are not reorderable', (tester) async {
    final (kit, repo, services) = _setup(tracks: testTracks(2));
    repo.add(const Playlist(id: 's1', name: 'Smart one', kind: PlaylistKind.smart, smartRulesJson: '{"rules":[{"field":"genre","op":"contains","value":"jazz"}],"matchAll":true}'),
        trackIds: ['audius:t1', 'audius:t2']);
    await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('s1'));
    expect(find.widgetWithText(FilledButton, 'Edit rules'), findsOneWidget);
    expect(find.textContaining('1 rule, all rules'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
  });

  testWidgets('missing playlist', (tester) async {
    final (kit, _, services) = _setup();
    await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('nope'));
    expect(find.text("This playlist doesn't exist anymore."), findsOneWidget);
  });

  // Just below the compact breakpoint: narrow-row behaviour with room for
  // the shared TrackTile badges (they don't shrink; see responsive_test).
  const narrow = Size(599, 900);

  group('compact layout', () {
    testWidgets('reorder mode with drag handles', (tester) async {
      final (kit, repo, services) = _setup(tracks: testTracks(3));
      repo.add(testPlaylist('p1', name: 'Morning'), trackIds: ['audius:t1', 'audius:t2', 'audius:t3']);
      await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('p1'), size: narrow);
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('playlist-reorder')));
      await tester.tap(find.byKey(const ValueKey('playlist-reorder')));
      await settle(tester);
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(3));
      final handle = find.byIcon(Icons.drag_indicator_rounded).last;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await settle(tester);
      expect(repo.moves.single.$1, 2);
      expect(repo.entries['p1']!.first, 'audius:t3');
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping an unplayable import opens "Find alternatives"', (tester) async {
      final yt = testTrack('y1', sourceId: SourceIds.youtube, title: 'Video', playback: PlaybackRights.externalOnly);
      final (kit, repo, services) = _setup(tracks: [yt]);
      repo.add(testPlaylist('p1'), trackIds: [yt.id]);
      await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('p1'), size: narrow);
      await tester.tap(_inPage(find.text('Video')));
      await settle(tester);
      expect(find.text('Alternatives'), findsOneWidget);
      expect(kit.openedLinks, isEmpty);
    });
  });

  testWidgets('adding SoundCloud tracks to an open queue asks to start a new queue', (tester) async {
    final sc = [testTrack('s1', sourceId: SourceIds.soundcloud, title: 'SC one')];
    final (kit, repo, services) = _setup(tracks: sc);
    kit.playback.load(testTracks(1));
    kit.playback.canJoin = (tracks) => false;
    repo.add(testPlaylist('p1'), trackIds: [sc.single.id]);
    await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('p1'));
    await tester.longPress(_inPage(find.text('SC one')));
    await settle(tester);
    await tester.tap(find.byTooltip('Add to queue'));
    await settle(tester);
    expect(find.text("SoundCloud tracks play in their own queue (SoundCloud's terms). Start a new queue?"), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start new queue'));
    await settle(tester);
    expect((kit.playback.argsOf('playTracks')[0] as List<Track>).single.id, sc.single.id);
  });

  group('remote playlists', () {
    FakeMusicSource audius() => FakeMusicSource(
          id: SourceIds.audius,
          displayName: 'Audius',
          capabilities: const {SourceCapability.searchTracks, SourceCapability.stream, SourceCapability.playlistImport},
          playlists: [
            Playlist(
              id: 'audius:pl9',
              name: 'Late Night',
              kind: PlaylistKind.remote,
              sourceId: SourceIds.audius,
              sourcePlaylistId: 'pl9',
              ownerName: 'DJ',
              permalink: Uri.parse('https://audius.co/dj/playlist/late-night'),
            ),
          ],
          tracks: testTracks(3, prefix: 'r'),
        );

    testWidgets('shows tracks with attribution; save to library copies it', (tester) async {
      final (kit, repo, services) = _setup(sources: [audius()]);
      await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('audius:pl9'));
      expect(find.text('PLAYLIST ON AUDIUS'), findsOneWidget);
      expect(_inPage(find.text('Late Night')), findsOneWidget);
      expect(find.text('Data from Audius'), findsOneWidget);
      expect(_inPage(find.text('Song 3')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-to-library')));
      await settle(tester);
      final saved = (await repo.playlists()).single;
      expect((saved.name, saved.sourceId, saved.sourcePlaylistId), ('Late Night', SourceIds.audius, 'pl9'));
      expect(repo.entries[saved.id], ['audius:r1', 'audius:r2', 'audius:r3']);
      expect(tester.widget<PlaylistDetailPage>(find.byType(PlaylistDetailPage)).playlistId, saved.id);
    });

    testWidgets('import & match starts an import session', (tester) async {
      final (kit, _, services) = _setup(sources: [audius()]);
      await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('audius:pl9'));
      await tester.tap(find.byKey(const ValueKey('import-and-match')));
      await settle(tester);
      expect(kit.imports.calls, ['start']);
      expect(find.byType(ImportReviewPage), findsOneWidget);
    });

    testWidgets('open on provider', (tester) async {
      final (kit, _, services) = _setup(sources: [audius()]);
      await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('audius:pl9'));
      await tester.tap(find.text('Open on Audius'));
      await settle(tester);
      expect(kit.openedLinks.single.toString(), 'https://audius.co/dj/playlist/late-night');
    });

    testWidgets('errors offer retry', (tester) async {
      final (kit, _, services) = _setup(sources: [audius()]);
      await pumpPage(tester, kit: kit, services: services, route: AppRoutes.playlist('audius:missing'));
      expect(find.text('Something went wrong.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
