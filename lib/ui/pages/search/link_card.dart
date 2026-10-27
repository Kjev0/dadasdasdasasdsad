import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/music_source.dart';
import '../../actions/routes.dart';
import '../../actions/track_actions.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/tracks/track_tile.dart';
import '../library/shared/import_helpers.dart';
import '../library/shared/page_layout.dart';
import 'search_providers.dart';
import 'search_results.dart';
import 'share_links.dart';

/// Shown instead of search results when a provider share link is pasted:
/// open or import a playlist, play a track, open an album / artist page.
class ShareLinkCard extends ConsumerWidget {
  const ShareLinkCard({super.key, required this.link});

  final ShareLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    ref.watch(sourcesRevisionProvider);
    final source = ref.watch(sourceRegistryProvider).byId(link.sourceId);
    final provider = sourceDisplayName(ref, link.sourceId);
    final ready = source != null && source.isReady;
    final kindLabel = switch (link.kind) {
      ShareLinkKind.track => l10n.searchLinkTrack(provider),
      ShareLinkKind.playlist => l10n.searchLinkPlaylist(provider),
      ShareLinkKind.album => l10n.searchLinkAlbum(provider),
      ShareLinkKind.artist => l10n.searchLinkArtist(provider),
      ShareLinkKind.unknown => l10n.searchLinkGeneric(provider),
    };
    final openExternal = FermataButton(
      label: l10n.shellMenuOpenOn(provider),
      icon: Icons.open_in_new_rounded,
      variant: FermataButtonVariant.ghost,
      onPressed: () => TrackActions(context, ref).openLink(link.uri),
    );

    final actions = <Widget>[];
    Widget? body;
    if (ready) {
      switch (link.kind) {
        case ShareLinkKind.playlist || ShareLinkKind.unknown:
          actions.add(FermataButton(
            label: l10n.searchOpenPlaylist,
            icon: Icons.queue_music_rounded,
            onPressed: () => context.go(AppRoutes.playlist('${link.sourceId}:${link.id}')),
          ));
          if (source.supports(SourceCapability.playlistImport)) {
            actions.add(FermataButton(
              label: l10n.pagesImportAndMatch,
              icon: Icons.sync_alt_rounded,
              variant: FermataButtonVariant.secondary,
              onPressed: () => startPlaylistImport(context, ref, sourceId: link.sourceId, playlistIdOrUrl: link.id),
            ));
          }
        case ShareLinkKind.track:
          body = _SharedTrack(link: link);
        case ShareLinkKind.album:
          if (!link.idIsUrl) {
            actions.add(FermataButton(
              label: l10n.searchOpenAlbum,
              icon: Icons.album_rounded,
              onPressed: () => context.go(AppRoutes.album(link.sourceId, link.id)),
            ));
          }
        case ShareLinkKind.artist:
          if (!link.idIsUrl) {
            actions.add(FermataButton(
              label: l10n.searchOpenArtist,
              icon: Icons.person_rounded,
              onPressed: () => context.go(AppRoutes.artist(link.sourceId, link.id)),
            ));
          }
      }
    }
    actions.add(openExternal);

    return ListView(
      padding: pageInsets(context).copyWith(top: 8, bottom: 24),
      children: [
        Container(
          key: const ValueKey('share-link-card'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: context.radii.mdAll,
            border: Border.all(color: c.outlineSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link_rounded, color: c.accentText),
                  const SizedBox(width: 12),
                  Expanded(child: Text(kindLabel, style: context.type.titleSmall)),
                ],
              ),
              const SizedBox(height: 4),
              Text(link.uri.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.type.caption),
              if (!ready) ...[
                const SizedBox(height: 12),
                InlineNotice(
                  icon: Icons.link_off_rounded,
                  message: source == null ? l10n.searchSourceMissing(provider) : notReadyReason(l10n, source),
                  actionLabel: l10n.searchConnectedServices,
                  onAction: () => context.go(AppRoutes.settingsSection(SettingsSections.services)),
                ),
              ],
              if (body != null) ...[const SizedBox(height: 12), body],
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
        ),
      ],
    );
  }
}

class _SharedTrack extends ConsumerWidget {
  const _SharedTrack({required this.link});

  final ShareLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(sharedTrackProvider(link));
    return track.when(
      loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(sharedTrackProvider(link))),
      data: (t) => t == null
          ? Text(context.l10n.searchLinkNotFound, style: context.type.bodySmall)
          : TrackTile(key: ValueKey('shared-${t.id}'), track: t, showSource: true),
    );
  }
}
