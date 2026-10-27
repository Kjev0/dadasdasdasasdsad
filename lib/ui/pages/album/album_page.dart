import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/library.dart';
import '../../../core/errors.dart';
import '../../../core/models/library.dart';
import '../../../core/models/track.dart';
import '../../../core/sources/source_ids.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/artwork/artwork_image.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/feedback/skeleton.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/tracks/track_menu.dart';
import '../../widgets/tracks/track_tile.dart';
import '../../widgets/util/async_utils.dart';
import '../library/shared/labels.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/provider_notices.dart';
import '../library/shared/revisions.dart';
import '../library/shared/track_actions_row.dart';
import '../library/shared/track_helpers.dart';

/// Pages fetched at most for one album.
const albumMaxPages = 20;

/// An album's tracks (disc / track order) and display metadata.
@immutable
class AlbumData {
  const AlbumData({required this.title, required this.tracks, this.artist, this.artistRoute, this.artworkUrl, this.year});

  final String title;
  final String? artist;
  final String? artistRoute;
  final Uri? artworkUrl;
  final int? year;
  final List<Track> tracks;

  /// Disc numbers present (more than one = grouped display).
  List<int> get discs => {for (final t in tracks) t.discNumber ?? 1}.toList()..sort();
}

/// Album page data for `(sourceId, albumId)`; `local` albums are matched by
/// title in the library.
final albumPageProvider = FutureProvider.autoDispose.family<AlbumData, (String, String)>(
  (ref, key) async {
    final (sourceId, albumId) = key;
    List<Track> tracks;
    if (sourceId == SourceIds.local) {
      watchLibrary(ref, LibraryTopic.tracks);
      tracks = await ref.watch(trackRepositoryProvider).query(TrackQuery(album: albumId, sort: TrackSortField.album, descending: false));
    } else {
      watchSources(ref);
      final source = ref.watch(sourceRegistryProvider).byId(sourceId);
      if (source == null) throw UnsupportedSourceOperation(sourceId, 'albumTracks', 'Source $sourceId is not available');
      final token = providerCancelToken(ref);
      tracks = [];
      String? cursor;
      for (var page = 0; page < albumMaxPages; page++) {
        final p = await source.albumTracks(albumId, cursor: cursor, cancel: token);
        tracks.addAll(p.items);
        cursor = p.nextCursor;
        if (cursor == null) break;
      }
    }
    tracks = sortAlbumTracks(tracks);
    final first = tracks.firstOrNull;
    final artistName = first?.albumArtist ?? first?.primaryArtist;
    return AlbumData(
      title: first?.album ?? albumId,
      artist: artistName == null || artistName.isEmpty ? null : artistName,
      artistRoute: first == null ? null : AppRoutes.artistForTrack(first),
      artworkUrl: tracks.map((t) => t.artworkUrl).whereType<Uri>().firstOrNull,
      year: tracks.map((t) => t.year).whereType<int>().firstOrNull,
      tracks: tracks,
    );
  },
  retry: noRetry,
);

/// An album: track list grouped by disc, total duration, play / shuffle
/// and "Download" for the tracks a provider lets you download.
class AlbumPage extends ConsumerWidget {
  const AlbumPage({super.key, required this.sourceId, required this.albumId});

  final String sourceId;

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (sourceId, albumId);
    final data = ref.watch(albumPageProvider(key));
    final back = BackHeaderButton(onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.home));
    return Scaffold(
      body: data.when(
        loading: () => ListView(children: const [SkeletonHeader(), SkeletonTrackList()]),
        error: (e, _) => ListView(
          children: [
            Padding(padding: pageInsets(context).copyWith(top: 8), child: Align(alignment: Alignment.centerLeft, child: back)),
            ErrorState(error: e, onRetry: () => ref.invalidate(albumPageProvider(key))),
          ],
        ),
        data: (d) => _AlbumContent(data: d, sourceId: sourceId, albumId: albumId, back: back),
      ),
    );
  }
}

class _AlbumContent extends ConsumerWidget {
  const _AlbumContent({required this.data, required this.sourceId, required this.albumId, required this.back});

  final AlbumData data;
  final String sourceId;
  final String albumId;
  final Widget back;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = data;
    final insets = pageInsets(context);
    final origin = 'album:$sourceId:$albumId';
    final discs = d.discs;
    final grouped = discs.length > 1;
    final meta = [if (d.year != null) '${d.year}', trackStats(l10n, d.tracks)].join(' · ');
    final rows = <Widget>[];
    for (final disc in discs) {
      if (grouped) {
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
          child: Row(
            children: [
              Icon(Icons.album_rounded, size: 18, color: context.colors.textSecondary),
              const SizedBox(width: 8),
              Semantics(header: true, child: Text(l10n.albumDisc(disc), style: context.type.label)),
            ],
          ),
        ));
      }
      for (var i = 0; i < d.tracks.length; i++) {
        final t = d.tracks[i];
        if ((t.discNumber ?? 1) != disc) continue;
        rows.add(TrackTile(
          key: ValueKey('album-track-${t.id}'),
          track: t,
          index: t.trackNumber ?? i + 1,
          showArtwork: false,
          playContext: TrackPlayContext(tracks: d.tracks, index: i, origin: origin, originLabel: d.title),
        ));
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        CollectionHeader(
          leading: back,
          eyebrow: sourceId == SourceIds.local ? l10n.albumInLibrary : l10n.albumOnProvider(sourceDisplayName(ref, sourceId)),
          title: d.title,
          subtitle: d.artist,
          meta: meta,
          artwork: (size) => ArtworkImage(uri: d.artworkUrl, size: size, borderRadius: context.radii.lgAll),
          actions: [
            PlayShuffleButtons(
              enabled: d.tracks.any(isPlayableInApp),
              onPlay: () => playCollection(context, ref, d.tracks, origin: origin, originLabel: d.title),
              onShuffle: () => playCollection(context, ref, d.tracks, shuffle: true, origin: origin, originLabel: d.title),
            ),
            CollectionDownloadButton(tracks: d.tracks, origin: origin),
            if (d.artistRoute != null)
              TextButton.icon(
                onPressed: () => context.go(d.artistRoute!),
                icon: const Icon(Icons.person_rounded, size: 18),
                label: Text(l10n.shellMenuGoToArtist),
              ),
          ],
        ),
        TrackListNotices(tracks: d.tracks, padding: insets.copyWith(bottom: 8)),
        if (d.tracks.isEmpty)
          EmptyState(icon: Icons.album_rounded, title: l10n.albumEmpty, compact: true)
        else
          Padding(padding: insets, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows)),
      ],
    );
  }
}
