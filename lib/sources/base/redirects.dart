import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors.dart';
import '../../core/net/http_client.dart';
import '../../core/util/cancel_token.dart';

/// Resolves share/short links (e.g. `link.deezer.com/s/…`) to their final
/// URL by following `Location` headers manually.
///
/// `FermataHttp.send` follows redirects transparently but does not expose
/// the final URL, so this helper uses the same underlying client
/// (`FermataHttp.raw`, same User-Agent) with redirects disabled, plus a
/// per-hop timeout and cancellation. Only GET is used; bodies are drained.
Future<Uri> resolveRedirects(
  FermataHttp http0,
  Uri uri, {
  int maxHops = 6,
  CancelToken? cancel,
  Duration timeout = const Duration(seconds: 15),
}) async {
  var current = uri;
  for (var hop = 0; hop <= maxHops; hop++) {
    cancel?.throwIfCanceled();
    final request = http.Request('GET', current)
      ..followRedirects = false
      ..headers['User-Agent'] = http0.userAgent;
    final http.StreamedResponse response;
    try {
      final future = http0.raw.send(request).timeout(timeout);
      response = cancel == null
          ? await future
          : await Future.any([
              future,
              cancel.whenCanceled.then<http.StreamedResponse>((_) => throw const OperationCanceledException()),
            ]);
    } on TimeoutException catch (e) {
      throw NetworkException('Resolving ${current.host} timed out', cause: e, isTimeout: true);
    } on SocketException catch (e) {
      throw NetworkException('Network error resolving ${current.host}', cause: e);
    } on http.ClientException catch (e) {
      throw NetworkException('Network error resolving ${current.host}', cause: e);
    }
    final status = response.statusCode;
    final location = response.headers['location'];
    if (status >= 300 && status < 400 && location != null && location.isNotEmpty) {
      // Redirect bodies are tiny: drain so the connection can be reused.
      unawaited(response.stream.drain<void>().catchError((Object _) {}));
      current = current.resolve(location);
      continue;
    }
    // The final page may be a large HTML document; we only need its URL.
    unawaited(response.stream.listen(null, onError: (Object _) {}).cancel());
    if (status >= 400) {
      throw ApiException(status, 'HTTP $status while resolving ${current.host}');
    }
    return current;
  }
  throw ApiException(310, 'Too many redirects resolving ${uri.host}');
}
