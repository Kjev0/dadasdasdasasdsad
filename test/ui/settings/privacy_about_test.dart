import 'dart:convert';
import 'dart:typed_data';

import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:fermata/ui/pages/settings/data_transfer.dart';
import 'package:fermata/ui/pages/settings/diagnostics.dart';
import 'package:fermata/ui/pages/settings/settings_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'settings_harness.dart';

PickedFile _file(String name, Object json) {
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
  return PickedFile(name: name, path: '/tmp/$name', read: () async => bytes);
}

void main() {
  final l10n = AppLocalizationsEn();

  group('privacy data controls', () {
    testWidgets('delete history and clear searches ask first', (tester) async {
      final kit = await pumpSettings(tester, section: 'privacy');
      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.deleteHistory')), matching: find.byType(FilledButton)));
      expect(find.text(l10n.settingsDeleteHistoryTitle), findsOneWidget);
      await tester.tap(find.text(l10n.actionCancel));
      await pumpFrames(tester);
      expect(kit.history.called('clearHistory'), isFalse);

      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.deleteHistory')), matching: find.byType(FilledButton)));
      await tester.tap(find.widgetWithText(FilledButton, l10n.actionDelete).last);
      await pumpFrames(tester);
      expect(kit.history.called('clearHistory'), isTrue);

      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.clearSearches')), matching: find.byType(FilledButton)));
      await tester.tap(find.widgetWithText(FilledButton, l10n.settingsClearAction).last);
      await pumpFrames(tester);
      expect(kit.searchHistory.called('clear'), isTrue);
    });

    testWidgets('delete all data needs the typed word, then signs out of services', (tester) async {
      final linked = oauthSource('linked', auth: const SourceAuthState(status: SourceConnectionStatus.connected, accountName: 'Ada'));
      final kit = FakeKit(sources: [linked]);
      await pumpSettings(tester, kit: kit, section: 'privacy');
      await scrollTo(tester, find.byKey(const ValueKey('settings.deleteAll')));
      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.deleteAll')), matching: find.byType(FilledButton)));
      final confirm = find.widgetWithText(FilledButton, l10n.settingsDeleteAllAction).last;
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'nope');
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), l10n.settingsDeleteAllWord);
      await tester.pump();
      await tester.tap(confirm);
      await pumpFrames(tester);
      expect(kit.maintenance.called('deleteAllUserData'), isTrue);
      expect(linked.calls, contains('disconnect'));
      expect(find.text(l10n.settingsDeleteAllDone), findsOneWidget);
    });

    testWidgets('export settings writes the JSON through the save dialog; import applies a file', (tester) async {
      final dialogs = FakeFileDialogs();
      final kit = FakeKit(settings: const AppSettings(onboardingCompleted: true, appearance: AppearanceSettings(accent: AccentChoice.coral)));
      await pumpSettings(tester, kit: kit, section: 'privacy', dialogs: dialogs);
      await scrollTo(tester, find.byKey(const ValueKey('settings.exportSettings')));
      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.exportSettings')), matching: find.byType(FilledButton)));
      final name = dialogs.saved.keys.single;
      expect(name, startsWith('fermata-settings-'));
      final exported = jsonDecode(utf8.decode(dialogs.saved[name]!)) as Map<String, Object?>;
      expect((exported['appearance'] as Map)['accent'], 'coral');

      dialogs.file = _file('s.json', (const AppSettings(appearance: AppearanceSettings(accent: AccentChoice.mint), onboardingCompleted: false)).toJson());
      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.importSettings')), matching: find.byType(FilledButton)));
      expect(kit.settingsStore.current.appearance.accent, AccentChoice.mint);
      expect(kit.settingsStore.current.onboardingCompleted, isTrue, reason: 'onboarding state of this install is kept');
      await pumpFrames(tester);
      expect(find.text(l10n.settingsImportSettingsDone), findsOneWidget);

      dialogs.file = _file('bad.json', ['not', 'settings']);
      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.importSettings')), matching: find.byType(FilledButton)));
      await pumpFrames(tester);
      expect(find.text(l10n.settingsFileInvalid), findsOneWidget);
    });

    testWidgets('library backup and restore (merge) go through LibraryMaintenance', (tester) async {
      final dialogs = FakeFileDialogs();
      final kit = FakeKit();
      kit.maintenance.backup = {'version': 1, 'playlists': []};
      await pumpSettings(tester, kit: kit, section: 'privacy', dialogs: dialogs);
      await scrollTo(tester, find.byKey(const ValueKey('settings.backupLibrary')));
      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.backupLibrary')), matching: find.byType(FilledButton)));
      expect(kit.maintenance.called('exportBackup'), isTrue);
      expect(dialogs.saved.keys.single, startsWith('fermata-library-'));

      dialogs.file = _file('b.json', {'version': 1, 'favorites': ['x']});
      await scrollTo(tester, find.byKey(const ValueKey('settings.restoreLibrary')));
      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.restoreLibrary')), matching: find.byType(FilledButton)));
      await tester.tap(find.byKey(const ValueKey('settings.restoreMerge')));
      await pumpFrames(tester);
      expect(kit.maintenance.called('importBackup'), isTrue);
      expect(kit.maintenance.backup['favorites'], ['x']);
    });

    testWidgets('network statement reflects lyrics and update settings', (tester) async {
      final kit = FakeKit(settings: const AppSettings(onboardingCompleted: true, playback: PlaybackSettings(lyricsEnabled: false)));
      await pumpSettings(tester, kit: kit, section: 'privacy');
      await scrollTo(tester, find.byKey(const ValueKey('settings.networkStatement')));
      expect(find.text(l10n.settingsNoTracking), findsOneWidget);
      expect(find.text(l10n.settingsNetworkLyricsOff), findsOneWidget);
      expect(find.text(l10n.settingsNetworkUpdatesOff), findsOneWidget);
    });
  });

  test('DataTransfer round-trips settings and rejects other files', () async {
    const s = AppSettings(localeCode: 'da', storage: StorageSettings(downloadLimitMb: 2048));
    final bytes = DataTransfer.encodeSettings(s);
    expect(DataTransfer.decodeSettings(bytes).localeCode, 'da');
    expect(DataTransfer.decodeSettings(bytes).storage.downloadLimitMb, 2048);
    expect(() => DataTransfer.decodeSettings(Uint8List.fromList(utf8.encode('{"a":1}'))), throwsFormatException);
    expect(() => DataTransfer.decodeSettings(Uint8List.fromList(utf8.encode('not json'))), throwsFormatException);
    expect(() => DataTransfer.decodeLibrary(Uint8List.fromList(utf8.encode('[1]'))), throwsFormatException);
    final store = SettingsStore.inMemory(const AppSettings(onboardingCompleted: true));
    await DataTransfer.importSettings(store, bytes);
    expect(store.current.onboardingCompleted, isTrue);
    expect(DataTransfer.fileName('x', 'json', DateTime(2026, 3, 4)), 'fermata-x-2026-03-04.json');
  });

  test('diagnostics never contain tokens, secrets or account names', () {
    final kit = FakeKit(sources: [
      oauthSource('sc', auth: const SourceAuthState(status: SourceConnectionStatus.connected, accountName: 'Secret Person')),
    ]);
    kit.credentials.credentials['sc'] = const SourceCredentials(clientId: 'cid-123', clientSecret: 'very-secret');
    kit.tokens.tokens['sc'] = const OAuthToken(accessToken: 'tok-abc', refreshToken: 'ref-def');
    final report = buildDiagnosticsReport(
      now: DateTime.utc(2026, 10, 27),
      platform: const PlatformInfo(os: HostOs.linux),
      settings: const AppSettings(),
      sources: kit.sources.all,
      credentials: kit.credentials,
      tokens: kit.tokens,
      locale: 'en',
      version: const AppVersion(version: '1.0.0', buildNumber: '7'),
      recentLogs: '{"m":"hello"}',
    );
    expect(report, contains('Version: 1.0.0 (7)'));
    expect(report, contains('sc: status=connected'));
    expect(report, contains('hello'));
    for (final secret in ['cid-123', 'very-secret', 'tok-abc', 'ref-def', 'Secret Person']) {
      expect(report, isNot(contains(secret)), reason: secret);
    }
  });

  group('updates & about', () {
    testWidgets('without an update checker: no automatic toggle, manual instructions instead', (tester) async {
      await pumpSettings(tester, section: 'updates');
      expect(find.text('1.2.3 (45)'), findsOneWidget);
      expect(find.byKey(const ValueKey('setting.checkForUpdates')), findsNothing);
      expect(find.text(l10n.settingsUpdateHowLinux), findsOneWidget);
    });

    testWidgets('check now shows the result and links to the release notes', (tester) async {
      final kit = FakeKit();
      await pumpSettings(
        tester,
        kit: kit,
        section: 'updates',
        hooks: SettingsHooks(
          checkForUpdates: () async => UpdateInfo(
            status: UpdateInfoStatus.updateAvailable,
            currentVersion: '1.2.3',
            latestVersion: '1.3.0',
            releaseNotesUrl: Uri.parse('https://example.invalid/releases/1.3.0'),
          ),
        ),
      );
      await tapVisible(tester, find.byKey(const ValueKey('setting.checkForUpdates')));
      expect(kit.settingsStore.current.updates.checkForUpdates, isTrue);
      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.checkNow')), matching: find.byType(FilledButton)));
      expect(find.text(l10n.settingsUpdateAvailable('1.3.0')), findsOneWidget);
      await tapVisible(tester, find.text(l10n.settingsReleaseNotes));
      expect(kit.openedLinks.single.toString(), 'https://example.invalid/releases/1.3.0');
    });

    testWidgets('about shows version, attributions, licenses and exports diagnostics', (tester) async {
      final dialogs = FakeFileDialogs();
      await pumpSettings(tester, section: 'about', dialogs: dialogs);
      expect(find.text('1.2.3 (45)'), findsOneWidget);
      expect(find.text('Linux'), findsOneWidget);
      await scrollTo(tester, find.byKey(const ValueKey('settings.attributions')));
      expect(find.text(l10n.settingsAttributionLrclib), findsOneWidget);
      expect(find.text(l10n.settingsAttributionSoundCloud), findsOneWidget);
      await scrollTo(tester, find.byKey(const ValueKey('settings.exportDiagnostics')));
      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.exportDiagnostics')), matching: find.byType(FilledButton)));
      final name = dialogs.saved.keys.single;
      expect(name, endsWith('.txt'));
      expect(utf8.decode(dialogs.saved[name]!), contains('Fermata diagnostics'));
      await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('settings.licenses')), matching: find.byType(FilledButton)));
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });
}
