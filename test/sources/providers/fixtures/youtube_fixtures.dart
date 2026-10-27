// YouTube Data API v3 fixtures.
//
// HAND-WRITTEN from the official reference's documented resource shapes
// (https://developers.google.com/youtube/v3/docs — search.list,
// videos.list, playlists.list, playlistItems.list, channels.list and the
// documented error format with `errors[].reason`; fetched 2026-10-27). Not
// recorded from the live API, which needs a Google Cloud project.

Map<String, Object?> ytThumbs(String id) => {
  'default': {'url': 'https://i.ytimg.com/vi/$id/default.jpg', 'width': 120, 'height': 90},
  'medium': {'url': 'https://i.ytimg.com/vi/$id/mqdefault.jpg', 'width': 320, 'height': 180},
  'high': {'url': 'https://i.ytimg.com/vi/$id/hqdefault.jpg', 'width': 480, 'height': 360},
  'standard': {'url': 'https://i.ytimg.com/vi/$id/sddefault.jpg', 'width': 640, 'height': 480},
};

Map<String, Object?> ytSnippet(
  String id, {
  required String title,
  required String channel,
  String channelId = 'UCchannel000000000000000',
  String description = '',
  String categoryId = '10',
}) => {
  'publishedAt': '2017-05-26T04:00:01Z',
  'channelId': channelId,
  'title': title,
  'description': description,
  'thumbnails': ytThumbs(id),
  'channelTitle': channel,
  'categoryId': categoryId,
  'liveBroadcastContent': 'none',
};

/// `videos` resource.
Map<String, Object?> ytVideo(
  String id, {
  String title = 'Carly Rae Jepsen - Cut To The Feeling (Official Video)',
  String channel = 'CarlyRaeJepsenVEVO',
  String duration = 'PT3M28S',
  String description = '',
  String categoryId = '10',
}) => {
  'kind': 'youtube#video',
  'etag': 'etag-$id',
  'id': id,
  'snippet': ytSnippet(id, title: title, channel: channel, description: description, categoryId: categoryId),
  'contentDetails': {
    'duration': duration,
    'dimension': '2d',
    'definition': 'hd',
    'caption': 'false',
    'licensedContent': true,
    'contentRating': <String, Object?>{},
    'projection': 'rectangular',
  },
};

/// `search` result (snippet titles are HTML-escaped).
Map<String, Object?> ytSearchResult(String id, {String title = 'Carly Rae Jepsen - Cut To The Feeling', String channel = 'CarlyRaeJepsenVEVO'}) => {
  'kind': 'youtube#searchResult',
  'etag': 'etag-s-$id',
  'id': {'kind': 'youtube#video', 'videoId': id},
  'snippet': {
    ...ytSnippet(id, title: title, channel: channel),
    'publishTime': '2017-05-26T04:00:01Z',
  }..remove('categoryId'),
};

Map<String, Object?> ytList(String kind, List<Object?> items, {String? next, int? total}) => {
  'kind': 'youtube#$kind',
  'etag': 'etag-list',
  'nextPageToken': ?next,
  'pageInfo': {'totalResults': total ?? items.length, 'resultsPerPage': items.length},
  'items': items,
};

/// `playlistItems` entry.
Map<String, Object?> ytPlaylistItem(
  String videoId, {
  String playlistId = 'PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf',
  String title = 'Carly Rae Jepsen - Cut To The Feeling (Official Video)',
  String? owner = 'CarlyRaeJepsenVEVO',
  String privacy = 'public',
  int position = 0,
}) => {
  'kind': 'youtube#playlistItem',
  'etag': 'etag-pi-$videoId',
  'id': 'item-$videoId',
  'snippet': {
    'publishedAt': '2026-01-01T00:00:00Z',
    'channelId': 'UCplaylistowner000000000',
    'title': title,
    'description': '',
    'thumbnails': ytThumbs(videoId),
    'channelTitle': 'Ada',
    'playlistId': playlistId,
    'position': position,
    'resourceId': {'kind': 'youtube#video', 'videoId': videoId},
    'videoOwnerChannelTitle': ?owner,
    'videoOwnerChannelId': ?(owner == null ? null : 'UCowner00000000000000000'),
  },
  'contentDetails': {'videoId': videoId, 'videoPublishedAt': '2017-05-26T04:00:01Z'},
  'status': {'privacyStatus': privacy},
};

/// `playlists` resource.
Map<String, Object?> ytPlaylist(String id, {String title = 'Road trip', int count = 3}) => {
  'kind': 'youtube#playlist',
  'etag': 'etag-p-$id',
  'id': id,
  'snippet': {
    'publishedAt': '2025-03-01T10:00:00Z',
    'channelId': 'UCplaylistowner000000000',
    'title': title,
    'description': 'Songs for the road',
    'thumbnails': ytThumbs('cover'),
    'channelTitle': 'Ada',
  },
  'contentDetails': {'itemCount': count},
};

/// `channels?mine=true` with the related "likes" playlist.
Map<String, Object?> ytMyChannel() => ytList('channelListResponse', [
  {
    'kind': 'youtube#channel',
    'id': 'UCada0000000000000000000',
    'snippet': {'title': 'Ada', 'thumbnails': ytThumbs('ada')},
    'contentDetails': {
      'relatedPlaylists': {'likes': 'LL', 'uploads': 'UUada0000000000000000000'},
    },
  },
]);

Map<String, Object?> ytError(int code, String reason, {String domain = 'youtube.quota'}) => {
  'error': {
    'code': code,
    'message': 'The request cannot be completed because you have exceeded your quota.',
    'errors': [
      {'message': 'The request cannot be completed because you have exceeded your quota.', 'domain': domain, 'reason': reason},
    ],
  },
};

/// Auto-generated "Art Track" description (YouTube Music uploads).
const ytArtTrackDescription = '''Provided to YouTube by Universal Music Group

Cut To The Feeling · Carly Rae Jepsen

Cut To The Feeling

℗ 2017 School Boy/Interscope Records

Released on: 2017-05-26

Auto-generated by YouTube.''';
