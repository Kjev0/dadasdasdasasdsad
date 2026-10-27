import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../../app/providers.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/library.dart';
import '../../../core/models/track.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/dialogs/dialogs.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/feedback/toast.dart';
import '../library/shared/page_services.dart';
import '../library/shared/track_helpers.dart';
import 'playlist_providers.dart';

final _log = Logger('ui.pages.playlists');

/// Playlist operations shared by the Playlists page and the detail page.
/// Every action shows a localized toast on success or failure.
class PlaylistActions {
  PlaylistActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  void _toast(String message, {IconData? icon, bool error = false}) {
    if (context.mounted) showFermataToast(context, message, icon: icon, isError: error);
  }

  void _fail(Object e, [StackTrace? st]) {
    _log.warning('Playlist action failed', e, st);
    if (!context.mounted) return;
    _toast(errorMessageFor(context.l10n, e) ?? context.l10n.errorGeneric, error: true);
  }

  /// "New playlist" (name + description). Returns the new playlist.
  Future<Playlist?> create() async {
    final l10n = context.l10n;
    final result = await PlaylistDetailsDialog.show(context, title: l10n.shellNewPlaylist, confirmLabel: l10n.shellCreate);
    if (result == null) return null;
    try {
      final playlist = await ref.read(playlistRepositoryProvider).createPlaylist(result.$1, description: result.$2);
      _toast(l10n.playlistsCreated(playlist.name), icon: Icons.playlist_add_check_rounded);
      return playlist;
    } catch (e, st) {
      _fail(e, st);
      return null;
    }
  }

