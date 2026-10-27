import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';

import '../../core/contracts/auth.dart';
import '../../core/errors.dart';
import '../../core/models/auth.dart';
import '../../core/net/http_client.dart';
import '../../core/platform/platform_info.dart';
import '../../core/util/cancel_token.dart';
import 'browser_launcher.dart';
import 'callback_page.dart';
import 'oauth_errors.dart';
import 'pkce.dart';
import 'token_endpoint_client.dart';

final _log = Logger('sources.auth.oauth');

/// Authorization code + PKCE (S256) client following RFC 8252 for native
/// apps: the user signs in on the provider's own page in the system browser
/// (desktop) or a Custom Tab (Android) — never in an embedded webview.
///
/// * Desktop ([RedirectStrategy.loopback]): a one-shot HTTP server on
///   `127.0.0.1:<port>` receives `/callback/<sourceId>`, answers with a small
///   bilingual page and is always closed afterwards (success, error, timeout,
///   cancel). `loopbackPort: 0` binds an ephemeral port (providers that allow
///   any loopback port, e.g. Spotify/Google).
/// * Android ([RedirectStrategy.customScheme]): `fermata://oauth/<sourceId>`
///   delivered by `app_links`. A config may force loopback for providers
///   that reject custom schemes.
///
/// Only one interactive flow runs at a time; starting another cancels the
/// previous one (they would share the loopback port).
class OAuthClientImpl implements OAuthClient {
  OAuthClientImpl({
    required FermataHttp http,
    PlatformInfo? platform,
    BrowserLauncher? launcher,
    DeepLinkStream? deepLinks,
    this.timeout = const Duration(minutes: 5),
    this.customScheme = 'fermata',
    String Function(String sourceId)? providerName,
    Random? random,
  }) : _platform = platform ?? PlatformInfo.current(),
       _tokens = TokenEndpointClient(http),
       _launcherOverride = launcher,
       _deepLinks = deepLinks ?? appLinksDeepLinks,
       _providerName = providerName ?? _defaultName,
       _random = random ?? Random.secure();

  final PlatformInfo _platform;
  final TokenEndpointClient _tokens;
  final BrowserLauncher? _launcherOverride;
  final DeepLinkStream _deepLinks;
  final String Function(String) _providerName;
  final Random _random;

  /// How long to wait for the user to finish signing in.
  final Duration timeout;

  /// Scheme for Android deep-link redirects.
  final String customScheme;

  _Flow? _active;

  BrowserLauncher get _launcher => _launcherOverride ?? systemBrowserLauncher(_platform);

  static const _knownNames = {
    'soundcloud': 'SoundCloud',
    'spotify': 'Spotify',
    'youtube': 'YouTube',
    'jamendo': 'Jamendo',
    'deezer': 'Deezer',
    'audius': 'Audius',
  };

  static String _defaultName(String id) => _knownNames[id] ?? (id.isEmpty ? id : id[0].toUpperCase() + id.substring(1));

  /// The token-endpoint client (exchange/refresh/revoke/client credentials).
  TokenEndpointClient get tokenEndpoint => _tokens;

  /// The redirect strategy used for [config] on this platform.
  RedirectStrategy strategyFor(OAuthConfig config) =>
      config.redirectStrategy ?? (_platform.isAndroid ? RedirectStrategy.customScheme : RedirectStrategy.loopback);

  @override
  String redirectUriFor(OAuthConfig config) {
    final override = config.redirectUriOverride;
    if (override != null && override.isNotEmpty) return override;
    switch (strategyFor(config)) {
      case RedirectStrategy.loopback:
        final port = config.loopbackPort == 0 ? '' : ':${config.loopbackPort}';
        return 'http://127.0.0.1$port/callback/${config.sourceId}';
      case RedirectStrategy.customScheme:
        return '$customScheme://oauth/${config.sourceId}';
    }
  }

  /// Builds the provider authorization URL (keeps query parameters already
  /// present on the endpoint).
  Uri buildAuthorizeUrl(OAuthConfig config, {required String redirectUri, required String state, PkcePair? pkce}) {
    final params = <String, String>{
      ...config.authorizeEndpoint.queryParameters,
      'response_type': 'code',
      'client_id': config.clientId,
      'redirect_uri': redirectUri,
      if (config.scopes.isNotEmpty) 'scope': config.scopes.join(config.scopeSeparator),
      'state': state,
      if (pkce != null) 'code_challenge': pkce.challenge,
      if (pkce != null) 'code_challenge_method': pkce.method,
      ...config.extraAuthorizeParams,
    };
    return config.authorizeEndpoint.replace(queryParameters: params);
  }

