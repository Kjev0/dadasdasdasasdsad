import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/models/download.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/controls/section_header.dart';
import '../../widgets/controls/segmented_tabs.dart';
import '../../widgets/dialogs/dialogs.dart';
import '../../widgets/feedback/skeleton.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/feedback/toast.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/track_helpers.dart';
import 'download_support.dart';
import 'download_widgets.dart';

/// Downloads list filter.
enum DownloadFilter { all, active, completed, failed }

/// Downloads: active queue (progress, speed, ETA, status), per-task and
/// bulk pause / resume / retry / cancel, completed downloads, filters,
/// storage usage, the Wi-Fi-only waiting state, and the mobile-data
/// confirmation.
class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  DownloadFilter _filter = DownloadFilter.all;

  /// The mobile-data question is asked at most once per visit.
  bool _askedMobileData = false;

  Future<void> _askMobileData() async {
    _askedMobileData = true;
    final l10n = context.l10n;
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.downloadsMobileDataTitle,
      message: l10n.downloadsMobileDataMessage,
      confirmLabel: l10n.downloadsMobileDataConfirm,
      cancelLabel: l10n.downloadsMobileDataWait,
    );
    if (!ok || !mounted) return;
    if (confirmMobileData(ref.read(downloadManagerProvider))) {
      showFermataToast(context, l10n.downloadsMobileDataAllowed, icon: Icons.signal_cellular_alt_rounded);
      setState(() {});
    }
  }

  bool _matches(DownloadTask t) => switch (_filter) {
        DownloadFilter.all => true,
        DownloadFilter.active => t.isActive || t.status == DownloadStatus.paused,
        DownloadFilter.completed => t.status == DownloadStatus.completed,
        DownloadFilter.failed => t.status == DownloadStatus.failed || t.status == DownloadStatus.canceled,
      };

  Future<void> _bulk(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showFermataToast(context, context.l10n.errorGeneric, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tasksAsync = ref.watch(downloadTasksProvider);
    final dm = ref.watch(downloadManagerProvider);
    final wifiOnly = ref.watch(settingsProvider.select((s) => s.downloads.wifiOnly));
    final insets = pageInsets(context);

    final tasks = tasksAsync.value ?? const <DownloadTask>[];
    final waiting = tasks.any((t) => t.status == DownloadStatus.waitingForNetwork);
    final needsMobile = needsMobileDataConfirmation(dm) ?? false;
    if (needsMobile && waiting && !_askedMobileData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_askedMobileData) _askMobileData();
      });
    }
    final active = [for (final t in tasks) if (t.isActive || t.status == DownloadStatus.paused) t];
    final hasPaused = tasks.any((t) => t.status == DownloadStatus.paused);
    final shown = [for (final t in tasks) if (_matches(t)) t]..sort((a, b) {
        // Active first (queue order), then newest finished.
        final ra = a.isActive || a.status == DownloadStatus.paused ? 0 : 1;
        final rb = b.isActive || b.status == DownloadStatus.paused ? 0 : 1;
        if (ra != rb) return ra.compareTo(rb);
        if (ra == 0) return a.createdAt.compareTo(b.createdAt);
        return (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt);
      });
    final completedTracks = [for (final t in shown) if (t.status == DownloadStatus.completed) t.track];

    Widget? waitingNotice;
    if (waiting) {
      final reason = networkWaitReason(dm);
      if (needsMobile || reason == 'mobileDataConfirmation') {
        waitingNotice = InlineNotice(
          key: const ValueKey('notice-mobile-data'),
          warning: true,
          icon: Icons.signal_cellular_alt_rounded,
          message: l10n.downloadsWaitingMobileData,
          actionLabel: l10n.downloadsMobileDataConfirm,
          onAction: _askMobileData,
        );
      } else if (reason == 'wifiOnly' || (reason == null && wifiOnly)) {
        waitingNotice = InlineNotice(
          key: const ValueKey('notice-wifi-only'),
          icon: Icons.wifi_rounded,
          title: l10n.downloadsWaitingWifiTitle,
          message: l10n.downloadsWaitingWifi,
          actionLabel: l10n.downloadsDownloadSettings,
          onAction: () => context.go(AppRoutes.settingsSection(SettingsSections.downloads)),
        );
      } else {
        waitingNotice = InlineNotice(
          key: const ValueKey('notice-offline'),
          icon: Icons.cloud_off_rounded,
          message: l10n.downloadsWaitingConnection,
        );
      }
    }

    final children = <Widget>[
      PageHeader(
        title: l10n.navDownloads,
        padding: EdgeInsets.only(top: isCompactWidth(context) ? 16 : 24, bottom: 12),
        actions: [
          if (active.any((t) => t.isActive))
            FermataButton(
              label: l10n.downloadsPauseAll,
              icon: Icons.pause_rounded,
              variant: FermataButtonVariant.secondary,
              onPressed: () => _bulk(dm.pauseAll),
            ),
          if (hasPaused)
            FermataButton(label: l10n.downloadsResumeAll, icon: Icons.play_arrow_rounded, onPressed: () => _bulk(dm.resumeAll)),
        ],
      ),
      const StorageSummaryCard(),
      const SizedBox(height: 16),
      if (waitingNotice != null) ...[waitingNotice, const SizedBox(height: 16)],
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedTabs<DownloadFilter>(
          selected: _filter,
          onChanged: (f) => setState(() => _filter = f),
          tabs: [
            SegmentedTab(DownloadFilter.all, l10n.searchFilterAll),
            SegmentedTab(DownloadFilter.active, l10n.downloadsFilterActive),
            SegmentedTab(DownloadFilter.completed, l10n.downloadsFilterCompleted),
            SegmentedTab(DownloadFilter.failed, l10n.downloadsFilterFailed),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ];

    if (tasksAsync.isLoading && !tasksAsync.hasValue) {
      children.add(const SkeletonTrackList(count: 4));
    } else if (tasksAsync.hasError && !tasksAsync.hasValue) {
      children.add(ErrorState(error: tasksAsync.error!, onRetry: () => ref.invalidate(downloadTasksProvider)));
    } else if (tasks.isEmpty) {
      children.add(EmptyState(
        icon: Icons.download_rounded,
        title: l10n.downloadsEmptyTitle,
        message: l10n.downloadsEmptyMessage,
        actionLabel: l10n.navExplore,
        onAction: () => context.go(AppRoutes.explore),
      ));
    } else if (shown.isEmpty) {
      children.add(EmptyState(icon: Icons.filter_alt_off_rounded, title: l10n.downloadsNothingHere, compact: true));
    } else {
      final activeShown = [for (final t in shown) if (t.isActive || t.status == DownloadStatus.paused) t];
      final finished = [for (final t in shown) if (!(t.isActive || t.status == DownloadStatus.paused)) t];
      if (activeShown.isNotEmpty) {
        children.add(SectionHeader(title: l10n.downloadsActive, subtitle: l10n.downloadsActiveCount(activeShown.length)));
        for (final t in activeShown) {
          children.add(DownloadTaskTile(key: ValueKey('task-${t.id}'), task: t));
        }
        children.add(const SizedBox(height: 16));
      }
      if (finished.isNotEmpty) {
        children.add(SectionHeader(title: l10n.downloadsFinished));
        for (final t in finished) {
          final index = completedTracks.indexOf(t.track);
          children.add(DownloadTaskTile(
            key: ValueKey('task-${t.id}'),
            task: t,
            onPlay: index < 0
                ? null
                : () => playCollection(context, ref, completedTracks, startIndex: index, origin: 'downloads', originLabel: l10n.navDownloads),
          ));
        }
      }
    }

    return Scaffold(
      body: ListView(padding: insets.copyWith(bottom: 32), children: children),
    );
  }
}
