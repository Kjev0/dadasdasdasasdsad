// Jamendo API v3 fixtures.
//
// HAND-WRITTEN from the official documentation's documented response shapes:
// the "Response:" samples of https://developer.jamendo.com/v3.0/albums/tracks,
// /artists/tracks, /albums, /artists and /playlists (copied, fetched
// 2026-10-27), the `tracks` field list of /v3.0/tracks (audio,
// audiodownload, audiodownload_allowed, album_*, image, …) and the error
// header format of /v3.0/response-codes. Not recorded from the live API
// (every call needs a registered client_id).

Map<String, Object?> jmHeaders({int count = 1, int code = 0, String message = ''}) => {
  'status': code == 0 ? 'success' : 'failed',
  'code': code,
  'error_message': message,
  'warnings': '',
  'results_count': count,
};

Map<String, Object?> jmEnvelope(List<Map<String, Object?>> results) => {
  'headers': jmHeaders(count: results.length),
  'results': results,
};

Map<String, Object?> jmError(int code, String message) => {
  'headers': jmHeaders(count: 0, code: code, message: message),
  'results': <Object?>[],
};

/// A `/tracks` result.
Map<String, Object?> jmTrack({
  String id = '887209',
  String name = 'Scene 5',
  bool downloadAllowed = true,
  String format = 'mp32',
  bool single = false,
}) => {
  'id': id,
  'name': name,
  'duration': '325',
  'artist_id': '376782',
  'artist_name': 'WE ARE FM',
  'artist_idstr': 'we_are_fm',
  'album_name': single ? '' : 'Season One',
  'album_id': single ? '' : '104336',
  'license_ccurl': 'http://creativecommons.org/licenses/by-nc-sa/3.0/',
  'position': '5',
  'releasedate': '2011-12-29',
  'album_image': single ? '' : 'https://usercontent.jamendo.com?type=album&id=104336&width=500&trackid=$id',
  'audio': 'https://prod-1.storage.jamendo.com/?trackid=$id&format=$format&from=app-devsite',
  'audiodownload': downloadAllowed ? 'https://prod-1.storage.jamendo.com/download/track/$id/mp32/' : '',
  'audiodownload_allowed': downloadAllowed,
  'shorturl': 'https://jamen.do/t/$id',
  'shareurl': 'https://www.jamendo.com/track/$id',
  'image': 'https://usercontent.jamendo.com?type=album&id=104336&width=500&trackid=$id',
  'musicinfo': {
    'vocalinstrumental': 'vocal',
    'tags': {
      'genres': ['electronic', 'pop'],
      'instruments': <Object?>[],
      'vartags': <Object?>[],
    },
  },
};

/// Documented `albums/tracks` sample (shortened to three tracks).
Map<String, Object?> jmAlbumTracks() => jmEnvelope([
  {
    'id': '104336',
    'name': 'Season One',
    'releasedate': '2011-12-29',
    'artist_id': '376782',
    'artist_name': 'WE ARE FM',
    'track_id': '887202',
    'image': 'https://usercontent.jamendo.com?type=album&id=104336&width=300&trackid=887202',
    'zip': 'https://storage.jamendo.com/download/a104336/mp32/',
    'zip_allowed': true,
    'tracks': [
      {
        'count': '1',
        'id': '887202',
        'position': '10',
        'name': 'Press Record',
        'duration': '192',
        'license_ccurl': 'http://creativecommons.org/licenses/by-nc-sa/3.0/',
        'audio': 'https://prod-1.storage.jamendo.com/?trackid=887202&format=mp31&from=app-devsite',
        'audiodownload': 'https://prod-1.storage.jamendo.com/download/track/887202/mp32/',
        'audiodownload_allowed': true,
      },
      {
        'count': '1',
        'id': '887203',
        'position': '3',
        'name': "No Words (Director's Cut)",
        'duration': '338',
        'license_ccurl': 'http://creativecommons.org/licenses/by-nc-sa/3.0/',
        'audio': 'https://prod-1.storage.jamendo.com/?trackid=887203&format=mp31&from=app-devsite',
        'audiodownload': '',
        'audiodownload_allowed': false,
      },
      {
        'count': '1',
        'id': '887204',
        'position': '2',
        'name': 'Dance',
        'duration': '211',
        'license_ccurl': 'http://creativecommons.org/licenses/by-nc-sa/3.0/',
        'audio': 'https://prod-1.storage.jamendo.com/?trackid=887204&format=mp31&from=app-devsite',
        'audiodownload': 'https://prod-1.storage.jamendo.com/download/track/887204/mp32/',
        'audiodownload_allowed': true,
      },
    ],
  },
]);

/// Documented `artists` sample.
Map<String, Object?> jmArtists() => jmEnvelope([
  {
    'id': '376782',
    'name': 'WE ARE FM',
    'website': 'https://www.facebook.com/wearefm',
    'joindate': '2011-12-29',
    'image': 'https://usercontent.jamendo.com?type=artist&id=376782&width=300',
    'shorturl': 'https://jamen.do/a/376782',
    'shareurl': 'https://www.jamendo.com/artist/376782',
  },
]);

/// Documented `albums` sample.
Map<String, Object?> jmAlbums() => jmEnvelope([
  {
    'id': '104336',
    'name': 'Season One',
    'releasedate': '2011-12-29',
    'artist_id': '376782',
    'artist_name': 'WE ARE FM',
    'image': 'https://usercontent.jamendo.com?type=album&id=104336&width=300',
    'zip': 'https://storage.jamendo.com/download/a104336/mp32/',
    'shorturl': 'https://jamen.do/l/a104336',
    'shareurl': 'https://www.jamendo.com/list/a104336',
    'zip_allowed': true,
  },
  {
    'id': '124067',
    'name': 'Season One: Instrumental',
    'releasedate': '2013-08-01',
    'artist_id': '376782',
    'artist_name': 'WE ARE FM',
    'image': 'https://usercontent.jamendo.com?type=album&id=124067&width=300',
    'zip': 'https://storage.jamendo.com/download/a124067/mp32/',
    'shorturl': 'https://jamen.do/l/a124067',
    'shareurl': 'https://www.jamendo.com/list/a124067',
    'zip_allowed': true,
  },
]);

/// `playlists/tracks`: the documented `playlists` object plus a `tracks`
/// list (same sub-entity shape as `albums/tracks`; the method's own page is
/// no longer published).
Map<String, Object?> jmPlaylistTracks() => jmEnvelope([
  {
    'id': '218277',
    'name': 'some cool stuff',
    'creationdate': '2012-01-04',
    'user_id': '1293438',
    'user_name': 'hywayace',
    'zip': 'https://storage.jamendo.com/download/p218277/mp32/',
    'shorturl': 'https://jamen.do/l/p218277',
    'shareurl': 'https://www.jamendo.com/list/p218277',
    'tracks': [
      jmTrack(id: '1', name: 'One'),
      jmTrack(id: '2', name: 'Two', downloadAllowed: false),
    ],
  },
]);
