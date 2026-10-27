import 'dart:async';

import 'package:logging/logging.dart';

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
import 'audius_api.dart';
import 'audius_mapper.dart';

final _log = Logger('sources.audius');

/// Audius — open, artist-first catalog with full streaming and no account.
///
/// Uses the public REST API (see [AudiusApi]); an optional API key from the
/// [CredentialsStore] (`audius` → `apiKey`, e.g. `FERMATA_AUDIUS_API_KEY`)
/// raises rate limits. Downloads only for tracks whose artist enabled them,
/// via the official download endpoint, and only when the user asks
/// (`SourcePolicies`).
class AudiusSource extends MusicSourceBase {
  AudiusSource({required FermataHttp http, this._credentials, Uri? baseUri}) {
    api = AudiusApi(http, apiKey: () => _credentials?.get(SourceIds.audius)?.apiKey, baseUri: baseUri);
  }

  final CredentialsStore? _credentials;

  /// Request builder (exposed for tests and diagnostics).
  late final AudiusApi api;

  /// Re-check availability before playing/downloading when older than this.
  static const availabilityMaxAge = Duration(minutes: 10);

  @override
  String get id => SourceIds.audius;

  @override
  String get displayName => 'Audius';

  @override
  Set<SourceCapability> get capabilities => const {
    SourceCapability.searchTracks,
    SourceCapability.searchArtists,
    SourceCapability.searchAlbums,
    SourceCapability.searchPlaylists,
    SourceCapability.stream,
    SourceCapability.download,
    SourceCapability.playlistImport,
    SourceCapability.isrcLookup,
    SourceCapability.relatedTracks,
    SourceCapability.trending,
    SourceCapability.artistPages,
    SourceCapability.albumPages,
    SourceCapability.genres,
    SourceCapability.newReleases,
  };

  @override
  String get limitationsNote =>
      'Audius is an open music platform: search, browse and full-length streaming work without an account. '
      'Tracks an artist locked behind a purchase or follow cannot be played (a 30-second preview is used when one '
      'exists). Downloads are only offered for tracks the artist made downloadable, one track at a time. '
      'Signing in with an Audius account is not supported.';

  @override
  Uri? get termsUrl => Uri.parse('https://audius.co/legal/terms-of-use');

  @override
  CredentialStatus get credentialStatus {
    final origin = _credentials?.originOf(id) ?? CredentialOrigin.none;
    return CredentialStatus(configured: true, origin: origin, helpUrl: Uri.parse('https://api.audius.co/plans'));
  }

