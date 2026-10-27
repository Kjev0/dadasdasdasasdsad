import 'dart:math';

import 'package:flutter/foundation.dart';

/// Tunables of the download engine (defaults are production values; tests
/// shorten the delays).
@immutable
class DownloadOptions {
  const DownloadOptions({
    this.maxAttempts = 5,
    this.retryBaseDelay = const Duration(seconds: 2),
    this.maxRetryDelay = const Duration(minutes: 5),
    this.maxRetryAfter = const Duration(hours: 1),
    this.progressInterval = const Duration(milliseconds: 250),
    this.indexWriteDebounce = const Duration(milliseconds: 500),
    this.headerTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 30),
    this.artworkTimeout = const Duration(seconds: 15),
    this.syncOnInit = true,
  });

  /// Failed attempts before a task is marked failed (spec: 5).
  final int maxAttempts;
  final Duration retryBaseDelay;
  final Duration maxRetryDelay;

  /// Upper bound for a server's `Retry-After`.
  final Duration maxRetryAfter;

  /// Minimum spacing of progress emissions (250 ms = at most 4 Hz).
  final Duration progressInterval;
  final Duration indexWriteDebounce;
  final Duration headerTimeout;

  /// A transfer that receives no bytes for this long is aborted (retryable).
  final Duration idleTimeout;
  final Duration artworkTimeout;

  /// Run `syncAutoDownloads()` at the end of `init()`.
  final bool syncOnInit;

  /// Exponential backoff for the [failures]-th failure (1-based) with
  /// ±20 % jitter; a server `Retry-After` takes precedence.
  Duration backoff(int failures, {Duration? retryAfter, Random? random}) {
    if (retryAfter != null) return retryAfter > maxRetryAfter ? maxRetryAfter : retryAfter;
    final exp = retryBaseDelay.inMilliseconds * pow(2, max(0, failures - 1));
    final capped = min(exp.toDouble(), maxRetryDelay.inMilliseconds.toDouble());
    final jitter = 1 + ((random ?? Random()).nextDouble() * 0.4 - 0.2);
    return Duration(milliseconds: (capped * jitter).round());
  }
}
