import 'package:logging/logging.dart';

import '../../../core/contracts/platform.dart';
import '../../../core/errors.dart';
import '../../../core/platform/platform_info.dart';
import '../../linux/linux_autostart.dart';
import '../../windows/windows_run_key.dart';
import 'autostart_backend.dart';

final _log = Logger('desktop.startup');

/// [StartupManager] for Linux (XDG autostart) and Windows (HKCU Run key).
/// Unsupported elsewhere.
class StartupManagerImpl implements StartupManager {
  StartupManagerImpl({required PlatformInfo platform, AutostartBackend? backend})
      : _backend = backend ?? _defaultBackend(platform);

  final AutostartBackend? _backend;

  static AutostartBackend? _defaultBackend(PlatformInfo platform) {
    if (platform.isLinux) return LinuxAutostart();
    if (platform.isWindows) return WindowsRunKeyAutostart();
    return null;
  }

  @override
  bool get isSupported => _backend != null;

  @override
  Future<bool> isEnabled() async {
    final backend = _backend;
    if (backend == null) return false;
    try {
      return await backend.isEnabled();
    } catch (e) {
      _log.warning('Could not read start-on-login state: $e');
      return false;
    }
  }

  /// Throws [StorageException] (`startup_failed`) when the entry cannot be
  /// written, so Settings can revert the switch and explain.
  @override
  Future<void> setEnabled(bool enabled, {bool startMinimized = false}) async {
    final backend = _backend;
    if (backend == null) return;
    try {
      if (enabled) {
        await backend.enable(startMinimized: startMinimized);
      } else {
        await backend.disable();
      }
    } catch (e) {
      _log.warning('Changing start-on-login failed: $e');
      throw StorageException('startup_failed', 'Could not ${enabled ? 'enable' : 'disable'} start on login', cause: e);
    }
  }
}
