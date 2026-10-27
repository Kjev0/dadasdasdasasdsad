import 'dart:async';

import 'package:http/http.dart' as http_pkg;
import 'package:logging/logging.dart';

import '../../core/contracts/auth.dart';
import '../../core/errors.dart';
import '../../core/models/auth.dart';
import '../../core/net/http_client.dart';
import '../../core/platform/platform_info.dart';
import '../../core/util/cancel_token.dart';
import 'oauth_errors.dart';

final _log = Logger('sources.auth.session');

/// The connected account, fetched right after connecting.
class OAuthAccount {
  const OAuthAccount({required this.name, this.avatar, this.id});

  final String name;
  final Uri? avatar;
  final String? id;
}

/// How the access token is sent to the provider's API.
enum AuthHeaderStyle {
  /// `Authorization: Bearer <token>` (Spotify, Google, Audius, …).
  bearer,

  /// `Authorization: OAuth <token>` (SoundCloud).
  oauth,

  /// `Authorization: <token_type> <token>` as returned by the token endpoint.
  tokenType,
}

/// Builds the provider's [OAuthConfig] from the resolved credentials.
typedef OAuthConfigBuilder = OAuthConfig Function(SourceCredentials credentials);

/// Fetches the account behind a fresh token (typically `GET /me` via
/// [OAuthSession.authorizedGetJson]).
typedef AccountFetcher = Future<OAuthAccount> Function(OAuthSession session, CancelToken? cancel);

/// Custom remote revocation (e.g. SoundCloud `POST /disconnect`). Used
/// instead of RFC 7009 revocation when given.
typedef TokenRevoker = Future<void> Function(OAuthSession session, OAuthToken token);

/// Account connection state machine for one source: wraps [OAuthClient],
/// [TokenStore] and [CredentialsStore].
///
/// States: `credentialsMissing` ↔ `notConnected` → `connecting` →
/// `connected` → (`expired` when refresh fails) / `error`.
///
/// * [connect]: authorize → store token → fetch account → connected.
/// * Tokens are refreshed shortly *before* they expire ([refreshLeeway]) on
///   the next request; a 401 triggers one forced refresh + retry, after which
///   the state becomes `expired` and [AuthRequiredException] is thrown.
/// * [disconnect]: remote revoke when supported (errors ignored), delete
///   tokens locally.
/// * Credential changes re-evaluate the state.
class OAuthSession {
  OAuthSession({
    required this.sourceId,
    required this.displayName,
    required this._client,
    required this._tokens,
    required this._credentials,
    required this._http,
    required this._buildConfig,
    required this._fetchAccount,
    this.requiredCredentialFields = const ['clientId'],
    this.credentialsHelpUrl,
    this.headerStyle = AuthHeaderStyle.bearer,
    this.refreshLeeway = const Duration(minutes: 2),
    this.fetchAccountOnInit = true,
    this.supportsAndroidRedirect = true,
    this.androidUnsupportedExplanation,
    this._revoker,
    PlatformInfo? platform,
  }) : _platform = platform ?? PlatformInfo.current();

  final String sourceId;
  final String displayName;

  /// Credential fields that must be non-empty: any of `clientId`,
  /// `clientSecret`, `apiKey`.
  final List<String> requiredCredentialFields;

  /// Where a developer registers an app for this provider.
  final Uri? credentialsHelpUrl;
  final AuthHeaderStyle headerStyle;

  /// Refresh this long before `expiresAt`.
  final Duration refreshLeeway;

  /// Re-fetch the account name in the background after [init] when a token
  /// is stored (also detects revoked tokens early).
  final bool fetchAccountOnInit;

  /// False for providers whose OAuth cannot work on Android (e.g. Google
  /// rejects custom schemes and loopback for Android clients): [connect]
  /// then throws [UnsupportedSourceOperation] with
  /// [androidUnsupportedExplanation].
  final bool supportsAndroidRedirect;
  final String? androidUnsupportedExplanation;

