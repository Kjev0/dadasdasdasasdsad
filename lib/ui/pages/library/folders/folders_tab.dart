import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../app/providers.dart';
import '../../../../core/contracts/library.dart';
import '../../../../core/models/library.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/controls/section_header.dart';
import '../../../widgets/dialogs/dialogs.dart';
import '../../../widgets/feedback/messages.dart';
import '../../../widgets/feedback/skeleton.dart';
import '../../../widgets/feedback/states.dart';
import '../../../widgets/feedback/toast.dart';
import '../../../widgets/util/async_utils.dart';
import '../shared/labels.dart';
import '../shared/page_layout.dart';
import '../shared/revisions.dart';
import 'maintenance_sheets.dart';
import 'scan_controller.dart';

/// Library folders; refetched on folder changes and when a scan finishes.
final libraryFoldersProvider = FutureProvider.autoDispose<List<LibraryFolder>>(
  (ref) async {
    watchLibrary(ref, LibraryTopic.folders);
    watchLibrary(ref, LibraryTopic.tracks);
    ref.watch(libraryScanProvider.select((s) => s.running));
    final folders = await ref.watch(localLibraryProvider).folders();
    return [...folders]..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  },
  retry: noRetry,
);

/// Library → Folders: add / remove / rescan folders, watch toggle (desktop),
/// scan progress, missing files and duplicates tools.
class LibraryFoldersTab extends ConsumerWidget {
  const LibraryFoldersTab({super.key});

