import 'package:logging/logging.dart';

import '../../core/errors.dart';

final _log = Logger('sources.soundcloud.limits');

/// SoundCloud rate-limit groups (developers.soundcloud.com/docs/api/rate-limits,
/// verified 2026-10-27): ~100 requests/min overall, play requests
/// (`/tracks/:id/streams`) 1,500 per 24 h, search 3,000 per hour, likes
/// (including listing them) 500 per 24 h — all per `client_id`.
enum SoundCloudRateGroup { general, search, streams, likes }

/// Honours SoundCloud 429s and documented play limits without hammering the
/// API:
///
/// * after a 429 (or `X-RateLimit-Remaining: 0`) the affected group is
///   blocked until `Retry-After` / `X-RateLimit-Reset`; calls fail fast with
///   [RateLimitedException] and make no request;
/// * stream resolutions are counted in a rolling 24 h window and capped at
///   [dailyStreamLimit] (1,500 by default — the documented play limit; the
///   budget is shared by every user of the same `client_id`). The counter is
///   in memory only.
class SoundCloudRateGate {
  SoundCloudRateGate({this.dailyStreamLimit = 1500, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Stream resolutions allowed per rolling 24 hours.
  final int dailyStreamLimit;
  final DateTime Function() _clock;

  final Map<SoundCloudRateGroup, DateTime> _blockedUntil = {};
  final List<DateTime> _streamCalls = [];

  static const _window = Duration(hours: 24);

  /// Default back-off when a 429 carries no usable `Retry-After`.
  static const defaultBackoff = {
    SoundCloudRateGroup.general: Duration(minutes: 1),
    SoundCloudRateGroup.search: Duration(minutes: 5),
    SoundCloudRateGroup.streams: Duration(minutes: 15),
    SoundCloudRateGroup.likes: Duration(minutes: 15),
  };

  /// Stream resolutions made in the last 24 hours.
  int get streamResolutionsInWindow {
    _prune();
    return _streamCalls.length;
  }

  void _prune() {
    final cutoff = _clock().subtract(_window);
    _streamCalls.removeWhere((t) => t.isBefore(cutoff));
  }

  /// Throws [RateLimitedException] when [group] is currently blocked or —
  /// for [SoundCloudRateGroup.streams] with [budget] — the daily stream
  /// budget is used up.
  void check(SoundCloudRateGroup group, {bool budget = true}) {
    final now = _clock();
    for (final g in {group, SoundCloudRateGroup.general}) {
      final until = _blockedUntil[g];
      if (until != null && now.isBefore(until)) {
        throw RateLimitedException(
          'SoundCloud rate limit reached; try again later.',
          retryAfter: until.difference(now),
        );
      }
    }
    if (group == SoundCloudRateGroup.streams && budget) {
      _prune();
      if (_streamCalls.length >= dailyStreamLimit) {
        final retry = _streamCalls.first.add(_window).difference(now);
        throw RateLimitedException(
          'SoundCloud allows $dailyStreamLimit stream requests per day for this app; the limit is reached.',
          retryAfter: retry.isNegative ? Duration.zero : retry,
        );
      }
    }
  }

  /// Records a stream resolution (counted against [dailyStreamLimit]).
  void recordStream() {
    _streamCalls.add(_clock());
    final used = streamResolutionsInWindow;
    if (used == (dailyStreamLimit * 0.8).floor()) {
      _log.warning('SoundCloud stream budget at 80 % ($used/$dailyStreamLimit in 24 h)');
    }
  }

  /// A 429 was received for [group].
  void onRateLimited(SoundCloudRateGroup group, Duration? retryAfter) {
    final backoff = retryAfter == null || retryAfter <= Duration.zero ? defaultBackoff[group]! : retryAfter;
    _block(group, _clock().add(backoff));
    _log.info('SoundCloud ${group.name} requests rate limited for ${backoff.inSeconds} s');
  }

  /// Applies `X-RateLimit-Remaining` / `X-RateLimit-Reset` (unix seconds).
  void onHeaders(SoundCloudRateGroup group, Map<String, String> headers) {
    final remaining = int.tryParse(headers['x-ratelimit-remaining'] ?? '');
    final reset = int.tryParse(headers['x-ratelimit-reset'] ?? '');
    if (remaining != null && remaining <= 0 && reset != null) {
      _block(group, DateTime.fromMillisecondsSinceEpoch(reset * 1000, isUtc: true));
    }
  }

  void _block(SoundCloudRateGroup group, DateTime until) {
    final current = _blockedUntil[group];
    if (current == null || until.isAfter(current)) _blockedUntil[group] = until;
  }
}
