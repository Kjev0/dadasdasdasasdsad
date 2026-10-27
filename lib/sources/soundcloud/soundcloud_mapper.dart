import '../../core/models/catalog.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../base/artwork.dart';
import '../base/availability.dart';
import '../base/json_utils.dart';
import 'soundcloud_links.dart';

/// Maps SoundCloud API JSON (OpenAPI `Track`, `User`, `Playlist`; verified
/// 2026-10-27 against developers.soundcloud.com/docs/api/explorer/api.json)
/// to Fermata models.
///
/// Availability follows the documented `access` field (authoritative for the
/// caller), with the legacy `policy` and `streamable` fields as fallbacks:
///
/// | API | Fermata |
/// |---|---|
/// | `access: playable` | full stream, **stream-only** offline |
/// | `access: preview` (or `policy: SNIP`) | 30 s preview |
/// | `access: blocked` (or `policy: BLOCK`) | unavailable, `region_restricted` |
/// | no `access`, `streamable: false` | unavailable, `not_streamable` |
///
/// SoundCloud audio is **never** downloadable in Fermata (API Terms: no
/// offline access "regardless of whether Uploaders have set that User
/// Content as allowed to be downloaded"); the uploader's `downloadable`
/// flag is only kept in [extraUploaderAllowsDownload] for display.
abstract final class SoundCloudMapper {
  static const _id = SourceIds.soundcloud;

  static const extraUrn = 'soundcloud.urn';
  static const extraUserUrn = 'soundcloud.userUrn';
  static const extraUploader = 'soundcloud.uploader';
  static const extraUploaderUrl = 'soundcloud.uploaderUrl';
  static const extraAccess = 'soundcloud.access';
  static const extraLicense = 'soundcloud.license';
  static const extraSharing = 'soundcloud.sharing';
  static const extraSecretToken = 'soundcloud.secretToken';
  static const extraUploaderAllowsDownload = 'soundcloud.uploaderDownloadable';
  static const extraLabel = 'soundcloud.label';

  /// SoundCloud previews are 30-second snippets.
  static const previewDuration = Duration(seconds: 30);

  // ---- Tracks ---------------------------------------------------------------

  /// A track, or null when the object has no URN/id or no title.
  static Track? track(Object? json, {DateTime? now, String? secretToken}) {
    final t = asJsonMapOrNull(json);
    if (t == null) return null;
    final kind = jsonString(t['kind']);
    if (kind != null && kind != 'track') return null;
    final urn = _urn(t, 'tracks');
    final title = jsonString(t['title']);
    if (urn == null || title == null) return null;
    final user = asJsonMap(t['user']);
    final uploader = jsonString(user['username']);
    final userUrn = _urn(user, 'users') ?? jsonString(t['user_urn']);
    final durationMs = jsonInt(t['duration']);
    final permalink = jsonHttpUri(t['permalink_url']);
    final secret = secretToken ?? SoundCloudLinks.secretToken(jsonString(t['secret_uri']) ?? '');
    return Track(
      sourceId: _id,
      sourceTrackId: urn,
      title: title,
      artists: _artists(jsonString(t['metadata_artist']), uploader, userUrn),
      album: jsonString(t['release']),
      duration: durationMs == null || durationMs <= 0 ? null : Duration(milliseconds: durationMs),
      isrc: jsonString(t['isrc'])?.toUpperCase(),
      year: jsonInt(t['release_year']) ?? parseDate(t['created_at'])?.year,
      genre: jsonString(t['genre']),
      artworkUrl: artwork(t['artwork_url']) ?? artwork(user['avatar_url']),
      permalink: permalink,
      availability: availability(t, now: now),
      extra: {
        extraUrn: urn,
        extraUserUrn: ?userUrn,
        extraUploader: ?uploader,
        extraUploaderUrl: ?jsonHttpUri(user['permalink_url'])?.toString(),
        extraAccess: ?jsonString(t['access']),
        extraLicense: ?jsonString(t['license']),
        extraSharing: ?jsonString(t['sharing']),
        extraSecretToken: ?secret,
        extraLabel: ?jsonString(t['label_name']),
        if (jsonBool(t['downloadable']) == true) extraUploaderAllowsDownload: 'true',
      },
    );
  }

  static List<Track> tracks(Object? list, {DateTime? now}) => [
    for (final t in asJsonMapList(list)) ?track(t, now: now),
  ];

