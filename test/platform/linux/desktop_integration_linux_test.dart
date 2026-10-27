// End-to-end wiring of DesktopIntegration.start on Linux: private session
// bus (MPRIS + tray host detection + notifications), fake window/tray/hotkey
// backends, real single-instance server and playerctl.
@TestOn('linux')
library;

import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:fermata/core/platform/app_paths.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/platform/desktop/desktop_integration.dart';
import 'package:fermata/platform/desktop/lifecycle_controller.dart';
import 'package:fermata/platform/desktop/single_instance.dart';
import 'package:fermata/platform/desktop/tray/tray_menu.dart';
import 'package:fermata/platform/desktop/window/window_backend.dart';
import 'package:fermata/platform/linux/mpris_server.dart';
import 'package:fermata/platform/linux/status_notifier_probe.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../desktop/fakes.dart';
import 'test_bus.dart';

void main() {
  if (!TestBus.available) {
    test('desktop integration (Linux)', () {}, skip: 'dbus-daemon not installed');
    return;
  }
  final hasPlayerctl = Process.runSync('which', ['playerctl']).exitCode == 0;

  late TestBus bus;
  late Directory tmp;

  setUp(() async {
    bus = await TestBus.start();
    tmp = await Directory.systemTemp.createTemp('fermata-integration-');
  });

  tearDown(() async {
    await bus.stop();
    await tmp.delete(recursive: true);
  });

  Future<void> until(bool Function() condition, {Duration timeout = const Duration(seconds: 5)}) async {
    final end = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(end)) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('wires tray, window, MPRIS, hotkeys and single instance together', () async {
    final paths = AppPaths.forTesting(tmp);
    final assets = Directory(p.join(tmp.path, 'flutter_assets', 'assets', 'branding'))..createSync(recursive: true);
    File(p.join(assets.path, 'tray_icon.png')).writeAsStringSync('png');

    // A StatusNotifier host is running (e.g. KDE Plasma).
    final panel = bus.client();
    await panel.requestName(StatusNotifierProbe.watcherName);

    final settings = SettingsStore.inMemory();
    final playback = FakePlaybackController()..load([track('1', title: 'So What'), track('2', title: 'Blue in Green')]);
    final window = FakeWindowBackend();
    final trayBackend = FakeTrayBackend();
    final hotkeys = FakeHotkeyBackend();
    final exits = <int>[];
    var disposed = false;

    final instance = (await SingleInstance.acquire(paths.instanceLockFile, const []) as PrimaryInstance).instance;
    final sessionBus = bus.client();

    final integration = await DesktopIntegration.start(
      platform: const PlatformInfo(os: HostOs.linux),
      playback: playback,
      settings: settings,
      paths: paths,
      disposeAll: () async => disposed = true,
      singleInstance: instance,
      sessionBus: sessionBus,
      window: window,
      trayBackend: trayBackend,
      trayAssetsRoot: p.join(tmp.path, 'flutter_assets'),
      hotkeyBackend: hotkeys,
      environment: const {'XDG_CURRENT_DESKTOP': 'KDE', 'XDG_SESSION_TYPE': 'x11'},
      exitProcess: exits.add,
    );

    final lifecycle = integration.lifecycle as DesktopLifecycleController;
    expect(window.preventClose, isTrue);
    expect(window.visible, isTrue);
    expect(lifecycle.trayAvailable, isTrue);
    expect(trayBackend.iconPath, p.join(assets.path, 'tray_icon.png'));
    expect(trayBackend.entry(TrayMenuIds.nowPlaying).label, 'So What — Artist');
    expect(hotkeys.registered.keys, hasLength(4));
    expect(integration.hotkeys.registrationErrors, isEmpty);
    expect(integration.mpris!.busName, MprisServer.baseBusName);
    expect(integration.notifier.isSupported, isFalse, reason: 'no notification server on the private bus');
    expect(integration.startup.isSupported, isTrue);

    // Closing the window keeps the music going: hidden to the tray.
    await playback.play();
    window.fire(WindowEventKind.close);
    await settle();
    expect(window.visible, isFalse);
    expect(playback.snapshot.playing, isTrue);

    // MPRIS Raise brings it back.
    final remote = DBusRemoteObject(bus.client(), name: MprisServer.baseBusName, path: DBusObjectPath(MprisServer.objectPath));
    await remote.callMethod(MprisServer.rootInterface, 'Raise', const []);
    await until(() => window.visible);

    // A second launch with --next is forwarded to us.
    final second = await SingleInstance.acquire(paths.instanceLockFile, const ['--next']);
    expect(second, isA<ForwardedToRunningInstance>());
    await until(() => playback.queue.currentIndex == 1);
    await Future<void>.delayed(const Duration(milliseconds: 250)); // tray debounce
    expect(trayBackend.entry(TrayMenuIds.nowPlaying).label, 'Blue in Green — Artist');

    // Global hotkey → previous.
    hotkeys.handlers['global.previous']!();
    await until(() => playback.queue.currentIndex == 0);

    if (hasPlayerctl) {
      final r = await Process.run('playerctl', ['-p', 'fermata', 'play-pause'], environment: bus.environment);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      await until(() => !playback.snapshot.playing);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(trayBackend.entry(TrayMenuIds.playPause).label, 'Play');
    }

    // Settings → tray off → closing minimizes instead of hiding.
    await settings.update((s) => s.copyWith(desktop: s.desktop.copyWith(showTrayIcon: false)));
    await until(() => !lifecycle.trayAvailable);
    window.fire(WindowEventKind.close);
    await settle();
    expect(window.minimized, isTrue);
    expect(window.visible, isTrue);

    // MPRIS Quit → orderly shutdown.
    await remote.callMethod(MprisServer.rootInterface, 'Quit', const []);
    await until(() => window.calls.contains('destroy'));
    expect(playback.calls, contains('dispose'));
    expect(disposed, isTrue);
    expect(hotkeys.registered, isEmpty);
    expect(await panel.nameHasOwner(MprisServer.baseBusName), isFalse);
    expect(await paths.instanceLockFile.exists(), isFalse);
    await until(() => exits.isNotEmpty, timeout: const Duration(seconds: 6));
    expect(exits, [0]);

    await remote.client.close();
    await sessionBus.close();
    await panel.close();
    expect(const AppSettings().desktop.closeBehavior.name, 'minimizeToTray');
  });

  test('without a tray host closing minimizes and Settings can explain why', () async {
    final paths = AppPaths.forTesting(tmp);
    final settings = SettingsStore.inMemory();
    final window = FakeWindowBackend();
    final sessionBus = bus.client();
    final integration = await DesktopIntegration.start(
      platform: const PlatformInfo(os: HostOs.linux),
      playback: FakePlaybackController(),
      settings: settings,
      paths: paths,
      disposeAll: () async {},
      sessionBus: sessionBus,
      window: window,
      trayBackend: FakeTrayBackend(),
      trayAssetsRoot: p.join(tmp.path, 'none'),
      hotkeyBackend: FakeHotkeyBackend(),
      environment: const {'XDG_CURRENT_DESKTOP': 'ubuntu:GNOME', 'XDG_SESSION_TYPE': 'wayland', 'WAYLAND_DISPLAY': 'wayland-0'},
      exitProcess: (_) {},
    );
    final lifecycle = integration.lifecycle as DesktopLifecycleController;
    expect(lifecycle.trayAvailable, isFalse);
    expect(lifecycle.trayUnavailableReason, contains('AppIndicator'));
    expect(integration.hotkeys.isSupported, isFalse, reason: 'Wayland session');

    window.fire(WindowEventKind.close);
    await settle();
    expect(window.minimized, isTrue);
    expect(window.calls, isNot(contains('hide')));

    await lifecycle.quit();
    await sessionBus.close();
  });
}
