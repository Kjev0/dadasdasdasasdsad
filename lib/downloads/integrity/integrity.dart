import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors.dart';
import '../download_errors.dart';
import 'audio_sniffer.dart';

/// A finished transfer failed verification. [code] is a
/// [DownloadErrorCode] (`not_audio`, `size_mismatch`, `checksum_mismatch`,
/// `file_missing`).
class DownloadIntegrityException extends StorageException {
  const DownloadIntegrityException(super.code, super.message);
}

/// Outcome of a successful [IntegrityChecker.verify].
@immutable
class VerifiedFile {
  const VerifiedFile({required this.sizeBytes, required this.sha256, required this.sniff});

  final int sizeBytes;

  /// Lower-case hex SHA-256 of the whole file.
  final String sha256;
  final SniffResult sniff;
}

/// Size, checksum and content-type verification for downloaded files.
abstract final class IntegrityChecker {
  /// Streams [file] through SHA-256 (constant memory). Lower-case hex.
  static Future<String> sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  /// Verifies [file]:
  /// * size equals every known expectation ([expectedBytes] from the source,
  ///   [declaredBytes] from Content-Length / Content-Range),
  /// * SHA-256 equals [expectedSha256] when given (the computed hash is
  ///   always returned so it can be stored),
  /// * the header is a recognised audio container (never an HTML page).
  ///
  /// With [strict] false only the audio sniff is enforced (the
  /// `downloads.verifyIntegrity` setting); the hash is still computed.
  static Future<VerifiedFile> verify(
    File file, {
    int? expectedBytes,
    int? declaredBytes,
    String? expectedSha256,
    bool strict = true,
  }) async {
    if (!await file.exists()) {
      throw const DownloadIntegrityException(DownloadErrorCode.fileMissing, 'Downloaded file disappeared');
    }
    final size = await file.length();
    if (size == 0) {
      throw const DownloadIntegrityException(DownloadErrorCode.sizeMismatch, 'Downloaded file is empty');
    }
    final sniff = await AudioSniffer.sniffFile(file);
    if (!sniff.isAudio) {
      throw DownloadIntegrityException(
        DownloadErrorCode.notAudio,
        sniff.looksLikeText ? 'Server returned a text/HTML page instead of audio' : 'Unrecognised file format',
      );
    }
    if (strict) {
      for (final expected in [expectedBytes, declaredBytes]) {
        if (expected != null && expected > 0 && expected != size) {
          throw DownloadIntegrityException(
              DownloadErrorCode.sizeMismatch, 'Expected $expected bytes but received $size');
        }
      }
    }
    final hash = await sha256Of(file);
    if (strict && expectedSha256 != null && expectedSha256.trim().toLowerCase() != hash) {
      throw const DownloadIntegrityException(DownloadErrorCode.checksumMismatch, 'SHA-256 does not match');
    }
    return VerifiedFile(sizeBytes: size, sha256: hash, sniff: sniff);
  }
}
