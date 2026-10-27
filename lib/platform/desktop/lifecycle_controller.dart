import 'dart:async';
import 'dart:io' show exit;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../core/contracts/platform.dart';
import '../../core/contracts/playback.dart';
import '../../core/platform/app_paths.dart';
import '../../core/platform/platform_info.dart';
import '../../settings/settings_store.dart';
import 'single_instance.dart';
import 'tray/tray_controller.dart';
import 'window/window_backend.dart';
import 'window/window_state.dart';

final _log = Logger('desktop.lifecycle');

/// Desktop window + app lifecycle (Linux, Windows) on top of
/// `window_manager`:
///
/// * closing the window does not stop music: it hides to the tray, or
///   minimizes when no tray is available, per `desktop.closeBehavior`;
/// * window bounds are restored (validated against the connected displays)
///   and saved on move/resize (debounced);
/// * `desktop.startMinimized` / `--minimized` start hidden (or minimized);
/// * commands from later launches (single instance) show the window or
///   control playback;
/// * [quit] shuts everything down in order and exits.
class DesktopLifecycleController implements AppLifecycleController {
  DesktopLifecycleController({
    required this._playback,
    required this._settings,
    required AppPaths paths,
    required this._platform,
    required this._disposeAll,
    required this._tray,
    WindowBackend? window,
    this._args = const [],
    this._instanceCommands,
    this._launchCommands = const [],
    this._openFile,
    void Function(int code)? exitProcess,
    this.quitStepTimeout = const Duration(seconds: 4),
    this.exitGracePeriod = const Duration(seconds: 3),
    this.boundsSaveDebounce = const Duration(milliseconds: 500),
    this.startHiddenGrace = const Duration(milliseconds: 2500),
  })  : _window = window ?? WindowManagerBackend(),
        _exit = exitProcess ?? exit,
        _boundsStore = WindowStateStore(paths.windowStateFile) {
    _tray.onShowWindow = showWindow;
    _tray.onQuit = quit;
  }

  static const windowTitle = 'Fermata';
  static const minimizedFlag = '--minimized';

  final PlaybackController _playback;
  final SettingsStore _settings;
  final PlatformInfo _platform;
  final Future<void> Function() _disposeAll;
  final TrayController _tray;
  final WindowBackend _window;
  final List<String> _args;
  final Stream<String>? _instanceCommands;
  final List<String> _launchCommands;
  final Future<void> Function(String path)? _openFile;
  final void Function(int code) _exit;
  final WindowStateStore _boundsStore;
  final Duration quitStepTimeout;
  final Duration exitGracePeriod;
  final Duration boundsSaveDebounce;

  /// The stock Flutter runners show the window when the first frame is
  /// rendered, i.e. after [init]. When starting hidden/minimized, a show or
  /// restore within this period re-applies the start state.
  final Duration startHiddenGrace;

  final _shutdownHooks = <(String, Future<void> Function())>[];
  final _subs = <StreamSubscription<Object?>>[];
  Future<(CloseChoice, bool remember)> Function()? _closeDelegate;
  Future<void>? _initFuture;
  Future<void>? _quitFuture;
  Timer? _boundsTimer;
  Rect? _lastNormalBounds;
  bool _hiddenToTray = false;
  bool _askingClose = false;
  bool _miniMode = false;
  Rect? _boundsBeforeMini;
  bool _maximizedBeforeMini = false;
  bool _keepStartHidden = false;
  Timer? _startHiddenTimer;

  @override
  bool get trayAvailable => _tray.isActive;

  /// Why the tray is not shown (localized), null when it is. Settings uses
  /// this to explain e.g. GNOME without the AppIndicator extension.
  String? get trayUnavailableReason => _tray.unavailableReason;

  TrayStatus get trayStatus => _tray.status;

  bool get isQuitting => _quitFuture != null;

  bool get isMiniMode => _miniMode;

  @override
  set closeDecisionDelegate(Future<(CloseChoice, bool remember)> Function()? delegate) => _closeDelegate = delegate;

  /// Registers work for [quit] that runs after the tray is destroyed and
  /// before `disposeAll` (hotkeys, MPRIS, SMTC, notifier, single instance).
  void addShutdownHook(String name, Future<void> Function() hook) => _shutdownHooks.add((name, hook));

  @override
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    if (!_platform.isDesktop) return;
    await _window.ensureInitialized();
    await _safe('setPreventClose', () => _window.setPreventClose(true));
    await _safe('setTitle', () => _window.setTitle(windowTitle));
    await _safe('setMinimumSize', () => _window.setMinimumSize(kMinWindowSize));
    await _restoreBounds();
    await _tray.start();

