// Adversarial review: PlaylistImportServiceImpl / ImportReport defects.
//
// Every test in this file failed before the review fixes; they now guard
// against regressions (see review_fixes_test.dart for the fixes' own tests).
import 'dart:async';

import 'package:fermata/core/contracts/matching.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/matching.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/matching/matching.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// A matcher whose results the test releases one by one.
class ControlledMatcher implements TrackMatcher {
  final pending = <String, Completer<TrackMatchResult>>{};

  @override
  Future<TrackMatchResult> findMatches(Track original, MatchOptions options, {CancelToken? cancel}) =>
      (pending[original.id] = Completer<TrackMatchResult>()).future;

  void finish(Track original) => pending[original.id]!
      .complete(TrackMatchResult(original: original, candidates: const [], decision: MatchDecision.notFound));
}

/// Every track gets one medium candidate and needs review.
class InstantMediumMatcher implements TrackMatcher {
  @override
  Future<TrackMatchResult> findMatches(Track original, MatchOptions options, {CancelToken? cancel}) async =>
      TrackMatchResult(
        original: original,
        candidates: [
          MatchCandidate(
            candidate: track('deezer', 'd${original.sourceTrackId}', original.title, ['A']),
            score: 0.8,
            confidence: MatchConfidence.medium,
          ),
        ],
        decision: MatchDecision.needsReview,
      );
}

PlaylistImportServiceImpl serviceWith(FakeSource source, TrackMatcher matcher, {ImportSettings? settings}) =>
    PlaylistImportServiceImpl(
      registry: FakeRegistry([source]),
      matcher: matcher,
      scorer: WeightedTrackScorer(),
      trackRepository: InMemoryTrackRepository(),
      playlistRepository: InMemoryPlaylistRepository(),
      linkRepository: InMemoryLinkRepository(),
      settings: settings ?? const ImportSettings(progressInterval: Duration.zero),
    );

void main() {
  final tracks = [for (var i = 0; i < 5; i++) track('spotify', 's$i', 'Song $i', ['Artist $i'], seconds: 200)];

  group('REVIEW: ImportReport.truncated', () {
    // truncated is only `playlist.trackCount > results.length`
    // (import_report.dart:161). Sources that do not report a track count, and
    // fetches stopped by maxPages / a repeated cursor, are never reported as
    // truncated; the session itself does not record that it stopped early.
    test('a playlist cut at maxTracks is reported as truncated even without trackCount', () async {
      final spotify = FakeSource('spotify')..pageSize = 2;
      spotify.playlists['p'] = (
        const Playlist(id: 'spotify:p', name: 'No count', kind: PlaylistKind.remote, sourceId: 'spotify'),
        tracks,
      );
      final service = serviceWith(
        spotify,
        SourceTrackMatcher(registry: FakeRegistry([spotify]), scorer: WeightedTrackScorer()),
        settings: const ImportSettings(progressInterval: Duration.zero, maxTracks: 3),
      );
      final id = await service.start(sourceId: 'spotify', playlistIdOrUrl: 'p', options: const MatchOptions());
      await service.watch(id).firstWhere((s) => s.phase == ImportPhase.reviewing).timeout(const Duration(seconds: 5));
      expect(service.current(id)!.total, 3);
      expect(service.report(id)!.truncated, isTrue);
    });
  });

  group('REVIEW: ImportReport positions', () {
    // ImportReport.fromState uses state.results, which is
    // `results.nonNulls` (import_session.dart:54): while matching (or after
    // a cancel) unfinished positions are dropped, so MissingTrack.position
    // is the index in the compacted list, not the playlist position.
    test('MissingTrack.position is the playlist position while matching', () async {
      final matcher = ControlledMatcher();
      final service = serviceWith(FakeSource('spotify'), matcher);
      final id = await service.startWithTracks(
        sourceId: 'spotify',
        name: 'Mix',
        tracks: tracks.take(3).toList(),
        options: const MatchOptions(),
      );
      await pumpEventQueue();
      // Track at position 1 finishes first.
      matcher.finish(tracks[1]);
      await service.watch(id).firstWhere((s) => s.processed == 1).timeout(const Duration(seconds: 5));
      final missing = service.report(id)!.missing;
      expect(missing.single.track.id, tracks[1].id);
      expect(missing.single.position, 1);
      service.cancel(id);
    });
  });

  group('REVIEW: acceptAllAtLeast is quadratic on the UI isolate', () {
    // acceptAllAtLeast calls s.resultPositionsOf(id) (a full scan of all
    // results) for every unique result: O(n^2) string compares, run
    // synchronously from a button tap. Measured 12.3 s for the supported
    // maximum of 10 000 tracks (flutter test, JIT) -> frozen UI / ANR.
    test('"accept all" on a 10 000-track import returns quickly', () async {
      final service = serviceWith(FakeSource('spotify'), InstantMediumMatcher(),
          settings: const ImportSettings(progressInterval: Duration(milliseconds: 100)));
      final big = [for (var i = 0; i < 10000; i++) track('spotify', 'big$i', 'Song $i', ['A'])];
      final id = await service.startWithTracks(
          sourceId: 'spotify', name: 'Big', tracks: big, options: const MatchOptions());
      await service.watch(id).firstWhere((s) => s.phase == ImportPhase.reviewing).timeout(const Duration(seconds: 60));
      final sw = Stopwatch()..start();
      service.acceptAllAtLeast(id, MatchConfidence.medium);
      sw.stop();
      expect(service.report(id)!.matched, 10000);
      expect(sw.elapsedMilliseconds, lessThan(1000), reason: 'blocked the isolate for ${sw.elapsedMilliseconds} ms');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('REVIEW: searchAlternatives error contract', () {
    // searchAlternatives is not `async` (playlist_import_service.dart:371):
    // unknown session / track / source errors are thrown synchronously
    // instead of completing the returned Future with an error, so callers
    // using `.then/.catchError` or a FutureBuilder get an uncaught error.
    test('an unknown session completes the Future with an error', () async {
      final service = serviceWith(FakeSource('spotify'), ControlledMatcher());
      late Future<List<MatchCandidate>> result;
      expect(() => result = service.searchAlternatives('nope', 'spotify:s1', ''), returnsNormally);
      await expectLater(result, throwsStateError);
    });
  });
}
