import 'dart:async';

import '../../core/contracts/music_source.dart';
import '../../core/errors.dart';
import '../../core/models/catalog.dart';
import '../../core/models/download.dart';
import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import '../../core/net/http_client.dart';
import '../../core/sources/source_ids.dart';
import '../../core/sources/source_policies.dart';
import '../../core/util/cancel_token.dart';
import '../base/json_utils.dart';
import '../base/music_source_base.dart';
import '../base/paging.dart';
import '../base/rate_limiter.dart';
import 'deezer_api.dart';
import 'deezer_links.dart';
import 'deezer_mapper.dart';

/// Deezer via its public, unauthenticated API: rich metadata (the best
/// ISRC resolver available without auth), 30-second previews in-app and
/// "Open in Deezer" for full tracks. Never downloadable.
///
/// No account connection: new Deezer app registrations appear closed
/// (docs/research/API_NOTES.md §4.4), so `userLibrary` is not offered.
/// Public playlists of any Deezer profile can still be imported with
/// [publicUserPlaylists].
class DeezerSource extends MusicSourceBase {
  DeezerSource({required FermataHttp http, Uri? baseUri, TokenBucketRateLimiter? limiter, DateTime Function()? clock})
    : _http = http,
      _clock = clock ?? DateTime.now {
    api = DeezerApi(http, baseUri: baseUri, limiter: limiter);
  }

  final FermataHttp _http;
  final DateTime Function() _clock;

  /// Request layer (rate limiting, error-in-200 handling).
  late final DeezerApi api;

  static const _pageSize = 100;
  final _albumCache = _MetaCache();
  final _playlistCache = _MetaCache();
  Map<String, String>? _genreIds;

  @override
  String get id => SourceIds.deezer;

  @override
  String get displayName => 'Deezer';

  @override
  Set<SourceCapability> get capabilities => const {
    SourceCapability.searchTracks,
    SourceCapability.searchArtists,
    SourceCapability.searchAlbums,
    SourceCapability.searchPlaylists,
    SourceCapability.previewOnly,
    SourceCapability.externalPlayback,
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
      'Deezer allows third-party apps to play 30-second previews only; full tracks open in the Deezer app or '
      'website. Nothing from Deezer can be downloaded or stored offline. Connecting a Deezer account is not '
      'available because Deezer currently does not accept new developer apps — you can still import public '
      'playlists by pasting a playlist or profile link. Previews are for private, non-commercial listening.';

  @override
  Uri? get termsUrl => Uri.parse('https://developers.deezer.com/guidelines');

  // ---- Search -------------------------------------------------------------

  Future<Page<T>> _searchPage<T>(
    String path,
    String query,
    String? cursor,
    int limit,
    List<T> Function(Object? data) map,
    CancelToken? cancel,
  ) async {
    final q = query.trim();
    if (q.isEmpty) return Page<T>(const []);
    final offset = PageCursor.decodeOffset(cursor);
    final json = await api.get(path, query: {'q': q, 'index': offset, 'limit': limit}, cancel: cancel);
    return _page(json, offset: offset, limit: limit, map: map);
  }

  Page<T> _page<T>(
    Map<String, Object?> json, {
    required int offset,
    required int limit,
    required List<T> Function(Object?) map,
  }) {
    final raw = asJsonMapList(json['data']);
    return PageCursor.offsetPage(
      map(raw),
      offset: offset,
      limit: limit,
      total: jsonInt(json['total']),
      // Deezer includes `next` exactly when another page exists.
      hasMore: jsonString(json['next']) != null,
      consumed: raw.length,
    );
  }

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) =>
      _searchPage('search', query, cursor, limit, (d) => DeezerMapper.tracks(d, checkedAt: _clock()), cancel);

