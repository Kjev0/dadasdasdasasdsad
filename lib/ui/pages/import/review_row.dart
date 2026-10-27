import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/matching.dart';
import '../../../core/models/track.dart';
import '../../../core/util/cancel_token.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/dialogs/sheet.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/tracks/track_format.dart';
import 'import_format.dart';

/// Confidence badge: label + percentage, coloured by confidence.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({super.key, required this.candidate});

  final MatchCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = confidenceColor(context.colors, candidate.confidence);
    final pct = (candidate.score * 100).round();
    return Semantics(
      label: l10n.importConfidenceSemantics(confidenceLabel(l10n, candidate.confidence), pct),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(borderRadius: context.radii.xsAll, border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Text(
          '${confidenceLabel(l10n, candidate.confidence)} · $pct %',
          style: context.type.caption.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Chips for the version/metadata differences of a candidate.
class DifferenceChips extends StatelessWidget {
  const DifferenceChips({super.key, required this.candidate});

  final MatchCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final diffs = candidate.differences.toList()..sort((a, b) => a.index.compareTo(b.index));
    return Wrap(spacing: 6, runSpacing: 6, children: [
      if (candidate.durationDelta != null)
        _Chip(label: durationDeltaLabel(candidate.durationDelta!), color: c.textSecondary, tabular: true),
      if (candidate.matchedByIsrc) _Chip(label: l10n.importMatchedByIsrc, color: c.success),
      for (final d in diffs)
        _Chip(
          label: differenceLabel(l10n, d),
          color: MatchCandidate.significantVersionDifferences.contains(d) ? c.danger : c.warning,
        ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, this.tabular = false});

  final String label;
  final Color color;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: context.radii.xsAll),
      child: Text(
        label,
        style: context.type.caption.copyWith(color: color, fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null),
      ),
    );
  }
}

class _TrackColumn extends StatelessWidget {
  const _TrackColumn({required this.track, this.caption});

  final Track track;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (caption != null) Text(caption!, style: context.type.caption.copyWith(color: c.textTertiary)),
      Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.type.body),
      Text(
        [track.artistLine, if (track.duration != null) formatDuration(track.duration!)].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.type.bodySmall,
      ),
      const SizedBox(height: 4),
      Wrap(spacing: 6, runSpacing: 4, children: [
        SourceChip(sourceId: track.sourceId, dense: true),
        if (AvailabilityBadge.isNotable(AvailabilityBadge.primaryKind(track))) AvailabilityBadge.forTrack(track, dense: true),
      ]),
    ]);
  }
}

/// One row of the import review: original vs. match, confidence, duration
/// difference, version differences, availability and the review actions.
class ReviewRow extends ConsumerWidget {
  const ReviewRow({super.key, required this.sessionId, required this.result});

  final String sessionId;
  final TrackMatchResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final svc = ref.read(playlistImportProvider);
    final r = result;
    final proposed = proposedCandidate(r);
    final id = r.original.id;
    final accepted = isAccepted(r.decision);
    final unsafeOnly = proposed == null && r.candidates.isNotEmpty;

    final decisionColor = switch (r.decision) {
      MatchDecision.autoAccepted || MatchDecision.userAccepted => c.success,
      MatchDecision.needsReview => c.warning,
      MatchDecision.notFound || MatchDecision.userRejected => c.danger,
      MatchDecision.skipped => c.textSecondary,
    };