  /// Edit name and description.
  Future<void> editDetails(Playlist playlist) async {
    final l10n = context.l10n;
    final result = await PlaylistDetailsDialog.show(
      context,
      title: l10n.playlistEditDetails,
      confirmLabel: l10n.actionSave,
      name: playlist.name,
      description: playlist.description,
    );
    if (result == null) return;
    try {
      await ref.read(playlistRepositoryProvider).updatePlaylist(
            playlist.copyWith(name: result.$1, description: result.$2 ?? '', updatedAt: DateTime.now()),
          );
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Delete after confirmation. Returns true when deleted.
  Future<bool> delete(Playlist playlist) async {
    final l10n = context.l10n;
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.playlistDeleteTitle(playlist.name),
      message: l10n.playlistDeleteMessage,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!ok) return false;
    try {
      await ref.read(playlistRepositoryProvider).deletePlaylist(playlist.id);
      _toast(l10n.playlistDeleted(playlist.name), icon: Icons.delete_outline_rounded);
      return true;
    } catch (e, st) {
      _fail(e, st);
      return false;
    }
  }

  /// Pick an image, copy it into app storage and use it as artwork.
  Future<void> changeArtwork(Playlist playlist) async {
    final l10n = context.l10n;
    final path = await ref.read(pageFilePickerProvider).pickImage(title: l10n.playlistChangeArtwork);
    if (path == null) return;
    try {
      final uri = await ref.read(playlistArtworkStoreProvider).store(playlist.id, path);
      await ref.read(playlistRepositoryProvider).updatePlaylist(playlist.copyWith(artworkUrl: uri, updatedAt: DateTime.now()));
      _toast(l10n.playlistArtworkUpdated, icon: Icons.image_rounded);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Export as extended M3U8 (local files only; streams are skipped).
  Future<void> exportM3u(Playlist playlist) async {
    final l10n = context.l10n;
    try {
      final location = await ref.read(pageFilePickerProvider).exportFile(
            fileName: '${safeFileName(playlist.name)}.m3u8',
            title: l10n.playlistExportM3u,
            write: (path) => ref.read(localLibraryProvider).exportM3u(playlist.id, path),
          );
      if (location != null) _toast(l10n.playlistExported(location), icon: Icons.ios_share_rounded);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Import an M3U/M3U8 file as a new playlist.
  Future<Playlist?> importM3u() async {
    final l10n = context.l10n;
    final path = await ref.read(pageFilePickerProvider).pickPlaylistFile(title: l10n.playlistsImportM3u);
    if (path == null) return null;
    try {
      final tracks = await ref.read(localLibraryProvider).importM3u(path);
      if (tracks.isEmpty) {
        _toast(l10n.playlistsImportM3uEmpty, error: true);
        return null;
      }
      final repo = ref.read(playlistRepositoryProvider);
      final playlist = await repo.createPlaylist(p.basenameWithoutExtension(path));
      await repo.addTracks(playlist.id, [for (final t in tracks) t.id]);
      _toast(l10n.playlistsImportedM3u(tracks.length, playlist.name), icon: Icons.playlist_add_check_rounded);
      return playlist;
    } catch (e, st) {
      _fail(e, st);
      return null;
    }
  }

  /// Auto-download toggle. Turning it on explains that only permitted
  /// sources are downloaded automatically (currently none of the streaming
  /// providers).
  Future<void> setAutoDownload(Playlist playlist, bool value) async {
    final l10n = context.l10n;
    if (value) {
      final ok = await ConfirmDialog.show(
        context,
        title: l10n.playlistAutoDownloadTitle,
        message: l10n.playlistAutoDownloadExplain,
        confirmLabel: l10n.playlistAutoDownloadConfirm,
      );
      if (!ok) return;
    }
    try {
      await ref.read(playlistRepositoryProvider).updatePlaylist(playlist.copyWith(autoDownload: value));
      if (value) await ref.read(downloadManagerProvider).syncAutoDownloads();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Remove duplicate entries (also linked copies of the same track).
  Future<void> deduplicate(Playlist playlist) async {
    final l10n = context.l10n;
    try {
      final removed = await ref.read(playlistRepositoryProvider).deduplicate(playlist.id);
      _toast(removed == 0 ? l10n.playlistNoDuplicates : l10n.playlistDuplicatesRemoved(removed), icon: Icons.cleaning_services_rounded);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Quick-play from a card.
  Future<void> play(Playlist playlist, {bool shuffle = false}) async {
    try {
      // Read the repositories directly: autoDispose providers read without a
      // listener could be disposed before they resolve.
      final tracks = await ref.read(playlistRepositoryProvider).playlistTracks(playlist.id);
      final linkRepo = ref.read(trackLinkRepositoryProvider);
      final links = <String, List<(Track, TrackLink)>>{};
      for (final t in {for (final t in tracks) if (!isPlayableInApp(t)) t}) {
        final linked = await linkRepo.linkedTracks(t.id);
        if (linked.isNotEmpty) links[t.id] = linked;
      }
      if (!context.mounted) return;
      await playCollection(
        context,
        ref,
        tracks,
        shuffle: shuffle,
        origin: 'playlist:${playlist.id}',
        originLabel: playlist.name,
        canPlay: (t) => playableOrLinked(t, links),
      );
    } catch (e, st) {
      _fail(e, st);
    }
  }

  void open(Playlist playlist) => context.go(AppRoutes.playlist(playlist.id));
}

/// Name + description dialog. Returns `(name, description)`.
class PlaylistDetailsDialog extends StatefulWidget {
  const PlaylistDetailsDialog({super.key, required this.title, required this.confirmLabel, this.name, this.description});

  final String title;
  final String confirmLabel;
  final String? name;
  final String? description;

  static Future<(String, String?)?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? name,
    String? description,
  }) =>
      showDialog<(String, String?)>(
        context: context,
        builder: (_) => PlaylistDetailsDialog(title: title, confirmLabel: confirmLabel, name: name, description: description),
      );

  @override
  State<PlaylistDetailsDialog> createState() => _PlaylistDetailsDialogState();
}

class _PlaylistDetailsDialogState extends State<PlaylistDetailsDialog> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _description = TextEditingController(text: widget.description ?? '');

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final d = _description.text.trim();
    Navigator.of(context).pop((name, d.isEmpty ? null : d));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('playlist-name'),
              controller: _name,
              autofocus: true,
              maxLength: 200,
              decoration: InputDecoration(labelText: l10n.shellPlaylistNameHint, counterText: ''),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('playlist-description'),
              controller: _description,
              maxLines: 3,
              minLines: 1,
              maxLength: 1000,
              decoration: InputDecoration(labelText: l10n.playlistDescription, counterText: ''),
            ),
          ],
        ),
      ),
      actions: [
        FermataButton(label: l10n.actionCancel, variant: FermataButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (context, v, _) => FermataButton(label: widget.confirmLabel, onPressed: v.text.trim().isEmpty ? null : _submit),
        ),
      ],
    );
  }
}