  // ---- Search -------------------------------------------------------------

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    final offset = PageCursor.decodeOffset(cursor);
    final data = await api.getData(
      'tracks/search',
      query: {'query': query.trim(), 'limit': limit, 'offset': offset},
      cancel: cancel,
    );
    final raw = asJsonMapList(data);
    return PageCursor.offsetPage(AudiusMapper.tracks(raw), offset: offset, limit: limit, consumed: raw.length);
  }

  @override
  Future<Page<Artist>> searchArtists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    final offset = PageCursor.decodeOffset(cursor);
    final data = await api.getData(
      'users/search',
      query: {'query': query.trim(), 'limit': limit, 'offset': offset},
      cancel: cancel,
    );
    final raw = asJsonMapList(data);
    return PageCursor.offsetPage(AudiusMapper.artists(raw), offset: offset, limit: limit, consumed: raw.length);
  }

  /// Albums only appear in the "full" search (`kind=albums`).
  @override
  Future<Page<Album>> searchAlbums(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    final offset = PageCursor.decodeOffset(cursor);
    final data = await api.getData(
      'search/full',
      query: {'query': query.trim(), 'kind': 'albums', 'limit': limit, 'offset': offset},
      cancel: cancel,
    );
    final raw = asJsonMapList(asJsonMap(data)['albums']);
    return PageCursor.offsetPage(AudiusMapper.albums(raw), offset: offset, limit: limit, consumed: raw.length);
  }

  @override
  Future<Page<Playlist>> searchPlaylists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    final offset = PageCursor.decodeOffset(cursor);
    final data = await api.getData(
      'playlists/search',
      query: {'query': query.trim(), 'limit': limit, 'offset': offset},
      cancel: cancel,
    );
    final raw = asJsonMapList(data);
    return PageCursor.offsetPage(AudiusMapper.playlists(raw), offset: offset, limit: limit, consumed: raw.length);
  }

  // ---- Browse -------------------------------------------------------------

  @override
  Future<Track?> getTrack(String sourceTrackId, {CancelToken? cancel}) async {
    final data = await api.getDataOrNull('tracks/${Uri.encodeComponent(sourceTrackId)}', cancel: cancel);
    return AudiusMapper.track(data);
  }

  @override
  Future<Artist?> getArtist(String sourceArtistId, {CancelToken? cancel}) async {
    final data = await api.getDataOrNull('users/${Uri.encodeComponent(sourceArtistId)}', cancel: cancel);
    return AudiusMapper.artist(data);
  }

  /// The artist's tracks, most played first.
  @override
  Future<Page<Track>> artistTopTracks(
    String sourceArtistId, {
    String? cursor,
    int limit = 30,
    CancelToken? cancel,
  }) async {
    final offset = PageCursor.decodeOffset(cursor);
    final data = await api.getData(
      'users/${Uri.encodeComponent(sourceArtistId)}/tracks',
      query: {'sort': 'plays', 'limit': limit, 'offset': offset},
      cancel: cancel,
    );
    final raw = asJsonMapList(data);
    return PageCursor.offsetPage(AudiusMapper.tracks(raw), offset: offset, limit: limit, consumed: raw.length);
  }

  @override
  Future<List<Artist>> relatedArtists(String sourceArtistId, {int limit = 12, CancelToken? cancel}) async {
    final data = await api.getData(
      'users/${Uri.encodeComponent(sourceArtistId)}/related',
      query: {'limit': limit},
      cancel: cancel,
    );
    return AudiusMapper.artists(data).take(limit).toList();
  }

  /// Albums are playlists on Audius; all tracks come in one page.
  @override
  Future<Page<Track>> albumTracks(String sourceAlbumId, {String? cursor, CancelToken? cancel}) async {
    final tracks = await _playlistTracks(sourceAlbumId, cancel: cancel);
    return Page(tracks, total: tracks.length);
  }

  /// [idOrUrl]: a playlist id (`DOPRl`) or an `audius.co/<handle>/playlist/…`
  /// / `…/album/…` URL (resolved with `/resolve`).
  @override
  Future<PlaylistDetail> getPlaylist(String idOrUrl, {String? cursor, CancelToken? cancel}) async {
    final input = idOrUrl.trim();
    final Object? data;
    if (_looksLikeUrl(input)) {
      data = await api.getData('resolve', query: {'url': _normaliseUrl(input)}, cancel: cancel);
    } else {
      data = await api.getDataOrNull('playlists/${Uri.encodeComponent(input)}', cancel: cancel);
    }
    final json = data is List ? (data.isEmpty ? null : data.first) : data;
    final map = asJsonMapOrNull(json);
    final playlist = AudiusMapper.playlist(map);
    if (map == null || playlist == null) {
      throw ApiException(404, 'Audius playlist not found: $input');
    }
    final embedded = map['tracks'];
    final tracks = embedded is List && embedded.isNotEmpty
        ? AudiusMapper.tracks(embedded)
        : await _playlistTracks(playlist.sourcePlaylistId!, cancel: cancel);
    return PlaylistDetail(
      playlist: playlist,
      tracks: Page(tracks, total: tracks.length),
    );
  }

  Future<List<Track>> _playlistTracks(String playlistId, {CancelToken? cancel}) async {
    final data = await api.getData('playlists/${Uri.encodeComponent(playlistId)}/tracks', cancel: cancel);
    return AudiusMapper.tracks(data);
  }

  static bool _looksLikeUrl(String s) => s.contains('audius.co') || s.startsWith('http') || s.contains('/');

  static String _normaliseUrl(String s) =>
      s.startsWith('http') ? s : 'https://${s.startsWith('/') ? 'audius.co$s' : s}';

  /// Audius has no related-tracks endpoint (docs/COMPLIANCE.md): uses the
  /// most played tracks of artists related to the track's artist.
  @override
  Future<List<Track>> relatedTracks(String sourceTrackId, {int limit = 20, CancelToken? cancel}) async {
    final track = await getTrack(sourceTrackId, cancel: cancel);
    final artistId = track?.artists.firstOrNull?.sourceArtistId;
    if (track == null || artistId == null) return const [];
    final related = await relatedArtists(artistId, limit: 4, cancel: cancel);
    if (related.isEmpty) return const [];
    final perArtist = (limit / related.length).ceil().clamp(1, 10);
    final lists = await Future.wait(
      related.map((a) async {
        try {
          return (await artistTopTracks(a.sourceArtistId, limit: perArtist, cancel: cancel)).items;
        } on FermataException catch (e) {
          if (e is OperationCanceledException) rethrow;
          _log.fine('Related tracks: skipping ${a.sourceArtistId}: ${e.code}');
          return const <Track>[];
        }
      }),
    );
    // Interleave so one artist does not dominate.
    final result = <Track>[];
    for (var i = 0; result.length < limit; i++) {
      var added = false;
      for (final l in lists) {
        if (i < l.length && result.length < limit) {
          final t = l[i];
          if (t.availability.isPlayableInApp && t.sourceTrackId != sourceTrackId) result.add(t);
          added = true;
        }
      }
      if (!added) break;
    }
    return result;
  }

  @override
  Future<List<Track>> trending({String? genre, int limit = 30, CancelToken? cancel}) async {
    final data = await api.getData(
      'tracks/trending',
      query: {'limit': limit, if (genre != null && genre.trim().isNotEmpty) 'genre': genre.trim()},
      cancel: cancel,
    );
    return AudiusMapper.tracks(data);
  }

  @override
  Future<List<Album>> newReleases({int limit = 20, CancelToken? cancel}) async {
    final data = await api.getData('playlists/new-releases', query: {'type': 'album', 'limit': limit}, cancel: cancel);
    return AudiusMapper.albums(data);
  }

  @override
  Future<List<String>> genres({CancelToken? cancel}) async {
    final data = await api.getData('genres/popular', query: {'limit': 50}, cancel: cancel);
    return AudiusMapper.genres(data);
  }

  @override
  Future<Track?> lookupByIsrc(String isrc, {CancelToken? cancel}) async {
    final code = isrc.trim().toUpperCase();
    if (code.isEmpty) return null;
    final data = await api.getDataOrNull('tracks', query: {'isrc': code}, cancel: cancel);
    final tracks = AudiusMapper.tracks(data);
    return tracks.where((t) => t.isrc?.toUpperCase() == code).firstOrNull ?? tracks.firstOrNull;
  }

  // ---- Playback & downloads ---------------------------------------------

  /// Re-reads the track when its availability is stale; null if deleted.
  Future<Track?> _fresh(Track track, CancelToken? cancel) async {
    if (!Availabilities.isStale(track.availability, maxAge: availabilityMaxAge)) return track;
    return getTrack(track.sourceTrackId, cancel: cancel);
  }

  @override
  Future<PlayableSource> resolveStream(
    Track track, {
    AudioQuality quality = AudioQuality.high,
    CancelToken? cancel,
  }) async {
    checkOwnTrack(track);
    final fresh = await _fresh(track, cancel);
    if (fresh == null) throw UnplayableTrackException(track.id, AvailabilityReason.deleted);
    Availabilities.ensurePlayable(fresh);
    final preview = fresh.availability.playback == PlaybackRights.preview;
    // Audius serves one MP3 rendition; [quality] has no effect.
    return PlayableSource(
      uri: api.streamUri(fresh.sourceTrackId, preview: preview),
      isPreview: preview,
      mimeType: 'audio/mpeg',
    );
  }

  /// Only for tracks the artist made downloadable and that are not
  /// download-gated; availability is always re-checked first.
  @override
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel}) async {
    checkOwnTrack(track);
    final fresh = await getTrack(track.sourceTrackId, cancel: cancel);
    if (fresh == null || fresh.availability.offline != OfflineRights.downloadable) return null;
    return DownloadAuthorization(
      uri: api.downloadUri(fresh.sourceTrackId),
      headers: api.downloadHeaders,
      suggestedFileExtension: fresh.extra[AudiusMapper.extraOrigExt] ?? 'mp3',
    );
  }

  @override
  Uri? externalPlaybackUri(Track track) => track.sourceId == id ? track.permalink : null;
}
