// Notifications, tray-host detection and the colour-scheme portal against
// fake services on a private dbus-daemon.
@TestOn('linux')
library;

import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/platform/desktop/desktop_l10n.dart';
import 'package:fermata/platform/desktop/track_change_notifier.dart';
import 'package:fermata/platform/desktop/tray/tray_availability.dart';
import 'package:fermata/platform/linux/linux_notifier.dart';
import 'package:fermata/platform/linux/panel_theme_probe.dart';
import 'package:fermata/platform/linux/status_notifier_probe.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../desktop/fakes.dart';
import 'test_bus.dart';

/// Minimal org.freedesktop.Notifications server recording Notify calls.
class FakeNotificationServer extends DBusObject {
  FakeNotificationServer({this.capabilities = const ['body', 'body-markup']})
      : super(DBusObjectPath('/org/freedesktop/Notifications'));

  final List<String> capabilities;
  final calls = <List<DBusValue>>[];
  var _nextId = 1;

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != 'org.freedesktop.Notifications') return DBusMethodErrorResponse.unknownInterface();
    switch (methodCall.name) {
      case 'GetCapabilities':
        return DBusMethodSuccessResponse([DBusArray.string(capabilities)]);
      case 'Notify':
        if (methodCall.signature != DBusSignature('susssasa{sv}i')) return DBusMethodErrorResponse.invalidArgs();
        calls.add(methodCall.values);
        final replaces = methodCall.values[1].asUint32();
        return DBusMethodSuccessResponse([DBusUint32(replaces != 0 ? replaces : _nextId++)]);
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }
}

/// Fake xdg-desktop-portal Settings implementation.
class FakePortal extends DBusObject {
  FakePortal(this.colorScheme, {this.readOneSupported = true}) : super(DBusObjectPath('/org/freedesktop/portal/desktop'));

