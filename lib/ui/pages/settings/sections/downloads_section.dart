import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/errors.dart';
import '../../../../core/models/download.dart';
import '../../../../settings/app_settings.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/chips/badges.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/dialogs/dialogs.dart';
import '../../../widgets/feedback/toast.dart';
import '../settings_format.dart';
import '../settings_hooks.dart';
import '../widgets/section_frame.dart';
import '../widgets/setting_tiles.dart';

/// Settings → Downloads.
class DownloadsSection extends ConsumerStatefulWidget {
  const DownloadsSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  ConsumerState<DownloadsSection> createState() => _DownloadsSectionState();
}

class _DownloadsSectionState extends ConsumerState<DownloadsSection> {
  bool _moving = false;

  Future<void> _changeDirectory() async {
    final l10n = context.l10n;
    final store = ref.read(settingsStoreProvider);
    final current = store.current.downloads.directory ?? ref.read(appPathsProvider).defaultDownloadDir.path;
    final picked = await ref.read(fileDialogsProvider).pickDirectory(title: l10n.settingsDownloadFolderPick, initialDirectory: current);
    if (picked == null || picked == current || !mounted) return;
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.settingsDownloadFolderMoveTitle,
      message: l10n.settingsDownloadFolderMoveBody(picked),
      confirmLabel: l10n.settingsDownloadFolderMove,
    );
    if (!ok || !mounted) return;
    setState(() => _moving = true);
    final before = store.current.downloads.directory;
    try {
      await ref.read(downloadManagerProvider).changeDownloadDirectory(picked);
      // The download manager records the (normalized) path itself; only fill
      // it in when it did not.
      if (store.current.downloads.directory == before) {
        await store.update((s) => s.copyWith(downloads: s.downloads.copyWith(directory: picked)));
      }
      if (mounted) showFermataToast(context, l10n.settingsDownloadFolderMoved, icon: Icons.check_rounded);
    } catch (e) {
      if (mounted) {
        final message = e is StorageException ? l10n.settingsDownloadFolderFailedDetail(e.message) : l10n.settingsDownloadFolderFailed;
        showFermataToast(context, message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = ref.watch(settingsProvider.select((s) => s.downloads));
    final notifierSupported = ref.watch(systemNotifierProvider).isSupported;
    final dir = d.directory ?? ref.watch(appPathsProvider).defaultDownloadDir.path;
    void set(DownloadSettings Function(DownloadSettings d) change) =>
        updateSettings(ref, (s) => s.copyWith(downloads: change(s.downloads)));

    return SectionFrame(
      title: l10n.shellSectionDownloads,
      showHeading: widget.showHeading,
      onRestoreDefaults: () => updateSettings(
        ref,
        // The folder is kept: changing it moves files and needs its own step.
        (s) => s.copyWith(downloads: const DownloadSettings().copyWith(directory: s.downloads.directory)),
      ),
      children: [
        SettingsGroup(children: [
          SettingAction(
            key: const ValueKey('setting.downloadFolder'),
            title: l10n.settingsDownloadFolder,
            subtitle: dir,
            actionLabel: _moving ? l10n.settingsDownloadFolderMoving : l10n.settingsDownloadFolderChange,
            icon: Icons.folder_open_rounded,
            busy: _moving,
            onPressed: _moving ? null : _changeDirectory,
          ),
          if (_moving) const LinearProgressIndicator(minHeight: 2),
          SettingSwitch(
            key: const ValueKey('setting.wifiOnly'),
            title: l10n.settingWifiOnly,
            subtitle: l10n.settingsWifiOnlyHint,
            value: d.wifiOnly,
            onChanged: (v) => set((d) => d.copyWith(wifiOnly: v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.warnMobile'),
            title: l10n.settingsWarnMobile,
            subtitle: l10n.settingsWarnMobileHint,
            value: d.warnOnMobileData,
            disabledReason: l10n.settingsWarnMobileDisabled,
            onChanged: d.wifiOnly ? null : (v) => set((d) => d.copyWith(warnOnMobileData: v)),
          ),
          SettingSlider(
            key: const ValueKey('setting.maxConcurrent'),
            title: l10n.settingsMaxConcurrent,
            subtitle: l10n.settingsMaxConcurrentHint,
            value: d.maxConcurrent.toDouble(),
            min: 1,
            max: 6,
            divisions: 5,
            format: (v) => '${v.round()}',
            onChanged: (v) => set((d) => d.copyWith(maxConcurrent: v.round())),
          ),
          SettingSwitch(
            key: const ValueKey('setting.verifyIntegrity'),
            title: l10n.settingsVerifyIntegrity,
            subtitle: l10n.settingsVerifyIntegrityHint,
            value: d.verifyIntegrity,
            onChanged: (v) => set((d) => d.copyWith(verifyIntegrity: v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.notifyComplete'),
            title: l10n.settingsNotifyComplete,
            subtitle: l10n.settingsNotifyCompleteHint,
            value: d.notifyOnComplete && notifierSupported,
            disabledReason: l10n.settingsNotificationsUnsupported,
            onChanged: notifierSupported ? (v) => set((d) => d.copyWith(notifyOnComplete: v)) : null,
          ),
        ]),
        SettingsGroup(
          title: l10n.settingsOfflineGroup,
          description: l10n.settingsOfflineIntro,
          children: [
            _OfflineCategory(kind: AvailabilityBadgeKind.userOwned, text: l10n.settingsOfflineUserOwned),
            _OfflineCategory(kind: AvailabilityBadgeKind.downloadable, text: l10n.settingsOfflineDownloadable),
            _OfflineCategory(kind: AvailabilityBadgeKind.streamOnly, text: l10n.settingsOfflineStreamOnly),
            _OfflineCategory(kind: AvailabilityBadgeKind.unavailableOffline, text: l10n.settingsOfflineUnavailable),
          ],
        ),
        SettingNote(text: l10n.settingsAutoDownloadNote),
      ],
    );
  }
}

class _OfflineCategory extends StatelessWidget {
  const _OfflineCategory({required this.kind, required this.text});

  final AvailabilityBadgeKind kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvailabilityBadge(kind: kind),
          const SizedBox(height: 6),
          Text(text, style: context.type.bodySmall),
        ],
      ),
    );
  }
}

/// Storage usage, refreshed after every storage action.
final storageUsageProvider = FutureProvider.autoDispose<StorageUsage>((ref) => ref.watch(downloadManagerProvider).storageUsage());

/// Settings → Storage & cache.
class StorageSection extends ConsumerStatefulWidget {
  const StorageSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  ConsumerState<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends ConsumerState<StorageSection> {
  String? _busy;

  static const _limitsMb = [0, 1024, 2048, 5120, 10240, 20480, 51200];
  static const _artworkMb = [100, 300, 500, 1000, 2000];

  Future<void> _run(String id, Future<String> Function() task) async {
    setState(() => _busy = id);
    try {
      final message = await task();
      if (mounted) showFermataToast(context, message, icon: Icons.check_rounded);
    } catch (_) {
      if (mounted) showFermataToast(context, context.l10n.errorGeneric, isError: true);
    } finally {
      if (mounted) setState(() => _busy = null);
      ref.invalidate(storageUsageProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final st = ref.watch(settingsProvider.select((s) => s.storage));
    final dm = ref.read(downloadManagerProvider);
    void set(StorageSettings Function(StorageSettings s) change) =>
        updateSettings(ref, (s) => s.copyWith(storage: change(s.storage)));
    final limits = {..._limitsMb, st.downloadLimitMb}.toList()..sort();
    final artwork = {..._artworkMb, st.artworkCacheMb}.toList()..sort();

    return SectionFrame(
      title: l10n.shellSectionStorage,
      showHeading: widget.showHeading,
      onRestoreDefaults: () => updateSettings(ref, (s) => s.copyWith(storage: const StorageSettings())),
      children: [
        SettingsGroup(title: l10n.settingsUsageGroup, children: [
          ref.watch(storageUsageProvider).when(
                loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator(minHeight: 2)),
                error: (e, _) => SettingNote(text: l10n.settingsUsageFailed, tone: NoteTone.warning, inGroup: true),
                data: (u) => _UsageBreakdown(usage: u, locale: locale),
              ),
        ]),
        SettingsGroup(title: l10n.settingsLimitsGroup, children: [
          SettingChoice<int>(
            key: const ValueKey('setting.downloadLimit'),
            title: l10n.settingsDownloadLimit,
            subtitle: l10n.settingsDownloadLimitHint,
            value: st.downloadLimitMb,
            forceDropdown: true,
            options: [
              for (final mb in limits) SettingOption(mb, mb == 0 ? l10n.settingsUnlimited : formatMegabytes(mb, locale: locale)),
            ],
            onChanged: (v) => set((s) => s.copyWith(downloadLimitMb: v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.autoCleanup'),
            title: l10n.settingsAutoCleanup,
            subtitle: l10n.settingsAutoCleanupHint,
            value: st.autoCleanup,
            disabledReason: l10n.settingsAutoCleanupDisabled,
            onChanged: st.downloadLimitMb == 0 ? null : (v) => set((s) => s.copyWith(autoCleanup: v)),
          ),
          SettingChoice<int>(
            key: const ValueKey('setting.artworkCache'),
            title: l10n.settingsArtworkCache,
            subtitle: l10n.settingsArtworkCacheHint,
            value: st.artworkCacheMb,
            forceDropdown: true,
            options: [for (final mb in artwork) SettingOption(mb, formatMegabytes(mb, locale: locale))],
            onChanged: (v) => set((s) => s.copyWith(artworkCacheMb: v)),
          ),
        ]),
        SettingsGroup(title: l10n.settingsMaintenanceGroup, children: [
          SettingAction(
            key: const ValueKey('settings.cleanUpNow'),
            title: l10n.settingsCleanUpNow,
            subtitle: l10n.settingsCleanUpNowHint,
            actionLabel: l10n.settingsCleanUpNowAction,
            busy: _busy == 'cleanup',
            onPressed: _busy != null
                ? null
                : () => _run('cleanup', () async {
                      final freed = await dm.enforceStorageLimit();
                      return freed == 0 ? l10n.settingsNothingToClean : l10n.settingsFreed(formatBytes(freed, locale: locale));
                    }),
          ),
          SettingAction(
            key: const ValueKey('settings.clearArtwork'),
            title: l10n.settingsClearArtwork,
            subtitle: l10n.settingsClearArtworkHint,
            actionLabel: l10n.settingsClearArtworkAction,
            busy: _busy == 'artwork',
            onPressed: _busy != null
                ? null
                : () => _run('artwork', () async => l10n.settingsFreed(formatBytes(await dm.clearArtworkCache(), locale: locale))),
          ),
          SettingAction(
            key: const ValueKey('settings.verifyDownloads'),
            title: l10n.settingsVerifyDownloads,
            subtitle: l10n.settingsVerifyDownloadsHint,
            actionLabel: l10n.settingsVerifyDownloadsAction,
            busy: _busy == 'verify',
            onPressed: _busy != null
                ? null
                : () => _run('verify', () async {
                      final broken = await dm.verifyAll();
                      return broken.isEmpty ? l10n.settingsVerifyOk : l10n.settingsVerifyBroken(broken.length);
                    }),
          ),
        ]),
      ],
    );
  }
}

class _UsageBreakdown extends StatelessWidget {
  const _UsageBreakdown({required this.usage, required this.locale});

  final StorageUsage usage;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final parts = [
      (l10n.settingsUsageDownloads(usage.downloadCount), usage.downloadsBytes, c.accent),
      (l10n.settingsUsageArtwork, usage.artworkCacheBytes, c.success),
      (l10n.settingsUsageStreamCache, usage.streamCacheBytes, c.warning),
      (l10n.settingsUsageDatabase, usage.databaseBytes, c.textSecondary),
    ];
    final total = usage.totalBytes;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.settingsUsageTotal(formatBytes(total, locale: locale)), style: context.type.titleSmall),
          if (usage.freeDiskBytes != null) ...[
            const SizedBox(height: 2),
            Text(l10n.settingsUsageFree(formatBytes(usage.freeDiskBytes!, locale: locale)), style: context.type.bodySmall),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: total == 0
                  ? ColoredBox(color: c.surfaceHigh)
                  : Row(children: [
                      for (final p in parts)
                        if (p.$2 > 0) Expanded(flex: (p.$2 * 1000 ~/ total).clamp(1, 1000), child: ColoredBox(color: p.$3)),
                    ]),
            ),
          ),
          const SizedBox(height: 12),
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(p.$1, style: context.type.bodySmall)),
                Text(formatBytes(p.$2, locale: locale), style: context.type.bodySmall.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          if (usage.downloadLimitBytes != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.settingsUsageLimit(formatBytes(usage.downloadsBytes, locale: locale), formatBytes(usage.downloadLimitBytes!, locale: locale)),
              style: context.type.bodySmall,
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Consumer(
              builder: (context, ref, _) => FermataButton(
                label: l10n.settingsRefresh,
                icon: Icons.refresh_rounded,
                variant: FermataButtonVariant.ghost,
                onPressed: () => ref.invalidate(storageUsageProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
