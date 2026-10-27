import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import '../core/contracts/library.dart';
import '../core/contracts/matching.dart';
import '../core/contracts/music_source.dart';
import '../core/errors.dart';
import '../core/models/catalog.dart';
import '../core/models/matching.dart';
import '../core/models/track.dart';
import '../core/util/cancel_token.dart';
import 'alternative_search.dart';
import 'import_report.dart';
import 'import_saver.dart';
import 'import_session.dart';
import 'match_policy.dart';
import 'normalizer.dart';
import 'scoring_config.dart';
import 'source_rules.dart';
import 'util/async_utils.dart';

/// Tunables of [PlaylistImportServiceImpl].
@immutable
class ImportSettings {
  const ImportSettings({
    this.maxConcurrentMatches = 3,
    this.maxTracks = 10000,
    this.maxPages = 1000,
    this.progressInterval = const Duration(milliseconds: 100),
    this.rateLimit = const RateLimitPolicy(maxRetries: 3),
    this.alternativesLimit = 20,
    this.writeChunkSize = 500,
    this.explicitOnlySources = MatchingSourceRules.explicitOnlySources,
    this.maxSearchPageSize = MatchingSourceRules.maxSearchPageSize,
  });

  /// Tracks matched in parallel.
  final int maxConcurrentMatches;

  /// Imports stop fetching after this many tracks.
  final int maxTracks;

  /// Safety cap on playlist pages (guards against cursor loops).
  final int maxPages;

  /// Minimum spacing of progress events while matching (phase changes are
  /// always emitted immediately). Zero emits after every track.
  final Duration progressInterval;

  /// Retry policy for playlist page fetches and alternative searches.
  final RateLimitPolicy rateLimit;

  /// Results requested per source by `searchAlternatives`.
  final int alternativesLimit;

  /// Tracks per repository write.
  final int writeChunkSize;

  /// Sources searched for alternatives only when the user picks them (by
  /// `sourceId` or in the session's target sources); YouTube's search quota
  /// is tiny.
  final Set<String> explicitOnlySources;

  /// Per-source cap on the search page size.
  final Map<String, int> maxSearchPageSize;
}

/// Imports a playlist from one source and matches every track on the
/// user's other sources.
///
/// Sessions live in memory. Lifecycle:
/// `fetching → matching → reviewing → saving → done`, or `failed` (fetch
/// error) / `canceled`. A failed save returns to `reviewing` with
/// [ImportSessionState.error] set so it can be retried.
///
/// Saving creates a local playlist holding the *original* tracks in their
/// original order (metadata stays faithful to the source), upserts the
/// originals and every accepted match, and links original ↔ match (see
/// [ImportSaver]). Tracks without an accepted match stay in the playlist as
/// originals; [ImportReport] lists them.
class PlaylistImportServiceImpl implements PlaylistImportService {
  PlaylistImportServiceImpl({
    required this._registry,
    required this._matcher,
    required TrackScorer scorer,
    required TrackRepository trackRepository,
    required PlaylistRepository playlistRepository,
    required TrackLinkRepository linkRepository,
    this.settings = const ImportSettings(),
    TrackNormalizer normalizer = const TrackNormalizer(),
    String Function()? idGenerator,
  })  : _alternatives = AlternativeSearch(
          scorer: scorer,
          normalizer: normalizer,
          rateLimit: settings.rateLimit,
          limit: settings.alternativesLimit,
          maxPageSize: settings.maxSearchPageSize,
        ),
        _saver = ImportSaver(
          tracks: trackRepository,
          playlists: playlistRepository,
          links: linkRepository,
          chunkSize: settings.writeChunkSize,
        ),
        _newId = idGenerator ?? const Uuid().v4;

  final ImportSettings settings;
  final SourceRegistry _registry;
  final TrackMatcher _matcher;
  final AlternativeSearch _alternatives;
  final ImportSaver _saver;
  final String Function() _newId;
  final _sessions = <String, MutableImportSession>{};

  static final _log = Logger('matching.import');

  // ---------------------------------------------------------------------
  // Starting
  // ---------------------------------------------------------------------

