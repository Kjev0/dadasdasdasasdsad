import 'package:fermata/app/providers.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/download.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/pages/settings/settings_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'settings_harness.dart';

class _FailingDownloads extends FakeDownloadManager {
  @override
  Future<void> changeDownloadDirectory(String newPath) async => throw const StorageException('no_space', 'Not enough space');
}

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('changing the download folder asks, moves via the download manager and stores the path', (tester) async {
    final dialogs = FakeFileDialogs()..directory = '/media/music/fermata';
    final kit = await pumpSettings(tester, section: 'downloads', dialogs: dialogs);
    await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('setting.downloadFolder')), matching: find.byType(FilledButton)));
    expect(dialogs.calls, ['pickDirectory']);
    expect(find.text(l10n.settingsDownloadFolderMoveTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, l10n.settingsDownloadFolderMove));
    await pumpFrames(tester);
    expect(kit.downloads.calls, contains('changeDownloadDirectory'));
    expect(kit.settingsStore.current.downloads.directory, '/media/music/fermata');
    expect(find.text(l10n.settingsDownloadFolderMoved), findsOneWidget);
  });

  testWidgets('a failed move keeps the old folder and explains', (tester) async {
    final dialogs = FakeFileDialogs()..directory = '/nope';
    final kit = FakeKit(settings: const AppSettings(onboardingCompleted: true, downloads: DownloadSettings(directory: '/old')));
    await pumpSettings(
      tester,
      kit: kit,
      section: 'downloads',
      dialogs: dialogs,
      overrides: [downloadManagerProvider.overrideWithValue(_FailingDownloads())],
    );
    await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('setting.downloadFolder')), matching: find.byType(FilledButton)));
    await tester.tap(find.widgetWithText(FilledButton, l10n.settingsDownloadFolderMove));
    await pumpFrames(tester);
    expect(kit.settingsStore.current.downloads.directory, '/old');
    expect(find.text(l10n.settingsDownloadFolderFailedDetail('Not enough space')), findsOneWidget);
  });

  testWidgets('downloads section explains the four offline categories and auto-download limits', (tester) async {
    await pumpSettings(tester, section: 'downloads');
    await scrollTo(tester, find.text(l10n.settingsAutoDownloadNote));
    expect(find.text(l10n.settingsOfflineStreamOnly), findsOneWidget);
    expect(find.text(l10n.settingsOfflineUnavailable), findsOneWidget);
    expect(find.text(l10n.settingsAutoDownloadNote), findsOneWidget);
  });

  testWidgets('warn on mobile data is disabled while downloads wait for Wi-Fi', (tester) async {
    final kit = await pumpSettings(tester, section: 'downloads');
    expect(find.text(l10n.settingsWarnMobileDisabled), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('setting.wifiOnly')));
    expect(kit.settingsStore.current.downloads.wifiOnly, isFalse);
    expect(find.text(l10n.settingsWarnMobileDisabled), findsNothing);
  });

  testWidgets('storage usage breakdown and maintenance actions', (tester) async {
    final kit = FakeKit();
    kit.downloads.usage = const StorageUsage(
      downloadsBytes: 3 * 1024 * 1024,
      downloadCount: 4,
      artworkCacheBytes: 1024 * 1024,
      streamCacheBytes: 0,
      databaseBytes: 4096,
      freeDiskBytes: 10 * 1024 * 1024 * 1024,
    );
    await pumpSettings(tester, kit: kit, section: 'storage');
    expect(kit.downloads.calls, contains('storageUsage'));
    expect(find.text(l10n.settingsUsageDownloads(4)), findsOneWidget);
    expect(find.text(l10n.settingsUsageFree(formatBytes(10 * 1024 * 1024 * 1024, locale: 'en'))), findsOneWidget);

    await scrollTo(tester, find.byKey(const ValueKey('settings.verifyDownloads')));
    await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.cleanUpNow')), matching: find.byType(FilledButton)));
    expect(kit.downloads.calls, contains('enforceStorageLimit'));
    expect(find.text(l10n.settingsNothingToClean), findsOneWidget);
    await pumpFrames(tester);
    await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.clearArtwork')), matching: find.byType(FilledButton)));
    expect(kit.downloads.calls, contains('clearArtworkCache'));
    await pumpFrames(tester);
    await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.verifyDownloads')), matching: find.byType(FilledButton)));
    expect(kit.downloads.calls, contains('verifyAll'));
    await pumpFrames(tester);
    expect(find.text(l10n.settingsVerifyOk), findsOneWidget);
  });

  testWidgets('auto clean-up needs a limit; picking a limit stores megabytes', (tester) async {
    final kit = await pumpSettings(tester, section: 'storage');
    expect(find.text(l10n.settingsAutoCleanupDisabled), findsOneWidget);
    final dropdown = find.descendant(of: find.byKey(const ValueKey('setting.downloadLimit')), matching: find.byType(DropdownButton<int>));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await pumpFrames(tester, count: 3);
    await tester.tap(find.text(formatMegabytes(5120, locale: 'en')).last);
    await pumpFrames(tester, count: 3);
    expect(kit.settingsStore.current.storage.downloadLimitMb, 5120);
    expect(find.text(l10n.settingsAutoCleanupDisabled), findsNothing);
  });
}
