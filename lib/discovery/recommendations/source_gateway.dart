import 'package:logging/logging.dart';

import '../../core/contracts/music_source.dart';
import '../../core/models/catalog.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../../core/util/cancel_token.dart';
import '../../settings/settings_store.dart';
import '../util/safe_call.dart';
import '../util/text_keys.dart';

final _log = Logger('discovery.sources');

/// Discovery's view of the [SourceRegistry]: which sources to ask in which
/// order, isolated + rate-limited + memoized provider calls, and resolution
/// of metadata-only items (Deezer) to in-app playable equivalents.
///
/// Every call returns an empty result instead of throwing when a source
/// fails; only cancellation propagates.
class SourceGateway {
  SourceGateway(
    this.registry,
    this.settings, {
    this.callTimeout = const Duration(seconds: 15),
    int maxConcurrent = 6,
    this.memoTtl = const Duration(hours: 6),
    DateTime Function()? clock,
  })  : _limiter = ConcurrencyLimiter(maxConcurrent),
        _clock = clock ?? DateTime.now;

  final SourceRegistry registry;
  final SettingsStore settings;
  final Duration callTimeout;
  final Duration memoTtl;
  final ConcurrencyLimiter _limiter;
  final DateTime Function() _clock;
  final Map<String, (DateTime, Object?)> _memo = {};

  /// Number of provider calls that failed since the last [clearMemo]
  /// (used to avoid caching results computed while sources were down).
  int failures = 0;

  bool get preferSoundCloud => settings.current.services.preferSoundCloudInDiscovery;

  bool _enabled(String id) => !settings.current.services.disabledSources.contains(id);

  /// Whether the user's local library may be used.
  bool get localEnabled => _enabled(SourceIds.local);

  /// Ready, enabled sources that play full tracks inside Fermata, in
  /// discovery order: the user's provider order, with SoundCloud first when
  /// `preferSoundCloudInDiscovery` (and last among playable sources
  /// otherwise).
  List<MusicSource> get playable {
    final list = [
      for (final s in registry.ordered)
        if (s.isReady && s.supports(SourceCapability.stream)) s,
    ];
    final sc = list.where((s) => s.id == SourceIds.soundcloud).toList();
    if (sc.isNotEmpty) {
      list.removeWhere((s) => s.id == SourceIds.soundcloud);
      preferSoundCloud ? list.insertAll(0, sc) : list.addAll(sc);
    }
    return list;
  }

  /// Ready sources without in-app full playback (Deezer previews, external
  /// players): used for metadata, charts and related items only.
  List<MusicSource> get metadataOnly => [
        for (final s in registry.ordered)
          if (s.isReady && !s.supports(SourceCapability.stream)) s,
      ];

  /// Ready sources declaring [capability]: playable first.
  List<MusicSource> supporting(SourceCapability capability, {bool playableOnly = false}) => [
        for (final s in [...playable, if (!playableOnly) ...metadataOnly])
          if (s.supports(capability)) s,
      ];

  /// Whether [t] plays inside Fermata now: a full track from a ready,
  /// enabled source (or a local file). Previews only with [allowPreview].
  bool canPlay(Track t, {bool allowPreview = false}) {
    if (t.isLocal) {
      return localEnabled &&
          (t.localPath?.isNotEmpty ?? false) &&
          t.availability.playback != PlaybackRights.unavailable;
    }
    if (!_enabled(t.sourceId)) return false;
    final s = registry.byId(t.sourceId);
    if (s == null || !s.isReady) return false;
    return switch (t.availability.playback) {
      PlaybackRights.full => s.supports(SourceCapability.stream),
      PlaybackRights.preview => allowPreview,
      PlaybackRights.unknown => s.supports(SourceCapability.stream),
      PlaybackRights.externalOnly || PlaybackRights.unavailable => false,
    };
  }

  // ---- Isolated, memoized calls ------------------------------------------

  Future<T?> call<T>(MusicSource s, String op, Future<T> Function(CancelToken token) f, {CancelToken? cancel}) =>
      attempt('${s.id}.$op', f, cancel: cancel, timeout: callTimeout, limiter: _limiter, onError: (_) => failures++);

