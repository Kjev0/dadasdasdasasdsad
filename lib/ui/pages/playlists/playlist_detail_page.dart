import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/feedback/skeleton.dart';
import '../../widgets/feedback/states.dart';
import '../library/shared/page_layout.dart';
import 'local_playlist_view.dart';
import 'playlist_providers.dart';
import 'remote_playlist_view.dart';

/// A playlist: a library playlist (local / smart / imported, by id) or a
/// playlist on a provider (`<sourceId>:<id or share URL>`).
class PlaylistDetailPage extends ConsumerWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final String playlistId;

  Widget _loading() => ListView(children: const [SkeletonHeader(), SkeletonTrackList()]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sourceIds = {for (final s in ref.watch(sourceRegistryProvider).all) s.id};
    final Widget body;
    if (isRemotePlaylistId(playlistId, sourceIds)) {
      final remote = ref.watch(remotePlaylistProvider(playlistId));
      body = remote.when(
        loading: _loading,
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(remotePlaylistProvider(playlistId))),
        data: (d) => RemotePlaylistView(key: ValueKey('remote-$playlistId'), id: playlistId, detail: d),
      );
    } else {
      final local = ref.watch(localPlaylistProvider(playlistId));
      body = local.when(
        loading: _loading,
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(localPlaylistProvider(playlistId))),
        data: (d) => d == null
            ? EmptyState(
                icon: Icons.playlist_remove_rounded,
                title: l10n.playlistNotFound,
                actionLabel: l10n.navPlaylists,
                onAction: () => context.go(AppRoutes.playlists),
              )
            : LocalPlaylistView(key: ValueKey('local-$playlistId'), data: d),
      );
    }
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: pageInsets(context).copyWith(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: BackHeaderButton(
                onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.playlists),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
