import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fermata/core/models/download.dart';
import 'package:fermata/downloads/network/connectivity_network_status.dart';
import 'package:fermata/downloads/network/network_policy.dart';
import 'package:fermata/downloads/network/network_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/test_server.dart';

void main() {
  group('DownloadManagerImpl network policy', () {
    late DownloadHarness h;

    setUp(() async => h = await DownloadHarness.start());
    tearDown(() async => h.dispose());

    test('wifi-only: waits on mobile data and resumes automatically on Wi-Fi', () async {
      expect(h.settings.current.downloads.wifiOnly, isTrue, reason: 'default');
      h.network.state = const NetworkState.mobile();
      final m = h.create();
      await m.init();
      expect(m.isMetered, isTrue);
      final task = await m.enqueue(h.serve('w', ServedFile(fakeMp3(64 * 1024))));
      final waiting = await waitForStatus(m, task.id, DownloadStatus.waitingForNetwork);
      expect(waiting.isActive, isTrue);
      expect(m.networkWaitReason, NetworkWaitReason.wifiOnly);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(h.source.authorizeCalls, 0, reason: 'nothing transferred on cellular');
      expect(h.server.file('audio/w').requests, 0);

      h.network.state = const NetworkState.wifi();
      await waitForStatus(m, task.id, DownloadStatus.completed);
      expect(m.networkWaitReason, isNull);
    });

    test('a running transfer is suspended when the network becomes metered and resumes with Range', () async {
      final bytes = fakeMp3(512 * 1024);
      final served = ServedFile(bytes, etag: '"n"', chunkSize: 8192, chunkDelay: const Duration(milliseconds: 10));
      final m = h.create();
      await m.init();
      final task = await m.enqueue(h.serve('switch', served));
      await waitForTask(m, task.id, (t) => t.receivedBytes > 32 * 1024);
      h.network.state = const NetworkState.mobile();
      final waiting = await waitForStatus(m, task.id, DownloadStatus.waitingForNetwork);
      expect(waiting.receivedBytes, greaterThan(0));
      served.chunkDelay = Duration.zero;
      h.network.state = const NetworkState.wifi();
      await waitForStatus(m, task.id, DownloadStatus.completed);
      expect(served.requestHeaders.last['range'], 'bytes=${waiting.receivedBytes}-');
    });

    test('offline: waits without burning attempts', () async {
      h.network.state = const NetworkState.offline();
      final m = h.create();
      await m.init();
      final task = await m.enqueue(h.serve('off', ServedFile(fakeMp3(4096))));
      await waitForStatus(m, task.id, DownloadStatus.waitingForNetwork);
      expect(m.networkWaitReason, NetworkWaitReason.offline);
      h.network.state = const NetworkState(kind: NetworkKind.ethernet, isMetered: false);
      final done = await waitForStatus(m, task.id, DownloadStatus.completed);
      expect(done.attempts, 0);
    });

    test('mobile data allowed but warnOnMobileData: held until confirmed for the session', () async {
      await h.settings.update((s) => s.copyWith(downloads: s.downloads.copyWith(wifiOnly: false)));
      h.network.state = const NetworkState.mobile();
      final m = h.create();
      await m.init();
      final task = await m.enqueue(h.serve('confirm', ServedFile(fakeMp3(4096))));
      await waitForStatus(m, task.id, DownloadStatus.waitingForNetwork);
      expect(m.needsMobileDataConfirmation, isTrue);
      m.confirmMobileDataForSession();
      expect(m.needsMobileDataConfirmation, isFalse);
      await waitForStatus(m, task.id, DownloadStatus.completed);
    });

    test('mobile data allowed without warning downloads directly', () async {
      await h.settings
          .update((s) => s.copyWith(downloads: s.downloads.copyWith(wifiOnly: false, warnOnMobileData: false)));
      h.network.state = const NetworkState.mobile();
      final m = h.create();
      await m.init();
      expect(m.needsMobileDataConfirmation, isFalse);
      final task = await m.enqueue(h.serve('direct', ServedFile(fakeMp3(4096))));
      await waitForStatus(m, task.id, DownloadStatus.completed);
    });

    test('turning wifi-only off in settings releases waiting tasks', () async {
      h.network.state = const NetworkState.mobile();
      final m = h.create();
      await m.init();
      final task = await m.enqueue(h.serve('toggle', ServedFile(fakeMp3(4096))));
      await waitForStatus(m, task.id, DownloadStatus.waitingForNetwork);
      await h.settings
          .update((s) => s.copyWith(downloads: s.downloads.copyWith(wifiOnly: false, warnOnMobileData: false)));
      await waitForStatus(m, task.id, DownloadStatus.completed);
    });
  });

  group('ConnectivityNetworkStatus.mapResults', () {
    NetworkState map(List<ConnectivityResult> r, {bool mobile = true}) =>
        ConnectivityNetworkStatus.mapResults(r, mobilePlatform: mobile);

    test('none → offline', () {
      expect(map([ConnectivityResult.none]).isConnected, isFalse);
      expect(map([]).isConnected, isFalse);
    });

    test('wifi / ethernet are unmetered, even with VPN', () {
      expect(map([ConnectivityResult.wifi]), const NetworkState.wifi());
      expect(map([ConnectivityResult.vpn, ConnectivityResult.wifi]).isMetered, isFalse);
      expect(map([ConnectivityResult.ethernet]).kind, NetworkKind.ethernet);
    });

    test('mobile and satellite are metered', () {
      expect(map([ConnectivityResult.mobile]).isMetered, isTrue);
      expect(map([ConnectivityResult.vpn, ConnectivityResult.mobile]).isMetered, isTrue);
      expect(map([ConnectivityResult.wifi, ConnectivityResult.satellite]).isMetered, isTrue);
    });

    test('unknown transports: metered on Android, unmetered on desktop', () {
      expect(map([ConnectivityResult.other], mobile: true).isMetered, isTrue);
      expect(map([ConnectivityResult.bluetooth], mobile: false).isMetered, isFalse);
    });
  });
}
