import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/track.dart';
import '../../actions/routes.dart';
import '../../actions/track_actions.dart';
import '../../design/context_ext.dart';
import '../../widgets/artwork/artwork_image.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/tracks/track_menu.dart';
import '../library/shared/track_helpers.dart';
import 'search_results.dart';

/// The top search result (track, artist, album or playlist) as a large
/// card with a primary action.
class TopResultCard extends ConsumerWidget {
  const TopResultCard({super.key, required this.item, required this.query});

  final Object item;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final (String title, String subtitle, Uri? art, bool circle, String kind, String sourceId) = switch (item) {
      Track t => (t.title, t.artistLine, t.artworkUrl, false, l10n.searchKindTrack, t.sourceId),
      Artist a => (a.name, '', a.avatarUrl, true, l10n.searchKindArtist, a.sourceId),
      Album a => (a.title, a.artists.map((x) => x.name).join(', '), a.artworkUrl, false, l10n.searchKindAlbum, a.sourceId),
      Playlist p => (p.name, p.ownerName ?? '', p.artworkUrl, false, l10n.searchKindPlaylist, p.sourceId ?? ''),
      _ => ('', '', null, false, '', ''),
    };

    void open() {
      switch (item) {
        case Track t:
          if (isExternalTrack(t)) {
            TrackActions(context, ref).openExternally(t);
          } else {
            playCollection(context, ref, [t], origin: 'search');
          }
        case Artist a:
          context.go(AppRoutes.artist(a.sourceId, a.sourceArtistId));
        case Album a:
          context.go(AppRoutes.album(a.sourceId, a.sourceAlbumId));
        case Playlist p:
          context.go(AppRoutes.playlist(remotePlaylistId(p)));
      }
    }

    final track = item is Track ? item as Track : null;
    final playable = track == null || isPlayableInApp(track);
    final tappable = track == null || isPlayableInApp(track) || isExternalTrack(track);
    return Semantics(
      button: true,
      label: '$kind: $title',
      child: Material(
        color: c.surface,
        borderRadius: context.radii.mdAll,
        child: InkWell(
          key: const ValueKey('top-result'),
          borderRadius: context.radii.mdAll,
          onTap: tappable ? open : null,
          onSecondaryTapUp: track == null ? null : (d) => showTrackMenu(context, ref, track, position: d.globalPosition),
          onLongPress: track == null ? null : () => showTrackMenu(context, ref, track),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 88,
                  child: ArtworkImage(uri: art, size: 88, circle: circle, borderRadius: circle ? null : context.radii.smAll),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.type.title),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.bodySmall),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Text(kind, style: context.type.caption.copyWith(color: c.textSecondary)),
                          if (sourceId.isNotEmpty) SourceChip(sourceId: sourceId, dense: true),
                          if (track != null && AvailabilityBadge.isNotable(AvailabilityBadge.primaryKind(track)))
                            AvailabilityBadge.forTrack(track, dense: true),
                        ],
                      ),
                    ],
                  ),
                ),
                if (track != null && playable)
                  IconButton.filled(
                    tooltip: l10n.playerPlay,
                    style: IconButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent),
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: open,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
