import 'dart:async';

import '../../core/contracts/auth.dart';
import '../../core/contracts/music_source.dart';
import '../../core/errors.dart';
import '../../core/models/auth.dart';
import '../../core/models/catalog.dart';
import '../../core/models/download.dart';
import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import '../../core/net/http_client.dart';
import '../../core/sources/source_ids.dart';
import '../../core/util/cancel_token.dart';
import '../base/availability.dart';
import '../base/json_utils.dart';
import '../base/music_source_base.dart';
import '../base/paging.dart';
import 'jamendo_api.dart';
import 'jamendo_links.dart';
import 'jamendo_mapper.dart';

/// Jamendo — independent music under Creative Commons licences, with
/// full-length streaming and artist-permitted downloads.
///
/// * Needs a free developer `clientId` (devportal.jamendo.com). Without it:
///   `credentialsMissing`, [isReady] false, every call throws
///   [MissingCredentialsException] before any request.
/// * No account connection (Jamendo's OAuth needs a client secret on a
///   server); everything here is public data.
/// * Downloads: single tracks, user-initiated, only when
///   `audiodownload_allowed` (`SourcePolicies`: user-initiated only).
class JamendoSource extends MusicSourceBase {
  JamendoSource({
    required FermataHttp http,
    required CredentialsStore credentials,
    Uri? apiBaseUri,
    DateTime Function()? clock,
  }) : _credentials = credentials,
       _clock = clock ?? DateTime.now,
       super(initialAuthState: _stateFor(credentials)) {
    api = JamendoApi(http, clientId: () => _credentials.get(SourceIds.jamendo)?.clientId, baseUri: apiBaseUri);
    _sub = credentials.changes
        .where((id) => id == SourceIds.jamendo)
        .listen((_) => emitAuthState(_stateFor(_credentials)));
  }

  static final helpUrl = Uri.parse('https://devportal.jamendo.com/');

  /// Re-check availability before playing/downloading when older than this.
  static const availabilityMaxAge = Duration(minutes: 30);

  /// Jamendo's featured genre selections (tracks documentation: "lounge,
  /// classical, electronic, jazz, pop, hiphop, relaxation, rock, songwriter,
  /// world, metal, soundtrack").
  static const featuredGenres = [
    'lounge',
    'classical',
    'electronic',
    'jazz',
    'pop',
    'hiphop',
    'relaxation',
    'rock',
    'songwriter',
    'world',
    'metal',
    'soundtrack',
  ];

  /// Both singles and album tracks ("by default we return only albumtracks").
  static const _bothTypes = 'single albumtrack';
  static const _include = 'licenses musicinfo';
  static const _listFormat = 'mp32';
  static const _imageSize = 500;

  final CredentialsStore _credentials;
  final DateTime Function() _clock;
  late final StreamSubscription<String> _sub;

  /// Request layer (exposed for tests and diagnostics).
  late final JamendoApi api;

  static SourceAuthState _stateFor(CredentialsStore c) {
    final id = c.get(SourceIds.jamendo)?.clientId;
    return id == null || id.trim().isEmpty
        ? const SourceAuthState(status: SourceConnectionStatus.credentialsMissing)
        : const SourceAuthState.notRequired();
  }

  @override
  String get id => SourceIds.jamendo;

  @override
  String get displayName => 'Jamendo';

  @override
  Set<SourceCapability> get capabilities => const {
    SourceCapability.searchTracks,
    SourceCapability.searchArtists,
    SourceCapability.searchAlbums,
    SourceCapability.searchPlaylists,
    SourceCapability.stream,
    SourceCapability.download,
    SourceCapability.playlistImport,
    SourceCapability.relatedTracks,
    SourceCapability.trending,
    SourceCapability.artistPages,
    SourceCapability.albumPages,
    SourceCapability.genres,
    SourceCapability.newReleases,
  };

  @override
  String get limitationsNote =>
      'Jamendo offers independent music under Creative Commons licences. Search, browsing and full-length '
      'streaming need a free Jamendo developer client ID (devportal.jamendo.com). Tracks can be downloaded one at '
      'a time when the artist allows it. Free API use is for non-commercial purposes only; each track shows its '
      'licence and links back to Jamendo. Signing in to a Jamendo account is not supported.';

  @override
  Uri? get termsUrl => Uri.parse('https://devportal.jamendo.com/api_terms_of_use');