  Future<T?> _memoized<T>(String key, Future<T?> Function() compute) async {
    final hit = _memo[key];
    final now = _clock();
    if (hit != null && now.difference(hit.$1) < memoTtl) return hit.$2 as T?;
    final value = await compute();
    if (value != null) _memo[key] = (now, value);
    return value;
  }

  void clearMemo() {
    _memo.clear();
    failures = 0;
  }

  Future<List<Track>> search(MusicSource s, String query, {int limit = 20, CancelToken? cancel}) async {
    if (!s.supports(SourceCapability.searchTracks) || query.trim().isEmpty) return const [];
    return await _memoized('search:${s.id}:$limit:${query.trim().toLowerCase()}',
            () async => (await call(s, 'searchTracks', (c) => s.searchTracks(query, limit: limit, cancel: c), cancel: cancel))?.items) ??
        const [];
  }

  /// [name] on [s] by exact (normalized) name; [knownId] skips the lookup.
  Future<Artist?> findArtist(MusicSource s, String name, {String? knownId, CancelToken? cancel}) async {
    if (knownId != null && knownId.isNotEmpty) {
      return Artist(sourceId: s.id, sourceArtistId: knownId, name: name);
    }
    if (!s.supports(SourceCapability.searchArtists) || name.trim().isEmpty) return null;
    final key = TextKeys.artist(name);
    return _memoized('artist:${s.id}:$key', () async {
      final page = await call(s, 'searchArtists', (c) => s.searchArtists(name, limit: 5, cancel: c), cancel: cancel);
      final items = page?.items ?? const <Artist>[];
      for (final a in items) {
        if (TextKeys.artist(a.name) == key) return a;
      }
      return null;
    });
  }

  Future<List<Artist>> relatedArtists(MusicSource s, String artistId, {int limit = 8, CancelToken? cancel}) async =>
      await _memoized('relArtists:${s.id}:$artistId:$limit',
          () => call(s, 'relatedArtists', (c) => s.relatedArtists(artistId, limit: limit, cancel: c), cancel: cancel)) ??
      const [];

  Future<List<Track>> topTracks(MusicSource s, String artistId, {int limit = 10, CancelToken? cancel}) async =>
      await _memoized('top:${s.id}:$artistId:$limit', () async {
        final page = await call(s, 'artistTopTracks', (c) => s.artistTopTracks(artistId, limit: limit, cancel: c),
            cancel: cancel);
        return page?.items;
      }) ??
      const [];

  Future<List<Track>> relatedTracks(MusicSource s, String trackId, {int limit = 20, CancelToken? cancel}) async {
    if (!s.supports(SourceCapability.relatedTracks)) return const [];
    return await _memoized('relTracks:${s.id}:$trackId:$limit',
            () => call(s, 'relatedTracks', (c) => s.relatedTracks(trackId, limit: limit, cancel: c), cancel: cancel)) ??
        const [];
  }

  Future<List<Track>> trending(MusicSource s, {String? genre, int limit = 30, CancelToken? cancel}) async {
    if (!s.supports(SourceCapability.trending)) return const [];
    return await _memoized('trending:${s.id}:${genre ?? ''}:$limit',
            () => call(s, 'trending', (c) => s.trending(genre: genre, limit: limit, cancel: c), cancel: cancel)) ??
        const [];
  }

  Future<List<Album>> newReleases(MusicSource s, {int limit = 20, CancelToken? cancel}) async {
    if (!s.supports(SourceCapability.newReleases)) return const [];
    return await _memoized('newReleases:${s.id}:$limit',
            () => call(s, 'newReleases', (c) => s.newReleases(limit: limit, cancel: c), cancel: cancel)) ??
        const [];
  }

  Future<List<String>> genres(MusicSource s, {CancelToken? cancel}) async {
    if (!s.supports(SourceCapability.genres)) return const [];
    return await _memoized('genres:${s.id}', () => call(s, 'genres', (c) => s.genres(cancel: c), cancel: cancel)) ??
        const [];
  }

