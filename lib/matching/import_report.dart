import 'package:flutter/foundation.dart';

import '../core/contracts/matching.dart';
import '../core/models/matching.dart';
import '../core/models/track.dart';

/// A playlist entry that has no accepted match on any target source. It is
/// still saved (as the original track) and shows as unavailable unless the
/// original source itself can play it.
@immutable
class MissingTrack {
  const MissingTrack({required this.position, required this.track, required this.decision, this.error});

  /// 0-based position in the imported playlist.
  final int position;
  final Track track;

  /// notFound, skipped, userRejected, or needsReview (never resolved).
  final MatchDecision decision;

  /// Why matching failed, when it did (e.g. `SourceMatchFailures`).
  final Object? error;
}

/// Summary of an import for the UI (result screen, "N tracks missing").
@immutable
class ImportReport {
  const ImportReport({
    required this.total,
    required this.counts,
    required this.matchedBySource,
    required this.missing,
    this.truncated = false,
  });

  factory ImportReport.fromState(ImportSessionState state) =>
      ImportReport.fromResults(state.results, expectedTotal: state.playlist?.trackCount);

  /// [results] in playlist order (one per position). [expectedTotal] is the
  /// track count the source reported; a larger value means the import was
  /// cut at the track cap.
  factory ImportReport.fromResults(List<TrackMatchResult> results, {int? expectedTotal}) {
    final counts = {for (final d in MatchDecision.values) d: 0};
    final bySource = <String, int>{};
    final missing = <MissingTrack>[];
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      counts[r.decision] = counts[r.decision]! + 1;
      final chosen = r.chosen;
      if (isAccepted(r) && chosen != null) {
        bySource.update(chosen.candidate.sourceId, (n) => n + 1, ifAbsent: () => 1);
      } else {
        missing.add(MissingTrack(position: i, track: r.original, decision: r.decision, error: r.error));
      }
    }
    return ImportReport(
      total: results.length,
      counts: Map.unmodifiable(counts),
      matchedBySource: Map.unmodifiable(bySource),
      missing: List.unmodifiable(missing),
      truncated: expectedTotal != null && expectedTotal > results.length,
    );
  }

  static bool isAccepted(TrackMatchResult r) =>
      r.chosen != null && (r.decision == MatchDecision.autoAccepted || r.decision == MatchDecision.userAccepted);

  /// Playlist entries covered by this report.
  final int total;

  /// Entries per decision (every decision present, 0 when unused).
  final Map<MatchDecision, int> counts;

  /// Accepted matches per target source id.
  final Map<String, int> matchedBySource;

  /// Entries without an accepted match, in playlist order.
  final List<MissingTrack> missing;

  /// Whether the source playlist had more tracks than were imported.
  final bool truncated;

  int count(MatchDecision decision) => counts[decision] ?? 0;

  int get matched => count(MatchDecision.autoAccepted) + count(MatchDecision.userAccepted);

  int get pendingReview => count(MatchDecision.needsReview);

  double get matchRate => total == 0 ? 0 : matched / total;

  List<MissingTrack> get notFound => missing.where((m) => m.decision == MatchDecision.notFound).toList();

  List<MissingTrack> get skipped => missing.where((m) => m.decision == MatchDecision.skipped).toList();

  /// Entries whose matching hit source errors.
  List<MissingTrack> get failed => missing.where((m) => m.error != null).toList();
}
