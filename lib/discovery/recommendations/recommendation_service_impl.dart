import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../core/contracts/discovery.dart';
import '../../core/contracts/library.dart';
import '../../core/contracts/music_source.dart';
import '../../core/errors.dart';
import '../../core/models/catalog.dart';
import '../../core/models/track.dart';
import '../../core/platform/app_paths.dart';
import '../../core/util/cancel_token.dart';
import '../../settings/app_settings.dart';
import '../../settings/settings_store.dart';
import '../util/seeded_random.dart';
import '../util/text_keys.dart';
import 'browse_builders.dart';
import 'discovery_cache.dart';
import 'discovery_codec.dart';
import 'discovery_context.dart';
import 'library_pools.dart';
import 'moods.dart';
import 'personal_builders.dart';
import 'shelf_ids.dart';
import 'source_gateway.dart';
import 'taste_profile.dart';

final _log = Logger('discovery.recommendations');

/// Privacy-first recommendations computed on the device from listening
/// history, favorites, the local library and provider catalog endpoints
/// (related, top tracks, trending, new releases, genres). Nothing about
/// the user is uploaded; providers only see ordinary catalog requests.
///
/// * Personal shelves are skipped entirely (history is not even read)
///   when `privacy.personalizedRecommendations` is off.
/// * Results are memoized per shelf (6 h; Discover Weekly 24 h) in memory
///   and in `<cacheDir>/discovery/recommendations.json`. With
///   `performance.backgroundSync` off or the data-saver mode, expired
///   entries keep being served until [refresh] is called (no implicit
///   refetching). The service never refreshes in the background.
/// * One failing source never breaks a shelf, and [homeShelves] never
///   throws because of sources (only [OperationCanceledException]).
class RecommendationServiceImpl implements RecommendationService {
  RecommendationServiceImpl(
    SourceRegistry sources,
    HistoryRepository history,
    TrackRepository tracks,
    FavoritesRepository favorites,
    SettingsStore settings,
    AppPaths paths, {
    DateTime Function()? clock,
    DiscoveryTuning tuning = const DiscoveryTuning(),
    Duration sourceTimeout = const Duration(seconds: 15),
    int maxConcurrentRequests = 6,
    bool persistCache = true,
  })  : _settings = settings,
        _clock = clock ?? DateTime.now {
    final gateway = SourceGateway(sources, settings,
        callTimeout: sourceTimeout, maxConcurrent: maxConcurrentRequests, clock: _clock, memoTtl: tuning.shelfTtl);
    _ctx = DiscoveryContext(
      registry: sources,
      gateway: gateway,
      library: LibraryPools(tracks, gateway),
      history: history,
      favorites: favorites,
      settings: settings,
      clock: _clock,
      tuning: tuning,
    );
    _personal = PersonalBuilders(_ctx);
    _browse = BrowseBuilders(_ctx);
    _cache = DiscoveryCache(
      persistCache ? File(p.join(paths.cacheDir.path, 'discovery', 'recommendations.json')) : null,
      clock: _clock,
    );
    _lastPersonalized = settings.current.privacy.personalizedRecommendations;
    _settingsSub = settings.changes.listen(_onSettings);
  }

  final SettingsStore _settings;
  final DateTime Function() _clock;
  late final DiscoveryContext _ctx;
  late final PersonalBuilders _personal;
  late final BrowseBuilders _browse;
  late final DiscoveryCache _cache;
  late final StreamSubscription<AppSettings> _settingsSub;
  late bool _lastPersonalized;
  (DateTime, Future<TasteProfile>)? _profile;

  DiscoveryTuning get _t => _ctx.tuning;

  bool get _personalized => _settings.current.privacy.personalizedRecommendations;

  /// Expired cache entries are only recomputed implicitly when background
  /// sync is allowed and data saver is off.
  bool get _autoRefresh {
    final perf = _settings.current.performance;
    return perf.backgroundSync && perf.mode != PerformanceMode.dataSaver;
  }

  void _onSettings(AppSettings s) {
    final personalized = s.privacy.personalizedRecommendations;
    if (_lastPersonalized && !personalized) {
      // Privacy: forget everything derived from history right away.
      _cache.removeWhere((_, e) => e.personal);
      _profile = null;
    }
    _lastPersonalized = personalized;
  }

  // ---- Caching ---------------------------------------------------------------

  Future<T> _cached<T>(
    String key, {
    required Future<T> Function() compute,
    required Object? Function(T value) encode,
    required T Function(Object? json) decode,
    required bool Function(T value) isEmpty,
    Duration? ttl,
    String? variant,
    bool personal = false,
    bool persist = true,
    CancelToken? cancel,
  }) async {
    await _cache.ensureLoaded();
    cancel?.throwIfCanceled();
    final hit = _cache.peek(key);
    final usable = hit != null && hit.variant == variant;
    if (usable && (hit.isFresh(_clock()) || !_autoRefresh)) {
      try {
        return decode(hit.data);
      } catch (e) {
        _log.warning('Dropping undecodable cache entry $key', e);
        _cache.remove(key);
      }
    }
    final failuresBefore = _ctx.gateway.failures;
    final value = await compute();
    cancel?.throwIfCanceled();
    if (!isEmpty(value)) {
      final degraded = _ctx.gateway.failures > failuresBefore;
      final full = ttl ?? _t.shelfTtl;
      _cache.put(key, encode(value),
          ttl: degraded && _t.degradedTtl < full ? _t.degradedTtl : full,
          variant: variant,
          personal: personal,
          persist: persist);
    } else if (usable) {
      // Everything failed (offline?): a stale result beats an empty shelf.
      try {
        return decode(hit.data);
      } catch (_) {}
    }
    return value;
  }

