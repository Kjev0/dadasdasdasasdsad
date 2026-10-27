import 'package:flutter/foundation.dart';

import 'track.dart';

enum MatchConfidence {
  /// Identical identifier (ISRC or provider cross-reference).
  exact,

  /// Very likely the same recording.
  high,

  /// Plausible; needs a human check unless the user chose otherwise.
  medium,

  /// Weak; never auto-accepted.
  low,

  /// No usable candidate.
  none,
}

/// Version / metadata differences between an original and a candidate.
enum MatchDifference {
  remix,
  live,
  acoustic,
  extended,
  radioEdit,
  instrumental,
  karaoke,
  cover,
  remaster,
  sped,
  slowed,
  demo,
  explicitMismatch,
  durationMismatch,
  albumMismatch,
  yearMismatch,
  artistMismatch,
  featuredArtistMismatch,
  titleMismatch,

  /// Candidate is only a preview / not fully playable.
  previewOnly,
}

@immutable
class MatchCandidate {
  const MatchCandidate({
    required this.candidate,
    required this.score,
    required this.confidence,
    this.differences = const {},
    this.durationDelta,
    this.matchedByIsrc = false,
    this.breakdown = const {},
  });

  final Track candidate;

  /// Combined weighted score in 0..1.
  final double score;
  final MatchConfidence confidence;
  final Set<MatchDifference> differences;

  /// candidate.duration - original.duration (null if either is unknown).
  final Duration? durationDelta;
  final bool matchedByIsrc;

  /// Per-signal sub-scores for transparency in the review UI
  /// (e.g. `title`, `artist`, `album`, `duration`, `version`).
  final Map<String, double> breakdown;

  /// Version differences that make the candidate a different recording.
  bool get hasSignificantVersionDifference => differences.any(significantVersionDifferences.contains);

  static const significantVersionDifferences = {
    MatchDifference.remix,
    MatchDifference.live,
    MatchDifference.acoustic,
    MatchDifference.extended,
    MatchDifference.instrumental,
    MatchDifference.karaoke,
    MatchDifference.cover,
    MatchDifference.sped,
    MatchDifference.slowed,
    MatchDifference.demo,
  };
}

enum MatchDecision {
  /// Accepted automatically (score above the auto-accept threshold, no
  /// significant version difference).
  autoAccepted,
  needsReview,
  notFound,
  userAccepted,
  userRejected,
  skipped,
}

@immutable
class TrackMatchResult {
  const TrackMatchResult({
    required this.original,
    required this.candidates,
    required this.decision,
    this.chosen,
    this.searchedSources = const [],
    this.error,
  });

  final Track original;

  /// Sorted best-first.
  final List<MatchCandidate> candidates;
  final MatchDecision decision;

  /// The accepted candidate (auto or user), if any.
  final MatchCandidate? chosen;
  final List<String> searchedSources;
  final Object? error;

  MatchCandidate? get best => candidates.isEmpty ? null : candidates.first;

  TrackMatchResult copyWith({
    List<MatchCandidate>? candidates,
    MatchDecision? decision,
    MatchCandidate? chosen,
    bool clearChosen = false,
  }) =>
      TrackMatchResult(
        original: original,
        candidates: candidates ?? this.candidates,
        decision: decision ?? this.decision,
        chosen: clearChosen ? null : (chosen ?? this.chosen),
        searchedSources: searchedSources,
        error: error,
      );
}

enum ReviewMode {
  /// Auto-accept high/exact confidence matches, review the rest.
  autoAcceptHigh,

  /// Every match must be reviewed.
  reviewAll,
}

@immutable
class MatchOptions {
  const MatchOptions({
    this.targetSources = const [],
    this.reviewMode = ReviewMode.autoAcceptHigh,
    this.autoAcceptThreshold = 0.88,
    this.skipUnavailable = false,
    this.preferredSource,
    this.maxCandidates = 5,
    this.allowPreviewOnly = false,
  });

  /// Sources to search, in preference order.
  final List<String> targetSources;
  final ReviewMode reviewMode;
  final double autoAcceptThreshold;
  final bool skipUnavailable;
  final String? preferredSource;
  final int maxCandidates;
  final bool allowPreviewOnly;
}
