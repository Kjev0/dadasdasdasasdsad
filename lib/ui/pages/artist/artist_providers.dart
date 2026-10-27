import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/library.dart';
import '../../../core/errors.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/library.dart';
import '../../../core/models/track.dart';
import '../../../core/sources/source_ids.dart';
import '../../widgets/util/async_utils.dart';
import '../library/shared/revisions.dart';

final _log = Logger('ui.pages.artist');

/// An album shown on an artist page (route id + display data).
@immutable
class ArtistAlbum {
  const ArtistAlbum({required this.sourceId, required this.albumId, required this.title, this.artworkUrl, this.year, this.trackCount});

  final String sourceId;

  /// Id for `AppRoutes.album` (the title for library albums).
  final String albumId;
  final String title;
  final Uri? artworkUrl;
  final int? year;
  final int? trackCount;
}

/// Everything the artist page shows.
@immutable
class ArtistPageData {
  const ArtistPageData({
    required this.sourceId,
    required this.name,
    this.avatarUrl,
    this.permalink,
    this.followers,
    this.description,
    this.genres = const [],
    this.topTracks = const [],
    this.albums = const [],
    this.related = const [],
  });

  final String sourceId;
  final String name;
  final Uri? avatarUrl;
  final Uri? permalink;
  final int? followers;
  final String? description;
  final List<String> genres;
  final List<Track> topTracks;
  final List<ArtistAlbum> albums;
  final List<Artist> related;
}

/// Library albums of [artist] from its tracks (remote sources have no
/// "artist albums" call; albums are derived from the top tracks).
List<ArtistAlbum> albumsFromTracks(String sourceId, List<Track> tracks) {
  final seen = <String>{};
  final out = <ArtistAlbum>[];
  for (final t in tracks) {
    final id = t.extra['albumId'] ?? t.extra['${t.sourceId}.albumId'];
    final title = t.album;
    if (id == null || title == null || title.isEmpty || !seen.add(id)) continue;
    out.add(ArtistAlbum(sourceId: sourceId, albumId: id, title: title, artworkUrl: t.artworkUrl, year: t.year));
  }
  return out;
}

/// Artist page data for `(sourceId, artistId)`; `local` uses the name.
final artistPageProvider = FutureProvider.autoDispose.family<ArtistPageData, (String, String)>(
  (ref, key) async {
    final (sourceId, artistId) = key;
    final token = providerCancelToken(ref);
    final recs = ref.watch(recommendationsProvider);
    Future<List<Artist>> similar(String name) async {
      try {
        return await recs.similarArtists(name, cancel: token);
      } on OperationCanceledException {
        rethrow;
      } catch (e) {
        _log.fine('Similar artists failed: $e');
        return const [];
      }
    }

    if (sourceId == SourceIds.local) {
      watchLibrary(ref, LibraryTopic.tracks);
      final repo = ref.watch(trackRepositoryProvider);
      final top = await repo.query(TrackQuery(artist: artistId, sort: TrackSortField.playCount, limit: 20));
      final albums = await repo.albums(artist: artistId);
      return ArtistPageData(
        sourceId: sourceId,
        name: artistId,
        avatarUrl: top.map((t) => t.artworkUrl).whereType<Uri>().firstOrNull,
        topTracks: top,
        albums: [
          for (final a in albums)
            ArtistAlbum(sourceId: SourceIds.local, albumId: a.title, title: a.title, artworkUrl: a.artworkUrl, year: a.year, trackCount: a.trackCount),
        ],
        related: await similar(artistId),
      );
    }

    watchSources(ref);
    final source = ref.watch(sourceRegistryProvider).byId(sourceId);
    if (source == null) throw UnsupportedSourceOperation(sourceId, 'getArtist', 'Source $sourceId is not available');
    final artist = await source.getArtist(artistId, cancel: token);
    if (artist == null) throw ApiException(404, 'Artist $artistId not found');
    final top = await source.artistTopTracks(artistId, limit: 20, cancel: token);
    var related = const <Artist>[];
    try {
      related = await source.relatedArtists(artistId, cancel: token);
    } on OperationCanceledException {
      rethrow;
    } catch (e) {
      _log.fine('Related artists from $sourceId failed: $e');
    }
    if (related.isEmpty) related = await similar(artist.name);
    return ArtistPageData(
      sourceId: sourceId,
      name: artist.name,
      avatarUrl: artist.avatarUrl,
      permalink: artist.permalink,
      followers: artist.followers,
      description: artist.description,
      genres: artist.genres,
      topTracks: top.items,
      albums: albumsFromTracks(sourceId, top.items),
      related: [for (final a in related) if (a.id != artist.id) a],
    );
  },
  retry: noRetry,
);
