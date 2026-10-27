import 'dart:io';

import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/contracts/platform.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/pages/onboarding/music_folders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'settings_harness.dart';

String currentPath(WidgetTester tester) => appRouter(tester).routerDelegate.currentConfiguration.uri.path;

void main() {
  final l10n = AppLocalizationsEn();

  List<MusicSource> sources() => [
        oauthSource(SourceIds.spotify, name: 'Spotify'),
        oauthSource(SourceIds.soundcloud, name: 'SoundCloud'),
        FakeMusicSource(id: SourceIds.audius, displayName: 'Audius'),
        oauthSource(SourceIds.youtube,
            name: 'YouTube Music', credentials: const CredentialStatus(configured: false, origin: CredentialOrigin.none, missing: ['apiKey'])),
      ];

  testWidgets('first start opens onboarding; Skip completes it and redirects to Home', (tester) async {
    final kit = FakeKit(settings: const AppSettings());
    await pumpFermata(tester, kit: kit, initialRoute: '/', overrides: settingsOverrides());
    expect(currentPath(tester), '/onboarding');
    expect(find.text(l10n.onboardingWelcomeTitle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding.skip')));
    await pumpFrames(tester);
    expect(kit.settingsStore.current.onboardingCompleted, isTrue);
    expect(currentPath(tester), '/home');
  });

  testWidgets('full flow: add the suggested Music folder, connect SoundCloud, choose close behaviour, finish', (tester) async {
    final kit = FakeKit(settings: const AppSettings(), sources: sources());
    await pumpFermata(tester, kit: kit, initialRoute: '/onboarding', overrides: settingsOverrides(musicFolder: '/home/u/Music'));
    expect(find.bySemanticsLabel(l10n.onboardingStepOf(1, 4)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding.next')));
    await pumpFrames(tester);

    // Step 2 — music folders.
    expect(find.text(l10n.onboardingMusicTitle), findsOneWidget);
    expect(find.text('/home/u/Music'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding.addSuggested')));
    await pumpFrames(tester);
    expect(kit.localLibrary.folderList.map((f) => f.path), ['/home/u/Music']);
    expect(kit.localLibrary.called('scan'), isTrue);
    expect(find.byKey(const ValueKey('onboarding.suggestedFolder')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('onboarding.next')));
    await pumpFrames(tester);

    // Step 3 — services: SoundCloud first and highlighted; YouTube needs credentials.
    expect(find.text(l10n.onboardingServicesTitle), findsOneWidget);
    final scTop = tester.getTopLeft(find.byKey(const ValueKey('onboarding.service.soundcloud'))).dy;
    final spTop = tester.getTopLeft(find.byKey(const ValueKey('onboarding.service.spotify'))).dy;
    expect(scTop, lessThan(spTop));
    expect(find.text(l10n.onboardingRecommended), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding.service.youtube.connect')), findsNothing);
    expect(find.text(l10n.onboardingNoAccountNeeded('Audius')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding.service.soundcloud.connect')));
    await pumpFrames(tester);
    expect((kit.sources.byId(SourceIds.soundcloud)! as FakeMusicSource).calls, contains('connect'));
    expect(find.text(l10n.onboardingConnectedAs('Tester')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding.next')));
    await pumpFrames(tester);

    // Step 4 — background (desktop): tray explanation + close behaviour.
    expect(find.text(l10n.onboardingBackgroundTray), findsOneWidget);
    final dropdown = find.descendant(of: find.byKey(const ValueKey('onboarding.closeBehavior')), matching: find.byType(DropdownButton<CloseBehavior>));
    await tester.tap(dropdown);
    await pumpFrames(tester, count: 3);
    await tester.tap(find.text(l10n.settingsCloseAsk).last);
    await pumpFrames(tester, count: 3);
    expect(kit.settingsStore.current.desktop.closeBehavior, CloseBehavior.ask);

    await tester.tap(find.byKey(const ValueKey('onboarding.finish')));
    await pumpFrames(tester);
    expect(kit.settingsStore.current.onboardingCompleted, isTrue);
    expect(currentPath(tester), '/home');
  });

  testWidgets('back returns to the previous step; choosing another folder uses the picker', (tester) async {
    final dialogs = FakeFileDialogs()..directory = '/data/music';
    final kit = FakeKit(settings: const AppSettings());
    await pumpFermata(tester, kit: kit, initialRoute: '/onboarding', overrides: settingsOverrides(dialogs: dialogs));
    await tester.tap(find.byKey(const ValueKey('onboarding.next')));
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('onboarding.suggestedFolder')), findsNothing, reason: 'no suggestion when the folder does not exist');
    await tester.tap(find.byKey(const ValueKey('onboarding.chooseFolder')));
    await pumpFrames(tester);
    expect(dialogs.calls, ['pickDirectory']);
    expect(kit.localLibrary.folderList.single.path, '/data/music');
    await tester.tap(find.byKey(const ValueKey('onboarding.back')));
    await pumpFrames(tester);
    expect(find.text(l10n.onboardingWelcomeTitle), findsOneWidget);
  });

  testWidgets('Android asks for audio and notification permission with a rationale', (tester) async {
    final kit = FakeKit(os: HostOs.android, settings: const AppSettings());
    kit.androidSystem
      ..isSupported = true
      ..audioLibrary = false
      ..notifications = false;
    await pumpFermata(tester, kit: kit, initialRoute: '/onboarding', size: TestSizes.compact, overrides: settingsOverrides());
    await tester.tap(find.byKey(const ValueKey('onboarding.next')));
    await pumpFrames(tester);
    expect(find.text(l10n.onboardingAudioPermissionRationale), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding.chooseFolder')), findsNothing);
    expect(kit.androidSystem.calls, isEmpty);
    await tapVisible(tester, find.byKey(const ValueKey('onboarding.audioPermission')));
    await pumpFrames(tester);
    expect(kit.androidSystem.calls, ['requestAudioLibraryPermission']);
    expect(find.byKey(const ValueKey('onboarding.chooseFolder'), skipOffstage: false), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding.next')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('onboarding.next')));
    await pumpFrames(tester);
    expect(find.text(l10n.onboardingNotificationRationale), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('onboarding.notifications')));
    await pumpFrames(tester);
    expect(kit.androidSystem.calls, contains('requestNotificationPermission'));
    expect(find.text(l10n.onboardingNotificationsAllowed), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding.finish')));
    await pumpFrames(tester);
    expect(currentPath(tester), '/home');
  });

  testWidgets('onboarding is localized (Danish)', (tester) async {
    final kit = FakeKit(settings: const AppSettings(localeCode: 'da'));
    await pumpFermata(tester, kit: kit, initialRoute: '/onboarding', overrides: settingsOverrides());
    expect(find.text('Velkommen til Fermata'), findsOneWidget);
    expect(find.text('Spring over'), findsOneWidget);
  });

  testWidgets('steps expose headings to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpFermata(tester, kit: FakeKit(settings: const AppSettings()), initialRoute: '/onboarding', overrides: settingsOverrides());
    expect(tester.getSemantics(find.text(l10n.onboardingWelcomeTitle)), isSemantics(isHeader: true));
    handle.dispose();
  });

  group('suggested music folder', () {
    late Directory home;
    setUp(() => home = Directory.systemTemp.createTempSync('fermata-home'));
    tearDown(() => home.deleteSync(recursive: true));

    test('Linux reads XDG_MUSIC_DIR from user-dirs.dirs', () {
      Directory('${home.path}/.config').createSync();
      Directory('${home.path}/Musik').createSync();
      File('${home.path}/.config/user-dirs.dirs').writeAsStringSync('XDG_MUSIC_DIR="\$HOME/Musik"\n');
      expect(suggestedMusicFolder(const PlatformInfo(os: HostOs.linux), {'HOME': home.path}), '${home.path}/Musik');
    });

    test('Linux falls back to ~/Music and only suggests existing folders', () {
      const linux = PlatformInfo(os: HostOs.linux);
      expect(suggestedMusicFolder(linux, {'HOME': home.path}), isNull);
      Directory('${home.path}/Music').createSync();
      expect(suggestedMusicFolder(linux, {'HOME': home.path}), '${home.path}/Music');
    });

    test('Windows uses %USERPROFILE%\\Music; Android has no suggestion', () {
      expect(
        suggestedMusicFolder(const PlatformInfo(os: HostOs.windows), {'USERPROFILE': r'C:\Users\ada'}, exists: (_) => true),
        endsWith('Music'),
      );
      expect(suggestedMusicFolder(const PlatformInfo(os: HostOs.android), {'HOME': home.path}, exists: (_) => true), isNull);
    });
  });
}
