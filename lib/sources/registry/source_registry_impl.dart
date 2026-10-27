import 'dart:async';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import '../../core/contracts/music_source.dart';
import '../../core/errors.dart';
import '../../core/models/catalog.dart';
import '../../core/models/track.dart';
import '../../core/util/cancel_token.dart';
import '../../settings/app_settings.dart';
import '../../settings/settings_store.dart';

final _log = Logger('sources.registry');

/// [SourceRegistry] backed by the user's provider preferences.
///
/// * [all]: every registered source in registration order.
/// * [ordered]: `services.providerOrder` first (unknown ids ignored), then
///   sources missing from the order in registration order; sources in
///   `services.disabledSources` are excluded.
/// * [byId]/[require] also return disabled sources — tracks already in the
///   library still need their source (e.g. for metadata refresh).
/// * [changes] merges every source's `authStateChanges` with changes of the
///   order / disabled set.
/// * [searchAll] queries ready, enabled sources concurrently with a
///   per-source timeout and emits each source's results as they arrive.
class SourceRegistryImpl implements SourceRegistry {
  SourceRegistryImpl({required SettingsStore settings, this.searchTimeout = const Duration(seconds: 10)})
    : _settings = settings {
    _lastServices = settings.current.services;
    _settingsSub = settings.changes.listen((s) {
      final prev = _lastServices;
      _lastServices = s.services;
      if (!_sameServicePrefs(prev, s.services)) _emitChange();
    });
  }

  final SettingsStore _settings;

  /// Per-source time budget in [searchAll].
  final Duration searchTimeout;

  final List<MusicSource> _sources = [];
  final Map<String, StreamSubscription<Object?>> _authSubs = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  late ServicesSettings _lastServices;
  late final StreamSubscription<AppSettings> _settingsSub;

  static const _listEq = ListEquality<String>();
  static const _setEq = SetEquality<String>();

  static bool _sameServicePrefs(ServicesSettings a, ServicesSettings b) =>
      _listEq.equals(a.providerOrder, b.providerOrder) && _setEq.equals(a.disabledSources, b.disabledSources);

  void _emitChange() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  List<MusicSource> get all => List.unmodifiable(_sources);

  @override
  List<MusicSource> get ordered {
    final services = _settings.current.services;
    final disabled = services.disabledSources;
    final rank = <String, int>{};
    for (var i = 0; i < services.providerOrder.length; i++) {
      rank.putIfAbsent(services.providerOrder[i], () => i);
    }
    final enabled = [
      for (var i = 0; i < _sources.length; i++)
        if (!disabled.contains(_sources[i].id)) (i, _sources[i]),
    ];
    enabled.sort((a, b) {
      final ra = rank[a.$2.id];
      final rb = rank[b.$2.id];
      if (ra != null && rb != null) return ra.compareTo(rb);
      if (ra != null) return -1;
      if (rb != null) return 1;
      return a.$1.compareTo(b.$1);
    });
    return List.unmodifiable([for (final e in enabled) e.$2]);
  }

  /// Whether the user disabled [id] in settings.
  bool isEnabled(String id) => !_settings.current.services.disabledSources.contains(id);

  @override
  MusicSource? byId(String id) => _sources.firstWhereOrNull((s) => s.id == id);

  @override
  MusicSource require(String id) {
    final source = byId(id);
    if (source == null) throw StateError('No music source registered with id "$id"');
    return source;
  }

  @override
  void register(MusicSource source) {
    if (byId(source.id) != null) {
      throw ArgumentError.value(source.id, 'source', 'A source with this id is already registered');
    }
    _sources.add(source);
    _authSubs[source.id] = source.authStateChanges.listen(
      (_) => _emitChange(),
      onError: (Object e) {
        _log.warning('Auth state stream of ${source.id} failed', e);
      },
    );
    _emitChange();
  }

  /// Unregisters and returns [id] (the caller disposes it).
  MusicSource? unregister(String id) {
    final source = byId(id);
    if (source == null) return null;
    _sources.remove(source);
    unawaited(_authSubs.remove(id)?.cancel());
    _emitChange();
    return source;
  }

  @override
  Stream<void> get changes => _changes.stream;

  /// Calls `init()` on every source; one failing source does not stop the
  /// others (sources must not throw for missing credentials anyway).
  Future<void> initAll() async {
    await Future.wait(
      _sources.map((s) async {
        try {
          await s.init();
        } catch (e, st) {
          _log.severe('Initialising source ${s.id} failed', e, st);
        }
      }),
    );
    _emitChange();
  }

