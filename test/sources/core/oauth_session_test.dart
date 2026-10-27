import 'dart:io';

import 'package:fermata/core/contracts/auth.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/sources/auth/auth.dart';
import 'package:fermata/sources/base/music_source_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// OAuthClient double: hands out scripted tokens, counts calls.
class _FakeOAuthClient implements OAuthClient {
  OAuthToken authorizeResult = OAuthToken(
    accessToken: 'at-1',
    refreshToken: 'rt-1',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    scopes: const ['read'],
  );
  Object? authorizeError;
  Object? refreshError;
  int authorizeCalls = 0;
  int refreshCalls = 0;
  final List<OAuthToken> revoked = [];
  int _n = 1;

  @override
  Future<OAuthToken> authorize(OAuthConfig config) async {
    authorizeCalls++;
    if (authorizeError != null) throw authorizeError!;
    return authorizeResult;
  }

  @override
  Future<OAuthToken> refresh(OAuthConfig config, OAuthToken token) async {
    refreshCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (refreshError != null) throw refreshError!;
    _n++;
    return OAuthToken(
      accessToken: 'at-$_n',
      refreshToken: token.refreshToken,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      scopes: token.scopes,
    );
  }

  @override
  Future<void> revoke(OAuthConfig config, OAuthToken token) async => revoked.add(token);

  @override
  String redirectUriFor(OAuthConfig config) => 'http://127.0.0.1:43821/callback/${config.sourceId}';
}

OAuthConfig _build(SourceCredentials c) => OAuthConfig(
  sourceId: 'acme',
  authorizeEndpoint: Uri.parse('https://acme.example/authorize'),
  tokenEndpoint: Uri.parse('https://acme.example/token'),
  clientId: c.clientId!,
  clientSecret: c.clientSecret,
  scopes: const ['read'],
);

