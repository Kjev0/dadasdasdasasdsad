import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/library.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/feedback/toast.dart';
import '../library/shared/labels.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/provider_notices.dart';
import '../library/shared/track_actions_row.dart';
import 'playlist_actions.dart';
import 'playlist_providers.dart';
import 'smart_rule_editor.dart';

/// Localized category of a playlist ("Playlist", "Smart playlist",
/// "Imported from Spotify").
String playlistKindLabel(BuildContext context, WidgetRef ref, Playlist p) {
  final l10n = context.l10n;
  return switch (categoryOf(p)) {
    PlaylistCategory.smart => l10n.playlistKindSmart,
    PlaylistCategory.imported => l10n.playlistKindImported(sourceDisplayName(ref, p.sourceId!)),
    PlaylistCategory.local => l10n.playlistKindLocal,
  };
}

/// Parsed smart rules of [p] (null for other playlists / invalid JSON).
SmartPlaylistRules? smartRulesOf(Playlist p) {
  final raw = p.smartRulesJson;
  if (raw == null || raw.isEmpty) return null;
  try {
    return SmartPlaylistRules.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  } catch (_) {
    return null;
  }
}

/// Opens the rule editor for an existing smart playlist and saves it.
Future<void> editSmartRules(BuildContext context, WidgetRef ref, Playlist p) async {
  final draft = await SmartRuleEditor.show(context, name: p.name, initial: smartRulesOf(p));
  if (draft == null) return;
  try {
    await ref.read(playlistRepositoryProvider).updatePlaylist(
          p.copyWith(name: draft.name, smartRulesJson: jsonEncode(draft.rules.toJson()), updatedAt: DateTime.now()),
        );
  } catch (e) {
    if (context.mounted) showFermataToast(context, context.l10n.errorGeneric, isError: true);
  }
}

/// Menu entries of a library playlist.
enum PlaylistMenuAction { editDetails, editRules, artwork, exportM3u, autoDownload, dedupe, delete }

/// The "more" menu for a library playlist (cards and detail header).
class PlaylistMoreMenu extends ConsumerWidget {
  const PlaylistMoreMenu({super.key, required this.playlist, this.onDeleted});

  final Playlist playlist;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final smart = playlist.kind == PlaylistKind.smart;
    return PopupMenuButton<PlaylistMenuAction>(
      key: ValueKey('playlist-menu-${playlist.id}'),
      tooltip: l10n.pagesMore,
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (a) async {
        final actions = PlaylistActions(context, ref);
        switch (a) {
          case PlaylistMenuAction.editDetails:
            await actions.editDetails(playlist);
          case PlaylistMenuAction.editRules:
            await editSmartRules(context, ref, playlist);
          case PlaylistMenuAction.artwork:
            await actions.changeArtwork(playlist);
          case PlaylistMenuAction.exportM3u:
            await actions.exportM3u(playlist);
          case PlaylistMenuAction.autoDownload:
            await actions.setAutoDownload(playlist, !playlist.autoDownload);
          case PlaylistMenuAction.dedupe:
            await actions.deduplicate(playlist);
          case PlaylistMenuAction.delete:
            if (await actions.delete(playlist)) onDeleted?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: PlaylistMenuAction.editDetails, child: menuRow(Icons.edit_rounded, l10n.playlistEditDetails)),
        if (smart) PopupMenuItem(value: PlaylistMenuAction.editRules, child: menuRow(Icons.rule_rounded, l10n.playlistEditRules)),
        PopupMenuItem(value: PlaylistMenuAction.artwork, child: menuRow(Icons.image_rounded, l10n.playlistChangeArtwork)),
        PopupMenuItem(value: PlaylistMenuAction.exportM3u, child: menuRow(Icons.ios_share_rounded, l10n.playlistExportM3u)),
        CheckedPopupMenuItem(value: PlaylistMenuAction.autoDownload, checked: playlist.autoDownload, child: Text(l10n.playlistAutoDownload)),
        if (!smart) PopupMenuItem(value: PlaylistMenuAction.dedupe, child: menuRow(Icons.cleaning_services_rounded, l10n.playlistDedupe)),
        PopupMenuItem(value: PlaylistMenuAction.delete, child: menuRow(Icons.delete_outline_rounded, l10n.actionDelete)),
      ],
    );
  }
}

/// Header of a library playlist: artwork (custom or a mosaic of its
/// tracks), kind, name, description, stats and actions.
class LocalPlaylistHeader extends ConsumerWidget {
  const LocalPlaylistHeader({super.key, required this.data, required this.onPlay, required this.onShuffle, required this.canPlay});

  final LocalPlaylistData data;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final bool canPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = data.playlist;
    final tracks = data.tracks;
    final mosaic = p.artworkUrl != null ? [p.artworkUrl!] : ArtworkMosaic.pick(tracks.map((t) => t.artworkUrl));
    final rules = smartRulesOf(p);
    final meta = [
      trackStats(l10n, tracks),
      if (rules != null) l10n.playlistRulesSummary(rules.rules.length, rules.matchAll ? l10n.smartMatchAll : l10n.smartMatchAny),
      if (p.autoDownload) l10n.playlistAutoDownloadOn,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CollectionHeader(
          eyebrow: playlistKindLabel(context, ref, p),
          title: p.name,
          description: p.description,
          meta: meta,
          artwork: (size) => ArtworkMosaic(uris: mosaic, size: size),
          actions: [
            PlayShuffleButtons(enabled: canPlay, onPlay: onPlay, onShuffle: onShuffle),
            CollectionDownloadButton(tracks: tracks, origin: 'playlist:${p.id}'),
            if (p.kind == PlaylistKind.smart)
              FermataButton(
                label: l10n.playlistEditRules,
                icon: Icons.rule_rounded,
                variant: FermataButtonVariant.secondary,
                onPressed: () => editSmartRules(context, ref, p),
              ),
            PlaylistMoreMenu(playlist: p, onDeleted: () => context.go(AppRoutes.playlists)),
          ],
        ),
        TrackListNotices(tracks: tracks, padding: pageInsets(context).copyWith(bottom: 8)),
      ],
    );
  }
}
