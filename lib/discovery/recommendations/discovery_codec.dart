import '../../core/contracts/discovery.dart';
import '../../core/models/catalog.dart';
import '../../core/models/track.dart';

/// JSON codecs for cached discovery results (the core models only define
/// JSON for [Track]).
abstract final class DiscoveryCodec {
  static Map<String, Object?> shelf(Shelf s) => {
        'id': s.id,
        'title': s.title,
        if (s.subtitle != null) 'subtitle': s.subtitle,
        if (s.artworkUrl != null) 'artwork': s.artworkUrl.toString(),
        'kind': s.kind.name,
        'tracks': [for (final t in s.tracks) t.toJson()],
      };

  static Shelf shelfFrom(Object? raw) {
    final j = _map(raw);
    return Shelf(
      id: j['id'] as String,
      title: j['title'] as String,
      subtitle: j['subtitle'] as String?,
      artworkUrl: j['artwork'] == null ? null : Uri.tryParse(j['artwork'] as String),
      kind: ShelfKind.values.asNameMap()[j['kind']] ?? ShelfKind.mix,
      tracks: tracksFrom(j['tracks']),
    );
  }

  static List<Object?> shelves(List<Shelf> list) => [for (final s in list) shelf(s)];

  static List<Shelf> shelvesFrom(Object? raw) => [for (final s in (raw as List? ?? const [])) shelfFrom(s)];

  static List<Object?> tracks(List<Track> list) => [for (final t in list) t.toJson()];

  static List<Track> tracksFrom(Object? raw) =>
      [for (final t in (raw as List? ?? const [])) Track.fromJson(_map(t))];

  static Map<String, Object?> album(Album a) => {
        'source': a.sourceId,
        'sid': a.sourceAlbumId,
        'title': a.title,
        'artists': [for (final r in a.artists) r.toJson()],
        if (a.artworkUrl != null) 'artwork': a.artworkUrl.toString(),
        if (a.year != null) 'year': a.year,
        if (a.trackCount != null) 'trackCount': a.trackCount,
        if (a.permalink != null) 'permalink': a.permalink.toString(),
        if (a.upc != null) 'upc': a.upc,
      };

  static Album albumFrom(Object? raw) {
    final j = _map(raw);
    return Album(
      sourceId: j['source'] as String,
      sourceAlbumId: j['sid'] as String,
      title: j['title'] as String? ?? '',
      artists: [for (final r in (j['artists'] as List? ?? const [])) ArtistRef.fromJson(_map(r))],
      artworkUrl: j['artwork'] == null ? null : Uri.tryParse(j['artwork'] as String),
      year: (j['year'] as num?)?.toInt(),
      trackCount: (j['trackCount'] as num?)?.toInt(),
      permalink: j['permalink'] == null ? null : Uri.tryParse(j['permalink'] as String),
      upc: j['upc'] as String?,
    );
  }

  static List<Object?> albums(List<Album> list) => [for (final a in list) album(a)];

  static List<Album> albumsFrom(Object? raw) => [for (final a in (raw as List? ?? const [])) albumFrom(a)];

  static Map<String, Object?> artist(Artist a) => {
        'source': a.sourceId,
        'sid': a.sourceArtistId,
        'name': a.name,
        if (a.avatarUrl != null) 'avatar': a.avatarUrl.toString(),
        if (a.permalink != null) 'permalink': a.permalink.toString(),
        if (a.followers != null) 'followers': a.followers,
        if (a.genres.isNotEmpty) 'genres': a.genres,
      };

  static Artist artistFrom(Object? raw) {
    final j = _map(raw);
    return Artist(
      sourceId: j['source'] as String,
      sourceArtistId: j['sid'] as String,
      name: j['name'] as String? ?? '',
      avatarUrl: j['avatar'] == null ? null : Uri.tryParse(j['avatar'] as String),
      permalink: j['permalink'] == null ? null : Uri.tryParse(j['permalink'] as String),
      followers: (j['followers'] as num?)?.toInt(),
      genres: [for (final g in (j['genres'] as List? ?? const [])) g as String],
    );
  }

  static List<Object?> artists(List<Artist> list) => [for (final a in list) artist(a)];

  static List<Artist> artistsFrom(Object? raw) => [for (final a in (raw as List? ?? const [])) artistFrom(a)];

  static List<String> stringsFrom(Object? raw) => [for (final s in (raw as List? ?? const [])) s as String];

  static Map<String, Object?> _map(Object? raw) => (raw as Map).cast<String, Object?>();
}
