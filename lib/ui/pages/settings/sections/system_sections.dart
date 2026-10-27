import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/contracts/platform.dart';
import '../../../../settings/app_settings.dart';
import '../../../actions/link_launcher.dart';
import '../../../actions/routes.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/feedback/toast.dart';
import '../settings_hooks.dart';
import '../widgets/section_frame.dart';
import '../widgets/setting_tiles.dart';

/// Android permission / battery state shown in Settings (re-read on demand).
@immutable
class AndroidStatus {
  const AndroidStatus({required this.notifications, required this.ignoringBatteryOptimizations});

  final bool notifications;
  final bool ignoringBatteryOptimizations;
}

final androidStatusProvider = FutureProvider.autoDispose<AndroidStatus?>((ref) async {
  final helper = ref.watch(androidSystemProvider);
  if (!helper.isSupported) return null;
  return AndroidStatus(
    notifications: await helper.notificationsPermitted(),
    ignoringBatteryOptimizations: await helper.isIgnoringBatteryOptimizations(),
  );
});

/// Settings → Notifications.
class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final n = ref.watch(settingsProvider.select((s) => s.notifications));
    final platform = ref.watch(platformInfoProvider);
    final notifier = ref.watch(systemNotifierProvider);
    final android = ref.watch(androidSystemProvider);
    void set(NotificationSettings Function(NotificationSettings n) change) =>
        updateSettings(ref, (s) => s.copyWith(notifications: change(s.notifications)));

    return SectionFrame(
      title: l10n.shellSectionNotifications,
      showHeading: showHeading,
      onRestoreDefaults: () => updateSettings(ref, (s) => s.copyWith(notifications: const NotificationSettings())),
      children: [
        SettingsGroup(children: [
          // Track-change toasts are a desktop feature (Android shows the
          // media notification instead).
          if (platform.isDesktop)
            SettingSwitch(
              key: const ValueKey('setting.notifyTrackChange'),
              title: l10n.settingsNotifyTrackChange,
              subtitle: l10n.settingsNotifyTrackChangeHint,
              value: n.trackChange && notifier.isSupported,
              disabledReason: l10n.settingsNotificationsUnsupported,
              onChanged: notifier.isSupported ? (v) => set((n) => n.copyWith(trackChange: v)) : null,
            ),
          SettingSwitch(
            key: const ValueKey('setting.notifyDownloads'),
            title: l10n.settingsNotifyDownloads,
            subtitle: l10n.settingsNotifyDownloadsHint,
            value: n.downloads && notifier.isSupported,
            disabledReason: l10n.settingsNotificationsUnsupported,
            onChanged: notifier.isSupported ? (v) => set((n) => n.copyWith(downloads: v)) : null,
          ),
        ]),
        if (android.isSupported) const _AndroidNotificationPermission(),
        if (platform.isAndroid) SettingNote(text: l10n.settingsMediaNotificationNote),
      ],
    );
  }
}

class _AndroidNotificationPermission extends ConsumerWidget {
  const _AndroidNotificationPermission();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final helper = ref.watch(androidSystemProvider);
    final status = ref.watch(androidStatusProvider).value;
    final allowed = status?.notifications ?? false;
    return SettingsGroup(title: l10n.settingsPermissionGroup, children: [
      SettingAction(
        key: const ValueKey('settings.notificationPermission'),
        title: l10n.settingsNotificationPermission,
        subtitle: allowed ? l10n.settingsPermissionAllowed : l10n.settingsNotificationPermissionMissing,
        actionLabel: allowed ? l10n.settingsOpenSystemSettings : l10n.settingsAllow,
        onPressed: () async {
          if (allowed) {
            await helper.openAppSettings();
          } else {
            final granted = await helper.requestNotificationPermission();
            if (!granted) await helper.openAppSettings();
          }
          ref.invalidate(androidStatusProvider);
        },
      ),
    ]);
  }
}

/// Settings → Background playback.
class BackgroundSection extends ConsumerWidget {
  const BackgroundSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final platform = ref.watch(platformInfoProvider);
    final a = ref.watch(settingsProvider.select((s) => s.android));
    final hooks = ref.watch(settingsHooksProvider);
    final helper = ref.watch(androidSystemProvider);
    void set(AndroidSettings Function(AndroidSettings a) change) => updateSettings(ref, (s) => s.copyWith(android: change(s.android)));

