import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/catalog.dart';
import '../actions/routes.dart';
import '../design/context_ext.dart';
import '../widgets/artwork/artwork_image.dart';
import '../widgets/brand/fermata_mark.dart';
import '../widgets/glass/glass_surface.dart';
import '../widgets/playlists/playlist_providers.dart';
import 'command_palette.dart';
import 'destinations.dart';

/// Expanded-layout sidebar (248 px): logo, primary destinations, library
/// destinations, the user's playlists and Settings.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key, required this.location});

  static const width = 248.0;

  final Uri location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final path = location.path;
    final active = NavDestination.matching(path);
    final playlists = ref.watch(userPlaylistsProvider);

    Widget item(NavDestination d) => SidebarItem(
          icon: d.icon,
          label: d.label(l10n),
          selected: active == d,
          onTap: () => context.go(d.path),
        );

    return SizedBox(
      width: width,
      child: GlassSurface(
        edges: GlassEdges.rightOnly,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
              child: Row(
                children: [
                  const Expanded(child: Align(alignment: Alignment.centerLeft, child: FermataLogo(markSize: 26))),
                  IconButton(
                    tooltip: l10n.shellCommandPalette,
                    icon: const Icon(Icons.keyboard_command_key_rounded, size: 20),
                    onPressed: () => showCommandPalette(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList.list(children: [
                      for (final d in NavDestination.sidebarPrimary) item(d),
                      const SizedBox(height: 12),
                      Divider(color: c.outlineSubtle, indent: 8, endIndent: 8),
                      const SizedBox(height: 12),
                      for (final d in NavDestination.sidebarLibrary) item(d),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                        child: Text(l10n.shellYourPlaylists.toUpperCase(), style: context.type.caption.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: playlists.when(
                      loading: () => const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                      data: (items) => items.isEmpty
                          ? SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: Text(l10n.shellNoPlaylists, style: context.type.bodySmall.copyWith(color: c.textTertiary)),
                              ),
                            )
                          : SliverList.builder(
                              itemCount: items.length,
                              itemBuilder: (context, i) => _PlaylistItem(
                                playlist: items[i],
                                selected: path == AppRoutes.playlist(items[i].id),
                              ),
                            ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: item(NavDestination.settings),
            ),
          ],
        ),
      ),
    );
  }
}

/// One sidebar row.
class SidebarItem extends StatelessWidget {
  const SidebarItem({super.key, required this.icon, required this.label, required this.selected, required this.onTap, this.leading});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Replaces the icon (e.g. playlist artwork).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: context.radii.smAll,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? c.accent.withValues(alpha: 0.12) : null,
                borderRadius: context.radii.smAll,
              ),
              child: Row(
                children: [
                  leading ?? Icon(icon, size: 20, color: selected ? c.accentText : c.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.body.copyWith(
                        color: selected ? c.textPrimary : c.textSecondary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistItem extends StatelessWidget {
  const _PlaylistItem({required this.playlist, required this.selected});

  final Playlist playlist;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SidebarItem(
      icon: Icons.queue_music_rounded,
      label: playlist.name,
      selected: selected,
      leading: ArtworkImage(uri: playlist.artworkUrl, size: 24, borderRadius: context.radii.xsAll),
      onTap: () => context.go(AppRoutes.playlist(playlist.id)),
    );
  }
}
