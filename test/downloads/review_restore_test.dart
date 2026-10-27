// Adversarial review: restoring completed downloads whose folder is only
// temporarily unavailable (external drive / SD card / NAS not mounted yet
// when the app starts).
import 'dart:io';

import 'package:fermata/core/models/download.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/test_server.dart';

void main() {
  late DownloadHarness h;

  setUp(() async => h = await DownloadHarness.start());
  tearDown(() async => h.dispose());

  Future<DownloadTask> downloadThenRestartWhileUnmounted(String sid) async {
    final first = h.create();
    await first.init();
    final task = await first.enqueue(h.serve(sid, ServedFile(fakeMp3(16 * 1024, seed: 51))));
    final done = await waitForStatus(first, task.id, DownloadStatus.completed);
    await first.dispose();

    final dir = h.paths.defaultDownloadDir;
    final parked = Directory('${dir.path}.unmounted');
    await dir.rename(parked.path); // drive not mounted at app start
    final second = h.create();
    await second.init();
    await parked.rename(dir.path); // drive mounted a moment later
    expect(await File(done.filePath!).exists(), isTrue);
    return done;
  }

  test('a download whose folder was briefly unavailable at startup is usable again once it is back', () async {
    final done = await downloadThenRestartWhileUnmounted('mount1');
    final m = h.create();
    await m.init(); // (a fresh instance with the drive present still sees the persisted "failed")
    expect(await m.localFileFor(done.trackId), done.filePath,
        reason: 'restore turned completed into failed(file_missing) permanently; '
            'status now ${taskById(m, done.id)?.status} / ${taskById(m, done.id)?.error}');
    expect(m.isDownloaded(done.trackId), isTrue);
  });

  test('retry() of a task flagged file_missing deletes the (present) file before re-authorizing', () async {
    final done = await downloadThenRestartWhileUnmounted('mount2');
    final m = h.create();
    await m.init();
    // The provider no longer authorizes the track (e.g. uploader disabled downloads).
    h.auths.remove('mount2');
    await m.retry(done.id);
    await waitForStatus(m, done.id, DownloadStatus.failed);
    expect(await File(done.filePath!).exists(), isTrue,
        reason: 'the only offline copy was deleted by retry() and can no longer be re-downloaded');
  });
}