    _subs.add(_window.events.listen(_onWindowEvent));
    _subs.add(_tray.activeChanges.listen(_onTrayActiveChanged));
    final commands = _instanceCommands;
    if (commands != null) _subs.add(commands.listen((c) => unawaited(handleCommand(c))));

    final startHidden = _settings.current.desktop.startMinimized || _args.contains(minimizedFlag);
    if (startHidden) {
      _log.info('Starting ${trayAvailable ? 'hidden to tray' : 'minimized'}');
      if (trayAvailable) {
        await hideWindow();
      } else {
        // Not shown yet: iconify before the runner maps the window.
        await _safe('minimize', _window.minimize);
      }
      _keepStartHidden = true;
      _startHiddenTimer = Timer(startHiddenGrace, () => _keepStartHidden = false);
    } else {
      await _safe('show', _window.show);
      await _safe('focus', _window.focus);
    }
    for (final c in _launchCommands) {
      await handleCommand(c);
    }
  }

  Future<void> _restoreBounds() async {
    if (!_settings.current.desktop.rememberWindowBounds) return;
    final saved = await _boundsStore.load();
    if (saved == null) return;
    final areas = await _window.displayWorkAreas();
    final fitted = fitWindowBounds(saved, areas);
    _lastNormalBounds = fitted.rect;
    await _safe('setBounds', () => _window.setBounds(fitted.rect));
    if (fitted.maximized) await _safe('maximize', _window.maximize);
  }

  void _onWindowEvent(WindowEventKind e) {
    switch (e) {
      case WindowEventKind.close:
        unawaited(handleCloseRequest());
      case WindowEventKind.moved ||
            WindowEventKind.resized ||
            WindowEventKind.maximized ||
            WindowEventKind.unmaximized:
        _scheduleBoundsSave();
      case WindowEventKind.shown || WindowEventKind.restored:
        if (_keepStartHidden) {
          // The runner showed the window on its first frame.
          unawaited(hideWindow());
          return;
        }
        _hiddenToTray = false;
      case WindowEventKind.focused:
        if (!_keepStartHidden) _hiddenToTray = false;
      case WindowEventKind.minimized || WindowEventKind.hidden:
        break;
    }
  }

  void _onTrayActiveChanged(bool active) {
    // Never leave the app unreachable: the icon the window was hidden to
    // went away (setting turned off, panel crashed).
    if (!active && _hiddenToTray && !isQuitting) unawaited(showWindow());
  }

  /// Handles a close request according to `desktop.closeBehavior`. Called
  /// for the window's close button (prevent-close is on).
  @visibleForTesting
  Future<void> handleCloseRequest() async {
    if (isQuitting) return;
    switch (_settings.current.desktop.closeBehavior) {
      case CloseBehavior.minimizeToTray:
        await hideWindow();
      case CloseBehavior.exit:
        await quit();
      case CloseBehavior.ask:
        await _ask();
    }
  }

  Future<void> _ask() async {
    final delegate = _closeDelegate;
    if (delegate == null) {
      // No UI registered (yet): keep playing rather than quitting.
      await hideWindow();
      return;
    }
    if (_askingClose) return;
    _askingClose = true;
    try {
      final (choice, remember) = await delegate();
      if (remember && choice != CloseChoice.cancel) {
        final behavior = choice == CloseChoice.quit ? CloseBehavior.exit : CloseBehavior.minimizeToTray;
        await _settings.update((s) => s.copyWith(desktop: s.desktop.copyWith(closeBehavior: behavior)));
      }
      switch (choice) {
        case CloseChoice.minimizeToTray:
          await hideWindow();
        case CloseChoice.quit:
          await quit();
        case CloseChoice.cancel:
          break;
      }
    } catch (e, st) {
      _log.warning('Close dialog failed; keeping Fermata running', e, st);
      await hideWindow();
    } finally {
      _askingClose = false;
    }
  }

  /// Runs a command from another launch (see [InstanceCommands]).
  Future<void> handleCommand(String command) async {
    try {
      switch (command) {
        case InstanceCommands.show:
          await showWindow();
        case InstanceCommands.playPause:
          await _playback.togglePlayPause();
        case InstanceCommands.next:
          await _playback.next();
        case InstanceCommands.previous:
          await _playback.previous();
        default:
          if (command.startsWith(InstanceCommands.openPrefix)) {
            final path = command.substring(InstanceCommands.openPrefix.length);
            final open = _openFile;
            if (open == null) {
              _log.info('Ignoring "open" command: no file opener configured');
            } else {
              await open(path);
            }
          } else {
            _log.info('Unknown instance command "$command"');
          }
      }
    } catch (e, st) {
      _log.warning('Instance command "$command" failed', e, st);
    }
  }

  @override
  Future<void> showWindow() async {
    _cancelStartHidden();
    _hiddenToTray = false;
    if (await _safeValue('isMinimized', _window.isMinimized, false)) {
      await _safe('restore', _window.restore);
    }
    await _safe('show', _window.show);
    await _safe('focus', _window.focus);
  }

  @override
  Future<void> hideWindow() async {
    await _flushBoundsSave();
    if (trayAvailable) {
      _hiddenToTray = true;
      await _safe('hide', _window.hide);
    } else {
      // Stay reachable via taskbar/dock and MPRIS/SMTC "Raise".
      _hiddenToTray = false;
      await _safe('show', _window.show);
      await _safe('minimize', _window.minimize);
    }
  }

  /// Compact always-on-top player window (UI "mini player"); restores the
  /// previous bounds when turned off. Mini-mode bounds are never saved.
  Future<void> setMiniMode(bool enabled, {Size size = const Size(380, 132), bool alwaysOnTop = true}) async {
    if (enabled == _miniMode) return;
    if (enabled) {
      await _flushBoundsSave();
      _boundsBeforeMini = await _safeValue<Rect?>('getBounds', _window.getBounds, null);
      _maximizedBeforeMini = await _safeValue('isMaximized', _window.isMaximized, false);
      _miniMode = true;
      if (_maximizedBeforeMini) await _safe('restore', _window.restore);
      await _safe('setMinimumSize', () => _window.setMinimumSize(size));
      final origin = _boundsBeforeMini;
      await _safe('setBounds',
          () => _window.setBounds(Rect.fromLTWH(origin?.left ?? 0, origin?.top ?? 0, size.width, size.height)));
      await _safe('setAlwaysOnTop', () => _window.setAlwaysOnTop(alwaysOnTop));
    } else {
      await _safe('setAlwaysOnTop', () => _window.setAlwaysOnTop(false));
      await _safe('setMinimumSize', () => _window.setMinimumSize(kMinWindowSize));
      final before = _boundsBeforeMini;
      if (before != null) await _safe('setBounds', () => _window.setBounds(before));
      if (_maximizedBeforeMini) await _safe('maximize', _window.maximize);
      _miniMode = false;
    }
  }

  void _cancelStartHidden() {
    _keepStartHidden = false;
    _startHiddenTimer?.cancel();
    _startHiddenTimer = null;
  }

  void _scheduleBoundsSave() {
    if (_miniMode || isQuitting) return;
    _boundsTimer?.cancel();
    _boundsTimer = Timer(boundsSaveDebounce, () {
      _boundsTimer = null;
      unawaited(_saveBounds());
    });
  }

  Future<void> _flushBoundsSave() async {
    if (_boundsTimer == null) return;
    _boundsTimer!.cancel();
    _boundsTimer = null;
    await _saveBounds();
  }

  Future<void> _saveBounds() async {
    if (_miniMode || !_settings.current.desktop.rememberWindowBounds) return;
    try {
      // Minimized windows report bogus positions (-32000 on Windows).
      if (await _window.isMinimized() || !await _window.isVisible()) return;
      final maximized = await _window.isMaximized();
      if (!maximized) _lastNormalBounds = await _window.getBounds();
      final rect = _lastNormalBounds ?? await _window.getBounds();
      await _boundsStore.save(WindowBounds(rect: rect, maximized: maximized));
    } catch (e) {
      _log.fine('Saving window bounds failed: $e');
    }
  }

  @override
  Future<void> quit() => _quitFuture ??= _quit();

  Future<void> _quit() async {
    _log.info('Quitting Fermata');
    _cancelStartHidden();
    await _step('window state', _flushBoundsSave);
    await _step('playback', _playback.dispose);
    await _step('settings', _settings.flush);
    await _step('tray', _tray.dispose);
    for (final (name, hook) in _shutdownHooks) {
      await _step(name, hook);
    }
    await _step('services', _disposeAll);
    for (final s in _subs) {
      await _step('subscription', s.cancel);
    }
    await _step('window', () async {
      await _window.setPreventClose(false);
      await _window.destroy();
    });
    // Destroying the last window normally ends the process; make sure.
    Timer(exitGracePeriod, () => _exit(0));
  }

  Future<void> _step(String name, Future<void> Function() action) async {
    try {
      await action().timeout(quitStepTimeout);
    } on TimeoutException {
      _log.warning('Quit step "$name" timed out after $quitStepTimeout');
    } catch (e, st) {
      _log.warning('Quit step "$name" failed', e, st);
    }
  }

  Future<void> _safe(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      _log.fine('Window call $what failed: $e');
    }
  }

  Future<T> _safeValue<T>(String what, Future<T> Function() action, T fallback) async {
    try {
      return await action();
    } catch (e) {
      _log.fine('Window call $what failed: $e');
      return fallback;
    }
  }
}
