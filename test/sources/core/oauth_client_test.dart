import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fermata/core/contracts/auth.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/net/http_client.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/sources/auth/oauth_client_impl.dart';
import 'package:fermata/sources/auth/oauth_errors.dart';
import 'package:fermata/sources/auth/pkce.dart';
import 'package:fermata/sources/auth/token_endpoint_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A local OAuth token endpoint (real HTTP server).
class _TokenServer {
  late HttpServer server;
  final List<Map<String, String>> forms = [];
  final List<String?> authHeaders = [];
  final List<String> paths = [];
  int status = 200;
  Map<String, Object?> response = {
    'access_token': 'at-1',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'rt-1',
    'scope': 'read write',
  };

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body = await utf8.decoder.bind(req).join();
      paths.add(req.uri.path);
      forms.add(Uri.splitQueryString(body));
      authHeaders.add(req.headers.value('authorization'));
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(response));
      await req.response.close();
    });
  }

  Uri get tokenUri => Uri.parse('http://127.0.0.1:${server.port}/token');
  Uri get revokeUri => Uri.parse('http://127.0.0.1:${server.port}/revoke');

  Future<void> stop() => server.close(force: true);
}

/// Simulates the provider's login page: reads the authorize URL and calls
/// the redirect URI like a browser would.
class _FakeBrowser {
  _FakeBrowser({this.stateOverride, this.error, this.act = true});

  final String? stateOverride;
  final String? error;
  final bool act;
  final List<Uri> opened = [];
  final Completer<(int, String)> page = Completer();

  Future<void> launch(Uri url) async {
    opened.add(url);
    if (!act) return;
    final redirect = Uri.parse(url.queryParameters['redirect_uri']!);
    final params = <String, String>{
      'state': stateOverride ?? url.queryParameters['state']!,
      if (error == null) 'code': 'auth-code-123',
      'error': ?error,
    };
    final callback = redirect.replace(queryParameters: params);
    unawaited(
      Future(() async {
        final client = HttpClient();
        try {
          // A browser would also ask for a favicon; it must not break the flow.
          final fav = await client.getUrl(redirect.replace(path: '/favicon.ico', queryParameters: {}));
          await (await fav.close()).drain<void>();
          final req = await client.getUrl(callback);
          final res = await req.close();
          page.complete((res.statusCode, await utf8.decoder.bind(res).join()));
        } catch (e) {
          if (!page.isCompleted) page.completeError(e);
        } finally {
          client.close(force: true);
        }
      }),
    );
  }
}

OAuthConfig _config(
  _TokenServer t, {
  int port = 0,
  String? secret,
  bool header = false,
  RedirectStrategy? strategy,
  String? override,
  Uri? revoke,
}) => OAuthConfig(
  sourceId: 'test',
  authorizeEndpoint: Uri.parse('https://provider.example/authorize?display=popup'),
  tokenEndpoint: t.tokenUri,
  revokeEndpoint: revoke,
  clientId: 'client-abc',
  clientSecret: secret,
  clientAuthInHeader: header,
  scopes: const ['read', 'write'],
  extraAuthorizeParams: const {'prompt': 'consent'},
  loopbackPort: port,
  redirectStrategy: strategy,
  redirectUriOverride: override,
);

