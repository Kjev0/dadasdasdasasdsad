import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/models/library.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/search_field.dart';
import '../../../widgets/feedback/skeleton.dart';
import '../../../widgets/feedback/states.dart';
import '../../../widgets/feedback/toast.dart';
import '../folders/scan_controller.dart';
import '../shared/page_layout.dart';
import '../shared/page_services.dart';
import '../shared/track_helpers.dart';
import 'filter_sheet.dart';
import 'library_query.dart';
import 'library_track_list.dart';

/// Library → Tracks: filter text, sort, filters (incl. the "Downloaded"
/// quick filter), play/shuffle, import a single file, and the track list.
class LibraryTracksTab extends ConsumerStatefulWidget {
  const LibraryTracksTab({super.key});

  @override
  ConsumerState<LibraryTracksTab> createState() => _LibraryTracksTabState();
}

class _LibraryTracksTabState extends ConsumerState<LibraryTracksTab> {
  late final _text = TextEditingController(text: ref.read(libraryFiltersProvider).text);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _importFile() async {
    final l10n = context.l10n;
    final path = await ref.read(pageFilePickerProvider).pickAudioFile(title: l10n.libraryImportFile);
    if (path == null || !mounted) return;
    try {
      final track = await ref.read(localLibraryProvider).importFile(path);
      if (!mounted) return;
      if (track == null) {
        showFermataToast(context, l10n.libraryImportFileFailed, isError: true);
      } else {
        ref.invalidate(libraryTracksProvider);
        showFermataToast(context, l10n.libraryImportFileDone(track.title), icon: Icons.library_add_check_rounded);
      }
    } catch (e) {
      if (mounted) showFermataToast(context, l10n.libraryImportFileFailed, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filters = ref.watch(libraryFiltersProvider);
    final ctl = ref.read(libraryFiltersProvider.notifier);
    final tracks = ref.watch(libraryTracksProvider);
    final insets = pageInsets(context);
    final compact = isCompactWidth(context);

    final sortMenu = PopupMenuButton<TrackSortField>(
      key: const ValueKey('library-sort'),
      tooltip: l10n.pagesSort,
      icon: const Icon(Icons.sort_rounded),
      onSelected: ctl.sortBy,
      itemBuilder: (context) => [
        for (final f in librarySortFields)
          CheckedPopupMenuItem(
            value: f,
            checked: f == filters.sort,
            child: Row(
              children: [
                Expanded(child: Text(sortFieldLabel(l10n, f))),
                if (f == filters.sort)
                  Icon(filters.descending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 16),
              ],
            ),
          ),
      ],
    );
    final filterButton = Badge(
      isLabelVisible: filters.activeCount > 0,
      label: Text('${filters.activeCount}'),
      child: IconButton(
        key: const ValueKey('library-filters'),
        tooltip: l10n.pagesFilter,
        icon: const Icon(Icons.tune_rounded),
        onPressed: () => showLibraryFilterSheet(context),
      ),
    );
    final toolbar = Padding(
      padding: insets.copyWith(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SearchField(
                  controller: _text,
                  hint: l10n.libraryFilterHint,
                  onChanged: (v) => ctl.update((f) => f.copyWith(text: v)),
                ),
              ),
              const SizedBox(width: 4),
              sortMenu,
              filterButton,
              IconButton(
                tooltip: l10n.libraryImportFile,
                icon: const Icon(Icons.file_open_rounded),
                onPressed: _importFile,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                key: const ValueKey('quick-downloaded'),
                avatar: const Icon(Icons.download_done_rounded, size: 16),
                label: Text(l10n.libraryQuickDownloaded),
                selected: filters.downloadedOnly,
                onSelected: (v) => ctl.update((f) => f.copyWith(downloadedOnly: v)),
              ),
              FilterChip(
                key: const ValueKey('quick-local'),
                avatar: const Icon(Icons.folder_rounded, size: 16),
                label: Text(l10n.libraryLocalFiles),
                selected: filters.localFilesOnly,
                onSelected: (v) => ctl.update((f) => f.copyWith(localFilesOnly: v)),
              ),
              if (filters.activeCount > 0)
                TextButton(onPressed: () => ctl.set(filters.cleared()), child: Text(l10n.pagesClearFilters)),
              if (!compact) Text(l10n.librarySortedBy(sortFieldLabel(l10n, filters.sort)), style: context.type.caption),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toolbar,
        Expanded(
          child: tracks.when(
            loading: () => const SkeletonTrackList(),
            error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(libraryTracksProvider)),
            data: (list) {
              if (list.isEmpty) {
                final filtered = filters.activeCount > 0 || filters.text.trim().isNotEmpty;
                return SingleChildScrollView(
                  child: filtered
                      ? EmptyState(
                          icon: Icons.filter_alt_off_rounded,
                          title: l10n.pagesNoMatches,
                          actionLabel: l10n.pagesClearFilters,
                          onAction: () {
                            _text.clear();
                            ctl.set(const LibraryFilters().copyWith(sort: filters.sort, descending: filters.descending));
                          },
                        )
                      : EmptyState(
                          icon: Icons.library_music_rounded,
                          title: l10n.libraryEmptyTitle,
                          message: l10n.libraryEmptyMessage,
                          actionLabel: l10n.libraryAddFolder,
                          onAction: () => addMusicFolder(context, ref),
                          secondaryLabel: l10n.libraryImportFile,
                          onSecondary: _importFile,
                        ),
                );
              }
              return LibraryTrackList(
                tracks: list,
                origin: 'library',
                padding: insets.copyWith(bottom: 24),
                showSource: true,
                header: Padding(
                  padding: insets.copyWith(top: 4, bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PlayShuffleButtons(
                        enabled: list.any(isPlayableInApp),
                        onPlay: () => playCollection(context, ref, list, origin: 'library'),
                        onShuffle: () => playCollection(context, ref, list, shuffle: true, origin: 'library'),
                      ),
                      Text(l10n.pagesTrackCount(list.length), style: context.type.bodySmall),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
