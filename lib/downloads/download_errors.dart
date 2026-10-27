import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/errors.dart';

/// Stable, localizable error codes stored in `DownloadTask.error`.
abstract final class DownloadErrorCode {
  /// The source did not authorize the download (or no longer does).
  static const notPermitted = 'download_not_permitted';

  /// The track's source is not registered / not available.
  static const sourceUnavailable = 'source_unavailable';
  static const authRequired = 'auth_required';
  static const credentialsMissing = 'credentials_missing';
  static const unavailable = 'unavailable';
  static const notFound = 'http_not_found';
  static const forbidden = 'http_forbidden';
  static const httpError = 'http_error';
  static const serverError = 'server_error';
  static const rateLimited = 'rate_limited';
  static const network = 'network_error';
  static const timeout = 'network_timeout';

  /// The body was not audio (HTML error page, captive portal, JSON, ...).
  static const notAudio = 'not_audio';
  static const sizeMismatch = 'size_mismatch';
  static const checksumMismatch = 'checksum_mismatch';

  /// A completed download's file was deleted or moved outside Fermata.
  static const fileMissing = 'file_missing';
  static const diskFull = 'disk_full';
  static const storage = 'storage_error';
  static const unknown = 'unknown';

  /// Automatic downloads are not permitted for the track's source (provider
  /// terms, see docs/COMPLIANCE.md).
  static const autoNotPermitted = 'automatic_downloads_not_permitted';
}

/// Carries a pre-classified [DownloadFailure] through the transfer pipeline.
class DownloadFailureException implements Exception {
  const DownloadFailureException(this.failure, [this.message]);

  final DownloadFailure failure;
  final String? message;

  @override
  String toString() => 'DownloadFailureException(${failure.code}${message == null ? '' : ': $message'})';
}

/// How a failed attempt is handled.
@immutable
class DownloadFailure {
  const DownloadFailure(this.code, {required this.retryable, this.retryAfter, this.discardPartial = false, this.cause});

  final String code;

  /// Transient (network, 5xx, 429, corrupted transfer): retried with backoff.
  final bool retryable;

  /// Server-mandated delay (429 `Retry-After`).
  final Duration? retryAfter;

  /// The partial file is unusable and must be restarted from byte 0.
  final bool discardPartial;
  final Object? cause;

  /// Maps an exception thrown by authorization, transfer or verification.
  static DownloadFailure classify(Object error) {
    switch (error) {
      case DownloadFailureException(:final failure):
        return failure;
      case DownloadNotPermittedException():
        return DownloadFailure(DownloadErrorCode.notPermitted, retryable: false, cause: error);
      case UnsupportedSourceOperation():
        return DownloadFailure(DownloadErrorCode.notPermitted, retryable: false, cause: error);
      case AuthRequiredException():
        return DownloadFailure(DownloadErrorCode.authRequired, retryable: false, cause: error);
      case MissingCredentialsException():
        return DownloadFailure(DownloadErrorCode.credentialsMissing, retryable: false, cause: error);
      case UnplayableTrackException():
        return DownloadFailure(DownloadErrorCode.unavailable, retryable: false, cause: error);
      case RateLimitedException(:final retryAfter):
        return DownloadFailure(DownloadErrorCode.rateLimited, retryable: true, retryAfter: retryAfter, cause: error);
      case NetworkException(:final isTimeout):
        return DownloadFailure(isTimeout ? DownloadErrorCode.timeout : DownloadErrorCode.network,
            retryable: true, cause: error);
      case ApiException(:final statusCode):
        if (statusCode == 404 || statusCode == 410) {
          return DownloadFailure(DownloadErrorCode.notFound, retryable: false, discardPartial: true, cause: error);
        }
        // Signed download URLs expire; every retry re-authorizes.
        if (statusCode == 401 || statusCode == 403) {
          return DownloadFailure(DownloadErrorCode.forbidden, retryable: true, cause: error);
        }
        if (statusCode >= 500 || statusCode == 408) {
          return DownloadFailure(DownloadErrorCode.serverError, retryable: true, cause: error);
        }
        return DownloadFailure(DownloadErrorCode.httpError, retryable: false, cause: error);
      case StorageException(:final code):
        // Integrity failures (subclass) and disk problems.
        final transient = code == DownloadErrorCode.sizeMismatch || code == DownloadErrorCode.checksumMismatch;
        return DownloadFailure(code, retryable: transient, discardPartial: true, cause: error);
      case FileSystemException():
        return DownloadFailure(isDiskFull(error) ? DownloadErrorCode.diskFull : DownloadErrorCode.storage,
            retryable: false, cause: error);
      case TimeoutException():
        return DownloadFailure(DownloadErrorCode.timeout, retryable: true, cause: error);
      case SocketException() || HttpException() || http.ClientException():
        return DownloadFailure(DownloadErrorCode.network, retryable: true, cause: error);
      default:
        return DownloadFailure(DownloadErrorCode.unknown, retryable: true, cause: error);
    }
  }

  /// ENOSPC (Linux/Android 28) or ERROR_DISK_FULL / ERROR_HANDLE_DISK_FULL
  /// (Windows 112 / 39).
  static bool isDiskFull(FileSystemException e) {
    final code = e.osError?.errorCode;
    if (code == null) return false;
    if (Platform.isWindows) return code == 112 || code == 39;
    return code == 28;
  }

  @override
  String toString() => 'DownloadFailure($code, retryable: $retryable)';
}

final _urlPattern = RegExp(r'''[a-zA-Z][a-zA-Z0-9+.-]*://[^\s"'<>)]+''');

/// Describes [error] for logs with the query/fragment (signatures, tokens) of
/// any URL stripped.
String redactUrls(Object? error) => '$error'.replaceAllMapped(_urlPattern, (m) {
      final url = m[0]!;
      final cut = url.indexOf(RegExp('[?#]'));
      return cut < 0 ? url : '${url.substring(0, cut)}?<redacted>';
    });