    if (!platform.isAndroid) {
      return SectionFrame(
        title: l10n.shellSectionBackground,
        showHeading: showHeading,
        children: [
          SettingNote(key: const ValueKey('settings.backgroundDesktop'), text: l10n.settingsBackgroundDesktop),
          if (platform.isDesktop)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FermataButton(
                label: l10n.shellSectionDesktop,
                variant: FermataButtonVariant.ghost,
                onPressed: () => context.go(AppRoutes.settingsSection(SettingsSections.desktop)),
              ),
            ),
        ],
      );
    }

    final status = ref.watch(androidStatusProvider).value;
    final restart = hooks.androidRestartRequired?.call() ?? false;
    return SectionFrame(
      title: l10n.shellSectionBackground,
      intro: l10n.settingsBackgroundIntro,
      showHeading: showHeading,
      onRestoreDefaults: () => updateSettings(ref, (s) => s.copyWith(android: const AndroidSettings())),
      children: [
        if (restart) SettingNote(text: l10n.settingsRestartRequired, tone: NoteTone.warning),
        SettingsGroup(children: [
          SettingSwitch(
            key: const ValueKey('setting.stopForegroundOnPause'),
            title: l10n.settingsStopServiceOnPause,
            subtitle: l10n.settingsStopServiceOnPauseHint,
            value: a.stopForegroundOnPause,
            onChanged: (v) => set((a) => a.copyWith(stopForegroundOnPause: v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.resumeOnHeadset'),
            title: l10n.settingsResumeOnHeadset,
            subtitle: l10n.settingsResumeOnHeadsetHint,
            value: a.resumeOnHeadsetConnect,
            onChanged: (v) => set((a) => a.copyWith(resumeOnHeadsetConnect: v)),
          ),
        ]),
        if (helper.isSupported)
          SettingsGroup(title: l10n.settingsBatteryGroup, children: [
            SettingAction(
              key: const ValueKey('settings.batteryOptimization'),
              title: status?.ignoringBatteryOptimizations == true ? l10n.settingsBatteryUnrestricted : l10n.settingsBatteryOptimized,
              subtitle: status?.ignoringBatteryOptimizations == true
                  ? l10n.settingsBatteryUnrestrictedHint
                  : l10n.settingsBatteryOptimizedHint,
              actionLabel: status?.ignoringBatteryOptimizations == true ? l10n.settingsOpenSystemSettings : l10n.settingsAllowBackground,
              onPressed: () async {
                if (status?.ignoringBatteryOptimizations == true) {
                  await helper.openAppSettings();
                } else {
                  // Opt-in only: the system dialog appears after this tap.
                  await helper.requestIgnoreBatteryOptimizations();
                }
                ref.invalidate(androidStatusProvider);
              },
            ),
          ]),
        SettingNote(
          text: l10n.settingsOemNote,
          action: TextButton(
            onPressed: () => ref.read(externalLinkLauncherProvider)(Uri.parse('https://dontkillmyapp.com')),
            child: const Text('dontkillmyapp.com'),
          ),
        ),
      ],
    );
  }
}

/// Settings → System tray & window (desktop).
class DesktopSection extends ConsumerWidget {
  const DesktopSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = ref.watch(settingsProvider.select((s) => s.desktop));
    final lifecycle = ref.watch(appLifecycleProvider);
    final hooks = ref.watch(settingsHooksProvider);
    final env = ref.watch(desktopEnvironmentProvider);
    final platform = ref.watch(platformInfoProvider);
    void set(DesktopSettings Function(DesktopSettings d) change) => updateSettings(ref, (s) => s.copyWith(desktop: change(s.desktop)));

    final trayReason = lifecycle.trayAvailable ? null : (hooks.trayUnavailableReason?.call() ?? _fallbackTrayReason(context, env, platform.isLinux, d.showTrayIcon));

