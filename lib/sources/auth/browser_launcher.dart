import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/platform/platform_info.dart';

/// Opens the provider's authorization page. Injected so tests can simulate
/// the provider (a fake launcher calls the redirect URI itself).
typedef BrowserLauncher = Future<void> Function(Uri url);

/// Supplies incoming deep links (`fermata://oauth/<source>` on Android).
typedef DeepLinkStream = Stream<Uri> Function();

/// The real launcher: the system browser on desktop
/// (`LaunchMode.externalApplication`), a Custom Tab on Android
/// (`LaunchMode.inAppBrowserView`). Never an embedded webview.
BrowserLauncher systemBrowserLauncher(PlatformInfo platform) => (Uri url) async {
      final mode = platform.isAndroid ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication;
      var ok = await launchUrl(url, mode: mode);
      if (!ok && mode != LaunchMode.externalApplication) {
        ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (!ok) throw StateError('No browser could open ${url.host}');
    };

/// Incoming app links via `app_links` (registered by the Android manifest's
/// `fermata://oauth` intent filter).
Stream<Uri> appLinksDeepLinks() => AppLinks().uriLinkStream;
