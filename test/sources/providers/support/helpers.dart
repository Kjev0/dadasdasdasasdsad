import 'dart:async';
import 'dart:convert';

import 'package:fermata/core/contracts/auth.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/net/http_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// JSON response with the right content type (UTF-8).
http.Response jsonResponse(Object? body, {int status = 200, Map<String, String>? headers}) => http.Response.bytes(
  utf8.encode(body is String ? body : jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
);

/// A MockClient-backed [FermataHttp] that records every request.
class RecordingHttp {
  RecordingHttp(Future<http.Response> Function(http.Request request) handler) {
    client = MockClient((request) {
      requests.add(request);
      return handler(request);
    });
    fermata = FermataHttp(client: client, timeout: const Duration(seconds: 5));
  }

  late final MockClient client;
  late final FermataHttp fermata;
  final List<http.Request> requests = [];

  Uri get last => requests.last.url;

  /// Requests whose path equals [path].
  List<http.Request> to(String path) => [
    for (final r in requests)
      if (r.url.path == path) r,
  ];
}

/// In-memory [CredentialsStore] for tests.
class FakeCredentialsStore implements CredentialsStore {
  FakeCredentialsStore([Map<String, SourceCredentials>? initial]) {
    if (initial != null) _values.addAll(initial);
  }

  final Map<String, SourceCredentials> _values = {};
  final StreamController<String> _changes = StreamController<String>.broadcast();

  @override
  Future<void> init() async {}

  @override
  SourceCredentials? get(String sourceId) => _values[sourceId];

  @override
  CredentialOrigin originOf(String sourceId) =>
      _values.containsKey(sourceId) ? CredentialOrigin.userEntered : CredentialOrigin.none;

  @override
  Future<void> setUserCredentials(String sourceId, SourceCredentials? credentials) async {
    if (credentials == null) {
      _values.remove(sourceId);
    } else {
      _values[sourceId] = credentials;
    }
    _changes.add(sourceId);
  }

  @override
  Stream<String> get changes => _changes.stream;

  @override
  String get configFilePath => '/nonexistent/credentials.json';

  Future<void> dispose() => _changes.close();
}

/// [OAuthClient] double: scripted authorize result, counted refreshes.
class FakeOAuthClient implements OAuthClient {
  FakeOAuthClient({this.prefix = 'user'});

  final String prefix;
  OAuthConfig? lastConfig;
  Object? authorizeError;
  Object? refreshError;
  int authorizeCalls = 0;
  int refreshCalls = 0;
  final List<OAuthToken> revoked = [];
  int _n = 1;

  @override
  Future<OAuthToken> authorize(OAuthConfig config) async {
    authorizeCalls++;
    lastConfig = config;
    if (authorizeError != null) throw authorizeError!;
    return OAuthToken(
      accessToken: '$prefix-1',
      refreshToken: '$prefix-refresh',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<OAuthToken> refresh(OAuthConfig config, OAuthToken token) async {
    refreshCalls++;
    lastConfig = config;
    if (refreshError != null) throw refreshError!;
    _n++;
    return OAuthToken(
      accessToken: '$prefix-$_n',
      refreshToken: token.refreshToken,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<void> revoke(OAuthConfig config, OAuthToken token) async => revoked.add(token);

  @override
  String redirectUriFor(OAuthConfig config) => 'http://127.0.0.1:43821/callback/${config.sourceId}';
}

/// A valid user token for pre-seeding a [TokenStore].
OAuthToken userToken([String access = 'user-1']) => OAuthToken(
  accessToken: access,
  refreshToken: 'user-refresh',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
);

/// Lets pending microtasks / stream events run.
Future<void> settle() => Future<void>.delayed(Duration.zero);
