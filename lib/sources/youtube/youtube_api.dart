import 'dart:convert';

import 'package:logging/logging.dart';

import '../../core/errors.dart';
import '../../core/net/http_client.dart';
import '../../core/sources/source_ids.dart';
import '../../core/util/cancel_token.dart';
import '../auth/oauth_session.dart';
import '../base/json_utils.dart';

final _log = Logger('sources.youtube.api');

/// Request layer for the YouTube Data API v3
/// (`https://www.googleapis.com/youtube/v3/`, all calls via [FermataHttp]).
///
/// * Auth: the user's OAuth token (`youtube.readonly`) when connected,
///   otherwise the API key (`key=`). User-only resources (`mine=true`) need
///   the connection.
/// * Quota (2026): `search.list` has its own bucket of **100 calls per day
///   per project**; everything else shares 10,000 units/day (1 unit per
///   list call). Daily quotas reset at midnight Pacific Time. Search calls
///   are counted locally and refused once [searchCallsPerDay] is reached;
///   Google's `quotaExceeded` / `rateLimitExceeded` errors become
///   [RateLimitedException] (retry after the Pacific-time reset).
class YouTubeApi {
  YouTubeApi({
    required this._http,
    required this._session,
    required this._apiKey,
    Uri? baseUri,
    DateTime Function()? clock,
    this.searchCallsPerDay = 100,
  }) : baseUri = baseUri ?? defaultBaseUri,
       _clock = clock ?? DateTime.now;

  static final defaultBaseUri = Uri.parse('https://www.googleapis.com/youtube/v3');

  final FermataHttp _http;
  final OAuthSession _session;
  final String? Function() _apiKey;
  final DateTime Function() _clock;
  final Uri baseUri;

  /// Local cap for `search.list` calls per Pacific-time day.
  final int searchCallsPerDay;

  int _searchCalls = 0;
  String? _searchDay;
  DateTime? _blockedUntil;

  String? get apiKey {
    final k = _apiKey();
    return k == null || k.trim().isEmpty ? null : k.trim();
  }

  bool get userConnected => _session.state.isConnected;

  /// Search calls left today according to the local counter.
  int get searchCallsRemaining {
    _rollDay();
    return (searchCallsPerDay - _searchCalls).clamp(0, searchCallsPerDay);
  }

  Uri uri(String resource, Map<String, Object?> query) {
    final params = <String, String>{
      for (final e in query.entries)
        if (e.value != null) e.key: '${e.value}',
    };
    return baseUri.replace(path: '${baseUri.path}/$resource', queryParameters: params.isEmpty ? null : params);
  }

  /// GET [resource] (`search`, `videos`, `playlists`, `playlistItems`,
  /// `channels`) → the decoded JSON object.
  Future<Map<String, Object?>> get(
    String resource,
    Map<String, Object?> query, {
    bool requireUser = false,
    CancelToken? cancel,
  }) async {
    final isSearch = resource == 'search';
    final now = _clock();
    final blocked = _blockedUntil;
    if (blocked != null && now.isBefore(blocked)) {
      throw RateLimitedException(
        'The YouTube API quota is used up until it resets.',
        retryAfter: blocked.difference(now),
      );
    }
    if (isSearch) {
      _rollDay();
      if (_searchCalls >= searchCallsPerDay) {
        throw RateLimitedException(
          'YouTube allows $searchCallsPerDay searches per day for this app; the limit is reached.',
          retryAfter: untilPacificMidnight(now),
        );
      }
    }
    final useUser = requireUser || userConnected;
    if (requireUser && !userConnected) {
      _session.requireCredentials();
      throw AuthRequiredException(SourceIds.youtube, 'Connect your YouTube account to use your library.');
    }
    final key = apiKey;
    if (!useUser && key == null) {
      if (_session.hasCredentials) {
        throw AuthRequiredException(SourceIds.youtube, 'Connect your YouTube account (or configure an API key).');
      }
      throw MissingCredentialsException(SourceIds.youtube, const ['apiKey', 'clientId']);
    }
    if (isSearch) _searchCalls++;
    try {
      if (useUser) {
        try {
          return asJsonMap(await _session.authorizedGetJson(uri(resource, query), cancel: cancel));
        } on AuthRequiredException {
          if (requireUser || key == null) rethrow;
          _log.fine('YouTube session unusable; using the API key for a public request');
        }
      }
      return asJsonMap(await _http.getJson(uri(resource, {...query, 'key': key}), cancel: cancel));
    } on ApiException catch (e) {
      throw _mapError(e);
    }
  }

