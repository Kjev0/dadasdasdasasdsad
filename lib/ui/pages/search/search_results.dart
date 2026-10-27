import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/music_source.dart';
import '../../../core/errors.dart';
import '../../../core/models/auth.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/track.dart';
import '../../../core/sources/source_ids.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../actions/routes.dart';
import '../../actions/track_actions.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/section_header.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/feedback/skeleton.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/media/media_card.dart';
import '../../widgets/media/shelf_row.dart';
import '../../widgets/tracks/track_tile.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/provider_notices.dart';
import '../library/shared/track_helpers.dart';
import 'search_controller.dart';
import 'top_result_card.dart';

/// Tracks shown per group before "Show all".
const searchCollapsedTracks = 8;

/// Grouped search results with per-source notices.
class SearchResultsView extends ConsumerStatefulWidget {
  const SearchResultsView({super.key, required this.state, required this.onRetry});

  final SearchState state;
  final VoidCallback onRetry;

  @override
  ConsumerState<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends ConsumerState<SearchResultsView> {
  bool _allTracks = false;
  String? _forQuery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;
    if (_forQuery != state.activeQuery) {
      _forQuery = state.activeQuery;
      _allTracks = false;
    }
    final order = ref.watch(settingsProvider.select((s) => s.services.providerOrder));
    ref.watch(sourcesRevisionProvider);
    final registry = ref.watch(sourceRegistryProvider);
    final grouped = GroupedResults.from(state.activeQuery ?? '', state.results, order, only: state.filter);
    final notices = _notices(context, registry, state, grouped);
    final insets = pageInsets(context);

    final children = <Widget>[...notices];
    if (grouped.top != null) {
      children
        ..add(SectionHeader(title: l10n.searchTopResult))
        ..add(TopResultCard(item: grouped.top!, query: state.activeQuery ?? ''));
    }
    if (grouped.tracks.isNotEmpty) {
      final collapsed = state.filter == null && !_allTracks && grouped.tracks.length > searchCollapsedTracks;
      final shown = collapsed ? grouped.tracks.take(searchCollapsedTracks).toList() : grouped.tracks;
      children.add(SectionHeader(
        title: l10n.searchTracks,
        actionLabel: collapsed ? l10n.searchShowAll(grouped.tracks.length) : null,
        onAction: collapsed ? () => setState(() => _allTracks = true) : null,
      ));
      children.add(TrackListNotices(tracks: shown, padding: const EdgeInsets.only(bottom: 8)));
      for (var i = 0; i < shown.length; i++) {
        children.add(SearchTrackTile(key: ValueKey('result-${shown[i].id}'), tracks: grouped.tracks, index: i));
      }
      children.add(const SizedBox(height: 16));
    }
    if (grouped.artists.isNotEmpty) children.add(_ArtistsRow(artists: grouped.artists));
    if (grouped.albums.isNotEmpty) children.add(_AlbumsRow(albums: grouped.albums));
    if (grouped.playlists.isNotEmpty) children.add(_PlaylistsRow(playlists: grouped.playlists));

    if (grouped.isEmpty) {
      if (state.searching) {
        children.add(const SkeletonTrackList(count: 6));
      } else if (grouped.errors.isEmpty) {
        children.add(EmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.searchNoResults(state.activeQuery ?? ''),
          message: l10n.searchNoResultsHint,
        ));
      }
    } else if (state.searching) {
      children.add(const Padding(padding: EdgeInsets.all(16), child: Center(child: LinearProgressIndicator())));
    }

    return ListView(padding: insets.copyWith(top: 4, bottom: 32), children: children);
  }

  List<Widget> _notices(BuildContext context, SourceRegistry registry, SearchState state, GroupedResults grouped) {
    final l10n = context.l10n;
    final out = <Widget>[];
    void settingsLink() => context.go(AppRoutes.settingsSection(SettingsSections.services));
    final notReady = <MusicSource>[];
    for (final s in registry.ordered) {
      if (s.id == SourceIds.local || !isSearchable(s)) continue;
      if (state.filter != null && state.filter != s.id) continue;
      final error = grouped.errors[s.id];
      if (error != null) {
        if (error is OperationCanceledException) continue;
        final needsSettings = error is AuthRequiredException || error is MissingCredentialsException;
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InlineNotice(
            key: ValueKey('notice-${s.id}'),
            warning: true,
            icon: Icons.error_outline_rounded,
            title: s.displayName,
            message: errorMessageFor(l10n, error, sourceName: (_) => s.displayName) ?? l10n.errorGeneric,
            actionLabel: needsSettings ? l10n.searchConnectedServices : l10n.actionRetry,
            onAction: needsSettings ? settingsLink : widget.onRetry,
          ),
        ));
      } else if (!s.isReady) {
        notReady.add(s);
      }
    }
    if (notReady.isNotEmpty) {
      final message = notReady.length == 1 && state.filter != null
          ? notReadyReason(l10n, notReady.single)
          : l10n.searchNotSearched(notReady.map((s) => '${s.displayName} (${notReadyShort(l10n, s)})').join(', '));
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InlineNotice(
          key: const ValueKey('notice-not-ready'),
          icon: Icons.link_off_rounded,
          message: message,
          actionLabel: l10n.searchConnectedServices,
          onAction: settingsLink,
        ),
      ));
    }
    return out;
  }
}

