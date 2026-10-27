import 'dart:convert';

import 'package:logging/logging.dart';

import '../../core/contracts/auth.dart';
import '../../core/errors.dart';
import '../../core/models/auth.dart';
import '../../core/net/http_client.dart';
import '../../core/util/cancel_token.dart';
import '../base/json_utils.dart';
import 'oauth_errors.dart';

final _log = Logger('sources.auth.token');

/// Talks to an OAuth 2 token endpoint (RFC 6749 §4.1.3, §6, §4.4) and
/// revocation endpoint (RFC 7009).
///
/// Used by `OAuthClientImpl`; providers may also use it directly, e.g. for
/// the client-credentials grant (SoundCloud public browsing).
///
/// Client authentication: when [OAuthConfig.clientAuthInHeader] is set and a
/// secret is configured, `Authorization: Basic base64(id:secret)`; otherwise
/// `client_id` (+ `client_secret` only when configured) as form fields.
class TokenEndpointClient {
  TokenEndpointClient(this._http, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final FermataHttp _http;
  final DateTime Function() _clock;

  /// Authorization-code exchange.
  Future<OAuthToken> exchangeCode(
    OAuthConfig config, {
    required String code,
    required String redirectUri,
    String? codeVerifier,
    CancelToken? cancel,
  }) async {
    final fields = <String, String>{
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'code_verifier': ?codeVerifier,
    };
    final json = await _post(config, config.tokenEndpoint, fields, cancel: cancel);
    return parseTokenResponse(json, config: config, requestedScopes: config.scopes, now: _clock());
  }

  /// `grant_type=refresh_token`. Keeps the previous refresh token when the
  /// provider does not rotate it (Spotify), stores the new one when it does
  /// (SoundCloud refresh tokens are single-use).
  Future<OAuthToken> refresh(OAuthConfig config, OAuthToken token, {CancelToken? cancel}) async {
    final refreshToken = token.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw OAuthFlowException(
        config.sourceId,
        OAuthFailure.tokenRequestFailed,
        'No refresh token available',
        providerError: 'invalid_grant',
      );
    }
    final fields = <String, String>{'grant_type': 'refresh_token', 'refresh_token': refreshToken};
    final json = await _post(config, config.tokenEndpoint, fields, cancel: cancel);
    return parseTokenResponse(json, config: config, previous: token, requestedScopes: token.scopes, now: _clock());
  }

  /// `grant_type=client_credentials` (app-only token for public resources).
  Future<OAuthToken> clientCredentials(OAuthConfig config, {List<String>? scopes, CancelToken? cancel}) async {
    final s = scopes ?? config.scopes;
    final fields = <String, String>{
      'grant_type': 'client_credentials',
      if (s.isNotEmpty) 'scope': s.join(config.scopeSeparator),
    };
    final json = await _post(config, config.tokenEndpoint, fields, cancel: cancel);
    return parseTokenResponse(json, config: config, requestedScopes: s, now: _clock());
  }

  /// RFC 7009 revocation. No-op when the provider has no revoke endpoint.
  /// Revokes the refresh token when present (which also invalidates access
  /// tokens at most providers), otherwise the access token.
  Future<void> revoke(OAuthConfig config, OAuthToken token, {CancelToken? cancel}) async {
    final endpoint = config.revokeEndpoint;
    if (endpoint == null) return;
    final useRefresh = token.refreshToken != null && token.refreshToken!.isNotEmpty;
    final fields = <String, String>{
      'token': useRefresh ? token.refreshToken! : token.accessToken,
      'token_type_hint': useRefresh ? 'refresh_token' : 'access_token',
    };
    await _post(config, endpoint, fields, cancel: cancel, expectJson: false);
  }

  Future<Object?> _post(
    OAuthConfig config,
    Uri endpoint,
    Map<String, String> fields, {
    CancelToken? cancel,
    bool expectJson = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final secret = config.clientSecret;
    final hasSecret = secret != null && secret.isNotEmpty;
    if (config.clientAuthInHeader && hasSecret) {
      headers['Authorization'] = 'Basic ${base64.encode(utf8.encode('${config.clientId}:$secret'))}';
    } else {
      fields['client_id'] = config.clientId;
      if (hasSecret) fields['client_secret'] = secret;
    }
    final response = await _http.send(
      'POST',
      endpoint,
      headers: headers,
      body: fields,
      retry: RetryPolicy.none,
      cancel: cancel,
    );
    final status = response.statusCode;
    Object? json;
    if (response.body.isNotEmpty) {
      try {
        json = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        json = null;
      }
    }
    if (status >= 500) {
      throw ApiException(status, 'Token endpoint ${endpoint.host} failed with HTTP $status');
    }
    final error = jsonString(asJsonMap(json)['error']);
    if (status >= 400 || error != null) {
      final description = jsonString(asJsonMap(json)['error_description']);
      // Never log the request body (codes, refresh tokens, secrets).
      _log.warning(
        'Token request to ${endpoint.host} for ${config.sourceId} failed: '
        'HTTP $status ${error ?? ''} ${description ?? ''}',
      );
      throw OAuthFlowException(
        config.sourceId,
        OAuthFailure.tokenRequestFailed,
        'Token request rejected (HTTP $status${error == null ? '' : ', $error'}${description == null ? '' : ': $description'})',
        providerError: error ?? (status == 400 || status == 401 ? 'invalid_grant' : null),
      );
    }
    if (expectJson && json is! Map) {
      throw OAuthFlowException(
        config.sourceId,
        OAuthFailure.tokenRequestFailed,
        'Token endpoint ${endpoint.host} did not return JSON',
      );
    }
    return json;
  }

  /// Parses a token response (`access_token`, `token_type`, `expires_in`,
  /// `refresh_token`, `scope`). Exposed for tests and custom grants.
  static OAuthToken parseTokenResponse(
    Object? json, {
    required OAuthConfig config,
    OAuthToken? previous,
    List<String> requestedScopes = const [],
    DateTime? now,
  }) {
    final map = asJsonMap(json);
    final access = jsonString(map['access_token']);
    if (access == null) {
      throw OAuthFlowException(config.sourceId, OAuthFailure.tokenRequestFailed, 'Token response has no access_token');
    }
    final expiresIn = jsonInt(map['expires_in']);
    final scopeRaw = jsonString(map['scope']);
    final scopes = scopeRaw == null
        ? (previous?.scopes.isNotEmpty == true ? previous!.scopes : requestedScopes)
        : scopeRaw.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
    final type = jsonString(map['token_type']);
    return OAuthToken(
      accessToken: access,
      refreshToken: jsonString(map['refresh_token']) ?? previous?.refreshToken,
      expiresAt: expiresIn == null ? null : (now ?? DateTime.now()).add(Duration(seconds: expiresIn)),
      scopes: List.unmodifiable(scopes),
      tokenType: type == null || type.toLowerCase() == 'bearer' ? 'Bearer' : type,
    );
  }
}