Future<bool> _portOpen(int port) async {
  try {
    final s = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: const Duration(milliseconds: 300));
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  late _TokenServer tokens;
  late FermataHttp fhttp;

  setUp(() async {
    tokens = _TokenServer();
    await tokens.start();
    fhttp = FermataHttp();
  });

  tearDown(() async {
    fhttp.close();
    await tokens.stop();
  });

  OAuthClientImpl client(_FakeBrowser browser, {HostOs os = HostOs.linux, Duration? timeout, Stream<Uri>? links}) =>
      OAuthClientImpl(
        http: fhttp,
        platform: PlatformInfo(os: os),
        launcher: browser.launch,
        deepLinks: links == null ? null : () => links,
        timeout: timeout ?? const Duration(seconds: 10),
      );

  group('loopback flow (desktop)', () {
    test('end to end: authorize URL, callback page, PKCE code exchange, server closed', () async {
      final browser = _FakeBrowser();
      final token = await client(browser).authorize(_config(tokens));

      final url = browser.opened.single;
      final q = url.queryParameters;
      expect(url.host, 'provider.example');
      expect(q['display'], 'popup', reason: 'existing endpoint parameters are kept');
      expect(q['response_type'], 'code');
      expect(q['client_id'], 'client-abc');
      expect(q['scope'], 'read write');
      expect(q['prompt'], 'consent');
      expect(q['code_challenge_method'], 'S256');
      expect(q['state']!.length, greaterThanOrEqualTo(43));
      final redirect = Uri.parse(q['redirect_uri']!);
      expect(redirect.host, '127.0.0.1');
      expect(redirect.path, '/callback/test');

      final (status, html) = await browser.page.future;
      expect(status, 200);
      expect(html, contains('You can close this tab'));
      expect(html, contains('Du kan lukke denne fane'));
      expect(html, isNot(contains('<script')));
      expect(html, isNot(contains('http')), reason: 'no external assets');

      final form = tokens.forms.single;
      expect(form['grant_type'], 'authorization_code');
      expect(form['code'], 'auth-code-123');
      expect(form['redirect_uri'], q['redirect_uri']);
      expect(form['client_id'], 'client-abc');
      expect(form.containsKey('client_secret'), isFalse, reason: 'no secret configured');
      expect(PkcePair.challengeFor(form['code_verifier']!), q['code_challenge']);
      expect(form['code_verifier']!.length, 86);
      expect(tokens.authHeaders.single, isNull);

      expect(token.accessToken, 'at-1');
      expect(token.refreshToken, 'rt-1');
      expect(token.tokenType, 'Bearer');
      expect(token.scopes, ['read', 'write']);
      expect(token.expiresAt!.difference(DateTime.now()).inMinutes, inInclusiveRange(58, 60));

      expect(await _portOpen(redirect.port), isFalse, reason: 'loopback server must be closed');
    });

    test('fixed port is used and announced exactly', () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      final c = client(_FakeBrowser());
      final config = _config(tokens, port: port);
      expect(c.redirectUriFor(config), 'http://127.0.0.1:$port/callback/test');
      await c.authorize(config);
      expect(tokens.forms.single['redirect_uri'], 'http://127.0.0.1:$port/callback/test');
    });

    test('client secret goes into the form, or HTTP Basic with clientAuthInHeader', () async {
      await client(_FakeBrowser()).authorize(_config(tokens, secret: 's3cret'));
      expect(tokens.forms.last['client_secret'], 's3cret');
      expect(tokens.forms.last['client_id'], 'client-abc');

      await client(_FakeBrowser()).authorize(_config(tokens, secret: 's3cret', header: true));
      expect(tokens.authHeaders.last, 'Basic ${base64.encode(utf8.encode('client-abc:s3cret'))}');
      expect(tokens.forms.last.containsKey('client_secret'), isFalse);
      expect(tokens.forms.last.containsKey('client_id'), isFalse);
    });

    test('state mismatch is rejected and the code is never exchanged', () async {
      final browser = _FakeBrowser(stateOverride: 'forged');
      await expectLater(
        client(browser).authorize(_config(tokens)),
        throwsA(isA<OAuthFlowException>().having((e) => e.failure, 'failure', OAuthFailure.stateMismatch)),
      );
      final (status, html) = await browser.page.future;
      expect(status, 400);
      expect(html, contains('Could not connect'));
      expect(tokens.forms, isEmpty);
    });

    test('access_denied from the provider', () async {
      final browser = _FakeBrowser(error: 'access_denied');
      await expectLater(
        client(browser).authorize(_config(tokens)),
        throwsA(
          isA<OAuthFlowException>()
              .having((e) => e.failure, 'failure', OAuthFailure.accessDenied)
              .having((e) => e.code, 'code', 'auth_required'),
        ),
      );
      expect(tokens.forms, isEmpty);
    });

    test('times out and closes the server', () async {
      final browser = _FakeBrowser(act: false);
      final c = client(browser, timeout: const Duration(milliseconds: 300));
      await expectLater(
        c.authorize(_config(tokens)),
        throwsA(isA<OAuthFlowException>().having((e) => e.failure, 'failure', OAuthFailure.timeout)),
      );
      final port = Uri.parse(browser.opened.single.queryParameters['redirect_uri']!).port;
      expect(await _portOpen(port), isFalse);
    });

    test('cancel via CancelToken and via cancelPending', () async {
      final browser = _FakeBrowser(act: false);
      final c = client(browser);
      final cancel = CancelToken();
      final f = c.authorizeWithCancel(_config(tokens), cancel: cancel);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      cancel.cancel();
      await expectLater(f, throwsA(isA<OAuthFlowException>().having((e) => e.failure, 'f', OAuthFailure.cancelled)));
      final port = Uri.parse(browser.opened.single.queryParameters['redirect_uri']!).port;
      expect(await _portOpen(port), isFalse);

      final f2 = c.authorize(_config(tokens));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      c.cancelPending();
      await expectLater(f2, throwsA(isA<OAuthFlowException>().having((e) => e.failure, 'f', OAuthFailure.cancelled)));
    });

    test('port in use gives a clear error', () async {
      final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(blocker.close);
      final browser = _FakeBrowser();
      await expectLater(
        client(browser).authorize(_config(tokens, port: blocker.port)),
        throwsA(
          isA<OAuthFlowException>()
              .having((e) => e.failure, 'failure', OAuthFailure.portInUse)
              .having((e) => e.message, 'message', contains('${blocker.port}')),
        ),
      );
      expect(browser.opened, isEmpty, reason: 'browser is not opened when the port is busy');
    });

    test('browser launch failure', () async {
      final c = OAuthClientImpl(
        http: fhttp,
        platform: const PlatformInfo(os: HostOs.linux),
        launcher: (_) async => throw StateError('none'),
      );
      await expectLater(
        c.authorize(_config(tokens)),
        throwsA(isA<OAuthFlowException>().having((e) => e.failure, 'f', OAuthFailure.browserUnavailable)),
      );
    });

    test('loopback redirectUriOverride without port binds an ephemeral port (Spotify style)', () async {
      final browser = _FakeBrowser();
      await client(browser).authorize(_config(tokens, override: 'http://127.0.0.1/callback/spotify'));
      final announced = Uri.parse(browser.opened.single.queryParameters['redirect_uri']!);
      expect(announced.path, '/callback/spotify');
      expect(announced.port, isNot(80));
      expect(tokens.forms.single['redirect_uri'], announced.toString());
    });

    test('token endpoint rejection becomes tokenRequestFailed', () async {
      tokens
        ..status = 400
        ..response = {'error': 'invalid_client', 'error_description': 'bad client'};
      final browser = _FakeBrowser();
      await expectLater(
        client(browser).authorize(_config(tokens)),
        throwsA(
          isA<OAuthFlowException>()
              .having((e) => e.failure, 'f', OAuthFailure.tokenRequestFailed)
              .having((e) => e.providerError, 'providerError', 'invalid_client'),
        ),
      );
      final (status, _) = await browser.page.future;
      expect(status, 400, reason: 'the browser page reports the failure');
    });
  });

  group('custom scheme flow (Android)', () {
    test('receives fermata://oauth/<source> via the deep-link stream', () async {
      final links = StreamController<Uri>.broadcast();
      addTearDown(links.close);
      final opened = <Uri>[];
      final c = OAuthClientImpl(
        http: fhttp,
        platform: const PlatformInfo(os: HostOs.android),
        deepLinks: () => links.stream,
        launcher: (url) async {
          opened.add(url);
          final state = url.queryParameters['state']!;
          scheduleMicrotask(() {
            links.add(Uri.parse('fermata://oauth/other?code=x&state=$state')); // other source: ignored
            links.add(Uri.parse('fermata://oauth/test?code=deep-code&state=$state'));
          });
        },
      );
      final config = _config(tokens);
      expect(c.strategyFor(config), RedirectStrategy.customScheme);
      expect(c.redirectUriFor(config), 'fermata://oauth/test');
      final token = await c.authorize(config);
      expect(opened.single.queryParameters['redirect_uri'], 'fermata://oauth/test');
      expect(tokens.forms.single['code'], 'deep-code');
      expect(tokens.forms.single['redirect_uri'], 'fermata://oauth/test');
      expect(token.accessToken, 'at-1');
    });

    test('state mismatch on the deep link is rejected', () async {
      final links = StreamController<Uri>.broadcast();
      addTearDown(links.close);
      final c = OAuthClientImpl(
        http: fhttp,
        platform: const PlatformInfo(os: HostOs.android),
        deepLinks: () => links.stream,
        launcher: (url) async =>
            scheduleMicrotask(() => links.add(Uri.parse('fermata://oauth/test?code=x&state=wrong'))),
      );
      await expectLater(
        c.authorize(_config(tokens)),
        throwsA(isA<OAuthFlowException>().having((e) => e.failure, 'f', OAuthFailure.stateMismatch)),
      );
      expect(tokens.forms, isEmpty);
    });

    test('per-config loopback override on Android', () async {
      final browser = _FakeBrowser();
      final c = client(browser, os: HostOs.android);
      final config = _config(tokens, strategy: RedirectStrategy.loopback);
      expect(c.strategyFor(config), RedirectStrategy.loopback);
      await c.authorize(config);
      expect(Uri.parse(browser.opened.single.queryParameters['redirect_uri']!).host, '127.0.0.1');
    });
  });

  group('refresh / revoke / client credentials', () {
    test('refresh keeps the old refresh token when it is not rotated', () async {
      tokens.response = {'access_token': 'at-2', 'expires_in': 3600, 'token_type': 'Bearer'};
      final c = client(_FakeBrowser());
      final old = const OAuthToken(accessToken: 'at-1', refreshToken: 'rt-1', scopes: ['read']);
      final fresh = await c.refresh(_config(tokens), old);
      expect(tokens.forms.single, {'grant_type': 'refresh_token', 'refresh_token': 'rt-1', 'client_id': 'client-abc'});
      expect(fresh.accessToken, 'at-2');
      expect(fresh.refreshToken, 'rt-1');
      expect(fresh.scopes, ['read']);
    });

    test('refresh stores a rotated refresh token', () async {
      tokens.response = {'access_token': 'at-3', 'refresh_token': 'rt-2', 'expires_in': '60'};
      final fresh = await client(_FakeBrowser())
          .refresh(_config(tokens, secret: 'sec'), const OAuthToken(accessToken: 'a', refreshToken: 'rt-1'));
      expect(fresh.refreshToken, 'rt-2');
      expect(tokens.forms.single['client_secret'], 'sec');
      expect(fresh.expiresAt!.difference(DateTime.now()).inSeconds, inInclusiveRange(55, 60));
    });

    test('rejected refresh is reported as invalid_grant', () async {
      tokens
        ..status = 400
        ..response = {'error': 'invalid_grant'};
      await expectLater(
        client(_FakeBrowser()).refresh(_config(tokens), const OAuthToken(accessToken: 'a', refreshToken: 'r')),
        throwsA(isA<OAuthFlowException>().having((e) => e.providerError, 'error', 'invalid_grant')),
      );
    });

    test('revoke posts RFC 7009 parameters; no endpoint = no request', () async {
      final c = client(_FakeBrowser());
      await c.revoke(_config(tokens), const OAuthToken(accessToken: 'a', refreshToken: 'r'));
      expect(tokens.forms, isEmpty);
      tokens.response = {};
      await c.revoke(_config(tokens, revoke: tokens.revokeUri), const OAuthToken(accessToken: 'a', refreshToken: 'r'));
      expect(tokens.paths.single, '/revoke');
      expect(tokens.forms.single['token'], 'r');
      expect(tokens.forms.single['token_type_hint'], 'refresh_token');
    });

    test('client credentials grant with HTTP Basic (SoundCloud style)', () async {
      final requests = <http.Request>[];
      final mock = MockClient((r) async {
        requests.add(r);
        return http.Response(
          '{"access_token":"app","expires_in":3600}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final endpoint = TokenEndpointClient(FermataHttp(client: mock));
      final token = await endpoint.clientCredentials(
        OAuthConfig(
          sourceId: 'soundcloud',
          authorizeEndpoint: Uri.parse('https://secure.soundcloud.com/authorize'),
          tokenEndpoint: Uri.parse('https://secure.soundcloud.com/oauth/token'),
          clientId: 'id',
          clientSecret: 'secret',
          clientAuthInHeader: true,
          scopes: const [],
        ),
      );
      expect(token.accessToken, 'app');
      expect(requests.single.headers['Authorization'], 'Basic ${base64.encode(utf8.encode('id:secret'))}');
      expect(requests.single.bodyFields, {'grant_type': 'client_credentials'});
    });

    test('redirectUriFor', () {
      final c = client(_FakeBrowser());
      expect(c.redirectUriFor(_config(tokens, port: 43821)), 'http://127.0.0.1:43821/callback/test');
      expect(c.redirectUriFor(_config(tokens, port: 0)), 'http://127.0.0.1/callback/test');
      expect(c.redirectUriFor(_config(tokens, override: 'https://x/cb')), 'https://x/cb');
      expect(client(_FakeBrowser(), os: HostOs.android).redirectUriFor(_config(tokens)), 'fermata://oauth/test');
    });
  });
}