  Future<List<Shelf>> _cachedShelves(String key, Future<List<Shelf>> Function() compute,
          {Duration? ttl, String? variant, bool personal = false, CancelToken? cancel}) =>
      _cached(key,
          compute: compute,
          encode: DiscoveryCodec.shelves,
          decode: DiscoveryCodec.shelvesFrom,
          isEmpty: (v) => v.isEmpty,
          ttl: ttl,
          variant: variant,
          personal: personal,
          cancel: cancel);

  Future<List<Track>> _cachedTracks(String key, Future<List<Track>> Function() compute,
          {Duration? ttl, String? variant, bool persist = true, CancelToken? cancel}) =>
      _cached(key,
          compute: compute,
          encode: DiscoveryCodec.tracks,
          decode: DiscoveryCodec.tracksFrom,
          isEmpty: (v) => v.isEmpty,
          ttl: ttl,
          variant: variant,
          persist: persist,
          cancel: cancel);

  /// One profile per burst of calls (Home computes several personal shelves
  /// in parallel).
  Future<TasteProfile> _loadProfile(CancelToken? cancel) {
    final now = _clock();
    final cached = _profile;
    if (cached != null && now.difference(cached.$1) < const Duration(minutes: 1)) return cached.$2;
    final future = _ctx.buildProfile();
    _profile = (now, future);
    return future;
  }

  /// Drops every cached shelf and provider response so the next calls
  /// recompute them (pull-to-refresh / "Refresh recommendations").
  Future<void> refresh() async {
    await _cache.ensureLoaded();
    _cache.clear();
    _ctx.gateway.clearMemo();
    _profile = null;
  }

  /// Deletes cached recommendations (memory and disk), e.g. after the user
  /// cleared their history or deleted all data.
  Future<void> clearCache() async {
    await refresh();
    await _cache.flush();
  }

  /// Writes pending cache changes; call before exit.
  Future<void> dispose() async {
    await _settingsSub.cancel();
    await _cache.dispose();
  }

  // ---- Home ------------------------------------------------------------------

  @override
  Future<List<Shelf>> homeShelves({CancelToken? cancel}) async {
    final personal = _personalized;
    final builders = <Future<List<Shelf>>>[
      if (personal) _guard('continueListening', () async => [?await _personal.continueListening(cancel: cancel)]),
      if (personal) _guard('dailyMixes', () => dailyMixes(cancel: cancel)),
      if (personal) _guard('discoverWeekly', () async => [?await discoverWeekly(cancel: cancel)]),
      if (personal) _guard('becauseYouLiked', () => _becauseYouLiked(cancel)),
      _guard('trending', () => _cachedShelves('home:trending', () async => [?await _browse.trendingShelf(cancel: cancel)], cancel: cancel)),
      _guard('newReleases',
          () => _cachedShelves('home:newReleases', () async => [?await _browse.newReleasesShelf(cancel: cancel)], cancel: cancel)),
      _guard('genres', () => _genreShelves(personal, cancel)),
      _guard('recentlyAdded', () => _recentlyAdded(cancel)),
    ];
    final results = await Future.wait(builders);
    cancel?.throwIfCanceled();
    return [for (final l in results) ...l];
  }

  /// Runs one shelf builder in isolation: anything but cancellation is
  /// logged and yields no shelf.
  Future<List<Shelf>> _guard(String name, Future<List<Shelf>> Function() build) async {
    try {
      return await build();
    } on OperationCanceledException {
      rethrow;
    } catch (e, st) {
      _log.warning('Shelf "$name" failed', e, st);
      return const [];
    }
  }

  Future<List<Shelf>> _becauseYouLiked(CancelToken? cancel) {
    final day = DiscoveryCalendar.dayKey(_clock());
    return _cachedShelves('home:becauseYouLiked', () async {
      final profile = await _loadProfile(cancel);
      final favorites = await _ctx.loadFavorites();
      return [?await _personal.becauseYouLiked(profile, favorites, cancel: cancel)];
    }, variant: day, personal: true, cancel: cancel);
  }

