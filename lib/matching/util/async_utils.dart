import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../core/errors.dart';
import '../../core/util/cancel_token.dart';

/// Limits how many async operations run at once (FIFO fairness).
class AsyncSemaphore {
  AsyncSemaphore(this.permits) : assert(permits > 0);

  final int permits;
  int _inUse = 0;
  final _waiters = Queue<Completer<void>>();

  int get inUse => _inUse;

  /// Waits for a free permit. Throws [OperationCanceledException] when
  /// [cancel] fires while waiting.
  Future<void> acquire({CancelToken? cancel}) {
    cancel?.throwIfCanceled();
    if (_inUse < permits) {
      _inUse++;
      return Future.value();
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    cancel?.whenCanceled.then((_) {
      if (_waiters.remove(waiter)) waiter.completeError(const OperationCanceledException());
    });
    return waiter.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      // Hand the permit straight to the next waiter.
      _waiters.removeFirst().complete();
    } else if (_inUse > 0) {
      _inUse--;
    }
  }

  Future<T> withPermit<T>(Future<T> Function() action, {CancelToken? cancel}) async {
    await acquire(cancel: cancel);
    try {
      return await action();
    } finally {
      release();
    }
  }
}

/// Completes after [duration], or throws [OperationCanceledException] as
/// soon as [cancel] fires.
Future<void> cancellableDelay(Duration duration, CancelToken? cancel) {
  if (duration <= Duration.zero) {
    cancel?.throwIfCanceled();
    return Future.value();
  }
  if (cancel == null) return Future.delayed(duration);
  cancel.throwIfCanceled();
  final done = Completer<void>();
  final timer = Timer(duration, () {
    if (!done.isCompleted) done.complete();
  });
  cancel.whenCanceled.then((_) {
    timer.cancel();
    if (!done.isCompleted) done.completeError(const OperationCanceledException());
  });
  return done.future;
}

/// How to react to [RateLimitedException]s.
@immutable
class RateLimitPolicy {
  const RateLimitPolicy({
    this.maxRetries = 2,
    this.defaultDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(seconds: 30),
  });

  /// Retries after the first attempt; 0 disables retrying.
  final int maxRetries;

  /// Wait when the source gives no Retry-After (multiplied by the attempt).
  final Duration defaultDelay;

  /// Upper bound for any single wait (a huge Retry-After fails fast instead
  /// of stalling an import).
  final Duration maxDelay;

  Duration delayFor(RateLimitedException e, int attempt) {
    final wanted = e.retryAfter ?? defaultDelay * attempt;
    if (wanted > maxDelay) return maxDelay;
    return wanted < Duration.zero ? Duration.zero : wanted;
  }
}

/// Runs [action], waiting and retrying on [RateLimitedException] according
/// to [policy]. Other errors propagate unchanged.
Future<T> withRateLimitRetry<T>(
  Future<T> Function() action, {
  RateLimitPolicy policy = const RateLimitPolicy(),
  CancelToken? cancel,
  Logger? log,
  String? label,
}) async {
  var attempt = 0;
  while (true) {
    cancel?.throwIfCanceled();
    try {
      return await action();
    } on RateLimitedException catch (e) {
      if (attempt >= policy.maxRetries) rethrow;
      attempt++;
      final delay = policy.delayFor(e, attempt);
      log?.info('${label ?? 'request'} rate limited; retry $attempt/${policy.maxRetries} in ${delay.inMilliseconds} ms');
      await cancellableDelay(delay, cancel);
    }
  }
}
