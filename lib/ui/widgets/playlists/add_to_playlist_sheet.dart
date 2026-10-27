import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/catalog.dart';
import '../../design/context_ext.dart';
import '../artwork/artwork_image.dart';
import '../dialogs/dialogs.dart';
import '../dialogs/sheet.dart';
import '../feedback/states.dart';
import 'playlist_providers.dart';

/// Bottom sheet listing the user's editable playlists plus "New playlist".
/// Returns the chosen (or newly created) playlist; adding the tracks is done
/// by the caller (see `TrackActions.addToPlaylist`).
class AddToPlaylistSheet extends ConsumerWidget {
  const AddToPlaylistSheet({super.key});

  static Future<Playlist?> pick(BuildContext context) =>
      showFermataSheet<Playlist>(context, maxWidth: 560, builder: (_) => const AddToPlaylistSheet());

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final name = await TextInputDialog.show(
      context,
      title: l10n.shellNewPlaylist,
      hint: l10n.shellPlaylistNameHint,
      confirmLabel: l10n.shellCreate,
    );
    if (name == null || !context.mounted) return;
    final playlist = await ref.read(playlistRepositoryProvider).createPlaylist(name);
    if (context.mounted) Navigator.of(context).pop(playlist);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playlists = ref.watch(editablePlaylistsProvider);
    final height = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(l10n.shellAddToPlaylistTitle, style: context.type.title),
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: context.colors.surfaceHigh, borderRadius: context.radii.smAll),
              child: Icon(Icons.add_rounded, color: context.colors.accentText),
            ),
            title: Text(l10n.shellNewPlaylist),
            onTap: () => _create(context, ref),
          ),
          Flexible(
            child: playlists.when(
              loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(userPlaylistsProvider)),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.shellAddToPlaylistEmpty, textAlign: TextAlign.center, style: context.type.bodySmall),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final p = items[i];
                        return ListTile(
                          leading: ArtworkImage(uri: p.artworkUrl, size: 40),
                          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: p.trackCount == null ? null : Text(l10n.playerQueueCount(p.trackCount!)),
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
