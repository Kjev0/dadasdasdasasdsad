// Review: the real NativeTrayBackend (tray_manager 0.8 / nativeapi) on Linux
// must export its context menu over StatusNotifierItem/dbusmenu. Runs the
// native SNI implementation against a private dbus-daemon and Xvfb (GTK is
// initialised through FFI because flutter_tester never does), then reads the
// item's `Menu` property the way a panel (KDE Plasma, GNOME AppIndicator)
// does.
@TestOn('linux')
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:fermata/platform/desktop/tray/tray_backend.dart';
import 'package:fermata/platform/desktop/tray/tray_menu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart' as tm;

import '../desktop/fakes.dart';
import 'test_bus.dart';

typedef _SetenvC = Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Int32);
typedef _SetenvD = int Function(Pointer<Uint8>, Pointer<Uint8>, int);
typedef _MallocC = Pointer<Uint8> Function(IntPtr);
typedef _MallocD = Pointer<Uint8> Function(int);
typedef _GtkInitCheckC = Int32 Function(Pointer<Void>, Pointer<Void>);
typedef _GtkInitCheckD = int Function(Pointer<Void>, Pointer<Void>);
typedef _IterC = Int32 Function(Pointer<Void>, Int32);
typedef _IterD = int Function(Pointer<Void>, int);

final _libc = DynamicLibrary.process();
final _malloc = _libc.lookupFunction<_MallocC, _MallocD>('malloc');
final _setenv = _libc.lookupFunction<_SetenvC, _SetenvD>('setenv');

Pointer<Uint8> _cstr(String s) {
  final units = s.codeUnits; // ASCII only here
  final p = _malloc(units.length + 1);
  for (var i = 0; i < units.length; i++) {
    p[i] = units[i];
  }
  p[units.length] = 0;
  return p;
}

void _putenv(String k, String v) => _setenv(_cstr(k), _cstr(v), 1);

/// 2x2 RGBA PNG.
const _png = <int>[
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 2, 0, 0, 0, 2, 8, 6, 0, 0, 0, 114, 182, 13, //
  36, 0, 0, 0, 17, 73, 68, 65, 84, 120, 156, 99, 248, 223, 192, 240, 31, 132, 25, 96, 12, 0, 90, 202, 9, 249, 239,
  174, 106, 161, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
];

void main() {
  final hasXvfb = Process.runSync('which', ['Xvfb']).exitCode == 0;
  if (!TestBus.available || !hasXvfb) {
    test('native tray menu', () {}, skip: 'dbus-daemon or Xvfb not installed');
    return;
  }

  late TestBus bus;
  late Process xvfb;
  late Directory tmp;
  Timer? pump;

  setUpAll(() async {
    bus = await TestBus.start();
    final display = ':${4000 + pid % 1000}';
    xvfb = await Process.start('Xvfb', [display, '-nolisten', 'tcp', '-screen', '0', '640x480x24']);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _putenv('DISPLAY', display);
    _putenv('DBUS_SESSION_BUS_ADDRESS', bus.address);
    _putenv('GDK_BACKEND', 'x11');
    final gtk = DynamicLibrary.open('libgtk-3.so.0');
    final ok = gtk.lookupFunction<_GtkInitCheckC, _GtkInitCheckD>('gtk_init_check')(nullptr, nullptr);
    expect(ok, isNonZero, reason: 'GTK could not open the Xvfb display');
    // Dispatch GDBus callbacks (property reads) like the GTK main loop would.
    final glib = DynamicLibrary.open('libglib-2.0.so.0');
    final iterate = glib.lookupFunction<_IterC, _IterD>('g_main_context_iteration');
    pump = Timer.periodic(const Duration(milliseconds: 5), (_) {
      while (iterate(nullptr, 0) != 0) {}
    });
    tmp = await Directory.systemTemp.createTemp('fermata-review-tray-');
  });

  tearDownAll(() async {
    pump?.cancel();
    xvfb.kill();
    await bus.stop();
    await tmp.delete(recursive: true);
  });

  test('the Linux tray icon exposes its context menu to the panel (Menu != /NO_DBUSMENU)', () async {
    final icon = File('${tmp.path}/tray_icon.png')..writeAsBytesSync(_png);
    final backend = NativeTrayBackend();
    final ok = await backend.create(iconPath: icon.path, onActivate: () {}, onMenuItem: (_) {});
    expect(ok, isTrue, reason: 'tray icon could not be created');
    await backend.setMenu(const TrayMenuState(title: 'So What', artist: 'Miles Davis', playing: true)
        .entries(desktopTestStrings()));

    final client = bus.client();
    final names = await client.listNames();
    final sni = names.firstWhere((n) => n.startsWith('org.kde.StatusNotifierItem-$pid-'),
        orElse: () => fail('no StatusNotifierItem on the bus: $names'));
    final item = DBusRemoteObject(client, name: sni, path: DBusObjectPath('/StatusNotifierItem'));
    final menuPath = await item.getProperty('org.kde.StatusNotifierItem', 'Menu').timeout(const Duration(seconds: 5));

    // Panels only show a menu that is exported over com.canonical.dbusmenu;
    // "/NO_DBUSMENU" means "this item has no menu" (Play/Pause, Next,
    // Previous, Show and Quit are unreachable from the tray on Linux).
    expect(menuPath, isNot(DBusObjectPath('/NO_DBUSMENU')));
    expect(menuPath, DBusObjectPath('/StatusNotifierItem/Menu'));

    await backend.destroy();
    await client.close();
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Control: the same native item with the trigger set (what the fix would
  // do on Linux too) exports the menu. Shows the failure above is caused by
  // NativeTrayBackend only calling setContextMenuTrigger on Windows.
  test('control: with setContextMenuTrigger(rightClicked) the menu is exported', () async {
    final iconFile = File('${tmp.path}/tray_icon_ctrl.png')..writeAsBytesSync(_png);
    final image = tm.Image.fromFile(iconFile.path)!;
    final icon = tm.TrayIcon.create()!;
    icon.icon = image;
    final menu = tm.Menu.create()!;
    menu.addItem(tm.MenuItem.createWithLabelAndType('Play', tm.MenuItemType.normal)!);
    icon.setContextMenu(menu);
    icon.setContextMenuTrigger(tm.ContextMenuTrigger.rightClicked);
    icon.setVisible(true);

    final client = bus.client();
    final names = (await client.listNames()).where((n) => n.startsWith('org.kde.StatusNotifierItem-$pid-')).toList()
      ..sort();
    final item = DBusRemoteObject(client, name: names.last, path: DBusObjectPath('/StatusNotifierItem'));
    final menuPath = await item.getProperty('org.kde.StatusNotifierItem', 'Menu').timeout(const Duration(seconds: 5));
    expect(menuPath, DBusObjectPath('/StatusNotifierItem/Menu'));

    icon.setVisible(false);
    icon.dispose();
    await client.close();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
