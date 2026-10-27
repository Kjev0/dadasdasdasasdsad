import 'dart:typed_data';

import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/ui/pages/onboarding/music_folders.dart';
import 'package:fermata/ui/pages/settings/settings_hooks.dart';
import 'package:fermata/ui/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

/// Records file dialog calls; returns preset answers.
class FakeFileDialogs implements FileDialogs {
  String? directory;
  PickedFile? file;
  String? saveLocation = '/tmp/fermata-test/out';
  final saved = <String, Uint8List>{};
  final calls = <String>[];

  @override
  Future<String?> pickDirectory({String? title, String? initialDirectory}) async {
    calls.add('pickDirectory');
    return directory;
  }

  @override
  Future<PickedFile?> pickFile({String? title, List<String>? extensions}) async {
    calls.add('pickFile');
    return file;
  }

  @override
  Future<String?> saveFile({required String fileName, required Uint8List bytes, String mimeType = '', String? title}) async {
    calls.add('saveFile');
    if (saveLocation == null) return null;
    saved[fileName] = bytes;
    return '$saveLocation/$fileName';
  }
}

/// Overrides every settings test needs: deterministic version, environment,
/// file dialogs and hooks.
List<Override> settingsOverrides({
  FakeFileDialogs? dialogs,
  SettingsHooks hooks = const SettingsHooks(),
  Map<String, String> env = const {},
  String? musicFolder,
}) =>
    [
      appVersionProvider.overrideWith((ref) async => const AppVersion(version: '1.2.3', buildNumber: '45')),
      desktopEnvironmentProvider.overrideWithValue(env),
      fileDialogsProvider.overrideWithValue(dialogs ?? FakeFileDialogs()),
      settingsHooksProvider.overrideWithValue(hooks),
      suggestedMusicFolderProvider.overrideWithValue(musicFolder),
    ];

/// Pumps `SettingsPage(section:)` alone (no router) — two-pane at the
/// default size.
Future<FakeKit> pumpSettings(
  WidgetTester tester, {
  FakeKit? kit,
  String? section,
  Size size = TestSizes.expanded,
  List<Override> overrides = const [],
  FakeFileDialogs? dialogs,
  SettingsHooks hooks = const SettingsHooks(),
  Map<String, String> env = const {},
}) async {
  return pumpInApp(
    tester,
    SettingsPage(section: section),
    kit: kit,
    size: size,
    overrides: [...settingsOverrides(dialogs: dialogs, hooks: hooks, env: env), ...overrides],
  );
}

/// The vertical scrollable of the open settings section.
Finder get sectionScrollable =>
    find.descendant(of: find.byKey(const ValueKey('settings.sectionBody')), matching: find.byType(Scrollable)).first;

/// Scrolls the open settings section until [finder] is visible.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: sectionScrollable, maxScrolls: 80);
  await tester.pump();
}

/// Scrolls the settings section list until the entry for [section] is
/// visible, then taps it.
Future<void> openSection(WidgetTester tester, String section) async {
  final entry = find.byKey(ValueKey('settings.section.$section'));
  await tester.scrollUntilVisible(
    entry,
    120,
    scrollable: find.descendant(of: find.byKey(const ValueKey('settings.sectionList')), matching: find.byType(Scrollable)).first,
  );
  await tester.pump();
  await tester.tap(entry);
  await pumpFrames(tester);
}

/// Taps [finder] after scrolling it into view and pumps.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await pumpFrames(tester, count: 4);
}

/// The value of the `Switch` inside a settings row.
bool switchValue(WidgetTester tester, String key) =>
    tester.widget<Switch>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Switch))).value;

/// A fake OAuth source in a given state.
FakeMusicSource oauthSource(
  String id, {
  String? name,
  SourceAuthState auth = const SourceAuthState(status: SourceConnectionStatus.notConnected),
  CredentialStatus credentials = const CredentialStatus(configured: true, origin: CredentialOrigin.buildTime),
  Set<SourceCapability>? capabilities,
}) =>
    FakeMusicSource(
      id: id,
      displayName: name ?? id,
      authState: auth,
      credentialStatus: credentials,
      termsUrl: Uri.parse('https://example.invalid/$id/terms'),
      limitationsNote: '$id limitations.',
      capabilities: capabilities ??
          const {
            SourceCapability.searchTracks,
            SourceCapability.stream,
            SourceCapability.oauth,
            SourceCapability.userLibrary,
            SourceCapability.playlistImport,
          },
    );
