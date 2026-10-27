import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../core/contracts/platform.dart';
import '../../core/contracts/playback.dart';
import '../../core/models/track.dart';
import '../../core/platform/app_paths.dart';
import '../../core/platform/platform_info.dart';
import '../../core/sources/source_ids.dart';
import '../../settings/settings_store.dart';
import '../linux/linux_notifier.dart';
import '../linux/mpris_server.dart';
import '../linux/panel_theme_probe.dart';
import '../linux/status_notifier_probe.dart';
import '../windows/smtc_adapter.dart';
import 'desktop_l10n.dart';
import 'hotkeys/global_hotkey_service.dart';
import 'lifecycle_controller.dart';
import 'noop.dart';
import 'single_instance.dart';
import 'startup/startup_manager.dart';
import 'track_change_notifier.dart';
import 'tray/tray_availability.dart';
import 'tray/tray_backend.dart';
import 'tray/tray_controller.dart';
import 'tray/tray_icon_locator.dart';

final _log = Logger('desktop');

/// Everything the desktop integration hands to `AppServices`.
class DesktopIntegration {
  DesktopIntegration._({
    required this.lifecycle,
    required this.startup,
    required this.hotkeys,
    required this.notifier,
    this.mpris,
    this.smtc,
  });

  final AppLifecycleController lifecycle;
  final StartupManager startup;
  final GlobalHotkeyService hotkeys;
  final SystemNotifier notifier;

  /// Linux only, null when the session bus is unavailable.
  final MprisServer? mpris;

  /// Windows only.
  final SmtcAdapter? smtc;

  /// No-op integration for Android and other non-desktop platforms.
  factory DesktopIntegration.noop() => DesktopIntegration._(
        lifecycle: const NoopLifecycleController(),
        startup: const NoopStartupManager(),
        hotkeys: const NoopGlobalHotkeyService(),
        notifier: const NoopSystemNotifier(),
      );

  /// Wires the window/tray lifecycle, MPRIS (Linux) or SMTC (Windows), global
  /// hotkeys, notifications and start-on-login for the current platform and
  /// initializes the window. Call after `WidgetsFlutterBinding
  /// .ensureInitialized()` and after the playback controller exists, before
  /// `runApp`. On non-desktop platforms returns [DesktopIntegration.noop].
  ///
  /// [disposeAll] disposes the remaining services on quit (after playback,
  /// settings, tray, hotkeys, MPRIS/SMTC). [openFile] plays a local file for
  /// "Open with" / MPRIS `OpenUri`; by default a minimal local [Track] is
  /// queued.
  static Future<DesktopIntegration> start({
    required PlatformInfo platform,
    required PlaybackController playback,
    required SettingsStore settings,
    required AppPaths paths,
    required Future<void> Function() disposeAll,
    SingleInstance? singleInstance,
    List<String> args = const [],
    Future<void> Function(String path)? openFile,
  }) async {
    if (!platform.isLinux && !platform.isWindows) return DesktopIntegration.noop();

    final strings = desktopStringsFor(settings);
    final open = openFile ?? (path) => playLocalFile(playback, path);

    // One session-bus connection shared by MPRIS, notifications and the
    // tray probe (connects lazily; failures surface per feature).
    final DBusClient? bus = platform.isLinux ? DBusClient.session() : null;

    // Notifications (Linux).
    SystemNotifier notifier = const NoopSystemNotifier();
    if (bus != null) {
      final linux = LinuxNotifier(client: bus);
      await linux.init();
      notifier = linux;
    }

    // Tray.
    final TrayAvailabilityProbe probe = bus != null
        ? StatusNotifierProbe(client: bus, environment: Platform.environment)
        : const AlwaysAvailableTrayProbe();
    final locator = TrayIconLocator(
      platform: platform,
      prefersDarkPanel: bus == null ? null : () => portalPrefersDark(bus),
    );
    final tray = TrayController(
      backend: NativeTrayBackend(),
      probe: probe,
      settings: settings,
      playback: playback,
      resolveIconPath: locator.resolve,
      strings: strings,
    );

    // Window lifecycle.
    final lifecycle = DesktopLifecycleController(
      playback: playback,
      settings: settings,
      paths: paths,
      platform: platform,
      disposeAll: disposeAll,
      tray: tray,
      args: args,
      instanceCommands: singleInstance?.commands,
      launchCommands: singleInstance?.launchCommands ?? const [],
      openFile: open,
    );

    // Global hotkeys.
    final hotkeys = GlobalHotkeyServiceImpl(
      backend: HotkeyManagerBackend(platform: platform),
      actions: defaultGlobalHotkeyActions(
        playPause: playback.togglePlayPause,
        next: playback.next,
        previous: playback.previous,
        showWindow: lifecycle.showWindow,
      ),
      platform: platform,
      strings: strings,
      environment: Platform.environment,
    );
    lifecycle.addShutdownHook('hotkeys', hotkeys.dispose);

    // MPRIS (Linux).
    MprisServer? mpris;
    if (bus != null) {
      final server = MprisServer(
        playback: playback,
        client: bus,
        onRaise: lifecycle.showWindow,
        onQuit: lifecycle.quit,
        onOpenFile: (path) async {
          await open(path);
        },
      );
      try {
        await server.start();
        mpris = server;
        lifecycle.addShutdownHook('mpris', server.stop);
      } catch (e) {
        _log.warning('MPRIS unavailable (no session bus?): $e');
      }
    }

    // SMTC (Windows).
    SmtcAdapter? smtc;
    if (platform.isWindows) {
      final adapter = SmtcAdapter(playback: playback, platform: platform);
      await adapter.start();
      smtc = adapter;
      lifecycle.addShutdownHook('smtc', adapter.stop);
    }

    // Track-change notifications.
    final trackNotifier = TrackChangeNotifier(
      playback: playback,
      settings: settings,
      notifier: notifier,
      strings: strings,
    )..start();
    lifecycle.addShutdownHook('track notifications', trackNotifier.dispose);

    if (singleInstance != null) lifecycle.addShutdownHook('single instance', singleInstance.close);
    if (bus != null) lifecycle.addShutdownHook('session bus', bus.close);

    await lifecycle.init();
    await hotkeys.bindToSettings(settings);

    return DesktopIntegration._(
      lifecycle: lifecycle,
      startup: StartupManagerImpl(platform: platform),
      hotkeys: hotkeys,
      notifier: notifier,
      mpris: mpris,
      smtc: smtc,
    );
  }

  /// Default "open file" action: queue a minimal user-owned local track and
  /// play it. The library may later enrich it with tags.
  static Future<void> playLocalFile(PlaybackController playback, String path) async {
    final file = File(path);
    if (!await file.exists()) {
      _log.info('Ignoring open request for missing file');
      return;
    }
    final absolute = file.absolute.path;
    final track = Track(
      sourceId: SourceIds.local,
      sourceTrackId: absolute,
      title: p.basenameWithoutExtension(absolute),
      localPath: absolute,
      availability: const TrackAvailability.local(),
    );
    await playback.playTracks([track], origin: 'open-file');
  }
}
