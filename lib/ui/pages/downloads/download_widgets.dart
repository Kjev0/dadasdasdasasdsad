import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/models/download.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../design/fermata_tokens.dart';
import '../../widgets/artwork/artwork_image.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/feedback/toast.dart';
import '../../widgets/tracks/track_format.dart';
import '../library/shared/labels.dart';
import 'download_support.dart';

/// One download: artwork, title, status chip, progress, size, speed, ETA
/// and the actions valid for its status.
class DownloadTaskTile extends ConsumerWidget {
  const DownloadTaskTile({super.key, required this.task, this.onPlay});

  final DownloadTask task;

  /// Plays the completed download (and the rest of the completed list).
  final VoidCallback? onPlay;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) showFermataToast(context, errorMessageFor(context.l10n, e) ?? context.l10n.errorGeneric, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final dm = ref.read(downloadManagerProvider);
    final t = task;
    final s = t.status;
    final color = downloadStatusColor(context, s);

    String sizes() => t.totalBytes == null
        ? formatBytes(context, t.receivedBytes)
        : l10n.downloadsSizeOf(formatBytes(context, t.receivedBytes), formatBytes(context, t.totalBytes!));
    final details = <String>[
      if (s == DownloadStatus.downloading) ...[
        sizes(),
        if (t.bytesPerSecond > 0) l10n.downloadsSpeed(formatBytes(context, t.bytesPerSecond.round())),
        if (t.bytesPerSecond > 0 && t.totalBytes != null)
          l10n.downloadsEta(formatDuration(Duration(seconds: ((t.totalBytes! - t.receivedBytes) / t.bytesPerSecond).ceil()))),
      ],
      if (s == DownloadStatus.paused && t.receivedBytes > 0) sizes(),
      if (s == DownloadStatus.failed) downloadErrorText(l10n, t.error),
      if (s == DownloadStatus.failed && t.attempts > 1) l10n.downloadsAttempts(t.attempts),
      if (s == DownloadStatus.completed) ...[
        if (t.totalBytes != null) formatBytes(context, t.totalBytes!),
        if (t.completedAt != null) dateLabel(context, t.completedAt!),
      ],
    ];

    IconButton action(String tooltip, IconData icon, Future<void> Function() run) =>
        IconButton(tooltip: tooltip, icon: Icon(icon, size: 20), onPressed: () => _run(context, run));

    final actions = <Widget>[
      if (s == DownloadStatus.completed && onPlay != null)
        IconButton(tooltip: l10n.pagesPlay, icon: const Icon(Icons.play_arrow_rounded, size: 20), onPressed: onPlay),
      if (t.isActive) action(l10n.downloadsPause, Icons.pause_rounded, () => dm.pause(t.id)),
      if (s == DownloadStatus.paused) action(l10n.downloadsResume, Icons.play_circle_outline_rounded, () => dm.resume(t.id)),
      if (s == DownloadStatus.failed || s == DownloadStatus.canceled) action(l10n.actionRetry, Icons.refresh_rounded, () => dm.retry(t.id)),
      if (t.isActive || s == DownloadStatus.paused) action(l10n.actionCancel, Icons.close_rounded, () => dm.cancel(t.id)),
      if (s == DownloadStatus.completed) action(l10n.shellMenuRemoveDownload, Icons.delete_outline_rounded, () => dm.deleteDownload(t.trackId)),
      if (s == DownloadStatus.failed || s == DownloadStatus.canceled) action(l10n.pagesRemove, Icons.delete_outline_rounded, () => dm.remove(t.id)),
    ];

    return Semantics(
      label: '${t.track.title}, ${downloadStatusLabel(l10n, s)}',
      child: Padding(
        key: ValueKey('download-${t.id}'),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox.square(dimension: 44, child: ArtworkImage(uri: t.track.artworkUrl, size: 44)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _StatusChip(label: downloadStatusLabel(l10n, s), color: color),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          [t.track.artistLine, ...details].where((x) => x.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FermataTypography.tabular(context.type.bodySmall),
                        ),
                      ),
                    ],
                  ),
                  if (s == DownloadStatus.downloading || s == DownloadStatus.verifying || (s == DownloadStatus.paused && t.progress != null)) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: s == DownloadStatus.verifying ? null : t.progress,
                        minHeight: 3,
                        color: s == DownloadStatus.paused ? c.warning : null,
                        semanticsLabel: l10n.downloadsProgress,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(borderRadius: context.radii.xsAll, border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Text(label, style: context.type.caption.copyWith(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

/// Storage summary: downloads, artwork cache, database, free space and the
/// download limit, with a link to Settings → Storage.
class StorageSummaryCard extends ConsumerWidget {
  const StorageSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final usage = ref.watch(storageUsageProvider);
    final limitMb = ref.watch(settingsProvider.select((s) => s.storage.downloadLimitMb));
    return Container(
      key: const ValueKey('storage-summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, borderRadius: context.radii.mdAll, border: Border.all(color: c.outlineSubtle)),
      child: usage.when(
        loading: () => const SizedBox(height: 64, child: Center(child: LinearProgressIndicator())),
        error: (e, _) => Text(errorMessageFor(l10n, e) ?? l10n.errorGeneric, style: context.type.bodySmall),
        data: (u) {
          final limit = u.downloadLimitBytes ?? (limitMb > 0 ? limitMb * 1024 * 1024 : null);
          Widget row(String label, String value) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: context.type.bodySmall)),
                    Text(value, style: FermataTypography.tabular(context.type.body)),
                  ],
                ),
              );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.downloadsStorage, style: context.type.titleSmall)),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.settingsSection(SettingsSections.storage)),
                    child: Text(l10n.downloadsStorageSettings),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (limit != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (u.downloadsBytes / limit).clamp(0.0, 1.0),
                    minHeight: 6,
                    color: u.downloadsBytes > limit * 0.9 ? c.warning : null,
                    semanticsLabel: l10n.downloadsStorage,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              row(l10n.downloadsStorageDownloads(u.downloadCount), formatBytes(context, u.downloadsBytes)),
              row(l10n.downloadsStorageArtwork, formatBytes(context, u.artworkCacheBytes)),
              if (u.streamCacheBytes > 0) row(l10n.downloadsStorageStreamCache, formatBytes(context, u.streamCacheBytes)),
              row(l10n.downloadsStorageDatabase, formatBytes(context, u.databaseBytes)),
              row(l10n.downloadsStorageLimit, limit == null ? l10n.downloadsUnlimited : formatBytes(context, limit)),
              if (u.freeDiskBytes != null) row(l10n.downloadsStorageFree, formatBytes(context, u.freeDiskBytes!)),
            ],
          );
        },
      ),
    );
  }
}
