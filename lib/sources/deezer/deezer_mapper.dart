import '../../core/models/catalog.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../base/artwork.dart';
import '../base/availability.dart';
import '../base/json_utils.dart';

/// Maps public Deezer API JSON (shapes verified against live responses on
/// 2026-10-27, see test/sources/core/fixtures/deezer_*.json).
abstract final class DeezerMapper {
  /// Deezer previews are 30-second MP3 extracts.
  static const previewLength = Duration(seconds: 30);

  /// `extra` key holding the (short-lived, signed) preview URL.
  static const extraPreview = 'deezer.preview';
  static const extraArtistId = 'deezer.artistId';
  static const extraAlbumId = 'deezer.albumId';

  static Uri trackLink(String id) => Uri.parse('https://www.deezer.com/track/$id');

  /// Cover fields → best URL; falls back to building the CDN URL from
  /// `md5_image` (the format used by the API's own `cover_*` fields).
  static Uri? coverOf(
    Map<String, Object?> m, {
    String type = 'cover',
    String md5Folder = 'cover',
    int targetPx = ArtworkSizing.standard,
  }) {
    final picked = ArtworkSizing.pick({
      56: m['${type}_small'],
      250: m['${type}_medium'],
      500: m['${type}_big'],
      1000: m['${type}_xl'],
    }, targetPx: targetPx);
    if (picked != null) return picked;
    final md5 = jsonString(m['md5_image']);
    if (md5 == null) return null;
    final size = targetPx <= 56 ? 56 : (targetPx <= 250 ? 250 : (targetPx <= 500 ? 500 : 1000));
    final folder = jsonString(m['picture_type']) ?? md5Folder;
    return Uri.parse('https://cdn-images.dzcdn.net/images/$folder/$md5/${size}x$size-000000-80-0-0.jpg');
  }

  /// * `readable == false` → unavailable (`region_restricted`);
  /// * a non-empty `preview` → 30 s preview in-app (`preview_only`);
  /// * otherwise playback only on Deezer (`external_only`).
  /// Never downloadable (offline storage is forbidden by Deezer's terms).
  static TrackAvailability availabilityOf(Map<String, Object?> t, {DateTime? checkedAt}) {
    final at = checkedAt ?? DateTime.now();
    if (jsonBool(t['readable']) == false) {
      return Availabilities.unavailable(AvailabilityReason.regionRestricted, checkedAt: at);
    }
    if (jsonHttpUri(t['preview']) != null) {
      return Availabilities.preview(previewLength, checkedAt: at);
    }
    return Availabilities.externalOnly(checkedAt: at);
  }

  /// [album] supplies album fields for endpoints whose track items omit
  /// them (`/album/{id}/tracks`).
  static Track? track(Object? json, {Map<String, Object?>? album, DateTime? checkedAt}) {
    final t = asJsonMapOrNull(json);
    if (t == null) return null;
    final id = jsonString(t['id']);
    final title = jsonString(t['title']);
    if (id == null || title == null) return null;
    final artist = asJsonMap(t['artist']);
    final alb = asJsonMapOrNull(t['album']) ?? album ?? const <String, Object?>{};
    final contributors = asJsonMapList(t['contributors']);
    final artists = <ArtistRef>[];
    final seen = <String>{};
    void addArtist(Map<String, Object?> a) {
      final name = jsonString(a['name']);
      if (name == null || !seen.add(name.toLowerCase())) return;
      artists.add(ArtistRef(name, sourceArtistId: jsonString(a['id'])));
    }

    addArtist(artist);
    for (final c in contributors) {
      addArtist(c);
    }
    final duration = jsonInt(t['duration']);
    final preview = jsonHttpUri(t['preview']);
    final artistId = jsonString(artist['id']);
    final albumId = jsonString(alb['id']);
    return Track(
      sourceId: SourceIds.deezer,
      sourceTrackId: id,
      title: title,
      artists: artists,
      album: jsonString(alb['title']),
      albumArtist: jsonString(asJsonMap(alb['artist'])['name']),
      duration: duration == null || duration <= 0 ? null : Duration(seconds: duration),
      isrc: jsonString(t['isrc']),
      explicit: jsonBool(t['explicit_lyrics']),
      year: jsonYear(t['release_date']) ?? jsonYear(alb['release_date']),
      trackNumber: jsonInt(t['track_position']),
      discNumber: jsonInt(t['disk_number']),
      artworkUrl: coverOf(alb.isEmpty ? t : alb),
      permalink: jsonHttpUri(t['link']) ?? trackLink(id),
      availability: availabilityOf(t, checkedAt: checkedAt),
      extra: {if (preview != null) extraPreview: preview.toString(), extraArtistId: ?artistId, extraAlbumId: ?albumId},
    );
  }

