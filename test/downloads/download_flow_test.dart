import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/downloads/download_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fakes.dart';
import 'support/harness.dart';
import 'support/test_server.dart';

void main() {
  late DownloadHarness h;

  setUp(() async => h = await DownloadHarness.start());
  tearDown(() async => h.dispose());

  test('enqueue → download → verify → completed file in Artist/Album layout', () async {
    final bytes = fakeMp3(200 * 1024);
    final artwork = h.server.add('art/cover.png', ServedFile(tinyPng, contentType: 'image/png'));
    final track = h.serve('t1', ServedFile(bytes, etag: '"v1"'),
        title: 'Hello: World?', artist: 'AC/DC', album: 'Back in Black', trackNumber: 3, artworkUrl: artwork);
    final m = h.create();
    await m.init();

    final idsFuture = m.watchDownloadedIds().firstWhere((ids) => ids.contains(track.id));
    final task = await m.enqueue(track);
    expect(task.status, anyOf(DownloadStatus.queued, DownloadStatus.downloading));

    final done = await waitForStatus(m, task.id, DownloadStatus.completed);
    expect(done.filePath, p.join(h.paths.defaultDownloadDir.path, 'AC_DC', 'Back in Black', '03 - Hello_ World_.mp3'));
    final file = File(done.filePath!);
    expect(await file.readAsBytes(), bytes);
    expect(done.sha256, sha256.convert(bytes).toString());
    expect(done.receivedBytes, bytes.length);
    expect(done.totalBytes, bytes.length);
    expect(done.completedAt, isNotNull);
    expect(done.progress, 1.0);

    // Re-authorized once, auth headers forwarded, User-Agent set.
    expect(h.source.authorizeCalls, 1);
    final req = h.server.file('audio/t1').requestHeaders.single;
    expect(req['authorization'], 'Bearer test-token');
    expect(req['user-agent'], startsWith('Fermata/'));

    expect(m.isDownloaded(track.id), isTrue);
    expect(await m.localFileFor(track.id), done.filePath);
    expect(await idsFuture, contains(track.id));

    // Library metadata updated with availability + format.
    final stored = h.tracks.tracks[track.id]!;
    expect(stored.availability.offline, OfflineRights.downloadable);
    expect(stored.availability.checkedAt, isNotNull);
    expect(stored.format?.fileSizeBytes, bytes.length);
    expect(stored.format?.codec, 'mp3');
    expect(stored.localPath, isNull, reason: 'downloaded copies are not user-owned local files');

    // Artwork downloaded once and pinned for offline use.
    expect(m.artwork.isPinned(artwork), isTrue);
    expect(h.server.file('art/cover.png').requests, 1);

    // Partial file is gone.
    expect(h.paths.tempDownloadDir.listSync(), isEmpty);
  });

  test('extension comes from authorization, then sniffing (octet-stream FLAC)', () async {
    final flac = fakeFlac(64 * 1024);
    final t1 = h.serve('a', ServedFile(flac, contentType: 'application/octet-stream'), title: 'Sniffed');
    final t2 = h.serve('b', ServedFile(fakeMp3(32 * 1024, seed: 9)), title: 'Suggested', ext: '.MP3');
    final m = h.create();
    await m.init();
    final a = await m.enqueue(t1);
    final b = await m.enqueue(t2);
    expect(p.basename((await waitForStatus(m, a.id, DownloadStatus.completed)).filePath!), '01 - Sniffed.flac');
    expect(p.basename((await waitForStatus(m, b.id, DownloadStatus.completed)).filePath!), '01 - Suggested.mp3');
  });

  test('HTML error page served as audio/mpeg fails integrity with not_audio', () async {
    final track = h.serve('html', ServedFile(htmlPage(), contentType: 'audio/mpeg'));
    final m = h.create();
    await m.init();
    final task = await m.enqueue(track);
    final failed = await waitForStatus(m, task.id, DownloadStatus.failed);
    expect(failed.error, DownloadErrorCode.notAudio);
    expect(h.source.authorizeCalls, 1, reason: 'not_audio is not retried');
    expect(m.isDownloaded(track.id), isFalse);
    expect(h.paths.defaultDownloadDir.listSync(recursive: true).whereType<File>(), isEmpty);
    expect(h.paths.tempDownloadDir.listSync(), isEmpty, reason: 'partial discarded');
  });

  test('size mismatch against expectedBytes and SHA-256 mismatch are detected', () async {
    final bytes = fakeMp3(50 * 1024);
    final wrongSize = h.serve('size', ServedFile(bytes), expectedBytes: bytes.length + 10);
    final wrongHash = h.serve('hash', ServedFile(fakeMp3(50 * 1024, seed: 3)), expectedSha256: 'ab' * 32);
    final m = h.create();
    await m.init();
    final a = await m.enqueue(wrongSize);
    final b = await m.enqueue(wrongHash);
    final fa = await waitForStatus(m, a.id, DownloadStatus.failed);
    final fb = await waitForStatus(m, b.id, DownloadStatus.failed);
    expect(fa.error, DownloadErrorCode.sizeMismatch);
    expect(fb.error, DownloadErrorCode.checksumMismatch);
    // Corrupted transfers are retried (re-authorized) up to the attempt limit.
    expect(fa.attempts, testOptions.maxAttempts);
    expect(h.server.file('audio/size').requests, testOptions.maxAttempts);
  });

  test('a matching expected SHA-256 passes', () async {
    final bytes = fakeMp3(40 * 1024, seed: 5);
    final track = h.serve('ok', ServedFile(bytes), expectedSha256: sha256.convert(bytes).toString().toUpperCase());
    final m = h.create();
    await m.init();
    final task = await m.enqueue(track);
    await waitForStatus(m, task.id, DownloadStatus.completed);
  });

  test('authorizeDownload returning null fails with download_not_permitted', () async {
    final track = remoteTrack('nope');
    final m = h.create();
    await m.init();
    final task = await m.enqueue(track);
    final failed = await waitForStatus(m, task.id, DownloadStatus.failed);
    expect(failed.error, DownloadErrorCode.notPermitted);
    expect(h.source.authorizeCalls, 1);
  });

  test('auth errors from the source are not retried', () async {
    h.source.authorizeError = const AuthRequiredException('fake', 'reconnect');
    final track = h.serve('auth', ServedFile(fakeMp3(1024)));
    final m = h.create();
    await m.init();
    final task = await m.enqueue(track);
    final failed = await waitForStatus(m, task.id, DownloadStatus.failed);
    expect(failed.error, DownloadErrorCode.authRequired);
    expect(h.source.authorizeCalls, 1);
  });

  test('progress is emitted at most ~4 Hz with an EMA speed', () async {
    final bytes = fakeMp3(400 * 1024);
    final track = h.serve('slow', ServedFile(bytes, chunkSize: 4096, chunkDelay: const Duration(milliseconds: 5)));
    final m = h.create();
    await m.init();
    final progressEvents = <DownloadTask>[];
    final sub = m.tasksStream.listen((list) {
      final t = list.single;
      if (t.status == DownloadStatus.downloading && t.receivedBytes > 0) progressEvents.add(t);
    });
    final watch = Stopwatch()..start();
    final task = await m.enqueue(track);
    await waitForStatus(m, task.id, DownloadStatus.completed);
    watch.stop();
    await sub.cancel();
    final seconds = watch.elapsedMilliseconds / 1000;
    expect(seconds, greaterThan(0.4));
    // 4 Hz plus one immediate emission at the start of the body.
    expect(progressEvents.length, lessThanOrEqualTo((seconds * 4).ceil() + 2));
    expect(progressEvents.length, greaterThanOrEqualTo(1));
    expect(progressEvents.any((t) => t.bytesPerSecond > 0), isTrue);
    final received = progressEvents.map((t) => t.receivedBytes).toList();
    expect(received, orderedEquals([...received]..sort()));
  });

  test('maxConcurrent limits parallel transfers', () async {
    await h.settings.update((s) => s.copyWith(downloads: s.downloads.copyWith(maxConcurrent: 1)));
    final slow = ServedFile(fakeMp3(120 * 1024), chunkSize: 8192, chunkDelay: const Duration(milliseconds: 5));
    final a = h.serve('c1', slow, title: 'One');
    final b = h.serve('c2', ServedFile(fakeMp3(120 * 1024, seed: 4), chunkSize: 8192), title: 'Two');
    final m = h.create();
    await m.init();
    var maxParallel = 0;
    final sub = m.tasksStream.listen((list) {
      final n = list.where((t) => t.status == DownloadStatus.downloading || t.status == DownloadStatus.verifying).length;
      if (n > maxParallel) maxParallel = n;
    });
    final ta = await m.enqueue(a);
    final tb = await m.enqueue(b);
    await waitForStatus(m, ta.id, DownloadStatus.completed);
    await waitForStatus(m, tb.id, DownloadStatus.completed);
    await sub.cancel();
    expect(maxParallel, 1);
  });
}
