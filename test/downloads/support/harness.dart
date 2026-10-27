import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/net/http_client.dart';
import 'package:fermata/core/platform/app_paths.dart';
import 'package:fermata/core/sources/source_policies.dart';
import 'package:fermata/downloads/artwork/fermata_artwork_cache.dart';
import 'package:fermata/downloads/download_manager_impl.dart';
import 'package:fermata/downloads/download_options.dart';
import 'package:fermata/downloads/files/file_ops.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';

import 'fakes.dart';
import 'test_server.dart';

/// Fast timings for tests.
const testOptions = DownloadOptions(
  retryBaseDelay: Duration(milliseconds: 40),
  maxRetryDelay: Duration(milliseconds: 300),
  progressInterval: Duration(milliseconds: 250),
  indexWriteDebounce: Duration(milliseconds: 20),
  headerTimeout: Duration(seconds: 5),
  idleTimeout: Duration(seconds: 5),
  artworkTimeout: Duration(seconds: 5),
  syncOnInit: false,
);

/// Everything a download test needs: temp dirs, local server, fakes and a
/// manager factory (call [create] again to simulate an app restart).
class DownloadHarness {
  DownloadHarness._(this.root, this.server);

  static Future<DownloadHarness> start({AppSettings? settings}) async {
    final root = await Directory.systemTemp.createTemp('fermata_dl_');
    final h = DownloadHarness._(root, await TestAudioServer.start());
    h.settings = SettingsStore.inMemory(settings ?? const AppSettings());
    h.paths = AppPaths.forTesting(root);
    await h.paths.tempDownloadDir.create(recursive: true);
    await h.paths.artworkCacheDir.create(recursive: true);
    return h;
  }

  final Directory root;
  final TestAudioServer server;
  late final SettingsStore settings;
  late final AppPaths paths;
  final source = FakeSource();
  final tracks = FakeTrackRepository();
  final playlists = FakePlaylistRepository();
  final history = FakeHistoryRepository();
  final network = FakeNetworkStatus();
  final notifier = FakeNotifier();
  final http = FermataHttp();
  final _managers = <DownloadManagerImpl>[];

  /// The harness source is a stand-in for a provider that permits user-initiated
  /// and automatic downloads (no real remote provider does, see
  /// docs/COMPLIANCE.md); every other source id keeps its real policy.
  static SourcePolicy _policyOf(String id) => id == 'fake'
      ? const SourcePolicy(userInitiatedDownloads: true, automaticDownloads: true)
      : SourcePolicies.of(id);

  /// Authorization URLs per source track id (served by [server]).
  final auths = <String, DownloadAuthorization>{};

  DownloadManagerImpl create({DownloadOptions options = testOptions, FileMover? mover, OfflineArtworkStore? artwork}) {
    source.authorize = (t) => auths[t.sourceTrackId];
    final m = DownloadManagerImpl(
      sources: FakeRegistry([source]),
      tracks: tracks,
      playlists: playlists,
      history: history,
      settings: settings,
      paths: paths,
      http: http,
      network: network,
      notifier: notifier,
      options: options,
      fileMover: mover,
      artwork: artwork,
      sourcePolicies: _policyOf,
    );
    _managers.add(m);
    return m;
  }

  /// Serves [bytes] for track [sid] and registers its authorization.
  Track serve(
    String sid,
    ServedFile file, {
    String title = 'Song',
    String artist = 'Artist',
    String? album = 'Album',
    int? trackNumber = 1,
    int? expectedBytes,
    String? expectedSha256,
    String? ext,
    Uri? artworkUrl,
  }) {
    final uri = server.add('audio/$sid', file);
    auths[sid] = DownloadAuthorization(
      uri: uri,
      expectedBytes: expectedBytes,
      expectedSha256: expectedSha256,
      suggestedFileExtension: ext,
      headers: const {'Authorization': 'Bearer test-token'},
    );
    return remoteTrack(sid, title: title, artist: artist, album: album, trackNumber: trackNumber, artworkUrl: artworkUrl);
  }

  Future<void> dispose() async {
    for (final m in _managers) {
      await m.dispose();
    }
    await server.close();
    http.close();
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  }
}

DownloadTask? taskById(DownloadManagerImpl m, String id) => m.tasks.firstWhereOrNull((t) => t.id == id);

/// Waits until task [id] satisfies [test] (checks the current state first).
Future<DownloadTask> waitForTask(
  DownloadManagerImpl m,
  String id,
  bool Function(DownloadTask t) test, {
  Duration timeout = const Duration(seconds: 15),
}) {
  final now = taskById(m, id);
  if (now != null && test(now)) return Future.value(now);
  return m.tasksStream
      .map((list) => list.firstWhereOrNull((t) => t.id == id))
      .where((t) => t != null && test(t))
      .cast<DownloadTask>()
      .first
      .timeout(timeout, onTimeout: () => throw TimeoutException('Task $id: ${taskById(m, id)?.status}'));
}

Future<DownloadTask> waitForStatus(DownloadManagerImpl m, String id, DownloadStatus status,
        {Duration timeout = const Duration(seconds: 15)}) =>
    waitForTask(m, id, (t) => t.status == status, timeout: timeout);
