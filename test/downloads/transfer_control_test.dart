import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fermata/core/models/download.dart';
import 'package:fermata/downloads/download_errors.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/test_server.dart';

void main() {
  late DownloadHarness h;

  setUp(() async => h = await DownloadHarness.start());
  tearDown(() async => h.dispose());

  test('pause keeps the partial; resume continues from the byte offset with If-Range', () async {
    final bytes = fakeMp3(512 * 1024);
    final served = ServedFile(bytes, etag: '"abc"', chunkSize: 8 * 1024, chunkDelay: const Duration(milliseconds: 10));
    final track = h.serve('p', served);
    final m = h.create();
    await m.init();
    final task = await m.enqueue(track);
    await waitForTask(m, task.id, (t) => t.receivedBytes >= 64 * 1024);
    await m.pause(task.id);

    final paused = taskById(m, task.id)!;
    expect(paused.status, DownloadStatus.paused);
    final partial = File('${h.paths.tempDownloadDir.path}/${task.id}.part');
    expect(await partial.exists(), isTrue);
    final offset = await partial.length();
    expect(offset, greaterThan(0));
    expect(offset, lessThan(bytes.length));
    expect(paused.receivedBytes, offset);

    served.chunkDelay = Duration.zero;
    await m.resume(task.id);
    final done = await waitForStatus(m, task.id, DownloadStatus.completed);
    expect(await File(done.filePath!).readAsBytes(), bytes);
    expect(done.sha256, sha256.convert(bytes).toString());

    final second = served.requestHeaders.last;
    expect(second['range'], 'bytes=$offset-');
    expect(second['if-range'], '"abc"');
    // Only the remainder was sent the second time.
    expect(served.bytesSent, lessThan(bytes.length * 2));
    expect(h.source.authorizeCalls, 2, reason: 're-authorized on resume');
  });

  test('If-Range falls back to Last-Modified when there is no ETag', () async {
    final bytes = fakeMp3(256 * 1024);
    const lm = 'Wed, 21 Oct 2026 07:28:00 GMT';
    final served = ServedFile(bytes, lastModified: lm, chunkSize: 8192, chunkDelay: const Duration(milliseconds: 10));
    final m = h.create();
    await m.init();
    final task = await m.enqueue(h.serve('lm', served));
    await waitForTask(m, task.id, (t) => t.receivedBytes > 16 * 1024);
    await m.pause(task.id);
    served.chunkDelay = Duration.zero;
    await m.resume(task.id);
    await waitForStatus(m, task.id, DownloadStatus.completed);
    expect(served.requestHeaders.last['if-range'], lm);
  });

  test('server that ignores Range restarts from byte 0 and still completes correctly', () async {
    final bytes = fakeMp3(256 * 1024);
    final served = ServedFile(bytes,
        etag: '"x"', supportsRange: false, chunkSize: 8192, chunkDelay: const Duration(milliseconds: 10));
    final m = h.create();
    await m.init();
    final task = await m.enqueue(h.serve('norange', served));
    await waitForTask(m, task.id, (t) => t.receivedBytes > 32 * 1024);
    await m.pause(task.id);
    served.chunkDelay = Duration.zero;
    await m.resume(task.id);
    final done = await waitForStatus(m, task.id, DownloadStatus.completed);
    expect(served.requestHeaders.last['range'], isNotNull);
    expect(await File(done.filePath!).readAsBytes(), bytes, reason: 'no spliced bytes');
  });

  test('changed resource (If-Range mismatch) restarts instead of splicing', () async {
    final v1 = fakeMp3(256 * 1024, seed: 1);
    final v2 = fakeMp3(256 * 1024, seed: 2);
    final served = ServedFile(v1, etag: '"v1"', chunkSize: 8192, chunkDelay: const Duration(milliseconds: 10));
    final m = h.create();
    await m.init();
    final task = await m.enqueue(h.serve('changed', served));
    await waitForTask(m, task.id, (t) => t.receivedBytes > 32 * 1024);
    await m.pause(task.id);
    served
      ..bytes = v2
      ..etag = '"v2"'
      ..chunkDelay = Duration.zero;
    await m.resume(task.id);
    final done = await waitForStatus(m, task.id, DownloadStatus.completed);
    expect(await File(done.filePath!).readAsBytes(), v2);
  });

  test('cancel aborts the transfer and deletes the partial file', () async {
    final served = ServedFile(fakeMp3(512 * 1024), chunkSize: 8192, chunkDelay: const Duration(milliseconds: 10));
    final m = h.create();
    await m.init();
    final task = await m.enqueue(h.serve('c', served));
    await waitForTask(m, task.id, (t) => t.receivedBytes > 16 * 1024);
    await m.cancel(task.id);
    final canceled = taskById(m, task.id)!;
    expect(canceled.status, DownloadStatus.canceled);
    expect(canceled.receivedBytes, 0);
    expect(h.paths.tempDownloadDir.listSync(), isEmpty);
    expect(h.paths.defaultDownloadDir.listSync(recursive: true).whereType<File>(), isEmpty);

    // Retry after cancel starts from scratch and completes.
    served.chunkDelay = Duration.zero;
    await m.retry(task.id);
    await waitForStatus(m, task.id, DownloadStatus.completed);
    expect(served.requestHeaders.last['range'], isNull);
  });

  test('cancel of a queued task and remove() of a finished one', () async {
    await h.settings.update((s) => s.copyWith(downloads: s.downloads.copyWith(maxConcurrent: 1)));
    final m = h.create();
    await m.init();
    final first = await m.enqueue(h.serve('q1', ServedFile(fakeMp3(256 * 1024),
        chunkSize: 8192, chunkDelay: const Duration(milliseconds: 5))));
    final second = await m.enqueue(h.serve('q2', ServedFile(fakeMp3(1024, seed: 8)), title: 'Second'));
    expect(taskById(m, second.id)!.status, DownloadStatus.queued);
    await m.cancel(second.id);
    expect(taskById(m, second.id)!.status, DownloadStatus.canceled);
    final done = await waitForStatus(m, first.id, DownloadStatus.completed);
    await m.remove(first.id);
    expect(taskById(m, first.id), isNull);
    expect(await File(done.filePath!).exists(), isFalse);
    expect(m.isDownloaded(done.trackId), isFalse);
  });

  test('mid-transfer disconnect is retried and resumed from the partial offset', () async {
    final bytes = fakeMp3(300 * 1024);
    final served = ServedFile(bytes, etag: '"d"', disconnectAfterBytes: 100 * 1024, disconnects: 2);
    final m = h.create();
    await m.init();
    final task = await m.enqueue(h.serve('drop', served));
    final done = await waitForStatus(m, task.id, DownloadStatus.completed);
    expect(await File(done.filePath!).readAsBytes(), bytes);
    expect(served.requests, 3);
    expect(served.requestHeaders[1]['range'], 'bytes=${100 * 1024}-');
    expect(served.requestHeaders[2]['range'], 'bytes=${200 * 1024}-');
    expect(served.bytesSent, bytes.length, reason: 'no byte transferred twice');
    expect(done.attempts, 2);
  });

  test('5xx is retried with exponential backoff and re-authorization', () async {
    final served = ServedFile(fakeMp3(8 * 1024), statusSequence: [500, 503]);
    final m = h.create();
    await m.init();
    final task = await m.enqueue(h.serve('flaky', served));
    final done = await waitForStatus(m, task.id, DownloadStatus.completed);
    expect(done.attempts, 2);
    expect(done.error, isNull);
    expect(h.source.authorizeCalls, 3, reason: 'every (re)start re-authorizes');
    final times = served.requestTimes;
    final gap1 = times[1].difference(times[0]);
    final gap2 = times[2].difference(times[1]);
    // base 40 ms ±20 %, then 80 ms ±20 %
    expect(gap1.inMilliseconds, greaterThanOrEqualTo(30));
    expect(gap2.inMilliseconds, greaterThanOrEqualTo(60));
  });

  test('gives up after 5 attempts with server_error', () async {
    final served = ServedFile(fakeMp3(1024), statusSequence: List.filled(10, 500));
    final m = h.create();
    await m.init();
    final task = await m.enqueue(h.serve('dead', served));
    final failed = await waitForStatus(m, task.id, DownloadStatus.failed);
    expect(failed.error, DownloadErrorCode.serverError);
    expect(failed.attempts, 5);
    expect(served.requests, 5);

    // Manual retry resets the attempt counter.
    served.statusSequence.clear();
    await m.retry(task.id);
    final done = await waitForStatus(m, task.id, DownloadStatus.completed);
    expect(done.attempts, 0);
  });

  test('429 respects Retry-After', () async {
    final served = ServedFile(fakeMp3(4096), statusSequence: [429], retryAfterSeconds: 1);
    final m = h.create();
    await m.init();
    final task = await m.enqueue(h.serve('limited', served));
    final queued = await waitForTask(m, task.id, (t) => t.error == DownloadErrorCode.rateLimited);
    expect(queued.status, DownloadStatus.queued);
    await waitForStatus(m, task.id, DownloadStatus.completed);
    final gap = served.requestTimes[1].difference(served.requestTimes[0]);
    expect(gap.inMilliseconds, greaterThanOrEqualTo(950));
  });

  test('404 fails immediately without retries', () async {
    final served = ServedFile(fakeMp3(1024), statusSequence: [404]);
    final m = h.create();
    await m.init();
    final task = await m.enqueue(h.serve('gone', served));
    final failed = await waitForStatus(m, task.id, DownloadStatus.failed);
    expect(failed.error, DownloadErrorCode.notFound);
    expect(served.requests, 1);
  });

  test('pauseAll / resumeAll', () async {
    final m = h.create();
    await m.init();
    final a = await m.enqueue(h.serve('pa', ServedFile(fakeMp3(256 * 1024),
        chunkSize: 8192, chunkDelay: const Duration(milliseconds: 10))));
    final b = await m.enqueue(h.serve('pb', ServedFile(fakeMp3(256 * 1024, seed: 6),
        chunkSize: 8192, chunkDelay: const Duration(milliseconds: 10)), title: 'B'));
    await waitForTask(m, a.id, (t) => t.receivedBytes > 0);
    await m.pauseAll();
    expect(m.tasks.map((t) => t.status), everyElement(DownloadStatus.paused));
    h.server.file('audio/pa').chunkDelay = Duration.zero;
    h.server.file('audio/pb').chunkDelay = Duration.zero;
    await m.resumeAll();
    await waitForStatus(m, a.id, DownloadStatus.completed);
    await waitForStatus(m, b.id, DownloadStatus.completed);
  });
}
