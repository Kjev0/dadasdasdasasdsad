import 'dart:io';

import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/downloads/download_errors.dart';
import 'package:fermata/downloads/files/file_ops.dart';
import 'package:fermata/downloads/storage/free_space.dart';
import 'package:fermata/downloads/storage/storage_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fakes.dart';
import 'support/harness.dart';
import 'support/test_server.dart';

const _mb = 1024 * 1024;

void main() {
  late DownloadHarness h;

  setUp(() async => h = await DownloadHarness.start());
  tearDown(() async => h.dispose());

  Future<DownloadTask> download(dynamic m, String sid, int size, {int seed = 1}) async {
    final track = h.serve(sid, ServedFile(fakeMp3(size, seed: seed)), title: 'Track $sid');
    final task = await m.enqueue(track) as DownloadTask;
    return waitForStatus(m, task.id, DownloadStatus.completed);
  }

  test('enforceStorageLimit evicts least-recently-played first (history, else completedAt)', () async {
    await h.settings.update((s) => s.copyWith(storage: s.storage.copyWith(autoCleanup: false, downloadLimitMb: 2)));
    final m = h.create();
    await m.init();
    final a = await download(m, 'a', _mb, seed: 1);
    final b = await download(m, 'b', _mb, seed: 2);
    final c = await download(m, 'c', _mb, seed: 3);
    // a is the oldest download but was played most recently.
    h.history.played(a.track, DateTime.now().add(const Duration(minutes: 5)));
    h.history.played(c.track, DateTime.now().subtract(const Duration(days: 30)));

    final usage = await m.storageUsage();
    expect(usage.downloadsBytes, 3 * _mb);
    expect(usage.downloadLimitBytes, 2 * _mb);

    final freed = await m.enforceStorageLimit();
    expect(freed, greaterThanOrEqualTo(_mb));
    // b: completed before c and never played → least recently used.
    expect(m.isDownloaded(b.trackId), isFalse);
    expect(await File(b.filePath!).exists(), isFalse);
    expect(m.isDownloaded(a.trackId), isTrue);
    expect(m.isDownloaded(c.trackId), isTrue);
    expect((await m.storageUsage()).downloadsBytes, lessThanOrEqualTo(2 * _mb));
  });

  test('autoCleanup enforces the limit after each completed download, never evicting the new one', () async {
    await h.settings.update((s) => s.copyWith(storage: s.storage.copyWith(autoCleanup: true, downloadLimitMb: 1)));
    final m = h.create();
    await m.init();
    final first = await download(m, 'old', 700 * 1024, seed: 4);
    final second = await download(m, 'new', 700 * 1024, seed: 5);
    await m.idle;
    expect(m.isDownloaded(second.trackId), isTrue);
    expect(m.isDownloaded(first.trackId), isFalse);
    expect(await File(first.filePath!).exists(), isFalse);
  });

  test('StoragePolicy never evicts user-owned local tracks', () {
    final now = DateTime.now();
    DownloadTask completed(Track t, DateTime at) => DownloadTask(
          id: t.id,
          track: t,
          status: DownloadStatus.completed,
          createdAt: at,
          completedAt: at,
          filePath: '/x/${t.sourceTrackId}',
        );
    final local = Track(
        sourceId: SourceIds.local, sourceTrackId: 'l', title: 'L', availability: const TrackAvailability.local());
    final remote = remoteTrack('r');
    final order = StoragePolicy.evictionOrder(
      [completed(local, now.subtract(const Duration(days: 9))), completed(remote, now)],
      const {},
    );
    expect(order.map((t) => t.trackId), [remote.id]);
  });

  test('StoragePolicy.lastPlayed pages through history', () async {
    final t1 = remoteTrack('1');
    final t2 = remoteTrack('2');
    final base = DateTime(2026, 1, 1);
    for (var i = 0; i < 25; i++) {
      h.history.played(t1, base.add(Duration(hours: i)));
    }
    h.history.played(t2, base.subtract(const Duration(days: 1)));
    final result = await StoragePolicy.lastPlayed(h.history, {t1.id, t2.id}, pageSize: 10);
    expect(result[t1.id], base.add(const Duration(hours: 24)));
    expect(result[t2.id], base.subtract(const Duration(days: 1)));
  });

  test('changeDownloadDirectory moves files, keeps the layout, updates index and settings', () async {
    final m = h.create();
    await m.init();
    final a = await download(m, 'm1', 32 * 1024, seed: 1);
    final b = await download(m, 'm2', 32 * 1024, seed: 2);
    final target = p.join(h.root.path, 'new-music');
    await m.changeDownloadDirectory(target);

    expect(h.settings.current.downloads.directory, p.normalize(target));
    expect(m.downloadDirectory, p.normalize(target));
    for (final old in [a, b]) {
      final moved = taskById(m, old.id)!;
      expect(moved.filePath, p.join(target, p.relative(old.filePath!, from: h.paths.defaultDownloadDir.path)));
      expect(await File(moved.filePath!).exists(), isTrue);
      expect(await File(old.filePath!).exists(), isFalse);
      expect(await m.localFileFor(old.trackId), moved.filePath);
    }
    expect(h.paths.defaultDownloadDir.listSync(recursive: true), isEmpty);

    // New downloads go to the new directory; the move survives a restart.
    final c = await download(m, 'm3', 1024, seed: 3);
    expect(p.isWithin(target, c.filePath!), isTrue);
    await m.dispose();
    final restarted = h.create();
    await restarted.init();
    expect(await restarted.localFileFor(a.trackId), taskById(m, a.id)!.filePath);
  });

  test('changeDownloadDirectory rejects unwritable targets', () async {
    final m = h.create();
    await m.init();
    final blocker = File(p.join(h.root.path, 'not-a-dir'))..writeAsStringSync('x');
    await expectLater(m.changeDownloadDirectory(p.join(blocker.path, 'sub')), throwsA(isA<Exception>()));
  });

  test('cross-device move falls back to copy + delete', () async {
    final src = File(p.join(h.root.path, 'src.bin'))..writeAsBytesSync(randomBytes(4096));
    final mover = FileMover(
      rename: (f, t) async => throw FileSystemException('Invalid cross-device link', f.path, const OSError('EXDEV', 18)),
    );
    final target = p.join(h.root.path, 'other', 'dst.bin');
    final moved = await mover.move(src, target);
    expect(moved.path, target);
    expect(await File(target).readAsBytes(), randomBytes(4096));
    expect(await src.exists(), isFalse);
    expect(File('$target.part-move').existsSync(), isFalse);

    // Through the manager: completed downloads land via the copy fallback.
    final m = h.create(mover: mover);
    await m.init();
    final done = await download(m, 'xdev', 8192);
    expect(await File(done.filePath!).exists(), isTrue);
    expect(h.paths.tempDownloadDir.listSync(), isEmpty);
  });

  test('storageUsage reports downloads, artwork, database and free space', () async {
    final art = h.server.add('art.png', ServedFile(tinyPng, contentType: 'image/png'));
    final m = h.create();
    await m.init();
    final track = h.serve('u', ServedFile(fakeMp3(64 * 1024)), artworkUrl: art);
    await waitForStatus(m, (await m.enqueue(track)).id, DownloadStatus.completed);
    await h.paths.databaseFile.writeAsBytes(randomBytes(1000));
    final usage = await m.storageUsage();
    expect(usage.downloadsBytes, 64 * 1024);
    expect(usage.downloadCount, 1);
    expect(usage.artworkCacheBytes, greaterThanOrEqualTo(tinyPng.length));
    expect(usage.databaseBytes, 1000);
    expect(usage.streamCacheBytes, 0);
    expect(usage.downloadLimitBytes, isNull);
    if (Platform.isLinux) expect(usage.freeDiskBytes, greaterThan(0));
    expect(usage.totalBytes, greaterThan(usage.downloadsBytes));
  });

  test('FreeSpace.bytesAvailable works for missing subpaths', () async {
    final free = await FreeSpace.bytesAvailable(p.join(h.root.path, 'does', 'not', 'exist'));
    if (Platform.isLinux || Platform.isWindows) {
      expect(free, isNotNull);
      expect(free, greaterThan(0));
    }
  });

  test('verifyAll detects corrupted, truncated and missing files', () async {
    final m = h.create();
    await m.init();
    final ok = await download(m, 'v-ok', 8192, seed: 1);
    final corrupt = await download(m, 'v-bad', 8192, seed: 2);
    final truncated = await download(m, 'v-short', 8192, seed: 3);
    final missing = await download(m, 'v-gone', 8192, seed: 4);
    final raf = File(corrupt.filePath!).openSync(mode: FileMode.writeOnlyAppend)
      ..setPositionSync(4000)
      ..writeFromSync([1, 2, 3, 4]);
    raf.closeSync();
    await File(truncated.filePath!).writeAsBytes((await File(truncated.filePath!).readAsBytes()).sublist(0, 100));
    await File(missing.filePath!).delete();

    final broken = await m.verifyAll();
    expect(broken, unorderedEquals([corrupt.id, truncated.id, missing.id]));
    expect(taskById(m, corrupt.id)!.error, DownloadErrorCode.checksumMismatch);
    expect(taskById(m, truncated.id)!.error, DownloadErrorCode.sizeMismatch);
    expect(taskById(m, missing.id)!.error, DownloadErrorCode.fileMissing);
    expect(taskById(m, ok.id)!.status, DownloadStatus.completed);
    expect(m.isDownloaded(corrupt.trackId), isFalse);

    // Retry replaces the broken file with a fresh copy.
    await m.retry(corrupt.id);
    final fixed = await waitForStatus(m, corrupt.id, DownloadStatus.completed);
    expect(await m.verifyAll(), isEmpty);
    expect(fixed.sha256, corrupt.sha256);
  });

  test('directorySize and removeEmptyParents', () async {
    final dir = Directory(p.join(h.root.path, 'tree', 'a', 'b'))..createSync(recursive: true);
    File(p.join(dir.path, 'f'))..writeAsBytesSync(List.filled(10, 0));
    expect(await directorySize(Directory(p.join(h.root.path, 'tree'))), 10);
    File(p.join(dir.path, 'f')).deleteSync();
    await removeEmptyParents(dir.path, p.join(h.root.path, 'tree'));
    expect(Directory(p.join(h.root.path, 'tree')).existsSync(), isTrue);
    expect(Directory(p.join(h.root.path, 'tree', 'a')).existsSync(), isFalse);
  });
}
