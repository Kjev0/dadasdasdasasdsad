import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/library.dart';
import '../../../core/models/library.dart';
import '../../../core/sources/source_ids.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/controls/search_field.dart';
import '../../widgets/feedback/skeleton.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/media/media_card.dart';
import '../../widgets/util/async_utils.dart';
import 'shared/page_layout.dart';
import 'shared/revisions.dart';
import 'shared/track_helpers.dart';

/// Albums in the library (optionally filtered by text).
final libraryAlbumsProvider = FutureProvider.autoDispose.family<List<AlbumSummary>, String>(
  (ref, text) async {
    watchLibrary(ref, LibraryTopic.tracks);
    final albums = await ref.watch(trackRepositoryProvider).albums(text: text.isEmpty ? null : text);
    return [...albums]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  },
  retry: noRetry,
);

/// Artists in the library (optionally filtered by text).
final libraryArtistsProvider = FutureProvider.autoDispose.family<List<ArtistSummary>, String>(
  (ref, text) async {
    watchLibrary(ref, LibraryTopic.tracks);
    final artists = await ref.watch(trackRepositoryProvider).artists(text: text.isEmpty ? null : text);
    return [for (final a in artists) if (a.name.isNotEmpty) a]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  },
  retry: noRetry,
);

/// Responsive card grid: as many ~180 px columns as fit (at least two).
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.itemCount, required this.itemBuilder, this.header, this.padding = EdgeInsets.zero});

  final int itemCount;
  final Widget Function(BuildContext context, int index, double width) itemBuilder;
  final Widget? header;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth - padding.horizontal;
      const spacing = 12.0;
      final cols = max(2, ((available + spacing) / (180 + spacing)).floor());
      final cell = (available - spacing * (cols - 1)) / cols;
      return CustomScrollView(
        slivers: [
          if (header != null) SliverToBoxAdapter(child: header),
          SliverPadding(
            padding: padding,
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                mainAxisExtent: cell + 8 + 10 + 44 * textScale,
              ),
              delegate: SliverChildBuilderDelegate(childCount: itemCount, (context, i) => itemBuilder(context, i, cell)),
            ),
          ),
        ],
      );
    });
  }
}

/// Skeleton grid while albums/artists load.
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({super.key});

  @override
  Widget build(BuildContext context) => ClippedSkeleton(
        child: SkeletonShimmer(
          child: Padding(
            padding: pageInsets(context),
            child: Wrap(spacing: 12, runSpacing: 12, children: [for (var i = 0; i < 6; i++) const SkeletonCard(width: 150)]),
          ),
        ),
      );
}

class _FilterField extends StatelessWidget {
  const _FilterField({required this.onChanged, required this.hint});

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: pageInsets(context).copyWith(top: 8, bottom: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SearchField(hint: hint, onChanged: onChanged),
        ),
      );
}

/// Library → Albums.
class LibraryAlbumsTab extends ConsumerStatefulWidget {
  const LibraryAlbumsTab({super.key});

  @override
  ConsumerState<LibraryAlbumsTab> createState() => _LibraryAlbumsTabState();
}

class _LibraryAlbumsTabState extends ConsumerState<LibraryAlbumsTab> {
  String _text = '';

  Future<void> _play(AlbumSummary a) async {
    final tracks = await ref.read(trackRepositoryProvider).query(TrackQuery(album: a.title, sort: TrackSortField.album, descending: false));
    if (!mounted) return;
    await playCollection(context, ref, sortAlbumTracks(tracks), origin: 'album:${SourceIds.local}:${a.title}', originLabel: a.title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final albums = ref.watch(libraryAlbumsProvider(_text));
    final insets = pageInsets(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterField(hint: l10n.libraryFilterAlbums, onChanged: (v) => setState(() => _text = v.trim())),
        Expanded(
          child: albums.when(
            loading: () => const SkeletonGrid(),
            error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(libraryAlbumsProvider(_text))),
            data: (list) => list.isEmpty
                ? SingleChildScrollView(
                    child: EmptyState(icon: Icons.album_rounded, title: _text.isEmpty ? l10n.libraryNoAlbums : l10n.pagesNoMatches),
                  )
                : CardGrid(
                    padding: insets.copyWith(bottom: 24),
                    itemCount: list.length,
                    itemBuilder: (context, i, w) {
                      final a = list[i];
                      return MediaCard(
                        key: ValueKey('album-${a.artist}-${a.title}'),
                        width: w,
                        title: a.title,
                        subtitle: [a.artist, if (a.year != null) '${a.year}'].join(' · '),
                        artworkUrl: a.artworkUrl,
                        onTap: () => context.go(AppRoutes.album(SourceIds.local, a.title)),
                        onPlay: () => _play(a),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

/// Library → Artists.
class LibraryArtistsTab extends ConsumerStatefulWidget {
  const LibraryArtistsTab({super.key});

  @override
  ConsumerState<LibraryArtistsTab> createState() => _LibraryArtistsTabState();
}

class _LibraryArtistsTabState extends ConsumerState<LibraryArtistsTab> {
  String _text = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final artists = ref.watch(libraryArtistsProvider(_text));
    final insets = pageInsets(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterField(hint: l10n.libraryFilterArtists, onChanged: (v) => setState(() => _text = v.trim())),
        Expanded(
          child: artists.when(
            loading: () => const SkeletonGrid(),
            error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(libraryArtistsProvider(_text))),
            data: (list) => list.isEmpty
                ? SingleChildScrollView(
                    child: EmptyState(icon: Icons.person_rounded, title: _text.isEmpty ? l10n.libraryNoArtists : l10n.pagesNoMatches),
                  )
                : CardGrid(
                    padding: insets.copyWith(bottom: 24),
                    itemCount: list.length,
                    itemBuilder: (context, i, w) {
                      final a = list[i];
                      return MediaCard(
                        key: ValueKey('artist-${a.name}'),
                        width: w,
                        circle: true,
                        title: a.name,
                        subtitle: l10n.pagesTrackCount(a.trackCount),
                        artworkUrl: a.artworkUrl,
                        placeholderIcon: Icons.person_rounded,
                        onTap: () => context.go(AppRoutes.artist(SourceIds.local, a.name)),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