  @override
  Future<Page<Artist>> searchArtists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) =>
      _searchPage('search/artist', query, cursor, limit, DeezerMapper.artists, cancel);

  @override
  Future<Page<Album>> searchAlbums(String query, {String? cursor, int limit = 20, CancelToken? cancel}) =>
      _searchPage('search/album', query, cursor, limit, DeezerMapper.albums, cancel);

  @override
  Future<Page<Playlist>> searchPlaylists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) =>
      _searchPage('search/playlist', query, cursor, limit, DeezerMapper.playlists, cancel);

  // ---- Browse -------------------------------------------------------------

  static String _id(String raw) {
    final id = raw.trim();
    if (!RegExp(r'^\d+$').hasMatch(id)) throw FormatException('Not a Deezer id', raw);
    return id;
  }

  @override
  Future<Track?> getTrack(String sourceTrackId, {CancelToken? cancel}) async {
    final json = await api.getOrNull('track/${_id(sourceTrackId)}', cancel: cancel);
    return json == null ? null : DeezerMapper.track(json, checkedAt: _clock());
  }

  @override
  Future<Artist?> getArtist(String sourceArtistId, {CancelToken? cancel}) async {
    final json = await api.getOrNull('artist/${_id(sourceArtistId)}', cancel: cancel);
    return json == null ? null : DeezerMapper.artist(json);
  }

  @override
  Future<Page<Track>> artistTopTracks(
    String sourceArtistId, {
    String? cursor,
    int limit = 30,
    CancelToken? cancel,
  }) async {
    final offset = PageCursor.decodeOffset(cursor);
    final json = await api.get(
      'artist/${_id(sourceArtistId)}/top',
      query: {'index': offset, 'limit': limit},
      cancel: cancel,
    );
    return _page(
      json,
      offset: offset,
      limit: limit,
      map: (d) => DeezerMapper.tracks(d, checkedAt: _clock()),
    );
  }

  @override
  Future<List<Artist>> relatedArtists(String sourceArtistId, {int limit = 12, CancelToken? cancel}) async {
    final json = await api.get('artist/${_id(sourceArtistId)}/related', query: {'limit': limit}, cancel: cancel);
    return DeezerMapper.artists(json['data']).take(limit).toList();
  }

  @override
  Future<Page<Track>> albumTracks(String sourceAlbumId, {String? cursor, CancelToken? cancel}) async {
    final id = _id(sourceAlbumId);
    final offset = PageCursor.decodeOffset(cursor);
    final results = await Future.wait([
      // The cached request is shared between callers, so it must not carry
      // one caller's cancel token; each caller cancels its own wait.
      _albumCache.get(id, () => api.get('album/$id')),
      api.get('album/$id/tracks', query: {'index': offset, 'limit': _pageSize}, cancel: cancel),
    ]);
    final album = results[0];
    return _page(
      results[1],
      offset: offset,
      limit: _pageSize,
      map: (d) => DeezerMapper.tracks(d, album: album, checkedAt: _clock()),
    );
  }

  /// [idOrUrl]: numeric id, `deezer.com/<lang>/playlist/<id>`, or a short
  /// `link.deezer.com` / `deezer.page.link` share link (resolved by following
  /// redirects). Throws [FormatException] for links that are not playlists.
  @override
  Future<PlaylistDetail> getPlaylist(String idOrUrl, {String? cursor, CancelToken? cancel}) async {
    final id = await resolvePlaylistId(idOrUrl, cancel: cancel);
    final offset = PageCursor.decodeOffset(cursor);
    final results = await Future.wait([
      _playlistCache.get(id, () => api.get('playlist/$id', cancel: cancel)),
      api.get('playlist/$id/tracks', query: {'index': offset, 'limit': _pageSize}, cancel: cancel),
    ]);
    final playlist = DeezerMapper.playlist(results[0]);
    if (playlist == null) throw ApiException(404, 'Deezer playlist $id not found');
    final tracks = _page(
      results[1],
      offset: offset,
      limit: _pageSize,
      map: (d) => DeezerMapper.tracks(d, checkedAt: _clock()),
    );
    return PlaylistDetail(playlist: playlist, tracks: tracks);
  }

  /// Extracts the playlist id from [idOrUrl] (see [getPlaylist]).
  Future<String> resolvePlaylistId(String idOrUrl, {CancelToken? cancel}) async {
    final numeric = DeezerLinks.numericId(idOrUrl);
    if (numeric != null) return numeric;
    final link = await DeezerLinks.resolve(_http, idOrUrl, cancel: cancel);
    if (link == null || link.kind != DeezerLinkKind.playlist) {
      throw FormatException('Not a Deezer playlist link', idOrUrl);
    }
    return link.id;
  }

  /// Public playlists of a Deezer user, by profile URL
  /// (`deezer.com/<lang>/profile/<id>`, short links too) or user id. Works
  /// without OAuth; private playlists are not visible.
  Future<List<Playlist>> publicUserPlaylists(String profileUrlOrId, {int max = 500, CancelToken? cancel}) async {
    var userId = DeezerLinks.numericId(profileUrlOrId);
    if (userId == null) {
      final link = await DeezerLinks.resolve(_http, profileUrlOrId, cancel: cancel);
      if (link == null || link.kind != DeezerLinkKind.profile) {
        throw FormatException('Not a Deezer profile link', profileUrlOrId);
      }
      userId = link.id;
    }
    final result = <Playlist>[];
    var offset = 0;
    while (result.length < max) {
      final json = await api.get(
        'user/$userId/playlists',
        query: {'index': offset, 'limit': _pageSize},
        cancel: cancel,
      );
      final raw = asJsonMapList(json['data']);
      result.addAll(DeezerMapper.playlists(raw));
      offset += raw.length;
      final total = jsonInt(json['total']);
      if (raw.isEmpty || jsonString(json['next']) == null || (total != null && offset >= total)) break;
    }
    return result.take(max).toList();
  }

  /// Similar tracks from the artist's Deezer radio mix.
  @override
  Future<List<Track>> relatedTracks(String sourceTrackId, {int limit = 20, CancelToken? cancel}) async {
    final track = await getTrack(sourceTrackId, cancel: cancel);
    final artistId = track?.extra[DeezerMapper.extraArtistId];
    if (artistId == null) return const [];
    final Map<String, Object?> json;
    try {
      json = await api.get('artist/$artistId/radio', query: {'limit': limit + 1}, cancel: cancel);
    } on ApiException catch (e) {
      // Artists without a Deezer radio answer "no data" (mapped to 404).
      if (e.statusCode == 404) return const [];
      rethrow;
    }
    cancel?.throwIfCanceled();
    return DeezerMapper.tracks(
      json['data'],
      checkedAt: _clock(),
    ).where((t) => t.sourceTrackId != sourceTrackId).take(limit).toList();
  }

  /// The Deezer chart, optionally for a genre (name from [genres] or a
  /// numeric genre id).
  @override
  Future<List<Track>> trending({String? genre, int limit = 30, CancelToken? cancel}) async {
    var genreId = '0';
    final g = genre?.trim();
    if (g != null && g.isNotEmpty) {
      genreId =
          DeezerLinks.numericId(g) ??
          await _genreIdFor(g, cancel) ??
          (throw UnsupportedSourceOperation(id, 'trending', 'Deezer has no genre "$g"'));
    }
    final json = await api.get('chart/$genreId/tracks', query: {'limit': limit}, cancel: cancel);
    return DeezerMapper.tracks(json['data'], checkedAt: _clock());
  }

  Future<String?> _genreIdFor(String name, CancelToken? cancel) async {
    final ids = await _genres(cancel);
    final lower = name.toLowerCase();
    for (final e in ids.entries) {
      if (e.key.toLowerCase() == lower) return e.value;
    }
    return null;
  }

  Future<Map<String, String>> _genres(CancelToken? cancel) async =>
      _genreIds ??= DeezerMapper.genreIds((await api.get('genre', cancel: cancel))['data']);

  @override
  Future<List<String>> genres({CancelToken? cancel}) async => (await _genres(cancel)).keys.toList();

  /// Editorial new releases; when Deezer returns none (observed 2026-10),
  /// the editorial album selection is used instead.
  @override
  Future<List<Album>> newReleases({int limit = 20, CancelToken? cancel}) async {
    final releases = await api.get('editorial/0/releases', query: {'limit': limit}, cancel: cancel);
    var albums = DeezerMapper.albums(releases['data']);
    if (albums.isEmpty) {
      final selection = await api.get('editorial/0/selection', query: {'limit': limit}, cancel: cancel);
      albums = DeezerMapper.albums(selection['data']);
    }
    return albums.take(limit).toList();
  }

  @override
  Future<Track?> lookupByIsrc(String isrc, {CancelToken? cancel}) async {
    final code = isrc.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{12}$').hasMatch(code)) return null;
    final json = await api.getOrNull('track/isrc:$code', cancel: cancel);
    return json == null ? null : DeezerMapper.track(json, checkedAt: _clock());
  }

  // ---- Playback -----------------------------------------------------------

  /// Plays the 30 s preview. Preview URLs are signed and expire (~15 min),
  /// so the track is always re-fetched for a fresh URL; [PlayableSource.expiresAt]
  /// follows `SourcePolicies.of(deezer).previewUrlTtl` (or the URL's own
  /// expiry when earlier).
  @override
  Future<PlayableSource> resolveStream(
    Track track, {
    AudioQuality quality = AudioQuality.high,
    CancelToken? cancel,
  }) async {
    checkOwnTrack(track);
    final fresh = await getTrack(track.sourceTrackId, cancel: cancel);
    if (fresh == null) throw UnplayableTrackException(track.id, AvailabilityReason.deleted);
    if (fresh.availability.playback == PlaybackRights.unavailable) {
      throw UnplayableTrackException(track.id, fresh.availability.reason ?? AvailabilityReason.regionRestricted);
    }
    final preview = fresh.extra[DeezerMapper.extraPreview];
    if (preview == null) throw UnplayableTrackException(track.id, AvailabilityReason.externalOnly);
    final uri = Uri.parse(preview);
    return PlayableSource(uri: uri, isPreview: true, mimeType: 'audio/mpeg', expiresAt: previewExpiry(uri));
  }

  /// `now + previewUrlTtl`, or the `hdnea=exp=<unix>` time of the signed
  /// URL when that is earlier.
  DateTime previewExpiry(Uri uri) {
    final ttl = SourcePolicies.of(SourceIds.deezer).previewUrlTtl ?? const Duration(minutes: 12);
    final byPolicy = _clock().add(ttl);
    final m = RegExp(r'exp=(\d{9,11})').firstMatch(uri.query);
    if (m == null) return byPolicy;
    final signed = DateTime.fromMillisecondsSinceEpoch(int.parse(m.group(1)!) * 1000, isUtc: true);
    return signed.isBefore(byPolicy) ? signed : byPolicy;
  }

  @override
  Uri? externalPlaybackUri(Track track) =>
      track.sourceId == id ? (track.permalink ?? DeezerMapper.trackLink(track.sourceTrackId)) : null;

  /// Deezer forbids offline storage of any audio, previews included.
  @override
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel}) async => null;
}

/// Tiny LRU cache for album/playlist metadata used across track pages.
class _MetaCache {
  static const _max = 32;
  static const _ttl = Duration(minutes: 10);
  final _entries = <String, (DateTime, Future<Map<String, Object?>>)>{}; // insertion-ordered

  Future<Map<String, Object?>> get(String key, Future<Map<String, Object?>> Function() load) {
    final hit = _entries.remove(key);
    if (hit != null && DateTime.now().difference(hit.$1) < _ttl) {
      _entries[key] = hit;
      return hit.$2;
    }
    final future = load();
    _entries[key] = (DateTime.now(), future);
    // Failed loads must not be cached.
    unawaited(future.then<void>((_) {}, onError: (Object _) => _entries.remove(key)));
    while (_entries.length > _max) {
      _entries.remove(_entries.keys.first);
    }
    return future;
  }
}
