import 'package:fermata/core/errors.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/sources/base/rate_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Virtual time: sleeping advances the clock instantly.
class _FakeTime {
  DateTime now = DateTime(2026, 10, 27, 12);
  final List<Duration> sleeps = [];

  DateTime clock() => now;

  Future<void> sleep(Duration d) async {
    sleeps.add(d);
    now = now.add(d);
  }
}

void main() {
  test('allows a burst of capacity, then waits until the window frees up', () async {
    final t = _FakeTime();
    final limiter = TokenBucketRateLimiter(
      capacity: 50,
      period: const Duration(seconds: 5),
      clock: t.clock,
      sleep: t.sleep,
    );
    final start = t.now;
    for (var i = 0; i < 50; i++) {
      await limiter.acquire();
    }
    expect(t.now, start, reason: 'the first 50 requests need no waiting');
    await limiter.acquire();
    // The 51st request must be a full period after the 1st (<= capacity in any window).
    expect(t.now.difference(start), const Duration(seconds: 5));
    for (var i = 0; i < 49; i++) {
      await limiter.acquire();
    }
    expect(t.now.difference(start), const Duration(seconds: 5), reason: 'the second burst fits the freed window');
  });

  test('never exceeds capacity within any period window', () async {
    final t = _FakeTime();
    final limiter = TokenBucketRateLimiter(
      capacity: 5,
      period: const Duration(seconds: 1),
      clock: t.clock,
      sleep: t.sleep,
    );
    final stamps = <DateTime>[];
    for (var i = 0; i < 40; i++) {
      await limiter.acquire();
      stamps.add(t.now);
    }
    for (var i = 0; i < stamps.length; i++) {
      final windowEnd = stamps[i].add(const Duration(seconds: 1));
      final inWindow = stamps.where((s) => !s.isBefore(stamps[i]) && s.isBefore(windowEnd)).length;
      expect(inWindow, lessThanOrEqualTo(5));
    }
    final last = stamps.sublist(20);
    final span = last.last.difference(last.first);
    expect(span.inMilliseconds, greaterThanOrEqualTo(3000), reason: 'steady state is 5 per second');
  });

  test('penalize blocks for the backoff', () async {
    final t = _FakeTime();
    final limiter = TokenBucketRateLimiter(
      capacity: 50,
      period: const Duration(seconds: 5),
      clock: t.clock,
      sleep: t.sleep,
    );
    await limiter.acquire();
    limiter.penalize(const Duration(seconds: 5));
    final before = t.now;
    await limiter.acquire();
    expect(t.now.difference(before), greaterThanOrEqualTo(const Duration(seconds: 5)));
  });

  test('cancellation while waiting', () async {
    final limiter = TokenBucketRateLimiter(capacity: 1, period: const Duration(seconds: 30));
    await limiter.acquire();
    final cancel = CancelToken();
    final pending = limiter.acquire(cancel: cancel);
    cancel.cancel();
    await expectLater(pending, throwsA(isA<OperationCanceledException>()));
  });

  test('waiters are served in order with the real clock', () async {
    final limiter = TokenBucketRateLimiter(capacity: 2, period: const Duration(milliseconds: 100));
    final order = <int>[];
    await Future.wait([for (var i = 0; i < 5; i++) limiter.acquire().then((_) => order.add(i))]);
    expect(order, [0, 1, 2, 3, 4]);
  });
}
