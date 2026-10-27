import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/platform/android/android_system_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

class FakePermissions implements PermissionGateway {
  final statuses = <Permission, PermissionStatus>{};
  final afterRequest = <Permission, PermissionStatus>{};
  final log = <String>[];
  bool settingsOpened = false;
  bool throwOnStatus = false;

  @override
  Future<PermissionStatus> status(Permission permission) async {
    log.add('status:$permission');
    if (throwOnStatus) throw StateError('no plugin');
    return statuses[permission] ?? PermissionStatus.denied;
  }

  @override
  Future<PermissionStatus> request(Permission permission) async {
    log.add('request:$permission');
    final result = afterRequest[permission] ?? statuses[permission] ?? PermissionStatus.denied;
    statuses[permission] = result;
    return result;
  }

  @override
  Future<bool> openSettings() async {
    log.add('openSettings');
    return settingsOpened = true;
  }
}

void main() {
  const android = PlatformInfo(os: HostOs.android);
  late FakePermissions permissions;

  AndroidSystemHelperImpl helper({int sdk = 34, PlatformInfo platform = android}) =>
      AndroidSystemHelperImpl(platform: platform, permissions: permissions, sdkInt: () async => sdk);

  setUp(() => permissions = FakePermissions());

  group('non-Android', () {
    test('unsupported with safe defaults and no plugin calls', () async {
      for (final os in [HostOs.linux, HostOs.windows]) {
        final h = helper(platform: PlatformInfo(os: os));
        expect(h.isSupported, isFalse);
        expect(await h.notificationsPermitted(), isTrue);
        expect(await h.requestNotificationPermission(), isTrue);
        expect(await h.audioLibraryPermitted(), isTrue);
        expect(await h.requestAudioLibraryPermission(), isTrue);
        expect(await h.isIgnoringBatteryOptimizations(), isTrue);
        await h.requestIgnoreBatteryOptimizations();
        await h.openAppSettings();
      }
      expect(permissions.log, isEmpty);
    });
  });

  group('notifications', () {
    test('Android 13+: requests POST_NOTIFICATIONS when not granted', () async {
      permissions.afterRequest[Permission.notification] = PermissionStatus.granted;
      final h = helper(sdk: 33);
      expect(h.isSupported, isTrue);
      expect(await h.notificationsPermitted(), isFalse);
      expect(await h.requestNotificationPermission(), isTrue);
      expect(permissions.log, contains('request:${Permission.notification}'));
    });

    test('already granted: no prompt', () async {
      permissions.statuses[Permission.notification] = PermissionStatus.granted;
      expect(await helper().requestNotificationPermission(), isTrue);
      expect(permissions.log.where((l) => l.startsWith('request')), isEmpty);
    });

    test('below Android 13 there is no prompt; disabled notifications report false', () async {
      final h = helper(sdk: 31);
      expect(await h.requestNotificationPermission(), isFalse);
      expect(permissions.log.where((l) => l.startsWith('request')), isEmpty);
    });
  });

  group('audio library', () {
    test('Android 13+ uses READ_MEDIA_AUDIO (Permission.audio)', () async {
      permissions.afterRequest[Permission.audio] = PermissionStatus.granted;
      final h = helper(sdk: 34);
      expect(await h.audioLibraryPermitted(), isFalse);
      expect(await h.requestAudioLibraryPermission(), isTrue);
      expect(permissions.log, ['status:${Permission.audio}', 'status:${Permission.audio}', 'request:${Permission.audio}']);
    });

    test('below Android 13 uses READ_EXTERNAL_STORAGE (Permission.storage)', () async {
      permissions.afterRequest[Permission.storage] = PermissionStatus.granted;
      final h = helper(sdk: 30);
      expect(await h.requestAudioLibraryPermission(), isTrue);
      expect(permissions.log.last, 'request:${Permission.storage}');
      expect(permissions.log.any((l) => l.contains('${Permission.audio}')), isFalse);
    });

    test('limited access counts as permitted; permanently denied does not', () async {
      permissions.statuses[Permission.audio] = PermissionStatus.limited;
      expect(await helper().audioLibraryPermitted(), isTrue);
      permissions.statuses[Permission.audio] = PermissionStatus.permanentlyDenied;
      expect(await helper().audioLibraryPermitted(), isFalse);
    });

    test('unknown API level falls back to the Android 13 model', () async {
      final h = AndroidSystemHelperImpl(
        platform: android,
        permissions: permissions,
        sdkInt: () async => throw StateError('device_info unavailable'),
      );
      expect(await h.sdkInt(), androidTiramisu);
      await h.audioLibraryPermitted();
      expect(permissions.log.single, 'status:${Permission.audio}');
    });
  });

  group('battery optimization', () {
    test('status reflects the permission', () async {
      expect(await helper().isIgnoringBatteryOptimizations(), isFalse);
      permissions.statuses[Permission.ignoreBatteryOptimizations] = PermissionStatus.granted;
      expect(await helper().isIgnoringBatteryOptimizations(), isTrue);
    });

    test('request shows the system dialog only when still optimized', () async {
      final h = helper();
      await h.requestIgnoreBatteryOptimizations();
      expect(permissions.log.last, 'request:${Permission.ignoreBatteryOptimizations}');
      permissions.log.clear();
      permissions.statuses[Permission.ignoreBatteryOptimizations] = PermissionStatus.granted;
      await h.requestIgnoreBatteryOptimizations();
      expect(permissions.log, ['status:${Permission.ignoreBatteryOptimizations}']);
    });

    test('nothing is requested implicitly by status queries', () async {
      final h = helper();
      await h.isIgnoringBatteryOptimizations();
      await h.notificationsPermitted();
      await h.audioLibraryPermitted();
      expect(permissions.log.where((l) => l.startsWith('request')), isEmpty);
    });
  });

  test('openAppSettings opens the app settings screen', () async {
    await helper().openAppSettings();
    expect(permissions.settingsOpened, isTrue);
  });

  test('plugin failures are reported as not permitted', () async {
    permissions.throwOnStatus = true;
    expect(await helper().notificationsPermitted(), isFalse);
    expect(await helper().isIgnoringBatteryOptimizations(), isFalse);
  });
}
