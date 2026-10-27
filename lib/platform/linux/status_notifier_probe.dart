import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';

import '../desktop/tray/tray_availability.dart';

final _log = Logger('linux.tray');

/// Linux tray availability: a tray icon (StatusNotifierItem) is only shown
/// when some panel owns `org.kde.StatusNotifierWatcher` on the session bus.
/// KDE Plasma, XFCE, Cinnamon, MATE, Budgie and waybar do; GNOME Shell only
/// with the AppIndicator extension.
class StatusNotifierProbe implements TrayAvailabilityProbe {
  StatusNotifierProbe({required DBusClient client, Map<String, String> environment = const {}})
      : _client = client,
        _env = environment;

  static const watcherName = 'org.kde.StatusNotifierWatcher';

  final DBusClient _client;
  final Map<String, String> _env;
  StreamController<void>? _changes;
  StreamSubscription<DBusNameOwnerChangedEvent>? _ownerSub;

  @override
  Future<TrayHostState> check() async {
    final bool hasOwner;
    try {
      hasOwner = await _client.nameHasOwner(watcherName);
    } catch (e) {
      _log.info('Session bus unavailable, no tray: $e');
      return TrayHostState.noSessionBus;
    }
    if (hasOwner) return TrayHostState.available;
    return isGnome(_env) ? TrayHostState.gnomeWithoutAppIndicator : TrayHostState.noHost;
  }

  /// True for GNOME Shell sessions (incl. Ubuntu's `ubuntu:GNOME`).
  static bool isGnome(Map<String, String> env) {
    final desktops = '${env['XDG_CURRENT_DESKTOP'] ?? ''}:${env['XDG_SESSION_DESKTOP'] ?? ''}'
        .toLowerCase()
        .split(':');
    return desktops.contains('gnome') || desktops.contains('gnome-classic') || desktops.contains('gnome-flashback');
  }

  @override
  Stream<void> get hostChanges {
    final existing = _changes;
    if (existing != null) return existing.stream;
    final controller = StreamController<void>.broadcast();
    _changes = controller;
    try {
      _ownerSub = _client.nameOwnerChanged.where((e) => e.name == watcherName).listen(
            (_) => controller.add(null),
            onError: (Object e) => _log.fine('NameOwnerChanged stream failed: $e'),
          );
    } catch (e) {
      _log.fine('Cannot watch $watcherName: $e');
    }
    return controller.stream;
  }

  @override
  Future<void> dispose() async {
    await _ownerSub?.cancel();
    _ownerSub = null;
    await _changes?.close();
    _changes = null;
  }
}