  @override
  Future<OAuthToken> authorize(OAuthConfig config) => authorizeWithCancel(config);

  /// [authorize] with cooperative cancellation (e.g. the user closed the
  /// "waiting for browser" dialog).
  Future<OAuthToken> authorizeWithCancel(OAuthConfig config, {CancelToken? cancel}) async {
    _active?.cancel();
    final flow = _Flow();
    _active = flow;
    StreamSubscription<void>? cancelSub;
    if (cancel != null) cancelSub = cancel.whenCanceled.asStream().listen((_) => flow.cancel());
    try {
      return switch (strategyFor(config)) {
        RedirectStrategy.loopback => await _loopbackFlow(config, flow),
        RedirectStrategy.customScheme => await _customSchemeFlow(config, flow),
      };
    } finally {
      await cancelSub?.cancel();
      if (identical(_active, flow)) _active = null;
    }
  }

  /// Cancels a running interactive flow (no-op when none is running).
  void cancelPending() => _active?.cancel();

  @override
  Future<OAuthToken> refresh(OAuthConfig config, OAuthToken token) => _tokens.refresh(config, token);

  @override
  Future<void> revoke(OAuthConfig config, OAuthToken token) => _tokens.revoke(config, token);

  // ---- Loopback (desktop) -------------------------------------------------

  Future<OAuthToken> _loopbackFlow(OAuthConfig config, _Flow flow) async {
    final target = _LoopbackTarget.of(config, redirectUriFor(config));
    final HttpServer server;
    try {
      server = await HttpServer.bind(target.address, target.port);
    } on SocketException catch (e) {
      throw OAuthFlowException(
        config.sourceId,
        OAuthFailure.portInUse,
        'Cannot listen on ${target.address.address}:${target.port} for the sign-in redirect '
        '(${e.osError?.message ?? e.message}). Another program is probably using this port — close it and try again.',
      );
    }
    final completer = Completer<HttpRequest>();
    final sub = server.listen((request) {
      if (request.uri.path == target.path && !completer.isCompleted) {
        completer.complete(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        unawaited(request.response.close().catchError((Object _) {}));
      }
    });
    HttpRequest? callback;
    try {
      final redirectUri = target.redirectUri(server.port);
      final pkce = config.usePkce ? PkcePair.generate(random: _random) : null;
      final state = generateOAuthState(random: _random);
      final url = buildAuthorizeUrl(config, redirectUri: redirectUri, state: state, pkce: pkce);
      _log.info('Starting ${config.sourceId} sign-in (loopback port ${server.port})');
      await _launch(config, url, flow);
      final request = await _await(config, completer.future, flow);
      callback = request;
      final token = await _finish(config, request.uri.queryParameters, state, redirectUri, pkce);
      await _respond(request, HttpStatus.ok, OAuthCallbackPage.success(_providerName(config.sourceId)));
      return token;
    } on Object catch (e) {
      if (callback != null) {
        await _respond(
          callback,
          HttpStatus.badRequest,
          OAuthCallbackPage.failure(
            _providerName(config.sourceId),
            e is FermataException ? e.message : 'unexpected error',
          ),
        );
      }
      rethrow;
    } finally {
      await sub.cancel();
      await server.close(force: true);
    }
  }

  static Future<void> _respond(HttpRequest request, int status, String html) async {
    try {
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.html
        ..headers.set('Cache-Control', 'no-store')
        ..write(html);
      await request.response.close();
    } catch (_) {
      // The browser may already have gone away; nothing to do.
    }
  }

  // ---- Custom scheme (Android) ---------------------------------------------

  Future<OAuthToken> _customSchemeFlow(OAuthConfig config, _Flow flow) async {
    final redirectUri = redirectUriFor(config);
    final expected = Uri.parse(redirectUri);
    final completer = Completer<Uri>();
    final sub = _deepLinks().listen((uri) {
      if (_sameRedirect(uri, expected) && !completer.isCompleted) completer.complete(uri);
    }, onError: (Object e) => _log.warning('Deep link stream error', e));
    try {
      final pkce = config.usePkce ? PkcePair.generate(random: _random) : null;
      final state = generateOAuthState(random: _random);
      final url = buildAuthorizeUrl(config, redirectUri: redirectUri, state: state, pkce: pkce);
      _log.info('Starting ${config.sourceId} sign-in (custom scheme)');
      await _launch(config, url, flow);
      final uri = await _await(config, completer.future, flow);
      return await _finish(config, uri.queryParameters, state, redirectUri, pkce);
    } finally {
      await sub.cancel();
    }
  }

  static bool _sameRedirect(Uri a, Uri b) {
    String norm(String p) => p.endsWith('/') && p.length > 1 ? p.substring(0, p.length - 1) : p;
    return a.scheme.toLowerCase() == b.scheme.toLowerCase() &&
        a.host.toLowerCase() == b.host.toLowerCase() &&
        norm(a.path) == norm(b.path);
  }

  // ---- Shared steps ------------------------------------------------------

  Future<void> _launch(OAuthConfig config, Uri url, _Flow flow) async {
    if (flow.isCancelled) throw _cancelled(config);
    try {
      await _launcher(url);
    } catch (e) {
      throw OAuthFlowException(
        config.sourceId,
        OAuthFailure.browserUnavailable,
        'Could not open the browser for signing in: $e',
      );
    }
  }

  Future<T> _await<T>(OAuthConfig config, Future<T> callback, _Flow flow) {
    final result = Completer<T>();
    final timer = Timer(timeout, () {
      if (!result.isCompleted) {
        result.completeError(
          OAuthFlowException(
            config.sourceId,
            OAuthFailure.timeout,
            'Sign-in was not completed within ${timeout.inMinutes} minutes.',
          ),
        );
      }
    });
    flow.onCancel = () {
      if (!result.isCompleted) result.completeError(_cancelled(config));
    };
    if (flow.isCancelled) flow.onCancel!();
    callback.then(
      (v) {
        if (!result.isCompleted) result.complete(v);
      },
      onError: (Object e, StackTrace st) {
        if (!result.isCompleted) result.completeError(e, st);
      },
    );
    return result.future.whenComplete(() {
      timer.cancel();
      flow.onCancel = null;
    });
  }

  OAuthFlowException _cancelled(OAuthConfig config) =>
      OAuthFlowException(config.sourceId, OAuthFailure.cancelled, 'Sign-in was cancelled.');

  /// Validates the redirect (state first — CSRF), then exchanges the code.
  Future<OAuthToken> _finish(
    OAuthConfig config,
    Map<String, String> params,
    String expectedState,
    String redirectUri,
    PkcePair? pkce,
  ) async {
    if (params['state'] != expectedState) {
      _log.warning('Rejected ${config.sourceId} redirect with mismatching state');
      throw OAuthFlowException(
        config.sourceId,
        OAuthFailure.stateMismatch,
        'The sign-in response did not match this request (state mismatch). Please try again.',
      );
    }
    final error = params['error'];
    if (error != null && error.isNotEmpty) {
      final description = params['error_description'];
      throw OAuthFlowException(
        config.sourceId,
        error == 'access_denied' ? OAuthFailure.accessDenied : OAuthFailure.providerError,
        error == 'access_denied'
            ? 'Access was declined on the provider page.'
            : 'The provider reported an error: $error${description == null ? '' : ' ($description)'}',
        providerError: error,
      );
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw OAuthFlowException(
        config.sourceId,
        OAuthFailure.missingCode,
        'The sign-in response had no authorization code.',
      );
    }
    return _tokens.exchangeCode(config, code: code, redirectUri: redirectUri, codeVerifier: pkce?.verifier);
  }
}

/// One interactive flow; cancelling completes its wait with an error.
class _Flow {
  bool isCancelled = false;
  void Function()? onCancel;

