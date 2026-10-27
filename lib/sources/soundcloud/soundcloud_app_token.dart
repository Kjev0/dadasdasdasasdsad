import 'package:logging/logging.dart';

import '../../core/contracts/auth.dart';
import '../../core/models/auth.dart';
import '../../core/util/cancel_token.dart';
import '../auth/oauth_errors.dart';
import '../auth/token_endpoint_client.dart';

final _log = Logger('sources.soundcloud.app_token');

/// App-only access token (OAuth `client_credentials`) for public SoundCloud
/// data — search, track/playlist pages, URL resolution and streaming —
/// when the user has not connected an account.
///
/// SoundCloud rules (API guide, verified 2026-10-27):
/// * credentials only via HTTP Basic for this grant ("Sending credentials in
///   the request body is not supported"), so the config passed in must set
///   `clientAuthInHeader`;
/// * at most 50 tokens per 12 h per app and 30 per hour per IP: the token is
///   cached in memory **and** in the [TokenStore] (under [storeKey]) so a
///   restart does not burn a new one, and it is renewed with its
///   `refresh_token` (form-encoded client credentials, as documented for the
///   refresh grant) before a new grant is requested.
class SoundCloudAppTokens {
  SoundCloudAppTokens({
    required TokenEndpointClient tokenEndpoint,
    required TokenStore store,
    required OAuthConfig Function() grantConfig,
    required OAuthConfig Function() refreshConfig,
    DateTime Function()? clock,
    this.leeway = const Duration(minutes: 2),
  }) : _endpoint = tokenEndpoint,
       _store = store,
       _grantConfig = grantConfig,
       _refreshConfig = refreshConfig,
       _clock = clock ?? DateTime.now;

  /// Key in the [TokenStore] (not a source id; ignored by sources).
  static const storeKey = 'soundcloud.app';

  final TokenEndpointClient _endpoint;
  final TokenStore _store;
  final OAuthConfig Function() _grantConfig;
  final OAuthConfig Function() _refreshConfig;
  final DateTime Function() _clock;

  /// Renew this long before `expiresAt`.
  final Duration leeway;

  OAuthToken? _token;
  bool _loaded = false;
  Future<OAuthToken>? _pending;
  int _generation = 0;

  bool _usable(OAuthToken t) {
    final exp = t.expiresAt;
    return exp == null || _clock().isBefore(exp.subtract(leeway));
  }

  /// A valid app token (cached, refreshed or newly granted).
  Future<OAuthToken> token({CancelToken? cancel}) async {
    final current = _token;
    if (current != null && _usable(current)) return current;
    return _pending ??= _obtain(rejected: null).whenComplete(() => _pending = null);
  }

  /// Called after the API rejected [rejected] with 401: obtains a new token
  /// unless another caller already did.
  Future<OAuthToken> renew(OAuthToken rejected, {CancelToken? cancel}) {
    final current = _token;
    if (current != null && current.accessToken != rejected.accessToken && _usable(current)) {
      return Future.value(current);
    }
    return _pending ??= _obtain(rejected: rejected).whenComplete(() => _pending = null);
  }

  Future<OAuthToken> _obtain({required OAuthToken? rejected}) async {
    final generation = _generation;
    if (!_loaded) {
      try {
        _token = await _store.read(storeKey);
      } catch (e) {
        _log.fine('Could not read the stored SoundCloud app token: ${e.runtimeType}');
      }
      _loaded = true;
      final stored = _token;
      if (stored != null && rejected == null && _usable(stored)) return stored;
    }
    OAuthToken? fresh;
    final previous = _token;
    final refreshToken = previous?.refreshToken;
    if (previous != null && refreshToken != null && refreshToken.isNotEmpty) {
      try {
        fresh = await _endpoint.refresh(_refreshConfig(), previous);
      } on OAuthFlowException catch (e) {
        // Refresh tokens are single-use and may have been consumed; fall
        // back to a new grant.
        _log.fine('SoundCloud app token refresh rejected (${e.providerError}); requesting a new one');
      }
    }
    fresh ??= await _endpoint.clientCredentials(_grantConfig(), scopes: const []);
    if (generation != _generation) {
      // Credentials changed while we were waiting; do not keep a token that
      // belongs to the old client.
      return fresh;
    }
    _token = fresh;
    try {
      await _store.write(storeKey, fresh);
    } catch (e) {
      _log.fine('Could not persist the SoundCloud app token: ${e.runtimeType}');
    }
    return fresh;
  }

  /// Forgets the token (e.g. developer credentials changed).
  Future<void> clear() async {
    _generation++;
    _token = null;
    _loaded = true;
    _pending = null;
    try {
      await _store.delete(storeKey);
    } catch (e) {
      _log.fine('Could not delete the SoundCloud app token: ${e.runtimeType}');
    }
  }
}