  @override
  CredentialStatus get credentialStatus {
    final configured = api.clientId != null;
    return CredentialStatus(
      configured: configured,
      origin: _credentials.originOf(id),
      missing: configured ? const [] : const ['clientId'],
      helpUrl: helpUrl,
    );
  }

  @override
  Future<void> init() async => emitAuthState(_stateFor(_credentials));

  void _ensure() {
    if (api.clientId == null) throw MissingCredentialsException(id, const ['clientId']);
  }

  int _limit(int limit) => limit.clamp(1, 200);

  Future<Page<Track>> _trackPage(
    Map<String, Object?> query, {
    String? cursor,
    int limit = 30,
    CancelToken? cancel,
  }) async {
    _ensure();
    final offset = PageCursor.decodeOffset(cursor);
    final results = await api.get(
      'tracks',
      query: {
        ...query,
        'type': _bothTypes,
        'include': _include,
        'audioformat': _listFormat,
        'imagesize': _imageSize,
        'limit': _limit(limit),
        'offset': offset,
      },
      cancel: cancel,
    );
    return PageCursor.offsetPage(
      JamendoMapper.tracks(results.items, audioFormat: _listFormat, now: _clock()),
      offset: offset,
      limit: _limit(limit),
      total: results.fullCount,
      consumed: results.items.length,
    );
  }

  Future<Page<T>> _page<T>(
    String method,
    Map<String, Object?> query,
    T? Function(Object?) map, {
    String? cursor,
    required int limit,
    CancelToken? cancel,
  }) async {
    _ensure();
    final offset = PageCursor.decodeOffset(cursor);
    final results = await api.get(method, query: {...query, 'limit': _limit(limit), 'offset': offset}, cancel: cancel);
    return PageCursor.offsetPage(
      [for (final r in results.items) ?map(r)],
      offset: offset,
      limit: _limit(limit),
      consumed: results.items.length,
    );
  }

