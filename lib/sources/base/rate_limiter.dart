import 'dart:async';
import 'dart:collection';

import '../../core/errors.dart';
import '../../core/util/cancel_token.dart';

/// Clock and sleep hooks so rate limiting can be tested deterministically.
typedef Clock = DateTime Function();
typedef Sleeper = Future<void> Function(Duration duration);

/// Client-side rate limiter that keeps a source below a provider's public
/// rate limit (e.g. Deezer: ≤ 50 requests per 5 seconds).
///
/// Sliding window: at most [capacity] requests are admitted in *any* window
/// of length [period] (a grant is only given when the grant [capacity]
/// positions earlier is at least [period] old). A plain token bucket that
/// refills [capacity] tokens per [period] would admit a full burst plus the
/// refill, i.e. almost 2 × [capacity] inside one window, which is over the
/// provider's limit. [acquire] waits until a slot is free. [penalize] fills
/// the window and blocks for a while (used when the provider signals "quota
/// exceeded").
class TokenBucketRateLimiter {
  TokenBucketRateLimiter({required this.capacity, required this.period, Clock? clock, Sleeper? sleep})
    : assert(capacity > 0),
      _clock = clock ?? DateTime.now,
      _sleep = sleep ?? ((d) => Future<void>.delayed(d));

  final int capacity;
  final Duration period;
  final Clock _clock;
  final Sleeper _sleep;

  /// Grant times inside the current window, oldest first (≤ [capacity]).
  final Queue<DateTime> _grants = Queue<DateTime>();
  DateTime? _blockedUntil;

  /// Serialises waiters so slots are handed out in FIFO order.
  Future<void> _queue = Future.value();

  /// Requests that could be sent right now without waiting, for
  /// diagnostics/tests.
  double get available {
    _prune(_clock());
    return (capacity - _grants.length).toDouble();
  }

  /// Drops grants that left the window ending at [now].
  void _prune(DateTime now) {
    while (_grants.isNotEmpty && !_grants.first.add(period).isAfter(now)) {
      _grants.removeFirst();
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
      _prune(now);
      if (_grants.length < capacity) {
        _grants.add(now);
        return;
      }
      // The window is full: the oldest grant leaves it after [period].
      final wait = _grants.first.add(period).difference(now);
      await _wait(wait > Duration.zero ? wait : const Duration(microseconds: 1), cancel);
    }
  }

  Future<void> _wait(Duration d, CancelToken? cancel) async {
    if (cancel == null) return _sleep(d);
    await Future.any([_sleep(d), cancel.whenCanceled]);
    cancel.throwIfCanceled();
  }

  /// The provider reported that the quota is exhausted: fill the window and
  /// block new requests for [backoff].
  void penalize(Duration backoff) {
    final now = _clock();
    _grants
      ..clear()
      ..addAll(List<DateTime>.filled(capacity, now));
    final until = now.add(backoff);
    if (_blockedUntil == null || until.isAfter(_blockedUntil!)) _blockedUntil = until;
  }
}
