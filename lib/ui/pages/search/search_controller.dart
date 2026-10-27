import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/music_source.dart';
import '../../../core/errors.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/track.dart';
import '../../../core/util/cancel_token.dart';
import '../library/shared/track_helpers.dart';
import 'share_links.dart';

final _log = Logger('ui.pages.search');

/// Search debounce (search-as-you-type).
const searchDebounce = Duration(milliseconds: 300);

/// Whether [s] answers any search type.
bool isSearchable(MusicSource s) =>
    s.supports(SourceCapability.searchTracks) ||
    s.supports(SourceCapability.searchArtists) ||
    s.supports(SourceCapability.searchAlbums) ||
    s.supports(SourceCapability.searchPlaylists);

/// Snapshot of the search page.
@immutable
class SearchState {
  const SearchState({
    this.query = '',
    this.activeQuery,
    this.results = const {},
    this.pending = const {},
    this.searching = false,
    this.link,
    this.filter,
  });

  /// Text in the field (trimmed).
  final String query;

  /// Query whose results are shown (null before the first search).
  final String? activeQuery;

  /// Results per source id, in arrival order.
  final Map<String, SourceSearchResults> results;

  /// Sources still searching for [activeQuery].
  final Set<String> pending;
  final bool searching;

  /// A recognised share link (search is not run for links).
  final ShareLink? link;

  /// Source chip filter (null = all sources).
  final String? filter;

  /// True while the field text differs from the shown results.
  bool get typing => query.isNotEmpty && query != activeQuery && link == null;

  SearchState copyWith({
    String? query,
    String? activeQuery,
    Map<String, SourceSearchResults>? results,
    Set<String>? pending,
    bool? searching,
    ShareLink? link,
    bool clearLink = false,
    String? filter,
    bool clearFilter = false,
  }) =>
      SearchState(
        query: query ?? this.query,
        activeQuery: activeQuery ?? this.activeQuery,
        results: results ?? this.results,
        pending: pending ?? this.pending,
        searching: searching ?? this.searching,
        link: clearLink ? null : (link ?? this.link),
        filter: clearFilter ? null : (filter ?? this.filter),
      );
}

/// Debounced search over `SourceRegistry.searchAll`. Results stream in per
/// source; a newer query cancels the previous one ([LatestOnly]) and late
/// results of a canceled search are dropped.
class SearchPageController extends Notifier<SearchState> {
  Timer? _debounce;
  final _latest = LatestOnly();
  StreamSubscription<SourceSearchResults>? _sub;

  @override
  SearchState build() {
    ref.onDispose(_stop);
    return const SearchState();
  }

  void _stop() {
    _debounce?.cancel();
    _debounce = null;
    _latest.cancel();
    _sub?.cancel();
    _sub = null;
  }

  /// Called on every keystroke.
  void setQuery(String text) {
    final q = text.trim();
    _debounce?.cancel();
    if (q.isEmpty) {
      _stop();
      state = SearchState(filter: state.filter);
      return;
    }
    final link = ShareLink.parse(q);
    if (link != null) {
      _stop();
      state = SearchState(query: q, link: link, filter: state.filter);
      return;
    }
    if (q == state.activeQuery && state.link == null) {
      state = state.copyWith(query: q);
      return;
    }
    state = state.copyWith(query: q, clearLink: true);
    _debounce = Timer(searchDebounce, () => _run(q));
  }

  /// Runs the search now (Enter / a recent search was chosen).
  void submit(String text) {
    final q = text.trim();
    _debounce?.cancel();
    if (q.isEmpty) return setQuery(q);
    final link = ShareLink.parse(q);
    if (link != null) return setQuery(q);
    if (q == state.activeQuery && !state.searching) {
      state = state.copyWith(query: q);
      return;
    }
    _run(q);
  }

  void setFilter(String? sourceId) =>
      state = sourceId == null ? state.copyWith(clearFilter: true) : state.copyWith(filter: sourceId);

