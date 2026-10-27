import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/net/http_client.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/downloads/download_errors.dart';
import 'package:fermata/downloads/download_options.dart';
import 'package:fermata/downloads/files/path_builder.dart';
import 'package:fermata/downloads/integrity/audio_sniffer.dart';
import 'package:fermata/downloads/integrity/integrity.dart';
import 'package:fermata/downloads/transfer/http_transfer.dart';
import 'package:fermata/downloads/transfer/speed_meter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/test_server.dart';

Uint8List _bytes(List<int> head, [int pad = 64]) => Uint8List.fromList([...head, ...List.filled(pad, 7)]);

List<int> _a(String s) => ascii.encode(s);

void main() {
  group('AudioSniffer', () {
    test('recognises common audio containers', () {
      expect(AudioSniffer.sniff(fakeMp3(256)).container, AudioContainer.mp3);
      expect(AudioSniffer.sniff(_bytes([0xFF, 0xFB, 0x90, 0x64])).container, AudioContainer.mp3);
      expect(AudioSniffer.sniff(_bytes([0xFF, 0xF1, 0x50, 0x80])).container, AudioContainer.aac);
      expect(AudioSniffer.sniff(_bytes(_a('fLaC'))).container, AudioContainer.flac);
      expect(AudioSniffer.sniff(_bytes([..._a('RIFF'), 0, 0, 0, 0, ..._a('WAVE')])).container, AudioContainer.wav);
      expect(AudioSniffer.sniff(_bytes([..._a('FORM'), 0, 0, 0, 0, ..._a('AIFF')])).container, AudioContainer.aiff);
      expect(AudioSniffer.sniff(_bytes([0, 0, 0, 0x20, ..._a('ftypM4A ')])).container, AudioContainer.m4a);
      expect(AudioSniffer.sniff(_bytes([0x1A, 0x45, 0xDF, 0xA3])).container, AudioContainer.webm);
      expect(
          AudioSniffer.sniff(_bytes([0x30, 0x26, 0xB2, 0x75, 0x8E, 0x66, 0xCF, 0x11])).container, AudioContainer.wma);
    });

    test('distinguishes Ogg Opus / Vorbis / FLAC', () {
      List<int> ogg(List<int> packet) => [..._a('OggS'), ...List.filled(22, 0), 1, 30, ...packet];
      expect(AudioSniffer.sniff(_bytes(ogg(_a('OpusHead')))).container, AudioContainer.oggOpus);
      expect(AudioSniffer.sniff(_bytes(ogg([1, ..._a('vorbis')]))).container, AudioContainer.oggVorbis);
      expect(AudioSniffer.sniff(_bytes(ogg([0x7F, ..._a('FLAC')]))).container, AudioContainer.oggFlac);
      expect(AudioSniffer.sniff(_bytes(ogg(_a('OpusHead')))).extension, 'opus');
    });

    test('looks behind an ID3 tag (FLAC with ID3)', () {
      final tag = [0x49, 0x44, 0x33, 3, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0];
      expect(AudioSniffer.sniff(_bytes([...tag, ..._a('fLaC')])).container, AudioContainer.flac);
    });

    test('rejects HTML, JSON, XML and plain text', () {
      for (final body in [
        htmlPage(),
        utf8.encode('  \n<html><body>502 Bad Gateway</body></html>'),
        utf8.encode('{"error":"forbidden"}'),
        utf8.encode('<?xml version="1.0"?><Error><Code>AccessDenied</Code></Error>'),
        [0xEF, 0xBB, 0xBF, ...utf8.encode('<!doctype html>')],
        utf8.encode('Access denied. ' * 40),
      ]) {
        final r = AudioSniffer.sniff(body);
        expect(r.isAudio, isFalse, reason: utf8.decode(body, allowMalformed: true));
        expect(r.looksLikeText, isTrue);
      }
      expect(AudioSniffer.sniff(randomBytes(4096, seed: 3)).isAudio, isFalse);
    });

    test('extension helpers', () {
      expect(AudioSniffer.extensionForContentType('audio/mpeg; charset=binary'), 'mp3');
      expect(AudioSniffer.extensionForContentType('audio/x-flac'), 'flac');
      expect(AudioSniffer.extensionForContentType('text/html'), isNull);
      expect(AudioSniffer.normalizeExtension('.MP3'), 'mp3');
      expect(AudioSniffer.normalizeExtension('../../etc'), isNull);
      final flac = AudioSniffer.sniff(fakeFlac(64));
      expect(AudioSniffer.chooseExtension(suggested: 'ogg', contentType: 'audio/mpeg', sniffed: flac), 'ogg');
      expect(AudioSniffer.chooseExtension(contentType: 'audio/mpeg', sniffed: flac), 'flac');
      expect(AudioSniffer.chooseExtension(contentType: 'audio/mpeg'), 'mp3');
    });
  });

  group('FileNameSanitizer / DownloadPathBuilder', () {
    test('replaces Windows-illegal characters and control chars', () {
      expect(FileNameSanitizer.sanitize('a<b>c:d"e/f\\g|h?i*j\u0001k'), 'a_b_c_d_e_f_g_h_i_j_k');
    });

    test('Windows reserved names, trailing dots/spaces, leading dots', () {
      expect(FileNameSanitizer.sanitize('CON'), '_CON');
      expect(FileNameSanitizer.sanitize('nul.txt'), '_nul.txt');
      expect(FileNameSanitizer.sanitize('Lpt9'), '_Lpt9');
      expect(FileNameSanitizer.sanitize('Console'), 'Console');
      expect(FileNameSanitizer.sanitize('Hello. . .'), 'Hello');
      expect(FileNameSanitizer.sanitize('...And Justice for All'), 'And Justice for All');
      expect(FileNameSanitizer.sanitize('  '), 'Unknown');
      expect(FileNameSanitizer.sanitize('///', fallback: 'X'), 'X');
      expect(FileNameSanitizer.sanitize('..'), 'Unknown');
    });

    test('limits UTF-8 length without splitting characters', () {
      final long = 'æøå🎵' * 100;
      final s = FileNameSanitizer.sanitize(long);
      expect(utf8.encode(s).length, lessThanOrEqualTo(FileNameSanitizer.maxComponentBytes));
      expect(s.runes.every((r) => r != 0xFFFD), isTrue);
      expect(long.startsWith(s), isTrue);
    });

    test('layout <Artist>/<Album or Singles>/<NN - >Title.ext', () {
      Track t({String? album, int? no, int? disc, String? albumArtist}) => Track(
            sourceId: 'x',
            sourceTrackId: '1',
            title: 'Title',
            artists: const [ArtistRef('Artist'), ArtistRef('Feat')],
            album: album,
            albumArtist: albumArtist,
            trackNumber: no,
            discNumber: disc,
          );
      expect(DownloadPathBuilder.relativePathFor(t(album: 'LP', no: 7), 'flac'), p.join('Artist', 'LP', '07 - Title.flac'));
      expect(DownloadPathBuilder.relativePathFor(t(), 'mp3'), p.join('Artist', 'Singles', 'Title.mp3'));
      expect(DownloadPathBuilder.relativePathFor(t(album: 'LP', no: 2, disc: 2, albumArtist: 'VA'), 'mp3'),
          p.join('VA', 'LP', '2-02 - Title.mp3'));
      final long = Track(sourceId: 'x', sourceTrackId: '1', title: 'T' * 400, trackNumber: 1);
      final name = DownloadPathBuilder.fileNameFor(long, 'flac', copy: 12);
      expect(utf8.encode(name).length, lessThanOrEqualTo(FileNameSanitizer.maxComponentBytes));
      expect(name, endsWith(' (12).flac'));
      expect(p.split(DownloadPathBuilder.relativePathFor(long, 'mp3')).first, 'Unknown Artist');
    });

    test('uniqueTarget adds (2), (3) on collisions', () async {
      final dir = await Directory.systemTemp.createTemp('fermata_names_');
      addTearDown(() => dir.delete(recursive: true));
      final track = Track(sourceId: 'x', sourceTrackId: '1', title: 'Same', artists: const [ArtistRef('A')]);
      final first = await DownloadPathBuilder.uniqueTarget(dir.path, track, 'mp3');
      await File(first).create(recursive: true);
      final second = await DownloadPathBuilder.uniqueTarget(dir.path, track, 'mp3');
      expect(p.basename(second), 'Same (2).mp3');
      await File(second).create();
      expect(p.basename(await DownloadPathBuilder.uniqueTarget(dir.path, track, 'mp3')), 'Same (3).mp3');
    });
  });

  group('IntegrityChecker', () {
    test('verify computes SHA-256 and enforces size only when strict', () async {
      final dir = await Directory.systemTemp.createTemp('fermata_int_');
      addTearDown(() => dir.delete(recursive: true));
      final f = File(p.join(dir.path, 'a'))..writeAsBytesSync(fakeMp3(1000));
      final ok = await IntegrityChecker.verify(f, expectedBytes: 1000, declaredBytes: 1000);
      expect(ok.sha256, hasLength(64));
      await expectLater(IntegrityChecker.verify(f, expectedBytes: 999),
          throwsA(isA<DownloadIntegrityException>().having((e) => e.code, 'code', DownloadErrorCode.sizeMismatch)));
      final lenient = await IntegrityChecker.verify(f, expectedBytes: 999, expectedSha256: '00', strict: false);
      expect(lenient.sizeBytes, 1000);
      final html = File(p.join(dir.path, 'h'))..writeAsBytesSync(htmlPage());
      await expectLater(IntegrityChecker.verify(html, strict: false),
          throwsA(isA<DownloadIntegrityException>().having((e) => e.code, 'code', DownloadErrorCode.notAudio)));
    });
  });

  group('DownloadFailure.classify & backoff', () {
    test('maps exceptions to codes and retryability', () {
      expect(DownloadFailure.classify(const NetworkException('x')).retryable, isTrue);
      expect(DownloadFailure.classify(const NetworkException('x', isTimeout: true)).code, DownloadErrorCode.timeout);
      expect(DownloadFailure.classify(const ApiException(404, 'x')).retryable, isFalse);
      expect(DownloadFailure.classify(const ApiException(403, 'x')).code, DownloadErrorCode.forbidden);
      expect(DownloadFailure.classify(const ApiException(502, 'x')).retryable, isTrue);
      expect(DownloadFailure.classify(const ApiException(400, 'x')).retryable, isFalse);
      final rl = DownloadFailure.classify(const RateLimitedException('x', retryAfter: Duration(seconds: 7)));
      expect(rl.retryAfter, const Duration(seconds: 7));
      expect(DownloadFailure.classify(const DownloadIntegrityException('not_audio', 'x')).retryable, isFalse);
      expect(DownloadFailure.classify(const DownloadIntegrityException('checksum_mismatch', 'x')).retryable, isTrue);
      expect(DownloadFailure.classify(MissingCredentialsException('s', const ['id'])).code,
          DownloadErrorCode.credentialsMissing);
      expect(
          DownloadFailure.classify(const FileSystemException('full', '/x', OSError('ENOSPC', 28))).code,
          Platform.isWindows ? DownloadErrorCode.storage : DownloadErrorCode.diskFull);
    });

    test('exponential backoff with cap, Retry-After wins', () {
      const o = DownloadOptions(retryBaseDelay: Duration(seconds: 1), maxRetryDelay: Duration(seconds: 10));
      final d1 = o.backoff(1).inMilliseconds;
      final d3 = o.backoff(3).inMilliseconds;
      expect(d1, inInclusiveRange(800, 1200));
      expect(d3, inInclusiveRange(3200, 4800));
      expect(o.backoff(20).inMilliseconds, lessThanOrEqualTo(12000));
      expect(o.backoff(1, retryAfter: const Duration(seconds: 30)), const Duration(seconds: 30));
      expect(o.backoff(1, retryAfter: const Duration(days: 3)), o.maxRetryAfter);
    });

    test('Retry-After parsing', () {
      expect(HttpTransfer.parseRetryAfter('5'), const Duration(seconds: 5));
      expect(HttpTransfer.parseRetryAfter(HttpDate.format(DateTime.now().toUtc().add(const Duration(seconds: 30))))!
          .inSeconds, inInclusiveRange(28, 31));
      expect(HttpTransfer.parseRetryAfter('soon'), isNull);
    });
  });

  test('SpeedMeter smooths with an EMA', () async {
    final meter = SpeedMeter(window: const Duration(milliseconds: 20));
    expect(meter.bytesPerSecond, 0);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      meter.add(10000);
    }
    expect(meter.bytesPerSecond, greaterThan(50000));
    expect(meter.bytesPerSecond, lessThan(1000000));
  });

  group('HttpTransfer', () {
    late TestAudioServer server;
    late Directory dir;
    final http = FermataHttp();

    setUp(() async {
      server = await TestAudioServer.start();
      dir = await Directory.systemTemp.createTemp('fermata_tx_');
    });
    tearDown(() async {
      await server.close();
      await dir.delete(recursive: true);
    });

    test('an already-complete partial (416 with matching size) is accepted', () async {
      final bytes = fakeMp3(4096);
      final uri = server.add('full', ServedFile(bytes, etag: '"z"'));
      final partial = File(p.join(dir.path, 'x.part'))..writeAsBytesSync(bytes);
      final result = await HttpTransfer(http: http)
          .run(uri: uri, partial: partial, etag: '"z"', cancel: CancelToken(), onProgress: (_, _) {});
      expect(result.receivedBytes, bytes.length);
      expect(server.file('full').requestHeaders.single['range'], 'bytes=4096-');
      expect(await partial.readAsBytes(), bytes);
    });

    test('a stale partial larger than the resource restarts from 0', () async {
      final bytes = fakeMp3(2048);
      final uri = server.add('small', ServedFile(bytes));
      final partial = File(p.join(dir.path, 'y.part'))..writeAsBytesSync(fakeMp3(8192, seed: 4));
      await HttpTransfer(http: http).run(uri: uri, partial: partial, cancel: CancelToken(), onProgress: (_, _) {});
      expect(await partial.readAsBytes(), bytes);
    });

    test('chunked responses without Content-Length complete', () async {
      final bytes = fakeMp3(100 * 1024);
      final uri = server.add('chunked', ServedFile(bytes, sendContentLength: false));
      final partial = File(p.join(dir.path, 'c.part'));
      final result =
          await HttpTransfer(http: http).run(uri: uri, partial: partial, cancel: CancelToken(), onProgress: (_, _) {});
      expect(result.headers.totalBytes, isNull);
      expect(await partial.readAsBytes(), bytes);
    });

    test('HTML bodies are rejected early', () async {
      final uri = server.add('html',
          ServedFile(htmlPage(500), contentType: 'audio/mpeg', chunkSize: 1024, chunkDelay: const Duration(milliseconds: 5)));
      final partial = File(p.join(dir.path, 'h.part'));
      await expectLater(
        HttpTransfer(http: http).run(uri: uri, partial: partial, cancel: CancelToken(), onProgress: (_, _) {}),
        throwsA(isA<DownloadIntegrityException>()),
      );
      expect(server.file('html').bytesSent, lessThan(htmlPage(500).length));
    });

    test('idle timeout surfaces as a retryable network timeout', () async {
      final uri = server.add('stall',
          ServedFile(fakeMp3(64 * 1024), chunkSize: 1024, chunkDelay: const Duration(milliseconds: 400)));
      final partial = File(p.join(dir.path, 's.part'));
      final transfer = HttpTransfer(http: http, idleTimeout: const Duration(milliseconds: 150));
      await expectLater(
        transfer.run(uri: uri, partial: partial, cancel: CancelToken(), onProgress: (_, _) {}),
        throwsA(isA<NetworkException>().having((e) => e.isTimeout, 'isTimeout', isTrue)),
      );
      expect(await partial.length(), greaterThan(0), reason: 'kept for resume');
    });

    test('cancellation aborts promptly', () async {
      final uri = server.add('long',
          ServedFile(fakeMp3(1024 * 1024), chunkSize: 4096, chunkDelay: const Duration(milliseconds: 20)));
      final cancel = CancelToken();
      final partial = File(p.join(dir.path, 'l.part'));
      final future = HttpTransfer(http: http).run(
        uri: uri,
        partial: partial,
        cancel: cancel,
        onProgress: (received, _) {
          if (received > 8192) cancel.cancel();
        },
      );
      await expectLater(future.timeout(const Duration(seconds: 3)), throwsA(isA<OperationCanceledException>()));
    });
  });
}
