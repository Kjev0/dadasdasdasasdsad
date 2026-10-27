import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Outcome of an explicit "Check for updates" (mirrors the discovery
/// module's `UpdateCheckResult` without importing it — the UI never
/// imports concrete service implementations).
enum UpdateInfoStatus { upToDate, updateAvailable, noReleases }

/// Result shown in Settings → Updates.
@immutable
class UpdateInfo {
  const UpdateInfo({required this.status, required this.currentVersion, this.latestVersion, this.releaseNotesUrl});

  final UpdateInfoStatus status;
  final String currentVersion;
  final String? latestVersion;

  /// Release page (notes + downloads).
  final Uri? releaseNotesUrl;
}

/// Optional platform/service capabilities that are not part of the frozen
/// contracts in `lib/core`. Bootstrap overrides [settingsHooksProvider] with
/// the real implementations; every hook is optional and the UI hides or
/// explains features whose hook is missing.
@immutable
class SettingsHooks {
  const SettingsHooks({
    this.checkForUpdates,
    this.releasesPage,
    this.trayUnavailableReason,
    this.hotkeysUnsupportedReason,
    this.androidRestartRequired,
    this.cancelPendingSignIn,
  });

  /// Explicit update check (e.g. `UpdateChecker.checkNow`). Null hides the
  /// automatic-check toggle and shows manual update instructions instead.
  final Future<UpdateInfo> Function()? checkForUpdates;

  /// Project releases page, shown as "Release notes".
  final Uri? releasesPage;

  /// Localized reason why the tray icon is not shown (null when it is).
  final String? Function()? trayUnavailableReason;

  /// Localized reason why global hotkeys are unavailable.
  final String? Function()? hotkeysUnsupportedReason;

  /// Android: true when a changed setting only applies after a restart.
  final bool Function()? androidRestartRequired;

  /// Cancels a running OAuth sign-in (closes the redirect listener).
  final void Function()? cancelPendingSignIn;
}

/// Overridden at startup; defaults to "no optional hooks".
final settingsHooksProvider = Provider<SettingsHooks>((ref) => const SettingsHooks());

/// A file the user picked.
@immutable
class PickedFile {
  const PickedFile({required this.name, required this.read, this.path});

  final String name;

  /// Absolute path when the platform provides one (desktop; Android may
  /// only give a content URI).
  final String? path;
  final Future<Uint8List> Function() read;
}

/// Native file dialogs used by Settings, Import and Onboarding. Overridable
/// in tests through [fileDialogsProvider].
abstract class FileDialogs {
  Future<String?> pickDirectory({String? title, String? initialDirectory});

  Future<PickedFile?> pickFile({String? title, List<String>? extensions});

  /// Lets the user choose where to save [bytes]; returns a displayable
  /// location, or null when canceled.
  Future<String?> saveFile({required String fileName, required Uint8List bytes, String mimeType, String? title});
}

/// [FileDialogs] backed by `file_picker`.
class PlatformFileDialogs implements FileDialogs {
  const PlatformFileDialogs();

  @override
  Future<String?> pickDirectory({String? title, String? initialDirectory}) =>
      fp.FilePicker.getDirectoryPath(dialogTitle: title, initialDirectory: initialDirectory);

  @override
  Future<PickedFile?> pickFile({String? title, List<String>? extensions}) async {
    final file = await fp.FilePicker.pickFile(
      dialogTitle: title,
      type: extensions == null ? fp.FileType.any : fp.FileType.custom,
      allowedExtensions: extensions,
    );
    if (file == null) return null;
    return PickedFile(name: file.name, path: file.path, read: file.xFile.readAsBytes);
  }

  @override
  Future<String?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? title,
  }) async {
    final uri = await fp.FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeType, dialogTitle: title);
    if (uri == null) return null;
    final location = uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
    // Some desktop backends only return the chosen path; make sure the
    // bytes really are on disk.
    if (uri.scheme == 'file') {
      final f = File(location);
      if (!await f.exists() || await f.length() != bytes.length) await f.writeAsBytes(bytes, flush: true);
    }
    return location;
  }
}

final fileDialogsProvider = Provider<FileDialogs>((ref) => const PlatformFileDialogs());

/// Installed version, e.g. `1.0.0 (1)`.
@immutable
class AppVersion {
  const AppVersion({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  String get display => buildNumber.isEmpty ? version : '$version ($buildNumber)';
}

final appVersionProvider = FutureProvider<AppVersion>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppVersion(version: info.version, buildNumber: info.buildNumber);
});

/// Process environment (desktop session detection for tray/hotkey notes).
final desktopEnvironmentProvider = Provider<Map<String, String>>((ref) => Platform.environment);