  Future<void> _remove(BuildContext context, WidgetRef ref, LibraryFolder f) async {
    final l10n = context.l10n;
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.libraryRemoveFolderTitle,
      message: l10n.libraryRemoveFolderMessage(f.path),
      confirmLabel: l10n.pagesRemove,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(localLibraryProvider).removeFolder(f.path);
      ref.invalidate(libraryFoldersProvider);
    } catch (e) {
      if (context.mounted) showFermataToast(context, errorMessageFor(l10n, e) ?? l10n.errorGeneric, isError: true);
    }
  }

  Future<void> _setWatch(BuildContext context, WidgetRef ref, LibraryFolder f, bool watch) async {
    try {
      // Re-adding an existing folder updates its watch flag.
      await ref.read(localLibraryProvider).addFolder(f.path, watch: watch);
      ref.invalidate(libraryFoldersProvider);
    } catch (e) {
      if (context.mounted) showFermataToast(context, errorMessageFor(context.l10n, e) ?? context.l10n.errorGeneric, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folders = ref.watch(libraryFoldersProvider);
    final scan = ref.watch(libraryScanProvider);
    final scanner = ref.read(libraryScanProvider.notifier);
    final desktop = ref.watch(platformInfoProvider).isDesktop;
    final insets = pageInsets(context);

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FermataButton(label: l10n.libraryAddFolder, icon: Icons.create_new_folder_rounded, onPressed: () => addMusicFolder(context, ref)),
        FermataButton(
          label: l10n.libraryRescanAll,
          icon: Icons.refresh_rounded,
          variant: FermataButtonVariant.secondary,
          onPressed: scan.running ? null : () => scanner.start(),
        ),
        FermataButton(
          label: l10n.libraryFullRescan,
          icon: Icons.manage_search_rounded,
          variant: FermataButtonVariant.ghost,
          onPressed: scan.running ? null : () => scanner.start(full: true),
        ),
      ],
    );

    return ListView(
      padding: insets.copyWith(top: 8, bottom: 32),
      children: [
        actions,
        const SizedBox(height: 16),
        if (scan.running || scan.progress != null || scan.error != null) ...[
          ScanProgressCard(state: scan, onCancel: scanner.cancel),
          const SizedBox(height: 16),
        ],
        SectionHeader(title: l10n.libraryFolders, subtitle: desktop ? l10n.libraryFoldersHintDesktop : l10n.libraryFoldersHintAndroid),
        folders.when(
          loading: () => const SkeletonTrackList(count: 3),
          error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(libraryFoldersProvider)),
          data: (list) => list.isEmpty
              ? EmptyState(
                  icon: Icons.folder_open_rounded,
                  title: l10n.libraryNoFolders,
                  message: l10n.libraryNoFoldersMessage,
                  compact: true,
                )
              : Column(
                  children: [
                    for (final f in list)
                      _FolderTile(
                        key: ValueKey('folder-${f.path}'),
                        folder: f,
                        showWatch: desktop,
                        busy: scan.running && (scan.folder == null || scan.folder == f.path),
                        onWatch: (v) => _setWatch(context, ref, f, v),
                        onRescan: scan.running ? null : () => scanner.start(folder: f.path),
                        onRemove: () => _remove(context, ref, f),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        SectionHeader(title: l10n.libraryTools),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FermataButton(
              label: l10n.libraryMissingFiles,
              icon: Icons.report_gmailerrorred_rounded,
              variant: FermataButtonVariant.secondary,
              onPressed: () => showMissingFilesSheet(context),
            ),
            FermataButton(
              label: l10n.libraryDuplicates,
              icon: Icons.content_copy_rounded,
              variant: FermataButtonVariant.secondary,
              onPressed: () => showDuplicatesSheet(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    super.key,
    required this.folder,
    required this.showWatch,
    required this.busy,
    required this.onWatch,
    required this.onRescan,
    required this.onRemove,
  });

  final LibraryFolder folder;
  final bool showWatch;
  final bool busy;
  final ValueChanged<bool> onWatch;
  final VoidCallback? onRescan;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = p.basename(folder.path).isEmpty ? folder.path : p.basename(folder.path);
    final meta = [
      l10n.pagesTrackCount(folder.trackCount),
      folder.lastScannedAt == null ? l10n.libraryNeverScanned : l10n.libraryScannedOn(dateLabel(context, folder.lastScannedAt!)),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.colors.surface,
        borderRadius: context.radii.mdAll,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(Icons.folder_rounded, color: context.colors.accentText),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.type.body.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(folder.path, style: context.type.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(meta, style: context.type.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (showWatch)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(l10n.libraryWatchFolder, style: context.type.bodySmall, overflow: TextOverflow.ellipsis)),
                          Switch(
                            value: folder.watch,
                            onChanged: onWatch,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (busy)
                const Padding(padding: EdgeInsets.all(12), child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              else
                IconButton(tooltip: l10n.libraryRescanFolder, icon: const Icon(Icons.refresh_rounded), onPressed: onRescan),
              IconButton(tooltip: l10n.libraryRemoveFolder, icon: const Icon(Icons.delete_outline_rounded), onPressed: onRemove),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scan progress: files scanned of total, added / updated / removed, the
/// current file, errors; cancel while running.
class ScanProgressCard extends StatelessWidget {
  const ScanProgressCard({super.key, required this.state, required this.onCancel});

  final LibraryScanState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final pr = state.progress;
    final title = state.error != null
        ? l10n.libraryScanFailed
        : state.running
            ? (pr?.totalFiles == null ? l10n.libraryScanEnumerating : l10n.libraryScanProgress(pr!.scannedFiles, pr.totalFiles!))
            : l10n.libraryScanDone;
    return Container(
      key: const ValueKey('scan-progress'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, borderRadius: context.radii.mdAll, border: Border.all(color: c.outlineSubtle)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.type.titleSmall)),
              if (state.running) TextButton(onPressed: onCancel, child: Text(l10n.actionCancel)),
            ],
          ),
          const SizedBox(height: 8),
          if (state.running) LinearProgressIndicator(value: state.fraction),
          if (pr != null) ...[
            const SizedBox(height: 8),
            Text(l10n.libraryScanCounts(pr.added, pr.updated, pr.removed), style: context.type.bodySmall),
            if (state.running && pr.currentPath != null)
              Text(pr.currentPath!, style: context.type.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (pr.errors.isNotEmpty)
              Text(l10n.libraryScanErrors(pr.errors.length), style: context.type.caption.copyWith(color: c.warning)),
          ],
          if (state.error != null)
            Text(errorMessageFor(l10n, state.error!) ?? l10n.errorGeneric, style: context.type.bodySmall.copyWith(color: c.danger)),
        ],
      ),
    );
  }
}
