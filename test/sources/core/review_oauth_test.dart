// Adversarial review tests for OAuthSession / OAuthClientImpl.
// Each test demonstrates a defect; they are expected to FAIL until fixed.
import 'dart:async';
import 'dart:io';

import 'package:fermata/core/contracts/auth.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/sources/auth/auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// OAuthClient whose refresh only completes when the test says so.
class _GatedOAuthClient implements OAuthClient {
  Completer<OAuthToken>? refreshGate;
  int refreshCalls = 0;
  Object? authorizeError;

  @override
  Future<OAuthToken> authorize(OAuthConfig config) async {
    if (authorizeError != null) throw authorizeError!;
    return OAuthToken(
      accessToken: 'at-1',
      refreshToken: 'rt-1',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<OAuthToken> refresh(OAuthConfig config, OAuthToken token) {
    refreshCalls++;
    refreshGate = Completer<OAuthToken>();
    return refreshGate!.future;
  }

  @override
  Future<void> revoke(OAuthConfig config, OAuthToken token) async {}

  @override
  String redirectUriFor(OAuthConfig config) => 'http://127.0.0.1:43821/callback/${config.sourceId}';
}

OAuthConfig _build(SourceCredentials c) => OAuthConfig(
  sourceId: 'acme',
  authorizeEndpoint: Uri.parse('https://acme.example/authorize'),
  tokenEndpoint: Uri.parse('https://acme.example/token'),
  clientId: c.clientId!,
  scopes: const ['read'],
);

void main() {
  group('OAuthSession state machine', () {
    late Directory tmp;
    late CredentialsStoreImpl creds;
    late InMemoryTokenStore tokens;
    late _GatedOAuthClient oauth;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('fermata_review_oauth');
      creds = CredentialsStoreImpl(
        configFile: File('${tmp.path}/credentials.json'),
        secureStorage: InMemoryKeyValueStore(),
        buildTime: const {'acme': SourceCredentials(clientId: 'cid')},
      );
      await creds.init();
      tokens = InMemoryTokenStore();
      oauth = _GatedOAuthClient();
    });

    tearDown(() async {
      await creds.dispose();
      await tmp.delete(recursive: true);
    });

    test('a refresh that completes after disconnect() must not resurrect the deleted token', () async {
      // Token about to expire -> the next request refreshes first.
      await tokens.write(
        'acme',
        OAuthToken(
          accessToken: 'old',
          refreshToken: 'rt-old',
          expiresAt: DateTime.now().add(const Duration(seconds: 30)),
        ),
      );
      final api = RecordingHttp((req) async => jsonResponse('{"ok":true}'));
      final session = OAuthSession(
        sourceId: 'acme',
        displayName: 'Acme',
        client: oauth,
        tokens: tokens,
        credentials: creds,
        http: api.fermata,
        buildConfig: _build,
        fetchAccountOnInit: false,
        platform: const PlatformInfo(os: HostOs.linux),
        fetchAccount: (s, cancel) async => const OAuthAccount(name: 'Ada'),
      );
      await session.init();
      expect(session.state.status, SourceConnectionStatus.connected);

      // A background request starts a refresh (e.g. a search while the
      // token is inside the refresh leeway)...
      final request = session.authorizedGetJson(Uri.parse('https://acme.example/me'));
      await pumpEventQueue();
      expect(oauth.refreshCalls, 1);

      // ...and the user clicks "Disconnect" in Connected services meanwhile.
      await session.disconnect();
      expect(await tokens.read('acme'), isNull, reason: 'disconnect deleted the token');
      expect(session.state.status, SourceConnectionStatus.notConnected);

      // The refresh response arrives afterwards.
      oauth.refreshGate!.complete(
        OAuthToken(
          accessToken: 'fresh',
          refreshToken: 'rt-fresh',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      try {
        await request;
      } catch (_) {
        // Failing the request is fine; resurrecting the account is not.
      }

      // BUG: OAuthSession._refresh() unconditionally does `_token = fresh`
      // and `_tokens.write(...)`, so the account the user just disconnected
      // is silently re-persisted and comes back as "connected" on next start.
      expect(await tokens.read('acme'), isNull, reason: 'token must stay deleted after disconnect');
      expect(await session.currentToken(), isNull);

      // Simulate the next app start.
      final next = OAuthSession(
        sourceId: 'acme',
        displayName: 'Acme',
        client: oauth,
        tokens: tokens,
        credentials: creds,
        http: api.fermata,
        buildConfig: _build,
        fetchAccountOnInit: false,
        platform: const PlatformInfo(os: HostOs.linux),
        fetchAccount: (s, cancel) async => const OAuthAccount(name: 'Ada'),
      );
      await next.init();
      expect(next.state.status, isNot(SourceConnectionStatus.connected));
      await session.dispose();
      await next.dispose();
    });
    test('a failed re-connect (e.g. loopback port busy) must not disable a still-valid session', () async {
      final api = RecordingHttp((req) async => jsonResponse('{"name":"Ada"}'));
      final session = OAuthSession(
        sourceId: 'acme',
        displayName: 'Acme',
        client: oauth,
        tokens: tokens,
        credentials: creds,
        http: api.fermata,
        buildConfig: _build,
        fetchAccountOnInit: false,
        platform: const PlatformInfo(os: HostOs.linux),
        fetchAccount: (s, cancel) async => const OAuthAccount(name: 'Ada'),
      );
      addTearDown(session.dispose);
      await session.init();
      await session.connect();
      expect(session.state.status, SourceConnectionStatus.connected);

      // The user presses "Reconnect"/"Switch account"; the flow fails hard
      // before the provider was even reached.
      oauth.authorizeError = const OAuthFlowException('acme', OAuthFailure.portInUse, 'Port 43821 is in use');
      await expectLater(session.connect(), throwsA(isA<OAuthFlowException>()));

      // BUG: _connect() emits SourceConnectionStatus.error for every
      // non-"soft" failure even though _token is still the valid old token,
      // so OAuthSourceMixin.isReady turns false and the registry drops the
      // source from search until the app is restarted.
      expect(await session.validToken(), isNotNull, reason: 'the old token still works');
      expect(session.state.isConnected, isTrue, reason: 'state is ${session.state.status}');
    });
  });
}
