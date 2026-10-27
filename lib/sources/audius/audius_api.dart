import '../../core/errors.dart';
import '../../core/net/http_client.dart';
import '../../core/util/cancel_token.dart';
import '../base/json_utils.dart';

/// Thin request builder for the public Audius REST API
/// (`https://api.audius.co/v1`, verified 2026-10-27 against
/// `https://api.audius.co/v1/swagger.yaml` and audius.co/agents.md).
///
/// * Read endpoints work without credentials. An optional API key
///   (`x-api-key` header) raises rate limits and is required for tracks
///   restricted to specific API keys (stream `api_key` query parameter).
/// * `app_name=Fermata` is sent on every request (optional today, kept for
///   attribution). No host discovery is needed: `GET https://api.audius.co`
///   lists only `https://api.audius.co` and the docs say to always use it.
class AudiusApi {
  AudiusApi(this._http, {String? Function()? apiKey, Uri? baseUri, this.appName = 'Fermata'})
    : _apiKey = apiKey ?? (() => null),
      baseUri = baseUri ?? Uri.parse('https://api.audius.co/v1');

  final FermataHttp _http;
  final String? Function() _apiKey;
  final Uri baseUri;
  final String appName;

  String? get apiKey {
    final k = _apiKey();
    return k == null || k.trim().isEmpty ? null : k.trim();
  }

  /// Builds `<base>/<path>?<query>&app_name=…`. List values become repeated
  /// parameters (`id=a&id=b`), as the API expects.
  Uri uri(String path, [Map<String, Object?> query = const {}]) {
    final params = <String, dynamic>{};
    query.forEach((k, v) {
      if (v == null) return;
      params[k] = v is Iterable ? [for (final e in v) '$e'] : '$v';
    });
    params['app_name'] = appName;
    final base = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
    return baseUri.replace(path: '$base/${path.startsWith('/') ? path.substring(1) : path}', queryParameters: params);
  }

  Map<String, String> get _headers => {'x-api-key': ?apiKey};

  /// GET returning the `data` member of the response envelope.
  Future<Object?> getData(String path, {Map<String, Object?> query = const {}, CancelToken? cancel}) async {
    final json = await _http.getJson(uri(path, query), headers: _headers, cancel: cancel);
    final map = asJsonMapOrNull(json);
    if (map == null || !map.containsKey('data')) {
      throw ApiException(200, 'Unexpected Audius response for $path');
    }
    return map['data'];
  }

  /// Like [getData] but returns null for "not found" (Audius answers 404,
  /// and 400 "invalid id" for malformed ids).
  Future<Object?> getDataOrNull(String path, {Map<String, Object?> query = const {}, CancelToken? cancel}) async {
    try {
      return await getData(path, query: query, cancel: cancel);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 400) return null;
      rethrow;
    }
  }

  /// Stream endpoint; the player follows the 302 to a content node.
  Uri streamUri(String trackId, {bool preview = false}) =>
      uri('tracks/$trackId/stream', {if (preview) 'preview': 'true', 'api_key': apiKey});

  /// Official download endpoint (302 to the original or MP3 file; 403 for
  /// download-gated tracks).
  Uri downloadUri(String trackId) => uri('tracks/$trackId/download');

  /// Headers the downloader should send with [downloadUri] (the optional,
  /// non-secret read API key).
  Map<String, String> get downloadHeaders => _headers;
}
