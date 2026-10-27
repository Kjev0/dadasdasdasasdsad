/// Typed failures shared across modules. UI maps these to localized messages
/// via their [code]; [message] is a developer-facing English description.
sealed class FermataException implements Exception {
  const FermataException(this.code, this.message, {this.cause});

  /// Stable, localizable code (e.g. `network_offline`).
  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType($code): $message${cause == null ? '' : ' — cause: $cause'}';
}

/// No connectivity, DNS failure, timeout, connection reset.
class NetworkException extends FermataException {
  const NetworkException(String message, {super.cause, this.isTimeout = false})
      : super(isTimeout ? 'network_timeout' : 'network_offline', message);

  final bool isTimeout;
}

/// The remote API answered with an unexpected status.
class ApiException extends FermataException {
  const ApiException(this.statusCode, String message, {this.body, super.cause})
      : super('api_error', message);

  final int statusCode;
  final String? body;
}

class RateLimitedException extends FermataException {
  const RateLimitedException(String message, {this.retryAfter})
      : super('rate_limited', message);

  final Duration? retryAfter;
}

/// The user must (re)connect their account.
class AuthRequiredException extends FermataException {
  const AuthRequiredException(this.sourceId, String message)
      : super('auth_required', message);

  final String sourceId;
}

/// Developer credentials (client id/secret, API key) are not configured.
class MissingCredentialsException extends FermataException {
  const MissingCredentialsException(this.sourceId, this.missing)
      : super('credentials_missing', 'Missing developer credentials for $sourceId: $missing');

  final String sourceId;
  final List<String> missing;
}

/// The source does not offer this operation (e.g. streaming Spotify audio).
class UnsupportedSourceOperation extends FermataException {
  const UnsupportedSourceOperation(this.sourceId, this.operation, String explanation)
      : super('unsupported_operation', explanation);

  final String sourceId;
  final String operation;
}

/// The track cannot be played. [reason] is an `AvailabilityReason` code.
class UnplayableTrackException extends FermataException {
  const UnplayableTrackException(this.trackId, this.reason, {String? message})
      : super('unplayable', message ?? 'Track $trackId is not playable ($reason)');

  final String trackId;
  final String reason;
}

class DownloadNotPermittedException extends FermataException {
  const DownloadNotPermittedException(this.trackId, this.reason)
      : super('download_not_permitted', 'Downloading $trackId is not permitted ($reason)');

  final String trackId;
  final String reason;
}

class StorageException extends FermataException {
  const StorageException(super.code, super.message, {super.cause});
}

class OperationCanceledException extends FermataException {
  const OperationCanceledException() : super('canceled', 'Operation was canceled');
}
