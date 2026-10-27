import 'dart:convert';

import '../../core/errors.dart';
import '../../core/net/http_client.dart';
import '../../core/sources/source_ids.dart';
import '../../core/util/cancel_token.dart';
import '../base/json_utils.dart';

/// A Jamendo result list plus the header's counts.
class JamendoResults {
  const JamendoResults(this.items, {this.count, this.fullCount});

  final List<Map<String, Object?>> items;

  /// `headers.results_count` (items in this response).
  final int? count;

  /// `headers.results_fullcount` (only with `fullcount=true`).
  final int? fullCount;
}

/// Request layer for the Jamendo API v3 (`https://api.jamendo.com/v3.0/`,
/// developer.jamendo.com, verified 2026-10-27; all calls via [FermataHttp]).
///
/// * Every call carries `client_id` (required) and `format=json`.
/// * Multi-value parameters are space separated (`type=single albumtrack`,
///   `include=licenses musicinfo`), encoded as `+` as in the docs.
/// * Errors come in the body: `headers.status = failed`, `headers.code` —
///   5 invalid client id, 6 rate limit exceeded, 11 suspended application,
///   … (Response Codes page). Code 6 → [RateLimitedException].
class JamendoApi {
  JamendoApi(this._http, {required this._clientId, Uri? baseUri}) : baseUri = baseUri ?? defaultBaseUri;

  static final defaultBaseUri = Uri.parse('https://api.jamendo.com/v3.0');

  static const codeInvalidClientId = 5;
  static const codeRateLimit = 6;
  static const codeSuspended = 11;

  final FermataHttp _http;
  final String? Function() _clientId;
  final Uri baseUri;

  String? get clientId {
    final id = _clientId();
    return id == null || id.trim().isEmpty ? null : id.trim();
  }

  /// `<base>/<method>/?client_id=…&format=json&…` (null values dropped).
  Uri uri(String method, [Map<String, Object?> query = const {}]) {
    final id = clientId;
    if (id == null) throw MissingCredentialsException(SourceIds.jamendo, const ['clientId']);
    final params = <String, String>{
      'client_id': id,
      'format': 'json',
      for (final e in query.entries)
        if (e.value != null) e.key: '${e.value}',
    };
    final m = method.endsWith('/') ? method : '$method/';
    return baseUri.replace(path: '${baseUri.path}/$m', queryParameters: params);
  }

  /// GET [method] and return its `results` (errors from `headers` thrown).
  Future<JamendoResults> get(String method, {Map<String, Object?> query = const {}, CancelToken? cancel}) async {
    final target = uri(method, query);
    Object? json;
    try {
      json = await _http.getJson(target, cancel: cancel);
    } on ApiException catch (e) {
      // Error documents may also arrive with a non-2xx status.
      final body = _tryDecode(e.body);
      if (body != null) _checkHeaders(body, method);
      rethrow;
    }
    final map = asJsonMapOrNull(json);
    if (map == null) throw ApiException(200, 'Unexpected Jamendo response for $method');
    final headers = _checkHeaders(map, method);
    return JamendoResults(
      asJsonMapList(map['results']),
      count: jsonInt(headers['results_count']),
      fullCount: jsonInt(headers['results_fullcount']),
    );
  }

  static Map<String, Object?>? _tryDecode(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      return asJsonMapOrNull(jsonDecode(body));
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> _checkHeaders(Map<String, Object?> json, String method) {
    final headers = asJsonMap(json['headers']);
    final code = jsonInt(headers['code']) ?? 0;
    final status = jsonString(headers['status']);
    if (code == 0 && status != 'failed') return headers;
    final message = jsonString(headers['error_message']) ?? 'Jamendo error';
    switch (code) {
      case codeRateLimit:
        throw RateLimitedException('Jamendo rate limit exceeded: $message', retryAfter: const Duration(minutes: 1));
      case codeInvalidClientId:
        throw ApiException(401, 'Jamendo rejected the configured client id: $message');
      case codeSuspended:
        throw ApiException(403, 'Jamendo suspended this application: $message');
      default:
        throw ApiException(400, 'Jamendo $method failed (code $code): $message');
    }
  }
}
