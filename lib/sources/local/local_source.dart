import 'dart:convert';
import 'dart:io';

import '../../core/contracts/library.dart';
import '../../core/contracts/music_source.dart';
import '../../core/errors.dart';
import '../../core/models/catalog.dart';
import '../../core/models/download.dart';
import '../../core/models/library.dart';
import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../../core/util/cancel_token.dart';
import '../base/music_source_base.dart';
import '../base/paging.dart';

/// The user's own audio files, exposed as a source so search, artist and
/// album pages and the stream resolver treat them like any provider.
///
/// Everything is answered from the library database ([TrackRepository]);
/// scanning and tag reading belong to the library module. Artists are
/// identified by name, albums by an opaque id encoding artist + title.
class LocalSource extends MusicSourceBase {
  LocalSource({required this._tracks, Future<bool> Function(String path)? fileExists})
    : _exists = fileExists ?? ((p) => File(p).exists());

  final TrackRepository _tracks;
  final Future<bool> Function(String path) _exists;

  @override
  String get id => SourceIds.local;

  @override
  String get displayName => 'Local files';

  @override
  Set<SourceCapability> get capabilities => const {
    SourceCapability.searchTracks,
    SourceCapability.searchArtists,
    SourceCapability.searchAlbums,
    SourceCapability.stream,
    SourceCapability.artistPages,
    SourceCapability.albumPages,
    SourceCapability.genres,
  };

  @override
  String get limitationsNote =>
      'Plays audio files from the folders you add to your library. Files stay where they are; '
      'nothing is uploaded. Search covers title, artist and album tags.';

  static const _localOnly = {SourceIds.local};

