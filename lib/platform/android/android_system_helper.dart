import 'package:device_info_plus/device_info_plus.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as ph show openAppSettings;

import '../../core/contracts/platform.dart';
import '../../core/platform/platform_info.dart';

final _log = Logger('platform.android.system');

/// Thin seam over `permission_handler` so the policy in
/// [AndroidSystemHelperImpl] can be unit-tested.
abstract class PermissionGateway {
  Future<PermissionStatus> status(Permission permission);
  Future<PermissionStatus> request(Permission permission);
  Future<bool> openSettings();
}

/// [PermissionGateway] backed by the `permission_handler` plugin.
class PermissionHandlerGateway implements PermissionGateway {
  const PermissionHandlerGateway();

  @override
  Future<PermissionStatus> status(Permission permission) => permission.status;

  @override
  Future<PermissionStatus> request(Permission permission) => permission.request();

  @override
  Future<bool> openSettings() => ph.openAppSettings();
}

/// Reads the Android API level (`Build.VERSION.SDK_INT`).
typedef SdkIntReader = Future<int> Function();

Future<int> _deviceSdkInt() async => (await DeviceInfoPlugin().androidInfo).version.sdkInt;

/// Android API level 33 (Android 13): runtime notification permission and
/// granular `READ_MEDIA_AUDIO`.
const androidTiramisu = 33;

/// Android permissions and battery-optimization status for
/// Settings → Background playback and onboarding.
///
/// * Notifications: `POST_NOTIFICATIONS` is a runtime permission from
///   Android 13. Below that it cannot be requested; the status reflects
///   whether the user disabled notifications for the app.
///   The media-playback notification is exempt on Android 13+, so playback
///   controls work even when this is denied.
/// * Audio library: `READ_MEDIA_AUDIO` (`Permission.audio`) on 13+,
///   `READ_EXTERNAL_STORAGE` (`Permission.storage`) below.
/// * Battery optimization: only requested after an explicit user opt-in.
///
/// On other platforms [isSupported] is false and every query reports "no
/// restriction" (true) so platform-neutral UI never nags desktop users.
/// Platform failures are logged and reported as "not permitted" (false).
class AndroidSystemHelperImpl implements AndroidSystemHelper {
  AndroidSystemHelperImpl({
    PlatformInfo? platform,
    PermissionGateway? permissions,
    SdkIntReader? sdkInt,
  })  : _platform = platform ?? PlatformInfo.current(),
        _permissions = permissions ?? const PermissionHandlerGateway(),
        _readSdkInt = sdkInt ?? _deviceSdkInt;

  final PlatformInfo _platform;
  final PermissionGateway _permissions;
  final SdkIntReader _readSdkInt;
  Future<int>? _sdkInt;

  @override
  bool get isSupported => _platform.isAndroid;

  /// Android API level, read once. Falls back to 33 when unknown (modern
  /// permission model; requesting the legacy storage permission on 13+
  /// would always be denied).
  Future<int> sdkInt() => _sdkInt ??= _readSdkInt().catchError((Object e, StackTrace st) {
        _log.warning('Could not read the Android API level', e, st);
        return androidTiramisu;
      });

  Future<Permission> _audioPermission() async =>
      await sdkInt() >= androidTiramisu ? Permission.audio : Permission.storage;

  Future<bool> _granted(Permission permission, {required bool request}) async {
    try {
      final status = request ? await _permissions.request(permission) : await _permissions.status(permission);
      return status.isGranted || status.isLimited;
    } catch (e, st) {
      _log.warning('Permission ${request ? 'request' : 'check'} for $permission failed', e, st);
      return false;
    }
  }

  @override
  Future<bool> notificationsPermitted() async {
    if (!isSupported) return true;
    return _granted(Permission.notification, request: false);
  }

  /// Shows the system prompt on Android 13+. Below Android 13 there is no
  /// prompt; when notifications were turned off the user must re-enable
  /// them in the app settings ([openAppSettings]), and this returns false.
  @override
  Future<bool> requestNotificationPermission() async {
    if (!isSupported) return true;
    if (await notificationsPermitted()) return true;
    if (await sdkInt() < androidTiramisu) return false;
    return _granted(Permission.notification, request: true);
  }

  @override
  Future<bool> audioLibraryPermitted() async {
    if (!isSupported) return true;
    return _granted(await _audioPermission(), request: false);
  }

  @override
  Future<bool> requestAudioLibraryPermission() async {
    if (!isSupported) return true;
    final permission = await _audioPermission();
    if (await _granted(permission, request: false)) return true;
    return _granted(permission, request: true);
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!isSupported) return true;
    return _granted(Permission.ignoreBatteryOptimizations, request: false);
  }

  /// Opens Android's "Allow app to always run in background?" dialog. Only
  /// call this after the user explicitly opted in from Settings.
  @override
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!isSupported) return;
    if (await isIgnoringBatteryOptimizations()) return;
    await _granted(Permission.ignoreBatteryOptimizations, request: true);
  }

  @override
  Future<void> openAppSettings() async {
    if (!isSupported) return;
    try {
      final opened = await _permissions.openSettings();
      if (!opened) _log.warning('The app settings screen could not be opened');
    } catch (e, st) {
      _log.warning('Opening app settings failed', e, st);
    }
  }
}