  Future<List<Track>> albumTracks(MusicSource s, String albumId, {CancelToken? cancel}) async =>
      await _memoized('album:${s.id}:$albumId', () async {
        final page = await call(s, 'albumTracks', (c) => s.albumTracks(albumId, cancel: c), cancel: cancel);
        return page?.items;
      }) ??
      const [];

  // ---- Cross-source resolution ------------------------------------------

  /// Quick "same song" check (title + artist, duration within 10 s when
  /// both are known). Not the full matcher — good enough for discovery.
  static bool quickMatch(Track seed, Track candidate) {
    if (!TextKeys.looselyEqual(TextKeys.title(seed.title), TextKeys.title(candidate.title))) return false;
    final a = TextKeys.artist(seed.primaryArtist);
    final artistOk = TextKeys.looselyEqual(a, TextKeys.artist(candidate.primaryArtist)) ||
        candidate.artists.any((r) => TextKeys.artist(r.name) == a) ||
        TextKeys.looselyEqual(a, TextKeys.normalize(candidate.artistLine));
    if (!artistOk) return false;
    final d1 = seed.duration, d2 = candidate.duration;
    if (d1 != null && d2 != null && d1 > Duration.zero && d2 > Duration.zero) {
      return (d1 - d2).abs() <= const Duration(seconds: 10);
    }
    return true;
  }

  /// The same song as [t] on [s] by a simple "artist title" search.
  Future<Track?> findEquivalent(MusicSource s, Track t, {CancelToken? cancel}) async {
    if (t.sourceId == s.id) return t;
    final query = '${t.primaryArtist} ${t.title}'.trim();
    final results = await search(s, query, limit: 8, cancel: cancel);
    for (final r in results) {
      if (quickMatch(t, r)) return r;
    }
    return null;
  }

  /// [t] itself when playable in-app, else the first playable equivalent
  /// on a playable source accepted by [sourceFilter] (provider order).
  Future<Track?> resolvePlayable(Track t, {bool Function(String sourceId)? sourceFilter, CancelToken? cancel}) async {
    if (canPlay(t) && (sourceFilter?.call(t.sourceId) ?? true)) return t;
    for (final s in playable) {
      if (sourceFilter != null && !sourceFilter(s.id)) continue;
      if (!s.supports(SourceCapability.searchTracks)) continue;
      final eq = await findEquivalent(s, t, cancel: cancel);
      if (eq != null && canPlay(eq)) return eq;
    }
    return null;
  }

  /// Maps [tracks] to in-app playable tracks, preserving order. At most
  /// [maxLookups] non-playable items are searched for; unresolved items are
  /// dropped, or kept when [keepPreviews] and they are playable previews
  /// (the UI labels them preview/external from their availability).
  Future<List<Track>> resolveAll(
    List<Track> tracks, {
    int maxLookups = 15,
    bool keepPreviews = false,
    bool Function(String sourceId)? sourceFilter,
    CancelToken? cancel,
  }) async {
    var lookups = 0;
    final futures = <Future<Track?>>[];
    for (final t in tracks) {
      if (canPlay(t) && (sourceFilter?.call(t.sourceId) ?? true)) {
        futures.add(Future.value(t));
      } else if (lookups < maxLookups) {
        lookups++;
        futures.add(resolvePlayable(t, sourceFilter: sourceFilter, cancel: cancel).then((r) {
          if (r != null) return r;
          return keepPreviews && canPlay(t, allowPreview: true) && (sourceFilter?.call(t.sourceId) ?? true) ? t : null;
        }));
      } else if (keepPreviews && canPlay(t, allowPreview: true) && (sourceFilter?.call(t.sourceId) ?? true)) {
        futures.add(Future.value(t));
      }
    }
    final resolved = await Future.wait(futures);
    cancel?.throwIfCanceled();
    final out = [for (final t in resolved) ?t];
    if (out.length < tracks.length) _log.finer('resolveAll: ${out.length}/${tracks.length} playable');
    return out;
  }
}
