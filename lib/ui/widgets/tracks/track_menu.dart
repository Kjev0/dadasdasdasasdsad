import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/download.dart';
import '../../../core/models/track.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../actions/routes.dart';
import '../../actions/track_actions.dart';
import '../../design/context_ext.dart';
import '../chips/badges.dart';

/// Actions offered for a single track (context menu / long-press sheet).
enum TrackMenuAction {
  play,
  playNext,
  addToQueue,
  addToPlaylist,
  like,
  unlike,
  download,
  removeDownload,
  goToArtist,
  goToAlbum,
  openExternal,
  copyLink,
}

/// One resolved menu entry.
class TrackMenuEntry {
  const TrackMenuEntry(this.action, this.label, this.icon);

  final TrackMenuAction action;
  final String label;
  final IconData icon;
}

/// Context for "Play" from a list: the list's tracks + this track's index.
class TrackPlayContext {
  const TrackPlayContext({required this.tracks, required this.index, this.origin, this.originLabel});

  final List<Track> tracks;
  final int index;
  final String? origin;
  final String? originLabel;
}

/// Builds the entries valid for [track] right now. Download entries appear
/// only when the provider policy allows downloads and the download manager
/// says the track is eligible (or already downloaded).
Future<List<TrackMenuEntry>> buildTrackMenuEntries(BuildContext context, WidgetRef ref, Track track) async {
  final actions = TrackActions(context, ref);
  final l10n = AppLocalizations.of(context);
  final favorites = ref.read(favoriteIdsProvider).value ?? const <String>{};
  final eligibility = await actions.eligibility(track);
  final downloaded = eligibility?.kind == DownloadEligibilityKind.alreadyDownloaded ||
      (TrackActions.policyAllowsDownload(track) && ref.read(downloadManagerProvider).isDownloaded(track.id));
  final external = actions.externalUri(track);
  final share = actions.shareUri(track);
  final playable = track.availability.isPlayableInApp || track.availability.playback == PlaybackRights.unknown;
  final provider = sourceDisplayName(ref, track.sourceId);

  return [
    if (playable) ...[
      TrackMenuEntry(TrackMenuAction.play, l10n.shellMenuPlay, Icons.play_arrow_rounded),
      TrackMenuEntry(TrackMenuAction.playNext, l10n.shellMenuPlayNext, Icons.playlist_play_rounded),
      TrackMenuEntry(TrackMenuAction.addToQueue, l10n.shellMenuAddToQueue, Icons.queue_music_rounded),
    ],
    TrackMenuEntry(TrackMenuAction.addToPlaylist, l10n.shellMenuAddToPlaylist, Icons.playlist_add_rounded),
    if (favorites.contains(track.id))
      TrackMenuEntry(TrackMenuAction.unlike, l10n.shellMenuUnlike, Icons.favorite_rounded)
    else
      TrackMenuEntry(TrackMenuAction.like, l10n.shellMenuLike, Icons.favorite_border_rounded),
    if (downloaded)
      TrackMenuEntry(TrackMenuAction.removeDownload, l10n.shellMenuRemoveDownload, Icons.delete_outline_rounded)
    else if (eligibility?.canDownload ?? false)
      TrackMenuEntry(TrackMenuAction.download, l10n.shellMenuDownload, Icons.download_rounded),
    if (AppRoutes.artistForTrack(track) != null)
      TrackMenuEntry(TrackMenuAction.goToArtist, l10n.shellMenuGoToArtist, Icons.person_rounded),
    if (AppRoutes.albumForTrack(track) != null)
      TrackMenuEntry(TrackMenuAction.goToAlbum, l10n.shellMenuGoToAlbum, Icons.album_rounded),
    if (external != null) TrackMenuEntry(TrackMenuAction.openExternal, l10n.shellMenuOpenOn(provider), Icons.open_in_new_rounded),
    if (share != null) TrackMenuEntry(TrackMenuAction.copyLink, l10n.shellMenuCopyLink, Icons.link_rounded),
  ];
}

/// Runs [action] for [track] with the tile's [context].
Future<void> runTrackMenuAction(
  BuildContext context,
  WidgetRef ref,
  Track track,
  TrackMenuAction action, {
  TrackPlayContext? playContext,
}) async {
  final a = TrackActions(context, ref);
  final origin = playContext?.origin;
  switch (action) {
    case TrackMenuAction.play:
      if (playContext != null) {
        await a.play(playContext.tracks, startIndex: playContext.index, origin: origin, originLabel: playContext.originLabel);
      } else {
        await a.play([track], origin: origin);
      }
    case TrackMenuAction.playNext:
      await a.playNext([track], origin: origin);
    case TrackMenuAction.addToQueue:
      await a.addToQueue([track], origin: origin);
    case TrackMenuAction.addToPlaylist:
      await a.addToPlaylist([track]);
    case TrackMenuAction.like:
      await a.setFavorite(track, true);
    case TrackMenuAction.unlike:
      await a.setFavorite(track, false);
    case TrackMenuAction.download:
      await a.download(track);
    case TrackMenuAction.removeDownload:
      await a.removeDownload(track);
    case TrackMenuAction.goToArtist:
      a.goToArtist(track);
    case TrackMenuAction.goToAlbum:
      a.goToAlbum(track);
    case TrackMenuAction.openExternal:
      await a.openExternally(track);
    case TrackMenuAction.copyLink:
      await a.copyLink(track);
  }
}

/// Shows the track menu: a popup at [position] (right-click / "more"
/// button) or, without a position, a bottom sheet (long-press).
Future<void> showTrackMenu(
  BuildContext context,
  WidgetRef ref,
  Track track, {
  Offset? position,
  TrackPlayContext? playContext,
}) async {
  final entries = await buildTrackMenuEntries(context, ref, track);
  if (!context.mounted || entries.isEmpty) return;
  TrackMenuAction? chosen;
  if (position != null) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final size = overlay?.size ?? MediaQuery.sizeOf(context);
    chosen = await showMenu<TrackMenuAction>(
      context: context,
      position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & size),
      items: [
        for (final e in entries)
          PopupMenuItem(
            value: e.action,
            height: 40,
            child: Row(
              children: [
                Icon(e.icon, size: 20, color: context.colors.textSecondary),
                const SizedBox(width: 12),
                Flexible(child: Text(e.label, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
    );
  } else {
    chosen = await showModalBottomSheet<TrackMenuAction>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => _TrackMenuSheet(track: track, entries: entries),
    );
  }
  if (chosen == null || !context.mounted) return;
  await runTrackMenuAction(context, ref, track, chosen, playContext: playContext);
}

class _TrackMenuSheet extends StatelessWidget {
  const _TrackMenuSheet({required this.track, required this.entries});

  final Track track;
  final List<TrackMenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.title, style: context.type.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (track.artistLine.isNotEmpty)
                  Text(track.artistLine, style: context.type.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Divider(color: c.outlineSubtle),
          for (final e in entries)
            ListTile(
              leading: Icon(e.icon),
              title: Text(e.label),
              onTap: () => Navigator.of(context).pop(e.action),
            ),
        ],
      ),
    );
  }
}
