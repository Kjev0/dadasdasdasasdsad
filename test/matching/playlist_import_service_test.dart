import 'package:fermata/core/contracts/matching.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/matching.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/matching/matching.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// One import scenario: a Spotify playlist, a Deezer and an Audius catalog.
class Harness {
  Harness({List<Track>? playlistTracks, ImportSettings? settings}) {
    final pl = playlistTracks ?? defaultPlaylist;
    spotify.playlists['37i9'] = (
      Playlist(
        id: 'spotify:37i9',
        name: 'Road Trip',
        kind: PlaylistKind.remote,
        sourceId: 'spotify',
        sourcePlaylistId: '37i9',
        trackCount: pl.length,
        description: 'Summer songs',
      ),
      pl,
    );
    final registry = FakeRegistry([spotify, deezer, audius]);
    final scorer = WeightedTrackScorer();
    service = PlaylistImportServiceImpl(
      registry: registry,
      matcher: SourceTrackMatcher(
        registry: registry,
        scorer: scorer,
        settings: const MatcherSettings(rateLimit: RateLimitPolicy(defaultDelay: Duration(milliseconds: 5))),
      ),
      scorer: scorer,
      trackRepository: tracks,
      playlistRepository: playlists,
      linkRepository: links,
      settings: settings ?? const ImportSettings(progressInterval: Duration.zero),
    );
  }

  static final exact = track('spotify', 's1', 'Adventure', ['Rogue'], seconds: 210, isrc: 'GBABC1600001');
  static final fuzzy = track('spotify', 's2', 'Firestone', ['Kygo', 'Conrad Sewell'], seconds: 271);
  static final remixOnly = track('spotify', 's3', 'Strobe', ['deadmau5'], seconds: 637);
  static final missing = track('spotify', 's4', 'Unreleased Demo Song', ['Nobody'], seconds: 180);
  static final medium = track('spotify', 's5', 'Halo', ['Beyoncé'], seconds: 261);
  static final defaultPlaylist = [exact, fuzzy, remixOnly, missing, medium];

  final spotify = FakeSource('spotify')..pageSize = 2;
  final deezer = FakeSource('deezer', catalog: [
    track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 211, isrc: 'GBABC1600001'),
    track('deezer', 'd3', 'Strobe (Kygo Remix)', ['deadmau5'], seconds: 637),
    track('deezer', 'd5', 'Halo', ['Beyonce'], seconds: 279),
  ]);
  final audius = FakeSource('audius', catalog: [
    track('audius', 'a2', 'Firestone (feat. Conrad Sewell)', ['Kygo'], seconds: 274),
  ]);
  final tracks = InMemoryTrackRepository();
  final playlists = InMemoryPlaylistRepository();
  final links = InMemoryLinkRepository();
  late final PlaylistImportServiceImpl service;

  static const options = MatchOptions(targetSources: ['deezer', 'audius']);

  Future<ImportSessionState> waitFor(String id, ImportPhase phase) =>
      service.watch(id).firstWhere((s) => s.phase == phase).timeout(const Duration(seconds: 10));

  Future<String> importAndWait() async {
    final id = await service.start(sourceId: 'spotify', playlistIdOrUrl: '37i9', options: options);
    await waitFor(id, ImportPhase.reviewing);
    return id;
  }

  TrackMatchResult result(String id, Track original) =>
      service.current(id)!.results.firstWhere((r) => r.original.id == original.id);
}

