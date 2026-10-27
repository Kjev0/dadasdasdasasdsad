import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../core/contracts/library.dart';
import '../../core/models/library.dart';
import '../../core/models/track.dart';
import 'media_session_labels.dart';
import 'media_session_mapping.dart';

final _log = Logger('platform.android.browser');

/// Kinds of nodes in the Android Auto / media browser tree.
enum BrowseKind { recent, favorites, playlists, playlist, search }

/// A media id in the browse tree, encoded as
/// `fermata:<kind>:<containerId>:<trackId>` with both ids URI-component
/// encoded (so `:` inside track/playlist ids cannot break parsing).
/// Folders have an empty track id.
@immutable
class BrowseId {
  const BrowseId(this.kind, {this.containerId = '', this.trackId = ''});

  static const _prefix = 'fermata';

  final BrowseKind kind;

  /// Playlist id for [BrowseKind.playlist], query for [BrowseKind.search].
  final String containerId;

  /// Empty for folders.
  final String trackId;

  bool get isTrack => trackId.isNotEmpty;

  BrowseId withTrack(String trackId) => BrowseId(kind, containerId: containerId, trackId: trackId);

  /// Null when [mediaId] is not a Fermata browse id.
  static BrowseId? tryParse(String mediaId) {
    final parts = mediaId.split(':');
    if (parts.length != 4 || parts[0] != _prefix) return null;
    final kind = BrowseKind.values.asNameMap()[parts[1]];
    if (kind == null) return null;
    try {
      return BrowseId(
        kind,
        containerId: Uri.decodeComponent(parts[2]),
        trackId: Uri.decodeComponent(parts[3]),
      );
    } on ArgumentError {
      return null;
    }
  }

  @override
  String toString() =>
      '$_prefix:${kind.name}:${Uri.encodeComponent(containerId)}:${Uri.encodeComponent(trackId)}';

  @override
  bool operator ==(Object other) =>
      other is BrowseId && other.kind == kind && other.containerId == containerId && other.trackId == trackId;

  @override
  int get hashCode => Object.hash(kind, containerId, trackId);
}

/// What to hand to `PlaybackController.playTracks` for a browse/search pick.
@immutable
class PlayRequest {
  const PlayRequest({
    required this.tracks,
    this.startIndex = 0,
    this.origin,
    this.originLabel,
    this.shuffle = false,
  });

  final List<Track> tracks;
  final int startIndex;
  final String? origin;
  final String? originLabel;
  final bool shuffle;
}

/// Read-only view of the library for Android Auto, Wear OS and the system
/// media browser: root → Recently played, Playlists, Favorites.
///
/// Every repository is optional; folders whose repository is missing are not
/// offered. Lists are capped so a huge library never blocks the car UI.
class MediaLibraryBrowser {
  MediaLibraryBrowser({
    this.tracks,
    this.playlists,
    this.history,
    this.favorites,
    this.labels = MediaSessionLabels.en,
    this.recentLimit = 50,
    this.listLimit = 300,
    this.searchLimit = 50,
  });

  final TrackRepository? tracks;
  final PlaylistRepository? playlists;
  final HistoryRepository? history;
  final FavoritesRepository? favorites;
  final MediaSessionLabels labels;
  final int recentLimit;
  final int listLimit;
  final int searchLimit;

  /// Whether there is anything to browse at all.
  bool get hasContent => history != null || playlists != null || favorites != null;

  /// Children of [parentMediaId] (`AudioService.browsableRootId` for the
  /// root). Unknown ids yield an empty list.
  Future<List<MediaItem>> children(String parentMediaId) async {
    try {
      if (parentMediaId == AudioService.browsableRootId) return _rootFolders();
      final id = BrowseId.tryParse(parentMediaId);
      if (id == null || id.isTrack) return const [];
      return switch (id.kind) {
        BrowseKind.playlists => await _playlistFolders(),
        BrowseKind.recent || BrowseKind.favorites || BrowseKind.playlist || BrowseKind.search => [
            for (final track in await _tracksOf(id)) _trackItem(id, track),
          ],
      };
    } catch (e, st) {
      _log.warning('Browsing $parentMediaId failed', e, st);
      return const [];
    }
  }

  /// The most recently played track, for Android's media resumption card
  /// when nothing is queued.
  Future<MediaItem?> mostRecent() async {
    final h = history;
    if (h == null) return null;
    try {
      final recent = await h.recentlyPlayed(limit: 1);
      if (recent.isEmpty) return null;
      return _trackItem(const BrowseId(BrowseKind.recent), recent.first);
    } catch (e, st) {
      _log.warning('Loading recently played failed', e, st);
      return null;
    }
  }

