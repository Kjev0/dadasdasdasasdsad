import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/library.dart';
import '../../../core/models/library.dart';
import '../../../core/models/track.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/search_field.dart';
import '../../widgets/feedback/skeleton.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/util/async_utils.dart';
import '../library/shared/labels.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/provider_notices.dart';
import '../library/shared/revisions.dart';
import '../library/shared/track_actions_row.dart';
import '../library/shared/track_helpers.dart';
import '../library/tracks/library_query.dart';
import '../library/tracks/library_track_list.dart';

/// Liked tracks (most recently liked first, as stored).
final favoriteTracksProvider = FutureProvider.autoDispose<List<Track>>(
  (ref) async {
    watchLibrary(ref, LibraryTopic.favorites);
    watchLibrary(ref, LibraryTopic.tracks);
    return ref.watch(favoritesRepositoryProvider).favorites();
  },
  retry: noRetry,
);

/// Sort orders for liked songs (`dateAdded` = order liked).
const favoriteSortFields = [
  TrackSortField.dateAdded,
  TrackSortField.title,
  TrackSortField.artist,
  TrackSortField.album,
  TrackSortField.duration,
];

/// Sorts and filters liked tracks in memory.
List<Track> sortFavorites(List<Track> tracks, {required TrackSortField sort, required bool descending, String text = '', String? source}) {
  final q = text.trim().toLowerCase();
  final list = [
    for (final t in tracks)
      if ((source == null || t.sourceId == source) &&
          (q.isEmpty || '${t.title} ${t.artistLine} ${t.album ?? ''}'.toLowerCase().contains(q)))
        t,
  ];
  if (sort == TrackSortField.dateAdded) return descending ? list : list.reversed.toList();
  int cmp(Track a, Track b) => switch (sort) {
        TrackSortField.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        TrackSortField.artist => a.artistLine.toLowerCase().compareTo(b.artistLine.toLowerCase()),
        TrackSortField.album => (a.album ?? '').toLowerCase().compareTo((b.album ?? '').toLowerCase()),
        TrackSortField.duration => (a.duration ?? Duration.zero).compareTo(b.duration ?? Duration.zero),
        _ => 0,
      };
  list.sort((a, b) => descending ? cmp(b, a) : cmp(a, b));
  return list;
}

/// Liked songs: sort, text + source filter, play all / shuffle, download
/// the tracks a provider permits.
class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  TrackSortField _sort = TrackSortField.dateAdded;
  bool _descending = true;
  String _text = '';
  String? _source;

  void _sortBy(TrackSortField f) => setState(() {
        if (f == _sort) {
          _descending = !_descending;
        } else {
          _sort = f;
          _descending = f == TrackSortField.dateAdded || f == TrackSortField.duration;
        }
      });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final favorites = ref.watch(favoriteTracksProvider);
    final insets = pageInsets(context);
    return Scaffold(
      body: favorites.when(
        loading: () => ListView(children: [PageHeader(title: l10n.navFavorites), const SkeletonTrackList()]),
        error: (e, _) => ListView(
          children: [PageHeader(title: l10n.navFavorites), ErrorState(error: e, onRetry: () => ref.invalidate(favoriteTracksProvider))],
        ),
        data: (all) {
          if (all.isEmpty) {
            return ListView(
              children: [
                PageHeader(title: l10n.navFavorites),
                EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: l10n.favoritesEmptyTitle,
                  message: l10n.favoritesEmptyMessage,
                  actionLabel: l10n.navExplore,
                  onAction: () => context.go(AppRoutes.explore),
                ),
              ],
            );
          }
          final sources = orderByPreference({for (final t in all) t.sourceId}, ref.watch(settingsProvider).services.providerOrder);
          final tracks = sortFavorites(all, sort: _sort, descending: _descending, text: _text, source: _source);
          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              PageHeader(
                title: l10n.navFavorites,
                subtitle: trackStats(l10n, all),
                actions: [
                  PlayShuffleButtons(
                    enabled: tracks.any(isPlayableInApp),
                    onPlay: () => playCollection(context, ref, tracks, origin: 'favorites', originLabel: l10n.navFavorites),
                    onShuffle: () => playCollection(context, ref, tracks, shuffle: true, origin: 'favorites', originLabel: l10n.navFavorites),
                  ),
                  CollectionDownloadButton(tracks: tracks, origin: 'favorites'),
                ],
              ),
              Padding(
                padding: insets.copyWith(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: SearchField(hint: l10n.favoritesFilterHint, onChanged: (v) => setState(() => _text = v)),
                      ),
                    ),
                    PopupMenuButton<TrackSortField>(
                      key: const ValueKey('favorites-sort'),
                      tooltip: l10n.pagesSort,
                      icon: const Icon(Icons.sort_rounded),
                      onSelected: _sortBy,
                      itemBuilder: (context) => [
                        for (final f in favoriteSortFields)
                          CheckedPopupMenuItem(
                            value: f,
                            checked: f == _sort,
                            child: Text(f == TrackSortField.dateAdded ? l10n.favoritesSortRecent : sortFieldLabel(l10n, f)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (sources.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: insets,
                    children: [
                      ChoiceChip(label: Text(l10n.searchFilterAll), selected: _source == null, onSelected: (_) => setState(() => _source = null)),
                      for (final id in sources) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          key: ValueKey('fav-source-$id'),
                          label: Text(sourceDisplayName(ref, id)),
                          selected: _source == id,
                          onSelected: (_) => setState(() => _source = _source == id ? null : id),
                        ),
                      ],
                    ],
                  ),
                ),
              TrackListNotices(tracks: tracks, padding: insets.copyWith(top: 8, bottom: 8)),
              if (tracks.isEmpty) EmptyState(icon: Icons.filter_alt_off_rounded, title: l10n.pagesNoMatches, compact: true),
            ],
          );
          return LibraryTrackList(
            tracks: tracks,
            origin: 'favorites',
            originLabel: l10n.navFavorites,
            header: header,
            showSource: true,
            padding: insets.copyWith(bottom: 24),
          );
        },
      ),
    );
  }
}
