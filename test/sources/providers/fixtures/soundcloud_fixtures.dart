// SoundCloud API fixtures.
//
// HAND-WRITTEN from the official documentation's documented response shapes
// (OpenAPI spec https://developers.soundcloud.com/docs/api/explorer/api.json,
// `components.examples` Track / User / Playlist / Streams / Tracks /
// NotFound / TooManyRequests / ExpiringToken, fetched 2026-10-27) — not
// recorded from the live API, which needs credentials. Values are varied per
// test; field names and nesting follow the documented examples exactly.

/// Documented `User` example, parameterised.
Map<String, Object?> scUser({
  String urn = 'soundcloud:users:12345',
  String username = 'some.user',
  String permalink = 'permalink',
}) => {
  'avatar_url': 'https://i1.sndcdn.com/avatars-000-large.jpg',
  'city': 'City',
  'country': 'Country',
  'created_at': '2018/01/01 12:08:25 +0000',
  'description': null,
  'followers_count': 42,
  'followings_count': 0,
  'full_name': 'Full Name',
  'urn': urn,
  'kind': 'user',
  'last_modified': '2020/01/03 12:08:25 +0000',
  'permalink': permalink,
  'permalink_url': 'https://soundcloud.com/$permalink',
  'plan': 'Free',
  'playlist_count': 3,
  'public_favorites_count': 20,
  'reposts_count': 0,
  'station_urn': 'soundcloud:system-playlists:artist-stations:12345',
  'track_count': 7,
  'uri': 'https://api.soundcloud.com/users/$urn',
  'username': username,
  'website': null,
  'website_title': null,
};

/// Documented `Track` example, parameterised.
Map<String, Object?> scTrack({
  String urn = 'soundcloud:tracks:1234',
  String title = 'Some title',
  String? access = 'playable',
  bool streamable = true,
  bool downloadable = false,
  String? metadataArtist = 'Metro Boomin, The Weeknd, 21 Savage',
  String? isrc,
  String? policy,
  Map<String, Object?>? user,
  int duration = 40000,
}) => {
  'kind': 'track',
  'artwork_url': 'https://i1.sndcdn.com/artworks-000-large.jpg',
  'available_country_codes': null,
  'bpm': null,
  'comment_count': 4,
  'commentable': true,
  'created_at': '2019/01/15 15:40:49 +0000',
  'description': null,
  'download_count': 0,
  'download_url': downloadable ? 'https://api.soundcloud.com/tracks/1234/download' : null,
  'downloadable': downloadable,
  'duration': duration,
  'embeddable_by': 'all',
  'favoritings_count': 271,
  'genre': 'Rock',
  'urn': urn,
  'isrc': isrc,
  'key_signature': null,
  'label_name': 'some label',
  'license': 'all-rights-reserved',
  'metadata_artist': metadataArtist,
  'permalink_url': 'https://soundcloud.com/userPermalink/trackPermalink',
  'playback_count': 8027,
  'purchase_title': null,
  'purchase_url': null,
  'release': null,
  'release_day': 22,
  'release_month': 8,
  'release_year': 2019,
  'reposts_count': 18,
  'secret_uri': null,
  'sharing': 'public',
  'stream_url': 'https://api.soundcloud.com/tracks/1234/stream',
  'streamable': streamable,
  'tag_list': '',
  'title': title,
  'uri': 'https://api.soundcloud.com/tracks/$urn',
  'user': user ?? scUser(),
  'user_favorite': true,
  'user_playback_count': 1,
  'waveform_url': 'https://wave.sndcdn.com/someString.png',
  'access': access,
  'policy': ?policy,
  'reveal_stats': true,
  'reveal_comments': true,
  'station_urn': 'soundcloud:system-playlists:track-stations:1234',
};

/// Documented `Playlist` example, parameterised.
Map<String, Object?> scPlaylist({
  String urn = 'soundcloud:playlists:12345',
  String title = 'permalink',
  int trackCount = 2,
  List<Map<String, Object?>>? tracks,
}) => {
  'artwork_url': '',
  'created_at': '2020/07/16 16:09:54 +0000',
  'description': null,
  'downloadable': true,
  'duration': 11000,
  'ean': null,
  'embeddable_by': 'all',
  'genre': '',
  'urn': urn,
  'kind': 'playlist',
  'label': null,
  'label_id': null,
  'label_name': null,
  'last_modified': '2020/09/08 09:13:00 +0000',
  'license': 'all-rights-reserved',
  'likes_count': 0,
  'permalink': 'permalink',
  'permalink_url': 'https://soundcloud.com/userPermalink/sets/permalink',
  'playlist_type': '',
  'sharing': 'public',
  'streamable': true,
  'tag_list': '',
  'tags': '',
  'title': title,
  'track_count': trackCount,
  'tracks': ?tracks,
  'tracks_uri': 'https://api.soundcloud.com/playlists/$urn/tracks',
  'type': '',
  'uri': 'https://api.soundcloud.com/playlists/$urn',
  'user': scUser(),
};

/// `linked_partitioning` collection (documented `Tracks` / `Playlists` /
/// `Users` shape).
Map<String, Object?> scCollection(List<Map<String, Object?>> items, {String? nextHref}) => {
  'collection': items,
  'next_href': ?nextHref,
};

/// Documented `Streams` example with distinct URLs per variant.
Map<String, Object?> scStreams({bool aac160 = true, bool aac96 = false, bool mp3 = true, bool preview = true}) => {
  if (aac160) 'hls_aac_160_url': 'https://api.soundcloud.com/tracks/urn/streams/aac160/',
  if (aac96) 'hls_aac_96_url': 'https://api.soundcloud.com/tracks/urn/streams/aac96/',
  if (mp3) 'hls_mp3_128_url': 'https://api.soundcloud.com/tracks/urn/streams/mp3128/',
  if (preview) 'preview_mp3_128_url': 'https://api.soundcloud.com/tracks/urn/streams/preview/',
};

/// Documented `ExpiringToken` example.
Map<String, Object?> scToken(String access, {String refresh = 'app-refresh'}) => {
  'access_token': access,
  'expires_in': 3599,
  'scope': '',
  'refresh_token': refresh,
  'token_type': 'bearer',
};

/// Documented error bodies.
Map<String, Object?> scError(int code) => {
  'code': code,
  'message': 'Detailed message of errors, when available',
  'link': 'https://developers.soundcloud.com/docs/api/explorer/open-api',
};