  static List<Track> tracks(Object? data, {Map<String, Object?>? album, DateTime? checkedAt}) {
    final now = checkedAt ?? DateTime.now();
    return [for (final e in asJsonMapList(data)) ?track(e, album: album, checkedAt: now)];
  }

  static Artist? artist(Object? json) {
    final a = asJsonMapOrNull(json);
    if (a == null) return null;
    final id = jsonString(a['id']);
    final name = jsonString(a['name']);
    if (id == null || name == null) return null;
    return Artist(
      sourceId: SourceIds.deezer,
      sourceArtistId: id,
      name: name,
      avatarUrl: coverOf(a, type: 'picture', md5Folder: 'artist'),
      permalink: jsonHttpUri(a['link']) ?? Uri.parse('https://www.deezer.com/artist/$id'),
      followers: jsonInt(a['nb_fan']),
    );
  }

  static List<Artist> artists(Object? data) => [for (final e in asJsonMapList(data)) ?artist(e)];

  static Album? album(Object? json) {
    final a = asJsonMapOrNull(json);
    if (a == null) return null;
    final id = jsonString(a['id']);
    final title = jsonString(a['title']);
    if (id == null || title == null) return null;
    final artist = asJsonMap(a['artist']);
    final artistName = jsonString(artist['name']);
    return Album(
      sourceId: SourceIds.deezer,
      sourceAlbumId: id,
      title: title,
      artists: artistName == null ? const [] : [ArtistRef(artistName, sourceArtistId: jsonString(artist['id']))],
      artworkUrl: coverOf(a),
      year: jsonYear(a['release_date']),
      trackCount: jsonInt(a['nb_tracks']),
      permalink: jsonHttpUri(a['link']) ?? Uri.parse('https://www.deezer.com/album/$id'),
      upc: jsonString(a['upc']),
    );
  }

  static List<Album> albums(Object? data) => [for (final e in asJsonMapList(data)) ?album(e)];

  static Playlist? playlist(Object? json) {
    final p = asJsonMapOrNull(json);
    if (p == null) return null;
    final id = jsonString(p['id']);
    final title = jsonString(p['title']);
    if (id == null || title == null) return null;
    final owner = asJsonMapOrNull(p['creator']) ?? asJsonMap(p['user']);
    return Playlist(
      id: '${SourceIds.deezer}:$id',
      name: title,
      kind: PlaylistKind.remote,
      description: jsonString(p['description']),
      artworkUrl: coverOf(p, type: 'picture', md5Folder: 'playlist'),
      ownerName: jsonString(owner['name']),
      sourceId: SourceIds.deezer,
      sourcePlaylistId: id,
      trackCount: jsonInt(p['nb_tracks']),
      createdAt: jsonDate(p['creation_date']),
      updatedAt: jsonDate(p['mod_date']),
      permalink: jsonHttpUri(p['link']) ?? Uri.parse('https://www.deezer.com/playlist/$id'),
    );
  }

  static List<Playlist> playlists(Object? data) => [for (final e in asJsonMapList(data)) ?playlist(e)];

  /// Genre names from `/genre`, without the catch-all "All" (id 0).
  static Map<String, String> genreIds(Object? data) => {
    for (final g in asJsonMapList(data))
      if (jsonInt(g['id']) != 0 && jsonString(g['name']) != null) jsonString(g['name'])!: jsonString(g['id'])!,
  };
}
