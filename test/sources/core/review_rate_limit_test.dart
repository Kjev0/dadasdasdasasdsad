// Adversarial review test for the Deezer client-side rate limit.
// Expected to FAIL until fixed.
import 'package:fermata/sources/base/rate_limiter.dart';
import 'package:fermata/sources/deezer/deezer_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _FakeTime {
  DateTime now = DateTime.utc(2026, 10, 27, 16, 40);
  DateTime clock() => now;
  Future<void> sleep(Duration d) async => now = now.add(d);
}

void main() {
  test('Deezer client keeps <= 50 requests in every 5 s window (claimed and required by the spec)', () async {
    final time = _FakeTime();
    final stamps = <DateTime>[];
    final net = RecordingHttp((r) async {
      stamps.add(time.now);
      return jsonResponse(fixture('deezer_genres.json'));
    });
    // Exactly how DeezerSource builds its default limiter, on virtual time.
    final source = DeezerSource(
      http: net.fermata,
      limiter: TokenBucketRateLimiter(
        capacity: 50,
        period: const Duration(seconds: 5),
        clock: time.clock,
        sleep: time.sleep,
      ),
    );
    addTearDown(source.dispose);

    // e.g. a playlist migration doing ISRC lookups back to back.
    for (var i = 0; i < 120; i++) {
      await source.api.get('genre');
    }

    var worst = 0;
    for (final start in stamps) {
      final end = start.add(const Duration(seconds: 5));
      final n = stamps.where((s) => !s.isBefore(start) && s.isBefore(end)).length;
      if (n > worst) worst = n;
    }
    // BUG: a token bucket with capacity 50 that refills 50 tokens per 5 s
    // admits a full burst of 50 plus ~49 refilled tokens inside the first
    // 5 s window (~99 requests), i.e. about twice Deezer's public limit.
    // The existing rate_limiter_test even asserts `<= 2 * capacity` under the
    // title "never exceeds capacity within any period window".
    expect(worst, lessThanOrEqualTo(50), reason: '$worst requests were sent within one 5 s window');
  });
}
