import '../models/auth.dart';

/// Secure token persistence (Keystore on Android, DPAPI-backed storage on
/// Windows, Secret Service/libsecret on Linux).
abstract class TokenStore {
  Future<OAuthToken?> read(String sourceId);
  Future<void> write(String sourceId, OAuthToken token);
  Future<void> delete(String sourceId);
  Future<void> deleteAll();

  /// False when no secure backend is available (e.g. Linux without a
  /// Secret Service). Then tokens are kept in memory only for the session and
  /// the UI explains why the user must reconnect after restart.
  bool get isPersistent;
}

/// Developer credentials resolution. Precedence: user-entered (secure
/// storage) > config file (`<appSupport>/credentials.json`) > build-time
/// `--dart-define` values. Never committed to the repository.
abstract class CredentialsStore {
  Future<void> init();
  SourceCredentials? get(String sourceId);
  CredentialOrigin originOf(String sourceId);
  Future<void> setUserCredentials(String sourceId, SourceCredentials? credentials);
  Stream<String> get changes;

  /// Path of the optional credentials.json (for docs/UI).
  String get configFilePath;
}

/// Platform redirect strategy for OAuth (RFC 8252).
enum RedirectStrategy {
  /// `http://127.0.0.1:<port>/callback/<source>` served by an in-app HTTP
  /// server; system browser. Default on desktop.
  loopback,

  /// `fermata://oauth/<source>` deep link via app_links + Custom Tabs.
  /// Default on Android.
  customScheme,
}

class OAuthConfig {
  const OAuthConfig({
    required this.sourceId,
    required this.authorizeEndpoint,
    required this.tokenEndpoint,
    required this.clientId,
    required this.scopes,
    this.clientSecret,
    this.revokeEndpoint,
    this.usePkce = true,
    this.extraAuthorizeParams = const {},
    this.scopeSeparator = ' ',
    this.redirectStrategy,
    this.loopbackPort = 43821,
    this.redirectUriOverride,
    this.clientAuthInHeader = false,
  });

  final String sourceId;
  final Uri authorizeEndpoint;
  final Uri tokenEndpoint;
  final String clientId;
  final String? clientSecret;
  final List<String> scopes;
  final Uri? revokeEndpoint;
  final bool usePkce;
  final Map<String, String> extraAuthorizeParams;
  final String scopeSeparator;

  /// Null = platform default.
  final RedirectStrategy? redirectStrategy;

  /// Fixed port because most providers require exact redirect URIs.
  final int loopbackPort;
  final String? redirectUriOverride;

  /// Send client credentials with HTTP Basic auth instead of form fields.
  final bool clientAuthInHeader;
}

/// Runs authorization-code + PKCE flows and token refresh.
abstract class OAuthClient {
  /// Opens the system browser and waits for the redirect (default timeout
  /// 5 minutes). Validates `state`.
  Future<OAuthToken> authorize(OAuthConfig config);

  Future<OAuthToken> refresh(OAuthConfig config, OAuthToken token);

  Future<void> revoke(OAuthConfig config, OAuthToken token);

  /// The redirect URI that must be registered with the provider.
  String redirectUriFor(OAuthConfig config);
}
