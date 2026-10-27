import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// A resource served by [TestAudioServer].
class ServedFile {
  ServedFile(
    this.bytes, {
    this.contentType = 'audio/mpeg',
    this.etag,
    this.lastModified,
    this.supportsRange = true,
    this.chunkSize = 16 * 1024,
    this.chunkDelay = Duration.zero,
    List<int>? statusSequence,
    this.retryAfterSeconds,
    this.disconnectAfterBytes,
    this.disconnects = 0,
    this.sendContentLength = true,
  }) : statusSequence = List.of(statusSequence ?? const []);

  Uint8List bytes;
  String contentType;
  String? etag;
  String? lastModified;
  bool supportsRange;
  int chunkSize;
  Duration chunkDelay;

  /// Statuses returned (one per request) before serving normally.
  final List<int> statusSequence;
  int? retryAfterSeconds;

  /// Drop the connection after this many body bytes, [disconnects] times.
  int? disconnectAfterBytes;
  int disconnects;
  bool sendContentLength;

  int requests = 0;
  final List<Map<String, String?>> requestHeaders = [];
  final List<DateTime> requestTimes = [];

  /// Bytes written by the server across all requests.
  int bytesSent = 0;
}

/// Local HTTP server for download tests: Range/If-Range, ETag, slow
/// streaming, mid-transfer disconnects, status sequences (404/429/500).
class TestAudioServer {
  TestAudioServer._(this._server) {
    _server.listen(_handle);
  }

  static Future<TestAudioServer> start() async =>
      TestAudioServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final _files = <String, ServedFile>{};

  Uri uri(String name) => Uri.parse('http://127.0.0.1:${_server.port}/$name');

  Uri add(String name, ServedFile file) {
    _files['/$name'] = file;
    return uri(name);
  }

  ServedFile file(String name) => _files['/$name']!;

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final file = _files[request.uri.path];
    try {
      if (file == null) {
        response.statusCode = 404;
        response.headers.contentType = ContentType.html;
        response.write('<html><body>Not found</body></html>');
        await response.close();
        return;
      }
      file.requests++;
      file.requestTimes.add(DateTime.now());
      file.requestHeaders.add({
        'range': request.headers.value('range'),
        'if-range': request.headers.value('if-range'),
        'user-agent': request.headers.value('user-agent'),
        'authorization': request.headers.value('authorization'),
      });
      if (file.statusSequence.isNotEmpty) {
        final status = file.statusSequence.removeAt(0);
        if (status != 200) {
          response.statusCode = status;
          if (status == 429 && file.retryAfterSeconds != null) {
            response.headers.set('retry-after', '${file.retryAfterSeconds}');
          }
          response.headers.contentType = ContentType.html;
          response.write('<html><body>Error $status</body></html>');
          await response.close();
          return;
        }
      }

      final total = file.bytes.length;
      var start = 0;
      var status = 200;
      final range = request.headers.value('range');
      if (range != null && file.supportsRange) {
        final ifRange = request.headers.value('if-range');
        final valid = ifRange == null || ifRange == file.etag || ifRange == file.lastModified;
        final m = RegExp(r'bytes=(\d+)-').firstMatch(range);
        if (valid && m != null) {
          start = int.parse(m.group(1)!);
          if (start >= total) {
            response.statusCode = 416;
            response.headers.set('content-range', 'bytes */$total');
            await response.close();
            return;
          }
          status = 206;
        }
      }

      final headers = <String, String>{
        'Content-Type': file.contentType,
        if (file.sendContentLength) 'Content-Length': '${total - start}',
        if (file.etag != null) 'ETag': file.etag!,
        if (file.lastModified != null) 'Last-Modified': file.lastModified!,
        if (file.supportsRange) 'Accept-Ranges': 'bytes',
        if (status == 206) 'Content-Range': 'bytes $start-${total - 1}/$total',
      };

      final dropAfter = file.disconnects > 0 ? file.disconnectAfterBytes : null;
      if (dropAfter != null) {
        file.disconnects--;
        // Write raw HTTP so the connection can be cut mid-body.
        final socket = await response.detachSocket(writeHeaders: false);
        final head = StringBuffer('HTTP/1.1 $status ${status == 206 ? 'Partial Content' : 'OK'}\r\n');
        headers.forEach((k, v) => head.write('$k: $v\r\n'));
        head.write('Connection: close\r\n\r\n');
        socket.add(ascii.encode(head.toString()));
        final end = min(total, start + dropAfter);
        socket.add(file.bytes.sublist(start, end));
        file.bytesSent += end - start;
        await socket.flush();
        socket.destroy();
        return;
      }

      response.statusCode = status;
      headers.forEach(response.headers.set);
      if (!file.sendContentLength) response.headers.chunkedTransferEncoding = true;
      var offset = start;
      while (offset < total) {
        final end = min(total, offset + file.chunkSize);
        response.add(file.bytes.sublist(offset, end));
        file.bytesSent += end - offset;
        offset = end;
        if (file.chunkDelay > Duration.zero) {
          await response.flush();
          await Future<void>.delayed(file.chunkDelay);
        }
      }
      await response.close();
    } catch (_) {
      // Client went away (cancel/pause) — expected in tests.
      try {
        await response.close();
      } catch (_) {}
    }
  }
}

/// Deterministic pseudo-random bytes.
Uint8List randomBytes(int length, {int seed = 1}) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
}

/// A small "MP3": empty ID3v2.4 tag + MPEG-1 Layer III frame header + noise.
Uint8List fakeMp3(int length, {int seed = 1}) {
  final b = randomBytes(length, seed: seed);
  const header = [0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFB, 0x90, 0x64];
  b.setRange(0, header.length, header);
  return b;
}

Uint8List fakeFlac(int length, {int seed = 2}) {
  final b = randomBytes(length, seed: seed);
  b.setRange(0, 4, ascii.encode('fLaC'));
  return b;
}

Uint8List htmlPage([int repeat = 20]) => Uint8List.fromList(utf8.encode(
    '<!DOCTYPE html><html><head><title>Login required</title></head><body>${'<p>Please sign in.</p>' * repeat}</body></html>'));

/// 1x1 PNG.
final Uint8List tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
