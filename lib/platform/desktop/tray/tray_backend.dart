import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:tray_manager/tray_manager.dart' as tm;

import 'tray_menu.dart';

final _log = Logger('desktop.tray');

/// The native tray icon, abstracted so [TrayController] can be tested.
abstract class TrayBackend {
  /// Creates and shows the icon. Returns false when the image cannot be
  /// loaded or the platform refuses the icon.
  Future<bool> create({
    required String iconPath,
    required void Function() onActivate,
    required void Function(String id) onMenuItem,
  });

  Future<void> setTooltip(String tooltip);

  /// Replaces the context menu.
  Future<void> setMenu(List<TrayMenuEntry> entries);

  /// Removes the icon. Safe to call when nothing was created.
  Future<void> destroy();
}

/// [TrayBackend] on top of `tray_manager` 0.8 (nativeapi: StatusNotifierItem
/// over D-Bus on Linux, `Shell_NotifyIcon` on Windows).
class NativeTrayBackend implements TrayBackend {
  tm.TrayIcon? _icon;
  tm.Image? _image;
  tm.ListenerId? _iconListener;
  _NativeMenu? _menu;
  void Function()? _onActivate;
  void Function(String id)? _onMenuItem;

  @override
  Future<bool> create({
    required String iconPath,
    required void Function() onActivate,
    required void Function(String id) onMenuItem,
  }) async {
    await destroy();
    try {
      final image = tm.Image.fromFile(iconPath);
      if (image == null) {
        _log.warning('Tray icon image could not be loaded: $iconPath');
        return false;
      }
      final icon = tm.TrayIcon.create();
      if (icon == null) {
        image.dispose();
        _log.warning('The platform refused to create a tray icon');
        return false;
      }
      icon.icon = image;
      // Windows: left click shows the window, right click opens the menu.
      // Linux: the native StatusNotifierItem only exports its menu over
      // dbusmenu (instead of Menu=/NO_DBUSMENU) once a trigger is set; the
      // panel then opens it itself.
      if (Platform.isWindows || Platform.isLinux) icon.setContextMenuTrigger(tm.ContextMenuTrigger.rightClicked);
      _onActivate = onActivate;
      _onMenuItem = onMenuItem;
      _iconListener = icon.addListener((event) {
        if (event is tm.TrayIconClickedEvent || event is tm.TrayIconDoubleClickedEvent) {
          _onActivate?.call();
        }
      });
      icon.setVisible(true);
      _icon = icon;
      _image = image;
      return true;
    } catch (e, st) {
      // Missing native library (e.g. libcnativeapi) or unsupported session.
      _log.warning('Tray icon creation failed', e, st);
      return false;
    }
  }

  @override
  Future<void> setTooltip(String tooltip) async {
    try {
      _icon?.setTooltip(tooltip);
    } catch (e) {
      _log.fine('setTooltip failed: $e');
    }
  }

  @override
  Future<void> setMenu(List<TrayMenuEntry> entries) async {
    final icon = _icon;
    if (icon == null) return;
    try {
      final menu = _NativeMenu.build(entries, (id) => _onMenuItem?.call(id));
      icon.setContextMenu(menu.menu);
      final old = _menu;
      _menu = menu;
      // A click handler may be running inside the old menu's native
      // callback; release it on the next event-loop turn.
      if (old != null) Timer.run(old.dispose);
    } catch (e, st) {
      _log.warning('Updating the tray menu failed', e, st);
    }
  }

  @override
  Future<void> destroy() async {
    final icon = _icon;
    _icon = null;
    if (icon != null) {
      try {
        final id = _iconListener;
        if (id != null) icon.removeListener(id);
        icon.setContextMenu(null);
        icon.setVisible(false);
        icon.dispose();
      } catch (e) {
        _log.fine('Tray destroy failed: $e');
      }
    }
    _iconListener = null;
    final menu = _menu;
    _menu = null;
    if (menu != null) Timer.run(menu.dispose);
    try {
      _image?.dispose();
    } catch (_) {}
    _image = null;
  }
}

class _NativeMenu {
  _NativeMenu._(this.menu);

  final tm.Menu menu;
  final _items = <(tm.MenuItem, tm.ListenerId)>[];

  static _NativeMenu build(List<TrayMenuEntry> entries, void Function(String id) onClick) {
    final menu = tm.Menu.create();
    if (menu == null) throw StateError('Unable to create the tray menu');
    final result = _NativeMenu._(menu);
    for (final entry in entries) {
      if (entry.separator) {
        menu.addSeparator();
        continue;
      }
      final item = tm.MenuItem.createWithLabelAndType(entry.label, tm.MenuItemType.normal);
      if (item == null) throw StateError('Unable to create tray menu item ${entry.id}');
      item.isEnabled = entry.enabled;
      final id = entry.id;
      final listener = item.addListener((event) {
        if (event is tm.MenuItemClickedEvent) onClick(id);
      });
      result._items.add((item, listener));
      menu.addItem(item);
    }
    return result;
  }

  void dispose() {
    for (final (item, listener) in _items) {
      try {
        item.removeListener(listener);
      } catch (_) {}
    }
    _items.clear();
  }
}
