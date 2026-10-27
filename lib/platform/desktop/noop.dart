import '../../core/contracts/platform.dart';

/// Lifecycle facade for platforms without a desktop window (Android, tests).
/// Android keeps the engine alive through its foreground media service, so
/// there is nothing to hide or quit here.
class NoopLifecycleController implements AppLifecycleController {
  const NoopLifecycleController();

  @override
  Future<void> init() async {}

  @override
  bool get trayAvailable => false;

  @override
  Future<void> showWindow() async {}

  @override
  Future<void> hideWindow() async {}

  @override
  Future<void> quit() async {}

  @override
  set closeDecisionDelegate(Future<(CloseChoice, bool remember)> Function()? delegate) {}
}

/// Start-on-login is not available (Android, unsupported desktops).
class NoopStartupManager implements StartupManager {
  const NoopStartupManager();

  @override
  bool get isSupported => false;

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<void> setEnabled(bool enabled, {bool startMinimized = false}) async {}
}

/// Global hotkeys are not available (Android, Wayland-only sessions).
class NoopGlobalHotkeyService implements GlobalHotkeyService {
  const NoopGlobalHotkeyService();

  @override
  bool get isSupported => false;

  @override
  Future<void> apply(Map<String, String> bindings, {required bool enabled}) async {}

  @override
  Map<String, String> get registrationErrors => const {};
}

/// No system notifications; the UI falls back to in-app messages.
class NoopSystemNotifier implements SystemNotifier {
  const NoopSystemNotifier();

  @override
  bool get isSupported => false;

  @override
  Future<void> show({required String id, required String title, String? body, String? iconPath}) async {}
}