  /// Library search (Assistant "play X on Fermata", Android Auto search).
  Future<List<MediaItem>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final id = BrowseId(BrowseKind.search, containerId: q);
    try {
      return [for (final track in await _tracksOf(id)) _trackItem(id, track)];
    } catch (e, st) {
      _log.warning('Media search failed', e, st);
      return const [];
    }
  }

  /// Resolves a playable media id into a queue. A track inside a folder
  /// queues the whole folder starting at that track; a bare track id plays
  /// just that track. Returns null when nothing playable was found.
  Future<PlayRequest?> resolve(String mediaId) async {
    final id = BrowseId.tryParse(mediaId);
    try {
      if (id == null) return await _single(mediaId);
      if (id.kind == BrowseKind.playlists) return null;
      final list = await _tracksOf(id);
      if (!id.isTrack) {
        // A folder was "played": queue it from the start.
        return list.isEmpty ? null : PlayRequest(tracks: list, origin: _origin(id), originLabel: await _label(id));
      }
      final index = list.indexWhere((t) => t.id == id.trackId);
      if (index < 0) return await _single(id.trackId);
      return PlayRequest(tracks: list, startIndex: index, origin: _origin(id), originLabel: await _label(id));
    } catch (e, st) {
      _log.warning('Resolving media id failed', e, st);
      return null;
    }
  }

  /// Queue for a voice/search request. An empty query ("play music on
  /// Fermata") shuffles the favorites, falling back to recently played.
  Future<PlayRequest?> resolveSearch(String query) async {
    final q = query.trim();
    try {
      if (q.isNotEmpty) {
        final id = BrowseId(BrowseKind.search, containerId: q);
        final found = await _tracksOf(id);
        return found.isEmpty ? null : PlayRequest(tracks: found, origin: 'search', originLabel: q);
      }
      final favs = favorites == null ? const <Track>[] : await _tracksOf(const BrowseId(BrowseKind.favorites));
      if (favs.isNotEmpty) {
        return PlayRequest(tracks: favs, origin: 'favorites', originLabel: labels.favorites, shuffle: true);
      }
      final recent = history == null ? const <Track>[] : await _tracksOf(const BrowseId(BrowseKind.recent));
      return recent.isEmpty ? null : PlayRequest(tracks: recent, origin: 'history', originLabel: labels.recentlyPlayed);
    } catch (e, st) {
      _log.warning('Resolving search failed', e, st);
      return null;
    }
  }

  // -------------------------------------------------------------------------

  List<MediaItem> _rootFolders() => [
        if (history != null) _folder(const BrowseId(BrowseKind.recent), labels.recentlyPlayed),
        if (playlists != null) _folder(const BrowseId(BrowseKind.playlists), labels.playlists),
        if (favorites != null) _folder(const BrowseId(BrowseKind.favorites), labels.favorites),
      ];

  Future<List<MediaItem>> _playlistFolders() async {
    final repo = playlists;
    if (repo == null) return const [];
    final all = await repo.playlists();
    return [
      for (final p in all.take(listLimit))
        _folder(
          BrowseId(BrowseKind.playlist, containerId: p.id),
          p.name,
          subtitle: p.trackCount == null ? null : labels.trackCount(p.trackCount!),
          artUri: p.artworkUrl,
        ),
    ];
  }

  Future<List<Track>> _tracksOf(BrowseId id) async {
    final List<Track> result;
    switch (id.kind) {
      case BrowseKind.recent:
        result = await history?.recentlyPlayed(limit: recentLimit) ?? const [];
      case BrowseKind.favorites:
        result = await favorites?.favorites() ?? const [];
      case BrowseKind.playlist:
        result = await playlists?.playlistTracks(id.containerId) ?? const [];
      case BrowseKind.search:
        result = await tracks?.query(TrackQuery(text: id.containerId, limit: searchLimit)) ?? const [];
      case BrowseKind.playlists:
        result = const [];
    }
    // Only offer what can actually be played inside the app.
    return result
        .where((t) => t.availability.isPlayableInApp || t.availability.playback == PlaybackRights.unknown)
        .take(listLimit)
        .toList(growable: false);
  }

  Future<PlayRequest?> _single(String trackId) async {
    final track = await tracks?.getTrack(trackId);
    return track == null ? null : PlayRequest(tracks: [track]);
  }

  String? _origin(BrowseId id) => switch (id.kind) {
        BrowseKind.recent => 'history',
        BrowseKind.favorites => 'favorites',
        BrowseKind.playlist => 'playlist:${id.containerId}',
        BrowseKind.search => 'search',
        BrowseKind.playlists => null,
      };

  Future<String?> _label(BrowseId id) async => switch (id.kind) {
        BrowseKind.recent => labels.recentlyPlayed,
        BrowseKind.favorites => labels.favorites,
        BrowseKind.playlist => (await playlists?.getPlaylist(id.containerId))?.name,
        BrowseKind.search => id.containerId,
        BrowseKind.playlists => null,
      };

  MediaItem _folder(BrowseId id, String title, {String? subtitle, Uri? artUri}) => MediaItem(
        id: id.toString(),
        title: title,
        displaySubtitle: subtitle,
        artUri: sessionArtUri(artUri),
        playable: false,
      );

  MediaItem _trackItem(BrowseId folder, Track track) =>
      mediaItemForTrack(track, id: folder.withTrack(track.id).toString(), origin: _origin(folder));
}
