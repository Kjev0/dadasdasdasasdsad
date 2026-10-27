import '../../core/models/catalog.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../base/artwork.dart';
import '../base/availability.dart';
import '../base/json_utils.dart';
import 'youtube_links.dart';
import 'youtube_metadata.dart';

/// Maps YouTube Data API v3 resources (`videos`, `playlistItems`,
/// `playlists`) to Fermata models. All tracks are
/// [PlaybackRights.externalOnly]: YouTube's policies forbid extracting or
/// separately playing the audio, so Fermata opens them in YouTube Music.
abstract final class YouTubeMapper {
  static const _id = SourceIds.youtube;

  static const extraChannelId = 'youtube.channelId';
  static const extraChannelTitle = 'youtube.channelTitle';
  static const extraRawTitle = 'youtube.rawTitle';
  static const extraCategoryId = 'youtube.categoryId';

  /// YouTube's "Music" video category (`videoCategories.list`).
  static const musicCategoryId = '10';

  /// Thumbnail keys and their documented widths.
  static const _thumbWidths = {'default': 120, 'medium': 320, 'high': 480, 'standard': 640, 'maxres': 1280};

  static Uri? thumbnail(Object? thumbnails, {int targetPx = ArtworkSizing.standard}) {
    final map = asJsonMap(thumbnails);
    final candidates = <int, Object?>{};
    map.forEach((key, value) {
      final t = asJsonMap(value);
      final width = jsonInt(t['width']) ?? _thumbWidths[key];
      if (width != null) candidates[width] = t['url'];
    });
    return ArtworkSizing.pick(candidates, targetPx: targetPx);
  }

  /// A track from a `videos` resource (snippet + contentDetails).
  static Track? video(Object? json, {DateTime? now}) {
    final v = asJsonMapOrNull(json);
    if (v == null) return null;
    final id = jsonString(v['id']);
    final snippet = asJsonMap(v['snippet']);
    final rawTitle = jsonString(snippet['title']);
    if (id == null || !YouTubeLinks.isVideoId(id) || rawTitle == null) return null;
    return _track(
      id,
      rawTitle,
      snippet,
      channelId: jsonString(snippet['channelId']),
      channelTitle: jsonString(snippet['channelTitle']),
      duration: YouTubeMetadataParser.parseDuration(jsonString(asJsonMap(v['contentDetails'])['duration'])),
      now: now,
    );
  }

  /// A track from a `search` result (no duration — the source joins
  /// `videos` for that).
  static Track? searchResult(Object? json, {DateTime? now}) {
    final r = asJsonMapOrNull(json);
    if (r == null) return null;
    final id = jsonString(asJsonMap(r['id'])['videoId']);
    final snippet = asJsonMap(r['snippet']);
    final rawTitle = jsonString(snippet['title']);
    if (id == null || rawTitle == null) return null;
    return _track(
      id,
      _unescapeHtml(rawTitle),
      snippet,
      channelId: jsonString(snippet['channelId']),
      channelTitle: jsonString(snippet['channelTitle']),
      now: now,
    );
  }

  /// A track from a `playlistItems` entry. Deleted / private videos keep a
  /// placeholder entry in playlists; they map to unavailable tracks.
  static Track? playlistItem(Object? json, {DateTime? now}) {
    final item = asJsonMapOrNull(json);
    if (item == null) return null;
    final snippet = asJsonMap(item['snippet']);
    final videoId =
        jsonString(asJsonMap(item['contentDetails'])['videoId']) ??
        jsonString(asJsonMap(snippet['resourceId'])['videoId']);
    final rawTitle = jsonString(snippet['title']);
    if (videoId == null || rawTitle == null) return null;
    final privacy = jsonString(asJsonMap(item['status'])['privacyStatus']);
    final ownerTitle = jsonString(snippet['videoOwnerChannelTitle']);
    final checkedAt = now ?? DateTime.now();
    if (rawTitle == 'Deleted video' || rawTitle == 'Private video' || privacy == 'privacyStatusUnspecified') {
      final private = rawTitle == 'Private video' || privacy == 'private';
      return Track(
        sourceId: _id,
        sourceTrackId: videoId,
        title: rawTitle,
        permalink: YouTubeLinks.watchUrl(videoId),
        availability: Availabilities.unavailable(
          private ? AvailabilityReason.private : AvailabilityReason.deleted,
          checkedAt: checkedAt,
        ),
      );
    }
    return _track(
      videoId,
      rawTitle,
      snippet,
      channelId: jsonString(snippet['videoOwnerChannelId']),
      channelTitle: ownerTitle,
      now: now,
    );
  }

  static Track _track(
    String id,
    String rawTitle,
    Map<String, Object?> snippet, {
    String? channelId,
    String? channelTitle,
    Duration? duration,
    DateTime? now,
  }) {
    final meta = YouTubeMetadataParser.parse(
      rawTitle,
      channelTitle: channelTitle,
      description: jsonString(snippet['description']),
    );
    return Track(
      sourceId: _id,
      sourceTrackId: id,
      title: meta.title,
      artists: [
        for (var i = 0; i < meta.artists.length; i++)
          ArtistRef(meta.artists[i], sourceArtistId: i == 0 && meta.artistFromChannel ? channelId : null),
      ],
      album: meta.album,
      year: meta.year,
      duration: duration,
      artworkUrl: thumbnail(snippet['thumbnails']),
      permalink: YouTubeLinks.watchUrl(id),
      availability: Availabilities.externalOnly(checkedAt: now),
      extra: {
        extraChannelId: ?channelId,
        extraChannelTitle: ?channelTitle,
        extraRawTitle: rawTitle,
        extraCategoryId: ?jsonString(snippet['categoryId']),
      },
    );
  }

  static Playlist? playlist(Object? json) {
    final p = asJsonMapOrNull(json);
    if (p == null) return null;
    final id = jsonString(p['id']);
    final snippet = asJsonMap(p['snippet']);
    final title = jsonString(snippet['title']);
    if (id == null || title == null) return null;
    return Playlist(
      id: '$_id:$id',
      name: title,
      kind: PlaylistKind.remote,
      description: jsonString(snippet['description']),
      artworkUrl: thumbnail(snippet['thumbnails']),
      ownerName: jsonString(snippet['channelTitle']),
      sourceId: _id,
      sourcePlaylistId: id,
      trackCount: jsonInt(asJsonMap(p['contentDetails'])['itemCount']),
      createdAt: jsonDate(snippet['publishedAt']),
      permalink: YouTubeLinks.playlistUrl(id),
    );
  }

  /// `search` snippets are HTML-escaped (`&amp;`, `&#39;`, `&quot;`).
  static String _unescapeHtml(String s) => s
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}
