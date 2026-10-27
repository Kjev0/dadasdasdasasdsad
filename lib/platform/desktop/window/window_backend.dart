import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:flutter/services.dart' show MethodChannel;
import 'package:logging/logging.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

final _log = Logger('desktop.window');

/// Window events the lifecycle controller cares about.
enum WindowEventKind { close, moved, resized, maximized, unmaximized, minimized, restored, shown, hidden, focused }

/// The native main window, abstracted so the lifecycle logic can be tested
/// without a real window. [WindowManagerBackend] is the production one.
abstract class WindowBackend {
  Future<void> ensureInitialized();
  Future<void> setPreventClose(bool prevent);
  Future<void> setTitle(String title);
  Future<void> setMinimumSize(Size size);
  Future<void> setAlwaysOnTop(bool onTop);
  Future<Rect> getBounds();
  Future<void> setBounds(Rect bounds);
  Future<bool> isMaximized();
  Future<void> maximize();
  Future<bool> isMinimized();
  Future<void> minimize();
  Future<void> restore();
  Future<bool> isVisible();
  Future<void> show();
  Future<void> hide();
  Future<void> focus();
  Future<void> destroy();

  /// Work areas of all connected displays in logical pixels (first entry is
  /// the primary display). Empty when unknown.
  Future<List<Rect>> displayWorkAreas();

  Stream<WindowEventKind> get events;

  Future<void> dispose();
}

/// [WindowBackend] backed by `window_manager` + `screen_retriever`.
class WindowManagerBackend with WindowListener implements WindowBackend {
  WindowManagerBackend({WindowManager? manager, ScreenRetriever? screens})
      : _wm = manager ?? WindowManager.instance,
        _screens = screens ?? ScreenRetriever.instance;

  final WindowManager _wm;
  final ScreenRetriever _screens;

  /// window_manager's own channel. 0.5.2's `focus()` invokes `isFocused` by
  /// mistake, so the native `focus` (gtk_window_present /
  /// SetForegroundWindow) is called directly.
  static const _channel = MethodChannel('window_manager');
  final _events = StreamController<WindowEventKind>.broadcast();
  bool _listening = false;

  @override
  Stream<WindowEventKind> get events => _events.stream;

  @override
  Future<void> ensureInitialized() async {
    await _wm.ensureInitialized();
    if (!_listening) {
      _wm.addListener(this);
      _listening = true;
    }
  }

  @override
  Future<void> setPreventClose(bool prevent) => _wm.setPreventClose(prevent);

  @override
  Future<void> setTitle(String title) => _wm.setTitle(title);

  @override
  Future<void> setMinimumSize(Size size) => _wm.setMinimumSize(size);

  @override
  Future<void> setAlwaysOnTop(bool onTop) => _wm.setAlwaysOnTop(onTop);

  @override
  Future<Rect> getBounds() => _wm.getBounds();

  @override
  Future<void> setBounds(Rect bounds) => _wm.setBounds(bounds);

  @override
  Future<bool> isMaximized() => _wm.isMaximized();

  @override
  Future<void> maximize() => _wm.maximize();

  @override
  Future<bool> isMinimized() => _wm.isMinimized();

  @override
  Future<void> minimize() => _wm.minimize();

  @override
  Future<void> restore() => _wm.restore();

  @override
  Future<bool> isVisible() => _wm.isVisible();

  @override
  Future<void> show() => _wm.show();

  @override
  Future<void> hide() => _wm.hide();

  @override
  Future<void> focus() => _channel.invokeMethod<void>('focus');

  @override
  Future<void> destroy() => _wm.destroy();

  @override
  Future<List<Rect>> displayWorkAreas() async {
    try {
      final primary = await _screens.getPrimaryDisplay();
      final all = await _screens.getAllDisplays();
      final ordered = [primary, ...all.where((d) => d.id != primary.id)];
      return [for (final d in ordered) _workArea(d)];
    } catch (e) {
      // screen_retriever is unavailable on some compositors; callers clamp.
      _log.fine('Display query failed: $e');
      return const [];
    }
  }

  static Rect _workArea(Display d) {
    final pos = d.visiblePosition;
    final size = d.visibleSize ?? d.size;
    return Rect.fromLTWH(pos?.dx ?? 0, pos?.dy ?? 0, size.width, size.height);
  }

  void _emit(WindowEventKind kind) {
    if (!_events.isClosed) _events.add(kind);
  }

  @override
  void onWindowClose() => _emit(WindowEventKind.close);
  @override
  void onWindowMove() => _emit(WindowEventKind.moved);
  @override
  void onWindowMoved() => _emit(WindowEventKind.moved);
  @override
  void onWindowResize() => _emit(WindowEventKind.resized);
  @override
  void onWindowResized() => _emit(WindowEventKind.resized);
  @override
  void onWindowMaximize() => _emit(WindowEventKind.maximized);
  @override
  void onWindowUnmaximize() => _emit(WindowEventKind.unmaximized);
  @override
  void onWindowMinimize() => _emit(WindowEventKind.minimized);
  @override
  void onWindowRestore() => _emit(WindowEventKind.restored);
  @override
  void onWindowFocus() => _emit(WindowEventKind.focused);
  @override
  void onWindowEvent(String eventName) {
    if (eventName == 'show') _emit(WindowEventKind.shown);
    if (eventName == 'hide') _emit(WindowEventKind.hidden);
  }

  @override
  Future<void> dispose() async {
    if (_listening) {
      _wm.removeListener(this);
      _listening = false;
    }
    await _events.close();
  }
}