  final int colorScheme;
  final bool readOneSupported;

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != 'org.freedesktop.portal.Settings') return DBusMethodErrorResponse.unknownInterface();
    final ns = methodCall.values[0].asString();
    final key = methodCall.values[1].asString();
    if (ns != 'org.freedesktop.appearance' || key != 'color-scheme') {
      return DBusMethodErrorResponse('org.freedesktop.portal.Error.NotFound');
    }
    if (methodCall.name == 'ReadOne' && readOneSupported) {
      return DBusMethodSuccessResponse([DBusVariant(DBusUint32(colorScheme))]);
    }
    if (methodCall.name == 'Read') {
      return DBusMethodSuccessResponse([DBusVariant(DBusVariant(DBusUint32(colorScheme)))]);
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

void main() {
  if (!TestBus.available) {
    test('Linux D-Bus services', () {}, skip: 'dbus-daemon not installed');
    return;
  }

  late TestBus bus;
  final clients = <DBusClient>[];

  setUpAll(() async => bus = await TestBus.start());
  tearDownAll(() async => bus.stop());
  tearDown(() async {
    for (final c in clients) {
      await c.close();
    }
    clients.clear();
  });

  DBusClient newClient() {
    final c = bus.client();
    clients.add(c);
    return c;
  }

  Future<FakeNotificationServer> startNotificationServer({List<String>? caps}) async {
    final c = newClient();
    final server = FakeNotificationServer(capabilities: caps ?? const ['body', 'body-markup']);
    await c.registerObject(server);
    await c.requestName('org.freedesktop.Notifications');
    return server;
  }

  group('LinuxNotifier', () {
    test('is unsupported without a notification server', () async {
      final notifier = LinuxNotifier(client: newClient());
      await notifier.init();
      expect(notifier.isSupported, isFalse);
      await notifier.show(id: 'x', title: 'ignored'); // no throw
    });

    test('sends Notify with app name, icon and hints; same id replaces', () async {
      final server = await startNotificationServer();
      final notifier = LinuxNotifier(client: newClient());
      await notifier.init();
      expect(notifier.isSupported, isTrue);

      await notifier.show(id: 'dl', title: 'Download finished', body: 'Tom & Jerry <live>');
      expect(server.calls, hasLength(1));
      final first = server.calls.single;
      expect(first[0], const DBusString('Fermata'));
      expect(first[1], const DBusUint32(0));
      expect(first[2], const DBusString('app.fermata.player'));
      expect(first[3], const DBusString('Download finished'));
      expect(first[4], const DBusString('Tom &amp; Jerry &lt;live&gt;'), reason: 'body-markup → escaped');
      final hints = first[6].asStringVariantDict();
      expect(hints['desktop-entry'], const DBusString('app.fermata.player'));

      await notifier.show(id: 'dl', title: 'Another');
      expect(server.calls[1][1], const DBusUint32(1), reason: 'replaces the previous notification');
      await notifier.show(id: 'other', title: 'Separate');
      expect(server.calls[2][1], const DBusUint32(0));
    });

    test('plain body without markup support; file icons become URIs', () async {
      final server = await startNotificationServer(caps: const ['body']);
      final notifier = LinuxNotifier(client: newClient());
      await notifier.init();
      await notifier.show(id: 'a', title: 'T', body: 'a < b', iconPath: '/tmp/cover art.png');
      expect(server.calls.single[4], const DBusString('a < b'));
      expect(server.calls.single[2], DBusString(Uri.file('/tmp/cover art.png').toString()));
      expect(server.calls.single[6].asStringVariantDict()['image-path'], const DBusString('/tmp/cover art.png'));
    });

    test('track-change notifications follow the setting and replace each other', () async {
      final server = await startNotificationServer();
      final notifier = LinuxNotifier(client: newClient());
      await notifier.init();
      final settings = SettingsStore.inMemory();
      final playback = FakePlaybackController();
      final tcn = TrackChangeNotifier(
        playback: playback,
        settings: settings,
        notifier: notifier,
        strings: desktopStringsFor(settings),
      )..start();
      addTearDown(tcn.dispose);

      playback.load([track('1', title: 'So What', artist: 'Miles Davis', album: 'Kind of Blue'), track('2', artist: '')]);
      await settle(20);
      expect(server.calls, isEmpty, reason: 'notifications.trackChange is off by default');

      await settings.update((s) => s.copyWith(notifications: s.notifications.copyWith(trackChange: true)));
      await playback.next();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(server.calls, hasLength(1));
      expect(server.calls.single[3], const DBusString('Song 2'));
      expect(server.calls.single[4], const DBusString('Unknown artist'));
      final hints = server.calls.single[6].asStringVariantDict();
      expect(hints['transient'], const DBusBoolean(true));
      expect(hints['urgency'], const DBusByte(0));

      playback.load([track('3', title: 'Freddie Freeloader', artist: 'Miles Davis', album: 'Kind of Blue')]);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(server.calls, hasLength(2));
      expect(server.calls[1][1], const DBusUint32(1), reason: 'replaces the previous track notification');
      expect(server.calls[1][4], const DBusString('Miles Davis — Kind of Blue'));

      await settings.update((s) => s.copyWith(localeCode: 'da'));
      playback.load([track('4', artist: '')]);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(server.calls.last[4], const DBusString('Ukendt kunstner'));
      expect(playback.snapshot.status, PlayerStatus.ready);
    });
  });

  group('StatusNotifierProbe', () {
    test('no watcher → noHost, or gnomeWithoutAppIndicator on GNOME', () async {
      final c = newClient();
      expect(await StatusNotifierProbe(client: c, environment: const {'XDG_CURRENT_DESKTOP': 'KDE'}).check(),
          TrayHostState.noHost);
      expect(await StatusNotifierProbe(client: c, environment: const {'XDG_CURRENT_DESKTOP': 'ubuntu:GNOME'}).check(),
          TrayHostState.gnomeWithoutAppIndicator);
    });

    test('watcher present → available; hostChanges fires when it appears and goes', () async {
      final c = newClient();
      final probe = StatusNotifierProbe(client: c, environment: const {'XDG_CURRENT_DESKTOP': 'GNOME'});
      addTearDown(probe.dispose);
      var changes = 0;
      final sub = probe.hostChanges.listen((_) => changes++);
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final panel = newClient();
      await panel.requestName(StatusNotifierProbe.watcherName);
      expect(await probe.check(), TrayHostState.available);
      await panel.releaseName(StatusNotifierProbe.watcherName);
      final end = DateTime.now().add(const Duration(seconds: 3));
      while (changes < 2 && DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(changes, 2);
      expect(await probe.check(), TrayHostState.gnomeWithoutAppIndicator);
    });

    test('unreachable bus → noSessionBus', () async {
      final dead = DBusClient(DBusAddress('unix:path=/nonexistent/fermata-bus'));
      clients.add(dead);
      expect(await StatusNotifierProbe(client: dead).check(), TrayHostState.noSessionBus);
    });

    test('GNOME detection', () {
      expect(StatusNotifierProbe.isGnome(const {'XDG_CURRENT_DESKTOP': 'ubuntu:GNOME'}), isTrue);
      expect(StatusNotifierProbe.isGnome(const {'XDG_CURRENT_DESKTOP': 'GNOME-Classic:GNOME'}), isTrue);
      expect(StatusNotifierProbe.isGnome(const {'XDG_CURRENT_DESKTOP': 'KDE'}), isFalse);
      expect(StatusNotifierProbe.isGnome(const {'XDG_CURRENT_DESKTOP': 'X-Cinnamon'}), isFalse);
      expect(StatusNotifierProbe.isGnome(const {'XDG_CURRENT_DESKTOP': 'XFCE'}), isFalse);
      expect(StatusNotifierProbe.isGnome(const {}), isFalse);
    });
  });

  group('portalPrefersDark', () {
    Future<void> startPortal(FakePortal portal) async {
      final c = newClient();
      await c.registerObject(portal);
      await c.requestName('org.freedesktop.portal.Desktop');
    }

    test('false without a portal', () async {
      expect(await portalPrefersDark(newClient(), timeout: const Duration(seconds: 1)), isFalse);
    });

    test('reads color-scheme via ReadOne', () async {
      await startPortal(FakePortal(1));
      expect(await portalPrefersDark(newClient()), isTrue);
    });
  });

  test('portalPrefersDark falls back to the deprecated Read', () async {
    final owner = newClient();
    await owner.registerObject(FakePortal(2, readOneSupported: false));
    await owner.requestName('org.freedesktop.portal.Desktop');
    expect(await portalPrefersDark(newClient()), isFalse);
    await owner.releaseName('org.freedesktop.portal.Desktop');

    final dark = newClient();
    await dark.registerObject(FakePortal(1, readOneSupported: false));
    await dark.requestName('org.freedesktop.portal.Desktop');
    expect(await portalPrefersDark(newClient()), isTrue);
    expect(const AppSettings().notifications.trackChange, isFalse);
  });
}
