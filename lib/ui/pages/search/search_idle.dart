import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/controls/section_header.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/tracks/track_tile.dart';
import '../library/shared/page_layout.dart';
import 'search_providers.dart';

/// Shown with an empty field: recent searches (with remove / clear) or a
/// hint, plus a notice when search history is turned off.
class SearchIdleView extends ConsumerWidget {
  const SearchIdleView({super.key, required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final saveHistory = ref.watch(settingsProvider.select((s) => s.privacy.saveSearchHistory));
    final recent = ref.watch(recentSearchesProvider);
    final insets = pageInsets(context);
    final hint = EmptyState(
      icon: Icons.search_rounded,
      title: l10n.searchEmptyTitle,
      message: l10n.searchEmptyMessage,
      actionLabel: l10n.searchBrowseExplore,
      onAction: () => context.go(AppRoutes.explore),
    );
    if (!saveHistory) {
      return ListView(
        padding: insets.copyWith(top: 8, bottom: 24),
        children: [
          InlineNotice(
            message: l10n.searchHistoryOff,
            icon: Icons.history_toggle_off_rounded,
            actionLabel: l10n.pagesOpenSettings,
            onAction: () => context.go(AppRoutes.settingsSection(SettingsSections.privacy)),
          ),
          hint,
        ],
      );
    }
    return recent.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(recentSearchesProvider)),
      data: (items) {
        if (items.isEmpty) return SingleChildScrollView(child: hint);
        return ListView(
          padding: insets.copyWith(top: 8, bottom: 24),
          children: [
            SectionHeader(
              title: l10n.searchRecent,
              actionLabel: l10n.searchClearRecent,
              onAction: () async {
                await ref.read(searchHistoryProvider).clear();
                resetRecordedSearch(ref);
                ref.invalidate(recentSearchesProvider);
              },
            ),
            for (final q in items)
              ListTile(
                key: ValueKey('recent-$q'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(Icons.history_rounded),
                title: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => onSearch(q),
                trailing: IconButton(
                  tooltip: l10n.searchRemoveRecent(q),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () async {
                    await ref.read(searchHistoryProvider).remove(q);
                    resetRecordedSearch(ref);
                    ref.invalidate(recentSearchesProvider);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Shown while typing (before results for the new text arrive): matching
/// recent searches and tracks from the library.
class SearchSuggestionsView extends ConsumerWidget {
  const SearchSuggestionsView({super.key, required this.query, required this.onSearch});

  final String query;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final suggestions = ref.watch(searchSuggestionsProvider(query));
    final data = suggestions.value;
    final insets = pageInsets(context);
    return ListView(
      padding: insets.copyWith(top: 4, bottom: 24),
      children: [
        ListTile(
          key: const ValueKey('suggest-query'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: const Icon(Icons.search_rounded),
          title: Text(l10n.searchFor(query), maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => onSearch(query),
        ),
        if (data != null) ...[
          for (final r in data.recent)
            ListTile(
              key: ValueKey('suggest-recent-$r'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.history_rounded),
              title: Text(r, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => onSearch(r),
            ),
          if (data.tracks.isNotEmpty) ...[
            SectionHeader(title: l10n.searchInYourLibrary, padding: const EdgeInsets.fromLTRB(8, 16, 0, 4)),
            for (final t in data.tracks)
              TrackTile(key: ValueKey('suggest-track-${t.id}'), track: t, showSource: true),
          ],
        ],
      ],
    );
  }
}