  final OAuthClient _client;
  final TokenStore _tokens;
  final CredentialsStore _credentials;
  final FermataHttp _http;
  final OAuthConfigBuilder _buildConfig;
  final AccountFetcher _fetchAccount;
  final TokenRevoker? _revoker;
  final PlatformInfo _platform;

  final StreamController<SourceAuthState> _changes = StreamController<SourceAuthState>.broadcast();
  SourceAuthState _state = const SourceAuthState(status: SourceConnectionStatus.notConnected);
  OAuthToken? _token;
  bool _tokenLoaded = false;

  /// Bumped whenever the session's token is replaced or deleted from outside
  /// the refresh path ([connect], [disconnect]); an in-flight refresh that
  /// finds it changed must drop its result.
  int _tokenEpoch = 0;
  Future<OAuthToken>? _refreshing;
  Future<void>? _connecting;
  StreamSubscription<String>? _credSub;
  bool _disposed = false;

  /// Current state.
  SourceAuthState get state => _state;

  /// Emits every state change.
  Stream<SourceAuthState> get changes => _changes.stream;

  FermataHttp get http => _http;

  // ---- Credentials --------------------------------------------------------

  SourceCredentials? get credentials => _credentials.get(sourceId);

  /// Names of required fields that are not configured.
  List<String> get missingCredentials {
    final c = credentials;
    bool has(String? v) => v != null && v.trim().isNotEmpty;
    return [
      for (final f in requiredCredentialFields)
        if (!switch (f) {
          'clientId' => has(c?.clientId),
          'clientSecret' => has(c?.clientSecret),
          'apiKey' => has(c?.apiKey),
          _ => false,
        })
          f,
    ];
  }

  bool get hasCredentials => missingCredentials.isEmpty;

  CredentialStatus get credentialStatus {
    final missing = missingCredentials;
    return CredentialStatus(
      configured: missing.isEmpty,
      origin: _credentials.originOf(sourceId),
      missing: missing,
      helpUrl: credentialsHelpUrl,
    );
  }

  /// Returns the credentials or throws [MissingCredentialsException]. Call at
  /// the start of every API operation so nothing hits the network without
  /// credentials.
  SourceCredentials requireCredentials() {
    final missing = missingCredentials;
    if (missing.isNotEmpty) throw MissingCredentialsException(sourceId, missing);
    return credentials!;
  }

  /// The provider config for the current credentials.
  OAuthConfig requireConfig() => _buildConfig(requireCredentials());

  // ---- Lifecycle ----------------------------------------------------------

  /// Loads the stored token and computes the initial state. Never throws for
  /// missing credentials or tokens.
  Future<void> init() async {
    _credSub ??= _credentials.changes.where((id) => id == sourceId).listen((_) => _evaluate());
    await _loadToken();
    _evaluate();
    if (fetchAccountOnInit && _token != null && hasCredentials) {
      unawaited(
        refreshAccount().catchError((Object e) {
          _log.fine('Background account refresh for $sourceId failed: $e');
        }),
      );
    }
  }

  Future<void> _loadToken() async {
    if (_tokenLoaded) return;
    try {
      _token = await _tokens.read(sourceId);
    } catch (e) {
      _log.warning('Could not read stored token for $sourceId: ${e.runtimeType}');
    }
    _tokenLoaded = true;
  }

  void _emit(SourceAuthState s) {
    _state = s;
    if (!_disposed) _changes.add(s);
  }

  SourceAuthState _connected({OAuthAccount? account, SourceAuthState? keepFrom}) => SourceAuthState(
    status: SourceConnectionStatus.connected,
    accountName: account?.name ?? keepFrom?.accountName,
    accountAvatar: account?.avatar ?? keepFrom?.accountAvatar,
    grantedScopes: _token?.scopes ?? const [],
    expiresAt: _token?.expiresAt,
  );

