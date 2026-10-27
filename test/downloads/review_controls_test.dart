// Adversarial review: user controls racing with the network policy, and the
// per-batch notification.
import 'dart:async';

import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/downloads/artwork/fermata_artwork_cache.dart';
import 'package:fermata/downloads/network/network_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/test_server.dart';

void main() {
  late DownloadHarness h;

  setUp(() async => h = await DownloadHarness.start());
  tearDown(() async => h.dispose());

  ServedFile slow(int seed) =>
      ServedFile(fakeMp3(512 * 1024, seed: seed), etag: '"s$seed"', chunkSize: 8192, chunkDelay: const Duration(milliseconds: 10));

  test('cancel() while a network-loss stop is in flight is lost: the task resumes and is stored', () async {
    final served = slow(41);
    final m = h.create();
    await m.init();
    final task = await m.enqueue(h.serve('race-cancel', served));
    await waitForTask(m, task.id, (t) => t.receivedBytes > 32 * 1024);

    // Wi-Fi drops; the manager stops the transfer with intent "network".
    h.network.state = const NetworkState.offline();
    await Future<void>.delayed(Duration.zero); // policy listener has run, transfer not yet unwound
    await m.cancel(task.id); // the user cancels in the same moment

    final afterCancel = taskById(m, task.id)!;
    expect(afterCancel.status, DownloadStatus.canceled,
        reason: 'cancel() returned but the task is ${afterCancel.status} (stop intent "network" wins)');
  });

  test('pause() while a network-loss stop is in flight is lost: the task auto-resumes on Wi-Fi', () async {
    final served = slow(42);
    final m = h.create();
    await m.init();
    final task = await m.enqueue(h.serve('race-pause', served));
    await waitForTask(m, task.id, (t) => t.receivedBytes > 32 * 1024);

    h.network.state = const NetworkState.offline();
    await Future<void>.delayed(Duration.zero);
    await m.pause(task.id);
    expect(taskById(m, task.id)!.status, DownloadStatus.paused,
        reason: 'pause() returned but the task is ${taskById(m, task.id)!.status}');
  });

  test('failures of an earlier batch are not reported in a later batch notification', () async {
    final m = h.create();
    await m.init();

    // Batch 1: a single download that fails (HTML page) → no notification.
    final bad = await m.enqueue(h.serve('bad', ServedFile(htmlPage())));
    await waitForStatus(m, bad.id, DownloadStatus.failed);
    await m.idle;
    expect(h.notifier.shown, isEmpty);

    // Batch 2 (later): one successful download, no failures.
    final good = await m.enqueue(h.serve('good', ServedFile(fakeMp3(4096, seed: 43)), title: 'Fine'));
    await waitForStatus(m, good.id, DownloadStatus.completed);
    await m.idle;

    expect(h.notifier.shown, hasLength(1));
    expect(h.notifier.shown.single.title, 'Downloaded: Fine');
    expect(h.notifier.shown.single.body, isNull,
        reason: 'stale failure count from the previous batch: "${h.notifier.shown.single.body}"');
  });

  test('canceling after the cover was pinned leaks the pin (cover can never be evicted or cleared)', () async {
    final store = _PinRecorder();
    final m = h.create(artwork: store);
    await m.init();
    final cover = Uri.parse('https://example.invalid/cover.png');
    final track = h.serve('pinleak', ServedFile(fakeMp3(8192, seed: 44)), artworkUrl: cover);
    late String id;
    // The user cancels right after the cover was fetched (before finalize).
    store.onPin = () => unawaited(m.cancel(id));
    id = (await m.enqueue(track)).id;
    await waitForStatus(m, id, DownloadStatus.canceled);
    await m.idle;

    expect(m.isDownloaded(track.id), isFalse);
    expect(store.isPinned(cover), isFalse,
        reason: 'no completed download uses this cover, but it stays pinned until the task is removed');
  });
}

/// Records pins without touching the network.
class _PinRecorder implements OfflineArtworkStore {
  final pinned = <String>{};
  void Function()? onPin;

  @override
  Future<bool> pin(Uri url, {CancelToken? cancel}) async {
    pinned.add(url.toString());
    onPin?.call();
    return true;
  }

  @override
  Future<void> unpin(Uri url) async => pinned.remove(url.toString());

  @override
  bool isPinned(Uri url) => pinned.contains(url.toString());

  @override
  Future<int> sizeBytes() async => 0;

  @override
  Future<int> clearUnpinned() async => 0;

  @override
  Future<int> trimToLimit() async => 0;

  @override
  Future<void> dispose() async {}
}