    return SectionFrame(
      title: l10n.shellSectionDesktop,
      showHeading: showHeading,
      onRestoreDefaults: () => updateSettings(
        ref,
        (s) => s.copyWith(
          desktop: const DesktopSettings().copyWith(launchAtLogin: s.desktop.launchAtLogin, startMinimized: s.desktop.startMinimized),
        ),
      ),
      children: [
        if (trayReason != null) SettingNote(key: const ValueKey('settings.trayUnavailable'), text: trayReason, tone: NoteTone.warning),
        SettingsGroup(children: [
          SettingChoice<CloseBehavior>(
            key: const ValueKey('setting.closeBehavior'),
            title: l10n.settingsCloseBehavior,
            value: d.closeBehavior,
            forceDropdown: true,
            options: [
              SettingOption(
                CloseBehavior.minimizeToTray,
                lifecycle.trayAvailable ? l10n.settingsCloseToTray : l10n.settingsCloseMinimize,
                description: lifecycle.trayAvailable ? l10n.settingsCloseToTrayHint : l10n.settingsCloseMinimizeHint,
              ),
              SettingOption(CloseBehavior.ask, l10n.settingsCloseAsk, description: l10n.settingsCloseAskHint),
              SettingOption(CloseBehavior.exit, l10n.settingsCloseQuit, description: l10n.settingsCloseQuitHint),
            ],
            onChanged: (v) => set((d) => d.copyWith(closeBehavior: v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.showTrayIcon'),
            title: l10n.settingsShowTrayIcon,
            subtitle: l10n.settingsShowTrayIconHint,
            value: d.showTrayIcon,
            onChanged: (v) => set((d) => d.copyWith(showTrayIcon: v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.rememberWindow'),
            title: l10n.settingsRememberWindow,
            subtitle: l10n.settingsRememberWindowHint,
            value: d.rememberWindowBounds,
            onChanged: (v) => set((d) => d.copyWith(rememberWindowBounds: v)),
          ),
        ]),
        SettingNote(text: l10n.settingsQuitNote),
      ],
    );
  }

  static String _fallbackTrayReason(BuildContext context, Map<String, String> env, bool linux, bool showIcon) {
    final l10n = context.l10n;
    if (!showIcon) return l10n.desktopTrayUnavailableDisabled;
    final desktop = (env['XDG_CURRENT_DESKTOP'] ?? '').toUpperCase();
    if (linux && desktop.contains('GNOME')) return l10n.desktopTrayUnavailableGnome;
    return l10n.desktopTrayUnavailableNoHost;
  }
}

/// Settings → Startup (desktop): launch at login + start minimized.
class StartupSection extends ConsumerStatefulWidget {
  const StartupSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  ConsumerState<StartupSection> createState() => _StartupSectionState();
}

class _StartupSectionState extends ConsumerState<StartupSection> {
  bool? _osEnabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final startup = ref.read(startupManagerProvider);
    if (!startup.isSupported) return;
    try {
      final enabled = await startup.isEnabled();
      if (mounted) setState(() => _osEnabled = enabled);
    } catch (_) {
      // Keep the stored value; the toggle still works.
    }
  }

  Future<void> _apply({required bool launch, required bool minimized}) async {
    final startup = ref.read(startupManagerProvider);
    setState(() => _busy = true);
    try {
      await startup.setEnabled(launch, startMinimized: minimized);
      await updateSettings(ref, (s) => s.copyWith(desktop: s.desktop.copyWith(launchAtLogin: launch, startMinimized: minimized)));
      if (mounted) setState(() => _osEnabled = launch);
    } catch (_) {
      if (mounted) showFermataToast(context, context.l10n.settingsLaunchAtLoginFailed, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = ref.watch(settingsProvider.select((s) => s.desktop));
    final startup = ref.watch(startupManagerProvider);
    final launch = _osEnabled ?? d.launchAtLogin;

    return SectionFrame(
      title: l10n.shellSectionStartup,
      showHeading: widget.showHeading,
      onRestoreDefaults: () => _apply(launch: false, minimized: false),
      children: [
        SettingsGroup(children: [
          SettingSwitch(
            key: const ValueKey('setting.launchAtLogin'),
            title: l10n.settingsLaunchAtLogin,
            subtitle: l10n.settingsLaunchAtLoginHint,
            value: launch && startup.isSupported,
            disabledReason: l10n.settingsLaunchAtLoginUnsupported,
            onChanged: startup.isSupported && !_busy ? (v) => _apply(launch: v, minimized: d.startMinimized) : null,
          ),
          SettingSwitch(
            key: const ValueKey('setting.startMinimized'),
            title: l10n.settingsStartMinimized,
            subtitle: l10n.settingsStartMinimizedHint,
            value: d.startMinimized,
            onChanged: _busy
                ? null
                : (v) async {
                    if (launch && startup.isSupported) {
                      // Rewrite the login entry so it carries --minimized.
                      await _apply(launch: true, minimized: v);
                    } else {
                      await updateSettings(ref, (s) => s.copyWith(desktop: s.desktop.copyWith(startMinimized: v)));
                    }
                  },
          ),
        ]),
      ],
    );
  }
}
