import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../../core/contracts/platform.dart';

final _log = Logger('linux.notify');

/// Desktop notifications through `org.freedesktop.Notifications.Notify`
/// (GNOME Shell, KDE Plasma, XFCE, Cinnamon, mako, dunst, ...).
///
/// Notifications shown with the same [show] `id` replace each other (e.g.
/// one "now playing" bubble instead of a pile). [isSupported] is false when
/// no notification server is running or activatable on the session bus.
class LinuxNotifier implements SystemNotifier {
  LinuxNotifier({
    required this._client,
    this.appName = 'Fermata',
    this.appIcon = 'app.fermata.player',
    this.desktopEntry = 'app.fermata.player',
  });

  static const serviceName = 'org.freedesktop.Notifications';
  static const objectPath = '/org/freedesktop/Notifications';

  final DBusClient _client;
  final String appName;

  /// Icon theme name installed with the app (hicolor).
  final String appIcon;
  final String desktopEntry;

  bool _supported = false;
  bool _bodyMarkup = false;
  final _serverIds = <String, int>{};

  @override
  bool get isSupported => _supported;

  /// Detects the notification server and its capabilities.
  Future<void> init() async {
    try {
      final running = await _client.nameHasOwner(serviceName);
      final activatable = running || (await _client.listActivatableNames()).contains(serviceName);
      _supported = activatable;
      if (_supported) {
        try {
          final caps = await _remote
              .callMethod(serviceName, 'GetCapabilities', const [], replySignature: DBusSignature('as'))
              .timeout(const Duration(seconds: 3));
          _bodyMarkup = caps.values.first.asStringArray().contains('body-markup');
        } catch (e) {
          _log.fine('GetCapabilities failed: $e');
        }
      }
    } catch (e) {
      _log.info('Notifications unavailable (no session bus): $e');
      _supported = false;
    }
    _log.fine('Notifications supported: $_supported');
  }

  DBusRemoteObject get _remote => DBusRemoteObject(_client, name: serviceName, path: DBusObjectPath(objectPath));

  @override
  Future<void> show({required String id, required String title, String? body, String? iconPath}) =>
      notify(id: id, title: title, body: body, iconPath: iconPath);

  /// [show] with extras: [transient] keeps it out of the notification
  /// history, [urgency] 0 = low, 1 = normal, 2 = critical.
  Future<void> notify({
    required String id,
    required String title,
    String? body,
    String? iconPath,
    bool transient = false,
    int urgency = 1,
    Duration? timeout,
  }) async {
    if (!_supported) return;
    final text = body ?? '';
    final hints = <String, DBusValue>{
      'desktop-entry': DBusString(desktopEntry),
      'urgency': DBusByte(urgency.clamp(0, 2)),
      if (transient) 'transient': const DBusBoolean(true),
      if (iconPath != null && iconPath.isNotEmpty && !iconPath.contains('://')) 'image-path': DBusString(iconPath),
    };
    try {
      final reply = await _remote.callMethod(
        serviceName,
        'Notify',
        [
          DBusString(appName),
          DBusUint32(_serverIds[id] ?? 0),
          DBusString(_iconArg(iconPath)),
          DBusString(title),
          DBusString(_bodyMarkup ? escapeMarkup(text) : text),
          DBusArray.string(const []),
          DBusDict.stringVariant(hints),
          DBusInt32(timeout?.inMilliseconds ?? -1),
        ],
        replySignature: DBusSignature('u'),
      ).timeout(const Duration(seconds: 5));
      _serverIds[id] = reply.values.first.asUint32();
    } catch (e) {
      _log.warning('Notification "$id" failed: $e');
    }
  }

  String _iconArg(String? iconPath) {
    if (iconPath == null || iconPath.isEmpty) return appIcon;
    if (iconPath.contains('://')) return iconPath;
    return Uri.file(iconPath).toString();
  }

  /// Escapes the subset of markup notification servers interpret.
  static String escapeMarkup(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