  void cancel() {
    if (isCancelled) return;
    isCancelled = true;
    onCancel?.call();
  }
}

/// Where the loopback server listens and which redirect URI it announces.
class _LoopbackTarget {
  _LoopbackTarget(this.address, this.port, this.path, this._host);

  /// Honours `redirectUriOverride` when it is itself a loopback URL (port and
  /// path are taken from it; no port = ephemeral).
  factory _LoopbackTarget.of(OAuthConfig config, String redirectUri) {
    final uri = Uri.tryParse(redirectUri);
    if (uri != null && uri.isScheme('http') && _isLoopbackHost(uri.host)) {
      final v6 = uri.host == '::1' || uri.host == '[::1]';
      return _LoopbackTarget(
        v6 ? InternetAddress.loopbackIPv6 : InternetAddress.loopbackIPv4,
        uri.hasPort ? uri.port : 0,
        uri.path.isEmpty ? '/' : uri.path,
        v6 ? '[::1]' : (uri.host == 'localhost' ? 'localhost' : '127.0.0.1'),
      );
    }
    return _LoopbackTarget(
      InternetAddress.loopbackIPv4,
      config.loopbackPort,
      '/callback/${config.sourceId}',
      '127.0.0.1',
    );
  }

  final InternetAddress address;
  final int port;
  final String path;
  final String _host;

  String redirectUri(int boundPort) => 'http://$_host:$boundPort$path';

  static bool _isLoopbackHost(String host) =>
      host == '127.0.0.1' || host == 'localhost' || host == '::1' || host == '[::1]';
}
