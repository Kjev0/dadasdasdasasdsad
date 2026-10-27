import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/sources/source_ids.dart';
import '../../actions/routes.dart';
import '../../actions/track_actions.dart';
import '../../design/context_ext.dart';
import '../../widgets/artwork/artwork_image.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/controls/section_header.dart';
import '../../widgets/feedback/skeleton.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/media/media_card.dart';
import '../../widgets/media/shelf_row.dart';
import '../../widgets/tracks/track_tile.dart';
import '../home/shelf_views.dart';
import '../library/shared/labels.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/provider_notices.dart';
import '../library/shared/track_helpers.dart';
import 'artist_providers.dart';

/// Top tracks shown before "Show all".
const artistCollapsedTracks = 5;

/// An artist (`sourceId` + `artistId`; library artists use their name):
/// header, top tracks, albums / releases, related artists and an "open on
/// provider" link with attribution.
class ArtistPage extends ConsumerStatefulWidget {
  const ArtistPage({super.key, required this.sourceId, required this.artistId});

  final String sourceId;

  final String artistId;

  @override
  ConsumerState<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends ConsumerState<ArtistPage> {
  bool _allTracks = false;

  @override
  Widget build(BuildContext context) {
    final key = (widget.sourceId, widget.artistId);
    final data = ref.watch(artistPageProvider(key));
    return Scaffold(
      body: data.when(
        loading: () => ListView(children: const [SkeletonHeader(), SkeletonTrackList(count: 5)]),
        error: (e, _) => ListView(
          children: [
            Padding(padding: pageInsets(context).copyWith(top: 8), child: Align(alignment: Alignment.centerLeft, child: _back(context))),
            ErrorState(error: e, onRetry: () => ref.invalidate(artistPageProvider(key))),
          ],
        ),
        data: (d) => _content(context, d),
      ),
    );
  }

  Widget _back(BuildContext context) =>
      BackHeaderButton(onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.home));

  Widget _content(BuildContext context, ArtistPageData d) {
    final l10n = context.l10n;
    final insets = pageInsets(context);
    final local = d.sourceId == SourceIds.local;
    final provider = local ? l10n.libraryLocalFiles : sourceDisplayName(ref, d.sourceId);
    final origin = 'artist:${d.sourceId}:${widget.artistId}';
    final followers = d.followers == null ? null : l10n.artistFollowers(NumberFormat.compact(locale: localeNameOf(context)).format(d.followers));
    final meta = [?followers, if (d.genres.isNotEmpty) d.genres.take(3).join(', '), if (local) l10n.pagesTrackCount(d.topTracks.length)].join(' · ');
    final shown = _allTracks ? d.topTracks : d.topTracks.take(artistCollapsedTracks).toList();
    final w = shelfCardWidth(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        CollectionHeader(
          leading: _back(context),
          eyebrow: local ? l10n.artistInLibrary : l10n.artistOnProvider(provider),
          title: d.name,
          meta: meta.isEmpty ? null : meta,
          description: d.description,
          artwork: (size) => ArtworkImage(uri: d.avatarUrl, size: size, circle: true),
          actions: [
            PlayShuffleButtons(
              enabled: d.topTracks.any(isPlayableInApp),
              onPlay: () => playCollection(context, ref, d.topTracks, origin: origin, originLabel: d.name),
              onShuffle: () => playCollection(context, ref, d.topTracks, shuffle: true, origin: origin, originLabel: d.name),
            ),
            if (d.permalink != null)
              FermataButton(
                key: const ValueKey('artist-open-on-provider'),
                label: l10n.pagesOpenOnProvider(provider),
                icon: Icons.open_in_new_rounded,
                variant: FermataButtonVariant.ghost,
                onPressed: () => TrackActions(context, ref).openLink(d.permalink!),
              ),
          ],
        ),
        if (!local)
          Padding(
            padding: insets.copyWith(bottom: 8),
            child: Text(l10n.pagesDataFrom(provider), key: const ValueKey('artist-attribution'), style: context.type.caption),
          ),
        Padding(
          padding: insets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: local ? l10n.artistTracks : l10n.artistTopTracks,
                actionLabel: !_allTracks && d.topTracks.length > artistCollapsedTracks ? l10n.searchShowAll(d.topTracks.length) : null,
                onAction: () => setState(() => _allTracks = true),
              ),
              if (d.topTracks.isEmpty)
                Text(l10n.artistNoTracks, style: context.type.bodySmall)
              else ...[
                TrackListNotices(tracks: d.topTracks, padding: const EdgeInsets.only(bottom: 8)),
                for (var i = 0; i < shown.length; i++)
                  TrackTile(
                    key: ValueKey('top-${shown[i].id}'),
                    track: shown[i],
                    index: i + 1,
                    showAlbum: true,
                    playContext: siloSafeContext(d.topTracks, i, origin: origin, originLabel: d.name),
                  ),
              ],
              const SizedBox(height: 24),
              if (d.albums.isNotEmpty)
                ShelfRow(
                  title: local ? l10n.artistAlbums : l10n.artistReleases,
                  itemWidth: w,
                  itemCount: d.albums.length,
                  itemBuilder: (context, i) {
                    final a = d.albums[i];
                    return MediaCard(
                      key: ValueKey('artist-album-${a.albumId}'),
                      width: w,
                      title: a.title,
                      subtitle: a.year?.toString() ?? (a.trackCount == null ? null : l10n.pagesTrackCount(a.trackCount!)),
                      artworkUrl: a.artworkUrl,
                      onTap: () => context.go(AppRoutes.album(a.sourceId, a.albumId)),
                    );
                  },
                ),
              if (d.related.isNotEmpty) ...[
                const SizedBox(height: 16),
                ShelfRow(
                  title: l10n.artistRelated,
                  itemWidth: w,
                  itemCount: d.related.length,
                  itemBuilder: (context, i) {
                    final a = d.related[i];
                    return MediaCard(
                      key: ValueKey('related-${a.id}'),
                      width: w,
                      circle: true,
                      title: a.name,
                      subtitle: sourceDisplayName(ref, a.sourceId),
                      artworkUrl: a.avatarUrl,
                      placeholderIcon: Icons.person_rounded,
                      onTap: () => context.go(AppRoutes.artist(a.sourceId, a.sourceArtistId)),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
