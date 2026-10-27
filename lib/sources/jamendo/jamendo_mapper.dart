import '../../core/models/catalog.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../base/availability.dart';
import '../base/json_utils.dart';

/// Maps Jamendo API v3 results to Fermata models (field names from the
/// documented sample responses of `tracks`, `albums/tracks`,
/// `artists/tracks`, `albums`, `artists`, `playlists`).
///
/// * Stream: the `audio` URL (format chosen with `audioformat`).
/// * Download: only when `audiodownload_allowed` is true **and**
///   `audiodownload` is non-empty (Jamendo empties it otherwise since 2020);
///   then [OfflineRights.downloadable], else stream-only.
/// * Licence: `license_ccurl` (Creative Commons) in [extraLicense] — the UI
///   shows it with the artist credit and a link back to Jamendo.
abstract final class JamendoMapper {
  static const _id = SourceIds.jamendo;

  static const extraAudio = 'jamendo.audio';
  static const extraAudioFormat = 'jamendo.audioFormat';
  static const extraDownload = 'jamendo.download';
  static const extraLicense = 'jamendo.license';
  static const extraArtistUrl = 'jamendo.artistUrl';
  static const extraAlbumId = 'jamendo.albumId';
  static const extraShortUrl = 'jamendo.shortUrl';

  /// A track. [album] / [artist] are the parent objects of `albums/tracks`
  /// / `artists/tracks` results (their track entries omit those fields).
  /// [audioFormat] is the `audioformat` the request asked for.
  static Track? track(
    Object? json, {
    Map<String, Object?>? album,
    Map<String, Object?>? artist,
    String? audioFormat,
    DateTime? now,
  }) {
    final t = asJsonMapOrNull(json);
    if (t == null) return null;
    final id = jsonString(t['id']) ?? jsonString(t['track_id']);
    final name = jsonString(t['name']) ?? jsonString(t['track_name']);
    if (id == null || name == null) return null;
    final artistName = jsonString(t['artist_name']) ?? jsonString(album?['artist_name']) ?? jsonString(artist?['name']);
    final artistId = jsonString(t['artist_id']) ?? jsonString(album?['artist_id']) ?? jsonString(artist?['id']);
    final albumName = jsonString(t['album_name']) ?? jsonString(album?['name']);
    final albumId = jsonString(t['album_id']) ?? jsonString(album?['id']);
    final seconds = jsonInt(t['duration']);
    final audio = jsonHttpUri(t['audio']);
    final download = jsonHttpUri(t['audiodownload'] ?? t['track_audiodownload']);
    final downloadAllowed =
        (jsonBool(t['audiodownload_allowed']) ?? jsonBool(t['track_audiodownload_allowed'])) == true &&
        download != null;
    final checkedAt = now ?? DateTime.now();
    final musicinfo = asJsonMap(t['musicinfo']);
    final genres = asJsonMap(musicinfo['tags'])['genres'];
    return Track(
      sourceId: _id,
      sourceTrackId: id,
      title: name,
      artists: [if (artistName != null) ArtistRef(artistName, sourceArtistId: artistId)],
      album: albumName,
      albumArtist: albumName == null ? null : artistName,
      duration: seconds == null || seconds <= 0 ? null : Duration(seconds: seconds),
      year: jsonYear(t['releasedate'] ?? album?['releasedate']),
      genre: genres is List && genres.isNotEmpty ? jsonString(genres.first) : null,
      trackNumber: jsonInt(t['position']),
      artworkUrl: jsonHttpUri(t['image']) ?? jsonHttpUri(t['album_image']) ?? jsonHttpUri(album?['image']),
      permalink: jsonHttpUri(t['shareurl']) ?? Uri.parse('https://www.jamendo.com/track/$id'),
      availability: audio == null
          ? Availabilities.unavailable(AvailabilityReason.notStreamable, checkedAt: checkedAt)
          : Availabilities.stream(downloadable: downloadAllowed, checkedAt: checkedAt),
      extra: {
        extraAudio: ?audio?.toString(),
        if (audio != null) extraAudioFormat: ?(audioFormat ?? _formatOf(audio)),
        if (downloadAllowed) extraDownload: download.toString(),
        extraLicense: ?jsonString(t['license_ccurl']),
        if (artistId != null) extraArtistUrl: 'https://www.jamendo.com/artist/$artistId',
        extraAlbumId: ?albumId,
        extraShortUrl: ?jsonString(t['shorturl']),
      },
    );
  }

  static List<Track> tracks(
    Iterable<Map<String, Object?>> list, {
    Map<String, Object?>? album,
    Map<String, Object?>? artist,
    String? audioFormat,
    DateTime? now,
  }) => [for (final t in list) ?track(t, album: album, artist: artist, audioFormat: audioFormat, now: now)];

  /// `format=` of a Jamendo storage URL (`…?trackid=1&format=mp31`).
  static String? _formatOf(Uri audio) => audio.queryParameters['format'];

  static Artist? artist(Object? json) {
    final a = asJsonMapOrNull(json);
    if (a == null) return null;
    final id = jsonString(a['id']);
    final name = jsonString(a['name']);
    if (id == null || name == null) return null;
    return Artist(
      sourceId: _id,
      sourceArtistId: id,
      name: name,
      avatarUrl: jsonHttpUri(a['image']),
      permalink: jsonHttpUri(a['shareurl']) ?? Uri.parse('https://www.jamendo.com/artist/$id'),
    );
  }

  static Album? album(Object? json) {
    final a = asJsonMapOrNull(json);
    if (a == null) return null;
    final id = jsonString(a['id']);
    final name = jsonString(a['name']);
    if (id == null || name == null) return null;
    final artistName = jsonString(a['artist_name']);
    return Album(
      sourceId: _id,
      sourceAlbumId: id,
      title: name,
      artists: [if (artistName != null) ArtistRef(artistName, sourceArtistId: jsonString(a['artist_id']))],
      artworkUrl: jsonHttpUri(a['image']),
      year: jsonYear(a['releasedate']),
      permalink: jsonHttpUri(a['shareurl']) ?? Uri.parse('https://www.jamendo.com/album/$id'),
    );
  }

  static Playlist? playlist(Object? json) {
    final p = asJsonMapOrNull(json);
    if (p == null) return null;
    final id = jsonString(p['id']);
    final name = jsonString(p['name']);
    if (id == null || name == null) return null;
    return Playlist(
      id: '$_id:$id',
      name: name,
      kind: PlaylistKind.remote,
      ownerName: jsonString(p['user_name']),
      sourceId: _id,
      sourcePlaylistId: id,
      createdAt: jsonDate(p['creationdate']),
      trackCount: asJsonMapList(p['tracks']).isEmpty ? null : asJsonMapList(p['tracks']).length,
      permalink: jsonHttpUri(p['shareurl']) ?? Uri.parse('https://www.jamendo.com/playlist/$id'),
    );
  }
}
