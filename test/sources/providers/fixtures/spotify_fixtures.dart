// Spotify Web API fixtures.
//
// HAND-WRITTEN from the official reference's documented response shapes
// (https://developer.spotify.com/documentation/web-api/reference/ — Get
// Playlist, Get Playlist Items (`/playlists/{id}/items`, item objects with
// `item` and the deprecated `track` alias), Get Current User's Playlists,
// Get User's Saved Tracks, Search for Item, Get Track; fetched 2026-10-27).
// Not recorded from the live API (it needs a registered app + Premium owner).

Map<String, Object?> spImage(int size) => {
  'url': 'https://i.scdn.co/image/ab67616d0000b273-$size',
  'height': size,
  'width': size,
};

Map<String, Object?> spArtist(String id, String name) => {
  'external_urls': {'spotify': 'https://open.spotify.com/artist/$id'},
  'href': 'https://api.spotify.com/v1/artists/$id',
  'id': id,
  'name': name,
  'type': 'artist',
  'uri': 'spotify:artist:$id',
};

/// TrackObject.
Map<String, Object?> spTrack({
  String id = '11dFghVXANMlKmJXsNCbNl',
  String name = 'Cut To The Feeling',
  String? isrc = 'USUM71703861',
  bool explicit = false,
  int durationMs = 207959,
}) => {
  'album': {
    'album_type': 'single',
    'total_tracks': 1,
    'external_urls': {'spotify': 'https://open.spotify.com/album/0tGPJ0bkWOUmH7MEOR77qc'},
    'href': 'https://api.spotify.com/v1/albums/0tGPJ0bkWOUmH7MEOR77qc',
    'id': '0tGPJ0bkWOUmH7MEOR77qc',
    'images': [spImage(640), spImage(300), spImage(64)],
    'name': 'Cut To The Feeling',
    'release_date': '2017-05-26',
    'release_date_precision': 'day',
    'type': 'album',
    'uri': 'spotify:album:0tGPJ0bkWOUmH7MEOR77qc',
    'artists': [spArtist('6sFIWsNpZYqfjUpaCgueju', 'Carly Rae Jepsen')],
  },
  'artists': [spArtist('6sFIWsNpZYqfjUpaCgueju', 'Carly Rae Jepsen'), spArtist('0000000000000000000002', 'Guest')],
  'disc_number': 1,
  'duration_ms': durationMs,
  'explicit': explicit,
  'external_ids': {'isrc': ?isrc},
  'external_urls': {'spotify': 'https://open.spotify.com/track/$id'},
  'href': 'https://api.spotify.com/v1/tracks/$id',
  'id': id,
  'is_playable': true,
  'name': name,
  'track_number': 1,
  'type': 'track',
  'uri': 'spotify:track:$id',
  'is_local': false,
};

/// A "local file" inside a playlist (no id, `spotify:local:` URI).
Map<String, Object?> spLocalTrack() => {
  'album': {'name': 'Local Album', 'images': <Object?>[], 'artists': <Object?>[]},
  'artists': [
    {'name': 'Local Artist', 'type': 'artist'},
  ],
  'duration_ms': 180000,
  'id': null,
  'is_local': true,
  'name': 'Home Recording',
  'type': 'track',
  'uri': 'spotify:local:Local+Artist:Local+Album:Home+Recording:180',
};

/// Episode inside a playlist (skipped by Fermata).
Map<String, Object?> spEpisode() => {'id': '512ojhOuo1ktJprKbVcKyQ', 'name': 'A podcast', 'type': 'episode'};

/// Paging object.
Map<String, Object?> spPaging(List<Object?> items, {required int total, int offset = 0, int limit = 50, String? next}) => {
  'href': 'https://api.spotify.com/v1/x?offset=$offset&limit=$limit',
  'limit': limit,
  'next': next,
  'offset': offset,
  'previous': null,
  'total': total,
  'items': items,
};

/// PlaylistTrackObject (`item` + deprecated `track` alias).
Map<String, Object?> spPlaylistItem(Map<String, Object?> item) => {
  'added_at': '2026-01-02T03:04:05Z',
  'added_by': {'id': 'ada', 'type': 'user'},
  'is_local': item['is_local'] ?? false,
  'item': item,
  'track': item,
};

/// Playlist object. [withItems] false = a playlist the user does not own
/// (dev mode: "the items field will be absent").
Map<String, Object?> spPlaylist({
  String id = '3cEYpjA9oz9GiPac4AsH4n',
  String name = 'Spotify Web API Testing playlist',
  String ownerId = 'ada',
  bool collaborative = false,
  bool withItems = true,
  int total = 3,
}) => {
  'collaborative': collaborative,
  'description': 'A playlist for testing pourposes',
  'external_urls': {'spotify': 'https://open.spotify.com/playlist/$id'},
  'href': 'https://api.spotify.com/v1/playlists/$id',
  'id': id,
  'images': [spImage(640)],
  'name': name,
  'owner': {
    'external_urls': {'spotify': 'https://open.spotify.com/user/$ownerId'},
    'id': ownerId,
    'type': 'user',
    'uri': 'spotify:user:$ownerId',
    'display_name': ownerId == 'ada' ? 'Ada' : 'Someone Else',
  },
  'public': true,
  'snapshot_id': 'MTY4NzE5ODU3OSwwMDAw',
  if (withItems) 'items': {'href': 'https://api.spotify.com/v1/playlists/$id/items', 'total': total},
  'type': 'playlist',
  'uri': 'spotify:playlist:$id',
};

Map<String, Object?> spMe() => {
  'display_name': 'Ada',
  'id': 'ada',
  'account_id': 'acc-ada',
  'images': [spImage(300)],
  'type': 'user',
  'uri': 'spotify:user:ada',
};

Map<String, Object?> spError(int status, String message) => {
  'error': {'status': status, 'message': message},
};