  /// Throws [ArgumentError] for an unknown source and
  /// [UnsupportedSourceOperation] when it cannot import playlists. Fetch
  /// failures (network, auth, ...) are reported through the session
  /// ([ImportPhase.failed] with [ImportSessionState.error]).
  @override
  Future<String> start({
    required String sourceId,
    required String playlistIdOrUrl,
    required MatchOptions options,
  }) async {
    final source = _registry.byId(sourceId);
    if (source == null) throw ArgumentError.value(sourceId, 'sourceId', 'Unknown source');
    if (!source.supports(SourceCapability.playlistImport)) {
      throw UnsupportedSourceOperation(
        sourceId,
        'playlistImport',
        '${source.displayName} does not support importing playlists',
      );
    }
    final session = _createSession(sourceId, options);
    _log.info('import ${session.id}: fetching $playlistIdOrUrl from $sourceId');
    unawaited(_run(session, () => _fetchPlaylist(session, source, playlistIdOrUrl)));
    return session.id;
  }

  @override
  Future<String> startWithTracks({
    required String sourceId,
    required String name,
    required List<Track> tracks,
    required MatchOptions options,
  }) async {
    final session = _createSession(sourceId, options);
    session.playlist = Playlist(
      id: 'import:${session.id}',
      name: name,
      kind: PlaylistKind.local,
      sourceId: sourceId,
      trackCount: tracks.length,
    );
    session.tracks.addAll(tracks.take(settings.maxTracks));
    _log.info('import ${session.id}: ${session.tracks.length} provided tracks from $sourceId');
    unawaited(_run(session, null));
    return session.id;
  }

  MutableImportSession _createSession(String sourceId, MatchOptions options) {
    final session = MutableImportSession(
      id: _newId(),
      source: sourceId,
      options: options,
      progressInterval: settings.progressInterval,
    );
    _sessions[session.id] = session;
    return session;
  }

  Future<void> _run(MutableImportSession s, Future<void> Function()? fetch) async {
    try {
      s.emit(immediate: true);
      if (fetch != null) await fetch();
      s.cancelToken.throwIfCanceled();
      s.results = List<TrackMatchResult?>.filled(s.tracks.length, null);
      s.phase = ImportPhase.matching;
      s.emit(immediate: true);
      await _matchAll(s);
      if (s.isTerminal) return;
      s.phase = ImportPhase.reviewing;
      s.emit(immediate: true);
      _log.info('import ${s.id}: matching done, '
          '${s.uniqueResults.where(ImportReport.isAccepted).length}/${s.uniqueResults.length} auto-accepted');
    } on OperationCanceledException {
      _markCanceled(s);
    } catch (e, st) {
      if (s.isTerminal) return;
      _log.warning('import ${s.id} failed', e, st);
      s
        ..error = e
        ..phase = ImportPhase.failed
        ..emit(immediate: true);
      await s.close();
    }
  }

  /// Follows `nextCursor` until the last page, [ImportSettings.maxTracks],
  /// [ImportSettings.maxPages] or a repeated cursor.
  Future<void> _fetchPlaylist(MutableImportSession s, MusicSource source, String idOrUrl) async {
    String? cursor;
    final seenCursors = <String>{};
    for (var page = 0; page < settings.maxPages; page++) {
      s.cancelToken.throwIfCanceled();
      final requestCursor = cursor;
      final detail = await withRateLimitRetry(
        () => source.getPlaylist(idOrUrl, cursor: requestCursor, cancel: s.cancelToken),
        policy: settings.rateLimit,
        cancel: s.cancelToken,
        log: _log,
        label: '${source.id} playlist page ${page + 1}',
      );
      s.playlist ??= detail.playlist;
      s.tracks.addAll(detail.tracks.items.take(settings.maxTracks - s.tracks.length));
      s.emit();
      final next = detail.tracks.nextCursor;
      if (next == null) return;
      if (s.tracks.length >= settings.maxTracks) {
        _log.warning('import ${s.id}: playlist truncated at ${settings.maxTracks} tracks');
        return;
      }
      if (!seenCursors.add(next)) {
        _log.warning('import ${s.id}: ${source.id} repeated cursor "$next"; stopping');
        return;
      }
      cursor = next;
    }
    _log.warning('import ${s.id}: stopped after ${settings.maxPages} pages');
  }

