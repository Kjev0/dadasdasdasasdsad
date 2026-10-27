import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/logging/logging.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../settings/app_settings.dart';
import '../../../actions/link_launcher.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/brand/fermata_mark.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/feedback/toast.dart';
import '../data_transfer.dart';
import '../diagnostics.dart';
import '../settings_hooks.dart';
import '../widgets/section_frame.dart';
import '../widgets/setting_tiles.dart';

String _platformName(AppLocalizations l10n, WidgetRef ref) {
  final p = ref.read(platformInfoProvider);
  if (p.isAndroid) return 'Android';
  if (p.isWindows) return 'Windows';
  if (p.isLinux) return 'Linux';
  return p.os.name;
}

/// Settings → Updates.
class UpdatesSection extends ConsumerStatefulWidget {
  const UpdatesSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  ConsumerState<UpdatesSection> createState() => _UpdatesSectionState();
}

class _UpdatesSectionState extends ConsumerState<UpdatesSection> {
  bool _checking = false;
  UpdateInfo? _result;
  bool _failed = false;

  Future<void> _check(Future<UpdateInfo> Function() check) async {
    setState(() {
      _checking = true;
      _failed = false;
    });
    try {
      final r = await check();
      if (mounted) setState(() => _result = r);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hooks = ref.watch(settingsHooksProvider);
    final auto = ref.watch(settingsProvider.select((s) => s.updates.checkForUpdates));
    final version = ref.watch(appVersionProvider).value;
    final platform = ref.watch(platformInfoProvider);
    final check = hooks.checkForUpdates;
    final notes = _result?.releaseNotesUrl ?? hooks.releasesPage;
    final result = _result;

    return SectionFrame(
      title: l10n.shellSectionUpdates,
      showHeading: widget.showHeading,
      onRestoreDefaults: check == null ? null : () => updateSettings(ref, (s) => s.copyWith(updates: const UpdateSettings())),
      children: [
        SettingsGroup(children: [
          SettingInfo(title: l10n.settingsCurrentVersion, value: version?.display ?? '…'),
          if (check != null) ...[
            SettingSwitch(
              key: const ValueKey('setting.checkForUpdates'),
              title: l10n.settingsAutoUpdateCheck,
              subtitle: l10n.settingsAutoUpdateCheckHint,
              value: auto,
              onChanged: (v) => updateSettings(ref, (s) => s.copyWith(updates: s.updates.copyWith(checkForUpdates: v))),
            ),
            SettingAction(
              key: const ValueKey('settings.checkNow'),
              title: l10n.settingsCheckNow,
              subtitle: _failed
                  ? l10n.settingsUpdateFailed
                  : result == null
                      ? l10n.settingsCheckNowHint
                      : switch (result.status) {
                          UpdateInfoStatus.upToDate => l10n.settingsUpToDate(result.currentVersion),
                          UpdateInfoStatus.updateAvailable => l10n.settingsUpdateAvailable(result.latestVersion ?? '?'),
                          UpdateInfoStatus.noReleases => l10n.settingsNoReleases,
                        },
              actionLabel: l10n.settingsCheckNowAction,
              busy: _checking,
              onPressed: _checking ? null : () => _check(check),
            ),
          ],
        ]),
        if (check == null || result?.status == UpdateInfoStatus.updateAvailable)
          SettingNote(
            key: const ValueKey('settings.updateInstructions'),
            text: platform.isAndroid
                ? l10n.settingsUpdateHowAndroid
                : platform.isWindows
                    ? l10n.settingsUpdateHowWindows
                    : l10n.settingsUpdateHowLinux,
          ),
        if (notes != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FermataButton(
              label: l10n.settingsReleaseNotes,
              icon: Icons.open_in_new_rounded,
              variant: FermataButtonVariant.ghost,
              onPressed: () => ref.read(externalLinkLauncherProvider)(notes),
            ),
          ),
      ],
    );
  }
}

/// Settings → About & diagnostics.
class AboutSection extends ConsumerStatefulWidget {
  const AboutSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  ConsumerState<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends ConsumerState<AboutSection> {
  bool _exporting = false;

  Future<void> _exportDiagnostics() async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    setState(() => _exporting = true);
    try {
      final report = buildDiagnosticsReport(
        now: DateTime.now(),
        platform: ref.read(platformInfoProvider),
        settings: ref.read(settingsStoreProvider).current,
        sources: ref.read(sourceRegistryProvider).all,
        credentials: ref.read(credentialsStoreProvider),
        tokens: ref.read(tokenStoreProvider),
        locale: locale,
        version: ref.read(appVersionProvider).value,
        logFilePath: AppLogging.currentLogFile?.path,
        recentLogs: await AppLogging.readRecent(),
      );
      final where = await ref.read(fileDialogsProvider).saveFile(
            fileName: DataTransfer.fileName('diagnostics', 'txt', DateTime.now()),
            bytes: Uint8List.fromList(utf8.encode(report)),
            mimeType: 'text/plain',
          );
      if (mounted && where != null) showFermataToast(context, l10n.settingsSavedTo(where), icon: Icons.check_rounded);
    } catch (_) {
      if (mounted) showFermataToast(context, l10n.errorGeneric, isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final version = ref.watch(appVersionProvider).value;
    final logPath = AppLogging.currentLogFile?.path ?? ref.watch(appPathsProvider).logsDir.path;
    final attributions = [
      l10n.settingsAttributionSoundCloud,
      l10n.settingsAttributionDeezer,
      l10n.settingsAttributionAudius,
      l10n.settingsAttributionJamendo,
      l10n.settingsAttributionLrclib,
      l10n.settingsAttributionSpotifyYouTube,
    ];

    return SectionFrame(
      title: l10n.shellSectionAbout,
      showHeading: widget.showHeading,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(children: [
            const FermataLogo(markSize: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.settingsTagline, style: context.type.bodySmall),
              ]),
            ),
          ]),
        ),
        SettingsGroup(children: [
          SettingInfo(title: l10n.settingsVersion, value: version?.display ?? '…'),
          SettingInfo(title: l10n.settingsPlatform, value: _platformName(l10n, ref)),
          SettingInfo(title: l10n.settingsLogFile, value: logPath),
          SettingAction(
            key: const ValueKey('settings.exportDiagnostics'),
            title: l10n.settingsExportDiagnostics,
            subtitle: l10n.settingsExportDiagnosticsHint,
            actionLabel: l10n.settingsExportAction,
            busy: _exporting,
            onPressed: _exporting ? null : _exportDiagnostics,
          ),
          SettingAction(
            key: const ValueKey('settings.licenses'),
            title: l10n.settingsLicenses,
            subtitle: l10n.settingsLicensesHint,
            actionLabel: l10n.settingsLicensesAction,
            onPressed: () => showLicensePage(
              context: context,
              applicationName: l10n.appName,
              applicationVersion: version?.display,
              applicationIcon: const Padding(padding: EdgeInsets.all(12), child: FermataMark(size: 48)),
            ),
          ),
        ]),
        SettingsGroup(title: l10n.settingsAttributions, children: [
          Padding(
            key: const ValueKey('settings.attributions'),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final a in attributions)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(a, style: context.type.bodySmall)),
            ]),
          ),
        ]),
        SettingsGroup(title: l10n.settingsCredits, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.settingsCreditsBody, style: context.type.bodySmall.copyWith(color: c.textSecondary)),
          ),
        ]),
      ],
    );
  }
}
