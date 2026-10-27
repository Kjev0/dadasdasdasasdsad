import 'package:path/path.dart' as p;

import '../../core/models/catalog.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../base/artwork.dart';
import '../base/availability.dart';
import '../base/json_utils.dart';

/// Maps Audius API JSON (fields verified against live responses on
/// 2026-10-27, see test/sources/core/fixtures/audius_*.json) to Fermata
/// models.
abstract final class AudiusMapper {
  static const webBase = 'https://audius.co';

  /// Audius previews of purchase-gated tracks are 30-second clips.
  static const previewLength = Duration(seconds: 30);

  /// `extra` keys.
  static const extraHandle = 'audius.handle';
  static const extraUserId = 'audius.userId';
  static const extraOrigExt = 'audius.origExt';

  static Uri? permalinkOf(Object? path) {
    final s = jsonString(path);
    if (s == null) return null;
    if (s.startsWith('http')) return Uri.tryParse(s);
    return Uri.tryParse('$webBase${s.startsWith('/') ? '' : '/'}${Uri.encodeFull(s)}');
  }

  static Uri? artworkOf(Object? artwork, {int targetPx = ArtworkSizing.standard}) {
    final map = asJsonMapOrNull(artwork);
    return map == null ? null : ArtworkSizing.pickFromSizeKeyedMap(map, targetPx: targetPx);
  }

  /// Availability rules (see docs/COMPLIANCE.md):
  /// * deleted track, deactivated uploader or `is_available == false` →
  ///   unavailable (`deleted`);
  /// * stream-gated without access (purchase / follow / tip / NFT gates) →
  ///   30 s preview when the track has one, otherwise unavailable with
  ///   `subscription_required`;
  /// * `is_streamable == false` → unavailable (`not_streamable`);
  /// * otherwise full streaming; downloadable only when the artist enabled
  ///   downloads (`is_downloadable`) and download access is granted
  ///   (`access.download`, i.e. not download-gated).
  static TrackAvailability availabilityOf(Map<String, Object?> t, {DateTime? checkedAt}) {
    final at = checkedAt ?? DateTime.now();
    final user = asJsonMap(t['user']);
    final access = asJsonMapOrNull(t['access']);
    if (jsonBool(t['is_delete']) == true ||
        jsonBool(user['is_deactivated']) == true ||
        jsonBool(t['is_available']) == false) {
      return Availabilities.unavailable(AvailabilityReason.deleted, checkedAt: at);
    }
    final downloadable = jsonBool(t['is_downloadable']) == true &&
        (access == null ? jsonBool(t['is_download_gated']) != true : jsonBool(access['download']) == true);
    final streamGated = jsonBool(t['is_stream_gated']) == true;
    final canStream = access == null ? !streamGated : jsonBool(access['stream']) == true;
    if (!canStream) {
      final hasPreview = t['preview'] != null || jsonString(t['preview_cid']) != null;
      return hasPreview
          ? Availabilities.preview(previewLength, reason: AvailabilityReason.subscriptionRequired, checkedAt: at)
          : Availabilities.unavailable(AvailabilityReason.subscriptionRequired, checkedAt: at);
    }
    if (jsonBool(t['is_streamable']) == false) {
      return Availabilities.unavailable(AvailabilityReason.notStreamable, downloadable: downloadable, checkedAt: at);
    }
    return Availabilities.stream(downloadable: downloadable, checkedAt: at);
  }

