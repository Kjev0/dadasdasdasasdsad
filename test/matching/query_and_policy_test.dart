import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/matching.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/matching/matching.dart';
import 'package:fermata/matching/util/async_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  const normalizer = TrackNormalizer();
  const builder = SearchQueryBuilder();

  group('SearchQueryBuilder', () {
    final cases = <(Track, String, List<String>)>[
      (track('spotify', 'q1', 'Adventure', ['Rogue']), 'deezer', ['Rogue Adventure', 'Adventure']),
      (track('spotify', 'q2', 'Adventure', ['Rogue']), 'soundcloud', ['Rogue Adventure', 'Adventure', 'Adventure Rogue']),
      (track('spotify', 'q3', 'Adventure - Kygo Remix', ['Rogue']), 'deezer', [
        'Rogue Adventure Kygo Remix',
        'Adventure Kygo Remix',
      ]),
      // Remaster qualifiers and features are not part of the query.
      (track('spotify', 'q4', 'Song (feat. X) - Remastered 2011', ['A']), 'deezer', ['A Song', 'Song']),
      // Provider syntax characters are stripped (Deezer's artist:"…" is unreliable).
      (track('spotify', 'q5', 'Title: "Quoted"', ['Art:ist']), 'deezer', ['Art ist Title Quoted', 'Title Quoted']),
      (track('youtube', 'q6', 'Rogue - Adventure (Official Video) 🔥', ['Monstercat']), 'deezer', [
        'Rogue Adventure',
        'Adventure',
      ]),
      (track('local', 'q7', 'Adventure', const []), 'deezer', ['Adventure']),
    ];
    for (final (original, target, expected) in cases) {
      test('"${original.title}" on $target', () {
        expect(builder.build(normalizer.normalize(original), target), expected);
      });
    }

    test('sanitize strips symbols and syntax', () {
      expect(SearchQueryBuilder.sanitize(' artist:"Daft Punk" 🔥 '), 'artist Daft Punk');
    });
  });

  group('MatchPolicy', () {
    final scorer = WeightedTrackScorer();
    final original = track('spotify', 'o', 'Adventure', ['Rogue'], seconds: 210);

    test('rank: score first, then preferred source, then playback', () {
      final c = [
        scorer.score(original, track('deezer', 'd', 'Adventure', ['Rogue'], seconds: 210, playback: PlaybackRights.preview)),
        scorer.score(original, track('audius', 'a', 'Adventure', ['Rogue'], seconds: 210)),
        scorer.score(original, track('jamendo', 'j', 'Adventure', ['Rogue'], seconds: 230)),
      ];
      expect(MatchPolicy.rank(c).map((m) => m.candidate.id), ['audius:a', 'deezer:d', 'jamendo:j']);
      expect(
        MatchPolicy.rank(c, preferredSource: 'deezer').map((m) => m.candidate.id),
        ['deezer:d', 'audius:a', 'jamendo:j'],
      );
    });

    test('decide honours thresholds and playability', () {
      final full = scorer.score(original, track('audius', 'a', 'Adventure', ['Rogue'], seconds: 210));
      final gone = scorer.score(original, track('audius', 'b', 'Adventure', ['Rogue'], seconds: 210, playback: PlaybackRights.unavailable));
      expect(MatchPolicy.decide([full], const MatchOptions()).$1, MatchDecision.autoAccepted);
      expect(MatchPolicy.decide([gone], const MatchOptions()).$1, MatchDecision.needsReview);
      expect(MatchPolicy.decide([gone], const MatchOptions(skipUnavailable: true)).$1, MatchDecision.skipped);
      expect(MatchPolicy.decide(const [], const MatchOptions()).$1, MatchDecision.notFound);
    });
  });

  group('async utils', () {
    test('semaphore limits concurrency and hands permits over FIFO', () async {
      final sem = AsyncSemaphore(2);
      var running = 0, peak = 0;
      final order = <int>[];
      await Future.wait([
        for (var i = 0; i < 6; i++)
          sem.withPermit(() async {
            running++;
            if (running > peak) peak = running;
            order.add(i);
            await Future<void>.delayed(const Duration(milliseconds: 5));
            running--;
          }),
      ]);
      expect(peak, 2);
      expect(order, [0, 1, 2, 3, 4, 5]);
      expect(sem.inUse, 0);
    });

    test('waiting for a permit is cancelable', () async {
      final sem = AsyncSemaphore(1);
      await sem.acquire();
      final token = CancelToken();
      final waiting = sem.acquire(cancel: token);
      token.cancel();
      await expectLater(waiting, throwsA(isA<OperationCanceledException>()));
      sem.release();
      expect(sem.inUse, 0);
    });

    test('rate-limit retry waits Retry-After, caps it and gives up after maxRetries', () async {
      var calls = 0;
      final value = await withRateLimitRetry(() async {
        if (++calls < 3) throw const RateLimitedException('429', retryAfter: Duration(milliseconds: 5));
        return 'ok';
      }, policy: const RateLimitPolicy(maxRetries: 2));
      expect(value, 'ok');
      expect(calls, 3);
      expect(
        const RateLimitPolicy(maxDelay: Duration(seconds: 1))
            .delayFor(const RateLimitedException('429', retryAfter: Duration(hours: 1)), 1),
        const Duration(seconds: 1),
      );
      await expectLater(
        withRateLimitRetry(() async => throw const RateLimitedException('429', retryAfter: Duration.zero),
            policy: const RateLimitPolicy(maxRetries: 1)),
        throwsA(isA<RateLimitedException>()),
      );
    });

    test('cancellableDelay aborts on cancel', () async {
      final token = CancelToken();
      final delay = cancellableDelay(const Duration(seconds: 10), token);
      token.cancel();
      await expectLater(delay, throwsA(isA<OperationCanceledException>()));
    });
  });
}