  /// Matches every distinct track once (duplicates share the result) with
  /// [ImportSettings.maxConcurrentMatches] workers.
  Future<void> _matchAll(MutableImportSession s) async {
    final positions = <String, List<int>>{};
    for (var i = 0; i < s.tracks.length; i++) {
      positions.putIfAbsent(s.tracks[i].id, () => []).add(i);
    }
    final queue = Queue.of(positions.keys);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        s.cancelToken.throwIfCanceled();
        final at = positions[queue.removeFirst()]!;
        final track = s.tracks[at.first];
        TrackMatchResult result;
        try {
          result = await _matcher.findMatches(track, s.options, cancel: s.cancelToken);
        } on OperationCanceledException {
          rethrow;
        } catch (e, st) {
          if (s.cancelToken.isCanceled) throw const OperationCanceledException();
          // One broken track must not fail the import.
          _log.warning('import ${s.id}: matching ${track.id} failed', e, st);
          result = TrackMatchResult(original: track, candidates: const [], decision: MatchDecision.notFound, error: e);
        }
        if (s.isTerminal) return;
        for (final p in at) {
          s.results[p] = result;
          s.processed++;
        }
        s.emit();
      }
    }

    final workers = math.min(math.max(1, settings.maxConcurrentMatches), positions.length);
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
  }

  // ---------------------------------------------------------------------
  // Observing
  // ---------------------------------------------------------------------

  @override
  Stream<ImportSessionState> watch(String sessionId) {
    final s = _sessions[sessionId];
    if (s == null) return Stream.error(StateError('Unknown import session $sessionId'));
    return s.watch();
  }

  @override
  ImportSessionState? current(String sessionId) => _sessions[sessionId]?.snapshot();

  /// Summary of the session's current results.
  ImportReport? report(String sessionId) {
    final state = current(sessionId);
    return state == null ? null : ImportReport.fromState(state);
  }

  // ---------------------------------------------------------------------
  // Review
  // ---------------------------------------------------------------------

  /// [candidate] may come from [searchAlternatives]; it is added to the
  /// result's candidates when new.
  @override
  void accept(String sessionId, String originalTrackId, MatchCandidate candidate) {
    final s = _reviewable(sessionId);
    _update(s, originalTrackId, (r) {
      final known = r.candidates.any((c) => c.candidate.id == candidate.candidate.id);
      return r.copyWith(
        candidates: known
            ? r.candidates
            : List.unmodifiable(MatchPolicy.rank(
                [...r.candidates, candidate],
                preferredSource: s.options.preferredSource,
                sourceOrder: s.options.targetSources,
              )),
        decision: MatchDecision.userAccepted,
        chosen: candidate,
      );
    });
  }

  @override
  void reject(String sessionId, String originalTrackId) {
    final s = _reviewable(sessionId);
    _update(s, originalTrackId, (r) => r.copyWith(decision: MatchDecision.userRejected, clearChosen: true));
  }

  @override
  void skip(String sessionId, String originalTrackId) {
    final s = _reviewable(sessionId);
    _update(s, originalTrackId, (r) => r.copyWith(decision: MatchDecision.skipped, clearChosen: true));
  }

  /// Only results still in [MatchDecision.needsReview] are touched (earlier
  /// user decisions stick). The best candidate must be at least
  /// [minConfidence] (never `none`), have no significant version difference
  /// and be playable (previews only when the session allows them).
  @override
  void acceptAllAtLeast(String sessionId, MatchConfidence minConfidence) {
    final s = _reviewable(sessionId);
    var accepted = 0;
    for (final r in s.uniqueResults.toList()) {
      final best = r.best;
      if (r.decision != MatchDecision.needsReview ||
          best == null ||
          best.confidence == MatchConfidence.none ||
          !best.confidence.isAtLeast(minConfidence) ||
          best.hasSignificantVersionDifference ||
          !MatchPolicy.isPlayable(best, allowPreviewOnly: s.options.allowPreviewOnly)) {
        continue;
      }
      final updated = r.copyWith(decision: MatchDecision.userAccepted, chosen: best);
      for (final p in s.resultPositionsOf(r.original.id)) {
        s.results[p] = updated;
      }
      accepted++;
    }
    _log.info('import $sessionId: bulk-accepted $accepted results at >= ${minConfidence.name}');
    s.emit(immediate: true);
  }

  /// Searches one source ([sourceId]) or all of the session's target
  /// sources (all ready sources except explicit-only ones when the session
  /// has none). An empty [query] searches "artist + title" of the original.
  @override
  Future<List<MatchCandidate>> searchAlternatives(
    String sessionId,
    String originalTrackId,
    String query, {
    String? sourceId,
    CancelToken? cancel,
  }) {
    final s = _require(sessionId);
    final original = s.tracks.firstWhereOrNull((t) => t.id == originalTrackId);
    if (original == null) {
      throw ArgumentError.value(originalTrackId, 'originalTrackId', 'Not part of import $sessionId');
    }
    final List<MusicSource> sources;
    if (sourceId != null) {
      final source = _registry.byId(sourceId);
      if (source == null) throw ArgumentError.value(sourceId, 'sourceId', 'Unknown source');
      sources = [source];
    } else {
      final ids = s.options.targetSources.isNotEmpty
          ? s.options.targetSources
          : [
              for (final src in _registry.ordered)
                if (!settings.explicitOnlySources.contains(src.id)) src.id,
            ];
      sources = [
        for (final id in ids.toSet())
          if (id != s.source) ?_registry.byId(id),
      ];
    }
    return _alternatives.search(
      original: original,
      sources: sources,
      query: query,
      preferredSource: s.options.preferredSource,
      cancel: cancel,
    );
  }

  // ---------------------------------------------------------------------
  // Saving & lifecycle
  // ---------------------------------------------------------------------

  /// Only allowed in [ImportPhase.reviewing]. On failure the session
  /// returns to reviewing with the error set and the error is rethrown.
  @override
  Future<String> save(String sessionId, {String? playlistName}) async {
    final s = _require(sessionId);
    if (s.phase != ImportPhase.reviewing) {
      throw StateError('Import $sessionId cannot be saved while ${s.phase.name}');
    }
    s
      ..phase = ImportPhase.saving
      ..error = null
      ..emit(immediate: true);
    try {
      final playlistId = await _saver.save(
        sourceId: s.source,
        sourcePlaylist: s.playlist,
        originals: s.tracks,
        results: s.uniqueResults,
        playlistName: playlistName,
      );
      s
        ..savedPlaylistId = playlistId
        ..phase = ImportPhase.done
        ..emit(immediate: true);
      await s.close();
      return playlistId;
    } catch (e, st) {
      _log.warning('import $sessionId: save failed', e, st);
      s
        ..error = e
        ..phase = ImportPhase.reviewing
        ..emit(immediate: true);
      rethrow;
    }
  }

  /// Cancels fetching/matching. Ignored once saving started (repository
  /// writes are not interruptible) and for finished sessions.
  @override
  void cancel(String sessionId) {
    final s = _sessions[sessionId];
    if (s == null || s.isTerminal) return;
    if (s.phase == ImportPhase.saving) {
      _log.info('import $sessionId: cancel ignored while saving');
      return;
    }
    s.cancelToken.cancel();
    _markCanceled(s);
  }

  /// Cancels (if running) and forgets a session.
  void discard(String sessionId) {
    cancel(sessionId);
    final s = _sessions.remove(sessionId);
    if (s != null) unawaited(s.close());
  }

  /// Cancels and forgets every session.
  void dispose() {
    for (final id in _sessions.keys.toList()) {
      discard(id);
    }
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  void _markCanceled(MutableImportSession s) {
    if (s.isTerminal) return;
    _log.info('import ${s.id} canceled');
    s
      ..phase = ImportPhase.canceled
      ..emit(immediate: true);
    unawaited(s.close());
  }

  MutableImportSession _require(String sessionId) =>
      _sessions[sessionId] ?? (throw StateError('Unknown import session $sessionId'));

  MutableImportSession _reviewable(String sessionId) {
    final s = _require(sessionId);
    if (s.phase != ImportPhase.matching && s.phase != ImportPhase.reviewing) {
      throw StateError('Import $sessionId cannot be reviewed while ${s.phase.name}');
    }
    return s;
  }

  void _update(MutableImportSession s, String originalTrackId, TrackMatchResult Function(TrackMatchResult) change) {
    final at = s.resultPositionsOf(originalTrackId);
    if (at.isEmpty) {
      throw ArgumentError.value(originalTrackId, 'originalTrackId', 'No match result in import ${s.id}');
    }
    final updated = change(s.results[at.first]!);
    for (final p in at) {
      s.results[p] = updated;
    }
    s.emit(immediate: true);
  }
}
