import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:fermata/core/contracts/platform.dart';
import 'package:fermata/core/platform/app_paths.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/platform/desktop/lifecycle_controller.dart';
import 'package:fermata/platform/desktop/tray/tray_availability.dart';
import 'package:fermata/platform/desktop/tray/tray_controller.dart';
import 'package:fermata/platform/desktop/tray/tray_menu.dart';
import 'package:fermata/platform/desktop/window/window_backend.dart';
import 'package:fermata/platform/desktop/window/window_state.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late Directory tmp;
  late AppPaths paths;
  late FakePlaybackController playback;
  late SettingsStore settings;
  late FakeWindowBackend window;
  late FakeTrayBackend trayBackend;
  late FakeTrayProbe probe;
  late TrayController tray;
  late List<String> order;
  late List<int> exitCodes;
  late StreamController<String> commands;
  late List<String> openedFiles;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fermata-lifecycle-');
    paths = AppPaths.forTesting(tmp);
    playback = FakePlaybackController();
    settings = SettingsStore.inMemory();
    window = FakeWindowBackend();
    trayBackend = FakeTrayBackend();
    probe = FakeTrayProbe();
    order = [];
    exitCodes = [];
    commands = StreamController<String>.broadcast();
    openedFiles = [];
    tray = TrayController(
      backend: trayBackend,
      probe: probe,
      settings: settings,
      playback: playback,
      resolveIconPath: () async => '/icons/tray_icon.png',
      menuDebounce: const Duration(milliseconds: 10),
    );
  });

  tearDown(() async {
    await commands.close();
    await tmp.delete(recursive: true);
  });

  DesktopLifecycleController controller({List<String> args = const [], List<String> launch = const []}) =>
      DesktopLifecycleController(
        playback: playback,
        settings: settings,
        paths: paths,
        platform: const PlatformInfo(os: HostOs.linux),
        disposeAll: () async => order.add('disposeAll'),
        tray: tray,
        window: window,
        args: args,
        instanceCommands: commands.stream,
        launchCommands: launch,
        openFile: (path) async => openedFiles.add(path),
        exitProcess: exitCodes.add,
        quitStepTimeout: const Duration(milliseconds: 300),
        exitGracePeriod: const Duration(milliseconds: 50),
        boundsSaveDebounce: const Duration(milliseconds: 30),
      );

  /// Waits (polling, the write is fsync'ed) until [expected] is on disk.
  Future<void> savedBounds(WindowBounds expected) async {
    final store = WindowStateStore(paths.windowStateFile);
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (await store.load() != expected) {
      if (DateTime.now().isAfter(end)) fail('window state never became $expected (is ${await store.load()})');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> setDesktop(DesktopSettings Function(DesktopSettings d) change) =>
      settings.update((s) => s.copyWith(desktop: change(s.desktop)));

  group('init', () {
    test('prevents close, sets title and minimum size, shows the window, creates the tray', () async {
      final c = controller();
      await c.init();
      expect(window.calls.take(4), ['ensureInitialized', 'setPreventClose:true', 'setTitle:Fermata', 'setMinimumSize:380x600']);
      expect(window.visible, isTrue);
      expect(window.calls, contains('focus'));
      expect(c.trayAvailable, isTrue);
      expect(trayBackend.created, isTrue);
      await c.init(); // idempotent
      expect(window.calls.where((x) => x == 'ensureInitialized'), hasLength(1));
    });

    test('restores saved bounds (validated) and maximized state', () async {
      await WindowStateStore(paths.windowStateFile)
          .save(const WindowBounds(rect: Rect.fromLTWH(300, 200, 1000, 700), maximized: true));
      await controller().init();
      expect(window.calls, contains('setBounds:300,200,1000x700'));
      expect(window.calls, contains('maximize'));
    });

    test('off-screen saved bounds are moved onto the primary display', () async {
      await WindowStateStore(paths.windowStateFile).save(const WindowBounds(rect: Rect.fromLTWH(5000, 3000, 1000, 700)));
      await controller().init();
      expect(window.bounds, const Rect.fromLTWH(460, 190, 1000, 700));
    });

    test('rememberWindowBounds off → saved bounds ignored', () async {
      await WindowStateStore(paths.windowStateFile).save(const WindowBounds(rect: Rect.fromLTWH(300, 200, 1000, 700)));
      await setDesktop((d) => d.copyWith(rememberWindowBounds: false));
      await controller().init();
      expect(window.calls.where((x) => x.startsWith('setBounds')), isEmpty);
    });

    test('--minimized starts hidden to the tray', () async {
      await controller(args: const ['--minimized']).init();
      expect(window.visible, isFalse);
      expect(window.calls, contains('hide'));
      expect(window.calls, isNot(contains('minimize')));
    });

    test('startMinimized without a tray starts minimized (still reachable)', () async {
      probe.state = TrayHostState.gnomeWithoutAppIndicator;
      await setDesktop((d) => d.copyWith(startMinimized: true));
      final c = controller();
      await c.init();
      expect(c.trayAvailable, isFalse);
      expect(window.calls, isNot(contains('hide')));
      expect(window.minimized, isTrue, reason: 'iconified before the runner maps it');
      expect(c.trayUnavailableReason, contains('AppIndicator'));
      expect(c.trayStatus, TrayStatus.gnomeWithoutAppIndicator);
    });

    test('the runner showing the window on its first frame does not defeat start hidden', () async {
      final c = controller(args: const ['--minimized']);
      await c.init();
      expect(window.visible, isFalse);
      window.visible = true; // runner: gtk_widget_show / ShowWindow on first frame
      window.fire(WindowEventKind.shown);
      await settle();
      expect(window.visible, isFalse);

      // An explicit show (tray, MPRIS Raise, second launch) wins.
      await c.showWindow();
      window.fire(WindowEventKind.shown);
      await settle();
      expect(window.visible, isTrue);
    });

    test('start minimized without tray stays minimized after the runner restores it', () async {
      probe.state = TrayHostState.noHost;
      await controller(args: const ['--minimized']).init();
      expect(window.minimized, isTrue);
      window.minimized = false; // Windows runner: ShowWindow(SW_SHOWNORMAL)
      window.fire(WindowEventKind.restored);
      await settle();
      expect(window.minimized, isTrue);
    });

    test('the start-hidden guard expires', () async {
      final c = DesktopLifecycleController(
        playback: playback,
        settings: settings,
        paths: paths,
        platform: const PlatformInfo(os: HostOs.linux),
        disposeAll: () async {},
        tray: tray,
        window: window,
        args: const ['--minimized'],
        startHiddenGrace: const Duration(milliseconds: 20),
      );
      await c.init();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      window.visible = true;
      window.fire(WindowEventKind.shown);
      await settle();
      expect(window.visible, isTrue);
    });

    test('runs launch commands of the primary instance', () async {
      playback.load([track('1')]);
      await controller(launch: const ['play-pause']).init();
      expect(playback.calls, ['togglePlayPause']);
    });
  });

  group('close button', () {
    test('minimizeToTray (default) hides the window and keeps playing', () async {
      final c = controller();
      await c.init();
      playback.load([track('1')], playing: true);
      window.fire(WindowEventKind.close);
      await settle();
      expect(window.visible, isFalse);
      expect(playback.calls, isNot(contains('dispose')));
      expect(playback.snapshot.playing, isTrue);
      expect(exitCodes, isEmpty);
    });

    test('without a tray the window is minimized instead of hidden', () async {
      probe.state = TrayHostState.noHost;
      final c = controller();
      await c.init();
      await c.handleCloseRequest();
      expect(window.calls, isNot(contains('hide')));
      expect(window.minimized, isTrue);
    });

    test('exit quits', () async {
      await setDesktop((d) => d.copyWith(closeBehavior: CloseBehavior.exit));
      final c = controller();
      await c.init();
      await c.handleCloseRequest();
      expect(c.isQuitting, isTrue);
      expect(playback.calls, contains('dispose'));
      expect(window.calls, contains('destroy'));
    });

    test('ask without a registered dialog keeps the app running (minimize)', () async {
      await setDesktop((d) => d.copyWith(closeBehavior: CloseBehavior.ask));
      final c = controller();
      await c.init();
      await c.handleCloseRequest();
      expect(window.visible, isFalse);
      expect(c.isQuitting, isFalse);
    });

    test('ask → keep playing, remembered', () async {
      await setDesktop((d) => d.copyWith(closeBehavior: CloseBehavior.ask));
      final c = controller();
      var asked = 0;
      c.closeDecisionDelegate = () async {
        asked++;
        return (CloseChoice.minimizeToTray, true);
      };
      await c.init();
      await c.handleCloseRequest();
      expect(asked, 1);
      expect(window.visible, isFalse);
      expect(settings.current.desktop.closeBehavior, CloseBehavior.minimizeToTray);
      await c.handleCloseRequest();
      expect(asked, 1, reason: 'remembered choice is not asked again');
    });

    test('ask → quit, remembered as exit', () async {
      await setDesktop((d) => d.copyWith(closeBehavior: CloseBehavior.ask));
      final c = controller();
      c.closeDecisionDelegate = () async => (CloseChoice.quit, true);
      await c.init();
      await c.handleCloseRequest();
      expect(settings.current.desktop.closeBehavior, CloseBehavior.exit);
      expect(c.isQuitting, isTrue);
    });

    test('ask → cancel does nothing and is never remembered', () async {
      await setDesktop((d) => d.copyWith(closeBehavior: CloseBehavior.ask));
      final c = controller();
      c.closeDecisionDelegate = () async => (CloseChoice.cancel, true);
      await c.init();
      await c.handleCloseRequest();
      expect(window.visible, isTrue);
      expect(settings.current.desktop.closeBehavior, CloseBehavior.ask);
      expect(c.isQuitting, isFalse);
    });

    test('a failing dialog falls back to minimize', () async {
      await setDesktop((d) => d.copyWith(closeBehavior: CloseBehavior.ask));
      final c = controller();
      c.closeDecisionDelegate = () async => throw StateError('no navigator');
      await c.init();
      await c.handleCloseRequest();
      expect(window.visible, isFalse);
    });
  });

  group('quit', () {
    test('shuts down in order, destroys the window and exits as a last resort', () async {
      final c = controller();
      c.addShutdownHook('hotkeys', () async => order.add('hotkeys'));
      c.addShutdownHook('mpris', () async => order.add('mpris'));
      await c.init();
      playback.calls.clear();

      final f1 = c.quit();
      final f2 = c.quit();
      expect(identical(f1, f2), isTrue, reason: 're-entrant calls share one shutdown');
      await f1;
      expect(playback.calls, ['dispose']);
      expect(trayBackend.created, isFalse);
      expect(order, ['hotkeys', 'mpris', 'disposeAll']);
      expect(window.calls.sublist(window.calls.length - 2), ['setPreventClose:false', 'destroy']);
      expect(exitCodes, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(exitCodes, [0]);
    });

    test('a hanging step times out and shutdown continues', () async {
      final c = controller();
      await c.init();
      playback.disposeGate = Completer<void>(); // never completes
      await c.quit();
      expect(order, ['disposeAll']);
      expect(window.calls, contains('destroy'));
    });

    test('a failing hook does not stop the shutdown', () async {
      final c = controller();
      c.addShutdownHook('broken', () async => throw StateError('boom'));
      await c.init();
      await c.quit();
      expect(order, ['disposeAll']);
      expect(window.calls, contains('destroy'));
    });

    test('settings are flushed on quit', () async {
      final file = File('${tmp.path}/settings.json');
      final persisted = await SettingsStore.load(file);
      final c = DesktopLifecycleController(
        playback: playback,
        settings: persisted,
        paths: paths,
        platform: const PlatformInfo(os: HostOs.linux),
        disposeAll: () async {},
        tray: tray,
        window: window,
        exitProcess: exitCodes.add,
        exitGracePeriod: const Duration(milliseconds: 10),
      );
      await c.init();
      await persisted.update((s) => s.copyWith(localeCode: 'da'));
      await c.quit();
      expect(jsonDecode(await file.readAsString())['localeCode'], 'da');
    });

    test('tray "Quit Fermata" quits', () async {
      final c = controller();
      await c.init();
      trayBackend.onMenuItem!(TrayMenuIds.quit);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.isQuitting, isTrue);
    });
  });

  group('window bounds', () {
    test('saved after move/resize (debounced), not while minimized', () async {
      final c = controller();
      await c.init();
      window.bounds = const Rect.fromLTWH(50, 60, 900, 640);
      window.fire(WindowEventKind.moved);
      window.fire(WindowEventKind.resized);
      expect(await paths.windowStateFile.exists(), isFalse, reason: 'debounced');
      await savedBounds(const WindowBounds(rect: Rect.fromLTWH(50, 60, 900, 640)));

      window.minimized = true;
      window.bounds = const Rect.fromLTWH(-32000, -32000, 160, 28);
      window.fire(WindowEventKind.moved);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect((await WindowStateStore(paths.windowStateFile).load())!.rect, const Rect.fromLTWH(50, 60, 900, 640));
      expect(c.isMiniMode, isFalse);
    });

    test('maximized windows keep the last normal bounds', () async {
      await controller().init();
      window.bounds = const Rect.fromLTWH(10, 20, 1000, 700);
      window.fire(WindowEventKind.resized);
      await savedBounds(const WindowBounds(rect: Rect.fromLTWH(10, 20, 1000, 700)));
      window.maximized = true;
      window.bounds = const Rect.fromLTWH(0, 0, 1920, 1040);
      window.fire(WindowEventKind.maximized);
      await savedBounds(const WindowBounds(rect: Rect.fromLTWH(10, 20, 1000, 700), maximized: true));
    });

    test('mini mode shrinks the window and restores it; its bounds are not saved', () async {
      final c = controller();
      await c.init();
      window.bounds = const Rect.fromLTWH(100, 100, 1200, 780);
      await c.setMiniMode(true);
      expect(c.isMiniMode, isTrue);
      expect(window.bounds, const Rect.fromLTWH(100, 100, 380, 132));
      expect(window.calls, contains('setAlwaysOnTop:true'));
      window.fire(WindowEventKind.resized);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(await paths.windowStateFile.exists(), isFalse);

      await c.setMiniMode(false);
      expect(window.bounds, const Rect.fromLTWH(100, 100, 1200, 780));
      expect(window.minimumSize, kMinWindowSize);
      expect(window.calls, contains('setAlwaysOnTop:false'));
    });
  });

  group('single instance commands', () {
    test('show / play-pause / next / previous / open', () async {
      final c = controller();
      await c.init();
      await c.hideWindow();
      playback.load([track('1'), track('2')]);

      commands.add('show');
      await settle();
      expect(window.visible, isTrue);
      commands.add('play-pause');
      commands.add('next');
      commands.add('previous');
      commands.add('open /music/a.flac');
      commands.add('bogus');
      await settle();
      expect(playback.calls, ['togglePlayPause', 'next', 'previous']);
      expect(openedFiles, ['/music/a.flac']);
    });

    test('show restores a minimized window', () async {
      final c = controller();
      await c.init();
      window.minimized = true;
      await c.showWindow();
      expect(window.calls, contains('restore'));
      expect(window.minimized, isFalse);
    });
  });

  test('turning the tray off while hidden brings the window back', () async {
    final c = controller();
    await c.init();
    await c.hideWindow();
    expect(window.visible, isFalse);
    await setDesktop((d) => d.copyWith(showTrayIcon: false));
    await tray.idle;
    await settle();
    expect(c.trayAvailable, isFalse);
    expect(window.visible, isTrue);
  });

  test('non-desktop platforms do nothing', () async {
    final c = DesktopLifecycleController(
      playback: playback,
      settings: settings,
      paths: paths,
      platform: const PlatformInfo(os: HostOs.android),
      disposeAll: () async {},
      tray: tray,
      window: window,
    );
    await c.init();
    expect(window.calls, isEmpty);
  });
}
