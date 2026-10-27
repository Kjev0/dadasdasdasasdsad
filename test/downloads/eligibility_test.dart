import 'dart:io';

import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';
import 'support/test_server.dart';

void main() {
  late DownloadHarness h;

  setUp(() async => h = await DownloadHarness.start());
  tearDown(() async => h.dispose());

  test('the four offline categories (+ already downloaded)', () async {
    final m = h.create();
    await m.init();

    final local = Track(
      sourceId: SourceIds.local,
      sourceTrackId: 'abc',
      title: 'Mine',
      localPath: '/music/mine.flac',
      availability: const TrackAvailability.local(),
    );
    expect((await m.checkEligibility(local)).kind, DownloadEligibilityKind.alreadyLocal);

    final allowed = await m.checkEligibility(remoteTrack('d1'));
    expect(allowed.kind, DownloadEligibilityKind.allowed);
    expect(allowed.canDownload, isTrue);

    final streamOnly =
        await m.checkEligibility(remoteTrack('s1', offline: OfflineRights.streamOnly, reason: 'not_downloadable'));
    expect(streamOnly.kind, DownloadEligibilityKind.streamOnly);
    expect(streamOnly.reason, 'not_downloadable');

    final unavailable = await m.checkEligibility(
        remoteTrack('u1', offline: OfflineRights.unavailable, reason: AvailabilityReason.regionRestricted));
    expect(unavailable.kind, DownloadEligibilityKind.unavailable);
    expect(unavailable.reason, AvailabilityReason.regionRestricted);

    final noSource = await m.checkEligibility(remoteTrack('x', sourceId: 'missing'));
    expect(noSource.kind, DownloadEligibilityKind.unavailable);

    final track = h.serve('done', ServedFile(fakeMp3(2048)));
    final task = await m.enqueue(track);
    await waitForStatus(m, task.id, DownloadStatus.completed);
    expect((await m.checkEligibility(track)).kind, DownloadEligibilityKind.alreadyDownloaded);
  });

  test('downloadable flag without the source capability / readiness is unavailable', () async {
    final m = h.create();
    await m.init();
    h.source.ready = false;
    final notReady = await m.checkEligibility(remoteTrack('r'));
    expect(notReady.kind, DownloadEligibilityKind.unavailable);
    expect(notReady.reason, AvailabilityReason.notAuthorized);
    h.source.ready = true;
    h.source.credentialsConfigured = false;
    expect((await m.checkEligibility(remoteTrack('r'))).reason, AvailabilityReason.credentialsMissing);
    h.source.credentialsConfigured = true;
    h.source.capabilities.remove(SourceCapability.download);
    expect((await m.checkEligibility(remoteTrack('r'))).kind, DownloadEligibilityKind.unavailable);
  });

  test('enqueue throws DownloadNotPermittedException for non-downloadable tracks; enqueueAll reports why', () async {
    final m = h.create();
    await m.init();
    final streamOnly = remoteTrack('s', offline: OfflineRights.streamOnly);
    await expectLater(m.enqueue(streamOnly), throwsA(isA<DownloadNotPermittedException>()));
    final local = Track(
        sourceId: SourceIds.local, sourceTrackId: 'l', title: 'L', availability: const TrackAvailability.local());
    await expectLater(m.enqueue(local), throwsA(isA<DownloadNotPermittedException>()));
    expect(m.tasks, isEmpty, reason: 'stream URLs are never queued');

    final ok = h.serve('ok', ServedFile(fakeMp3(1024)));
    final rejected = await m.enqueueAll([ok, streamOnly, local], origin: 'album:1');
    expect(rejected.keys, unorderedEquals([streamOnly.id, local.id]));
    expect(rejected[streamOnly.id]!.kind, DownloadEligibilityKind.streamOnly);
    expect(rejected[local.id]!.kind, DownloadEligibilityKind.alreadyLocal);
    expect(m.tasks.single.origin, 'album:1');
  });

  test('duplicate detection: same track id reuses the task', () async {
    final m = h.create();
    await m.init();
    final track = h.serve('dup', ServedFile(fakeMp3(64 * 1024), chunkSize: 4096, chunkDelay: const Duration(milliseconds: 2)));
    final a = await m.enqueue(track);
    final b = await m.enqueue(track);
    expect(b.id, a.id);
    expect(m.tasks, hasLength(1));
    await waitForStatus(m, a.id, DownloadStatus.completed);
    final c = await m.enqueue(track);
    expect(c.id, a.id);
    expect(c.status, DownloadStatus.completed);
    expect(h.server.file('audio/dup').requests, 1);
  });

  test('duplicate detection: identical bytes from two tracks are stored once', () async {
    final bytes = fakeMp3(48 * 1024, seed: 42);
    final m = h.create();
    await m.init();
    final t1 = h.serve('same1', ServedFile(bytes), title: 'Original');
    final t2 = h.serve('same2', ServedFile(bytes), title: 'Reupload', album: null);
    final a = await waitForStatus(m, (await m.enqueue(t1)).id, DownloadStatus.completed);
    final b = await waitForStatus(m, (await m.enqueue(t2)).id, DownloadStatus.completed);
    expect(b.filePath, a.filePath);
    expect(b.sha256, a.sha256);
    final files = h.paths.defaultDownloadDir.listSync(recursive: true).whereType<File>().toList();
    expect(files, hasLength(1));
    final usage = await m.storageUsage();
    expect(usage.downloadsBytes, bytes.length, reason: 'shared file counted once');
    expect(usage.downloadCount, 2);

    // Deleting one keeps the shared file for the other.
    await m.deleteDownload(t1.id);
    expect(await File(a.filePath!).exists(), isTrue);
    expect(await m.localFileFor(t2.id), a.filePath);
    await m.deleteDownload(t2.id);
    expect(await File(a.filePath!).exists(), isFalse);
    expect(h.paths.defaultDownloadDir.listSync(recursive: true), isEmpty, reason: 'empty folders removed');
  });

  test('a completed file deleted outside Fermata is detected and re-downloaded on enqueue', () async {
    final m = h.create();
    await m.init();
    final track = h.serve('ext', ServedFile(fakeMp3(4096)));
    final done = await waitForStatus(m, (await m.enqueue(track)).id, DownloadStatus.completed);
    await File(done.filePath!).delete();
    expect(await m.localFileFor(track.id), isNull);
    expect(m.isDownloaded(track.id), isFalse);
    final again = await m.enqueue(track);
    expect(again.id, done.id);
    await waitForStatus(m, done.id, DownloadStatus.completed);
    expect(await m.localFileFor(track.id), isNotNull);
  });
}
