import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

final _log = Logger('linux.tray');

/// Asks the XDG desktop portal for the system colour scheme
/// (`org.freedesktop.appearance` / `color-scheme`: 0 = no preference,
/// 1 = prefer dark, 2 = prefer light). Panels follow it on KDE Plasma and
/// GNOME, so "prefer dark" is the best available hint for a dark panel.
/// Returns false when the portal is missing or does not know.
Future<bool> portalPrefersDark(DBusClient client, {Duration timeout = const Duration(seconds: 2)}) async {
  final portal = DBusRemoteObject(
    client,
    name: 'org.freedesktop.portal.Desktop',
    path: DBusObjectPath('/org/freedesktop/portal/desktop'),
  );
  const iface = 'org.freedesktop.portal.Settings';
  final args = [const DBusString('org.freedesktop.appearance'), const DBusString('color-scheme')];
  try {
    DBusValue value;
    try {
      final r = await portal.callMethod(iface, 'ReadOne', args).timeout(timeout);
      value = r.values.first;
    } on DBusMethodResponseException {
      // Portal versions < 2 only implement the deprecated Read (v of v).
      final r = await portal.callMethod(iface, 'Read', args).timeout(timeout);
      value = r.values.first;
    }
    while (value is DBusVariant) {
      value = value.value;
    }
    return value is DBusUint32 && value.value == 1;
  } catch (e) {
    _log.fine('Colour scheme unknown: $e');
    return false;
  }
}
