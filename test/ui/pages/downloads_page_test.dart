import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/pages/downloads/download_support.dart';
import 'package:fermata/ui/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'support/page_harness.dart';

DownloadTask _task(String id, DownloadStatus status, {int received = 0, int? total, double speed = 0, String? error, Track? track}) => DownloadTask(
      id: id,
      track: track ?? testTrack('t$id', title: 'Download $id', offline: OfflineRights.downloadable),
      status: status,
      createdAt: DateTime(2026, 10, 1),
      receivedBytes: received,
      totalBytes: total,
      bytesPerSecond: speed,
      error: error,
      completedAt: status == DownloadStatus.completed ? DateTime(2026, 10, 2) : null,
    );

Finder _tile(String id) => find.byKey(ValueKey('download-$id'));

Future<void> _tapIn(WidgetTester tester, String id, String tooltip) async {
  await tester.tap(find.descendant(of: _tile(id), matching: find.byTooltip(tooltip)));
  await settle(tester);
}

void main() {
  testWidgets('active queue with progress, speed and ETA; completed and failed', (tester) async {
    final kit = FakeKit();
    kit.downloads
      ..addTask(_task('1', DownloadStatus.downloading, received: 2 * 1024 * 1024, total: 4 * 1024 * 1024, speed: 512 * 1024))
      ..addTask(_task('2', DownloadStatus.completed, total: 6 * 1024 * 1024))
      ..addTask(_task('3', DownloadStatus.failed, error: 'not_audio'))
      ..addTask(_task('4', DownloadStatus.paused, received: 1024, total: 4096));
    await pumpPage(tester, kit: kit, route: '/downloads');
    expect(find.text('Downloading'), findsWidgets);
    expect(find.textContaining('2 MB of 4 MB'), findsOneWidget);
    expect(find.textContaining('512 KB/s'), findsOneWidget);
    expect(find.textContaining('0:04 left'), findsOneWidget);
    expect(find.descendant(of: _tile('1'), matching: find.byType(LinearProgressIndicator)), findsOneWidget);
    expect(find.textContaining("The service didn't send an audio file."), findsOneWidget);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('per-task pause / resume / retry / cancel / remove and bulk actions', (tester) async {
    final kit = FakeKit();
    kit.downloads
      ..addTask(_task('1', DownloadStatus.downloading, received: 10, total: 100))
      ..addTask(_task('2', DownloadStatus.failed, error: 'network_error'))
      ..addTask(_task('3', DownloadStatus.completed, total: 100));
    await pumpPage(tester, kit: kit, route: '/downloads');
    await _tapIn(tester, '1', 'Pause');
    expect(kit.downloads.calls, contains('pause'));
    expect(kit.downloads.tasks.first.status, DownloadStatus.paused);
    await _tapIn(tester, '1', 'Resume');
    expect(kit.downloads.calls, contains('resume'));
    await _tapIn(tester, '1', 'Cancel');
    expect(kit.downloads.calls, contains('cancel'));
    await _tapIn(tester, '2', 'Retry');
    expect(kit.downloads.calls, contains('retry'));
    await _tapIn(tester, '3', 'Remove download');
    expect(kit.downloads.calls, contains('deleteDownload'));

    kit.downloads.addTask(_task('5', DownloadStatus.downloading, total: 100));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Pause all'));
    await settle(tester);
    expect(kit.downloads.calls, contains('pauseAll'));
    await tester.tap(find.widgetWithText(FilledButton, 'Resume all'));
    await settle(tester);
    expect(kit.downloads.calls, contains('resumeAll'));
  });

  testWidgets('completed downloads play from the list', (tester) async {
    final kit = FakeKit();
    kit.downloads
      ..addTask(_task('1', DownloadStatus.completed, total: 100))
      ..addTask(_task('2', DownloadStatus.completed, total: 100));
    await pumpPage(tester, kit: kit, route: '/downloads');
    await _tapIn(tester, '2', 'Play');
    expect(kit.playback.argsOf('playTracks')[2], 'downloads');
  });

  testWidgets('filters', (tester) async {
    final kit = FakeKit();
    kit.downloads
      ..addTask(_task('1', DownloadStatus.queued))
      ..addTask(_task('2', DownloadStatus.completed, total: 1))
      ..addTask(_task('3', DownloadStatus.failed));
    await pumpPage(tester, kit: kit, route: '/downloads');
    await tester.tap(find.text('Completed'));
    await settle(tester);
    expect(_tile('2'), findsOneWidget);
    expect(_tile('1'), findsNothing);
    await tester.tap(find.text('Failed'));
    await settle(tester);
    expect(_tile('3'), findsOneWidget);
    expect(_tile('2'), findsNothing);
    await tester.tap(find.text('Active'));
    await settle(tester);
    expect(_tile('1'), findsOneWidget);
  });

  testWidgets('storage summary links to Settings → Storage', (tester) async {
    final kit = FakeKit(settings: const AppSettings(onboardingCompleted: true, storage: StorageSettings(downloadLimitMb: 100)));
    await pumpPage(tester, kit: kit, route: '/downloads');
    expect(find.text('Downloads (12 tracks)'), findsOneWidget);
    expect(find.text('50 MB'), findsOneWidget);
    expect(find.text('8 MB'), findsOneWidget);
    expect(find.text('100 MB'), findsOneWidget);
    await tester.tap(find.text('Storage settings'));
    await settle(tester);
    expect(tester.widget<SettingsPage>(find.byType(SettingsPage)).section, 'storage');
  });

  testWidgets('Wi-Fi-only waiting state is explained', (tester) async {
    final kit = FakeKit();
    kit.downloads.addTask(_task('1', DownloadStatus.waitingForNetwork));
    await pumpPage(tester, kit: kit, route: '/downloads');
    expect(find.text('Waiting for Wi-Fi'), findsOneWidget);
    expect(find.textContaining('Downloads only run on Wi-Fi'), findsOneWidget);
    await tester.tap(find.text('Download settings'));
    await settle(tester);
    expect(tester.widget<SettingsPage>(find.byType(SettingsPage)).section, 'downloads');
  });

  testWidgets('mobile data needs confirmation (dialog, once per visit)', (tester) async {
    final kit = FakeKit(settings: const AppSettings(onboardingCompleted: true, downloads: DownloadSettings(wifiOnly: false)));
    final dm = PolicyDownloadManager()..needsMobileDataConfirmation = true;
    dm.addTask(_task('1', DownloadStatus.waitingForNetwork));
    await pumpPage(tester, kit: kit, route: '/downloads', services: servicesWith(kit, downloads: dm));
    expect(find.text('Download over mobile data?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Wait for Wi-Fi'));
    await settle(tester);
    expect(dm.confirmations, 0);
    expect(find.text('Download over mobile data?'), findsNothing);
    // The banner keeps offering it.
    await tester.tap(find.widgetWithText(TextButton, 'Use mobile data'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Use mobile data'));
    await settle(tester);
    expect(dm.confirmations, 1);
    expect(find.text('Downloading over mobile data'), findsOneWidget);
  });

  test('optional manager extras degrade gracefully', () {
    final plain = FakeDownloadManager();
    expect(needsMobileDataConfirmation(plain), isNull);
    expect(confirmMobileData(plain), isFalse);
    expect(networkWaitReason(plain), isNull);
    final policy = PolicyDownloadManager()..networkWaitReason = DownloadStatus.paused;
    expect(networkWaitReason(policy), 'paused');
  });

  testWidgets('empty state explains what can be downloaded', (tester) async {
    await pumpPage(tester, kit: FakeKit(), route: '/downloads');
    expect(find.text('No downloads yet'), findsOneWidget);
    expect(find.textContaining('Audius and Jamendo'), findsOneWidget);
  });
}
