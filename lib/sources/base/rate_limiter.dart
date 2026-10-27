import 'dart:async';
import 'dart:math';

import '../../core/errors.dart';
import '../../core/util/cancel_token.dart';

/// Clock and sleep hooks so rate limiting can be tested deterministically.
typedef Clock = DateTime Function();
typedef Sleeper = Future<void> Function(Duration duration);

/// Client-side token bucket that keeps a source below a provider's public
/// rate limit (e.g. Deezer: ≤ 50 requests per 5 seconds).
///
/// [capacity] tokens refill continuously over [period]. [acquire] waits until
/// a token is available. [penalize] empties the bucket and blocks for a
/// while (used when the provider signals "quota exceeded").
class TokenBucketRateLimiter {
  TokenBucketRateLimiter({
    required this.capacity,
    required this.period,
    Clock? clock,
    Sleeper? sleep,
  })  : assert(capacity > 0),
        _clock = clock ?? DateTime.now,
        _sleep = sleep ?? ((d) => Future<void>.delayed(d)),
        _tokens = capacity.toDouble() {
    _last = _clock();
  }

  final int capacity;
  final Duration period;
  final Clock _clock;
  final Sleeper _sleep;

  double _tokens;
  late DateTime _last;
  DateTime? _blockedUntil;

  /// Serialises waiters so tokens are handed out in FIFO order.
  Future<void> _queue = Future.value();

  double get _refillPerMicro => capacity / period.inMicroseconds;

  /// Tokens currently available (after refill), for diagnostics/tests.
  double get available {
    _refill();
    return _tokens;
  }

  void _refill() {
    final now = _clock();
    final elapsed = now.difference(_last).inMicroseconds;
    if (elapsed > 0) {
      _tokens = min(capacity.toDouble(), _tokens + elapsed * _refillPerMicro);
      _last = now;
    }
  }

  /// Waits for a token. Throws [OperationCanceledException] if [cancel]
  /// fires while waiting.
  Future<void> acquire({CancelToken? cancel}) {
    final completer = Completer<void>();
    _queue = _queue.then((_) async {
      try {
        await _take(cancel);
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _take(CancelToken? cancel) async {
    while (true) {
      cancel?.throwIfCanceled();
      final now = _clock();
      final blocked = _blockedUntil;
      if (blocked != null && now.isBefore(blocked)) {
        await _wait(blocked.difference(now), cancel);
        continue;
      }
      _refill();
      if (_tokens >= 1) {
        _tokens -= 1;
        return;
      }
      final missing = 1 - _tokens;
      final waitMicros = (missing / _refillPerMicro).ceil();
      await _wait(Duration(microseconds: max(waitMicros, 1)), cancel);
    }
  }

  Future<void> _wait(Duration d, CancelToken? cancel) async {
    if (cancel == null) return _sleep(d);
    await Future.any([_sleep(d), cancel.whenCanceled]);
    cancel.throwIfCanceled();
  }

  /// The provider reported that the quota is exhausted: drop all tokens and
  /// block new requests for [backoff].
  void penalize(Duration backoff) {
    _refill();
    _tokens = 0;
    final until = _clock().add(backoff);
    if (_blockedUntil == null || until.isAfter(_blockedUntil!)) _blockedUntil = until;
  }
}
