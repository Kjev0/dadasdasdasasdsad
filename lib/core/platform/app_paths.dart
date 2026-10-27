import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolved application directories. Created once at bootstrap.
///
/// * Windows: %APPDATA%\app.fermata\Fermata (support), %LOCALAPPDATA% caches
/// * Linux:   ~/.local/share/app.fermata.player (support), ~/.cache/...
/// * Android: app-private internal storage; downloads in the app-specific
///            external Music directory (no storage permission needed).
class AppPaths {
  AppPaths({
    required this.supportDir,
    required this.cacheDir,
    required this.defaultDownloadDir,
    required this.logsDir,
  });

  final Directory supportDir;
  final Directory cacheDir;
  final Directory defaultDownloadDir;
  final Directory logsDir;

  File get settingsFile => File(p.join(supportDir.path, 'settings.json'));
  File get databaseFile => File(p.join(supportDir.path, 'fermata.db'));
  File get queueStateFile => File(p.join(supportDir.path, 'queue_state.json'));
  File get windowStateFile => File(p.join(supportDir.path, 'window_state.json'));
  File get credentialsFile => File(p.join(supportDir.path, 'credentials.json'));
  File get instanceLockFile => File(p.join(supportDir.path, 'instance.lock'));
  Directory get artworkCacheDir => Directory(p.join(cacheDir.path, 'artwork'));
  Directory get tempDownloadDir => Directory(p.join(cacheDir.path, 'downloads-partial'));

  static Future<AppPaths> resolve() async {
    final support = await getApplicationSupportDirectory();
    final cache = await _cacheDir();
    final downloads = await _defaultDownloads(support);
    final logs = Directory(p.join(support.path, 'logs'));
    final paths = AppPaths(supportDir: support, cacheDir: cache, defaultDownloadDir: downloads, logsDir: logs);
    for (final d in [support, cache, logs, paths.artworkCacheDir, paths.tempDownloadDir]) {
      await d.create(recursive: true);
    }
    return paths;
  }

  /// Paths rooted in a temp dir — for tests.
  factory AppPaths.forTesting(Directory root) => AppPaths(
        supportDir: Directory(p.join(root.path, 'support'))..createSync(recursive: true),
        cacheDir: Directory(p.join(root.path, 'cache'))..createSync(recursive: true),
        defaultDownloadDir: Directory(p.join(root.path, 'downloads'))..createSync(recursive: true),
        logsDir: Directory(p.join(root.path, 'logs'))..createSync(recursive: true),
      );

  static Future<Directory> _cacheDir() async {
    if (Platform.isLinux) {
      final xdg = Platform.environment['XDG_CACHE_HOME'];
      final home = Platform.environment['HOME'];
      final base = (xdg != null && xdg.isNotEmpty) ? xdg : p.join(home ?? '/tmp', '.cache');
      return Directory(p.join(base, 'app.fermata.player'));
    }
    return getApplicationCacheDirectory();
  }

  static Future<Directory> _defaultDownloads(Directory support) async {
    if (Platform.isAndroid) {
      // App-specific external storage: visible to the user's file manager,
      // removed on uninstall, no permission required.
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.music);
      if (dirs != null && dirs.isNotEmpty) return Directory(p.join(dirs.first.path, 'Fermata'));
      return Directory(p.join(support.path, 'downloads'));
    }
    if (Platform.isLinux) {
      final music = _xdgUserDir('MUSIC');
      if (music != null) return Directory(p.join(music, 'Fermata'));
    }
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'];
      if (profile != null) return Directory(p.join(profile, 'Music', 'Fermata'));
    }
    final dl = await getDownloadsDirectory();
    return Directory(p.join((dl ?? support).path, 'Fermata'));
  }

  /// Reads ~/.config/user-dirs.dirs (XDG user dirs) without spawning a process.
  static String? _xdgUserDir(String key) {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    final file = File(p.join(Platform.environment['XDG_CONFIG_HOME'] ?? p.join(home, '.config'), 'user-dirs.dirs'));
    try {
      if (file.existsSync()) {
        for (final line in file.readAsLinesSync()) {
          final m = RegExp('^XDG_${key}_DIR="(.*)"\$').firstMatch(line.trim());
          if (m != null) return m.group(1)!.replaceAll(r'$HOME', home);
        }
      }
    } on FileSystemException {
      // fall through
    }
    final fallback = Directory(p.join(home, 'Music'));
    return fallback.path;
  }
}
