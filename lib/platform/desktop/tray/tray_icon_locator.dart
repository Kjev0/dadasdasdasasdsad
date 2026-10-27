import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../../core/platform/platform_info.dart';

final _log = Logger('desktop.tray');

/// Finds the tray icon inside the installed Flutter asset bundle
/// (`<exe dir>/data/flutter_assets/assets/branding/...`).
///
/// * Linux: `tray_icon.png`, or `tray_icon_mono.png` when [prefersDarkPanel]
///   says the panel is dark and the mono variant exists.
/// * Windows: `tray_icon.ico` (falls back to the PNG, which Windows also
///   accepts with tray_manager 0.8).
///
/// Returns null (and logs a warning) when the files are missing, in which
/// case the tray is skipped.
class TrayIconLocator {
  TrayIconLocator({required this.platform, String? assetsRoot, this.prefersDarkPanel})
      : assetsRoot = assetsRoot ?? defaultAssetsRoot();

  final PlatformInfo platform;
  final String assetsRoot;
  final Future<bool> Function()? prefersDarkPanel;

  static const brandingDir = 'assets/branding';

  static String defaultAssetsRoot() =>
      p.join(p.dirname(Platform.resolvedExecutable), 'data', 'flutter_assets');

  Future<String?> resolve() async {
    final candidates = <String>[];
    if (platform.isWindows) {
      candidates.addAll(['tray_icon.ico', 'tray_icon.png']);
    } else {
      var dark = false;
      final probe = prefersDarkPanel;
      if (probe != null) {
        try {
          dark = await probe();
        } catch (_) {}
      }
      if (dark) candidates.add('tray_icon_mono.png');
      candidates.add('tray_icon.png');
    }
    for (final name in candidates) {
      final path = p.join(assetsRoot, brandingDir, name);
      if (await File(path).exists()) return path;
    }
    _log.warning('Tray icon not found in ${p.join(assetsRoot, brandingDir)} '
        '(tried ${candidates.join(', ')}); the tray is disabled.');
    return null;
  }
}
