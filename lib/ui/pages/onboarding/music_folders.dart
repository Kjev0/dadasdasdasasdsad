import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../app/providers.dart';
import '../../../core/platform/platform_info.dart';
import '../settings/settings_hooks.dart';

/// The user's standard music folder, if it exists: `XDG_MUSIC_DIR` (or
/// `~/Music`) on Linux, `%USERPROFILE%\Music` on Windows. Android has no
/// suggestion (the user picks a folder after granting access).
String? suggestedMusicFolder(PlatformInfo platform, Map<String, String> env, {bool Function(String path)? exists}) {
  final dirExists = exists ?? (path) => Directory(path).existsSync();
  String? candidate;
  if (platform.isLinux) {
    final home = env['HOME'];
    if (home == null) return null;
    candidate = _xdgMusicDir(home, env) ?? p.join(home, 'Music');
  } else if (platform.isWindows) {
    final profile = env['USERPROFILE'];
    if (profile != null) candidate = p.join(profile, 'Music');
  }
  if (candidate == null || !dirExists(candidate)) return null;
  return candidate;
}

String? _xdgMusicDir(String home, Map<String, String> env) {
  final config = env['XDG_CONFIG_HOME'];
  final file = File(p.join(config == null || config.isEmpty ? p.join(home, '.config') : config, 'user-dirs.dirs'));
  try {
    if (!file.existsSync()) return null;
    for (final line in file.readAsLinesSync()) {
      final m = RegExp(r'^XDG_MUSIC_DIR="(.*)"$').firstMatch(line.trim());
      if (m != null) {
        final value = m.group(1)!.replaceAll(r'$HOME', home);
        // "$HOME/" alone means the desktop has no music folder configured.
        return value == home || value == '$home/' ? null : value;
      }
    }
  } on FileSystemException {
    return null;
  }
  return null;
}

/// Suggested music folder for onboarding (overridable in tests).
final suggestedMusicFolderProvider = Provider<String?>((ref) {
  return suggestedMusicFolder(ref.watch(platformInfoProvider), ref.watch(desktopEnvironmentProvider));
});
