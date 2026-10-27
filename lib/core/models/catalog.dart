import 'package:flutter/foundation.dart';

import 'track.dart';

/// A page of results with an opaque cursor for the next page.
@immutable
class Page<T> {
  const Page(this.items, {this.nextCursor, this.total});

  const Page.empty()
      : items = const [],
        nextCursor = null,
        total = 0;

  final List<T> items;

  /// Null when there are no further pages.
  final String? nextCursor;

  /// Total number of items if the source reports it.
  final int? total;

  bool get hasMore => nextCursor != null;
}

@immutable
class Artist {
  const Artist({
    required this.sourceId,
    required this.sourceArtistId,
    required this.name,
    this.avatarUrl,
    this.permalink,
    this.followers,
    this.description,
    this.genres = const [],
  });

  String get id => '$sourceId:$sourceArtistId';

  final String sourceId;
  final String sourceArtistId;
  final String name;
  final Uri? avatarUrl;
  final Uri? permalink;
  final int? followers;
  final String? description;
  final List<String> genres;

  @override
  bool operator ==(Object other) => other is Artist && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class Album {
  const Album({
    required this.sourceId,
    required this.sourceAlbumId,
    required this.title,
    this.artists = const [],
    this.artworkUrl,
    this.year,
    this.trackCount,
    this.permalink,
    this.upc,
  });

  String get id => '$sourceId:$sourceAlbumId';

  final String sourceId;
  final String sourceAlbumId;
  final String title;
  final List<ArtistRef> artists;
  final Uri? artworkUrl;
  final int? year;
  final int? trackCount;
  final Uri? permalink;
  final String? upc;

  @override
  bool operator ==(Object other) => other is Album && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum PlaylistKind {
  /// Created and owned in Fermata.
  local,

  /// Rule-based, evaluated against the library.
  smart,

  /// A playlist living on a remote source (browsed, not imported).
  remote,
}

/// Playlist metadata. Tracks are fetched separately.
@immutable
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.kind,
    this.description,
    this.artworkUrl,
    this.ownerName,
    this.sourceId,
    this.sourcePlaylistId,
    this.trackCount,
    this.createdAt,
    this.updatedAt,
    this.autoDownload = false,
    this.smartRulesJson,
    this.permalink,
  });

  /// Local playlists: a UUID. Remote playlists: `"<sourceId>:<sourcePlaylistId>"`.
  final String id;
  final String name;
  final PlaylistKind kind;
  final String? description;
  final Uri? artworkUrl;
  final String? ownerName;

  /// For remote playlists, or local playlists imported from a source.
  final String? sourceId;
  final String? sourcePlaylistId;
  final int? trackCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// When true and permitted, tracks are downloaded automatically.
  final bool autoDownload;

  /// JSON-encoded `SmartPlaylistRules` for [PlaylistKind.smart].
  final String? smartRulesJson;
  final Uri? permalink;

  Playlist copyWith({
    String? name,
    String? description,
    Uri? artworkUrl,
    int? trackCount,
    DateTime? updatedAt,
    bool? autoDownload,
    String? smartRulesJson,
  }) =>
      Playlist(
        id: id,
        name: name ?? this.name,
        kind: kind,
        description: description ?? this.description,
        artworkUrl: artworkUrl ?? this.artworkUrl,
        ownerName: ownerName,
        sourceId: sourceId,
        sourcePlaylistId: sourcePlaylistId,
        trackCount: trackCount ?? this.trackCount,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        autoDownload: autoDownload ?? this.autoDownload,
        smartRulesJson: smartRulesJson ?? this.smartRulesJson,
        permalink: permalink,
      );

  @override
  bool operator ==(Object other) =>
      other is Playlist &&
      other.id == id &&
      other.name == name &&
      other.trackCount == trackCount &&
      other.updatedAt == updatedAt &&
      other.autoDownload == autoDownload;

  @override
  int get hashCode => Object.hash(id, name, trackCount, updatedAt, autoDownload);
}

/// A remote playlist together with (a page of) its tracks.
@immutable
class PlaylistDetail {
  const PlaylistDetail({required this.playlist, required this.tracks});

  final Playlist playlist;
  final Page<Track> tracks;
}

enum SearchType { tracks, artists, albums, playlists }

/// Aggregated search results from one source.
@immutable
class SourceSearchResults {
  const SourceSearchResults({
    required this.sourceId,
    this.tracks = const Page.empty(),
    this.artists = const Page.empty(),
    this.albums = const Page.empty(),
    this.playlists = const Page.empty(),
    this.error,
  });

  final String sourceId;
  final Page<Track> tracks;
  final Page<Artist> artists;
  final Page<Album> albums;
  final Page<Playlist> playlists;

  /// Non-null when the source failed; other sources' results still show.
  final Object? error;
}