  /// Recomputes the state from credentials + stored token.
  void _evaluate() {
    if (_state.status == SourceConnectionStatus.connecting) return;
    if (!hasCredentials) {
      _emit(const SourceAuthState(status: SourceConnectionStatus.credentialsMissing));
    } else if (_token == null) {
      _emit(SourceAuthState(status: SourceConnectionStatus.notConnected, error: _state.error));
    } else if (_state.status == SourceConnectionStatus.expired) {
      _emit(_state);
    } else {
      _emit(_connected(keepFrom: _state.isConnected ? _state : null));
    }
  }

  /// Interactive sign-in. Completes when connected; throws on failure.
  Future<void> connect() async {
    if (_platform.isAndroid && !supportsAndroidRedirect) {
      throw UnsupportedSourceOperation(
        sourceId,
        'connect',
        androidUnsupportedExplanation ?? 'Connecting $displayName is not supported on Android.',
      );
    }
    if (!hasCredentials) {
      _emit(const SourceAuthState(status: SourceConnectionStatus.credentialsMissing));
      throw MissingCredentialsException(sourceId, missingCredentials);
    }
    final pending = _connecting ??= _connect().whenComplete(() => _connecting = null);
    return pending;
  }

  Future<void> _connect() async {
    final config = requireConfig();
    final previous = _state;
    _emit(const SourceAuthState(status: SourceConnectionStatus.connecting));
    final OAuthToken token;
    try {
      token = await _client.authorize(config);
    } on OAuthFlowException catch (e) {
      final soft =
          e.failure == OAuthFailure.cancelled ||
          e.failure == OAuthFailure.timeout ||
          e.failure == OAuthFailure.accessDenied;
      _emit(_failedConnectState(previous, e.message, soft: soft));
      rethrow;
    } catch (e) {
      _emit(_failedConnectState(previous, e is FermataException ? e.message : '$e', soft: false));
      rethrow;
    }
    _tokenEpoch++;
    _refreshing = null;
    _token = token;
    _tokenLoaded = true;
    try {
      await _tokens.write(sourceId, token);
    } catch (e) {
      // Keep the session usable; it just will not survive a restart.
      _log.warning('Could not persist the $sourceId token: ${e.runtimeType}');
    }
    OAuthAccount? account;
    try {
      account = await _fetchAccount(this, null);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        // e.g. Spotify dev-mode apps answer 403 for users not on the allow-list.
        await _tokens.delete(sourceId);
        _token = null;
        _emit(
          SourceAuthState(
            status: SourceConnectionStatus.error,
            error: 'Account rejected by $displayName (HTTP ${e.statusCode}).',
          ),
        );
        rethrow;
      }
      _log.warning('Connected to $sourceId but fetching the account failed: ${e.message}');
    } on AuthRequiredException {
      rethrow;
    } catch (e) {
      _log.warning('Connected to $sourceId but fetching the account failed: $e');
    }
    _emit(_connected(account: account));
    _log.info('Connected $sourceId');
  }

  /// State after a failed [connect]. A failure that leaves a still-usable
  /// session behind (an existing token) never turns it into `error`: the
  /// failed attempt did not touch the old token, so the session stays as it
  /// was and only reports the message.
  SourceAuthState _failedConnectState(SourceAuthState previous, String message, {required bool soft}) {
    final keepsSession = _token != null && previous.status != SourceConnectionStatus.expired;
    if (!soft && !keepsSession) return SourceAuthState(status: SourceConnectionStatus.error, error: message);
    final status = _restingStatus(previous);
    final connected = status == SourceConnectionStatus.connected;
    return SourceAuthState(
      status: status,
      error: message,
      accountName: previous.accountName,
      accountAvatar: connected ? previous.accountAvatar : null,
      grantedScopes: connected ? _token?.scopes ?? const [] : const [],
      expiresAt: connected ? _token?.expiresAt : null,
    );
  }

  SourceConnectionStatus _restingStatus(SourceAuthState previous) =>
      _token != null && previous.status != SourceConnectionStatus.expired
      ? SourceConnectionStatus.connected
      : (previous.status == SourceConnectionStatus.expired
            ? SourceConnectionStatus.expired
            : SourceConnectionStatus.notConnected);

  /// Revokes remotely where supported (best effort) and deletes local tokens.
  Future<void> disconnect() async {
    await _loadToken();
    final token = _token;
    if (token != null) {
      try {
        if (_revoker != null) {
          await _revoker(this, token);
        } else if (hasCredentials) {
          await _client.revoke(requireConfig(), token);
        }
      } catch (e) {
        _log.warning('Remote revoke for $sourceId failed (tokens are deleted locally anyway): ${e.runtimeType}');
      }
    }
    // Invalidate any refresh still in flight so it cannot re-persist the
    // token we are deleting.
    _tokenEpoch++;
    _refreshing = null;
    _token = null;
    Object? deleteError;
    StackTrace? deleteStack;
    try {
      await _tokens.delete(sourceId);
    } catch (e, st) {
      deleteError = e;
      deleteStack = st;
    }
    _emit(
      SourceAuthState(
        status: hasCredentials ? SourceConnectionStatus.notConnected : SourceConnectionStatus.credentialsMissing,
      ),
    );
    if (deleteError != null) {
      // The session is disconnected locally, but the stored token may
      // survive a restart: do not report success.
      _log.warning('Could not delete the stored $sourceId token: ${deleteError.runtimeType}');
      Error.throwWithStackTrace(deleteError, deleteStack!);
    }
    _log.info('Disconnected $sourceId');
  }

  /// Re-fetches the account (name/avatar) and updates the state.
  Future<void> refreshAccount({CancelToken? cancel}) async {
    final account = await _fetchAccount(this, cancel);
    if (_token != null && _state.status == SourceConnectionStatus.connected) {
      _emit(_connected(account: account));
    }
  }

  // ---- Tokens -------------------------------------------------------------

  /// The stored token (may be expired), or null when not connected.
  Future<OAuthToken?> currentToken() async {
    await _loadToken();
    return _token;
  }

  /// A token valid for at least [refreshLeeway]; refreshes when needed.
  /// Throws [MissingCredentialsException] / [AuthRequiredException].
  Future<OAuthToken> validToken({CancelToken? cancel}) async {
    requireCredentials();
    await _loadToken();
    final token = _token;
    if (token == null) {
      throw AuthRequiredException(sourceId, '$displayName is not connected.');
    }
    if (_state.status == SourceConnectionStatus.expired) {
      throw AuthRequiredException(sourceId, 'The $displayName session expired. Please reconnect.');
    }
    if (token.isExpired(leeway: refreshLeeway)) {
      if (token.refreshToken == null) {
        _markExpired('Access token expired and no refresh token is available.');
        throw AuthRequiredException(sourceId, 'The $displayName session expired. Please reconnect.');
      }
      return forceRefresh(cancel: cancel);
    }
    return token;
  }

  /// Refreshes now (shared between concurrent callers). On a rejected
  /// refresh token the state becomes `expired`.
  Future<OAuthToken> forceRefresh({CancelToken? cancel}) {
    final running = _refreshing;
    if (running != null) return running;
    late final Future<OAuthToken> refresh;
    refresh = _refresh().whenComplete(() {
      if (identical(_refreshing, refresh)) _refreshing = null;
    });
    return _refreshing = refresh;
  }

  Future<OAuthToken> _refresh() async {
    final token = _token;
    if (token == null) throw AuthRequiredException(sourceId, '$displayName is not connected.');
    if (token.refreshToken == null) {
      _markExpired('No refresh token.');
      throw AuthRequiredException(sourceId, 'The $displayName session expired. Please reconnect.');
    }
    final epoch = _tokenEpoch;
    try {
      final fresh = await _client.refresh(requireConfig(), token);
      // disconnect()/connect() ran while the request was in flight: the
      // result belongs to a session that no longer exists.
      if (epoch != _tokenEpoch) throw AuthRequiredException(sourceId, '$displayName was disconnected.');
      _token = fresh;
      await _tokens.write(sourceId, fresh);
      if (epoch != _tokenEpoch) {
        // disconnect() ran during the write: make sure nothing stays stored.
        if (_token == null) await _tokens.delete(sourceId);
        throw AuthRequiredException(sourceId, '$displayName was disconnected.');
      }
      if (_state.isConnected) _emit(_connected(keepFrom: _state));
      _log.fine('Refreshed $sourceId token');
      return fresh;
    } on OAuthFlowException catch (e) {
      if (epoch != _tokenEpoch) throw AuthRequiredException(sourceId, '$displayName was disconnected.');
      _markExpired(e.message);
      throw AuthRequiredException(sourceId, 'The $displayName session expired. Please reconnect.');
    }
  }

  void _markExpired(String why) {
    _log.info('$sourceId session expired: $why');
    _emit(
      SourceAuthState(
        status: SourceConnectionStatus.expired,
        accountName: _state.accountName,
        accountAvatar: _state.accountAvatar,
        error: why,
      ),
    );
  }

  /// The `Authorization` header for [token] in the provider's format.
  Map<String, String> authHeaders(OAuthToken token) => {
    'Authorization': switch (headerStyle) {
      AuthHeaderStyle.bearer => 'Bearer ${token.accessToken}',
      AuthHeaderStyle.oauth => 'OAuth ${token.accessToken}',
      AuthHeaderStyle.tokenType => '${token.tokenType} ${token.accessToken}',
    },
  };

  // ---- Authorized requests ------------------------------------------------

  /// Sends an authorized request. On 401 the token is refreshed once and the
  /// request retried; a second 401 marks the session expired and throws
  /// [AuthRequiredException]. Other statuses are returned as-is.
  Future<http_pkg.Response> authorizedSend(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    RetryPolicy retry = const RetryPolicy(),
    CancelToken? cancel,
  }) async {
    var token = await validToken(cancel: cancel);
    var response = await _http.send(
      method,
      uri,
      headers: {...?headers, ...authHeaders(token)},
      body: body,
      retry: retry,
      cancel: cancel,
    );
    if (response.statusCode != 401) return response;
    _log.fine('$sourceId answered 401; refreshing token once');
    if (token.refreshToken == null) {
      _markExpired('Access token rejected (401) and no refresh token is available.');
      throw AuthRequiredException(sourceId, 'The $displayName session expired. Please reconnect.');
    }
    token = await forceRefresh(cancel: cancel);
    response = await _http.send(
      method,
      uri,
      headers: {...?headers, ...authHeaders(token)},
      body: body,
      retry: retry,
      cancel: cancel,
    );
    if (response.statusCode == 401) {
      _markExpired('Access token rejected (401) after refresh.');
      throw AuthRequiredException(sourceId, 'The $displayName session expired. Please reconnect.');
    }
    return response;
  }

  /// Authorized GET returning decoded JSON (throws [ApiException] for other
  /// non-2xx statuses).
  Future<Object?> authorizedGetJson(
    Uri uri, {
    Map<String, String>? headers,
    RetryPolicy retry = const RetryPolicy(),
    CancelToken? cancel,
  }) async {
    final response = await authorizedSend(
      'GET',
      uri,
      headers: {'Accept': 'application/json', ...?headers},
      retry: retry,
      cancel: cancel,
    );
    return FermataHttp.decodeJsonResponse(response);
  }

  /// Authorized form POST returning decoded JSON.
  Future<Object?> authorizedPostForm(
    Uri uri,
    Map<String, String> fields, {
    Map<String, String>? headers,
    CancelToken? cancel,
  }) async {
    final response = await authorizedSend(
      'POST',
      uri,
      headers: {'Accept': 'application/json', ...?headers},
      body: fields,
      retry: RetryPolicy.none,
      cancel: cancel,
    );
    return FermataHttp.decodeJsonResponse(response);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _credSub?.cancel();
    await _changes.close();
  }
}
