import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/models/catalog.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/artwork/artwork_image.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/controls/segmented_tabs.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/feedback/toast.dart';
import '../../widgets/media/media_card.dart';
import '../../widgets/playlists/playlist_providers.dart';
import '../library/collections_tabs.dart';
import '../library/shared/page_layout.dart';
import 'playlist_actions.dart';
import 'playlist_header.dart';
import 'playlist_providers.dart';
import 'smart_rule_editor.dart';

/// Which playlists the page lists.
enum PlaylistFilter { all, local, smart, imported }

/// Playlists: grid or list of library, smart and imported playlists;
/// create (plain or smart), import (from a service or M3U), and per
/// playlist rename / artwork / export / auto-download / dedupe / delete.
class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key});

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  PlaylistFilter _filter = PlaylistFilter.all;
  bool _grid = true;

  Future<void> _newSmart() async {
    final draft = await SmartRuleEditor.show(context);
    if (draft == null || !mounted) return;
    try {
      final p = await ref.read(playlistRepositoryProvider).createSmartPlaylist(draft.name, draft.rules);
      if (mounted) showFermataToast(context, context.l10n.playlistsCreated(p.name), icon: Icons.playlist_add_check_rounded);
    } catch (e) {
      if (mounted) showFermataToast(context, context.l10n.errorGeneric, isError: true);
    }
  }

  bool _matches(Playlist p) => switch (_filter) {
        PlaylistFilter.all => true,
        PlaylistFilter.local => categoryOf(p) == PlaylistCategory.local,
        PlaylistFilter.smart => categoryOf(p) == PlaylistCategory.smart,
        PlaylistFilter.imported => categoryOf(p) == PlaylistCategory.imported,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final playlists = ref.watch(userPlaylistsProvider);
    final actions = PlaylistActions(context, ref);
    final insets = pageInsets(context);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        PageHeader(
          title: l10n.navPlaylists,
          actions: [
            FermataButton(label: l10n.shellNewPlaylist, icon: Icons.add_rounded, onPressed: actions.create),
            FermataButton(
              label: l10n.playlistsNewSmart,
              icon: Icons.auto_awesome_rounded,
              variant: FermataButtonVariant.secondary,
              onPressed: _newSmart,
            ),
            PopupMenuButton<String>(
              key: const ValueKey('playlists-import-menu'),
              tooltip: l10n.playlistsImport,
              icon: const Icon(Icons.download_for_offline_rounded),
              onSelected: (v) => v == 'service' ? context.go(AppRoutes.import) : actions.importM3u(),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'service', child: menuRow(Icons.sync_alt_rounded, l10n.playlistsImportFromService)),
                PopupMenuItem(value: 'm3u', child: menuRow(Icons.file_open_rounded, l10n.playlistsImportM3u)),
              ],
            ),
          ],
        ),
        Padding(
          padding: insets.copyWith(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedTabs<PlaylistFilter>(
                    selected: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                    tabs: [
                      SegmentedTab(PlaylistFilter.all, l10n.searchFilterAll),
                      SegmentedTab(PlaylistFilter.local, l10n.playlistsFilterYours),
                      SegmentedTab(PlaylistFilter.smart, l10n.playlistsFilterSmart),
                      SegmentedTab(PlaylistFilter.imported, l10n.playlistsFilterImported),
                    ],
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('playlists-view-toggle'),
                tooltip: _grid ? l10n.playlistsShowList : l10n.playlistsShowGrid,
                icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
                onPressed: () => setState(() => _grid = !_grid),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      body: playlists.when(
        loading: () => ListView(children: [header, const SkeletonGrid()]),
        error: (e, _) => ListView(children: [header, ErrorState(error: e, onRetry: () => ref.invalidate(userPlaylistsProvider))]),
        data: (all) {
          final list = [for (final p in all) if (_matches(p)) p];
          if (list.isEmpty) {
            return ListView(
              children: [
                header,
                all.isEmpty
                    ? EmptyState(
                        icon: Icons.queue_music_rounded,
                        title: l10n.shellNoPlaylists,
                        message: l10n.playlistsEmptyMessage,
                        actionLabel: l10n.shellNewPlaylist,
                        onAction: actions.create,
                        secondaryLabel: l10n.playlistsImportFromService,
                        onSecondary: () => context.go(AppRoutes.import),
                      )
                    : EmptyState(icon: Icons.filter_alt_off_rounded, title: l10n.pagesNoMatches, compact: true),
              ],
            );
          }
          if (_grid) {
            return CardGrid(
              header: header,
              padding: insets.copyWith(bottom: 24),
              itemCount: list.length,
              itemBuilder: (context, i, w) => _PlaylistCard(playlist: list[i], width: w),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: list.length + 1,
            itemBuilder: (context, i) => i == 0 ? header : _PlaylistRow(playlist: list[i - 1]),
          );
        },
      ),
    );
  }
}

String _subtitle(BuildContext context, WidgetRef ref, Playlist p) {
  final l10n = context.l10n;
  return [
    playlistKindLabel(context, ref, p),
    if (p.trackCount != null) l10n.pagesTrackCount(p.trackCount!),
  ].join(' · ');
}

IconData _placeholderIcon(Playlist p) => switch (categoryOf(p)) {
      PlaylistCategory.smart => Icons.auto_awesome_rounded,
      PlaylistCategory.imported => Icons.sync_alt_rounded,
      PlaylistCategory.local => Icons.queue_music_rounded,
    };

class _PlaylistCard extends ConsumerWidget {
  const _PlaylistCard({required this.playlist, required this.width});

  final Playlist playlist;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = PlaylistActions(context, ref);
    return Stack(
      children: [
        MediaCard(
          key: ValueKey('playlist-card-${playlist.id}'),
          width: width,
          title: playlist.name,
          subtitle: _subtitle(context, ref, playlist),
          artworkUrl: playlist.artworkUrl,
          placeholderIcon: _placeholderIcon(playlist),
          onTap: () => actions.open(playlist),
          onPlay: (playlist.trackCount ?? 1) > 0 ? () => actions.play(playlist) : null,
        ),
        Positioned(top: 4, right: 4, child: PlaylistMoreMenu(playlist: playlist)),
      ],
    );
  }
}

class _PlaylistRow extends ConsumerWidget {
  const _PlaylistRow({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = PlaylistActions(context, ref);
    final insets = pageInsets(context);
    return ListTile(
      key: ValueKey('playlist-row-${playlist.id}'),
      contentPadding: EdgeInsets.symmetric(horizontal: insets.left),
      leading: SizedBox.square(
        dimension: 48,
        child: playlist.artworkUrl == null
            ? Container(
                decoration: BoxDecoration(color: context.colors.surfaceHigh, borderRadius: context.radii.smAll),
                child: Icon(_placeholderIcon(playlist), color: context.colors.textTertiary),
              )
            : ArtworkImage(uri: playlist.artworkUrl, size: 48),
      ),
      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_subtitle(context, ref, playlist), maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => actions.open(playlist),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(tooltip: context.l10n.pagesPlay, icon: const Icon(Icons.play_arrow_rounded), onPressed: () => actions.play(playlist)),
          PlaylistMoreMenu(playlist: playlist),
        ],
      ),
    );
  }
}