  @override
  Stream<SourceSearchResults> searchAll(
    String query, {
    Set<SearchType> types = const {SearchType.tracks, SearchType.artists, SearchType.albums, SearchType.playlists},
    Set<String>? onlySources,
    CancelToken? cancel,
  }) {
    final q = query.trim();
    final targets = [
      for (final s in ordered)
        if ((onlySources == null || onlySources.contains(s.id)) && s.isReady && _searchTypesOf(s, types).isNotEmpty) s,
    ];
    final controller = StreamController<SourceSearchResults>();
    if (q.isEmpty || targets.isEmpty || (cancel?.isCanceled ?? false)) {
      controller.close();
      return controller.stream;
    }
    final children = <CancelToken>[];
    var pending = targets.length;
    StreamSubscription<void>? cancelSub;

    void finish() {
      for (final c in children) {
        c.cancel();
      }
      unawaited(cancelSub?.cancel());
      if (!controller.isClosed) controller.close();
    }

    cancelSub = cancel?.whenCanceled.asStream().listen((_) => finish());
    controller.onCancel = finish;

    for (final source in targets) {
      final child = CancelToken();
      children.add(child);
      _searchOne(source, q, _searchTypesOf(source, types), child).then((result) {
        if (controller.isClosed || (cancel?.isCanceled ?? false)) return;
        controller.add(result);
        if (--pending == 0) finish();
      });
    }
    return controller.stream;
  }

  static Set<SearchType> _searchTypesOf(MusicSource s, Set<SearchType> types) => {
    for (final t in types)
      if (s.supports(switch (t) {
        SearchType.tracks => SourceCapability.searchTracks,
        SearchType.artists => SourceCapability.searchArtists,
        SearchType.albums => SourceCapability.searchAlbums,
        SearchType.playlists => SourceCapability.searchPlaylists,
      }))
        t,
  };

  /// Runs all requested search types of one source in parallel within
  /// [searchTimeout]. Never throws: failures end up in `error`. When some
  /// types succeed and others fail, the successful pages are returned and
  /// the failures are only logged; `error` is set when nothing succeeded
  /// (a timeout becomes a [NetworkException] with `isTimeout`).
  Future<SourceSearchResults> _searchOne(
    MusicSource source,
    String q,
    Set<SearchType> types,
    CancelToken cancel,
  ) async {
    var timedOut = false;
    final timer = Timer(searchTimeout, () {
      timedOut = true;
      cancel.cancel();
    });
    Page<Track> tracks = const Page.empty();
    Page<Artist> artists = const Page.empty();
    Page<Album> albums = const Page.empty();
    Page<Playlist> playlists = const Page.empty();
    final errors = <Object>[];
    var succeeded = 0;
    var done = false;

    Future<void> run<T>(Future<Page<T>> Function() call, void Function(Page<T>) assign) async {
      try {
        final page = await call();
        if (done) return; // arrived after the deadline
        assign(page);
        succeeded++;
      } catch (e) {
        if (!done) errors.add(e);
      }
    }

    try {
      final work = Future.wait([
        if (types.contains(SearchType.tracks)) run(() => source.searchTracks(q, cancel: cancel), (p) => tracks = p),
        if (types.contains(SearchType.artists)) run(() => source.searchArtists(q, cancel: cancel), (p) => artists = p),
        if (types.contains(SearchType.albums)) run(() => source.searchAlbums(q, cancel: cancel), (p) => albums = p),
        if (types.contains(SearchType.playlists))
          run(() => source.searchPlaylists(q, cancel: cancel), (p) => playlists = p),
      ]);
      // A source that ignores cancellation must not block the stream.
      await Future.any([work, cancel.whenCanceled]);
    } finally {
      done = true;
      timer.cancel();
    }
    Object? error;
    if (succeeded == 0) {
      error = timedOut
          ? NetworkException(
              '${source.displayName} did not answer within ${searchTimeout.inSeconds} s',
              isTimeout: true,
            )
          : (errors.isNotEmpty ? errors.first : const OperationCanceledException());
      _log.info('Search on ${source.id} failed: $error');
    } else if (errors.isNotEmpty || timedOut) {
      _log.info('Search on ${source.id} partially failed (${errors.length} part(s)${timedOut ? ', timed out' : ''})');
    }
    return SourceSearchResults(
      sourceId: source.id,
      tracks: tracks,
      artists: artists,
      albums: albums,
      playlists: playlists,
      error: error,
    );
  }

  Future<void> dispose() async {
    await _settingsSub.cancel();
    for (final sub in _authSubs.values) {
      await sub.cancel();
    }
    _authSubs.clear();
    await _changes.close();
  }
}
