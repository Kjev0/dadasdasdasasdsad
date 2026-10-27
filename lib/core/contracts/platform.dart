/// What to do when the user closes the main window on desktop.
enum CloseBehavior { minimizeToTray, ask, exit }

enum CloseChoice { minimizeToTray, quit, cancel }

/// Desktop window + app lifecycle. On Android this is a no-op facade.
abstract class AppLifecycleController {
  Future<void> init();

  /// True when a system tray / StatusNotifier host is available.
  bool get trayAvailable;

  Future<void> showWindow();

  /// Hide to tray (or minimize when no tray is available — never leave the
  /// app unreachable).
  Future<void> hideWindow();

  /// Fully quit: stop playback, persist state, dispose services, exit.
  Future<void> quit();

  /// Registered by the UI to show the "Close Fermata?" dialog when
  /// [CloseBehavior.ask] is configured. Returns the user's choice and whether
  /// to remember it.
  set closeDecisionDelegate(Future<(CloseChoice, bool remember)> Function()? delegate);
}

/// Optional start-on-login (Windows HKCU Run key, Linux XDG autostart).
abstract class StartupManager {
  bool get isSupported;
  Future<bool> isEnabled();
  Future<void> setEnabled(bool enabled, {bool startMinimized = false});
}

/// System-wide hotkeys (desktop). Bindings come from settings.
abstract class GlobalHotkeyService {
  bool get isSupported;
  Future<void> apply(Map<String, String> bindings, {required bool enabled});

  /// Human-readable error for bindings that could not be registered
  /// (e.g. already taken by another app).
  Map<String, String> get registrationErrors;
}

/// Android-only helpers surfaced in Settings → Background playback.
abstract class AndroidSystemHelper {
  bool get isSupported;
  Future<bool> isIgnoringBatteryOptimizations();

  /// Opens the system dialog; only called after the user opts in.
  Future<void> requestIgnoreBatteryOptimizations();
  Future<bool> notificationsPermitted();
  Future<bool> requestNotificationPermission();
  Future<bool> audioLibraryPermitted();
  Future<bool> requestAudioLibraryPermission();
  Future<void> openAppSettings();
}
