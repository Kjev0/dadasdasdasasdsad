import '../../core/models/catalog.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../base/artwork.dart';
import '../base/availability.dart';
import '../base/json_utils.dart';
import 'spotify_links.dart';

/// Maps Spotify Web API objects (TrackObject, SimplifiedPlaylistObject,
/// PlaylistTrackObject; reference verified 2026-10-27) to Fermata models.
///
/// Every Spotify track is [PlaybackRights.externalOnly]: the Web API returns
/// no audio and Spotify's terms do not allow third-party playback, so the
/// tracks exist in Fermata to be matched to other sources or opened in
/// Spotify. `external_ids.isrc` (reinstated March 2026) is mapped when
/// present — it is the key for cross-service matching.
abstract final class SpotifyMapper {
  static const _id = SourceIds.spotify;

  static const extraUri = 'spotify.uri';
  static const extraAlbumId = 'spotify.albumId';
  static const extraLocal = 'spotify.local';
  static const extraRestriction = 'spotify.restriction';
  static const extraAddedAt = 'spotify.addedAt';

  /// A track, or null for episodes and unusable objects. Spotify "local
  /// files" inside playlists (no id) are kept — with their `spotify:local:…`
  /// URI as id — so imports can still match them by title/artist.
  static Track? track(Object? json, {DateTime? now, String? addedAt}) {
    final t = asJsonMapOrNull(json);
    if (t == null) return null;
    final type = jsonString(t['type']);
    if (type != null && type != 'track') return null;
    final name = jsonString(t['name']);
    if (name == null) return null;
    final isLocal = jsonBool(t['is_local']) == true;
    final id = jsonString(t['id']);
    final uri = jsonString(t['uri']);
    final sourceTrackId = isLocal ? uri : id;
    if (sourceTrackId == null) return null;
    final album = asJsonMap(t['album']);
    final albumArtists = asJsonMapList(album['artists']);
    final durationMs = jsonInt(t['duration_ms']);
    final checkedAt = now ?? DateTime.now();
    return Track(
      sourceId: _id,
      sourceTrackId: sourceTrackId,
      title: name,
      artists: [
        for (final a in asJsonMapList(t['artists']))
          if (jsonString(a['name']) != null) ArtistRef(jsonString(a['name'])!, sourceArtistId: jsonString(a['id'])),
      ],
      album: jsonString(album['name']),
      albumArtist: albumArtists.isEmpty ? null : jsonString(albumArtists.first['name']),
      duration: durationMs == null || durationMs <= 0 ? null : Duration(milliseconds: durationMs),
      isrc: jsonString(asJsonMap(t['external_ids'])['isrc'])?.toUpperCase(),
      explicit: jsonBool(t['explicit']),
      year: jsonYear(album['release_date']),
      trackNumber: jsonInt(t['track_number']),
      discNumber: jsonInt(t['disc_number']),
      artworkUrl: image(album['images']),
      permalink: isLocal ? null : (jsonHttpUri(asJsonMap(t['external_urls'])['spotify']) ?? SpotifyLinks.trackUrl(id!)),
      availability: isLocal
          ? Availabilities.unavailable(AvailabilityReason.notStreamable, checkedAt: checkedAt)
          : Availabilities.externalOnly(checkedAt: checkedAt),
      extra: {
        extraUri: ?uri,
        extraAlbumId: ?jsonString(album['id']),
        if (isLocal) extraLocal: 'true',
        extraRestriction: ?jsonString(asJsonMap(t['restrictions'])['reason']),
        extraAddedAt: ?addedAt,
      },
    );
  }

  /// Tracks from a list of TrackObjects.
  static List<Track> tracks(Object? list, {DateTime? now}) => [
    for (final t in asJsonMapList(list)) ?track(t, now: now),
  ];

  /// Tracks from a list of wrappers (`{added_at, item|track}` — saved
  /// tracks and playlist items; `track` is the deprecated alias of `item`).
  static List<Track> wrappedTracks(Object? list, {DateTime? now}) => [
    for (final w in asJsonMapList(list)) ?track(w['item'] ?? w['track'], now: now, addedAt: jsonString(w['added_at'])),
  ];

  /// Playlist metadata (full or simplified object).
  static Playlist? playlist(Object? json) {
    final p = asJsonMapOrNull(json);
    if (p == null) return null;
    final id = jsonString(p['id']);
    final name = jsonString(p['name']);
    if (id == null || name == null) return null;
    final owner = asJsonMap(p['owner']);
    // `items` replaced `tracks` in Feb 2026; both carry `total`.
    final total = jsonInt(asJsonMap(p['items'])['total']) ?? jsonInt(asJsonMap(p['tracks'])['total']);
    return Playlist(
      id: '$_id:$id',
      name: name,
      kind: PlaylistKind.remote,
      description: jsonString(p['description']),
      artworkUrl: image(p['images']),
      ownerName: jsonString(owner['display_name']) ?? jsonString(owner['id']),
      sourceId: _id,
      sourcePlaylistId: id,
      trackCount: total,
      permalink:
          jsonHttpUri(asJsonMap(p['external_urls'])['spotify']) ?? Uri.parse('https://open.spotify.com/playlist/$id'),
    );
  }

  /// The image closest to [ArtworkSizing.standard] from an `ImageObject`
  /// list (Spotify lists widest first; width may be null).
  static Uri? image(Object? images, {int targetPx = ArtworkSizing.standard}) {
    final list = asJsonMapList(images);
    if (list.isEmpty) return null;
    final sized = <int, Object?>{
      for (final i in list)
        if (jsonInt(i['width']) != null) jsonInt(i['width'])!: i['url'],
    };
    return ArtworkSizing.pick(sized, targetPx: targetPx) ?? jsonHttpUri(list.first['url']);
  }
}
