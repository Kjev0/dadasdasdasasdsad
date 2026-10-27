import 'package:collection/collection.dart';

import '../core/models/matching.dart';
import '../core/models/track.dart';
import 'scoring_config.dart';

/// Ranking and decision rules shared by the matcher and the import service.
abstract final class MatchPolicy {
  /// Whether [c] can be played at all (in-app, as a preview, or externally).
  /// Previews additionally need [allowPreviewOnly].
  static bool isPlayable(MatchCandidate c, {required bool allowPreviewOnly}) {
    switch (c.candidate.availability.playback) {
      case PlaybackRights.unavailable:
        return false;
      case PlaybackRights.preview:
        return allowPreviewOnly;
      case PlaybackRights.full:
      case PlaybackRights.externalOnly:
      case PlaybackRights.unknown:
        return true;
    }
  }

  /// A candidate that may be accepted without asking the user.
  static bool isAutoAcceptable(MatchCandidate c, MatchOptions options) =>
      c.confidence.isAtLeast(MatchConfidence.high) &&
      c.score >= options.autoAcceptThreshold &&
      !c.hasSignificantVersionDifference &&
      isPlayable(c, allowPreviewOnly: options.allowPreviewOnly);

  /// A candidate the user can reasonably pick (confidence low or better).
  static bool isViable(MatchCandidate c) => c.confidence.isAtLeast(MatchConfidence.low);

  /// Sorts best-first: confidence band, then score (in 0.01 buckets), then
  /// the preferred source, then [sourceOrder] (the user's target order),
  /// then playback quality, then exact score and id for determinism.
  ///
  /// The band comes first so a candidate capped at a lower band (a cover by
  /// another artist, an unknown artist) never outranks a better band
  /// through the source preference, even when its score is just below the
  /// band floor.
  static List<MatchCandidate> rank(
    Iterable<MatchCandidate> candidates, {
    String? preferredSource,
    List<String> sourceOrder = const [],
  }) {
    int sourceRank(String sourceId) {
      if (sourceId == preferredSource) return -1;
      final i = sourceOrder.indexOf(sourceId);
      return i < 0 ? sourceOrder.length : i;
    }

    return candidates.sorted((a, b) {
      final band = a.confidence.index.compareTo(b.confidence.index);
      if (band != 0) return band;
      final bucket = (b.score * 100).round().compareTo((a.score * 100).round());
      if (bucket != 0) return bucket;
      final source = sourceRank(a.candidate.sourceId).compareTo(sourceRank(b.candidate.sourceId));
      if (source != 0) return source;
      final playback = _playbackRank(a).compareTo(_playbackRank(b));
      if (playback != 0) return playback;
      final exact = b.score.compareTo(a.score);
      if (exact != 0) return exact;
      return a.candidate.id.compareTo(b.candidate.id);
    });
  }

  /// Decides the outcome of a search. Returns the decision and the chosen
  /// candidate (only for [MatchDecision.autoAccepted]).
  static (MatchDecision, MatchCandidate?) decide(List<MatchCandidate> ranked, MatchOptions options) {
    final viable = ranked.where(isViable).toList();
    if (options.skipUnavailable &&
        !viable.any((c) => isPlayable(c, allowPreviewOnly: options.allowPreviewOnly))) {
      return (MatchDecision.skipped, null);
    }
    if (viable.isEmpty) return (MatchDecision.notFound, null);
    if (options.reviewMode == ReviewMode.autoAcceptHigh) {
      final chosen = viable.firstWhereOrNull((c) => isAutoAcceptable(c, options));
      if (chosen != null) return (MatchDecision.autoAccepted, chosen);
    }
    return (MatchDecision.needsReview, null);
  }

  static int _playbackRank(MatchCandidate c) => switch (c.candidate.availability.playback) {
        PlaybackRights.full => 0,
        PlaybackRights.externalOnly => 1,
        PlaybackRights.unknown => 2,
        PlaybackRights.preview => 3,
        PlaybackRights.unavailable => 4,
      };
}
