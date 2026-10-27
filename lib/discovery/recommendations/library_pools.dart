import 'package:logging/logging.dart';

import '../../core/contracts/library.dart';
import '../../core/models/library.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import 'source_gateway.dart';

final _log = Logger('discovery.library');

/// Candidate pools from the user's own local files (always playable, work
/// offline and with no provider connected). Failures yield empty lists.
class LibraryPools {
  LibraryPools(this.tracks, this.gateway);

  final TrackRepository tracks;
  final SourceGateway gateway;

  static const _local = {SourceIds.local};

  Future<List<Track>> _query(TrackQuery q) async {
    if (!gateway.localEnabled) return const [];
    try {
      return [for (final t in await tracks.query(q)) if (gateway.canPlay(t)) t];
    } catch (e) {
      _log.warning('Library query failed', e);
      return const [];
    }
  }

  /// Local tracks by [artist] (exact, case/accent-insensitive), most played first.
  Future<List<Track>> byArtist(String artist, {int limit = 25}) => _query(TrackQuery(
        artist: artist,
        sourceIds: _local,
        localFilesOnly: true,
        sort: TrackSortField.playCount,
        descending: true,
        limit: limit,
      ));

  /// Local tracks tagged [genre], most played first.
  Future<List<Track>> byGenre(String genre, {int limit = 25}) => _query(TrackQuery(
        genre: genre,
        sourceIds: _local,
        localFilesOnly: true,
        sort: TrackSortField.playCount,
        descending: true,
        limit: limit,
      ));

  /// Newest local files first.
  Future<List<Track>> recentlyAdded({int limit = 30}) => _query(TrackQuery(
        sourceIds: _local,
        localFilesOnly: true,
        sort: TrackSortField.dateAdded,
        descending: true,
        limit: limit,
      ));

  /// Genres present in the local library.
  Future<List<String>> genres() async {
    if (!gateway.localEnabled) return const [];
    try {
      return await tracks.genres();
    } catch (e) {
      _log.warning('Library genres failed', e);
      return const [];
    }
  }

  /// Ids of [candidates] that are already in the library database.
  Future<Set<String>> inLibrary(Iterable<Track> candidates) async {
    final ids = {for (final t in candidates) t.id}.toList();
    if (ids.isEmpty) return const {};
    try {
      return {for (final t in await tracks.getTracks(ids)) t.id};
    } catch (e) {
      _log.warning('Library lookup failed', e);
      return const {};
    }
  }
}
