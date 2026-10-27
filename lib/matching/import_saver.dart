import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import '../core/contracts/library.dart';
import '../core/models/catalog.dart';
import '../core/models/matching.dart';
import '../core/models/track.dart';
import 'import_report.dart';
import 'source_rules.dart';

/// Persists a reviewed import: tracks, the local playlist and track links.
class ImportSaver {
  ImportSaver({
    required this._tracks,
    required this._playlists,
    required this._links,
    this.chunkSize = 500,
    this.minimizedSources = MatchingSourceRules.minimizedOriginalSources,
  });

  final TrackRepository _tracks;
  final PlaylistRepository _playlists;
  final TrackLinkRepository _links;

  /// Tracks per repository call.
  final int chunkSize;

  /// Sources whose terms forbid keeping a persistent copy of their
  /// metadata and cover art (Spotify). Their tracks (originals and accepted
  /// matches) are stored minimized (see [minimize]) and an imported
  /// playlist gets no cover from them.
  final Set<String> minimizedSources;

  /// [Track.extra] key set on originals stored minimized, so the library
  /// can find (and purge) them when the user disconnects the source.
  static const minimizedMarker = 'matching.minimizedOriginal';

  /// [track] without cover art and marked with [minimizedMarker]. Title,
  /// artists, album, duration, ISRC and the permalink stay: they are the
  /// provenance of the playlist entry and the attribution back-link.
  static Track minimize(Track track) => Track(
        sourceId: track.sourceId,
        sourceTrackId: track.sourceTrackId,
        title: track.title,
        artists: track.artists,
        album: track.album,
        albumArtist: track.albumArtist,
        duration: track.duration,
        isrc: track.isrc,
        explicit: track.explicit,
        year: track.year,
        trackNumber: track.trackNumber,
        discNumber: track.discNumber,
        permalink: track.permalink,
        availability: track.availability,
        extra: {...track.extra, minimizedMarker: '1'},
      );

  static final _log = Logger('matching.import');

  /// Saves and returns the new playlist id.
  ///
  /// 1. Upserts every original (so the playlist's metadata stays faithful
  ///    to the source) and every accepted candidate; tracks of
  ///    [minimizedSources] are stored minimized.
  /// 2. Creates a local playlist with [originals] in order; entries without
  ///    an accepted match stay as originals.
  /// 3. Links original ↔ accepted candidate. Per the `TrackLink` contract
  ///    the confidence is 1.0 for user-confirmed or ISRC-identical links and
  ///    the match score otherwise.
  ///
  /// If anything after the playlist creation fails, the partial playlist is
  /// deleted (best effort) and the error rethrown.
  Future<String> save({
    required String sourceId,
    required Playlist? sourcePlaylist,
    required List<Track> originals,
    required Iterable<TrackMatchResult> results,
    String? playlistName,
  }) async {
    final accepted = <String, TrackMatchResult>{
      for (final r in results)
        if (ImportReport.isAccepted(r)) r.original.id: r,
    };

    final toStore = <String, Track>{};
    Track stored(Track t) => minimizedSources.contains(t.sourceId) ? minimize(t) : t;
    for (final t in originals) {
      toStore.putIfAbsent(t.id, () => stored(t));
    }
    for (final r in accepted.values) {
      toStore.putIfAbsent(r.chosen!.candidate.id, () => stored(r.chosen!.candidate));
    }
    for (final chunk in toStore.values.slices(chunkSize)) {
      await _tracks.upsertTracks(chunk);
    }

    final name = playlistName?.trim();
    final created = await _playlists.createPlaylist(
      (name != null && name.isNotEmpty) ? name : (sourcePlaylist?.name ?? 'Imported playlist'),
      description: sourcePlaylist?.description,
      sourceId: sourceId,
      sourcePlaylistId: providerPlaylistId(sourcePlaylist, sourceId),
      artworkUrl: minimizedSources.contains(sourceId) ? null : sourcePlaylist?.artworkUrl,
    );
    try {
      for (final chunk in originals.map((t) => t.id).slices(chunkSize)) {
        await _playlists.addTracks(created.id, chunk);
      }
      for (final r in accepted.values) {
        final chosen = r.chosen!;
        if (chosen.candidate.id == r.original.id) continue;
        final userConfirmed = r.decision == MatchDecision.userAccepted;
        final isrcExact = chosen.matchedByIsrc && chosen.confidence == MatchConfidence.exact;
        await _links.link(
          r.original.id,
          chosen.candidate.id,
          confidence: userConfirmed || isrcExact ? 1.0 : chosen.score,
          userConfirmed: userConfirmed,
        );
      }
    } catch (_) {
      try {
        await _playlists.deletePlaylist(created.id);
      } catch (cleanupError) {
        _log.warning('could not remove partial playlist ${created.id}: $cleanupError');
      }
      rethrow;
    }
    _log.info('saved playlist ${created.id}: ${originals.length} entries, ${accepted.length} linked');
    return created.id;
  }

  /// The provider's own playlist id: [Playlist.sourcePlaylistId], or the
  /// part after `sourceId:` of a remote playlist id. Null for synthesized
  /// playlists (`import:` ids from `startWithTracks`).
  static String? providerPlaylistId(Playlist? playlist, String sourceId) {
    if (playlist == null || playlist.id.startsWith('import:')) return null;
    if (playlist.sourcePlaylistId != null) return playlist.sourcePlaylistId;
    final prefix = '$sourceId:';
    return playlist.id.startsWith(prefix) ? playlist.id.substring(prefix.length) : playlist.id;
  }
}