void main() {
  late Directory tmp;
  late CredentialsStoreImpl creds;
  late InMemoryTokenStore tokens;
  late _FakeOAuthClient oauth;
  late RecordingHttp api;
  late List<String> acceptedTokens;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fermata_session');
    creds = CredentialsStoreImpl(
      configFile: File('${tmp.path}/credentials.json'),
      secureStorage: InMemoryKeyValueStore(),
      buildTime: const {},
    );
    await creds.init();
    tokens = InMemoryTokenStore();
    oauth = _FakeOAuthClient();
    acceptedTokens = ['at-1', 'at-2', 'at-3'];
    // A provider API that only accepts tokens in [acceptedTokens].
    api = RecordingHttp((req) async {
      final auth = req.headers['Authorization'] ?? '';
      final token = auth.split(' ').last;
      if (!acceptedTokens.contains(token)) return jsonResponse('{"error":"unauthorized"}', status: 401);
      if (req.url.path == '/me') return jsonResponse('{"name":"Ada","avatar":"https://acme.example/ada.png"}');
      return jsonResponse('{"ok":true,"token":"$token"}');
    });
  });

  tearDown(() async {
    await creds.dispose();
    await tmp.delete(recursive: true);
  });

  OAuthSession session({
    AuthHeaderStyle style = AuthHeaderStyle.bearer,
    HostOs os = HostOs.linux,
    bool android = true,
    TokenRevoker? revoker,
    List<String> fields = const ['clientId'],
  }) => OAuthSession(
    sourceId: 'acme',
    displayName: 'Acme',
    client: oauth,
    tokens: tokens,
    credentials: creds,
    http: api.fermata,
    buildConfig: _build,
    requiredCredentialFields: fields,
    credentialsHelpUrl: Uri.parse('https://acme.example/developers'),
    headerStyle: style,
    fetchAccountOnInit: false,
    supportsAndroidRedirect: android,
    androidUnsupportedExplanation: 'Acme sign-in needs Google Play services.',
    revoker: revoker,
    platform: PlatformInfo(os: os),
    fetchAccount: (s, cancel) async {
      final json = await s.authorizedGetJson(Uri.parse('https://acme.example/me'), cancel: cancel) as Map;
      return OAuthAccount(name: json['name'] as String, avatar: Uri.parse(json['avatar'] as String));
    },
  );

  test('without credentials: credentialsMissing, missing fields listed, connect throws, no requests', () async {
    final s = session(fields: const ['clientId', 'clientSecret']);
    await s.init();
    expect(s.state.status, SourceConnectionStatus.credentialsMissing);
    expect(s.credentialStatus.configured, isFalse);
    expect(s.credentialStatus.missing, ['clientId', 'clientSecret']);
    expect(s.credentialStatus.helpUrl.toString(), 'https://acme.example/developers');
    await expectLater(s.connect(), throwsA(isA<MissingCredentialsException>()));
    await expectLater(
      s.authorizedGetJson(Uri.parse('https://acme.example/x')),
      throwsA(isA<MissingCredentialsException>()),
    );
    expect(oauth.authorizeCalls, 0);
    expect(api.requests, isEmpty);
  });

  test('credential changes re-evaluate the state (credentialsMissing <-> notConnected)', () async {
    final s = session();
    await s.init();
    final seen = <SourceConnectionStatus>[];
    s.changes.listen((e) => seen.add(e.status));
    await creds.setUserCredentials('acme', const SourceCredentials(clientId: 'cid'));
    await pumpEventQueue();
    expect(s.state.status, SourceConnectionStatus.notConnected);
    expect(s.credentialStatus.origin, CredentialOrigin.userEntered);
    await creds.setUserCredentials('acme', null);
    await pumpEventQueue();
    expect(s.state.status, SourceConnectionStatus.credentialsMissing);
    expect(seen, [SourceConnectionStatus.notConnected, SourceConnectionStatus.credentialsMissing]);
  });

  group('with credentials', () {
    setUp(() => creds.setUserCredentials('acme', const SourceCredentials(clientId: 'cid')));

    test('connect: authorize -> store token -> fetch account -> connected', () async {
      final s = session();
      await s.init();
      expect(s.state.status, SourceConnectionStatus.notConnected);
      final seen = <SourceConnectionStatus>[];
      s.changes.listen((e) => seen.add(e.status));
      await s.connect();
      await pumpEventQueue();
      expect(seen, [SourceConnectionStatus.connecting, SourceConnectionStatus.connected]);
      expect(s.state.accountName, 'Ada');
      expect(s.state.accountAvatar.toString(), 'https://acme.example/ada.png');
      expect(s.state.grantedScopes, ['read']);
      expect((await tokens.read('acme'))!.accessToken, 'at-1');
      expect(api.requests.single.headers['Authorization'], 'Bearer at-1');
    });

    test('concurrent connect calls share one flow', () async {
      final s = session();
      await s.init();
      await Future.wait([s.connect(), s.connect()]);
      expect(oauth.authorizeCalls, 1);
    });

    test('cancelled sign-in returns to notConnected with an explanation', () async {
      oauth.authorizeError = const OAuthFlowException('acme', OAuthFailure.cancelled, 'Sign-in was cancelled.');
      final s = session();
      await s.init();
      await expectLater(s.connect(), throwsA(isA<OAuthFlowException>()));
      expect(s.state.status, SourceConnectionStatus.notConnected);
      expect(s.state.error, contains('cancelled'));
      expect(await tokens.read('acme'), isNull);
    });

    test('hard sign-in failures end in error state', () async {
      oauth.authorizeError = const OAuthFlowException('acme', OAuthFailure.stateMismatch, 'state mismatch');
      final s = session();
      await s.init();
      await expectLater(s.connect(), throwsA(isA<OAuthFlowException>()));
      expect(s.state.status, SourceConnectionStatus.error);
    });

    test('account rejected (403) deletes the token', () async {
      api = RecordingHttp((req) async => jsonResponse('{"error":"forbidden"}', status: 403));
      final s = session();
      await s.init();
      await expectLater(s.connect(), throwsA(isA<ApiException>()));
      expect(s.state.status, SourceConnectionStatus.error);
      expect(await tokens.read('acme'), isNull);
    });

    test('stored token on init -> connected', () async {
      await tokens.write(
        'acme',
        OAuthToken(accessToken: 'at-1', expiresAt: DateTime.now().add(const Duration(hours: 1))),
      );
      final s = session();
      await s.init();
      expect(s.state.status, SourceConnectionStatus.connected);
    });

    test('refreshes automatically shortly before expiry', () async {
      await tokens.write(
        'acme',
        OAuthToken(
          accessToken: 'at-1',
          refreshToken: 'rt-1',
          expiresAt: DateTime.now().add(const Duration(seconds: 30)),
        ),
      ); // inside the 2 min leeway
      final s = session();
      await s.init();
      final json = await s.authorizedGetJson(Uri.parse('https://acme.example/data')) as Map;
      expect(oauth.refreshCalls, 1);
      expect(json['token'], 'at-2');
      expect((await tokens.read('acme'))!.accessToken, 'at-2', reason: 'refreshed token is persisted');
      expect(api.requests.length, 1, reason: 'no failed request was needed');
    });

    test('concurrent requests share one refresh', () async {
      await tokens.write('acme', OAuthToken(accessToken: 'old', refreshToken: 'rt', expiresAt: DateTime(2000)));
      final s = session();
      await s.init();
      await Future.wait([for (var i = 0; i < 5; i++) s.authorizedGetJson(Uri.parse('https://acme.example/d'))]);
      expect(oauth.refreshCalls, 1);
    });

    test('401 -> refresh once -> retry succeeds', () async {
      acceptedTokens = ['at-2'];
      await tokens.write(
        'acme',
        OAuthToken(accessToken: 'at-1', refreshToken: 'rt-1', expiresAt: DateTime.now().add(const Duration(hours: 1))),
      );
      final s = session();
      await s.init();
      final json = await s.authorizedGetJson(Uri.parse('https://acme.example/data')) as Map;
      expect(json['token'], 'at-2');
      expect(oauth.refreshCalls, 1);
      expect(api.requests.map((r) => r.headers['Authorization']), ['Bearer at-1', 'Bearer at-2']);
      expect(s.state.status, SourceConnectionStatus.connected);
    });

    test('401 after refresh -> expired + AuthRequiredException', () async {
      acceptedTokens = [];
      await tokens.write(
        'acme',
        OAuthToken(accessToken: 'at-1', refreshToken: 'rt-1', expiresAt: DateTime.now().add(const Duration(hours: 1))),
      );
      final s = session();
      await s.init();
      await expectLater(
        s.authorizedGetJson(Uri.parse('https://acme.example/data')),
        throwsA(isA<AuthRequiredException>().having((e) => e.sourceId, 'sourceId', 'acme')),
      );
      expect(oauth.refreshCalls, 1, reason: 'refresh only once');
      expect(api.requests.length, 2);
      expect(s.state.status, SourceConnectionStatus.expired);
      // Further calls fail fast without network.
      await expectLater(
        s.authorizedGetJson(Uri.parse('https://acme.example/data')),
        throwsA(isA<AuthRequiredException>()),
      );
      expect(api.requests.length, 2);
    });

    test('rejected refresh token -> expired; reconnect recovers', () async {
      oauth.refreshError = const OAuthFlowException(
        'acme',
        OAuthFailure.tokenRequestFailed,
        'invalid_grant',
        providerError: 'invalid_grant',
      );
      await tokens.write('acme', OAuthToken(accessToken: 'at-1', refreshToken: 'rt-1', expiresAt: DateTime(2000)));
      final s = session();
      await s.init();
      await expectLater(s.validToken(), throwsA(isA<AuthRequiredException>()));
      expect(s.state.status, SourceConnectionStatus.expired);
      await s.connect();
      expect(s.state.status, SourceConnectionStatus.connected);
    });

    test('network failure during refresh keeps the session', () async {
      oauth.refreshError = const NetworkException('offline');
      await tokens.write('acme', OAuthToken(accessToken: 'at-1', refreshToken: 'rt-1', expiresAt: DateTime(2000)));
      final s = session();
      await s.init();
      await expectLater(s.validToken(), throwsA(isA<NetworkException>()));
      expect(s.state.status, SourceConnectionStatus.connected);
    });

    test('SoundCloud-style OAuth header', () async {
      await tokens.write(
        'acme',
        OAuthToken(accessToken: 'at-1', expiresAt: DateTime.now().add(const Duration(hours: 1))),
      );
      final s = session(style: AuthHeaderStyle.oauth);
      await s.init();
      await s.authorizedGetJson(Uri.parse('https://acme.example/data'));
      expect(api.requests.single.headers['Authorization'], 'OAuth at-1');
    });

    test('disconnect revokes remotely and deletes tokens even if revoke fails', () async {
      final s = session();
      await s.init();
      await s.connect();
      await s.disconnect();
      expect(oauth.revoked.single.accessToken, 'at-1');
      expect(await tokens.read('acme'), isNull);
      expect(s.state.status, SourceConnectionStatus.notConnected);

      final failing = session(revoker: (_, _) async => throw const NetworkException('offline'));
      await failing.init();
      await failing.connect();
      await failing.disconnect();
      expect(await tokens.read('acme'), isNull);
      expect(failing.state.status, SourceConnectionStatus.notConnected);
    });

    test('Android opt-out throws UnsupportedSourceOperation', () async {
      final s = session(os: HostOs.android, android: false);
      await s.init();
      await expectLater(
        s.connect(),
        throwsA(
          isA<UnsupportedSourceOperation>().having((e) => e.message, 'message', contains('Google Play services')),
        ),
      );
      expect(oauth.authorizeCalls, 0);
    });
  });

  group('OAuthSourceMixin', () {
    test('delegates auth members to the session', () async {
      await creds.setUserCredentials('acme', const SourceCredentials(clientId: 'cid'));
      final source = _AcmeSource(session());
      await source.init();
      expect(source.authState.status, SourceConnectionStatus.notConnected);
      expect(source.isReady, isFalse);
      final states = <SourceConnectionStatus>[];
      source.authStateChanges.listen((s) => states.add(s.status));
      await source.connect();
      expect(source.isReady, isTrue);
      expect(source.credentialStatus.configured, isTrue);
      final page = await source.searchTracks('x');
      expect(page.items.single.title, 'at-1');
      await source.disconnect();
      await pumpEventQueue();
      expect(source.isReady, isFalse);
      expect(states, contains(SourceConnectionStatus.connected));
      await source.dispose();
    });

    test('missing credentials: not ready and calls throw before any request', () async {
      final source = _AcmeSource(session());
      await source.init();
      expect(source.isReady, isFalse);
      expect(source.authState.status, SourceConnectionStatus.credentialsMissing);
      await expectLater(source.searchTracks('x'), throwsA(isA<MissingCredentialsException>()));
      expect(api.requests, isEmpty);
    });
  });
}

class _AcmeSource extends MusicSourceBase with OAuthSourceMixin {
  _AcmeSource(this.oauthSession);

  @override
  final OAuthSession oauthSession;

  @override
  String get id => 'acme';

  @override
  String get displayName => 'Acme';

  @override
  Set<SourceCapability> get capabilities => const {SourceCapability.searchTracks, SourceCapability.oauth};

  @override
  String get limitationsNote => 'test';

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    ensureCredentials();
    final json = await oauthSession.authorizedGetJson(Uri.parse('https://acme.example/search?q=$query')) as Map;
    return Page([Track(sourceId: id, sourceTrackId: '1', title: json['token'] as String)]);
  }
}
