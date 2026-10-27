import 'package:flutter/material.dart';

import '../../../core/contracts/matching.dart';
import '../../../core/contracts/music_source.dart';
import '../../../core/models/matching.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../settings/app_settings.dart';
import '../../design/fermata_colors.dart';

/// Localized label of a version/metadata difference.
String differenceLabel(AppLocalizations l10n, MatchDifference d) => switch (d) {
      MatchDifference.remix => l10n.importDiffRemix,
      MatchDifference.live => l10n.importDiffLive,
      MatchDifference.acoustic => l10n.importDiffAcoustic,
      MatchDifference.extended => l10n.importDiffExtended,
      MatchDifference.radioEdit => l10n.importDiffRadioEdit,
      MatchDifference.instrumental => l10n.importDiffInstrumental,
      MatchDifference.karaoke => l10n.importDiffKaraoke,
      MatchDifference.cover => l10n.importDiffCover,
      MatchDifference.remaster => l10n.importDiffRemaster,
      MatchDifference.sped => l10n.importDiffSped,
      MatchDifference.slowed => l10n.importDiffSlowed,
      MatchDifference.demo => l10n.importDiffDemo,
      MatchDifference.explicitMismatch => l10n.importDiffExplicit,
      MatchDifference.durationMismatch => l10n.importDiffDuration,
      MatchDifference.albumMismatch => l10n.importDiffAlbum,
      MatchDifference.yearMismatch => l10n.importDiffYear,
      MatchDifference.artistMismatch => l10n.importDiffArtist,
      MatchDifference.featuredArtistMismatch => l10n.importDiffFeatured,
      MatchDifference.titleMismatch => l10n.importDiffTitle,
      MatchDifference.previewOnly => l10n.importDiffPreview,
    };

String confidenceLabel(AppLocalizations l10n, MatchConfidence c) => switch (c) {
      MatchConfidence.exact => l10n.importConfidenceExact,
      MatchConfidence.high => l10n.importConfidenceHigh,
      MatchConfidence.medium => l10n.importConfidenceMedium,
      MatchConfidence.low => l10n.importConfidenceLow,
      MatchConfidence.none => l10n.importConfidenceNone,
    };

Color confidenceColor(FermataColors c, MatchConfidence conf) => switch (conf) {
      MatchConfidence.exact || MatchConfidence.high => c.success,
      MatchConfidence.medium => c.warning,
      MatchConfidence.low || MatchConfidence.none => c.danger,
    };

String decisionLabel(AppLocalizations l10n, MatchDecision d) => switch (d) {
      MatchDecision.autoAccepted => l10n.importDecisionAuto,
      MatchDecision.userAccepted => l10n.importDecisionAccepted,
      MatchDecision.needsReview => l10n.importDecisionReview,
      MatchDecision.notFound => l10n.importDecisionNotFound,
      MatchDecision.userRejected => l10n.importDecisionRejected,
      MatchDecision.skipped => l10n.importDecisionSkipped,
    };

/// `+3 s`, `−12 s`, `±0 s`.
String durationDeltaLabel(Duration delta) {
  final s = delta.inMilliseconds / 1000;
  final r = s.round();
  if (r == 0) return '±0 s';
  return r > 0 ? '+$r s' : '−${-r} s';
}

/// The candidate to propose for a row: the chosen one, else the best
/// candidate without a significant version difference. Never proposes a
/// remix/live/… automatically.
MatchCandidate? proposedCandidate(TrackMatchResult r) {
  if (r.chosen != null) return r.chosen;
  for (final c in r.candidates) {
    if (!c.hasSignificantVersionDifference) return c;
  }
  return null;
}

bool isAccepted(MatchDecision d) => d == MatchDecision.autoAccepted || d == MatchDecision.userAccepted;

/// Results that end up without a match (for the "missing tracks" report).
List<TrackMatchResult> unmatchedResults(ImportSessionState s) =>
    [for (final r in s.results) if (!isAccepted(r.decision)) r];

/// Copyable report of tracks without a match.
String missingTracksReport(AppLocalizations l10n, ImportSessionState s) {
  final missing = unmatchedResults(s);
  final b = StringBuffer()..writeln(l10n.importReportHeader(s.playlist?.name ?? l10n.importUntitled, missing.length));
  for (final r in missing) {
    final artist = r.original.artistLine;
    b.writeln('${artist.isEmpty ? '' : '$artist — '}${r.original.title} (${decisionLabel(l10n, r.decision)})');
  }
  return b.toString().trimRight();
}

/// Sources that can be match targets: searchable and playable inside
/// Fermata (previews only when allowed). External-only providers are never
/// targets.
bool isImportTarget(MusicSource s, {required bool allowPreviewOnly}) =>
    s.supports(SourceCapability.searchTracks) &&
    ((s.supports(SourceCapability.stream) && !s.supports(SourceCapability.previewOnly)) ||
        (allowPreviewOnly && s.supports(SourceCapability.previewOnly)));

/// Eligible targets: every enabled target source except [origin], in the
/// user's provider order (SoundCloud first by default).
List<MusicSource> eligibleImportTargets(
  List<MusicSource> ordered,
  AppSettings settings, {
  String? origin,
  required bool allowPreviewOnly,
}) {
  final order = settings.services.providerOrder;
  int rank(MusicSource s) {
    final i = order.indexOf(s.id);
    return i < 0 ? order.length : i;
  }

  final list = [
    for (final s in ordered)
      if (s.id != origin &&
          !settings.services.disabledSources.contains(s.id) &&
          isImportTarget(s, allowPreviewOnly: allowPreviewOnly))
        s,
  ]..sort((a, b) => rank(a).compareTo(rank(b)));
  return list;
}
