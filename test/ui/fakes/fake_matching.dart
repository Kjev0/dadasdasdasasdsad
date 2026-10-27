import 'dart:async';

import 'package:fermata/core/contracts/matching.dart';
import 'package:fermata/core/models/matching.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';

/// Deterministic scorer: same lowercase title → 1.0 (high), else 0.3 (low).
class FakeTrackScorer implements TrackScorer {
  @override
  MatchCandidate score(Track original, Track candidate) {
    final same = original.title.toLowerCase() == candidate.title.toLowerCase();
    return MatchCandidate(
      candidate: candidate,
      score: same ? 1.0 : 0.3,
      confidence: same ? MatchConfidence.high : MatchConfidence.low,
    );
  }
}

/// Returns preset results by original track id (default: not found).
class FakeTrackMatcher implements TrackMatcher {
  final results = <String, TrackMatchResult>{};
  final requested = <String>[];

  @override
  Future<TrackMatchResult> findMatches(Track original, MatchOptions options, {CancelToken? cancel}) async {
    requested.add(original.id);
    return results[original.id] ?? TrackMatchResult(original: original, candidates: const [], decision: MatchDecision.notFound);
  }
}

/// In-memory import sessions. `start`/`startWithTracks` create a session in
/// the `reviewing` phase with [presetResults] (or "not found" per track);
/// review actions update decisions and emit on [watch].
class FakePlaylistImportService implements PlaylistImportService {
  final _sessions = <String, ImportSessionState>{};
  final _controllers = <String, StreamController<ImportSessionState>>{};
  final calls = <String>[];

  /// Results used for `start` (by source playlist id) — default empty.
  final presetResults = <String, List<TrackMatchResult>>{};

  /// Alternatives returned by [searchAlternatives].
  List<MatchCandidate> alternatives = const [];
  int _next = 1;

  void _emit(String id, ImportSessionState s) {
    _sessions[id] = s;
    _controllers.putIfAbsent(id, () => StreamController.broadcast()).add(s);
  }

  ImportSessionState _session(String id, String source, List<TrackMatchResult> results) => ImportSessionState(
        id: id,
        phase: ImportPhase.reviewing,
        source: source,
        results: results,
        total: results.length,
        processed: results.length,
      );

  @override
  Future<String> start({required String sourceId, required String playlistIdOrUrl, required MatchOptions options}) async {
    calls.add('start');
    final id = 's${_next++}';
    _emit(id, _session(id, sourceId, presetResults[playlistIdOrUrl] ?? const []));
    return id;
  }

  @override
  Future<String> startWithTracks({
    required String sourceId,
    required String name,
    required List<Track> tracks,
    required MatchOptions options,
  }) async {
    calls.add('startWithTracks');
    final id = 's${_next++}';
    _emit(id, _session(id, sourceId, [
      for (final t in tracks) TrackMatchResult(original: t, candidates: const [], decision: MatchDecision.notFound),
    ]));
    return id;
  }

  @override
  Stream<ImportSessionState> watch(String sessionId) async* {
    final current = _sessions[sessionId];
    if (current != null) yield current;
    yield* _controllers.putIfAbsent(sessionId, () => StreamController.broadcast()).stream;
  }

  @override
  ImportSessionState? current(String sessionId) => _sessions[sessionId];

  void _decide(String sessionId, String originalTrackId, TrackMatchResult Function(TrackMatchResult r) change) {
    final s = _sessions[sessionId];
    if (s == null) return;
    _emit(
      sessionId,
      ImportSessionState(
        id: s.id,
        phase: s.phase,
        source: s.source,
        playlist: s.playlist,
        results: [for (final r in s.results) r.original.id == originalTrackId ? change(r) : r],
        total: s.total,
        processed: s.processed,
      ),
    );
  }

  @override
  void accept(String sessionId, String originalTrackId, MatchCandidate candidate) {
    calls.add('accept');
    _decide(sessionId, originalTrackId, (r) => r.copyWith(decision: MatchDecision.userAccepted, chosen: candidate));
  }

  @override
  void reject(String sessionId, String originalTrackId) {
    calls.add('reject');
    _decide(sessionId, originalTrackId, (r) => r.copyWith(decision: MatchDecision.userRejected, clearChosen: true));
  }

  @override
  void skip(String sessionId, String originalTrackId) {
    calls.add('skip');
    _decide(sessionId, originalTrackId, (r) => r.copyWith(decision: MatchDecision.skipped, clearChosen: true));
  }

  @override
  void acceptAllAtLeast(String sessionId, MatchConfidence minConfidence) {
    calls.add('acceptAllAtLeast');
    final s = _sessions[sessionId];
    if (s == null) return;
    for (final r in s.results) {
      final best = r.best;
      if (best != null && best.confidence.index <= minConfidence.index && !best.hasSignificantVersionDifference) {
        accept(sessionId, r.original.id, best);
      }
    }
  }

  @override
  Future<List<MatchCandidate>> searchAlternatives(String sessionId, String originalTrackId, String query,
      {String? sourceId, CancelToken? cancel}) async {
    calls.add('searchAlternatives');
    return alternatives;
  }

  @override
  Future<String> save(String sessionId, {String? playlistName}) async {
    calls.add('save');
    final s = _sessions[sessionId];
    final playlistId = 'imported-$sessionId';
    if (s != null) {
      _emit(
        sessionId,
        ImportSessionState(
          id: s.id,
          phase: ImportPhase.done,
          source: s.source,
          playlist: s.playlist,
          results: s.results,
          total: s.total,
          processed: s.processed,
          savedPlaylistId: playlistId,
        ),
      );
    }
    return playlistId;
  }

  @override
  void cancel(String sessionId) {
    calls.add('cancel');
    final s = _sessions[sessionId];
    if (s == null) return;
    _emit(
      sessionId,
      ImportSessionState(id: s.id, phase: ImportPhase.canceled, source: s.source, results: s.results, total: s.total, processed: s.processed),
    );
  }
}