  /// Two genre shelves: the user's top genres when personalized, otherwise
  /// (or when those yield nothing) genres picked per day from the sources'
  /// and the library's genre lists.
  Future<List<Shelf>> _genreShelves(bool personal, CancelToken? cancel) async {
    const wanted = 2;
    final picks = <String>[];
    final keys = <String>{};
    void add(Iterable<String> genres) {
      for (final g in genres) {
        if (keys.add(TextKeys.genre(g))) picks.add(g);
      }
    }

    if (personal) add((await _loadProfile(cancel)).topGenres(limit: wanted));
    final all = await genres(cancel: cancel);
    final rng = SeededRandom.fromString('genres:${DiscoveryCalendar.dayKey(_clock())}');
    add(rng.shuffled(all.take(12)));
    final candidates = picks.take(wanted + 2).toList();
    final shelves = await Future.wait([
      for (final g in candidates)
        _cachedShelves('home:genre:${TextKeys.genre(g)}', () async => [?await _browse.genreShelf(g, cancel: cancel)],
            cancel: cancel),
    ]);
    return [for (final l in shelves) ...l].take(wanted).toList();
  }

  Future<List<Shelf>> _recentlyAdded(CancelToken? cancel) async {
    final tracks = await _ctx.library.recentlyAdded(limit: _t.shelfLength);
    cancel?.throwIfCanceled();
    if (tracks.isEmpty) return const [];
    return [
      Shelf(
        id: ShelfIds.recentlyAdded,
        title: ShelfTitles.recentlyAdded,
        tracks: tracks,
        artworkUrl: tracks.map((t) => t.artworkUrl).nonNulls.firstOrNull,
        // No dedicated ShelfKind exists for "recently added"; the id tells.
        kind: ShelfKind.mix,
      ),
    ];
  }

  // ---- Personal ----------------------------------------------------------------

  @override
  Future<List<Shelf>> dailyMixes({int count = 4, CancelToken? cancel}) async {
    if (!_personalized || count <= 0) return const [];
    final day = DiscoveryCalendar.dayKey(_clock());
    final mixes = await _cachedShelves('dailyMixes', () async {
      final profile = await _loadProfile(cancel);
      return _personal.dailyMixes(profile, math.max(count, 4), cancel: cancel);
    }, variant: day, personal: true, cancel: cancel);
    return mixes.take(count).toList();
  }

  @override
  Future<Shelf?> discoverWeekly({CancelToken? cancel}) async {
    if (!_personalized) return null;
    final week = DiscoveryCalendar.weekKey(_clock());
    final shelves = await _cachedShelves('discoverWeekly', () async {
      final profile = await _loadProfile(cancel);
      return [?await _personal.discoverWeekly(profile, cancel: cancel)];
    }, ttl: _t.weeklyTtl, variant: week, personal: true, cancel: cancel);
    return shelves.firstOrNull;
  }

  // ---- Non-personal ------------------------------------------------------------

  @override
  Future<List<Track>> similarTo(Track track, {int limit = 25, CancelToken? cancel}) =>
      _cachedTracks('similar:${track.id}:$limit', () => _browse.similarTo(track, limit: limit, cancel: cancel),
          persist: false, cancel: cancel);

  @override
  Future<List<Artist>> similarArtists(String artistName, {int limit = 12, CancelToken? cancel}) => _cached(
        'similarArtists:${TextKeys.artist(artistName)}:$limit',
        compute: () => _browse.similarArtists(artistName, limit: limit, cancel: cancel),
        encode: DiscoveryCodec.artists,
        decode: DiscoveryCodec.artistsFrom,
        isEmpty: (v) => v.isEmpty,
        ttl: _t.weeklyTtl,
        persist: false,
        cancel: cancel,
      );

  @override
  Future<List<Album>> newReleases({CancelToken? cancel}) => _cached(
        'newReleases',
        compute: () => _browse.newReleases(cancel: cancel),
        encode: DiscoveryCodec.albums,
        decode: DiscoveryCodec.albumsFrom,
        isEmpty: (v) => v.isEmpty,
        cancel: cancel,
      );

  @override
  Future<List<String>> genres({CancelToken? cancel}) => _cached(
        'genres',
        compute: () => _browse.genres(cancel: cancel),
        encode: (v) => v,
        decode: DiscoveryCodec.stringsFrom,
        isEmpty: (v) => v.isEmpty,
        ttl: _t.weeklyTtl,
        cancel: cancel,
      );

  @override
  Future<List<Track>> genreTracks(String genre, {CancelToken? cancel}) => _cachedTracks(
      'genreTracks:${TextKeys.genre(genre)}', () => _browse.genreTracks(genre, cancel: cancel),
      persist: false, cancel: cancel);

  @override
  List<MoodCategory> get moods => [for (final m in Moods.all) m.category];

  @override
  Future<List<Track>> moodTracks(MoodCategory mood, {CancelToken? cancel}) => _cachedTracks(
      'mood:${mood.id}', () => _browse.moodTracks(mood, cancel: cancel),
      variant: DiscoveryCalendar.dayKey(_clock()), persist: false, cancel: cancel);

  /// Not cached: depends on the live queue; provider responses are memoized.
  @override
  Future<List<Track>> smartQueueContinuation(List<Track> recent, {int limit = 10, CancelToken? cancel}) =>
      _browse.smartQueueContinuation(recent, limit: limit, cancel: cancel);
}
