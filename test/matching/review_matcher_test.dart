// Adversarial review: SourceTrackMatcher defects.
//
// Every test in this file failed before the review fixes; they now guard
// against regressions (see review_fixes_test.dart for the fixes' own tests).
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/matching.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/matching/matching.dart';
import 'package:fermata/matching/util/async_utils.dart' show withRateLimitRetry;
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Like Deezer's `lookupByIsrc` (`track/isrc:<trim().toUpperCase()>`): the
/// provider does an exact lookup and does not strip separators.
class StrictIsrcSource extends FakeSource {
  StrictIsrcSource(super.id, {super.catalog});

  final List<String> isrcArgs = [];

  @override
  Future<Track?> lookupByIsrc(String isrc, {CancelToken? cancel}) async {
    isrcArgs.add(isrc);
    isrcCalls++;
    final code = isrc.trim().toUpperCase();
    for (final t in catalog) {
      if (t.isrc == code) return t;
    }
    return null;
  }
}

void main() {
  group('REVIEW: ISRC is sent to providers un-normalized', () {
    // matcher.dart:126 `run.isrc = normalized.isrc != null ? original.isrc : null;`
    // passes the raw ISRC ("us-um7-17-03861", common in ID3 TSRC tags and
    // CSV/M3U imports) to lookupByIsrc although the module normalizes ISRCs
    // everywhere else (docs/MATCHING.md: "case/whitespace/hyphen-insensitive").
    test('lookupByIsrc receives the normalized ISRC', () async {
      final deezer = StrictIsrcSource('deezer', catalog: [
        track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 210, isrc: 'USUM71703861'),
      ]);
      final matcher = SourceTrackMatcher(registry: FakeRegistry([deezer]), scorer: WeightedTrackScorer());
      final local = track('local', 'l1', 'Adventure', ['Rogue'], seconds: 210, isrc: 'us-um7-17-03861');
      final result = await matcher.findMatches(local, const MatchOptions(targetSources: ['deezer']));
      expect(deezer.isrcArgs, ['USUM71703861']);
      expect(result.best?.matchedByIsrc, isTrue);
    });
  });

  group('REVIEW: rate limits stall imports and keep hammering an exhausted source', () {
    // RateLimitPolicy.maxDelay is documented as "a huge Retry-After fails
    // fast instead of stalling an import", but delayFor() just clamps to
    // maxDelay (30 s) and retries. A rate-limited query is not fatal for the
    // source either, so the next query (and the next track) asks again.
    // With Spotify's dev-mode QUOTA_EXCEEDED (Retry-After of hours, see
    // API_NOTES §2) every remaining track waits 2 x 30 s per query = ~2 min.
    test('a Retry-After far beyond maxDelay is not retried (fails fast)', () async {
      var calls = 0;
      final future = withRateLimitRetry<int>(
        () async {
          calls++;
          throw const RateLimitedException('quota', retryAfter: Duration(hours: 6));
        },
        policy: const RateLimitPolicy(maxDelay: Duration(milliseconds: 10)),
      );
      await expectLater(future, throwsA(isA<RateLimitedException>()));
      expect(calls, 1, reason: 'retried $calls times after a 6 h Retry-After');
    });

    test('an exhausted source is not asked again for the remaining queries of the track', () async {
      final spotify = FakeSource('spotify')
        ..rateLimitTimes = 1000
        ..rateLimitRetryAfter = const Duration(hours: 6);
      final matcher = SourceTrackMatcher(
        registry: FakeRegistry([spotify]),
        scorer: WeightedTrackScorer(),
        settings: const MatcherSettings(rateLimit: RateLimitPolicy(maxDelay: Duration(milliseconds: 5))),
      );
      final original = track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 210);
      final result = await matcher.findMatches(original, const MatchOptions(targetSources: ['spotify']));
      expect(result.error, isA<SourceMatchFailures>());
      // Before the fix: 6 requests (2 queries x 3 attempts) for a source that said
      // "come back in 6 hours".
      expect(spotify.searchCalls, lessThanOrEqualTo(1), reason: 'queries: ${spotify.queries}');
    });

    test('a source that reported a long rate limit is skipped for the next tracks', () async {
      final spotify = FakeSource('spotify')
        ..rateLimitTimes = 1000
        ..rateLimitRetryAfter = const Duration(hours: 6);
      final matcher = SourceTrackMatcher(
        registry: FakeRegistry([spotify]),
        scorer: WeightedTrackScorer(),
        settings: const MatcherSettings(rateLimit: RateLimitPolicy(maxDelay: Duration(milliseconds: 5))),
      );
      const options = MatchOptions(targetSources: ['spotify']);
      await matcher.findMatches(track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 210), options);
      final before = spotify.searchCalls;
      await matcher.findMatches(track('deezer', 'd2', 'Firestone', ['Kygo'], seconds: 271), options);
      expect(spotify.searchCalls - before, 0, reason: 'second track sent ${spotify.searchCalls - before} requests');
    });
  });

  group('REVIEW: ISRC equality bypasses every metadata gate', () {
    // scorer.dart:133 `if (isrcEqual && !significant) confidence = exact`:
    // no title/artist/duration sanity check. Audius and SoundCloud ISRCs are
    // typed in by uploaders (API_NOTES), and AudiusSource supports
    // isrcLookup, so a fan re-upload / edit carrying the original's ISRC is
    // returned by the ISRC-first lookup, scored `exact` and auto-accepted
    // without any text search - even with another artist and 45 s longer.
    test('an uploader-entered ISRC on a different artist/duration is not auto-accepted', () async {
      final audius = FakeSource('audius', catalog: [
        track('audius', 'a1', 'Adventure', ['xX Fan Uploads Xx'], seconds: 255, isrc: 'GBABC1600001'),
      ]);
      final matcher = SourceTrackMatcher(registry: FakeRegistry([audius]), scorer: WeightedTrackScorer());
      final original = track('spotify', 's1', 'Adventure', ['Rogue'], seconds: 210, isrc: 'GBABC1600001');
      final result = await matcher.findMatches(original, const MatchOptions(targetSources: ['audius']));
      final best = result.best!;
      expect(best.differences, containsAll([MatchDifference.artistMismatch, MatchDifference.durationMismatch]));
      expect(result.decision, isNot(MatchDecision.autoAccepted),
          reason: 'confidence=${best.confidence} score=${best.score} queries=${audius.queries}');
    });
  });

  group('REVIEW: ISRC placeholders are treated as real ISRCs', () {
    // TrackNormalizer.normalizeIsrc accepts any non-empty string; there is no
    // ISRC format check (2 letters + 3 alphanumerics + 7 digits). Placeholder
    // values found in ID3 TSRC tags and uploader-entered metadata ("N/A",
    // "0", "unknown") make unrelated tracks "exact" matches.
    test('two tracks with ISRC "N/A" are not an exact match', () {
      final m = WeightedTrackScorer().score(
        track('local', 'l1', 'Adventure', ['Rogue'], seconds: 210, isrc: 'N/A'),
        track('audius', 'a1', 'Something Else', ['Somebody'], seconds: 120, isrc: 'n/a'),
      );
      expect(m.confidence, isNot(MatchConfidence.exact), reason: 'score=${m.score}');
      expect(m.matchedByIsrc, isFalse);
    });

    test('an invalid ISRC is not sent to lookupByIsrc', () async {
      final deezer = StrictIsrcSource('deezer');
      final matcher = SourceTrackMatcher(registry: FakeRegistry([deezer]), scorer: WeightedTrackScorer());
      await matcher.findMatches(
        track('local', 'l1', 'Adventure', ['Rogue'], seconds: 210, isrc: 'unknown'),
        const MatchOptions(targetSources: ['deezer']),
      );
      expect(deezer.isrcArgs, isEmpty);
    });
  });

  group('REVIEW: explicit original silently replaced by the clean edit', () {
    // explicit is only a 0.04 weight + a flag; a clean (censored) edit of an
    // explicit original scores 0.96 "high" and is auto-accepted.
    test('a clean edit is not auto-accepted for an explicit original', () async {
      final deezer = FakeSource('deezer', catalog: [
        track('deezer', 'd1', 'Song', ['Artist'], seconds: 200, explicit: false, album: 'Album', year: 2020),
      ]);
      final matcher = SourceTrackMatcher(registry: FakeRegistry([deezer]), scorer: WeightedTrackScorer());
      final original = track('spotify', 's1', 'Song', ['Artist'], seconds: 200, explicit: true, album: 'Album', year: 2020);
      final result = await matcher.findMatches(original, const MatchOptions(targetSources: ['deezer']));
      expect(result.best?.differences, contains(MatchDifference.explicitMismatch));
      expect(result.decision, isNot(MatchDecision.autoAccepted));
    });
  });

  group('REVIEW: ranking buckets let a capped candidate outrank the next band', () {
    // Band ceilings are floor - 0.005 (0.695 / 0.875 / 0.445). MatchPolicy
    // ranks by (score * 100).round(), and 0.695 -> 70 == 0.70 -> 70,
    // 0.875 -> 88 == 0.88 -> 88. Ties then go to preferredSource / target
    // order, so a low-capped candidate (here: a cover by another artist)
    // becomes `best`, contradicting docs/MATCHING.md ("a candidate capped at
    // low never ... outranks a medium one"). acceptAllAtLeast(medium) then
    // skips the track because only `best` is considered.
    test('a low cover from the preferred source does not outrank a medium original', () {
      final scorer = WeightedTrackScorer();
      final original = track('spotify', 's1', 'Hallelujah', ['Leonard Cohen'], seconds: 280);
      final cover = scorer.score(original, track('audius', 'a1', 'Hallelujah', ['Jeff Buckley'], seconds: 280));
      expect(cover.confidence, MatchConfidence.low);
      final medium = MatchCandidate(
        candidate: track('deezer', 'd1', 'Hallelujah', ['Leonard Cohen'], seconds: 292),
        score: 0.70,
        confidence: MatchConfidence.medium,
      );
      final ranked = MatchPolicy.rank([cover, medium], preferredSource: 'audius');
      expect(ranked.first.confidence, MatchConfidence.medium,
          reason: 'cover score ${cover.score} ranked above medium 0.70');
    });

    test('a medium candidate does not outrank a high one through source order', () {
      final scorer = WeightedTrackScorer();
      final original = track('spotify', 's1', 'Adventure', ['Rogue'], seconds: 210);
      // No artist on the candidate -> capped at medium, clamped to 0.875.
      final mediumCapped = scorer.score(original, track('audius', 'a1', 'Adventure', const [], seconds: 210));
      expect(mediumCapped.confidence, MatchConfidence.medium);
      final high = MatchCandidate(
        candidate: track('deezer', 'd1', 'Adventure', ['Rogue'], seconds: 210),
        score: 0.88,
        confidence: MatchConfidence.high,
      );
      final ranked = MatchPolicy.rank([high, mediumCapped], sourceOrder: ['audius', 'deezer']);
      expect(ranked.first.confidence, MatchConfidence.high);
    });
  });
}