/// Why [s] can't be searched (full sentence).
String notReadyReason(AppLocalizations l10n, MusicSource s) {
  final status = s.authState.status;
  if (!s.credentialStatus.configured || status == SourceConnectionStatus.credentialsMissing) {
    return l10n.errorCredentialsMissing(s.displayName);
  }
  if (status == SourceConnectionStatus.expired || status == SourceConnectionStatus.error) {
    return l10n.errorAuthRequired(s.displayName);
  }
  return l10n.searchSourceNotConnected(s.displayName);
}

/// Short reason for the combined notice.
String notReadyShort(AppLocalizations l10n, MusicSource s) {
  final status = s.authState.status;
  if (!s.credentialStatus.configured || status == SourceConnectionStatus.credentialsMissing) {
    return l10n.searchNeedsCredentials;
  }
  return l10n.searchNotConnected;
}

/// A result row: plays from this track within the provider's queue silo
/// (SoundCloud results never mix with other services). SoundCloud rows link
/// to the track on SoundCloud (attribution).
class SearchTrackTile extends ConsumerWidget {
  const SearchTrackTile({super.key, required this.tracks, required this.index});

  final List<Track> tracks;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tracks[index];
    final link = t.sourceId == SourceIds.soundcloud ? t.permalink : null;
    return TrackTile(
      track: t,
      showSource: true,
      showAlbum: true,
      playContext: siloSafeContext(tracks, index, origin: 'search'),
      trailing: link == null
          ? null
          : IconButton(
              tooltip: context.l10n.shellMenuOpenOn(sourceDisplayName(ref, t.sourceId)),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              onPressed: () => TrackActions(context, ref).openLink(link),
            ),
    );
  }
}

double _cardWidth(BuildContext context) => MediaQuery.sizeOf(context).width < 600 ? 136 : 160;

class _ArtistsRow extends ConsumerWidget {
  const _ArtistsRow({required this.artists});

  final List<Artist> artists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = _cardWidth(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ShelfRow(
        title: context.l10n.searchArtists,
        itemWidth: w,
        itemCount: artists.length,
        itemBuilder: (context, i) {
          final a = artists[i];
          return MediaCard(
            key: ValueKey('artist-${a.id}'),
            width: w,
            circle: true,
            title: a.name,
            subtitle: sourceDisplayName(ref, a.sourceId),
            artworkUrl: a.avatarUrl,
            placeholderIcon: Icons.person_rounded,
            onTap: () => context.go(AppRoutes.artist(a.sourceId, a.sourceArtistId)),
          );
        },
      ),
    );
  }
}

class _AlbumsRow extends ConsumerWidget {
  const _AlbumsRow({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = _cardWidth(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ShelfRow(
        title: context.l10n.searchAlbums,
        itemWidth: w,
        itemCount: albums.length,
        itemBuilder: (context, i) {
          final a = albums[i];
          final artist = a.artists.map((x) => x.name).join(', ');
          return MediaCard(
            key: ValueKey('album-${a.id}'),
            width: w,
            title: a.title,
            subtitle: [if (artist.isNotEmpty) artist, sourceDisplayName(ref, a.sourceId)].join(' · '),
            artworkUrl: a.artworkUrl,
            onTap: () => context.go(AppRoutes.album(a.sourceId, a.sourceAlbumId)),
          );
        },
      ),
    );
  }
}

class _PlaylistsRow extends ConsumerWidget {
  const _PlaylistsRow({required this.playlists});

  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = _cardWidth(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ShelfRow(
        title: context.l10n.searchPlaylists,
        itemWidth: w,
        itemCount: playlists.length,
        itemBuilder: (context, i) {
          final p = playlists[i];
          final source = p.sourceId == null ? null : sourceDisplayName(ref, p.sourceId!);
          return MediaCard(
            key: ValueKey('playlist-${p.id}'),
            width: w,
            title: p.name,
            subtitle: [?p.ownerName, ?source].join(' · '),
            artworkUrl: p.artworkUrl,
            placeholderIcon: Icons.queue_music_rounded,
            onTap: () => context.go(AppRoutes.playlist(remotePlaylistId(p))),
          );
        },
      ),
    );
  }
}

/// Route id for a remote playlist (`<sourceId>:<sourcePlaylistId>`).
String remotePlaylistId(Playlist p) {
  if (p.sourceId != null && p.sourcePlaylistId != null && !p.id.startsWith('${p.sourceId}:')) {
    return '${p.sourceId}:${p.sourcePlaylistId}';
  }
  return p.id;
}
