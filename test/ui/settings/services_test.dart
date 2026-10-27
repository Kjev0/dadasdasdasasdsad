import 'dart:async';

import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/pages/settings/services/credentials_editor.dart';
import 'package:fermata/ui/pages/settings/settings_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'settings_harness.dart';

/// A source whose `connect()` waits until [finish] completes.
class SlowSource extends FakeMusicSource {
  SlowSource(String id)
      : super(
          id: id,
          displayName: 'Slow',
          authState: const SourceAuthState(status: SourceConnectionStatus.notConnected),
          capabilities: const {SourceCapability.searchTracks, SourceCapability.stream, SourceCapability.oauth},
        );

  final finish = Completer<void>();

  @override
  Future<void> connect() async {
    calls.add('connect');
    setAuthState(const SourceAuthState(status: SourceConnectionStatus.connecting));
    await finish.future;
  }
}

void main() {
  final l10n = AppLocalizationsEn();

  String statusOf(WidgetTester tester, String id) =>
      tester.widget<Text>(find.descendant(of: find.byKey(ValueKey('settings.source.$id.status')), matching: find.byType(Text))).data!;

  testWidgets('cards show credentials missing / not connected / connected / expired / error', (tester) async {
    final kit = FakeKit(sources: [
      oauthSource('nocreds',
          name: 'NoCreds',
          credentials: CredentialStatus(
              configured: false, origin: CredentialOrigin.none, missing: const ['clientId', 'clientSecret'], helpUrl: Uri.parse('https://dev.invalid/apps'))),
      oauthSource('fresh', name: 'Fresh'),
      oauthSource('linked',
          name: 'Linked',
          auth: const SourceAuthState(status: SourceConnectionStatus.connected, accountName: 'Ada', grantedScopes: ['playlists', 'likes'])),
      oauthSource('stale', name: 'Stale', auth: const SourceAuthState(status: SourceConnectionStatus.expired)),
      oauthSource('broken', name: 'Broken', auth: const SourceAuthState(status: SourceConnectionStatus.error, error: 'HTTP 500')),
      FakeMusicSource(id: SourceIds.deezer, displayName: 'Deezer', capabilities: const {SourceCapability.searchTracks, SourceCapability.previewOnly}),
    ]);
    await pumpSettings(tester, kit: kit, section: 'services');

    expect(statusOf(tester, 'nocreds'), l10n.settingsStatusCredentialsMissing);
    expect(find.byKey(const ValueKey('settings.credentials.nocreds')), findsOneWidget, reason: 'editor opens when not configured');
    expect(find.byKey(const ValueKey('settings.source.nocreds.connect')), findsNothing);

    expect(statusOf(tester, 'fresh'), l10n.settingsStatusNotConnected);
    expect(find.byKey(const ValueKey('settings.source.fresh.connect')), findsOneWidget);

    await scrollTo(tester, find.byKey(const ValueKey('settings.source.linked')));
    expect(statusOf(tester, 'linked'), l10n.settingsStatusConnected);
    expect(find.text(l10n.settingsAccount('Ada')), findsOneWidget);
    expect(find.text(l10n.settingsScopes('playlists, likes')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings.source.linked.disconnect')), findsOneWidget);

    await scrollTo(tester, find.byKey(const ValueKey('settings.source.stale')));
    expect(statusOf(tester, 'stale'), l10n.settingsStatusExpired);
    expect(find.text(l10n.settingsExpiredHint('Stale')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('settings.source.stale.connect')), matching: find.text(l10n.settingsReconnect)), findsOneWidget);

    await scrollTo(tester, find.byKey(const ValueKey('settings.source.broken')));
    expect(statusOf(tester, 'broken'), l10n.settingsStatusError);
    expect(find.text(l10n.settingsErrorDetail('HTTP 500')), findsOneWidget);

    await scrollTo(tester, find.byKey(const ValueKey('settings.source.deezer')));
    expect(statusOf(tester, SourceIds.deezer), l10n.settingsStatusNotRequired);
    // Honest limits: previews only, no downloads.
    expect(find.descendant(of: find.byKey(const ValueKey('settings.source.deezer')), matching: find.text(l10n.settingsCantStream)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('settings.source.deezer')), matching: find.text(l10n.settingsCantDownload)), findsOneWidget);
    expect(find.byKey(const ValueKey('settings.source.deezer.editCredentials')), findsNothing);
  });

  testWidgets('SoundCloud card states its silo rule', (tester) async {
    final kit = FakeKit(sources: [oauthSource(SourceIds.soundcloud, name: 'SoundCloud')]);
    await pumpSettings(tester, kit: kit, section: 'services');
    expect(find.text(l10n.settingsSiloed('SoundCloud')), findsOneWidget);
    expect(find.text(l10n.settingsCantDownload), findsOneWidget);
  });

  testWidgets('credentials editor validates, saves to the credentials store and shows redirect URIs', (tester) async {
    final source = oauthSource('sc',
        name: 'SC',
        credentials: const CredentialStatus(configured: false, origin: CredentialOrigin.none, missing: ['clientId', 'clientSecret']));
    final kit = FakeKit(sources: [source]);
    await pumpSettings(tester, kit: kit, section: 'services');

    // Exact redirect URIs from OAuthClient.redirectUriFor.
    expect(find.text('http://127.0.0.1:43821/callback/sc'), findsWidgets);
    expect(find.text(l10n.settingsCredRedirectDesktop), findsOneWidget);
    expect(find.text(l10n.settingsCredRedirectAndroid), findsOneWidget);
    expect(find.text(l10n.settingsCredOrigin(l10n.settingsCredOriginNone)), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('settings.cred.sc.save')));
    expect(find.text(l10n.settingsCredRequired('${l10n.settingsCredClientId}, ${l10n.settingsCredClientSecret}')), findsOneWidget);
    expect(kit.credentials.credentials, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('settings.cred.sc.clientId')), '  my-client  ');
    await tester.enterText(find.byKey(const ValueKey('settings.cred.sc.clientSecret')), 'shh');
    await tapVisible(tester, find.byKey(const ValueKey('settings.cred.sc.save')));
    final saved = kit.credentials.credentials['sc']!;
    expect(saved.clientId, 'my-client');
    expect(saved.clientSecret, 'shh');
    expect(saved.redirectUri, isNull);
    expect(find.text(l10n.settingsCredSaved('SC')), findsOneWidget);
    // The secret field is obscured.
    final secret = tester.widget<TextField>(find.byKey(const ValueKey('settings.cred.sc.clientSecret')));
    expect(secret.obscureText, isTrue);
  });

  testWidgets('configured sources can be overridden with own credentials, never pre-filling build-time secrets', (tester) async {
    final source = oauthSource(SourceIds.soundcloud, name: 'SoundCloud');
    final kit = FakeKit(sources: [source]);
    kit.credentials.credentials['soundcloud'] = const SourceCredentials(clientId: 'build-id', clientSecret: 'build-secret');
    kit.credentials.origins['soundcloud'] = CredentialOrigin.buildTime;
    await pumpSettings(tester, kit: kit, section: 'services');
    expect(find.byKey(const ValueKey('settings.credentials.soundcloud')), findsNothing);
    await tapVisible(tester, find.byKey(const ValueKey('settings.source.soundcloud.editCredentials')));
    expect(find.byKey(const ValueKey('settings.credentials.soundcloud')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('settings.cred.soundcloud.clientSecret'))).controller!.text, isEmpty);
    expect(find.text(l10n.settingsCredOrigin(l10n.settingsCredOriginBuild)), findsOneWidget);
  });

  test('credential fields: missing first, then the provider\'s known fields', () {
    final sc = oauthSource(SourceIds.soundcloud, credentials: const CredentialStatus(configured: false, origin: CredentialOrigin.none, missing: ['clientSecret']));
    expect(credentialFieldsFor(sc, null), ['clientSecret', 'clientId']);
    final unknown = FakeMusicSource(id: 'plugin', capabilities: const {SourceCapability.oauth});
    expect(credentialFieldsFor(unknown, null), ['clientId']);
  });

  testWidgets('connect shows progress, can be canceled, and reports success', (tester) async {
    final slow = SlowSource('slow');
    var canceled = 0;
    final kit = FakeKit(sources: [slow]);
    await pumpSettings(tester, kit: kit, section: 'services', hooks: SettingsHooks(cancelPendingSignIn: () => canceled++));
    await tapVisible(tester, find.byKey(const ValueKey('settings.source.slow.connect')));
    expect(slow.calls, contains('connect'));
    expect(find.text(l10n.settingsConnectingHint), findsOneWidget);
    expect(statusOf(tester, 'slow'), l10n.settingsStatusConnecting);
    await tapVisible(tester, find.byKey(const ValueKey('settings.source.slow.cancel')));
    expect(canceled, 1);
    expect(find.text(l10n.settingsConnectingHint), findsNothing);
    slow.finish.complete();
    await pumpFrames(tester);

    // A normal connect completes and toasts.
    final kit2 = FakeKit(sources: [oauthSource('ok', name: 'Okay')]);
    await pumpSettings(tester, kit: kit2, section: 'services');
    await tapVisible(tester, find.byKey(const ValueKey('settings.source.ok.connect')));
    expect(find.text(l10n.settingsConnected('Okay')), findsOneWidget);
    expect(statusOf(tester, 'ok'), l10n.settingsStatusConnected);
  });

  testWidgets('disconnect asks first', (tester) async {
    final src = oauthSource('linked', name: 'Linked', auth: const SourceAuthState(status: SourceConnectionStatus.connected, accountName: 'Ada'));
    final kit = FakeKit(sources: [src]);
    await pumpSettings(tester, kit: kit, section: 'services');
    await tapVisible(tester, find.byKey(const ValueKey('settings.source.linked.disconnect')));
    expect(find.text(l10n.settingsDisconnectTitle('Linked')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, l10n.settingsDisconnect).last);
    await pumpFrames(tester);
    expect(src.calls, contains('disconnect'));
    expect(statusOf(tester, 'linked'), l10n.settingsStatusNotConnected);
  });

  testWidgets('token storage notice only when tokens are not persistent; terms open externally', (tester) async {
    final kit = FakeKit(sources: [oauthSource('a', name: 'A')]);
    kit.tokens.isPersistent = false;
    await pumpSettings(tester, kit: kit, section: 'services');
    expect(find.byKey(const ValueKey('settings.tokenNotice')), findsOneWidget);
    expect(find.text(l10n.settingsNoPasswords), findsOneWidget);
    await tapVisible(tester, find.text(l10n.settingsTerms));
    expect(kit.openedLinks.single.toString(), 'https://example.invalid/a/terms');

    final kit2 = FakeKit();
    await pumpSettings(tester, kit: kit2, section: 'services');
    expect(find.byKey(const ValueKey('settings.tokenNotice')), findsNothing);
  });

  testWidgets('provider order can be reordered and sources disabled', (tester) async {
    final kit = FakeKit(
      settings: const AppSettings(onboardingCompleted: true, services: ServicesSettings(providerOrder: ['soundcloud', 'audius', 'deezer'])),
      sources: [
        FakeMusicSource(id: 'soundcloud', displayName: 'SoundCloud'),
        FakeMusicSource(id: 'audius', displayName: 'Audius'),
        FakeMusicSource(id: 'deezer', displayName: 'Deezer'),
      ],
    );
    await pumpSettings(tester, kit: kit, section: 'services');
    await tapVisible(tester, find.byKey(const ValueKey('settings.order.deezer.up')));
    expect(kit.settingsStore.current.services.providerOrder.take(3), ['soundcloud', 'deezer', 'audius']);
    await tapVisible(tester, find.byKey(const ValueKey('settings.order.soundcloud.down')));
    expect(kit.settingsStore.current.services.providerOrder.take(3), ['deezer', 'soundcloud', 'audius']);
    await tapVisible(tester, find.byKey(const ValueKey('settings.order.audius.enabled')));
    expect(kit.settingsStore.current.services.disabledSources, {'audius'});
    await tapVisible(tester, find.byKey(const ValueKey('setting.preferSoundCloud')));
    expect(kit.settingsStore.current.services.preferSoundCloudInDiscovery, isFalse);
  });
}
