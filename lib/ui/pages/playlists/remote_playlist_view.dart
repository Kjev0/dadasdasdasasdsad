import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/music_source.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/track.dart';
import '../../actions/routes.dart';
import '../../actions/track_actions.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/feedback/toast.dart';
import '../../widgets/tracks/track_list_view.dart';
import '../library/shared/import_helpers.dart';
import '../library/shared/labels.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/provider_notices.dart';
import '../library/shared/track_actions_row.dart';
import '../library/shared/track_helpers.dart';
import 'playlist_providers.dart';

/// Pages fetched at most when saving a remote playlist to the library.
const remotePlaylistMaxPages = 100;

/// A playlist on a provider (`<sourceId>:<id or url>`): tracks (paged),
/// play / shuffle, "Save to library" (a copy with the original tracks) and
/// "Import & match" (find each track on your other services).
class RemotePlaylistView extends ConsumerStatefulWidget {
  const RemotePlaylistView({super.key, required this.id, required this.detail});

  final String id;
  final PlaylistDetail detail;

  @override
  ConsumerState<RemotePlaylistView> createState() => _RemotePlaylistViewState();
}

class _RemotePlaylistViewState extends ConsumerState<RemotePlaylistView> {
  final _more = <Track>[];
  String? _cursor;
  bool _loadingMore = false;
  bool _saving = false;
  PlaylistDetail? _for;

  (String, String) get _ids => splitRemotePlaylistId(widget.id);

  void _syncWith(PlaylistDetail d) {
    if (identical(_for, d)) return;
    _for = d;
    _more.clear();
    _cursor = d.tracks.nextCursor;
  }

  List<Track> get _tracks => [...widget.detail.tracks.items, ..._more];

  MusicSource? get _source => ref.read(sourceRegistryProvider).byId(_ids.$1);

  Future<void> _loadMore() async {
    final source = _source;
    if (source == null || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final next = await source.getPlaylist(_ids.$2, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _more.addAll(next.tracks.items);
        _cursor = next.tracks.nextCursor;
      });
    } catch (e) {
      if (mounted) showFermataToast(context, errorMessageFor(context.l10n, e) ?? context.l10n.errorGeneric, isError: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Copies the playlist into the library with all of its tracks.
  Future<void> _save() async {
    final l10n = context.l10n;
    final source = _source;
    if (source == null) return;
    setState(() => _saving = true);
    try {
      final all = _tracks;
      var cursor = _cursor;
      for (var page = 0; cursor != null && page < remotePlaylistMaxPages; page++) {
        final next = await source.getPlaylist(_ids.$2, cursor: cursor);
        all.addAll(next.tracks.items);
        cursor = next.tracks.nextCursor;
      }
      final p = widget.detail.playlist;
      final repo = ref.read(playlistRepositoryProvider);
      await ref.read(trackRepositoryProvider).upsertTracks(all);
      final saved = await repo.createPlaylist(
        p.name,
        description: p.description,
        sourceId: _ids.$1,
        sourcePlaylistId: p.sourcePlaylistId ?? _ids.$2,
        artworkUrl: p.artworkUrl,
      );
      await repo.addTracks(saved.id, [for (final t in all) t.id]);
      if (!mounted) return;
      showFermataToast(context, l10n.playlistSavedToLibrary(p.name), icon: Icons.library_add_check_rounded);
      context.go(AppRoutes.playlist(saved.id));
    } catch (e) {
      if (mounted) showFermataToast(context, errorMessageFor(l10n, e) ?? l10n.errorGeneric, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    _syncWith(widget.detail);
    final p = widget.detail.playlist;
    final source = ref.watch(sourceRegistryProvider).byId(_ids.$1);
    final provider = sourceDisplayName(ref, _ids.$1);
    final tracks = _tracks;
    final origin = 'playlist:${widget.id}';
    final streamable = source != null &&
        (source.supports(SourceCapability.stream) || source.supports(SourceCapability.previewOnly));
    final total = widget.detail.tracks.total ?? p.trackCount;
    final meta = [
      if (total != null) l10n.pagesTrackCount(total) else trackStats(l10n, tracks),
      if (p.ownerName != null) l10n.playlistBy(p.ownerName!),
    ].join(' · ');

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CollectionHeader(
          eyebrow: l10n.playlistOnProvider(provider),
          title: p.name,
          description: p.description,
          meta: meta,
          artwork: (size) => ArtworkMosaic(
            uris: p.artworkUrl != null ? [p.artworkUrl!] : ArtworkMosaic.pick(tracks.map((t) => t.artworkUrl)),
            size: size,
          ),
          actions: [
            PlayShuffleButtons(
              enabled: tracks.any(isPlayableInApp),
              onPlay: () => playCollection(context, ref, tracks, origin: origin, originLabel: p.name),
              onShuffle: () => playCollection(context, ref, tracks, shuffle: true, origin: origin, originLabel: p.name),
            ),
            if (streamable)
              FermataButton(
                key: const ValueKey('save-to-library'),
                label: l10n.playlistSaveToLibrary,
                icon: Icons.library_add_rounded,
                variant: FermataButtonVariant.secondary,
                busy: _saving,
                onPressed: _save,
              ),
            if (source?.supports(SourceCapability.playlistImport) ?? false)
              FermataButton(
                key: const ValueKey('import-and-match'),
                label: l10n.pagesImportAndMatch,
                icon: Icons.sync_alt_rounded,
                variant: FermataButtonVariant.secondary,
                onPressed: () => startPlaylistImport(context, ref, sourceId: _ids.$1, playlistIdOrUrl: _ids.$2),
              ),
            CollectionDownloadButton(tracks: tracks, origin: origin),
            if (p.permalink != null)
              FermataButton(
                label: l10n.pagesOpenOnProvider(provider),
                icon: Icons.open_in_new_rounded,
                variant: FermataButtonVariant.ghost,
                onPressed: () => TrackActions(context, ref).openLink(p.permalink!),
              ),
          ],
        ),
        Padding(
          padding: pageInsets(context).copyWith(bottom: 8),
          child: Text(l10n.pagesDataFrom(provider), style: context.type.caption),
        ),
        TrackListNotices(tracks: tracks, padding: pageInsets(context).copyWith(bottom: 8)),
      ],
    );

    return TrackListView(
      tracks: tracks,
      origin: origin,
      originLabel: p.name,
      header: header,
      showAlbum: true,
      padding: pageInsets(context),
      footer: _cursor == null
          ? const SizedBox(height: 24)
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FermataButton(
                  label: l10n.pagesLoadMore,
                  variant: FermataButtonVariant.secondary,
                  busy: _loadingMore,
                  onPressed: _loadMore,
                ),
              ),
            ),
    );
  }
}
