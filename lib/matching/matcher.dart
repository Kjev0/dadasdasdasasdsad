import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../core/contracts/matching.dart';
import '../core/contracts/music_source.dart';
import '../core/errors.dart';
import '../core/models/matching.dart';
import '../core/models/track.dart';
import '../core/util/cancel_token.dart';
import 'match_errors.dart';
import 'match_policy.dart';
import 'normalizer.dart';
import 'query_builder.dart';
import 'scorer.dart';
import 'scoring_config.dart';
import 'util/async_utils.dart';

/// Tunables of [SourceTrackMatcher].
@immutable
class MatcherSettings {
  const MatcherSettings({
    this.maxConcurrentTracks = 3,
    this.searchLimit = 10,
    this.rateLimit = const RateLimitPolicy(),
    this.uploaderStyleSources = TrackNormalizer.defaultUploaderStyleSources,
    this.stopAfterStrongCandidate = true,
  });

  /// Tracks matched at the same time through one matcher (each searches its
  /// target sources concurrently).
  final int maxConcurrentTracks;

  /// Results requested per search query.
  final int searchLimit;
  final RateLimitPolicy rateLimit;
  final Set<String> uploaderStyleSources;

  /// Skip the remaining queries for a source once it returned an exact/high
  /// candidate without version differences (saves API quota).
  final bool stopAfterStrongCandidate;
}

/// Finds an original track on other sources: ISRC lookup first where
/// supported, then up to three metadata searches per source; candidates are
/// scored, de-duplicated, ranked and a decision is made (see
/// [MatchPolicy.decide]).
///
/// Failures of one source (network, rate limit, missing credentials, auth)
/// never fail the whole match: they are recorded in
/// [TrackMatchResult.error] as [SourceMatchFailures] and the other sources'
/// candidates are still returned. Cancellation propagates as
/// [OperationCanceledException].
class SourceTrackMatcher implements TrackMatcher {
  /// Uses the registry's sources; when [MatchOptions.targetSources] is empty
  /// all sources are searched in the user's preference order.
  SourceTrackMatcher({
    required SourceRegistry registry,
    required TrackScorer scorer,
    TrackNormalizer normalizer = const TrackNormalizer(),
    MatcherSettings settings = const MatcherSettings(),
  }) : this.withSources(
          sources: () => registry.ordered,
          scorer: scorer,
          normalizer: normalizer,
          settings: settings,
        );

  /// Uses whatever [sources] returns at call time (preference order).
  SourceTrackMatcher.withSources({
    required List<MusicSource> Function() sources,
    required this.scorer,
    this.normalizer = const TrackNormalizer(),
    this.settings = const MatcherSettings(),
  })  : _sources = sources,
        _slots = AsyncSemaphore(math.max(1, settings.maxConcurrentTracks)),
        _queries = SearchQueryBuilder(uploaderStyleSources: settings.uploaderStyleSources);

  final TrackScorer scorer;
  final TrackNormalizer normalizer;
  final MatcherSettings settings;
  final List<MusicSource> Function() _sources;
  final AsyncSemaphore _slots;
  final SearchQueryBuilder _queries;

  static final _log = Logger('matching.matcher');

  @override
  Future<TrackMatchResult> findMatches(Track original, MatchOptions options, {CancelToken? cancel}) =>
      _slots.withPermit(() => _findMatches(original, options, cancel), cancel: cancel);

  Future<TrackMatchResult> _findMatches(Track original, MatchOptions options, CancelToken? cancel) async {
    cancel?.throwIfCanceled();
    final normalized = _normalize(original);
    final (targets, notReady) = _resolveTargets(original, options);

    final outcomes = await Future.wait([
      for (final source in targets) _searchSource(source, original, normalized, cancel),
    ]);
    cancel?.throwIfCanceled();

    final byId = <String, MatchCandidate>{};
    final searched = <String>[];
    final errors = <String, Object>{};
    for (final outcome in outcomes) {
      if (outcome.searched) searched.add(outcome.sourceId);
      if (outcome.error != null) errors[outcome.sourceId] = outcome.error!;
      for (final c in outcome.candidates) {
        final previous = byId[c.candidate.id];
        if (previous == null || c.score > previous.score) byId[c.candidate.id] = c;
      }
    }

    final ranked = MatchPolicy.rank(
      byId.values,
      preferredSource: options.preferredSource,
      sourceOrder: [for (final s in targets) s.id],
    );
    final top = ranked.take(math.max(1, options.maxCandidates)).toList();
    final (decision, chosen) = MatchPolicy.decide(top, options);
    final error = (errors.isEmpty && searched.isNotEmpty)
        ? null
        : SourceMatchFailures(errors: errors, notReady: notReady, anySourceSearched: searched.isNotEmpty);

    _log.fine(() => 'match ${original.id}: ${decision.name}'
        '${top.isEmpty ? '' : ' best=${top.first.candidate.id} ${top.first.score.toStringAsFixed(3)} '
            '${top.first.confidence.name}'}'
        '${error == null ? '' : ' ($error)'}');

