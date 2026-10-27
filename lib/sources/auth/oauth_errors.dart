import '../../core/errors.dart';

/// Why an interactive OAuth flow failed.
enum OAuthFailure {
  /// The user did not finish signing in within the time limit.
  timeout,

  /// The provider redirected back with a `state` that does not match the one
  /// we sent (possible CSRF / stale browser tab). The code is discarded.
  stateMismatch,

  /// The user declined access on the provider's page (`error=access_denied`).
  accessDenied,

  /// The provider returned another `error` in the redirect.
  providerError,

  /// The loopback port is already used by another program.
  portInUse,

  /// The system browser could not be opened.
  browserUnavailable,

  /// The redirect did not contain an authorization code.
  missingCode,

  /// The token endpoint rejected the code/refresh token or answered with
  /// something that is not a token.
  tokenRequestFailed,

  /// The flow was replaced by a newer one or explicitly cancelled.
  cancelled,
}

/// An interactive OAuth flow failed. It is an [AuthRequiredException] (code
/// `auth_required`) so generic UI handling ("reconnect") still applies;
/// [failure] lets the UI show a precise message.
class OAuthFlowException extends AuthRequiredException {
  const OAuthFlowException(super.sourceId, this.failure, super.message, {this.providerError});

  final OAuthFailure failure;

  /// The OAuth `error` code from the provider, when there was one.
  final String? providerError;

  @override
  String toString() => 'OAuthFlowException($sourceId, ${failure.name}): $message';
}
