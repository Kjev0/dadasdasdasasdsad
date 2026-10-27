import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../desktop/startup/autostart_backend.dart';

final _log = Logger('linux.autostart');

/// Start-on-login on Linux through the XDG Autostart specification:
/// `$XDG_CONFIG_HOME/autostart/app.fermata.player.desktop` (default
/// `~/.config/autostart`). Honoured by GNOME, KDE Plasma, XFCE, Cinnamon,
/// MATE, LXQt and systemd's xdg-autostart-generator.
class LinuxAutostart implements AutostartBackend {
  LinuxAutostart({
    Map<String, String>? environment,
    String? executable,
    this.launcherName = 'fermata',
  })  : _env = environment ?? Platform.environment,
        _executable = executable ?? Platform.resolvedExecutable;

  static const desktopFileName = 'app.fermata.player.desktop';

  final Map<String, String> _env;
  final String _executable;

  /// Name of the launcher symlink/wrapper put on PATH by the installer.
  final String launcherName;

  /// `$XDG_CONFIG_HOME/autostart/app.fermata.player.desktop`.
  File get file {
    final xdg = _env['XDG_CONFIG_HOME'];
    final base = (xdg != null && xdg.isNotEmpty && p.isAbsolute(xdg))
        ? xdg
        : p.join(_env['HOME'] ?? Directory.systemTemp.path, '.config');
    return File(p.join(base, 'autostart', desktopFileName));
  }

  @override
  Future<bool> isEnabled() async {
    final f = file;
    if (!await f.exists()) return false;
    try {
      final entries = parseDesktopEntry(await f.readAsString());
      if (entries['Hidden']?.toLowerCase() == 'true') return false;
      if (entries['X-GNOME-Autostart-enabled']?.toLowerCase() == 'false') return false;
      return entries.containsKey('Exec');
    } catch (e) {
      _log.warning('Unreadable autostart entry ${f.path}: $e');
      return false;
    }
  }

  @override
  Future<void> enable({required bool startMinimized}) async {
    final f = file;
    await f.parent.create(recursive: true);
    final exec = [quoteExecArg(launcherPath()), if (startMinimized) '--minimized'].join(' ');
    final content = '''[Desktop Entry]
Type=Application
Name=Fermata
Comment=Music player
Exec=$exec
Icon=app.fermata.player
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
''';
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(f.path);
    _log.info('Autostart enabled: ${f.path} (Exec=$exec)');
  }

  @override
  Future<void> disable() async {
    final f = file;
    if (await f.exists()) {
      await f.delete();
      _log.info('Autostart disabled: removed ${f.path}');
    }
  }

  /// The command autostart should run. When the running binary lives in an
  /// installed bundle (not a build directory) and a `fermata` launcher on
  /// PATH (symlink or wrapper script) points at it, the launcher is used so
  /// the entry survives updates that move the bundle; otherwise the binary
  /// itself.
  String launcherPath() {
    final exe = _resolve(_executable);
    if (!_looksInstalled(exe)) return exe;
    final dirs = <String>[
      ...?_env['PATH']?.split(':').where((d) => d.isNotEmpty && p.isAbsolute(d)),
      if (_env['HOME'] != null) p.join(_env['HOME']!, '.local', 'bin'),
      '/usr/local/bin',
      '/usr/bin',
    ];
    for (final dir in dirs.toSet()) {
      final candidate = p.join(dir, launcherName);
      try {
        final type = FileSystemEntity.typeSync(candidate, followLinks: false);
        if (type == FileSystemEntityType.notFound) continue;
        if (type == FileSystemEntityType.link && _resolve(candidate) == exe) return candidate;
        if (type == FileSystemEntityType.file) {
          final f = File(candidate);
          // Small wrapper scripts that exec the bundle.
          if (f.lengthSync() < 16 * 1024 && f.readAsStringSync().contains(p.dirname(exe))) return candidate;
        }
      } catch (_) {
        // Unreadable candidate: keep looking.
      }
    }
    return exe;
  }

  static String _resolve(String path) {
    try {
      return File(path).resolveSymbolicLinksSync();
    } catch (_) {
      return path;
    }
  }

  /// Build output (`build/linux/x64/...`) and `flutter run` are not installs.
  static bool _looksInstalled(String exe) {
    final parts = p.split(exe);
    final buildIdx = parts.indexOf('build');
    final isBuildDir = buildIdx >= 0 && parts.length > buildIdx + 1 && parts[buildIdx + 1] == 'linux';
    return !isBuildDir;
  }

  /// Quotes one argument for a desktop entry `Exec` key (Desktop Entry
  /// Specification, "The Exec key").
  static String quoteExecArg(String arg) {
    const reserved = ' \t\n"\'\\><~|&;\$*?#()`';
    final needsQuotes = arg.isEmpty || arg.split('').any(reserved.contains);
    if (!needsQuotes) return arg.replaceAll('%', '%%');
    final escaped = arg
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('`', r'\`')
        .replaceAll(r'$', r'\$')
        .replaceAll('%', '%%');
    return '"$escaped"';
  }

  /// Parses the `[Desktop Entry]` group into key/value pairs.
  static Map<String, String> parseDesktopEntry(String content) {
    final result = <String, String>{};
    var inGroup = false;
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('[')) {
        inGroup = line == '[Desktop Entry]';
        continue;
      }
      if (!inGroup) continue;
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      result[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
    }
    return result;
  }
}
