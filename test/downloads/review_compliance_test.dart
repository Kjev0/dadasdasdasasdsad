// Adversarial review: provider-terms compliance (docs/specs/downloads.md,
// "Compliance addendum (binding)") — eligibility and automatic downloads
// must consult `SourcePolicies.of(track.sourceId)`.
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/core/sources/source_policies.dart';
import 'package:fermata/downloads/download_manager_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';
import 'support/test_server.dart';

void main() {
  late DownloadHarness h;
  final managers = <DownloadManagerImpl>[];

  setUp(() async => h = await DownloadHarness.start());
  tearDown(() async {
    for (final m in managers) {
      await m.dispose();
    }
    managers.clear();
    await h.dispose();
  });

  /// A manager whose registry holds [source] (a source that, like Audius,
  /// declares `SourceCapability.download` and authorizes the track).
  Future<DownloadManagerImpl> managerWith(FakeSource source) async {
    final m = DownloadManagerImpl(
      sources: FakeRegistry([source]),
      tracks: h.tracks,
      playlists: h.playlists,
      history: h.history,
      settings: h.settings,
      paths: h.paths,
      http: h.http,
      network: h.network,
      notifier: h.notifier,
      options: testOptions,
    );
    managers.add(m);
    await m.init();
    return m;
  }

  /// Serves bytes for [sid] and makes [source] authorize it.
  Track servedTrack(FakeSource source, String sid) {
    final uri = h.server.add('audio/${source.id}/$sid', ServedFile(fakeMp3(8192)));
    source.authorize = (t) => DownloadAuthorization(uri: uri);
    return remoteTrack(sid, sourceId: source.id);
  }

  group('eligibility consults SourcePolicies', () {
    test('SoundCloud is never downloadable, even when the API says downloadable', () async {
      expect(SourcePolicies.of(SourceIds.soundcloud).allowsAnyDownload, isFalse);
      final source = FakeSource(id: SourceIds.soundcloud);
      final m = await managerWith(source);
      final track = servedTrack(source, 'sc-1');
      expect(track.availability.offline, OfflineRights.downloadable);

      final eligibility = await m.checkEligibility(track);
      expect(eligibility.canDownload, isFalse,
          reason: 'SoundCloud API terms forbid in-app downloads regardless of the uploader flag');
      await expectLater(m.enqueue(track), throwsA(isA<DownloadNotPermittedException>()));
      expect(m.tasks, isEmpty);
    });

    test('Deezer / unknown plugin sources (no download policy) are never allowed', () async {
      for (final id in [SourceIds.deezer, 'some_plugin']) {
        expect(SourcePolicies.of(id).allowsAnyDownload, isFalse);
        final source = FakeSource(id: id);
        final m = await managerWith(source);
        final track = servedTrack(source, '$id-1');
        final eligibility = await m.checkEligibility(track);
        expect(eligibility.canDownload, isFalse, reason: '$id has no download rights in SourcePolicies');
        final rejected = await m.enqueueAll([track]);
        expect(rejected.keys, contains(track.id));
        expect(m.tasks, isEmpty);
      }
    });
  });

  group('automatic downloads', () {
    test('syncAutoDownloads never enqueues tracks of sources without automaticDownloads (Audius)', () async {
      final policy = SourcePolicies.of(SourceIds.audius);
      expect(policy.userInitiatedDownloads, isTrue);
      expect(policy.automaticDownloads, isFalse);

      final source = FakeSource(id: SourceIds.audius);
      final m = await managerWith(source);
      final track = servedTrack(source, 'au-1');
      h.playlists.autoDownload.add(autoPlaylist('p1'));
      h.playlists.entries['p1'] = [track];

      await m.syncAutoDownloads();
      await m.idle;

      expect(m.tasks, isEmpty,
          reason: 'COMPLIANCE.md: auto-download playlists only download sources with automaticDownloads');
      expect(source.authorizeCalls, 0);
      expect(h.server.file('audio/${source.id}/au-1').requests, 0, reason: 'nothing may be fetched');
    });

    test('a user-initiated single Audius download is still allowed', () async {
      final source = FakeSource(id: SourceIds.audius);
      final m = await managerWith(source);
      final track = servedTrack(source, 'au-2');
      expect((await m.checkEligibility(track)).kind, DownloadEligibilityKind.allowed);
      final task = await m.enqueue(track);
      await waitForStatus(m, task.id, DownloadStatus.completed);
    });
  });
}
