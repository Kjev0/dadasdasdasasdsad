import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a URL in the system browser / provider app.
typedef ExternalLinkLauncher = Future<bool> Function(Uri uri);

/// Overridable in tests (url_launcher has no test implementation).
final externalLinkLauncherProvider = Provider<ExternalLinkLauncher>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