  /// Like [get] but null for 404 (unknown playlist / video).
  Future<Map<String, Object?>?> getOrNull(
    String resource,
    Map<String, Object?> query, {
    bool requireUser = false,
    CancelToken? cancel,
  }) async {
    try {
      return await get(resource, query, requireUser: requireUser, cancel: cancel);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  void _rollDay() {
    final day = pacificDate(_clock());
    if (day != _searchDay) {
      _searchDay = day;
      _searchCalls = 0;
    }
  }

  /// Google error bodies: `{"error":{"code":403,"message":"…","errors":[{"reason":"quotaExceeded",…}]}}`.
  FermataException _mapError(ApiException e) {
    final error = _errorBody(e.body);
    final reasons = {
      for (final r in asJsonMapList(error['errors'])) ?jsonString(r['reason']),
      for (final d in asJsonMapList(error['details'])) ?jsonString(d['reason']),
    };
    final message = jsonString(error['message']) ?? e.message;
    if (reasons.any((r) => r.contains('quotaExceeded') || r == 'dailyLimitExceeded')) {
      final until = _clock().add(untilPacificMidnight(_clock()));
      _blockedUntil = until;
      return RateLimitedException('YouTube API quota exceeded: $message', retryAfter: untilPacificMidnight(_clock()));
    }
    if (reasons.any((r) => r.contains('RateLimitExceeded') || r == 'rateLimitExceeded')) {
      return RateLimitedException('YouTube rate limit: $message', retryAfter: const Duration(minutes: 1));
    }
    if (reasons.contains('API_KEY_INVALID') || reasons.contains('keyInvalid')) {
      return ApiException(e.statusCode, 'The configured YouTube API key was rejected: $message', body: e.body);
    }
    return ApiException(e.statusCode, 'YouTube: $message', body: e.body);
  }

  static Map<String, Object?> _errorBody(String? body) {
    if (body == null || body.isEmpty) return const {};
    try {
      return asJsonMap(asJsonMap(jsonDecode(body))['error']);
    } on FormatException {
      return const {};
    }
  }

  // ---- Pacific time ---------------------------------------------------------

  /// UTC offset of US Pacific time at [utc] (PDT from the second Sunday of
  /// March 02:00 to the first Sunday of November 02:00 local time).
  static Duration pacificOffset(DateTime utc) {
    final u = utc.toUtc();
    DateTime nthSunday(int year, int month, int n) {
      var d = DateTime.utc(year, month);
      while (d.weekday != DateTime.sunday) {
        d = d.add(const Duration(days: 1));
      }
      return d.add(Duration(days: 7 * (n - 1)));
    }

    final dstStart = nthSunday(u.year, 3, 2).add(const Duration(hours: 10)); // 02:00 PST
    final dstEnd = nthSunday(u.year, 11, 1).add(const Duration(hours: 9)); // 02:00 PDT
    final dst = !u.isBefore(dstStart) && u.isBefore(dstEnd);
    return Duration(hours: dst ? -7 : -8);
  }

  /// The Pacific calendar date of [now] (`yyyy-mm-dd`).
  static String pacificDate(DateTime now) {
    final local = now.toUtc().add(pacificOffset(now));
    return '${local.year}-${local.month}-${local.day}';
  }

  /// Time until the next midnight Pacific Time (when quotas reset).
  static Duration untilPacificMidnight(DateTime now) {
    final u = now.toUtc();
    final local = u.add(pacificOffset(u));
    final nextMidnightLocal = DateTime.utc(local.year, local.month, local.day + 1);
    final nextMidnightUtc = nextMidnightLocal.subtract(pacificOffset(u));
    return nextMidnightUtc.difference(u);
  }
}
