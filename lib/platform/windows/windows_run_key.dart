import 'dart:io';

import 'package:logging/logging.dart';
import 'package:win32_registry/win32_registry.dart';

import '../desktop/startup/autostart_backend.dart';

final _log = Logger('windows.autostart');

/// Start-on-login on Windows: the per-user Run key
/// `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, value `Fermata` =
/// `"<exe>" [--minimized]`. No admin rights needed.
///
/// Windows' "Startup apps" page (and Task Manager) can switch the entry off
/// without deleting it, by writing a marker under
/// `...\Explorer\StartupApproved\Run`; [isEnabled] honours that marker and
/// [enable] clears it.
///
/// Only touch on Windows: the registry API is FFI into advapi32.
class WindowsRunKeyAutostart implements AutostartBackend {
  WindowsRunKeyAutostart({String? executable}) : _executable = executable ?? Platform.resolvedExecutable;

  static const runKeyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const approvedKeyPath = r'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';
  static const valueName = 'Fermata';

  final String _executable;

  /// The registry value data for [executable].
  static String commandLine(String executable, {required bool startMinimized}) =>
      '"$executable"${startMinimized ? ' --minimized' : ''}';

  /// StartupApproved data: first byte even (0x02/0x06) = enabled, odd
  /// (0x03/0x07) = switched off by the user.
  static bool approvedDataDisablesEntry(List<int>? data) => data != null && data.isNotEmpty && data.first.isOdd;

  @override
  Future<bool> isEnabled() async {
    _ensureWindows();
    final value = _read(runKeyPath, (key) => key.getString(valueName));
    if (value == null || value.isEmpty) return false;
    final approved = _read(approvedKeyPath, (key) {
      final v = key.getValue(valueName);
      return v is BinaryValue ? v.value.toList() : null;
    });
    return !approvedDataDisablesEntry(approved);
  }

  @override
  Future<void> enable({required bool startMinimized}) async {
    _ensureWindows();
    final key = CURRENT_USER.create(runKeyPath);
    try {
      key.setValue(valueName, StringValue(commandLine(_executable, startMinimized: startMinimized)));
    } finally {
      key.close();
    }
    _removeValue(approvedKeyPath); // re-enable if the user had switched it off
    _log.info('Autostart enabled (HKCU Run\\$valueName)');
  }

  @override
  Future<void> disable() async {
    _ensureWindows();
    if (_removeValue(runKeyPath)) _log.info('Autostart disabled (removed HKCU Run\\$valueName)');
    _removeValue(approvedKeyPath);
  }

  static T? _read<T>(String path, T? Function(RegistryKey key) read) {
    RegistryKey? key;
    try {
      key = CURRENT_USER.open(path);
      return read(key);
    } catch (e) {
      _log.fine('Registry key $path not readable: $e');
      return null;
    } finally {
      key?.close();
    }
  }

  /// Removes [valueName] under [path]; false when it did not exist.
  static bool _removeValue(String path) {
    RegistryKey? key;
    try {
      key = CURRENT_USER.open(path, config: const RegistryOpenConfig(access: RegistryAccess.readWrite));
      if (key.getValue(valueName) == null) return false;
      key.removeValue(valueName);
      return true;
    } catch (e) {
      _log.fine('Registry value $path\\$valueName not removed: $e');
      return false;
    } finally {
      key?.close();
    }
  }

  static void _ensureWindows() {
    if (!Platform.isWindows) throw UnsupportedError('The Windows registry is only available on Windows');
  }
}
