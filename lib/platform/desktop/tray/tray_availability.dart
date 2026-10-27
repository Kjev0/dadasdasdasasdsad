import 'dart:async';

/// Whether the desktop can host a tray icon right now.
enum TrayHostState {
  available,

  /// GNOME Shell without the AppIndicator/KStatusNotifierItem extension.
  gnomeWithoutAppIndicator,

  /// No `org.kde.StatusNotifierWatcher` on the session bus.
  noHost,

  /// The session bus itself is unreachable.
  noSessionBus,

  /// The platform has no tray concept (Android, unknown OS).
  unsupported,
}

/// Detects whether a tray icon would be visible. Linux checks the session
/// bus for a StatusNotifier host; Windows always has a notification area.
abstract class TrayAvailabilityProbe {
  Future<TrayHostState> check();

  /// Fires when the host may have appeared or disappeared (e.g. the user
  /// enabled the GNOME extension or the panel restarted), so the tray can
  /// re-register.
  Stream<void> get hostChanges;

  Future<void> dispose();
}

/// Windows: the notification area always exists.
class AlwaysAvailableTrayProbe implements TrayAvailabilityProbe {
  const AlwaysAvailableTrayProbe();

  @override
  Future<TrayHostState> check() async => TrayHostState.available;

  @override
  Stream<void> get hostChanges => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

/// Platforms without a tray.
class UnsupportedTrayProbe implements TrayAvailabilityProbe {
  const UnsupportedTrayProbe();

  @override
  Future<TrayHostState> check() async => TrayHostState.unsupported;

  @override
  Stream<void> get hostChanges => const Stream.empty();

  @override
  Future<void> dispose() async {}
}
