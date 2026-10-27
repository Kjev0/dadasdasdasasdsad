import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../core/errors.dart';
import '../../core/net/http_client.dart';
import '../../core/util/cancel_token.dart';
import '../download_errors.dart';
import '../integrity/audio_sniffer.dart';
import '../integrity/integrity.dart';

final _log = Logger('downloads.transfer');

/// Response metadata captured when headers arrive (persisted so a later
/// resume can send `If-Range`).
@immutable
class TransferHeaders {
  const TransferHeaders({this.etag, this.lastModified, this.contentType, this.totalBytes, required this.resumed});

  final String? etag;
  final String? lastModified;
  final String? contentType;

  /// Full size of the resource, when the server told us.
  final int? totalBytes;

  /// True when the server honoured the Range request (206).
  final bool resumed;
}

/// Result of a finished transfer (the partial file holds the whole body).
@immutable
class TransferResult {
  const TransferResult({required this.receivedBytes, required this.headers});

  final int receivedBytes;
  final TransferHeaders headers;
}

/// One resumable HTTP GET into a partial file.
///
/// * Resumes with `Range: bytes=<n>-` (+ `If-Range` with the stored ETag or
///   Last-Modified) when the partial file has content.
/// * `206` → append; `200` → the server ignored the range (or the resource
///   changed): restart from byte 0; `416` → already complete or stale.
/// * Aborts promptly on [CancelToken] (via `http.AbortableRequest`) and on
///   idle timeouts; a disconnect leaves the partial file for the next resume.
/// * Rejects text/HTML bodies as soon as the first bytes arrive.
class HttpTransfer {
  HttpTransfer({
    required FermataHttp http,
    this.headerTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 30),
  }) : _http = http;

  final FermataHttp _http;
  final Duration headerTimeout;
  final Duration idleTimeout;

  Future<TransferResult> run({
    required Uri uri,
    required File partial,
    Map<String, String> headers = const {},
    String? etag,
    String? lastModified,
    required CancelToken cancel,
    required void Function(int received, int? total) onProgress,
    void Function(TransferHeaders headers)? onHeaders,
  }) async {
    var offset = await partial.exists() ? await partial.length() : 0;
    // At most one restart (stale range / mismatching Content-Range).
    for (var pass = 0;; pass++) {
      cancel.throwIfCanceled();
      final request = http.AbortableRequest('GET', uri, abortTrigger: cancel.whenCanceled)
        ..headers['User-Agent'] = _http.userAgent
        ..headers['Accept-Encoding'] = 'identity'
        ..headers.addAll(headers);
      if (offset > 0) {
        request.headers['Range'] = 'bytes=$offset-';
        final validator = etag ?? lastModified;
        if (validator != null) request.headers['If-Range'] = validator;
      }

      final response = await _send(request, cancel);
      final status = response.statusCode;
      final contentType = response.headers['content-type'];
      final newEtag = response.headers['etag'];
      final newLastModified = response.headers['last-modified'];

      if (status == 416) {
        await _discard(response);
        final total = _parseContentRange(response.headers['content-range'])?.total;
        if (offset > 0 && total != null && total == offset) {
          final h = TransferHeaders(etag: etag, lastModified: lastModified, totalBytes: total, resumed: true);
          onHeaders?.call(h);
          return TransferResult(receivedBytes: offset, headers: h);
        }
        if (pass > 0) throw ApiException(status, 'Range not satisfiable for ${uri.host}');
        _log.fine('416 for a stale partial; restarting');
        await _truncate(partial);
        offset = 0;
        continue;
      }
      if (status == 429) {
        await _discard(response);
        throw RateLimitedException('Rate limited by ${uri.host}',
            retryAfter: parseRetryAfter(response.headers['retry-after']));
      }
      if (status != 200 && status != 206) {
        await _discard(response);
        throw ApiException(status, 'HTTP $status from ${uri.host}');
      }

      var append = false;
      int? total;
      if (status == 206) {
        final range = _parseContentRange(response.headers['content-range']);
        if (range == null || range.start != offset) {
          await _discard(response);
          if (pass > 0) throw ApiException(status, 'Unexpected Content-Range from ${uri.host}');
          _log.fine('Content-Range mismatch (${response.headers['content-range']}); restarting');
          await _truncate(partial);
          offset = 0;
          continue;
        }
        append = true;
        total = range.total ?? (response.contentLength == null ? null : offset + response.contentLength!);
      } else {
        if (offset > 0) _log.fine('Server ignored Range for ${uri.host}; restarting from byte 0');
        offset = 0;
        total = response.contentLength;
      }

      final transferHeaders = TransferHeaders(
        etag: newEtag ?? (append ? etag : null),
        lastModified: newLastModified ?? (append ? lastModified : null),
        contentType: contentType,
        totalBytes: total,
        resumed: append,
      );
      onHeaders?.call(transferHeaders);
      final received = await _receive(response, partial, append: append, offset: offset, total: total,
          cancel: cancel, onProgress: onProgress, host: uri.host);
      return TransferResult(receivedBytes: received, headers: transferHeaders);
    }
  }

  Future<http.StreamedResponse> _send(http.BaseRequest request, CancelToken cancel) async {
    try {
      return await _http.raw.send(request).timeout(headerTimeout);
    } on TimeoutException catch (e) {
      cancel.throwIfCanceled();
      throw NetworkException('Download request to ${request.url.host} timed out', cause: e, isTimeout: true);
    } on http.RequestAbortedException {
      throw const OperationCanceledException();
    } on FermataException {
      rethrow;
    } catch (e) {
      cancel.throwIfCanceled();
      throw NetworkException('Network error contacting ${request.url.host}', cause: e);
    }
  }

  Future<int> _receive(
    http.StreamedResponse response,
    File partial, {
    required bool append,
    required int offset,
    required int? total,
    required CancelToken cancel,
    required void Function(int received, int? total) onProgress,
    required String host,
  }) async {
    await partial.parent.create(recursive: true);
    final sink = partial.openWrite(mode: append ? FileMode.append : FileMode.write);
    var received = offset;
    // Only the start of the resource tells us whether it is audio.
    final head = offset == 0 ? BytesBuilder(copy: false) : null;
    var headChecked = head == null;
    Object? failure;
    StackTrace? failureStack;
    try {
      await for (final chunk in response.stream.timeout(idleTimeout)) {
        if (!headChecked) {
          head!.add(chunk);
          if (head.length >= AudioSniffer.earlyCheckLength) {
            headChecked = true;
            _rejectText(head.takeBytes());
          }
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      if (!headChecked && head!.isNotEmpty) _rejectText(head.takeBytes());
    } catch (e, st) {
      failure = e;
      failureStack = st;
    }
    try {
      await sink.flush();
      await sink.close();
    } on FileSystemException catch (e, st) {
      failure ??= e;
      failureStack ??= st;
    }
    if (failure == null) return received;
    if (cancel.isCanceled) throw const OperationCanceledException();
    switch (failure) {
      case FermataException():
      case FileSystemException():
        Error.throwWithStackTrace(failure, failureStack!);
      case TimeoutException():
        throw NetworkException('Download from $host stalled', cause: failure, isTimeout: true);
      default:
        throw NetworkException('Connection to $host lost after $received bytes', cause: failure);
    }
  }

  static void _rejectText(Uint8List head) {
    final sniff = AudioSniffer.sniff(head);
    if (!sniff.isAudio && sniff.looksLikeText) {
      throw const DownloadIntegrityException(DownloadErrorCode.notAudio, 'Server returned a text/HTML page instead of audio');
    }
  }

  static Future<void> _discard(http.StreamedResponse response) async {
    try {
      await response.stream.drain<void>().timeout(const Duration(seconds: 5));
    } catch (_) {
      // connection is dropped anyway
    }
  }

  static Future<void> _truncate(File f) async {
    if (await f.exists()) await f.writeAsBytes(const [], flush: true);
  }

  /// `bytes 100-199/1000`, `bytes 100-199/*`, `bytes */1000`.
  static ({int? start, int? total})? _parseContentRange(String? value) {
    if (value == null) return null;
    final m = RegExp(r'^\s*bytes\s+(?:(\d+)-(\d+)|\*)/(\d+|\*)\s*$', caseSensitive: false).firstMatch(value);
    if (m == null) return null;
    return (start: int.tryParse(m.group(1) ?? ''), total: int.tryParse(m.group(3)!));
  }

  /// Seconds or HTTP-date.
  static Duration? parseRetryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);
    try {
      final d = HttpDate.parse(value).difference(DateTime.now());
      return d.isNegative ? Duration.zero : d;
    } catch (_) {
      return null;
    }
  }
}
