import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../../app/providers.dart';
import '../../../../core/contracts/music_source.dart';
import '../../../../settings/app_settings.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/dialogs/dialogs.dart';
import '../../../widgets/feedback/toast.dart';
import '../data_transfer.dart';
import '../settings_hooks.dart';
import '../widgets/section_frame.dart';
import '../widgets/setting_tiles.dart';

final _log = Logger('ui.settings.privacy');

enum _RestoreMode { merge, replace }

/// Settings → Privacy: what is recorded, the network statement, and data
/// controls (delete, export/import, backup/restore).
class PrivacySection extends ConsumerStatefulWidget {
  const PrivacySection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  ConsumerState<PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends ConsumerState<PrivacySection> {
  String? _busy;

  Future<void> _run(String id, Future<String?> Function() task) async {
    setState(() => _busy = id);
    try {
      final message = await task();
      if (mounted && message != null) showFermataToast(context, message, icon: Icons.check_rounded);
    } on FormatException {
      if (mounted) showFermataToast(context, context.l10n.settingsFileInvalid, isError: true);
    } catch (e, st) {
      _log.warning('Privacy action $id failed', e, st);
      if (mounted) showFermataToast(context, context.l10n.errorGeneric, isError: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<bool> _confirm(String title, String message, String confirm, {String? typed}) => ConfirmDialog.show(
        context,
        title: title,
        message: message,
        confirmLabel: confirm,
        destructive: true,
        typedConfirmation: typed,
      );

  Future<void> _deleteHistory() async {
    final l10n = context.l10n;
    if (!await _confirm(l10n.settingsDeleteHistoryTitle, l10n.settingsDeleteHistoryBody, l10n.actionDelete)) return;
    await _run('history', () async {
      await ref.read(historyRepositoryProvider).clearHistory();
      return l10n.settingsDeleteHistoryDone;
    });
  }

  Future<void> _clearSearches() async {
    final l10n = context.l10n;
    if (!await _confirm(l10n.settingsClearSearchesTitle, l10n.settingsClearSearchesBody, l10n.settingsClearAction)) return;
    await _run('searches', () async {
      await ref.read(searchHistoryProvider).clear();
      return l10n.settingsClearSearchesDone;
    });
  }

  Future<void> _deleteAll() async {
    final l10n = context.l10n;
    final ok = await _confirm(l10n.settingsDeleteAllTitle, l10n.settingsDeleteAllBody, l10n.settingsDeleteAllAction,
        typed: l10n.settingsDeleteAllWord);
    if (!ok) return;
    await _run('all', () async {
      await ref.read(libraryMaintenanceProvider).deleteAllUserData();
      for (final source in ref.read(sourceRegistryProvider).all) {
        if (source.supports(SourceCapability.oauth) && source.authState.isConnected) {
          try {
            await source.disconnect();
          } catch (e) {
            _log.warning('Disconnecting ${source.id} failed: ${e.runtimeType}');
          }
        }
      }
      await ref.read(tokenStoreProvider).deleteAll();
      return l10n.settingsDeleteAllDone;
    });
  }

  Future<void> _save(String id, String fileName, Future<Uint8List> Function() bytes, String mime) => _run(id, () async {
        final l10n = context.l10n;
        final data = await bytes();
        final where = await ref.read(fileDialogsProvider).saveFile(fileName: fileName, bytes: data, mimeType: mime);
        return where == null ? null : l10n.settingsSavedTo(where);
      });

  Future<void> _importSettings() async {
    final l10n = context.l10n;
    final file = await ref.read(fileDialogsProvider).pickFile(title: l10n.settingsImportSettings, extensions: const ['json']);
    if (file == null) return;
    await _run('importSettings', () async {
      await DataTransfer.importSettings(ref.read(settingsStoreProvider), await file.read());
      return l10n.settingsImportSettingsDone;
    });
  }

  Future<void> _restoreLibrary() async {
    final l10n = context.l10n;
    final file = await ref.read(fileDialogsProvider).pickFile(title: l10n.settingsRestoreLibrary, extensions: const ['json']);
    if (file == null || !mounted) return;
    final mode = await showDialog<_RestoreMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsRestoreLibraryTitle),
        content: Text(l10n.settingsRestoreLibraryBody),
        actions: [
          FermataButton(label: l10n.actionCancel, variant: FermataButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
          FermataButton(
            label: l10n.settingsRestoreReplace,
            variant: FermataButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(_RestoreMode.replace),
          ),
          FermataButton(
            key: const ValueKey('settings.restoreMerge'),
            label: l10n.settingsRestoreMerge,
            onPressed: () => Navigator.of(context).pop(_RestoreMode.merge),
          ),
        ],
      ),
    );
    if (mode == null) return;
    await _run('restoreLibrary', () async {
      final backup = DataTransfer.decodeLibrary(await file.read());
      await ref.read(libraryMaintenanceProvider).importBackup(backup, merge: mode == _RestoreMode.merge);
      return l10n.settingsRestoreLibraryDone;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = ref.watch(settingsProvider.select((s) => s.privacy));
    void set(PrivacySettings Function(PrivacySettings p) change) => updateSettings(ref, (s) => s.copyWith(privacy: change(s.privacy)));
    final now = DateTime.now();

    return SectionFrame(
      title: l10n.shellSectionPrivacy,
      showHeading: widget.showHeading,
      onRestoreDefaults: () => updateSettings(ref, (s) => s.copyWith(privacy: const PrivacySettings())),
      children: [
        SettingsGroup(children: [
          SettingSwitch(
            key: const ValueKey('setting.recordHistory'),
            title: l10n.settingsRecordHistory,
            subtitle: l10n.settingsRecordHistoryHint,
            value: p.recordHistory,
            onChanged: (v) => set((p) => p.copyWith(recordHistory: v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.personalized'),
            title: l10n.settingsPersonalized,
            subtitle: l10n.settingsPersonalizedHint,
            value: p.personalizedRecommendations,
            onChanged: (v) => set((p) => p.copyWith(personalizedRecommendations: v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.saveSearches'),
            title: l10n.settingsSaveSearches,
            subtitle: l10n.settingsSaveSearchesHint,
            value: p.saveSearchHistory,
            onChanged: (v) => set((p) => p.copyWith(saveSearchHistory: v)),
          ),
        ]),
        const NetworkStatement(),
        SettingsGroup(title: l10n.settingsYourDataGroup, children: [
          SettingAction(
            key: const ValueKey('settings.deleteHistory'),
            title: l10n.settingsDeleteHistory,
            subtitle: l10n.settingsDeleteHistoryHint,
            actionLabel: l10n.actionDelete,
            busy: _busy == 'history',
            onPressed: _busy == null ? _deleteHistory : null,
          ),
          SettingAction(
            key: const ValueKey('settings.clearSearches'),
            title: l10n.settingsClearSearches,
            subtitle: l10n.settingsClearSearchesHint,
            actionLabel: l10n.settingsClearAction,
            busy: _busy == 'searches',
            onPressed: _busy == null ? _clearSearches : null,
          ),
          SettingAction(
            key: const ValueKey('settings.exportSettings'),
            title: l10n.settingsExportSettings,
            subtitle: l10n.settingsExportSettingsHint,
            actionLabel: l10n.settingsExportAction,
            icon: Icons.file_upload_outlined,
            busy: _busy == 'exportSettings',
            onPressed: _busy != null
                ? null
                : () => _save('exportSettings', DataTransfer.fileName('settings', 'json', now),
                    () async => DataTransfer.encodeSettings(ref.read(settingsStoreProvider).current), 'application/json'),
          ),
          SettingAction(
            key: const ValueKey('settings.importSettings'),
            title: l10n.settingsImportSettings,
            subtitle: l10n.settingsImportSettingsHint,
            actionLabel: l10n.settingsImportAction,
            icon: Icons.file_download_outlined,
            busy: _busy == 'importSettings',
            onPressed: _busy == null ? _importSettings : null,
          ),
          SettingAction(
            key: const ValueKey('settings.backupLibrary'),
            title: l10n.settingsBackupLibrary,
            subtitle: l10n.settingsBackupLibraryHint,
            actionLabel: l10n.settingsExportAction,
            icon: Icons.backup_outlined,
            busy: _busy == 'backup',
            onPressed: _busy != null
                ? null
                : () => _save('backup', DataTransfer.fileName('library', 'json', now),
                    () => DataTransfer.exportLibrary(ref.read(libraryMaintenanceProvider)), 'application/json'),
          ),
          SettingAction(
            key: const ValueKey('settings.restoreLibrary'),
            title: l10n.settingsRestoreLibrary,
            subtitle: l10n.settingsRestoreLibraryHint,
            actionLabel: l10n.settingsImportAction,
            icon: Icons.restore_rounded,
            busy: _busy == 'restoreLibrary',
            onPressed: _busy == null ? _restoreLibrary : null,
          ),
          SettingAction(
            key: const ValueKey('settings.deleteAll'),
            title: l10n.settingsDeleteAll,
            subtitle: l10n.settingsDeleteAllHint,
            actionLabel: l10n.settingsDeleteAllAction,
            destructive: true,
            busy: _busy == 'all',
            onPressed: _busy == null ? _deleteAll : null,
          ),
        ]),
      ],
    );
  }
}

/// The "no analytics or tracking" statement with the documented network
/// behaviour (what Fermata connects to, and when).
class NetworkStatement extends ConsumerWidget {
  const NetworkStatement({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final s = ref.watch(settingsProvider);
    final items = [
      (Icons.library_music_outlined, l10n.settingsNetworkProviders),
      (Icons.lyrics_outlined, s.playback.lyricsEnabled ? l10n.settingsNetworkLyricsOn : l10n.settingsNetworkLyricsOff),
      (Icons.system_update_alt_rounded, s.updates.checkForUpdates ? l10n.settingsNetworkUpdatesOn : l10n.settingsNetworkUpdatesOff),
      (Icons.image_outlined, l10n.settingsNetworkArtwork),
      (Icons.login_rounded, l10n.settingsNetworkSignIn),
    ];
    return SettingsGroup(
      title: l10n.settingsNoTrackingTitle,
      children: [
        Padding(
          key: const ValueKey('settings.networkStatement'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.shield_outlined, color: c.success, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.settingsNoTracking, style: context.type.body)),
              ]),
              const SizedBox(height: 12),
              Text(l10n.settingsNetworkIntro, style: context.type.bodySmall),
              const SizedBox(height: 8),
              for (final (icon, text) in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(icon, size: 18, color: c.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(text, style: context.type.bodySmall)),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