    return TrackMatchResult(
      original: original,
      candidates: List.unmodifiable(top),
      decision: decision,
      chosen: chosen,
      searchedSources: List.unmodifiable(searched),
      error: error,
    );
  }

  NormalizedTrack _normalize(Track track) {
    final s = scorer;
    return s is WeightedTrackScorer ? s.normalized(track) : normalizer.normalize(track);
  }

  /// Target sources in search order, plus ids that were skipped because
  /// they are unknown or not ready. The original's own source is skipped.
  (List<MusicSource>, List<String>) _resolveTargets(Track original, MatchOptions options) {
    final available = _sources();
    final ids = options.targetSources.isNotEmpty ? options.targetSources : [for (final s in available) s.id];
    final targets = <MusicSource>[];
    final notReady = <String>[];
    final seen = <String>{};
    for (final id in ids) {
      if (id == original.sourceId || !seen.add(id)) continue;
      final source = available.firstWhereOrNull((s) => s.id == id);
      if (source == null || !source.isReady) {
        _log.fine('skipping target source $id (${source == null ? 'not registered' : 'not ready'})');
        notReady.add(id);
        continue;
      }
      targets.add(source);
    }
    return (targets, notReady);
  }

  Future<_SourceOutcome> _searchSource(
    MusicSource source,
    Track original,
    NormalizedTrack normalized,
    CancelToken? cancel,
  ) async {
    final candidates = <String, MatchCandidate>{};
    var searched = false;
    Object? error;

    void add(Track track) {
      if (track.id == original.id || candidates.containsKey(track.id)) return;
      candidates[track.id] = scorer.score(original, track);
    }

    bool hasStrong() => candidates.values.any(_isStrong);

    Future<T> call<T>(String label, Future<T> Function() request) => withRateLimitRetry(
          request,
          policy: settings.rateLimit,
          cancel: cancel,
          log: _log,
          label: '${source.id} $label',
        );

    try {
      final isrc = original.isrc;
      if (normalized.isrc != null && isrc != null && source.supports(SourceCapability.isrcLookup)) {
        try {
          final found = await call('isrc lookup', () => source.lookupByIsrc(isrc, cancel: cancel));
          searched = true;
          if (found != null) add(found);
        } on UnsupportedSourceOperation {
          // Declared but not available for this track/region; search instead.
        } on OperationCanceledException {
          rethrow;
        } catch (e) {
          if (_isFatalForSource(e)) rethrow;
          error = e;
          _log.warning('${source.id}: ISRC lookup for ${original.id} failed: $e');
        }
      }

      if (!hasStrong() && source.supports(SourceCapability.searchTracks)) {
        for (final query in _queries.build(normalized, source.id)) {
          cancel?.throwIfCanceled();
          try {
            final page = await call(
              'search',
              () => source.searchTracks(query, limit: settings.searchLimit, cancel: cancel),
            );
            searched = true;
            page.items.forEach(add);
            if (settings.stopAfterStrongCandidate && hasStrong()) break;
          } on UnsupportedSourceOperation catch (e) {
            error ??= e;
            break;
          } on OperationCanceledException {
            rethrow;
          } catch (e) {
            if (_isFatalForSource(e)) rethrow;
            error = e;
            _log.warning('${source.id}: search "$query" failed: $e');
          }
        }
      } else if (!searched && !source.supports(SourceCapability.searchTracks)) {
        error ??= UnsupportedSourceOperation(source.id, 'searchTracks', '${source.displayName} cannot search tracks');
      }
    } on OperationCanceledException {
      rethrow;
    } catch (e, st) {
      // Missing credentials / auth required, or an unexpected bug in a
      // source implementation: isolate it to this source.
      if (cancel?.isCanceled ?? false) throw const OperationCanceledException();
      error = e;
      if (e is FermataException) {
        _log.warning('${source.id}: giving up on ${original.id}: $e');
      } else {
        _log.severe('${source.id}: unexpected error matching ${original.id}', e, st);
      }
    }

    return _SourceOutcome(
      sourceId: source.id,
      candidates: candidates.values.toList(),
      searched: searched,
      // Partial failures (one query out of three) are only logged.
      error: searched ? null : error,
    );
  }

  static bool _isStrong(MatchCandidate c) =>
      c.confidence.isAtLeast(MatchConfidence.high) && !c.hasSignificantVersionDifference;

  /// Errors after which further requests to the source are pointless.
  static bool _isFatalForSource(Object e) => e is MissingCredentialsException || e is AuthRequiredException;
}

class _SourceOutcome {
  const _SourceOutcome({required this.sourceId, required this.candidates, required this.searched, this.error});

  final String sourceId;
  final List<MatchCandidate> candidates;
  final bool searched;
  final Object? error;
}
