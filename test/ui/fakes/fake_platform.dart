import 'dart:ui';

import 'package:fermata/core/contracts/platform.dart';
import 'package:fermata/ui/player/mini_mode.dart';

class FakeAppLifecycleController implements AppLifecycleController {
  final calls = <String>[];
  Future<(CloseChoice, bool remember)> Function()? delegate;

  @override
  bool trayAvailable = true;

  @override
  Future<void> init() async => calls.add('init');

  @override
  Future<void> showWindow() async => calls.add('showWindow');

  @override
  Future<void> hideWindow() async => calls.add('hideWindow');

  @override
  Future<void> quit() async => calls.add('quit');

  @override
  set closeDecisionDelegate(Future<(CloseChoice, bool remember)> Function()? delegate) => this.delegate = delegate;
}

class FakeStartupManager implements StartupManager {
  bool enabled = false;
  bool startMinimized = false;

  @override
  bool isSupported = true;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool enabled, {bool startMinimized = false}) async {
    this.enabled = enabled;
    this.startMinimized = startMinimized;
  }
}

class FakeGlobalHotkeyService implements GlobalHotkeyService {
  Map<String, String> applied = const {};
  bool appliedEnabled = false;

  @override
  bool isSupported = true;

  @override
  Map<String, String> registrationErrors = {};

  @override
  Future<void> apply(Map<String, String> bindings, {required bool enabled}) async {
    applied = bindings;
    appliedEnabled = enabled;
  }
}

class FakeAndroidSystemHelper implements AndroidSystemHelper {
  bool ignoringBatteryOptimizations = false;
  bool notifications = true;
  bool audioLibrary = true;
  final calls = <String>[];

  @override
  bool isSupported = false;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => ignoringBatteryOptimizations;

  @override
  Future<void> requestIgnoreBatteryOptimizations() async {
    calls.add('requestIgnoreBatteryOptimizations');
    ignoringBatteryOptimizations = true;
  }

  @override
  Future<bool> notificationsPermitted() async => notifications;

  @override
  Future<bool> requestNotificationPermission() async {
    calls.add('requestNotificationPermission');
    return notifications = true;
  }

  @override
  Future<bool> audioLibraryPermitted() async => audioLibrary;

  @override
  Future<bool> requestAudioLibraryPermission() async {
    calls.add('requestAudioLibraryPermission');
    return audioLibrary = true;
  }

  @override
  Future<void> openAppSettings() async => calls.add('openAppSettings');
}

class FakeSystemNotifier implements SystemNotifier {
  final shown = <(String id, String title, String? body)>[];

  @override
  bool isSupported = true;

  @override
  Future<void> show({required String id, required String title, String? body, String? iconPath}) async =>
      shown.add((id, title, body));
}

/// Records mini-mode window changes instead of resizing a real window.
class FakeMiniWindow implements MiniWindowController {
  final changes = <(bool enabled, bool alwaysOnTop)>[];

  @override
  Future<void> setMiniMode(bool enabled, {Size size = miniWindowSize, bool alwaysOnTop = true}) async =>
      changes.add((enabled, alwaysOnTop));
}