  // ---- Search ---------------------------------------------------------------

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    final q = query.trim();
    if (q.isEmpty) return const Page.empty();
    final offset = PageCursor.decodeOffset(cursor);
    final base = TrackQuery(
      text: q,
      sourceIds: _localOnly,
      localFilesOnly: true,
      sort: TrackSortField.title,
      descending: false,
    );
    final items = await _tracks.query(_withPage(base, offset: offset, limit: limit + 1));
    cancel?.throwIfCanceled();
    final more = items.length > limit;
    return PageCursor.offsetPage(more ? items.sublist(0, limit) : items, offset: offset, limit: limit, hasMore: more);
  }

  @override
  Future<Page<Artist>> searchArtists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    final q = query.trim();
    if (q.isEmpty) return const Page.empty();
    final all = _localArtists(await _localTracks(q), q);
    cancel?.throwIfCanceled();
    return _slice([for (final a in all) _artistOf(a)], cursor, limit);
  }

  @override
  Future<Page<Album>> searchAlbums(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    final q = query.trim();
    if (q.isEmpty) return const Page.empty();
    final all = _localAlbums(await _localTracks(q), q);
    cancel?.throwIfCanceled();
    return _slice([for (final a in all) _albumOf(a)], cursor, limit);
  }

  // ---- Browse ---------------------------------------------------------------

  @override
  Future<Track?> getTrack(String sourceTrackId, {CancelToken? cancel}) async {
    final track = await _tracks.getTrack(Track.makeId(id, sourceTrackId));
    return track != null && track.sourceId == id ? track : null;
  }

  @override
  Future<Artist?> getArtist(String sourceArtistId, {CancelToken? cancel}) async {
    final matches = await _tracks.artists(text: sourceArtistId);
    for (final a in matches) {
      if (a.name.toLowerCase() == sourceArtistId.toLowerCase()) return _artistOf(a);
    }
    return null;
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
    final base = TrackQuery(
      artist: sourceArtistId,
      sourceIds: _localOnly,
      localFilesOnly: true,
      sort: TrackSortField.playCount,
      descending: true,
    );
    final items = await _tracks.query(_withPage(base, offset: offset, limit: limit + 1));
    final more = items.length > limit;
    return PageCursor.offsetPage(more ? items.sublist(0, limit) : items, offset: offset, limit: limit, hasMore: more);
  }

  /// All tracks of the album in disc/track order (albums are small, so a
  /// single page).
  @override
  Future<Page<Track>> albumTracks(String sourceAlbumId, {String? cursor, CancelToken? cancel}) async {
    final key = decodeAlbumId(sourceAlbumId);
    final items = await _tracks.query(
      TrackQuery(
        album: key.title,
        artist: key.artist.isEmpty ? null : key.artist,
        sourceIds: _localOnly,
        localFilesOnly: true,
        sort: TrackSortField.title,
        descending: false,
      ),
    );
    // Album artist may differ from the track artist (compilations): fall
    // back to album-only matching when the artist filter found nothing.
    final tracks = items.isNotEmpty || key.artist.isEmpty
        ? items
        : (await _tracks.query(TrackQuery(album: key.title, sourceIds: _localOnly, localFilesOnly: true)))
              .where((t) => (t.albumArtist ?? t.primaryArtist).toLowerCase() == key.artist.toLowerCase())
              .toList();
    final sorted = [...tracks]..sort(_albumOrder);
    return Page(sorted, total: sorted.length);
  }

  static int _albumOrder(Track a, Track b) {
    final d = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
    if (d != 0) return d;
    final t = (a.trackNumber ?? 1 << 20).compareTo(b.trackNumber ?? 1 << 20);
    if (t != 0) return t;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  @override
  Future<List<String>> genres({CancelToken? cancel}) async {
    final genres = <String>{
      for (final t in await _localTracks(null))
        if (t.genre != null && t.genre!.trim().isNotEmpty) t.genre!.trim(),
    };
    return genres.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  // The library also stores remote tracks (favorites, history, imports);
  // this source only exposes the user's own files.
  Future<List<Track>> _localTracks(String? text) =>
      _tracks.query(TrackQuery(text: text, localFilesOnly: true, sort: TrackSortField.artist, descending: false));

  static bool _matches(String value, String q) => value.toLowerCase().contains(q.toLowerCase());

  List<ArtistSummary> _localArtists(List<Track> tracks, String q) {
    final byName = <String, List<Track>>{};
    for (final t in tracks) {
      final name = t.primaryArtist.trim();
      if (name.isEmpty || !_matches(name, q)) continue;
      byName.putIfAbsent(name.toLowerCase(), () => []).add(t);
    }
    return [
      for (final group in byName.values)
        ArtistSummary(
          name: group.first.primaryArtist.trim(),
          trackCount: group.length,
          albumCount: {for (final t in group) t.album}.whereType<String>().length,
          artworkUrl: group.map((t) => t.artworkUrl).whereType<Uri>().firstOrNull,
        ),
    ];
  }

  List<AlbumSummary> _localAlbums(List<Track> tracks, String q) {
    final byKey = <String, List<Track>>{};
    for (final t in tracks) {
      final title = t.album?.trim();
      if (title == null || title.isEmpty) continue;
      final artist = (t.albumArtist ?? t.primaryArtist).trim();
      if (!_matches(title, q) && !_matches(artist, q)) continue;
      byKey.putIfAbsent('${artist.toLowerCase()}\u0000${title.toLowerCase()}', () => []).add(t);
    }
    return [
      for (final group in byKey.values)
        AlbumSummary(
          title: group.first.album!.trim(),
          artist: (group.first.albumArtist ?? group.first.primaryArtist).trim(),
          trackCount: group.length,
          year: group.map((t) => t.year).whereType<int>().firstOrNull,
          artworkUrl: group.map((t) => t.artworkUrl).whereType<Uri>().firstOrNull,
          totalDuration: group.fold<Duration>(Duration.zero, (sum, t) => sum + (t.duration ?? Duration.zero)),
        ),
    ];
  }

  // ---- Playback ---------------------------------------------------------------

  @override
  Future<PlayableSource> resolveStream(
    Track track, {
    AudioQuality quality = AudioQuality.high,
    CancelToken? cancel,
  }) async {
    checkOwnTrack(track);
    var path = track.localPath;
    if (path == null || path.isEmpty) {
      path = (await _tracks.getTrack(track.id))?.localPath;
    }
    if (path == null || path.isEmpty || !await _exists(path)) {
      throw UnplayableTrackException(
        track.id,
        AvailabilityReason.fileMissing,
        message: 'The file for "${track.title}" was moved or deleted',
      );
    }
    return PlayableSource(uri: Uri.file(path), isLocalFile: true);
  }

  /// Local files are already offline; nothing to download.
  @override
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel}) async => null;

  @override
  Uri? externalPlaybackUri(Track track) => null;

  // ---- Mapping helpers --------------------------------------------------------

  Artist _artistOf(ArtistSummary a) =>
      Artist(sourceId: id, sourceArtistId: a.name, name: a.name, avatarUrl: a.artworkUrl);

  Album _albumOf(AlbumSummary a) => Album(
    sourceId: id,
    sourceAlbumId: encodeAlbumId(a.artist, a.title),
    title: a.title,
    artists: a.artist.isEmpty ? const [] : [ArtistRef(a.artist, sourceArtistId: a.artist)],
    artworkUrl: a.artworkUrl,
    year: a.year,
    trackCount: a.trackCount,
  );

  /// Opaque, URL-safe album id for (artist, title).
  static String encodeAlbumId(String artist, String title) =>
      base64Url.encode(utf8.encode(jsonEncode([artist, title]))).replaceAll('=', '');

  static ({String artist, String title}) decodeAlbumId(String albumId) {
    try {
      final padded = albumId.padRight(albumId.length + (4 - albumId.length % 4) % 4, '=');
      final list = jsonDecode(utf8.decode(base64Url.decode(padded)));
      if (list is List && list.length == 2 && list[0] is String && list[1] is String) {
        return (artist: list[0] as String, title: list[1] as String);
      }
    } on FormatException {
      // fall through
    }
    throw FormatException('Not a local album id', albumId);
  }

  static TrackQuery _withPage(TrackQuery q, {required int offset, required int limit}) => TrackQuery(
    text: q.text,
    sourceIds: q.sourceIds,
    artist: q.artist,
    album: q.album,
    genre: q.genre,
    localFilesOnly: q.localFilesOnly,
    sort: q.sort,
    descending: q.descending,
    limit: limit,
    offset: offset,
  );

  static Page<T> _slice<T>(List<T> all, String? cursor, int limit) {
    final offset = PageCursor.decodeOffset(cursor);
    final end = (offset + limit).clamp(0, all.length);
    final items = offset >= all.length ? <T>[] : all.sublist(offset, end);
    return PageCursor.offsetPage(items, offset: offset, limit: limit, total: all.length);
  }
}