  /// Availability from `access` / `policy` / `streamable` (see class docs).
  static TrackAvailability availability(Map<String, Object?> t, {DateTime? now}) {
    final checkedAt = now ?? DateTime.now();
    final access = jsonString(t['access'])?.toLowerCase();
    // `policy` is not in the current OpenAPI schema; older responses carried
    // ALLOW / MONETIZE / SNIP / BLOCK. Honoured only when present.
    final policy = jsonString(t['policy'])?.toUpperCase();
    if (access == 'blocked' || policy == 'BLOCK') {
      return Availabilities.unavailable(AvailabilityReason.regionRestricted, checkedAt: checkedAt);
    }
    if (access == 'preview' || policy == 'SNIP') {
      return Availabilities.preview(previewDuration, checkedAt: checkedAt);
    }
    if (access == 'playable') return Availabilities.stream(checkedAt: checkedAt);
    final streamable = jsonBool(t['streamable']);
    if (streamable == false) {
      return Availabilities.unavailable(AvailabilityReason.notStreamable, checkedAt: checkedAt);
    }
    if (streamable == true) return Availabilities.stream(checkedAt: checkedAt);
    return const TrackAvailability.unknown();
  }

  /// `metadata_artist` ("artist name when it differs from the uploader") is
  /// split on commas into credited artists; the uploader's URN is attached to
  /// the first one so artist pages open the uploader's profile.
  static List<ArtistRef> _artists(String? metadataArtist, String? uploader, String? userUrn) {
    final names = metadataArtist == null
        ? <String>[?uploader]
        : metadataArtist.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return [
      for (var i = 0; i < names.length; i++) ArtistRef(names[i], sourceArtistId: i == 0 ? userUrn : null),
    ];
  }

  // ---- Users / playlists ---------------------------------------------------

  static Artist? artist(Object? json) {
    final u = asJsonMapOrNull(json);
    if (u == null) return null;
    final urn = _urn(u, 'users');
    final name = jsonString(u['username']) ?? jsonString(u['full_name']);
    if (urn == null || name == null) return null;
    return Artist(
      sourceId: _id,
      sourceArtistId: urn,
      name: name,
      avatarUrl: artwork(u['avatar_url']),
      permalink: jsonHttpUri(u['permalink_url']),
      followers: jsonInt(u['followers_count']),
      description: jsonString(u['description']),
    );
  }

  static List<Artist> artists(Object? list) => [for (final u in asJsonMapList(list)) ?artist(u)];

  static Playlist? playlist(Object? json) {
    final p = asJsonMapOrNull(json);
    if (p == null) return null;
    final urn = _urn(p, 'playlists');
    final title = jsonString(p['title']);
    if (urn == null || title == null) return null;
    final user = asJsonMap(p['user']);
    final embedded = asJsonMapList(p['tracks']);
    return Playlist(
      id: '$_id:$urn',
      name: title,
      kind: PlaylistKind.remote,
      description: jsonString(p['description']),
      artworkUrl:
          artwork(p['artwork_url']) ??
          (embedded.isEmpty ? null : artwork(embedded.first['artwork_url'])) ??
          artwork(user['avatar_url']),
      ownerName: jsonString(user['username']),
      sourceId: _id,
      sourcePlaylistId: urn,
      trackCount: jsonInt(p['track_count']),
      createdAt: parseDate(p['created_at']),
      updatedAt: parseDate(p['last_modified']),
      permalink: jsonHttpUri(p['permalink_url']),
    );
  }

  static List<Playlist> playlists(Object? list) => [for (final p in asJsonMapList(list)) ?playlist(p)];

  // ---- Helpers --------------------------------------------------------------

  /// The `urn` field, or a URN built from a legacy numeric `id`.
  static String? _urn(Map<String, Object?> json, String kind) {
    final urn = jsonString(json['urn']);
    if (urn != null && SoundCloudLinks.isUrn(urn)) return urn;
    final id = jsonString(json['id']);
    return id != null && RegExp(r'^\d+$').hasMatch(id) ? 'soundcloud:$kind:$id' : null;
  }

  /// Artwork in the requested size: SoundCloud serves `-large` (100 px) by
  /// default; `-t500x500` / `-original` are documented variants.
  static Uri? artwork(Object? raw, {int targetPx = ArtworkSizing.standard}) {
    final url = jsonHttpUri(raw);
    if (url == null) return null;
    final token = targetPx <= 100 ? '-large' : (targetPx <= 500 ? '-t500x500' : '-original');
    return ArtworkSizing.replaceSizeToken(url, '-large', token);
  }

  static final _date = RegExp(r'^(\d{4})[/-](\d{2})[/-](\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\s*([+-]\d{4}|Z))?$');

  /// Parses SoundCloud's `2019/01/15 15:40:49 +0000` as well as ISO-8601.
  static DateTime? parseDate(Object? value) {
    final s = jsonString(value);
    if (s == null) return null;
    final m = _date.firstMatch(s);
    if (m == null) return jsonDate(s);
    final utc = DateTime.utc(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
    final offset = m.group(7);
    if (offset == null || offset == 'Z') return utc;
    final sign = offset.startsWith('-') ? -1 : 1;
    final minutes = int.parse(offset.substring(1, 3)) * 60 + int.parse(offset.substring(3, 5));
    return utc.subtract(Duration(minutes: sign * minutes));
  }
}
