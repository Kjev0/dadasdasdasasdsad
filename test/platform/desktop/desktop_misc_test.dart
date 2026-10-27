import 'dart:io';
import 'dart:ui';

import 'package:fermata/core/contracts/platform.dart';
import 'package:fermata/core/platform/app_paths.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/platform/desktop/desktop_integration.dart';
import 'package:fermata/platform/desktop/desktop_l10n.dart';
import 'package:fermata/platform/desktop/noop.dart';
import 'package:fermata/platform/desktop/startup/startup_manager.dart';
import 'package:fermata/platform/desktop/tray/tray_icon_locator.dart';
import 'package:fermata/platform/windows/windows_run_key.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'fakes.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('fermata-desktop-'));
  tearDown(() async => tmp.delete(recursive: true));

  group('DesktopIntegration', () {
    test('non-desktop platforms get no-op services', () async {
      final playback = FakePlaybackController();
      final integration = await DesktopIntegration.start(
        platform: const PlatformInfo(os: HostOs.android),
        playback: playback,
        settings: SettingsStore.inMemory(),
        paths: AppPaths.forTesting(tmp),
        disposeAll: () async {},
      );
      expect(integration.lifecycle, isA<NoopLifecycleController>());
      expect(integration.startup.isSupported, isFalse);
      expect(integration.hotkeys.isSupported, isFalse);
      expect(integration.notifier.isSupported, isFalse);
      expect(integration.mpris, isNull);
      expect(integration.smtc, isNull);
    });

    test('playLocalFile queues a user-owned local track', () async {
      final playback = FakePlaybackController();
      final f = File(p.join(tmp.path, 'Freddie Freeloader.mp3'))..writeAsStringSync('x');
      await DesktopIntegration.playLocalFile(playback, f.path);
      expect(playback.calls, ['playTracks:${f.absolute.path}']);
      final t = playback.queue.current!.track;
      expect(t.title, 'Freddie Freeloader');
      expect(t.isLocal, isTrue);
      expect(t.availability.isPlayableInApp, isTrue);

      await DesktopIntegration.playLocalFile(playback, p.join(tmp.path, 'missing.mp3'));
      expect(playback.calls, hasLength(1));
    });
  });

  group('no-ops', () {
    test('are inert', () async {
      const lifecycle = NoopLifecycleController();
      await lifecycle.init();
      await lifecycle.showWindow();
      await lifecycle.hideWindow();
      await lifecycle.quit();
      lifecycle.closeDecisionDelegate = () async => (CloseChoice.quit, false);
      expect(lifecycle.trayAvailable, isFalse);

      const startup = NoopStartupManager();
      await startup.setEnabled(true);
      expect(await startup.isEnabled(), isFalse);

      const hotkeys = NoopGlobalHotkeyService();
      await hotkeys.apply(const {'global.next': 'ctrl+n'}, enabled: true);
      expect(hotkeys.registrationErrors, isEmpty);

      const notifier = NoopSystemNotifier();
      await notifier.show(id: 'a', title: 'b');
      expect(notifier.isSupported, isFalse);
    });

    test('StartupManagerImpl is unsupported off Linux/Windows', () async {
      final m = StartupManagerImpl(platform: const PlatformInfo(os: HostOs.android));
      expect(m.isSupported, isFalse);
      expect(await m.isEnabled(), isFalse);
      await m.setEnabled(true);
    });
  });

  group('Windows Run key', () {
    test('command line quotes the executable and adds --minimized', () {
      expect(WindowsRunKeyAutostart.commandLine(r'C:\Program Files\Fermata\fermata.exe', startMinimized: true),
          r'"C:\Program Files\Fermata\fermata.exe" --minimized');
      expect(WindowsRunKeyAutostart.commandLine(r'C:\Fermata\fermata.exe', startMinimized: false),
          r'"C:\Fermata\fermata.exe"');
      expect(WindowsRunKeyAutostart.runKeyPath, r'Software\Microsoft\Windows\CurrentVersion\Run');
      expect(WindowsRunKeyAutostart.valueName, 'Fermata');
    });

    test('StartupApproved markers', () {
      expect(WindowsRunKeyAutostart.approvedDataDisablesEntry(null), isFalse);
      expect(WindowsRunKeyAutostart.approvedDataDisablesEntry([0x02, 0, 0]), isFalse);
      expect(WindowsRunKeyAutostart.approvedDataDisablesEntry([0x06, 0, 0]), isFalse);
      expect(WindowsRunKeyAutostart.approvedDataDisablesEntry([0x03, 1, 2]), isTrue);
      expect(WindowsRunKeyAutostart.approvedDataDisablesEntry([0x07]), isTrue);
    });

    test('refuses to touch the registry off Windows', () async {
      if (Platform.isWindows) return;
      await expectLater(WindowsRunKeyAutostart(executable: 'x').enable(startMinimized: false), throwsUnsupportedError);
    });
  });

  group('TrayIconLocator', () {
    late Directory assets;
    setUp(() {
      assets = Directory(p.join(tmp.path, 'flutter_assets', 'assets', 'branding'))..createSync(recursive: true);
    });
    String root() => p.join(tmp.path, 'flutter_assets');

    test('missing files → null (tray skipped)', () async {
      expect(await TrayIconLocator(platform: const PlatformInfo(os: HostOs.linux), assetsRoot: root()).resolve(), isNull);
    });

    test('Linux: colour icon by default, mono on dark panels', () async {
      File(p.join(assets.path, 'tray_icon.png')).writeAsStringSync('png');
      File(p.join(assets.path, 'tray_icon_mono.png')).writeAsStringSync('png');
      final light = TrayIconLocator(platform: const PlatformInfo(os: HostOs.linux), assetsRoot: root());
      expect(await light.resolve(), p.join(assets.path, 'tray_icon.png'));
      final dark = TrayIconLocator(
        platform: const PlatformInfo(os: HostOs.linux),
        assetsRoot: root(),
        prefersDarkPanel: () async => true,
      );
      expect(await dark.resolve(), p.join(assets.path, 'tray_icon_mono.png'));
    });

    test('Linux dark panel without mono variant falls back to colour', () async {
      File(p.join(assets.path, 'tray_icon.png')).writeAsStringSync('png');
      final dark = TrayIconLocator(
        platform: const PlatformInfo(os: HostOs.linux),
        assetsRoot: root(),
        prefersDarkPanel: () async => throw StateError('portal broke'),
      );
      expect(await dark.resolve(), p.join(assets.path, 'tray_icon.png'));
    });

    test('Windows prefers the .ico', () async {
      File(p.join(assets.path, 'tray_icon.png')).writeAsStringSync('png');
      final win = TrayIconLocator(platform: const PlatformInfo(os: HostOs.windows), assetsRoot: root());
      expect(await win.resolve(), p.join(assets.path, 'tray_icon.png'));
      File(p.join(assets.path, 'tray_icon.ico')).writeAsStringSync('ico');
      expect(await win.resolve(), p.join(assets.path, 'tray_icon.ico'));
    });

    test('default assets root is next to the executable', () {
      expect(TrayIconLocator.defaultAssetsRoot(),
          p.join(p.dirname(Platform.resolvedExecutable), 'data', 'flutter_assets'));
    });
  });

  group('desktopLocalizations', () {
    test('setting, then system language, then English', () {
      expect(desktopLocalizations('da').desktopTrayQuit, 'Afslut Fermata');
      expect(desktopLocalizations(null, systemLocale: const Locale('da', 'DK')).desktopTrayQuit, 'Afslut Fermata');
      expect(desktopLocalizations(null, systemLocale: const Locale('fr')).desktopTrayQuit, 'Quit Fermata');
      expect(desktopLocalizations('xx', systemLocale: const Locale('fr')).desktopTrayQuit, 'Quit Fermata');
    });

    test('Danish and English strings exist for every desktop key', () {
      final en = desktopLocalizations('en');
      final da = desktopLocalizations('da');
      expect(da.desktopTrayNowPlaying('A', 'B'), 'A — B');
      expect(da.desktopHotkeyErrorDuplicate('ctrl+x'), contains('ctrl+x'));
      expect(en.desktopCloseDialogTitle, 'Close Fermata?');
      expect(da.desktopCloseDialogTitle, 'Vil du lukke Fermata?');
    });
  });
}
