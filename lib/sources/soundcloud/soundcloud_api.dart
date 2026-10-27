import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../core/errors.dart';
import '../../core/models/auth.dart';
import '../../core/net/http_client.dart';
import '../../core/sources/source_ids.dart';
import '../../core/util/cancel_token.dart';
import '../auth/oauth_errors.dart';
import '../auth/oauth_session.dart';
import '../base/json_utils.dart';
import '../base/paging.dart';
import 'soundcloud_app_token.dart';
import 'soundcloud_rate_limits.dart';

final _log = Logger('sources.soundcloud.api');

/// One page of a `linked_partitioning` collection.
class SoundCloudCollection {
  const SoundCloudCollection(this.items, this.nextHref);

  final List<Map<String, Object?>> items;

  /// The API's `next_href` (null on the last page).
  final String? nextHref;

  /// [nextHref] as an opaque [PageCursor] token.
  String? get nextCursor => nextHref == null ? null : PageCursor.encodeToken(nextHref!);
}

/// A playable location for a SoundCloud stream URL.
class SoundCloudSignedStream {
  const SoundCloudSignedStream(this.uri, {this.headers = const {}, this.expiresAt});

  final Uri uri;

  /// Non-empty only when the URL itself needs the `Authorization` header
  /// (SoundCloud answered 200 instead of redirecting to a signed CDN URL).
  final Map<String, String> headers;
  final DateTime? expiresAt;
}

/// Request layer for `https://api.soundcloud.com` (all calls via
/// [FermataHttp]).
///
/// * **Auth**: every request carries `Authorization: OAuth <token>` — the
///   user's token when an account is connected (refresh + one retry on 401 via
///   [OAuthSession]), otherwise the app token from the client-credentials
///   grant ([SoundCloudAppTokens]). User-only endpoints (`/me/…`) throw
///   [AuthRequiredException] when no account is connected.
/// * **No credentials → no request**: [MissingCredentialsException] first.
/// * **Rate limits**: [SoundCloudRateGate] blocks groups after 429s.
/// * **Redirects**: `/resolve` answers 302 to the API resource; the location
///   (header or JSON body) is followed with the same authorization, only to
///   `*.soundcloud.com`.
class SoundCloudApi {
  SoundCloudApi({
    required this._http,
    required this._session,
    required SoundCloudAppTokens appTokens,
    required this._gate,
    Uri? baseUri,
    DateTime Function()? clock,
  }) : _app = appTokens,
       baseUri = baseUri ?? defaultBaseUri,
       _clock = clock ?? DateTime.now;

  static final defaultBaseUri = Uri.parse('https://api.soundcloud.com');

  final FermataHttp _http;
  final OAuthSession _session;
  final SoundCloudAppTokens _app;
  final SoundCloudRateGate _gate;
  final DateTime Function() _clock;
  final Uri baseUri;

  static const _maxRedirects = 3;

  /// Whether requests are made with the user's token.
  bool get userConnected => _session.state.isConnected;

  /// `<base>/<path>?<query>`; iterable values are joined with commas (the
  /// API's `style: form, explode: false` arrays, e.g. `access`).
  Uri uri(String path, [Map<String, Object?> query = const {}]) {
    final params = <String, String>{
      for (final e in query.entries)
        if (e.value != null) e.key: e.value is Iterable ? (e.value as Iterable).join(',') : '${e.value}',
    };
    final base = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
    final rel = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.replace(path: '$base/$rel', queryParameters: params.isEmpty ? null : params);
  }

  /// Path segment for a URN (`:` is a valid path character, as in the
  /// documented `/tracks/soundcloud:tracks:123`).
  static String seg(String urn) => Uri.encodeComponent(urn).replaceAll('%3A', ':');

  // ---- JSON requests ------------------------------------------------------------

