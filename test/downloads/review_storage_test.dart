// Adversarial review: storage operations that can lose data or churn.
import 'dart:io';

import 'package:fermata/core/models/download.dart';
import 'package:fermata/downloads/download_manager_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fakes.dart';
import 'support/harness.dart';
import 'support/test_server.dart';

void main() {
  late DownloadHarness h;

  setUp(() async => h = await DownloadHarness.start());
  tearDown(() async => h.dispose());

  Future<DownloadTask> download(DownloadManagerImpl m, String sid, int size, {int seed = 1}) async {
    final track = h.serve(sid, ServedFile(fakeMp3(size, seed: seed)), title: 'Track $sid');
    final task = await m.enqueue(track);
    return waitForStatus(m, task.id, DownloadStatus.completed);
  }

  test('changeDownloadDirectory to the same folder via a symlinked path must not delete the downloads', () async {
    final m = h.create();
    await m.init();
    final done = await download(m, 'sym', 32 * 1024, seed: 11);
    final original = await File(done.filePath!).readAsBytes();

    // e.g. ~/Music is a symlink to /data/Music, and the folder picker returns
    // the other spelling of the same directory.
    final alias = p.join(h.root.path, 'music-alias');
    await Link(alias).create(h.paths.defaultDownloadDir.path);

    await m.changeDownloadDirectory(alias);

    final after = taskById(m, done.id)!;
    expect(await File(after.filePath!).exists(), isTrue,
        reason: 'the only copy of the download was deleted ("identical file already at target")');
    expect(await File(after.filePath!).readAsBytes(), original);
    expect(await m.localFileFor(done.trackId), isNotNull);
  });

  test('changeDownloadDirectory must not adopt (and later delete) a file Fermata did not create', () async {
    final m = h.create();
    await m.init();
    final done = await download(m, 'adopt', 16 * 1024, seed: 12);
    final bytes = await File(done.filePath!).readAsBytes();

    // The user's own music folder already contains an identical copy at the
    // same relative path (e.g. they copied it there earlier).
    final target = p.join(h.root.path, 'Music');
    final relative = p.relative(done.filePath!, from: h.paths.defaultDownloadDir.path);
    final usersFile = File(p.join(target, relative));
    await usersFile.parent.create(recursive: true);
    await usersFile.writeAsBytes(bytes);

    await m.changeDownloadDirectory(target);
    await m.deleteDownload(done.trackId);

    expect(await usersFile.exists(), isTrue,
        reason: 'deleting the offline copy deleted a pre-existing user file in the new directory');
  });

  test('auto-download sync with a storage limit does not re-download evicted tracks on every run', () async {
    // 1 MB limit, three ~600 KB tracks whose size is unknown up front
    // (Track.format == null, as for most remote tracks).
    await h.settings.update((s) => s.copyWith(storage: s.storage.copyWith(autoCleanup: true, downloadLimitMb: 1)));
    final tracks = [
      for (var i = 0; i < 3; i++) h.serve('churn$i', ServedFile(fakeMp3(600 * 1024, seed: 30 + i)), title: 'Churn $i'),
    ];
    h.playlists.autoDownload.add(autoPlaylist('limit'));
    h.playlists.entries['limit'] = tracks;
    final m = h.create();
    await m.init();

    await m.syncAutoDownloads();
    await m.idle;
    final afterFirst = [for (var i = 0; i < 3; i++) h.server.file('audio/churn$i').requests];

    // The next periodic run (every syncIntervalMinutes).
    await m.syncAutoDownloads();
    await m.idle;
    final afterSecond = [for (var i = 0; i < 3; i++) h.server.file('audio/churn$i').requests];

    expect(afterSecond, afterFirst,
        reason: 'tracks evicted by autoCleanup are re-enqueued and downloaded again on every sync '
            '(first run: $afterFirst requests, second: $afterSecond)');
  });
}
