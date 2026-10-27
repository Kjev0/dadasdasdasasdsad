import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../errors.dart';
import '../util/cancel_token.dart';

final _log = Logger('net');

/// Retry policy for idempotent requests.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 400),
    this.maxDelay = const Duration(seconds: 8),
  });

  static const none = RetryPolicy(maxAttempts: 1);

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  Duration delayFor(int attempt) {
    final ms = baseDelay.inMilliseconds * pow(2, attempt - 1);
    final jitter = Random().nextInt(150);
    return Duration(milliseconds: min(ms.toInt() + jitter, maxDelay.inMilliseconds));
  }
}

/// Thin wrapper around `package:http` adding timeouts, retries with
/// exponential backoff (429 honours `Retry-After`), cancellation, a
/// consistent User-Agent and typed errors.
///
/// All network access in Fermata goes through this class so that network
/// behaviour is documented in one place (see docs/NETWORK.md).
class FermataHttp {
  FermataHttp({http.Client? client, this.userAgent = defaultUserAgent, this.timeout = const Duration(seconds: 20)})
      : _client = client ?? http.Client();

  static const defaultUserAgent = 'Fermata/1.0 (+https://github.com/kjev0/dadasdasdasasdsad)';

  final http.Client _client;
  final String userAgent;
  final Duration timeout;

  http.Client get raw => _client;

  Future<http.Response> send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    RetryPolicy retry = const RetryPolicy(),
    CancelToken? cancel,
    Duration? timeout,
  }) async {
    final idempotent = method == 'GET' || method == 'HEAD';
    final attempts = idempotent ? retry.maxAttempts : 1;
    Object? lastError;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      cancel?.throwIfCanceled();
      try {
        final request = http.Request(method, uri)
          ..headers['User-Agent'] = userAgent
          ..headers.addAll(headers ?? const {});
        if (encoding != null) request.encoding = encoding;
        if (body is String) {
          request.body = body;
        } else if (body is List<int>) {
          request.bodyBytes = body;
        } else if (body is Map<String, String>) {
          request.bodyFields = body;
        } else if (body != null) {
          throw ArgumentError('Unsupported body type ${body.runtimeType}');
        }
        final future = _client.send(request).then(http.Response.fromStream).timeout(timeout ?? this.timeout);
        final response = cancel == null
            ? await future
            : await Future.any([
                future,
                cancel.whenCanceled.then<http.Response>((_) => throw const OperationCanceledException()),
              ]);
        if (response.statusCode == 429) {
          final retryAfter = _parseRetryAfter(response.headers['retry-after']);
          if (attempt < attempts && (retryAfter == null || retryAfter <= retry.maxDelay)) {
            await Future<void>.delayed(retryAfter ?? retry.delayFor(attempt));
            continue;
          }
          throw RateLimitedException('Rate limited by ${uri.host}', retryAfter: retryAfter);
        }
        if (response.statusCode >= 500 && attempt < attempts) {
          _log.fine('HTTP ${response.statusCode} from ${uri.host}, retrying ($attempt/$attempts)');
          await Future<void>.delayed(retry.delayFor(attempt));
          continue;
        }
        return response;
      } on OperationCanceledException {
        rethrow;
      } on FermataException {
        rethrow;
      } on TimeoutException catch (e) {
        lastError = NetworkException('Request to ${uri.host} timed out', cause: e, isTimeout: true);
      } on SocketException catch (e) {
        lastError = NetworkException('Network error contacting ${uri.host}', cause: e);
      } on http.ClientException catch (e) {
        lastError = NetworkException('Network error contacting ${uri.host}', cause: e);
      } on HandshakeException catch (e) {
        lastError = NetworkException('TLS error contacting ${uri.host}', cause: e);
      }
      if (attempt < attempts) {
        await Future<void>.delayed(retry.delayFor(attempt));
      }
    }
    throw lastError ?? NetworkException('Request to ${uri.host} failed');
  }

  Future<http.Response> get(Uri uri, {Map<String, String>? headers, RetryPolicy retry = const RetryPolicy(), CancelToken? cancel}) =>
      send('GET', uri, headers: headers, retry: retry, cancel: cancel);

  /// GET and decode JSON. Throws [ApiException] for non-2xx responses and
  /// [AuthRequiredException]-friendly 401s are surfaced as [ApiException]
  /// with statusCode 401 so callers can map them to their source.
  Future<Object?> getJson(Uri uri, {Map<String, String>? headers, RetryPolicy retry = const RetryPolicy(), CancelToken? cancel}) async {
    final response = await get(uri, headers: {'Accept': 'application/json', ...?headers}, retry: retry, cancel: cancel);
    return decodeJsonResponse(response);
  }

  Future<Object?> postForm(Uri uri, Map<String, String> fields, {Map<String, String>? headers, CancelToken? cancel}) async {
    final response = await send('POST', uri,
        headers: {'Accept': 'application/json', ...?headers}, body: fields, retry: RetryPolicy.none, cancel: cancel);
    return decodeJsonResponse(response);
  }

  static Object? decodeJsonResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'HTTP ${response.statusCode} from ${response.request?.url.host}',
          body: response.body.length > 2000 ? response.body.substring(0, 2000) : response.body);
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      throw ApiException(response.statusCode, 'Invalid JSON from ${response.request?.url.host}', cause: e);
    }
  }

  static Duration? _parseRetryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) return Duration(seconds: seconds);
    try {
      final date = HttpDate.parse(value);
      final d = date.difference(DateTime.now());
      return d.isNegative ? Duration.zero : d;
    } catch (_) {
      return null;
    }
  }

  void close() => _client.close();
}