void main() {
  group('start → matching → reviewing', () {
    test('fetches every page and matches each track in playlist order', () async {
      final h = Harness();
      final id = await h.importAndWait();
      final state = h.service.current(id)!;
      expect(h.spotify.playlistCalls, 3); // 5 tracks, pages of 2
      expect(state.total, 5);
      expect(state.processed, 5);
      expect(state.playlist!.name, 'Road Trip');
      expect(state.results.map((r) => r.original.id), Harness.defaultPlaylist.map((t) => t.id));
      expect(h.result(id, Harness.exact).decision, MatchDecision.autoAccepted);
      expect(h.result(id, Harness.exact).chosen!.matchedByIsrc, isTrue);
      expect(h.result(id, Harness.fuzzy).decision, MatchDecision.autoAccepted);
      expect(h.result(id, Harness.remixOnly).decision, MatchDecision.needsReview);
      expect(h.result(id, Harness.missing).decision, MatchDecision.notFound);
      expect(h.result(id, Harness.medium).decision, MatchDecision.needsReview);
    });

    test('watch emits phases in order and progress', () async {
      final h = Harness();
      final id = await h.service.start(sourceId: 'spotify', playlistIdOrUrl: '37i9', options: Harness.options);
      final states = await h.service.watch(id).takeWhile((s) => s.phase != ImportPhase.reviewing).toList();
      final phases = states.map((s) => s.phase).toSet().toList();
      expect(phases, [ImportPhase.fetching, ImportPhase.matching]);
      final processed = states.where((s) => s.phase == ImportPhase.matching).map((s) => s.processed).toList();
      expect(processed, orderedEquals([...processed]..sort()));
    });

    test('duplicate tracks are matched once and kept at every position', () async {
      final h = Harness(playlistTracks: [Harness.exact, Harness.fuzzy, Harness.exact]);
      final id = await h.importAndWait();
      expect(h.deezer.isrcCalls, 1);
      expect(h.service.current(id)!.results, hasLength(3));
      final saved = await h.service.save(id);
      expect(h.playlists.entries[saved], ['spotify:s1', 'spotify:s2', 'spotify:s1']);
    });

    test('a playlist larger than maxTracks is truncated and reported', () async {
      final many = [for (var i = 0; i < 7; i++) track('spotify', 'm$i', 'Song $i', ['A'], seconds: 200)];
      final h = Harness(playlistTracks: many, settings: const ImportSettings(maxTracks: 4, progressInterval: Duration.zero));
      final id = await h.importAndWait();
      expect(h.service.current(id)!.results, hasLength(4));
      expect(h.service.report(id)!.truncated, isTrue);
    });

    test('fetch failure → failed phase with the error', () async {
      final h = Harness();
      h.spotify.playlistError = const NetworkException('offline');
      final id = await h.service.start(sourceId: 'spotify', playlistIdOrUrl: '37i9', options: Harness.options);
      final state = await h.waitFor(id, ImportPhase.failed);
      expect(state.error, isA<NetworkException>());
    });

    test('unknown source or unsupported import throws immediately', () async {
      final h = Harness();
      expect(
        () => h.service.start(sourceId: 'nope', playlistIdOrUrl: 'x', options: Harness.options),
        throwsArgumentError,
      );
      final h2 = Harness();
      h2.audius.capabilities.remove(SourceCapability.playlistImport);
      await expectLater(
        h2.service.start(sourceId: 'audius', playlistIdOrUrl: 'x', options: Harness.options),
        throwsA(isA<UnsupportedSourceOperation>()),
      );
    });

    test('startWithTracks imports a provided list', () async {
      final h = Harness();
      final id = await h.service.startWithTracks(
        sourceId: 'spotify',
        name: 'Liked songs',
        tracks: [Harness.exact],
        options: Harness.options,
      );
      await h.waitFor(id, ImportPhase.reviewing);
      final saved = await h.service.save(id);
      expect(h.playlists.byId[saved]!.name, 'Liked songs');
      expect(h.playlists.byId[saved]!.sourcePlaylistId, isNull);
      expect(h.playlists.entries[saved], ['spotify:s1']);
    });
  });

  group('save', () {
    test('creates the playlist with originals in order, tracks and links', () async {
      final h = Harness();
      final id = await h.importAndWait();
      final playlistId = await h.service.save(id);

      final playlist = h.playlists.byId[playlistId]!;
      expect(playlist.name, 'Road Trip');
      expect(playlist.description, 'Summer songs');
      expect(playlist.sourceId, 'spotify');
      expect(playlist.sourcePlaylistId, '37i9');
      // Every original, including the ones without a match.
      expect(h.playlists.entries[playlistId], Harness.defaultPlaylist.map((t) => t.id));

      // Originals plus accepted matches only.
      expect(
        h.tracks.tracks.keys.toSet(),
        {...Harness.defaultPlaylist.map((t) => t.id), 'deezer:d1', 'audius:a2'},
      );

      expect(h.links.links, hasLength(2));
      final isrcLink = h.links.linkFor('spotify:s1')!;
      expect(isrcLink.linkedTrackId, 'deezer:d1');
      expect(isrcLink.confidence, 1.0);
      expect(isrcLink.userConfirmed, isFalse);
      final fuzzyLink = h.links.linkFor('spotify:s2')!;
      expect(fuzzyLink.linkedTrackId, 'audius:a2');
      expect(fuzzyLink.confidence, h.result(id, Harness.fuzzy).chosen!.score);
      expect(fuzzyLink.confidence, lessThan(1));

      final state = h.service.current(id)!;
      expect(state.phase, ImportPhase.done);
      expect(state.savedPlaylistId, playlistId);
    });

    test('playlistName overrides the original name', () async {
      final h = Harness();
      final id = await h.importAndWait();
      final playlistId = await h.service.save(id, playlistName: '  My Copy ');
      expect(h.playlists.byId[playlistId]!.name, 'My Copy');
    });

    test('a failed save rolls back the playlist and can be retried', () async {
      final h = Harness();
      h.playlists.failAddTracksOnCall = 1;
      final id = await h.importAndWait();
      await expectLater(h.service.save(id), throwsA(isA<StorageException>()));
      final state = h.service.current(id)!;
      expect(state.phase, ImportPhase.reviewing);
      expect(state.error, isA<StorageException>());
      expect(h.playlists.deleted, ['pl-1']);
      final retried = await h.service.save(id);
      expect(h.playlists.entries[retried], hasLength(5));
    });

    test('saving is only possible while reviewing', () async {
      final h = Harness();
      h.deezer.latency = const Duration(milliseconds: 200);
      final id = await h.service.start(sourceId: 'spotify', playlistIdOrUrl: '37i9', options: Harness.options);
      await h.waitFor(id, ImportPhase.matching);
      expect(() => h.service.save(id), throwsStateError);
      h.service.cancel(id);
    });
  });

  group('review', () {
    test('accept a searched alternative → userAccepted, confirmed link', () async {
      final h = Harness();
      final id = await h.importAndWait();
      h.audius.catalog.add(track('audius', 'a9', 'Unreleased Demo Song', ['Nobody'], seconds: 181));
      final alternatives = await h.service.searchAlternatives(id, Harness.missing.id, 'nobody unreleased');
      expect(alternatives.first.candidate.id, 'audius:a9');
      h.service.accept(id, Harness.missing.id, alternatives.first);

      final r = h.result(id, Harness.missing);
      expect(r.decision, MatchDecision.userAccepted);
      expect(r.candidates.map((c) => c.candidate.id), contains('audius:a9'));
      await h.service.save(id);
      final link = h.links.linkFor(Harness.missing.id)!;
      expect(link.userConfirmed, isTrue);
      expect(link.confidence, 1.0);
    });

    test('reject and skip clear the choice and create no link', () async {
      final h = Harness();
      final id = await h.importAndWait();
      h.service.reject(id, Harness.exact.id);
      h.service.skip(id, Harness.fuzzy.id);
      expect(h.result(id, Harness.exact).decision, MatchDecision.userRejected);
      expect(h.result(id, Harness.exact).chosen, isNull);
      expect(h.result(id, Harness.fuzzy).decision, MatchDecision.skipped);
      final playlistId = await h.service.save(id);
      expect(h.links.links, isEmpty);
      expect(h.playlists.entries[playlistId], hasLength(5));
      expect(h.tracks.tracks.keys, isNot(contains('deezer:d1')));
    });

    test('acceptAllAtLeast(medium) accepts medium results but never remixes', () async {
      final h = Harness();
      final id = await h.importAndWait();
      h.service.acceptAllAtLeast(id, MatchConfidence.medium);
      expect(h.result(id, Harness.medium).decision, MatchDecision.userAccepted);
      expect(h.result(id, Harness.remixOnly).decision, MatchDecision.needsReview);
      expect(h.result(id, Harness.missing).decision, MatchDecision.notFound);
    });

    test('acceptAllAtLeast(high) leaves medium results for review', () async {
      final h = Harness();
      final id = await h.importAndWait();
      h.service.acceptAllAtLeast(id, MatchConfidence.high);
      expect(h.result(id, Harness.medium).decision, MatchDecision.needsReview);
    });

    test('searchAlternatives: empty query uses artist + title; failing sources are skipped', () async {
      final h = Harness();
      final id = await h.importAndWait();
      h.deezer.searchError = const NetworkException('offline');
      final results = await h.service.searchAlternatives(id, Harness.fuzzy.id, '');
      expect(h.audius.queries.last, 'Kygo Firestone');
      expect(results.single.candidate.id, 'audius:a2');
      await expectLater(
        h.service.searchAlternatives(id, Harness.fuzzy.id, 'x', sourceId: 'deezer'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('review actions validate ids', () async {
      final h = Harness();
      final id = await h.importAndWait();
      expect(() => h.service.reject(id, 'spotify:unknown'), throwsArgumentError);
      expect(() => h.service.reject('no-session', Harness.exact.id), throwsStateError);
    });
  });

  group('cancel and report', () {
    test('cancel stops matching and closes the stream', () async {
      final h = Harness();
      h.deezer.latency = const Duration(seconds: 5);
      final id = await h.service.start(sourceId: 'spotify', playlistIdOrUrl: '37i9', options: Harness.options);
      await h.waitFor(id, ImportPhase.matching);
      final done = h.service.watch(id).toList();
      h.service.cancel(id);
      final states = await done.timeout(const Duration(seconds: 2));
      expect(states.last.phase, ImportPhase.canceled);
      expect(h.service.current(id)!.phase, ImportPhase.canceled);
      expect(() => h.service.save(id), throwsStateError);
    });

    test('ImportReport counts decisions and lists missing tracks', () async {
      final h = Harness();
      final id = await h.importAndWait();
      h.service.reject(id, Harness.medium.id);
      final report = h.service.report(id)!;
      expect(report.total, 5);
      expect(report.matched, 2);
      expect(report.count(MatchDecision.autoAccepted), 2);
      expect(report.count(MatchDecision.notFound), 1);
      expect(report.pendingReview, 1);
      expect(report.matchedBySource, {'deezer': 1, 'audius': 1});
      expect(report.missing.map((m) => (m.position, m.decision)), [
        (2, MatchDecision.needsReview),
        (3, MatchDecision.notFound),
        (4, MatchDecision.userRejected),
      ]);
      expect(report.notFound.single.track.id, Harness.missing.id);
      expect(report.matchRate, closeTo(0.4, 1e-9));
      expect(report.truncated, isFalse);
    });

    test('matcher errors for one track do not fail the import', () async {
      final h = Harness(playlistTracks: [Harness.exact, Harness.fuzzy]);
      h.deezer
        ..searchError = const NetworkException('offline')
        ..isrcError = const NetworkException('offline');
      final id = await h.importAndWait();
      final exact = h.result(id, Harness.exact);
      expect(exact.decision, MatchDecision.notFound);
      expect((exact.error as SourceMatchFailures).errors.keys, ['deezer']);
      expect(h.result(id, Harness.fuzzy).decision, MatchDecision.autoAccepted);
      expect(h.service.report(id)!.failed.single.track.id, Harness.exact.id);
    });
  });
}