  // ---- Search -------------------------------------------------------------

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    _ensure();
    if (query.trim().isEmpty) return const Page.empty();
    return _trackPage({'search': query.trim()}, cursor: cursor, limit: limit, cancel: cancel);
  }

  @override
  Future<Page<Artist>> searchArtists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    _ensure();
    if (query.trim().isEmpty) return const Page.empty();
    return _page(
      'artists',
      {'namesearch': query.trim()},
      JamendoMapper.artist,
      cursor: cursor,
      limit: limit,
      cancel: cancel,
    );
  }

  @override
  Future<Page<Album>> searchAlbums(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    _ensure();
    if (query.trim().isEmpty) return const Page.empty();
    return _page(
      'albums',
      {'namesearch': query.trim(), 'imagesize': _imageSize},
      JamendoMapper.album,
      cursor: cursor,
      limit: limit,
      cancel: cancel,
    );
  }

  @override
  Future<Page<Playlist>> searchPlaylists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    _ensure();
    if (query.trim().isEmpty) return const Page.empty();
    return _page(
      'playlists',
      {'namesearch': query.trim()},
      JamendoMapper.playlist,
      cursor: cursor,
      limit: limit,
      cancel: cancel,
    );
  }

  // ---- Browse -------------------------------------------------------------

  /// [sourceTrackId]: a numeric id or a jamendo.com / jamen.do track link.
  @override
  Future<Track?> getTrack(String sourceTrackId, {CancelToken? cancel}) =>
      _fetchTrack(sourceTrackId, audioFormat: _listFormat, cancel: cancel);

  Future<Track?> _fetchTrack(
    String idOrUrl, {
    required String audioFormat,
    String? downloadFormat,
    CancelToken? cancel,
  }) async {
    _ensure();
    final trackId = JamendoLinks.idOf(idOrUrl, JamendoLinkKind.track);
    if (trackId == null) return null;
    final results = await api.get(
      'tracks',
      query: {
        'id': trackId,
        'type': _bothTypes,
        'include': _include,
        'audioformat': audioFormat,
        'audiodlformat': ?downloadFormat,
        'imagesize': _imageSize,
      },
      cancel: cancel,
    );
    return JamendoMapper.track(results.items.firstOrNull, audioFormat: audioFormat, now: _clock());
  }

  @override
  Future<Artist?> getArtist(String sourceArtistId, {CancelToken? cancel}) async {
    _ensure();
    final artistId = JamendoLinks.idOf(sourceArtistId, JamendoLinkKind.artist);
    if (artistId == null) return null;
    final results = await api.get('artists', query: {'id': artistId}, cancel: cancel);
    return JamendoMapper.artist(results.items.firstOrNull);
  }

  /// The artist's tracks by all-time popularity.
  @override
  Future<Page<Track>> artistTopTracks(String sourceArtistId, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    _ensure();
    final artistId = JamendoLinks.idOf(sourceArtistId, JamendoLinkKind.artist) ?? sourceArtistId;
    return _trackPage(
      {'artist_id': artistId, 'order': 'popularity_total'},
      cursor: cursor,
      limit: limit,
      cancel: cancel,
    );
  }

  /// Jamendo has no related-artists method: the artists of tracks similar
  /// (`tracks/similar`, tag-based) to this artist's most popular track.
  @override
  Future<List<Artist>> relatedArtists(String sourceArtistId, {int limit = 12, CancelToken? cancel}) async {
    _ensure();
    final top = await artistTopTracks(sourceArtistId, limit: 1, cancel: cancel);
    final seed = top.items.firstOrNull;
    if (seed == null) return const [];
    final results = await api.get(
      'tracks/similar',
      query: {'id': seed.sourceTrackId, 'no_artist': sourceArtistId, 'limit': 50},
      cancel: cancel,
    );
    final seen = <String>{sourceArtistId};
    final artists = <Artist>[];
    for (final t in results.items) {
      final artistId = jsonString(t['artist_id']);
      final name = jsonString(t['artist_name']);
      if (artistId == null || name == null || !seen.add(artistId)) continue;
      artists.add(
        Artist(
          sourceId: id,
          sourceArtistId: artistId,
          name: name,
          permalink: Uri.parse('https://www.jamendo.com/artist/$artistId'),
        ),
      );
      if (artists.length >= limit) break;
    }
    return artists;
  }

  /// All tracks of an album (`albums/tracks`), in album order.
  @override
  Future<Page<Track>> albumTracks(String sourceAlbumId, {String? cursor, CancelToken? cancel}) async {
    _ensure();
    final albumId = JamendoLinks.idOf(sourceAlbumId, JamendoLinkKind.album);
    if (albumId == null) throw ArgumentError.value(sourceAlbumId, 'sourceAlbumId', 'Not a Jamendo album id or link');
    final results = await api.get(
      'albums/tracks',
      query: {'id': albumId, 'track_type': _bothTypes, 'audioformat': _listFormat, 'imagesize': _imageSize},
      cancel: cancel,
    );
    final album = results.items.firstOrNull;
    if (album == null) throw ApiException(404, 'Jamendo album $albumId not found');
    final tracks = JamendoMapper.tracks(
      asJsonMapList(album['tracks']),
      album: album,
      audioFormat: _listFormat,
      now: _clock(),
    )..sort((a, b) => (a.trackNumber ?? 1 << 20).compareTo(b.trackNumber ?? 1 << 20));
    return Page(tracks, total: tracks.length);
  }

  /// [idOrUrl]: a playlist id or a jamendo.com/playlist/…, …/list/p…,
  /// jamen.do/l/p… link (`playlists/tracks`, one page).
  @override
  Future<PlaylistDetail> getPlaylist(String idOrUrl, {String? cursor, CancelToken? cancel}) async {
    _ensure();
    final playlistId = JamendoLinks.idOf(idOrUrl, JamendoLinkKind.playlist);
    if (playlistId == null) throw ArgumentError.value(idOrUrl, 'idOrUrl', 'Not a Jamendo playlist id or link');
    final results = await api.get(
      'playlists/tracks',
      query: {'id': playlistId, 'track_type': _bothTypes, 'audioformat': _listFormat, 'imagesize': _imageSize},
      cancel: cancel,
    );
    final json = results.items.firstOrNull;
    final playlist = JamendoMapper.playlist(json);
    if (json == null || playlist == null) throw ApiException(404, 'Jamendo playlist $playlistId not found');
    final tracks = JamendoMapper.tracks(asJsonMapList(json['tracks']), audioFormat: _listFormat, now: _clock());
    return PlaylistDetail(
      playlist: playlist,
      tracks: Page(tracks, total: tracks.length),
    );
  }

  @override
  Future<List<Track>> relatedTracks(String sourceTrackId, {int limit = 20, CancelToken? cancel}) async {
    _ensure();
    final trackId = JamendoLinks.idOf(sourceTrackId, JamendoLinkKind.track);
    if (trackId == null) return const [];
    final results = await api.get(
      'tracks/similar',
      query: {'id': trackId, 'limit': _limit(limit), 'audioformat': _listFormat, 'imagesize': _imageSize},
      cancel: cancel,
    );
    return JamendoMapper.tracks(
      results.items,
      audioFormat: _listFormat,
      now: _clock(),
    ).where((t) => t.sourceTrackId != trackId).toList();
  }

  /// Most popular tracks this week (one per artist), optionally by genre tag.
  @override
  Future<List<Track>> trending({String? genre, int limit = 30, CancelToken? cancel}) async {
    _ensure();
    final page = await _trackPage(
      {
        'order': 'popularity_week',
        'groupby': 'artist_id',
        if (genre != null && genre.trim().isNotEmpty) 'tags': genre.trim().toLowerCase(),
      },
      limit: limit,
      cancel: cancel,
    );
    return page.items;
  }

  @override
  Future<List<Album>> newReleases({int limit = 20, CancelToken? cancel}) async {
    final page = await _page(
      'albums',
      {'order': 'releasedate_desc', 'imagesize': _imageSize},
      JamendoMapper.album,
      limit: limit,
      cancel: cancel,
    );
    return page.items;
  }

  /// Jamendo's documented featured genre tags (no network request).
  @override
  Future<List<String>> genres({CancelToken? cancel}) async {
    _ensure();
    return featuredGenres;
  }

  // ---- Playback & downloads -------------------------------------------------

  /// `audioformat` per quality: low → mp31 (96 kbps), normal/high → mp32
  /// (VBR), lossless → flac (falls back to mp32 when not offered).
  static List<String> formatsFor(AudioQuality quality) => switch (quality) {
    AudioQuality.low => const ['mp31'],
    AudioQuality.normal || AudioQuality.high => const ['mp32'],
    AudioQuality.lossless => const ['flac', 'mp32'],
  };

  static String mimeFor(String format) => switch (format) {
    'ogg' => 'audio/ogg',
    'flac' => 'audio/flac',
    _ => 'audio/mpeg',
  };

  @override
  Future<PlayableSource> resolveStream(
    Track track, {
    AudioQuality quality = AudioQuality.high,
    CancelToken? cancel,
  }) async {
    checkOwnTrack(track);
    _ensure();
    final formats = formatsFor(quality);
    var current = track;
    final stale = Availabilities.isStale(track.availability, maxAge: availabilityMaxAge);
    if (stale || track.extra[JamendoMapper.extraAudioFormat] != formats.first) {
      Track? fresh;
      for (final format in formats) {
        fresh = await _fetchTrack(track.sourceTrackId, audioFormat: format, cancel: cancel);
        if (fresh == null) throw UnplayableTrackException(track.id, AvailabilityReason.deleted);
        if (fresh.extra[JamendoMapper.extraAudio] != null) break;
      }
      current = fresh!;
    }
    Availabilities.ensurePlayable(current);
    final audio = current.extra[JamendoMapper.extraAudio];
    if (audio == null) throw UnplayableTrackException(track.id, AvailabilityReason.notStreamable);
    return PlayableSource(
      uri: Uri.parse(audio),
      mimeType: mimeFor(current.extra[JamendoMapper.extraAudioFormat] ?? 'mp31'),
    );
  }

  /// Re-checks the track; returns the official `audiodownload` URL only when
  /// the artist allows downloads (`audiodownload_allowed`).
  @override
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel}) async {
    checkOwnTrack(track);
    _ensure();
    final fresh = await _fetchTrack(
      track.sourceTrackId,
      audioFormat: _listFormat,
      downloadFormat: 'mp32',
      cancel: cancel,
    );
    final url = fresh?.extra[JamendoMapper.extraDownload];
    if (fresh == null || url == null || fresh.availability.offline != OfflineRights.downloadable) return null;
    return DownloadAuthorization(uri: Uri.parse(url), suggestedFileExtension: 'mp3');
  }

  @override
  Uri? externalPlaybackUri(Track track) => track.sourceId == id ? track.permalink : null;

  @override
  Future<void> dispose() async {
    await _sub.cancel();
    await super.dispose();
  }
}