    final original = _TrackColumn(track: r.original, caption: l10n.importOriginal);
    final match = proposed == null
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.importMatch, style: context.type.caption.copyWith(color: c.textTertiary)),
            Text(unsafeOnly ? l10n.importOnlyOtherVersions : l10n.importNoMatch, style: context.type.bodySmall),
          ])
        : _TrackColumn(track: proposed.candidate, caption: l10n.importMatch);

    return Container(
      key: ValueKey('import.row.$id'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: context.radii.mdAll,
        border: Border.all(color: c.outlineSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [original, const SizedBox(height: 10), match]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: original),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Icon(Icons.arrow_forward_rounded, size: 18, color: c.textTertiary),
            ),
            Expanded(child: match),
          ]);
        }),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(
            decisionLabel(l10n, r.decision),
            key: ValueKey('import.row.$id.decision'),
            style: context.type.label.copyWith(color: decisionColor),
          ),
          if (proposed != null) ConfidenceBadge(candidate: proposed),
          if (proposed != null) DifferenceChips(candidate: proposed),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          FermataButton(
            key: ValueKey('import.row.$id.accept'),
            label: l10n.importAccept,
            icon: Icons.check_rounded,
            variant: FermataButtonVariant.secondary,
            onPressed: proposed == null || (accepted && r.chosen == proposed) ? null : () => svc.accept(sessionId, id, proposed),
          ),
          FermataButton(
            key: ValueKey('import.row.$id.reject'),
            label: l10n.importReject,
            icon: Icons.close_rounded,
            variant: FermataButtonVariant.ghost,
            onPressed: r.decision == MatchDecision.userRejected || r.candidates.isEmpty ? null : () => svc.reject(sessionId, id),
          ),
          FermataButton(
            key: ValueKey('import.row.$id.skip'),
            label: l10n.importSkip,
            variant: FermataButtonVariant.ghost,
            onPressed: r.decision == MatchDecision.skipped ? null : () => svc.skip(sessionId, id),
          ),
          if (r.candidates.length > (proposed == null ? 0 : 1))
            FermataButton(
              key: ValueKey('import.row.$id.candidates'),
              label: l10n.importOtherCandidates(r.candidates.length),
              variant: FermataButtonVariant.ghost,
              onPressed: () => _pickCandidate(context, ref, r.candidates, title: l10n.importCandidatesTitle(r.original.title)),
            ),
          FermataButton(
            key: ValueKey('import.row.$id.search'),
            label: l10n.importSearch,
            icon: Icons.search_rounded,
            variant: FermataButtonVariant.ghost,
            onPressed: () => showFermataSheet<void>(
              context,
              builder: (_) => ManualSearchSheet(sessionId: sessionId, original: r.original),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _pickCandidate(BuildContext context, WidgetRef ref, List<MatchCandidate> candidates, {required String title}) async {
    final picked = await showFermataSheet<MatchCandidate>(
      context,
      builder: (sheet) => _CandidateList(title: title, candidates: candidates, onPick: (c) => Navigator.of(sheet).pop(c)),
    );
    if (picked != null) ref.read(playlistImportProvider).accept(sessionId, result.original.id, picked);
  }
}

class _CandidateList extends StatelessWidget {
  const _CandidateList({required this.title, required this.candidates, required this.onPick});

  final String title;
  final List<MatchCandidate> candidates;
  final ValueChanged<MatchCandidate> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(title, style: context.type.titleSmall),
        const SizedBox(height: 12),
        for (final cand in candidates)
          Container(
            key: ValueKey('import.candidate.${cand.candidate.id}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: context.radii.smAll, border: Border.all(color: c.outlineSubtle)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _TrackColumn(track: cand.candidate),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                ConfidenceBadge(candidate: cand),
                DifferenceChips(candidate: cand),
              ]),
              if (cand.hasSignificantVersionDifference) ...[
                const SizedBox(height: 6),
                Text(l10n.importDifferentVersionWarning, style: context.type.caption.copyWith(color: c.danger)),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FermataButton(
                  key: ValueKey('import.candidate.${cand.candidate.id}.use'),
                  label: l10n.importUseThis,
                  variant: FermataButtonVariant.secondary,
                  onPressed: () => onPick(cand),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

/// Manual search for one track (`PlaylistImportService.searchAlternatives`).
class ManualSearchSheet extends ConsumerStatefulWidget {
  const ManualSearchSheet({super.key, required this.sessionId, required this.original});

  final String sessionId;
  final Track original;

  @override
  ConsumerState<ManualSearchSheet> createState() => _ManualSearchSheetState();
}

class _ManualSearchSheetState extends ConsumerState<ManualSearchSheet> {
  late final _query = TextEditingController(text: '${widget.original.primaryArtist} ${widget.original.title}'.trim());
  final _latest = LatestOnly();
  List<MatchCandidate>? _results;
  Object? _error;
  bool _searching = false;

  @override
  void dispose() {
    _latest.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    final token = _latest.next();
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(playlistImportProvider)
          .searchAlternatives(widget.sessionId, widget.original.id, q, cancel: token);
      if (mounted && !token.isCanceled) setState(() => _results = results);
    } catch (e) {
      if (mounted && !token.isCanceled) setState(() => _error = e);
    } finally {
      if (mounted && !token.isCanceled) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = _results;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            Expanded(
              child: TextField(
                key: const ValueKey('import.manualSearch.query'),
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(labelText: l10n.importSearchFor(widget.original.title)),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            FermataButton(
              key: const ValueKey('import.manualSearch.go'),
              label: l10n.importSearch,
              busy: _searching,
              onPressed: _search,
            ),
          ]),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(errorMessageFor(l10n, _error!) ?? l10n.errorGeneric, style: context.type.bodySmall),
          )
        else if (results != null && results.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text(l10n.importSearchNoResults, style: context.type.bodySmall))
        else if (results != null)
          Flexible(
            child: _CandidateList(
              title: l10n.importSearchResults,
              candidates: results,
              onPick: (cand) {
                ref.read(playlistImportProvider).accept(widget.sessionId, widget.original.id, cand);
                Navigator.of(context).pop();
              },
            ),
          ),
      ]),
    );
  }
}