  static Track? track(Object? json, {DateTime? checkedAt}) {
    final t = asJsonMapOrNull(json);
    if (t == null) return null;
    final id = jsonString(t['id']);
    final title = jsonString(t['title']);
    if (id == null || title == null) return null;
    final user = asJsonMap(t['user']);
    final userName = jsonString(user['name']) ?? jsonString(user['handle']);
    final userId = jsonString(user['id']) ?? jsonString(t['user_id']);
    final album = asJsonMapOrNull(t['album_backlink']);
    final origName = jsonString(t['orig_filename']);
    final origExt = origName == null ? null : p.extension(origName).replaceFirst('.', '').toLowerCase();
    final duration = jsonInt(t['duration']);
    return Track(
      sourceId: SourceIds.audius,
      sourceTrackId: id,
      title: title,
      artists: userName == null ? const [] : [ArtistRef(userName, sourceArtistId: userId)],
      album: album == null ? null : jsonString(album['playlist_name']),
      duration: duration == null || duration <= 0 ? null : Duration(seconds: duration),
      isrc: jsonString(t['isrc']),
      year: jsonYear(t['release_date']),
      genre: jsonString(t['genre']),
      artworkUrl: artworkOf(t['artwork']),
      permalink: permalinkOf(t['permalink']),
      availability: availabilityOf(t, checkedAt: checkedAt),
      extra: {
        if (jsonString(user['handle']) != null) extraHandle: jsonString(user['handle'])!,
        extraUserId: ?userId,
        if (origExt != null && origExt.isNotEmpty && jsonBool(t['is_original_available']) == true)
          extraOrigExt: origExt,
      },
    );
  }

  static List<Track> tracks(Object? data, {DateTime? checkedAt}) {
    final now = checkedAt ?? DateTime.now();
    return [for (final e in asJsonMapList(data)) ?track(e, checkedAt: now)];
  }

  static Artist? artist(Object? json) {
    final u = asJsonMapOrNull(json);
    if (u == null) return null;
    final id = jsonString(u['id']);
    final name = jsonString(u['name']) ?? jsonString(u['handle']);
    if (id == null || name == null) return null;
    final handle = jsonString(u['handle']);
    return Artist(
      sourceId: SourceIds.audius,
      sourceArtistId: id,
      name: name,
      avatarUrl: artworkOf(u['profile_picture']),
      permalink: handle == null ? null : Uri.parse('$webBase/${Uri.encodeComponent(handle)}'),
      followers: jsonInt(u['follower_count']),
      description: jsonString(u['bio']),
    );
  }

  static List<Artist> artists(Object? data) => [for (final e in asJsonMapList(data)) ?artist(e)];

  static Playlist? playlist(Object? json) {
    final pl = asJsonMapOrNull(json);
    if (pl == null) return null;
    final id = jsonString(pl['id']);
    final name = jsonString(pl['playlist_name']);
    if (id == null || name == null) return null;
    final user = asJsonMap(pl['user']);
    return Playlist(
      id: '${SourceIds.audius}:$id',
      name: name,
      kind: PlaylistKind.remote,
      description: jsonString(pl['description']),
      artworkUrl: artworkOf(pl['artwork']),
      ownerName: jsonString(user['name']) ?? jsonString(user['handle']),
      sourceId: SourceIds.audius,
      sourcePlaylistId: id,
      trackCount: jsonInt(pl['track_count']),
      createdAt: jsonDate(pl['created_at']),
      updatedAt: jsonDate(pl['updated_at']),
      permalink: permalinkOf(pl['permalink']),
    );
  }

  static List<Playlist> playlists(Object? data) => [for (final e in asJsonMapList(data)) ?playlist(e)];

  /// Audius albums are playlists with `is_album == true`.
  static Album? album(Object? json) {
    final pl = asJsonMapOrNull(json);
    if (pl == null) return null;
    final id = jsonString(pl['id']);
    final title = jsonString(pl['playlist_name']);
    if (id == null || title == null) return null;
    final user = asJsonMap(pl['user']);
    final userName = jsonString(user['name']) ?? jsonString(user['handle']);
    return Album(
      sourceId: SourceIds.audius,
      sourceAlbumId: id,
      title: title,
      artists: userName == null ? const [] : [ArtistRef(userName, sourceArtistId: jsonString(user['id']))],
      artworkUrl: artworkOf(pl['artwork']),
      year: jsonYear(pl['release_date']),
      trackCount: jsonInt(pl['track_count']),
      permalink: permalinkOf(pl['permalink']),
      upc: jsonString(pl['upc']),
    );
  }

  static List<Album> albums(Object? data) => [for (final e in asJsonMapList(data)) ?album(e)];

  /// Genre names from `/genres/popular`.
  static List<String> genres(Object? data) => [for (final e in asJsonMapList(data)) ?jsonString(e['name'])];
}