  /// Authorized GET → decoded JSON. Throws [ApiException] for non-2xx.
  Future<Object?> getJson(
    Uri uri, {
    bool requireUser = false,
    SoundCloudRateGroup group = SoundCloudRateGroup.general,
    CancelToken? cancel,
  }) async {
    final response = await send('GET', uri, requireUser: requireUser, group: group, cancel: cancel);
    return FermataHttp.decodeJsonResponse(response);
  }

  /// Like [getJson] but null for 404 (deleted / unknown resource).
  Future<Object?> getJsonOrNull(
    Uri uri, {
    bool requireUser = false,
    SoundCloudRateGroup group = SoundCloudRateGroup.general,
    CancelToken? cancel,
  }) async {
    try {
      return await getJson(uri, requireUser: requireUser, group: group, cancel: cancel);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// A `linked_partitioning` page: [first] for the first page, otherwise the
  /// `next_href` stored in [cursor] (validated to stay on the API host).
  Future<SoundCloudCollection> collection(
    Uri first, {
    String? cursor,
    bool requireUser = false,
    SoundCloudRateGroup group = SoundCloudRateGroup.general,
    CancelToken? cancel,
  }) async {
    final target = cursor == null ? first : nextPageUri(cursor);
    final json = await getJson(target, requireUser: requireUser, group: group, cancel: cancel);
    final map = asJsonMapOrNull(json);
    final items = map == null ? asJsonMapList(json) : asJsonMapList(map['collection']);
    final next = map == null ? null : jsonString(map['next_href']);
    return SoundCloudCollection(items, items.isEmpty ? null : next);
  }

  /// The `next_href` inside a cursor. Throws [FormatException] for cursors
  /// that do not point at the API host (never send tokens elsewhere).
  Uri nextPageUri(String cursor) {
    final token = PageCursor.decodeToken(cursor);
    final next = token == null ? null : Uri.tryParse(token);
    if (next == null || next.host != baseUri.host || next.scheme != baseUri.scheme) {
      throw FormatException('Invalid SoundCloud page cursor', cursor);
    }
    return next;
  }

  /// `GET /resolve?url=` → the resolved API resource (track, playlist, user).
  /// Null when SoundCloud does not know the URL (404).
  Future<Map<String, Object?>?> resolve(Uri shareUrl, {CancelToken? cancel}) async {
    final json = await getJsonOrNull(uri('resolve', {'url': shareUrl.toString()}), cancel: cancel);
    return asJsonMapOrNull(json);
  }

  // ---- Sending ------------------------------------------------------------------

  /// Authorized request with redirect following and rate-limit bookkeeping.
  Future<http.Response> send(
    String method,
    Uri uri, {
    bool requireUser = false,
    SoundCloudRateGroup group = SoundCloudRateGroup.general,
    CancelToken? cancel,
  }) async {
    _session.requireCredentials();
    _gate.check(group);
    if (group == SoundCloudRateGroup.streams) _gate.recordStream();
    // Play requests count against a daily budget: never retry them blindly.
    final retry = group == SoundCloudRateGroup.streams ? RetryPolicy.none : const RetryPolicy();
    var target = uri;
    try {
      for (var hop = 0; ; hop++) {
        final response = await _authorized(method, target, requireUser: requireUser, retry: retry, cancel: cancel);
        _gate.onHeaders(group, response.headers);
        final next = _redirectTarget(response, target);
        if (next == null || hop >= _maxRedirects) return response;
        target = next;
      }
    } on RateLimitedException catch (e) {
      _gate.onRateLimited(group, e.retryAfter);
      rethrow;
    }
  }

  /// Location of a 3xx response (header, or the `Found` JSON body), only when
  /// it stays on a SoundCloud host.
  Uri? _redirectTarget(http.Response response, Uri from) {
    final status = response.statusCode;
    if (status < 300 || status >= 400) return null;
    var location = response.headers['location'];
    if (location == null || location.isEmpty) {
      try {
        location = jsonString(asJsonMap(jsonDecode(response.body))['location']);
      } on FormatException {
        location = null;
      }
    }
    if (location == null) return null;
    final target = from.resolve(location);
    final allowed = target.host == baseUri.host || (isSoundCloudHost(target) && target.isScheme('https'));
    if (!allowed) {
      _log.warning('Not following SoundCloud redirect to ${target.host}');
      return null;
    }
    return target;
  }

  static bool isSoundCloudHost(Uri uri) {
    final h = uri.host.toLowerCase();
    return h == 'soundcloud.com' || h.endsWith('.soundcloud.com');
  }

  Future<http.Response> _authorized(
    String method,
    Uri uri, {
    required bool requireUser,
    required RetryPolicy retry,
    CancelToken? cancel,
  }) async {
    if (requireUser && !userConnected) {
      throw AuthRequiredException(SourceIds.soundcloud, 'Connect your SoundCloud account to use your library.');
    }
    if (userConnected) {
      try {
        return await _session.authorizedSend(method, uri, headers: _accept, retry: retry, cancel: cancel);
      } on AuthRequiredException {
        if (requireUser) rethrow;
        _log.fine('SoundCloud user session unusable; using the app token for a public request');
      }
    }
    var token = await _appToken(cancel: cancel);
    var response = await _http.send(method, uri, headers: _appHeaders(token), retry: retry, cancel: cancel);
    if (response.statusCode != 401) return response;
    token = await _appToken(rejected: token, cancel: cancel);
    response = await _http.send(method, uri, headers: _appHeaders(token), retry: retry, cancel: cancel);
    if (response.statusCode == 401) {
      throw ApiException(401, 'SoundCloud rejected the app token. Check the configured client id and secret.');
    }
    return response;
  }

  static const _accept = {'Accept': 'application/json; charset=utf-8'};

  Map<String, String> _appHeaders(OAuthToken token) => {..._accept, 'Authorization': 'OAuth ${token.accessToken}'};

  Future<OAuthToken> _appToken({OAuthToken? rejected, CancelToken? cancel}) async {
    try {
      return rejected == null ? await _app.token(cancel: cancel) : await _app.renew(rejected, cancel: cancel);
    } on OAuthFlowException catch (e) {
      // Not a user-session problem: the app credentials were refused.
      throw ApiException(401, 'SoundCloud did not issue an app token (${e.message}). Check the client id and secret.');
    }
  }

  // ---- Stream URLs -------------------------------------------------------------

  /// Resolves an authenticated stream URL from `/tracks/{urn}/streams`
  /// (e.g. `hls_aac_160_url`) to a playable location. SoundCloud answers an
  /// authorized request with 302 to a signed CDN URL that needs no token;
  /// that location is returned. If it answers 200 instead, the API URL is
  /// returned with the `Authorization` header the player must send.
  Future<SoundCloudSignedStream> signStream(Uri streamUrl, {CancelToken? cancel}) async {
    _session.requireCredentials();
    // Only the `/streams` call counts against the play budget.
    _gate.check(SoundCloudRateGroup.streams, budget: false);
    if (!isSoundCloudHost(streamUrl) || !streamUrl.isScheme('https')) {
      throw ApiException(502, 'Unexpected SoundCloud stream host ${streamUrl.host}');
    }
    _Ticket? rejected;
    for (var attempt = 0; attempt < 2; attempt++) {
      final ticket = await _ticket(rejected: rejected, cancel: cancel);
      final response = await _sendWithoutRedirect(streamUrl, ticket.headers, cancel);
      final status = response.statusCode;
      final location = response.headers['location'];
      if (status >= 300 && status < 400 && location != null && location.isNotEmpty) {
        unawaited(response.stream.drain<void>().catchError((Object _) {}));
        final signed = streamUrl.resolve(location);
        return SoundCloudSignedStream(signed, expiresAt: signedUrlExpiry(signed));
      }
      // Bodies of the remaining cases are irrelevant (or a large playlist).
      unawaited(response.stream.listen(null, onError: (Object _) {}).cancel());
      if (status >= 200 && status < 300) {
        return SoundCloudSignedStream(streamUrl, headers: ticket.headers, expiresAt: ticket.token.expiresAt);
      }
      if (status == 401 && attempt == 0) {
        rejected = ticket;
        continue;
      }
      if (status == 401) {
        if (ticket.user) throw AuthRequiredException(SourceIds.soundcloud, 'The SoundCloud session expired. Please reconnect.');
        throw ApiException(401, 'SoundCloud rejected the app token for streaming.');
      }
      if (status == 429) {
        final retryAfter = parseRetryAfter(response.headers['retry-after']);
        _gate.onRateLimited(SoundCloudRateGroup.streams, retryAfter);
        throw RateLimitedException('SoundCloud stream rate limit reached', retryAfter: retryAfter);
      }
      throw ApiException(status, 'HTTP $status for a SoundCloud stream URL');
    }
    throw ApiException(401, 'SoundCloud stream authorization failed');
  }

  Future<_Ticket> _ticket({_Ticket? rejected, CancelToken? cancel}) async {
    if (userConnected && (rejected == null || rejected.user)) {
      try {
        final token = rejected == null
            ? await _session.validToken(cancel: cancel)
            : await _session.forceRefresh(cancel: cancel);
        return _Ticket(_session.authHeaders(token), token, user: true);
      } on AuthRequiredException {
        if (rejected != null) rethrow;
        _log.fine('SoundCloud user session unusable; streaming with the app token');
      }
    }
    final token = await _appToken(rejected: rejected?.user == false ? rejected!.token : null, cancel: cancel);
    return _Ticket(_appHeaders(token), token, user: false);
  }

  Future<http.StreamedResponse> _sendWithoutRedirect(Uri url, Map<String, String> headers, CancelToken? cancel) async {
    cancel?.throwIfCanceled();
    final request = http.Request('GET', url)
      ..followRedirects = false
      ..headers['User-Agent'] = _http.userAgent
      ..headers.addAll(headers);
    try {
      final future = _http.raw.send(request).timeout(_http.timeout);
      return cancel == null
          ? await future
          : await Future.any([
              future,
              cancel.whenCanceled.then<http.StreamedResponse>((_) => throw const OperationCanceledException()),
            ]);
    } on TimeoutException catch (e) {
      throw NetworkException('SoundCloud stream request timed out', cause: e, isTimeout: true);
    } on SocketException catch (e) {
      throw NetworkException('Network error contacting SoundCloud', cause: e);
    } on http.ClientException catch (e) {
      throw NetworkException('Network error contacting SoundCloud', cause: e);
    }
  }

  /// Expiry of a signed CDN URL (`Expires=<unix seconds>`), when present.
  static DateTime? signedUrlExpiry(Uri url) {
    for (final e in url.queryParameters.entries) {
      if (e.key.toLowerCase() == 'expires') {
        final seconds = int.tryParse(e.value);
        if (seconds != null && seconds > 0) {
          return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
        }
      }
    }
    return null;
  }

  /// `Retry-After` in seconds or as an HTTP date.
  Duration? parseRetryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) return Duration(seconds: seconds);
    try {
      final d = HttpDate.parse(value).difference(_clock());
      return d.isNegative ? Duration.zero : d;
    } catch (_) {
      return null;
    }
  }

  /// `POST /disconnect` (204): revokes this app's tokens for the user. Used
  /// as the session's remote revoker.
  static Future<void> revokeRemotely(OAuthSession session, OAuthToken token, {Uri? baseUri}) async {
    final base = baseUri ?? defaultBaseUri;
    final response = await session.http.send(
      'POST',
      base.replace(path: '${base.path.endsWith('/') ? base.path : '${base.path}/'}disconnect'),
      headers: {'Accept': 'application/json; charset=utf-8', ...session.authHeaders(token)},
      retry: RetryPolicy.none,
    );
    if (response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'SoundCloud disconnect failed (HTTP ${response.statusCode})');
    }
  }
}

class _Ticket {
  const _Ticket(this.headers, this.token, {required this.user});

  final Map<String, String> headers;
  final OAuthToken token;
  final bool user;
}
