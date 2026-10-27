import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/matching.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/matching/matching.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

const fastRetry = RateLimitPolicy(maxRetries: 2, defaultDelay: Duration(milliseconds: 5));

SourceTrackMatcher matcherFor(List<FakeSource> sources, {MatcherSettings settings = const MatcherSettings(rateLimit: fastRetry)}) =>
    SourceTrackMatcher(registry: FakeRegistry(sources), scorer: WeightedTrackScorer(), settings: settings);

void main() {
  final original = track('spotify', 'o1', 'Adventure', ['Rogue'], seconds: 210, isrc: 'GBABC1600001');
  final noIsrc = track('spotify', 'o2', 'Adventure', ['Rogue'], seconds: 210);

  group('lookup strategy', () {
    test('ISRC lookup first; exact match is auto-accepted without searching', () async {
      final deezer = FakeSource('deezer', catalog: [
        track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 211, isrc: 'gb-abc-16-00001'),
      ]);
      final result = await matcherFor([deezer]).findMatches(original, const MatchOptions(targetSources: ['deezer']));
      expect(result.decision, MatchDecision.autoAccepted);
      expect(result.chosen!.candidate.id, 'deezer:d1');
      expect(result.chosen!.confidence, MatchConfidence.exact);
      expect(deezer.isrcCalls, 1);
      expect(deezer.searchCalls, 0);
      expect(result.searchedSources, ['deezer']);
      expect(result.error, isNull);
    });

    test('falls back to metadata search with artist + title first', () async {
      final sc = FakeSource('soundcloud', capabilities: {SourceCapability.searchTracks}, catalog: [
        track('soundcloud', 's1', 'Rogue - Adventure [Monstercat Release]', ['Monstercat'], seconds: 211),
      ]);
      final result = await matcherFor([sc]).findMatches(original, const MatchOptions(targetSources: ['soundcloud']));
      expect(sc.queries.first, 'Rogue Adventure');
      expect(result.decision, MatchDecision.autoAccepted);
      expect(result.chosen!.candidate.id, 'soundcloud:s1');
    });

    test('runs up to three queries and de-duplicates candidates by id', () async {
      final src = FakeSource('audius', capabilities: {SourceCapability.searchTracks}, catalog: [
        track('audius', 'a1', 'Adventure (Kygo Remix)', ['Rogue'], seconds: 250),
        track('audius', 'a2', 'Adventure Time', ['Someone'], seconds: 100),
      ]);
      final result = await matcherFor([src]).findMatches(noIsrc, const MatchOptions(targetSources: ['audius']));
      expect(src.queries, ['Rogue Adventure', 'Adventure', 'Adventure Rogue']);
      expect(result.candidates.map((c) => c.candidate.id).toSet(), {'audius:a1', 'audius:a2'});
      expect(result.candidates, hasLength(2));
    });

    test('a significant version of the original is searched with its qualifier', () async {
      final src = FakeSource('deezer', catalog: [
        track('deezer', 'd1', 'Adventure (Kygo Remix)', ['Rogue'], seconds: 250),
        track('deezer', 'd2', 'Adventure', ['Rogue'], seconds: 210),
      ]);
      final remix = track('spotify', 'o3', 'Adventure - Kygo Remix', ['Rogue'], seconds: 250);
      final result = await matcherFor([src]).findMatches(remix, const MatchOptions(targetSources: ['deezer']));
      expect(src.queries.first, 'Rogue Adventure Kygo Remix');
      expect(result.chosen!.candidate.id, 'deezer:d1');
    });

    test("skips the original's own source and sources that are not ready", () async {
      final spotify = FakeSource('spotify', catalog: [original]);
      final deezer = FakeSource('deezer', ready: false);
      final result = await matcherFor([spotify, deezer]).findMatches(
        original,
        const MatchOptions(targetSources: ['spotify', 'deezer', 'jamendo']),
      );
      expect(spotify.searchCalls + spotify.isrcCalls, 0);
      expect(deezer.searchCalls + deezer.isrcCalls, 0);
      expect(result.decision, MatchDecision.notFound);
      final failures = result.error as SourceMatchFailures;
      expect(failures.notReady, ['deezer', 'jamendo']);
      expect(failures.isTotalFailure, isTrue);
    });

    test('empty targetSources searches every registered source in preference order', () async {
      final a = FakeSource('audius', catalog: [track('audius', 'a1', 'Adventure', ['Rogue'], seconds: 210)]);
      final j = FakeSource('jamendo', catalog: [track('jamendo', 'j1', 'Adventure', ['Rogue'], seconds: 210)]);
      final result = await matcherFor([a, j]).findMatches(noIsrc, const MatchOptions());
      expect(result.searchedSources, ['audius', 'jamendo']);
      expect(result.candidates.first.candidate.sourceId, 'audius');
    });

    test('preferredSource wins ties', () async {
      final a = FakeSource('audius', catalog: [track('audius', 'a1', 'Adventure', ['Rogue'], seconds: 210)]);
      final j = FakeSource('jamendo', catalog: [track('jamendo', 'j1', 'Adventure', ['Rogue'], seconds: 210)]);
      final result = await matcherFor([a, j]).findMatches(
        noIsrc,
        const MatchOptions(targetSources: ['audius', 'jamendo'], preferredSource: 'jamendo'),
      );
      expect(result.chosen!.candidate.id, 'jamendo:j1');
    });

    test('maxCandidates is respected', () async {
      final src = FakeSource('audius', catalog: [
        for (var i = 0; i < 8; i++) track('audius', 'a$i', 'Adventure Part $i', ['Rogue'], seconds: 210),
      ]);
      final result = await matcherFor([src]).findMatches(
        noIsrc,
        const MatchOptions(targetSources: ['audius'], maxCandidates: 3),
      );
      expect(result.candidates, hasLength(3));
    });
  });

  group('provider rules', () {
    test('YouTube is never a default target', () async {
      final yt = FakeSource('youtube', catalog: [track('youtube', 'y1', 'Rogue - Adventure', ['RogueVEVO'])]);
      final a = FakeSource('audius');
      final result = await matcherFor([yt, a]).findMatches(noIsrc, const MatchOptions());
      expect(yt.searchCalls, 0);
      expect(result.searchedSources, ['audius']);
    });

    test('explicitly selected YouTube gets at most one query per track', () async {
      final yt = FakeSource('youtube', capabilities: {SourceCapability.searchTracks});
      await matcherFor([yt]).findMatches(noIsrc, const MatchOptions(targetSources: ['youtube']));
      expect(yt.searchCalls, 1);
    });

    test('missing ISRC is enriched via Deezer, then used for ISRC lookups', () async {
      final deezer = FakeSource('deezer', catalog: [
        track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 210, isrc: 'GBABC1600001', playback: PlaybackRights.preview),
      ]);
      final spotifyTarget = FakeSource('tidal', capabilities: {SourceCapability.isrcLookup}, catalog: [
        track('tidal', 't1', 'Adventure', ['Rogue'], seconds: 210, isrc: 'GBABC1600001'),
      ]);
      final yt = track('youtube', 'v1', 'Rogue - Adventure (Official Video)', ['RogueVEVO'], seconds: 212);
      final result = await matcherFor([deezer, spotifyTarget]).findMatches(
        yt,
        const MatchOptions(targetSources: ['tidal', 'deezer']),
      );
      expect(spotifyTarget.isrcCalls, 1);
      expect(result.candidates.map((c) => c.candidate.id), contains('tidal:t1'));
      // The enriched ISRC never makes a candidate "exact".
      expect(result.candidates.every((c) => !c.matchedByIsrc), isTrue);
      // The enrichment query is reused by the Deezer target search.
      expect(deezer.queries.where((q) => q == 'Rogue Adventure'), hasLength(1));
      expect(result.chosen!.candidate.id, 'tidal:t1');
    });

    test('ISRC enrichment failures are ignored', () async {
      final deezer = FakeSource('deezer')..searchError = const NetworkException('offline');
      final target = FakeSource('tidal', catalog: [track('tidal', 't1', 'Adventure', ['Rogue'], seconds: 210)]);
      final result = await matcherFor([deezer, target]).findMatches(
        noIsrc,
        const MatchOptions(targetSources: ['tidal']),
      );
      expect(result.decision, MatchDecision.autoAccepted);
      expect(result.error, isNull);
    });

    test('Spotify search pages are capped at 10', () async {
      final sp = _LimitRecordingSource('spotify');
      final o = track('deezer', 'x', 'Adventure', ['Rogue']);
      await SourceTrackMatcher(
        registry: FakeRegistry([sp]),
        scorer: WeightedTrackScorer(),
        settings: const MatcherSettings(searchLimit: 25),
      ).findMatches(o, const MatchOptions(targetSources: ['spotify']));
      expect(sp.limits, everyElement(10));
    });
  });

  group('decisions', () {
    test('ambiguous medium candidates → needsReview', () async {
      final src = FakeSource('deezer', catalog: [
        track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 228),
        track('deezer', 'd2', 'Adventure', ['Rogue'], seconds: 192),
      ]);
      final result = await matcherFor([src]).findMatches(noIsrc, const MatchOptions(targetSources: ['deezer']));
      expect(result.decision, MatchDecision.needsReview);
      expect(result.chosen, isNull);
      expect(result.candidates.first.confidence, MatchConfidence.medium);
    });

    test('no candidates → notFound', () async {
      final src = FakeSource('deezer');
      final result = await matcherFor([src]).findMatches(noIsrc, const MatchOptions(targetSources: ['deezer']));
      expect(result.decision, MatchDecision.notFound);
      expect(result.candidates, isEmpty);
      expect(result.searchedSources, ['deezer']);
      expect(result.error, isNull);
    });

    test('only unrelated results → notFound', () async {
      final src = FakeSource('deezer', catalog: [track('deezer', 'd1', 'Adventure Club Anthem', ['DJ Other'], seconds: 400)]);
      final result = await matcherFor([src]).findMatches(noIsrc, const MatchOptions(targetSources: ['deezer']));
      expect(result.decision, MatchDecision.notFound);
    });

    test('only a remix available → needsReview, never auto-accepted', () async {
      final src = FakeSource('deezer', catalog: [track('deezer', 'd1', 'Adventure (Kygo Remix)', ['Rogue'], seconds: 210)]);
      final result = await matcherFor([src]).findMatches(noIsrc, const MatchOptions(targetSources: ['deezer']));
      expect(result.decision, MatchDecision.needsReview);
      expect(result.best!.differences, contains(MatchDifference.remix));
    });

    test('reviewAll never auto-accepts', () async {
      final src = FakeSource('deezer', catalog: [track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 210, isrc: 'GBABC1600001')]);
      final result = await matcherFor([src]).findMatches(
        original,
        const MatchOptions(targetSources: ['deezer'], reviewMode: ReviewMode.reviewAll),
      );
      expect(result.decision, MatchDecision.needsReview);
      expect(result.best!.confidence, MatchConfidence.exact);
    });

    test('score below autoAcceptThreshold → needsReview', () async {
      final src = FakeSource('deezer', catalog: [track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 215)]);
      final result = await matcherFor([src]).findMatches(
        noIsrc,
        const MatchOptions(targetSources: ['deezer'], autoAcceptThreshold: 0.99),
      );
      expect(result.decision, MatchDecision.needsReview);
    });

    test('preview-only candidate is not auto-accepted unless allowed', () async {
      Future<TrackMatchResult> run(bool allow) => matcherFor([
            FakeSource('deezer', catalog: [
              track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 210, playback: PlaybackRights.preview),
            ]),
          ]).findMatches(noIsrc, MatchOptions(targetSources: const ['deezer'], allowPreviewOnly: allow));
      expect((await run(false)).decision, MatchDecision.needsReview);
      final allowed = await run(true);
      expect(allowed.decision, MatchDecision.autoAccepted);
      expect(allowed.chosen!.differences, contains(MatchDifference.previewOnly));
    });

    test('a full-length candidate is chosen over an equal preview', () async {
      final result = await matcherFor([
        FakeSource('deezer', catalog: [
          track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 210, playback: PlaybackRights.preview),
        ]),
        FakeSource('audius', catalog: [track('audius', 'a1', 'Adventure', ['Rogue'], seconds: 210)]),
      ]).findMatches(noIsrc, const MatchOptions(targetSources: ['deezer', 'audius']));
      expect(result.decision, MatchDecision.autoAccepted);
      expect(result.chosen!.candidate.id, 'audius:a1');
    });

    test('skipUnavailable: no playable candidate → skipped', () async {
      final unavailable = FakeSource('deezer', catalog: [
        track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 210, playback: PlaybackRights.unavailable),
      ]);
      final result = await matcherFor([unavailable]).findMatches(
        noIsrc,
        const MatchOptions(targetSources: ['deezer'], skipUnavailable: true),
      );
      expect(result.decision, MatchDecision.skipped);
      final empty = await matcherFor([FakeSource('deezer')]).findMatches(
        noIsrc,
        const MatchOptions(targetSources: ['deezer'], skipUnavailable: true),
      );
      expect(empty.decision, MatchDecision.skipped);
    });
  });

  group('failure isolation', () {
    test('one failing source does not fail the match', () async {
      final broken = FakeSource('deezer')
        ..searchError = const NetworkException('offline')
        ..isrcError = const NetworkException('offline');
      final healthy = FakeSource('audius', catalog: [track('audius', 'a1', 'Adventure', ['Rogue'], seconds: 210)]);
      final result = await matcherFor([broken, healthy]).findMatches(
        original,
        const MatchOptions(targetSources: ['deezer', 'audius']),
      );
      expect(result.decision, MatchDecision.autoAccepted);
      expect(result.chosen!.candidate.id, 'audius:a1');
      expect(result.searchedSources, ['audius']);
      final failures = result.error as SourceMatchFailures;
      expect(failures.errors.keys, ['deezer']);
      expect(failures.errors['deezer'], isA<NetworkException>());
      expect(failures.isTotalFailure, isFalse);
    });

    test('missing credentials stop further requests to that source', () async {
      final noCreds = FakeSource('deezer')..searchError = MissingCredentialsException('deezer', const ['apiKey']);
      final result = await matcherFor([noCreds]).findMatches(noIsrc, const MatchOptions(targetSources: ['deezer']));
      expect(noCreds.searchCalls, 1);
      expect(result.decision, MatchDecision.notFound);
      expect((result.error as SourceMatchFailures).errors['deezer'], isA<MissingCredentialsException>());
    });

    test('a failing query is tolerated when another query succeeds', () async {
      final flaky = _FlakySource('audius', failFirst: 1, catalog: [track('audius', 'a1', 'Adventure', ['Rogue'], seconds: 210)]);
      final result = await matcherFor([flaky]).findMatches(noIsrc, const MatchOptions(targetSources: ['audius']));
      expect(result.decision, MatchDecision.autoAccepted);
      expect(result.error, isNull);
    });

    test('rate limits are retried after retryAfter', () async {
      final limited = FakeSource('audius', catalog: [track('audius', 'a1', 'Adventure', ['Rogue'], seconds: 210)])
        ..rateLimitTimes = 2;
      final result = await matcherFor([limited]).findMatches(noIsrc, const MatchOptions(targetSources: ['audius']));
      expect(result.decision, MatchDecision.autoAccepted);
      expect(limited.searchCalls, 3);
    });

    test('exhausted rate-limit retries are recorded as the source error', () async {
      final limited = FakeSource('audius', capabilities: {SourceCapability.searchTracks})..rateLimitTimes = 100;
      final result = await matcherFor([limited]).findMatches(noIsrc, const MatchOptions(targetSources: ['audius']));
      expect(result.decision, MatchDecision.notFound);
      expect((result.error as SourceMatchFailures).errors['audius'], isA<RateLimitedException>());
    });

    test('a source without search capability is reported', () async {
      final src = FakeSource('audius', capabilities: {});
      final result = await matcherFor([src]).findMatches(noIsrc, const MatchOptions(targetSources: ['audius']));
      expect((result.error as SourceMatchFailures).errors['audius'], isA<UnsupportedSourceOperation>());
    });
  });

  group('cancellation and concurrency', () {
    test('an already canceled token throws', () async {
      final token = CancelToken()..cancel();
      expect(
        matcherFor([FakeSource('deezer')]).findMatches(noIsrc, const MatchOptions(), cancel: token),
        throwsA(isA<OperationCanceledException>()),
      );
    });

    test('canceling during a slow search throws OperationCanceledException', () async {
      final slow = FakeSource('deezer', latency: const Duration(seconds: 5));
      final token = CancelToken();
      final future = matcherFor([slow]).findMatches(noIsrc, const MatchOptions(targetSources: ['deezer']), cancel: token);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel();
      await expectLater(future, throwsA(isA<OperationCanceledException>()));
    });

    test('at most maxConcurrentTracks tracks are in flight', () async {
      final slow = FakeSource('deezer', capabilities: {SourceCapability.searchTracks}, latency: const Duration(milliseconds: 20));
      final matcher = matcherFor([slow]);
      await Future.wait([
        for (var i = 0; i < 7; i++)
          matcher.findMatches(track('spotify', 't$i', 'Song $i', ['A']), const MatchOptions(targetSources: ['deezer'])),
      ]);
      expect(slow.maxInFlight, inInclusiveRange(2, 3));
      expect(slow.searchCalls, greaterThanOrEqualTo(7));
    });
  });
}

/// Records the page size of each search.
class _LimitRecordingSource extends FakeSource {
  _LimitRecordingSource(super.id) : super(capabilities: {SourceCapability.searchTracks});

  final limits = <int>[];

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) {
    limits.add(limit);
    return super.searchTracks(query, limit: limit, cancel: cancel);
  }
}

/// Fails the first [failFirst] searches with a network error.
class _FlakySource extends FakeSource {
  _FlakySource(super.id, {required this.failFirst, super.catalog})
      : super(capabilities: {SourceCapability.searchTracks});

  int failFirst;

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) {
    if (failFirst > 0) {
      failFirst--;
      queries.add(query);
      return Future.error(const NetworkException('reset'));
    }
    return super.searchTracks(query, limit: limit, cancel: cancel);
  }
}