  /// Re-runs the current query (after an error / reconnecting a source).
  void retry() {
    final q = state.activeQuery ?? state.query;
    if (q.isNotEmpty) _run(q);
  }

  void _run(String query) {
    _sub?.cancel();
    final token = _latest.next();
    final registry = ref.read(sourceRegistryProvider);
    final targets = {for (final s in registry.ordered) if (s.isReady && isSearchable(s)) s.id};
    state = SearchState(
      query: query,
      activeQuery: query,
      pending: targets,
      searching: targets.isNotEmpty,
      filter: state.filter,
    );
    _sub = registry.searchAll(query, cancel: token).listen(
      (r) {
        if (token.isCanceled || !ref.mounted) return;
        state = state.copyWith(
          results: {...state.results, r.sourceId: r},
          pending: {...state.pending}..remove(r.sourceId),
        );
      },
      onError: (Object e, StackTrace st) {
        if (e is OperationCanceledException || token.isCanceled || !ref.mounted) return;
        _log.warning('Search failed', e, st);
      },
      onDone: () {
        if (token.isCanceled || !ref.mounted) return;
        state = state.copyWith(searching: false, pending: const {});
      },
    );
  }
}

final searchControllerProvider = NotifierProvider<SearchPageController, SearchState>(SearchPageController.new);

/// Results of one search, grouped and ordered by provider preference.
@immutable
class GroupedResults {
  const GroupedResults({
    required this.sources,
    required this.top,
    required this.tracks,
    required this.artists,
    required this.albums,
    required this.playlists,
    required this.errors,
  });

  /// Source ids with results, in preference order.
  final List<String> sources;

  /// The top result: a [Track], [Artist], [Album] or [Playlist] (or null).
  final Object? top;
  final List<Track> tracks;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;

  /// Failed sources → error.
  final Map<String, Object> errors;

  bool get isEmpty => top == null && tracks.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty;

  /// Groups [results] by type; each group lists sources in [preference]
  /// order (SoundCloud first by default). With [only] set, a single
  /// source's results are used.
  factory GroupedResults.from(
    String query,
    Map<String, SourceSearchResults> results,
    List<String> preference, {
    String? only,
  }) {
    final ids = orderByPreference(results.keys.where((id) => only == null || id == only), preference);
    final ok = [for (final id in ids) if (results[id]!.error == null) results[id]!];
    final errors = {for (final id in ids) if (results[id]!.error != null) id: results[id]!.error!};
    final top = _top(query, ok);
    return GroupedResults(
      sources: [for (final r in ok) if (_hasAny(r)) r.sourceId],
      top: top,
      tracks: [for (final r in ok) for (final t in r.tracks.items) if (!identical(t, top)) t],
      artists: [for (final r in ok) for (final a in r.artists.items) if (!identical(a, top)) a],
      albums: [for (final r in ok) ...r.albums.items],
      playlists: [for (final r in ok) ...r.playlists.items],
      errors: errors,
    );
  }

  static bool _hasAny(SourceSearchResults r) =>
      r.tracks.items.isNotEmpty || r.artists.items.isNotEmpty || r.albums.items.isNotEmpty || r.playlists.items.isNotEmpty;

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Exact artist name → exact track title → first track of the most
  /// preferred source → first artist / album / playlist.
  static Object? _top(String query, List<SourceSearchResults> ordered) {
    final q = _norm(query);
    for (final r in ordered) {
      for (final a in r.artists.items) {
        if (_norm(a.name) == q) return a;
      }
    }
    for (final r in ordered) {
      for (final t in r.tracks.items) {
        if (_norm(t.title) == q) return t;
      }
    }
    for (final r in ordered) {
      if (r.tracks.items.isNotEmpty) return r.tracks.items.first;
    }
    for (final r in ordered) {
      if (r.artists.items.isNotEmpty) return r.artists.items.first;
      if (r.albums.items.isNotEmpty) return r.albums.items.first;
      if (r.playlists.items.isNotEmpty) return r.playlists.items.first;
    }
    return null;
  }
}
