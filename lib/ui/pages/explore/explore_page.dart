import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/discovery.dart';
import '../../../core/models/track.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/section_header.dart';
import '../../widgets/feedback/skeleton.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/media/media_card.dart';
import '../../widgets/media/shelf_row.dart';
import '../home/shelf_views.dart';
import '../library/shared/labels.dart';
import '../library/shared/page_layout.dart';
import 'explore_providers.dart';

/// What the in-page detail view shows.
sealed class ExploreDetail {
  const ExploreDetail();
}

class GenreDetail extends ExploreDetail {
  const GenreDetail(this.genre);
  final String genre;
}

class MoodDetail extends ExploreDetail {
  const MoodDetail(this.mood);
  final MoodCategory mood;
}

/// Explore: moods, genres, trending tracks and new releases. A genre or
/// mood opens a playable track list (preview-only / external tracks are
/// labelled).
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  ExploreDetail? _detail;

  void _close() => setState(() => _detail = null);

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Scaffold(body: _DetailView(detail: detail, onBack: _close)),
      );
    }
    final l10n = context.l10n;
    final moods = ref.watch(recommendationsProvider).moods;
    final insets = pageInsets(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: PageHeader(title: l10n.navExplore, subtitle: l10n.exploreSubtitle)),
          SliverPadding(
            padding: insets.copyWith(bottom: 32),
            sliver: SliverList.list(
              children: [
                if (moods.isNotEmpty) ...[
                  SectionHeader(title: l10n.exploreMoods),
                  _MoodGrid(moods: moods, onOpen: (m) => setState(() => _detail = MoodDetail(m))),
                  const SizedBox(height: 24),
                ],
                SectionHeader(title: l10n.exploreGenres),
                _GenreChips(onOpen: (g) => setState(() => _detail = GenreDetail(g))),
                const SizedBox(height: 24),
                const _TrendingSection(),
                const SizedBox(height: 8),
                const _ReleasesSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodGrid extends StatelessWidget {
  const _MoodGrid({required this.moods, required this.onOpen});

  final List<MoodCategory> moods;
  final ValueChanged<MoodCategory> onOpen;

  static IconData iconFor(String id) => switch (id) {
        'focus' => Icons.center_focus_strong_rounded,
        'chill' => Icons.spa_rounded,
        'workout' => Icons.fitness_center_rounded,
        'party' => Icons.celebration_rounded,
        'sleep' => Icons.bedtime_rounded,
        'commute' => Icons.directions_car_rounded,
        'happy' => Icons.wb_sunny_rounded,
        'melancholy' => Icons.water_drop_rounded,
        _ => Icons.graphic_eq_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final tileWidth = width < 600 ? 150.0 : 184.0;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final m in moods)
          SizedBox(
            width: tileWidth,
            height: 64,
            child: Material(
              color: c.surface,
              borderRadius: context.radii.mdAll,
              child: InkWell(
                key: ValueKey('mood-${m.id}'),
                borderRadius: context.radii.mdAll,
                onTap: () => onOpen(m),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(iconFor(m.id), color: c.accentText),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(moodLabel(l10n, m), style: context.type.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GenreChips extends ConsumerWidget {
  const _GenreChips({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genres = ref.watch(exploreGenresProvider);
    return genres.when(
      loading: () => SkeletonShimmer(
        child: Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < 8; i++) const Skeleton(width: 96, height: 32, radius: 16)]),
      ),
      error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(exploreGenresProvider)),
      data: (list) => list.isEmpty
          ? Text(context.l10n.exploreNoGenres, style: context.type.bodySmall)
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in list) ActionChip(key: ValueKey('genre-$g'), label: Text(g), onPressed: () => onOpen(g)),
              ],
            ),
    );
  }
}

class _TrendingSection extends ConsumerWidget {
  const _TrendingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final trending = ref.watch(exploreTrendingProvider);
    return trending.when(
      loading: () => const Padding(padding: EdgeInsets.only(bottom: 16), child: SkeletonShelf()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ErrorState(title: l10n.shelfTrending, error: e, compact: true, onRetry: () => ref.invalidate(exploreTrendingProvider)),
      ),
      data: (tracks) => tracks.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TrackShelfRow(title: l10n.shelfTrending, tracks: tracks, origin: 'trending'),
            ),
    );
  }
}

class _ReleasesSection extends ConsumerWidget {
  const _ReleasesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final releases = ref.watch(exploreReleasesProvider);
    final w = shelfCardWidth(context);
    return releases.when(
      loading: () => const SkeletonShelf(),
      error: (e, _) => ErrorState(title: l10n.shelfNewReleases, error: e, compact: true, onRetry: () => ref.invalidate(exploreReleasesProvider)),
      data: (albums) => albums.isEmpty
          ? const SizedBox.shrink()
          : ShelfRow(
              title: l10n.shelfNewReleases,
              itemWidth: w,
              itemCount: albums.length,
              itemBuilder: (context, i) {
                final a = albums[i];
                final artist = a.artists.map((x) => x.name).join(', ');
                return MediaCard(
                  key: ValueKey('release-${a.id}'),
                  width: w,
                  title: a.title,
                  subtitle: [if (artist.isNotEmpty) artist, sourceDisplayName(ref, a.sourceId)].join(' · '),
                  artworkUrl: a.artworkUrl,
                  onTap: () => context.go(AppRoutes.album(a.sourceId, a.sourceAlbumId)),
                );
              },
            ),
    );
  }
}

class _DetailView extends ConsumerWidget {
  const _DetailView({required this.detail, required this.onBack});

  final ExploreDetail detail;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (String title, String eyebrow, String origin, AsyncValue<List<Track>> tracks, VoidCallback retry) = switch (detail) {
      GenreDetail(:final genre) => (
          genre,
          l10n.exploreGenre,
          'genre:$genre',
          ref.watch(genreTracksProvider(genre)),
          () => ref.invalidate(genreTracksProvider(genre)),
        ),
      MoodDetail(:final mood) => (
          moodLabel(l10n, mood),
          l10n.exploreMood,
          'mood:${mood.id}',
          ref.watch(moodTracksProvider(mood.id)),
          () => ref.invalidate(moodTracksProvider(mood.id)),
        ),
    };
    return tracks.when(
      loading: () => ListView(
        children: [
          Align(alignment: Alignment.centerLeft, child: Padding(padding: pageInsets(context), child: BackHeaderButton(onPressed: onBack))),
          const SkeletonHeader(),
          const SkeletonTrackList(),
        ],
      ),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: pageInsets(context).copyWith(top: 16), child: BackHeaderButton(onPressed: onBack)),
          Expanded(child: ErrorState(title: title, error: e, onRetry: retry)),
        ],
      ),
      data: (list) => TrackCollectionView(
        key: ValueKey(origin),
        title: title,
        eyebrow: eyebrow,
        tracks: list,
        origin: origin,
        onBack: onBack,
        emptyMessage: l10n.exploreNothingFound,
      ),
    );
  }
}
