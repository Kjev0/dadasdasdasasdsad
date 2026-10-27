import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/discovery.dart';
import '../../../core/models/track.dart';
import '../../actions/track_actions.dart';
import '../../design/context_ext.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/feedback/toast.dart';
import '../../widgets/media/media_card.dart';
import '../../widgets/media/shelf_row.dart';
import '../../widgets/tracks/track_list_view.dart';
import '../../widgets/tracks/track_menu.dart';
import '../library/shared/labels.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/provider_notices.dart';
import '../library/shared/track_actions_row.dart';
import '../library/shared/track_helpers.dart';

/// Card width for shelves on the current layout.
double shelfCardWidth(BuildContext context) => MediaQuery.sizeOf(context).width < 600 ? 140 : 168;

/// A horizontal row of track cards (tap or quick-play plays the shelf from
/// that track; right-click / long-press opens the track menu).
class TrackShelfRow extends ConsumerWidget {
  const TrackShelfRow({
    super.key,
    required this.title,
    required this.tracks,
    this.subtitle,
    this.origin,
    this.onSeeAll,
    this.maxItems = 20,
  });

  final String title;
  final String? subtitle;
  final List<Track> tracks;
  final String? origin;
  final VoidCallback? onSeeAll;
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = shelfCardWidth(context);
    final shown = tracks.take(maxItems).toList();
    return ShelfRow(
      title: title,
      subtitle: subtitle,
      itemWidth: width,
      itemCount: shown.length,
      onSeeAll: onSeeAll,
      itemBuilder: (context, i) {
        final t = shown[i];
        void play() => playCollection(context, ref, tracks, startIndex: i, origin: origin, originLabel: title);
        void open() {
          if (isExternalTrack(t)) {
            TrackActions(context, ref).openExternally(t);
          } else if (t.availability.playback == PlaybackRights.unavailable) {
            showFermataToast(context, availabilityReasonText(context.l10n, t.availability.reason), icon: Icons.block_rounded);
          } else {
            play();
          }
        }

        return MediaCard(
          key: ValueKey('card-${t.id}'),
          width: width,
          title: t.title,
          subtitle: t.artistLine,
          artworkUrl: t.artworkUrl,
          onTap: open,
          onPlay: isPlayableInApp(t) ? play : null,
          onSecondaryTap: (pos) => showTrackMenu(context, ref, t, position: pos),
        );
      },
    );
  }
}

/// Mix-style shelves (Daily Mixes, Discover Weekly) as one row of cards;
/// tapping a card opens the mix, quick-play plays it.
class MixesRow extends ConsumerWidget {
  const MixesRow({super.key, required this.title, required this.shelves, required this.onOpen});

  final String title;
  final List<Shelf> shelves;
  final ValueChanged<Shelf> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final width = shelfCardWidth(context);
    return ShelfRow(
      title: title,
      itemWidth: width,
      itemCount: shelves.length,
      itemBuilder: (context, i) {
        final s = shelves[i];
        final name = shelfTitle(l10n, s);
        return MediaCard(
          key: ValueKey('mix-${s.id}'),
          width: width,
          title: name,
          subtitle: s.subtitle ?? l10n.pagesTrackCount(s.tracks.length),
          artworkUrl: s.artworkUrl ?? s.tracks.map((t) => t.artworkUrl).whereType<Uri>().firstOrNull,
          onTap: () => onOpen(s),
          onPlay: () => playCollection(context, ref, s.tracks, origin: 'shelf:${s.id}', originLabel: name),
        );
      },
    );
  }
}

/// Full track list of a shelf / mix with a header, play and shuffle.
class TrackCollectionView extends ConsumerWidget {
  const TrackCollectionView({
    super.key,
    required this.title,
    required this.tracks,
    required this.origin,
    this.eyebrow,
    this.subtitle,
    this.artworkUrl,
    this.onBack,
    this.emptyMessage,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Uri? artworkUrl;
  final List<Track> tracks;
  final String origin;
  final VoidCallback? onBack;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mosaic = artworkUrl != null ? [artworkUrl!] : ArtworkMosaic.pick(tracks.map((t) => t.artworkUrl));
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CollectionHeader(
          leading: onBack == null ? null : BackHeaderButton(onPressed: onBack!),
          eyebrow: eyebrow,
          title: title,
          subtitle: subtitle,
          meta: trackStats(l10n, tracks),
          artwork: (size) => ArtworkMosaic(uris: mosaic, size: size),
          actions: [
            PlayShuffleButtons(
              enabled: tracks.any(isPlayableInApp),
              onPlay: () => playCollection(context, ref, tracks, origin: origin, originLabel: title),
              onShuffle: () => playCollection(context, ref, tracks, shuffle: true, origin: origin, originLabel: title),
            ),
            CollectionDownloadButton(tracks: tracks, origin: origin),
          ],
        ),
        TrackListNotices(tracks: tracks, padding: pageInsets(context).copyWith(bottom: 8)),
        if (tracks.isEmpty && emptyMessage != null)
          Padding(
            padding: pageInsets(context).copyWith(top: 24),
            child: Text(emptyMessage!, style: context.type.bodySmall, textAlign: TextAlign.center),
          ),
      ],
    );
    return TrackListView(
      tracks: tracks,
      origin: origin,
      originLabel: title,
      header: header,
      showAlbum: true,
      padding: pageInsets(context).copyWith(bottom: 24),
    );
  }
}
