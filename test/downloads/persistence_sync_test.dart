import 'dart:convert';
import 'dart:io';

import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/downloads/download_options.dart';
import 'package:fermata/downloads/notify/batch_notifier.dart';
import 'package:fermata/downloads/network/network_status.dart';
import 'package:fermata/downloads/store/download_index.dart';
import 'package:fermata/downloads/store/download_record.dart';
import 'package:fermata/downloads/sync/auto_download_scheduler.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fakes.dart';
import 'support/harness.dart';
import 'support/test_server.dart';

void main() {
  late DownloadHarness h;

  setUp(() async => h = await DownloadHarness.start());
  tearDown(() async => h.dispose());

  File indexFile() => File(p.join(h.paths.supportDir.path, 'downloads', 'index.json'));

  group('restart restoration', () {
    test('interrupted downloading task is restored as queued and resumes from the partial', () async {
      final bytes = fakeMp3(512 * 1024);
      final served = ServedFile(bytes, etag: '"r"', chunkSize: 8192, chunkDelay: const Duration(milliseconds: 10));
      final track = h.serve('restart', served);
      final first = h.create();
      await first.init();
      final task = await first.enqueue(track);
      await waitForTask(first, task.id, (t) => t.receivedBytes > 64 * 1024);
      await first.dispose(); // app quits mid-transfer

      final saved = jsonDecode(await indexFile().readAsString()) as Map;
      final entry = (saved['tasks'] as List).single as Map;
      expect(entry['status'], 'queued', reason: 'shutdown persists the task as queued');
      expect(entry['etag'], '"r"');
      final partialLength = await File(entry['partial'] as String).length();
      expect(partialLength, greaterThan(0));

      served.chunkDelay = Duration.zero;
      final second = h.create();
      await second.init();
      final restored = taskById(second, task.id)!;
      expect(restored.receivedBytes, anyOf(partialLength, greaterThanOrEqualTo(partialLength)));
      final done = await waitForStatus(second, task.id, DownloadStatus.completed);
      expect(await File(done.filePath!).readAsBytes(), bytes);
      expect(served.requestHeaders.last['range'], 'bytes=$partialLength-');
    });

    test('a hard crash ("downloading" in the index) is restored as queued', () async {
      final track = h.serve('crash', ServedFile(fakeMp3(4096)));
      final record = DownloadRecord(
        task: DownloadTask(id: 'crashed', track: track, status: DownloadStatus.downloading, createdAt: DateTime(2026)),
      );
      await indexFile().parent.create(recursive: true);
      await indexFile().writeAsString(jsonEncode({
        'version': 1,
        'tasks': [record.toJson()],
      }));
      final m = h.create();
      await m.init();
      await waitForStatus(m, 'crashed', DownloadStatus.completed);
    });

    test('completed, paused and failed tasks survive a restart; missing files are flagged', () async {
      final m = h.create();
      await m.init();
      final ok = await waitForStatus(m, (await m.enqueue(h.serve('k1', ServedFile(fakeMp3(4096))))).id,
          DownloadStatus.completed);
      final gone = await waitForStatus(m, (await m.enqueue(h.serve('k2', ServedFile(fakeMp3(4096, seed: 7)), title: 'Gone'))).id,
          DownloadStatus.completed);
      final failed = await waitForStatus(
          m, (await m.enqueue(h.serve('k3', ServedFile(htmlPage())))).id, DownloadStatus.failed);
      await m.dispose();
      await File(gone.filePath!).delete();

      final again = h.create();
      final ids = <Set<String>>[];
      await again.init();
      final sub = again.watchDownloadedIds().listen(ids.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(again.isDownloaded(ok.trackId), isTrue);
      expect(await again.localFileFor(ok.trackId), ok.filePath);
      expect(taskById(again, gone.id)!.status, DownloadStatus.failed);
      expect(taskById(again, gone.id)!.error, 'file_missing');
      expect(taskById(again, failed.id)!.error, 'not_audio');
      expect(ids.first, {ok.trackId});
      await sub.cancel();
    });

    test('corrupt index falls back to the backup; orphan partials are removed', () async {
      final m = h.create();
      await m.init();
      final done = await waitForStatus(m, (await m.enqueue(h.serve('b1', ServedFile(fakeMp3(2048))))).id,
          DownloadStatus.completed);
      await m.dispose();
      // Write once more so a .bak exists, then corrupt the main file.
      await DownloadIndex(indexFile()).flush(() => [
            DownloadRecord(task: done),
          ]);
      await indexFile().writeAsString('{"version":1,"tasks":[{broken');
      final orphan = File(p.join(h.paths.tempDownloadDir.path, 'orphan.part'))..writeAsBytesSync([1, 2, 3]);

      final again = h.create();
      await again.init();
      expect(again.isDownloaded(done.trackId), isTrue);
      expect(orphan.existsSync(), isFalse);
    });

    test('index writes are atomic (no temp file left behind)', () async {
      final index = DownloadIndex(indexFile(), debounce: const Duration(milliseconds: 5));
      final t = DownloadTask(id: 'x', track: remoteTrack('x'), status: DownloadStatus.paused, createdAt: DateTime(2026));
      final record = DownloadRecord(task: t, etag: '"e"', partialPath: '/tmp/x.part', nextAttemptAt: DateTime(2026, 2));
      await index.flush(() => [record]);
      await index.flush(() => [record]);
      expect(File('${indexFile().path}.tmp').existsSync(), isFalse);
      expect(File('${indexFile().path}.bak').existsSync(), isTrue);
      final loaded = (await index.load()).single;
      expect(loaded.task.status, DownloadStatus.paused);
      expect(loaded.etag, '"e"');
      expect(loaded.nextAttemptAt, DateTime(2026, 2));
      expect(loaded.task.track, t.track);
    });
  });

  group('auto-download playlists', () {
    test('syncAutoDownloads enqueues only permitted, missing tracks with a playlist origin', () async {
      final allowed1 = h.serve('p1', ServedFile(fakeMp3(4096)), title: 'One');
      final allowed2 = h.serve('p2', ServedFile(fakeMp3(4096, seed: 2)), title: 'Two');
      final streamOnly = remoteTrack('p3', offline: OfflineRights.streamOnly);
      final unavailable = remoteTrack('p4', offline: OfflineRights.unavailable);
      h.playlists.autoDownload.add(autoPlaylist('pl'));
      h.playlists.entries['pl'] = [allowed1, streamOnly, allowed2, unavailable];
      final m = h.create();
      await m.init();
      await m.syncAutoDownloads();
      expect(m.tasks.map((t) => t.trackId), [allowed1.id, allowed2.id]);
      expect(m.tasks.map((t) => t.origin), everyElement('playlist:pl'));
      for (final t in m.tasks) {
        await waitForStatus(m, t.id, DownloadStatus.completed);
      }
      // Second sync: nothing missing → nothing new.
      await m.syncAutoDownloads();
      expect(m.tasks, hasLength(2));
    });

    test('runs on init and never on metered networks when wifi-only', () async {
      h.playlists.autoDownload.add(autoPlaylist('pl'));
      h.playlists.entries['pl'] = [h.serve('i1', ServedFile(fakeMp3(4096)))];
      h.network.state = const NetworkState.mobile();
      final m = h.create(
        options: DownloadOptions(
          retryBaseDelay: testOptions.retryBaseDelay,
          indexWriteDebounce: testOptions.indexWriteDebounce,
          syncOnInit: true,
        ),
      );
      await m.init();
      await m.idle;
      expect(h.playlists.autoDownloadCalls, 0);
      expect(m.tasks, isEmpty);

      // Wi-Fi returns → the skipped sync runs automatically.
      h.network.state = const NetworkState.wifi();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await m.idle;
      expect(h.playlists.autoDownloadCalls, 1);
      expect(m.tasks, hasLength(1));
    });

    test('stops queuing when the storage limit is reached', () async {
      await h.settings.update((s) => s.copyWith(storage: s.storage.copyWith(downloadLimitMb: 1, autoCleanup: false)));
      final m = h.create();
      await m.init();
      final big = h.serve('big', ServedFile(fakeMp3(1024 * 1024 + 10)));
      await waitForStatus(m, (await m.enqueue(big)).id, DownloadStatus.completed);
      h.playlists.autoDownload.add(autoPlaylist('pl'));
      h.playlists.entries['pl'] = [h.serve('more', ServedFile(fakeMp3(4096)))];
      await m.syncAutoDownloads();
      expect(m.tasks, hasLength(1));
    });

    test('AutoDownloadScheduler follows performance.backgroundSync', () async {
      final store = SettingsStore.inMemory();
      var runs = 0;
      final scheduler = AutoDownloadScheduler(settings: store, sync: () async => runs++);
      scheduler.start();
      expect(scheduler.isScheduled, isTrue);
      await store.update((s) => s.copyWith(performance: s.performance.copyWith(backgroundSync: false)));
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.isScheduled, isFalse);
      await store.update((s) => s.copyWith(performance: s.performance.copyWith(backgroundSync: true, syncIntervalMinutes: 30)));
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.isScheduled, isTrue);
      await scheduler.stop();
      expect(runs, 0);
    });
  });

  group('notifications', () {
    test('one notification per batch', () async {
      final m = h.create();
      await m.init();
      final tracks = [
        for (var i = 0; i < 3; i++) h.serve('n$i', ServedFile(fakeMp3(8192, seed: i + 10)), title: 'N$i'),
      ];
      final tasks = [for (final t in tracks) await m.enqueue(t)];
      for (final t in tasks) {
        await waitForStatus(m, t.id, DownloadStatus.completed);
      }
      await m.idle;
      expect(h.notifier.shown, hasLength(1));
      expect(h.notifier.shown.single.title, '3 tracks downloaded');
      expect(h.notifier.shown.single.id, DownloadBatchNotifier.notificationId);

      // Next batch → next notification.
      final single = await m.enqueue(h.serve('n9', ServedFile(fakeMp3(1024, seed: 99)), title: 'Solo'));
      await waitForStatus(m, single.id, DownloadStatus.completed);
      await m.idle;
      expect(h.notifier.shown, hasLength(2));
      expect(h.notifier.shown.last.title, 'Downloaded: Solo');
    });

    test('respects notifyOnComplete / notifications.downloads and Danish locale', () async {
      final store = SettingsStore.inMemory(const AppSettings(localeCode: 'da'));
      final notifier = FakeNotifier();
      final batch = DownloadBatchNotifier(notifier: notifier, settings: store);
      final task = DownloadTask(id: '1', track: remoteTrack('1'), status: DownloadStatus.completed, createdAt: DateTime(2026));
      batch
        ..recordCompleted(task)
        ..recordCompleted(task)
        ..recordFailed(task);
      await batch.onQueueDrained();
      expect(notifier.shown.single.title, '2 numre downloadet');
      expect(notifier.shown.single.body, '1 download mislykkedes');

      await store.update((s) => s.copyWith(notifications: s.notifications.copyWith(downloads: false)));
      batch.recordCompleted(task);
      await batch.onQueueDrained();
      expect(notifier.shown, hasLength(1));

      final unsupported = FakeNotifier(isSupported: false);
      final b2 = DownloadBatchNotifier(notifier: unsupported, settings: SettingsStore.inMemory());
      b2.recordCompleted(task);
      await b2.onQueueDrained();
      expect(unsupported.shown, isEmpty);
    });
  });
}
