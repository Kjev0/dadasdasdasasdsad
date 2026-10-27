import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import '../core/contracts/matching.dart';
import '../core/contracts/music_source.dart';
import '../core/errors.dart';
import '../core/models/matching.dart';
import '../core/models/track.dart';
import '../core/util/cancel_token.dart';
import 'match_policy.dart';
import 'normalizer.dart';
import 'query_builder.dart';
import 'scorer.dart';
import 'util/async_utils.dart';

/// Manual "find another version" search for one original track: runs a
/// user query on one or several sources and scores every result against
/// the original.
class AlternativeSearch {
  AlternativeSearch({
    required this._scorer,
    this.normalizer = const TrackNormalizer(),
    this.rateLimit = const RateLimitPolicy(),
    this.limit = 20,
  });

  final TrackScorer _scorer;
  final TrackNormalizer normalizer;
  final RateLimitPolicy rateLimit;

  /// Results requested per source.
  final int limit;

  static final _log = Logger('matching.alternatives');

  /// Searches [sources] (those that are ready and can search) concurrently.
  /// An empty [query] falls back to "artist + title" of [original].
  ///
  /// Sources that fail are skipped; if every source fails the first error
  /// is thrown. Throws [StateError] when no source can search at all.
  Future<List<MatchCandidate>> search({
    required Track original,
    required List<MusicSource> sources,
    required String query,
    String? preferredSource,
    CancelToken? cancel,
  }) async {
    final searchable = sources.where((s) => s.isReady && s.supports(SourceCapability.searchTracks)).toList();
    if (searchable.isEmpty) throw StateError('No connected source can search for alternatives');

    final scorer = _scorer;
    final normalized = scorer is WeightedTrackScorer ? scorer.normalized(original) : normalizer.normalize(original);
    final errors = <Object>[];

    Future<List<Track>> searchOne(MusicSource source) async {
      final text = query.trim().isEmpty
          ? (const SearchQueryBuilder().build(normalized, source.id).firstOrNull ?? original.title)
          : SearchQueryBuilder.sanitize(query);
      try {
        final page = await withRateLimitRetry(
          () => source.searchTracks(text, limit: limit, cancel: cancel),
          policy: rateLimit,
          cancel: cancel,
          log: _log,
          label: '${source.id} alternatives',
        );
        return page.items;
      } on OperationCanceledException {
        rethrow;
      } catch (e) {
        if (cancel?.isCanceled ?? false) throw const OperationCanceledException();
        _log.warning('alternatives for ${original.id} on ${source.id} failed: $e');
        errors.add(e);
        return const [];
      }
    }

    final pages = await Future.wait(searchable.map(searchOne));
    cancel?.throwIfCanceled();
    if (errors.length == searchable.length) throw errors.first;

    final byId = <String, MatchCandidate>{};
    for (final track in pages.expand((p) => p)) {
      if (track.id == original.id || byId.containsKey(track.id)) continue;
      byId[track.id] = _scorer.score(original, track);
    }
    return MatchPolicy.rank(
      byId.values,
      preferredSource: preferredSource,
      sourceOrder: [for (final s in searchable) s.id],
    );
  }
}
