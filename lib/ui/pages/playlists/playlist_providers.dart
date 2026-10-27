import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/library.dart';
import '../../../core/errors.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/library.dart';
import '../../../core/models/track.dart';
import '../../widgets/util/async_utils.dart';
import '../library/shared/revisions.dart';
import '../library/shared/track_helpers.dart';

/// One playlist entry: its position in the playlist and the track.
@immutable
class PlaylistEntry {
  const PlaylistEntry(this.position, this.track);

  final int position;
  final Track track;
}

/// A local / smart playlist with its entries.
@immutable
class LocalPlaylistData {
  const LocalPlaylistData(this.playlist, this.entries);

  final Playlist playlist;
  final List<PlaylistEntry> entries;

  List<Track> get tracks => [for (final e in entries) e.track];
}

/// Whether [id] names a remote playlist (`<sourceId>:<id or url>` with a
/// registered source).
bool isRemotePlaylistId(String id, Set<String> sourceIds) {
  final i = id.indexOf(':');
  if (i <= 0) return false;
  return sourceIds.contains(id.substring(0, i));
}

/// `(sourceId, idOrUrl)` of a remote playlist id.
(String, String) splitRemotePlaylistId(String id) {
  final i = id.indexOf(':');
  return (id.substring(0, i), id.substring(i + 1));
}

/// A library playlist and its entries (null when it doesn't exist). Smart
/// playlists also refresh when favorites, history or downloads change.
final localPlaylistProvider = FutureProvider.autoDispose.family<LocalPlaylistData?, String>(
  (ref, id) async {
    watchLibrary(ref, LibraryTopic.playlists);
    watchLibrary(ref, LibraryTopic.tracks);
    final repo = ref.watch(playlistRepositoryProvider);
    final playlist = await repo.getPlaylist(id);
    if (playlist == null) return null;
    if (playlist.kind == PlaylistKind.smart) {
      watchLibrary(ref, LibraryTopic.favorites);
      watchLibrary(ref, LibraryTopic.history);
      final tracks = await repo.playlistTracks(id);
      return LocalPlaylistData(playlist, [for (var i = 0; i < tracks.length; i++) PlaylistEntry(i, tracks[i])]);
    }
    final ids = await repo.playlistTrackIds(id);
    final tracks = await repo.playlistTracks(id);
    final byId = {for (final t in tracks) t.id: t};
    return LocalPlaylistData(playlist, [
      for (var i = 0; i < ids.length; i++)
        if (byId[ids[i]] != null) PlaylistEntry(i, byId[ids[i]]!),
    ]);
  },
  retry: noRetry,
);

/// First page of a remote playlist (`<sourceId>:<id or url>`).
final remotePlaylistProvider = FutureProvider.autoDispose.family<PlaylistDetail, String>(
  (ref, id) async {
    watchSources(ref);
    final (sourceId, idOrUrl) = splitRemotePlaylistId(id);
    final source = ref.watch(sourceRegistryProvider).byId(sourceId);
    if (source == null) throw UnsupportedSourceOperation(sourceId, 'getPlaylist', 'Source $sourceId is not available');
    return source.getPlaylist(idOrUrl, cancel: providerCancelToken(ref));
  },
  retry: noRetry,
);

/// Links of the playlist's tracks that can't play inside Fermata on their
/// own (imported Spotify/YouTube tracks, unavailable tracks): track id →
/// linked tracks, best first.
final playlistLinksProvider = FutureProvider.autoDispose.family<Map<String, List<(Track, TrackLink)>>, String>(
  (ref, playlistId) async {
    watchLibrary(ref, LibraryTopic.links);
    final data = await ref.watch(localPlaylistProvider(playlistId).future);
    if (data == null) return const {};
    final links = ref.watch(trackLinkRepositoryProvider);
    final out = <String, List<(Track, TrackLink)>>{};
    for (final t in {for (final e in data.entries) if (!isPlayableInApp(e.track)) e.track}) {
      final linked = await links.linkedTracks(t.id);
      if (linked.isNotEmpty) out[t.id] = linked;
    }
    return out;
  },
  retry: noRetry,
);

/// True when [t] plays in Fermata itself or through a linked match.
bool playableOrLinked(Track t, Map<String, List<(Track, TrackLink)>> links) =>
    isPlayableInApp(t) || (links[t.id]?.any((l) => isPlayableInApp(l.$1)) ?? false);

/// Playlist kind label key for cards ("Smart playlist", "Imported", ...).
enum PlaylistCategory { local, smart, imported }

PlaylistCategory categoryOf(Playlist p) => p.kind == PlaylistKind.smart
    ? PlaylistCategory.smart
    : (p.sourceId != null ? PlaylistCategory.imported : PlaylistCategory.local);
