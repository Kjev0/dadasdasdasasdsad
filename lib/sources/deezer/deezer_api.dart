import 'package:logging/logging.dart';

import '../../core/errors.dart';
import '../../core/net/http_client.dart';
import '../../core/util/cancel_token.dart';
import '../base/json_utils.dart';
import '../base/rate_limiter.dart';

final _log = Logger('sources.deezer.api');

/// Client for the public Deezer API (`https://api.deezer.com`, no auth).
///
/// * Requests pass a client-side sliding-window limiter ([limiter], max 50 per
///   any 5 s — the commonly cited public limit; the official docs are
///   login-gated, see docs/research/API_NOTES.md §4.2).
/// * Deezer reports errors inside HTTP 200 bodies:
///   `{"error":{"type":"…","message":"…","code":N}}`. Code 4 ("quota
///   exceeded") penalises the bucket, retries a couple of times and then
///   throws [RateLimitedException]; 800 ("no data") becomes a 404
///   [ApiException]; 700 ("service busy") is retried once.
class DeezerApi {
  DeezerApi(
    this._http, {
    Uri? baseUri,
    TokenBucketRateLimiter? limiter,
    this.quotaBackoff = const Duration(seconds: 5),
    this.maxQuotaRetries = 2,
  }) : baseUri = baseUri ?? Uri.parse('https://api.deezer.com'),
       limiter = limiter ?? TokenBucketRateLimiter(capacity: 50, period: const Duration(seconds: 5));

  final FermataHttp _http;
  final Uri baseUri;
  final TokenBucketRateLimiter limiter;
  final Duration quotaBackoff;
  final int maxQuotaRetries;

  /// Deezer error codes (public API).
  static const codeQuota = 4;
  static const codeItemsLimit = 100;
  static const codePermission = 200;
  static const codeTokenInvalid = 300;
  static const codeParameter = 500;
  static const codeParameterMissing = 501;
  static const codeQueryInvalid = 600;
  static const codeServiceBusy = 700;
  static const codeNotFound = 800;

  Uri uri(String path, [Map<String, Object?> query = const {}]) {
    final params = <String, String>{
      for (final e in query.entries)
        if (e.value != null) e.key: '${e.value}',
    };
    final base = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
    return baseUri.replace(
      path: '$base/${path.startsWith('/') ? path.substring(1) : path}',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  /// GET [path] and return the JSON object (error envelopes are thrown).
  Future<Map<String, Object?>> get(String path, {Map<String, Object?> query = const {}, CancelToken? cancel}) async {
    final target = uri(path, query);
    var busyRetried = false;
    for (var attempt = 0; ; attempt++) {
      await limiter.acquire(cancel: cancel);
      final json = await _http.getJson(target, cancel: cancel);
      final map = asJsonMapOrNull(json);
      if (map == null) throw ApiException(200, 'Unexpected Deezer response for $path');
      final error = asJsonMapOrNull(map['error']);
      if (error == null) return map;
      final code = jsonInt(error['code']);
      final message = jsonString(error['message']) ?? 'Deezer error';
      if (code == codeQuota) {
        limiter.penalize(quotaBackoff);
        if (attempt < maxQuotaRetries) {
          _log.info('Deezer quota exceeded; backing off ${quotaBackoff.inSeconds} s');
          continue;
        }
        throw RateLimitedException('Deezer rate limit reached: $message', retryAfter: quotaBackoff);
      }
      if (code == codeServiceBusy && !busyRetried) {
        busyRetried = true;
        continue;
      }
      throw ApiException(_statusFor(code), 'Deezer: $message (code $code)', body: error.toString());
    }
  }

  /// Like [get] but returns null for "no data" (code 800 / HTTP 404).
  Future<Map<String, Object?>?> getOrNull(
    String path, {
    Map<String, Object?> query = const {},
    CancelToken? cancel,
  }) async {
    try {
      return await get(path, query: query, cancel: cancel);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  static int _statusFor(int? code) => switch (code) {
    codeNotFound => 404,
    codePermission || codeTokenInvalid => 401,
    codeServiceBusy => 503,
    codeParameter || codeParameterMissing || codeQueryInvalid || codeItemsLimit => 400,
    _ => 502,
  };
}
