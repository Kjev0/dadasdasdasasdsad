import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/matching.dart';
import '../../../core/models/matching.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/dialogs/dialogs.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/feedback/toast.dart';
import 'import_format.dart';
import 'review_row.dart';

/// Live state of one import session (null when the id is unknown, e.g.
/// after a restart — sessions live in memory).
final importSessionProvider = StreamProvider.autoDispose.family<ImportSessionState?, String>((ref, id) async* {
  final svc = ref.watch(playlistImportProvider);
  yield svc.current(id);
  yield* svc.watch(id);
});

/// Progress, review and result of a playlist import (`/import/<sessionId>`).
class ImportReviewPage extends ConsumerStatefulWidget {
  const ImportReviewPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends ConsumerState<ImportReviewPage> {
  /// Decision filter (null = all).
  MatchDecision? _filter;
  bool _saving = false;

  Future<void> _save(ImportSessionState s) async {
    final l10n = context.l10n;
    final svc = ref.read(playlistImportProvider);
    final pending = s.count(MatchDecision.needsReview);
    if (pending > 0) {
      final ok = await ConfirmDialog.show(
        context,
        title: l10n.importSavePendingTitle,
        message: l10n.importSavePendingBody(pending),
        confirmLabel: l10n.importSaveAnyway,
      );
      if (!ok || !mounted) return;
    }
    final name = await TextInputDialog.show(
      context,
      title: l10n.importSaveTitle,
      initialValue: s.playlist?.name ?? l10n.importUntitled,
      confirmLabel: l10n.actionSave,
    );
    if (name == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final playlistId = await svc.save(widget.sessionId, playlistName: name);
      if (!mounted) return;
      final after = svc.current(widget.sessionId) ?? s;
      if (unmatchedResults(after).isNotEmpty) {
        await showDialog<void>(context: context, builder: (_) => MissingTracksDialog(state: after));
        if (!mounted) return;
      } else {
        showFermataToast(context, l10n.importSaved, icon: Icons.check_rounded);
      }
      context.go(AppRoutes.playlist(playlistId));
    } catch (_) {
      if (mounted) showFermataToast(context, l10n.importSaveFailed, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(importSessionProvider(widget.sessionId));
    final state = async.value;
    final Widget body;
    if (async.isLoading && state == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state == null) {
      body = EmptyState(
        icon: Icons.playlist_remove_rounded,
        title: l10n.importSessionMissing,
        message: l10n.importSessionMissingHint,
        actionLabel: l10n.importStartNew,
        onAction: () => context.go(AppRoutes.import),
      );
    } else {
      body = switch (state.phase) {
        ImportPhase.fetching || ImportPhase.matching || ImportPhase.saving => _ProgressView(state: state),
        ImportPhase.reviewing => _review(context, state),
        ImportPhase.done => _DoneView(state: state),
        ImportPhase.failed => ErrorState(
            title: l10n.importFailed,
            error: state.error ?? StateError('failed'),
            onRetry: () => context.go(AppRoutes.import),
          ),
        ImportPhase.canceled => EmptyState(
            icon: Icons.cancel_outlined,
            title: l10n.importCanceled,
            actionLabel: l10n.importStartNew,
            onAction: () => context.go(AppRoutes.import),
          ),
      };
    }
    return Scaffold(body: SafeArea(child: body));
  }

  Widget _review(BuildContext context, ImportSessionState s) {
    final l10n = context.l10n;
    final c = context.colors;
    final svc = ref.read(playlistImportProvider);
    final rows = _filter == null ? s.results : [for (final r in s.results) if (r.decision == _filter) r];
    const core = [MatchDecision.autoAccepted, MatchDecision.needsReview, MatchDecision.notFound, MatchDecision.skipped];
    final chips = [
      for (final d in MatchDecision.values)
        if (core.contains(d) || s.count(d) > 0) d,
    ];
    final highConfidence = s.results.where((r) {
      final best = r.best;
      return r.decision == MatchDecision.needsReview &&
          best != null &&
          best.confidence.index <= MatchConfidence.high.index &&
          !best.hasSignificantVersionDifference;
    }).length;

    return LayoutBuilder(builder: (context, constraints) {
      final pad = constraints.maxWidth < 600 ? 16.0 : 32.0;
      return CustomScrollView(key: const ValueKey('import.reviewList'), slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 8),
          sliver: SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(header: true, child: Text(l10n.importReviewTitle, style: context.type.headline)),
              const SizedBox(height: 4),
              Row(children: [
                Flexible(
                  child: Text(s.playlist?.name ?? l10n.importUntitled, style: context.type.titleSmall, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                SourceChip(sourceId: s.source, dense: true),
              ]),
              const SizedBox(height: 4),
              Text(l10n.importReviewHint, style: context.type.bodySmall),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(
                  key: const ValueKey('import.filter.all'),
                  label: Text(l10n.importFilterAll(s.results.length)),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final d in chips)
                  ChoiceChip(
                    key: ValueKey('import.filter.${d.name}'),
                    label: Text('${decisionLabel(l10n, d)} · ${s.count(d)}'),
                    selected: _filter == d,
                    onSelected: (_) => setState(() => _filter = _filter == d ? null : d),
                  ),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FermataButton(
                  key: const ValueKey('import.save'),
                  label: l10n.importSavePlaylist,
                  icon: Icons.save_alt_rounded,
                  busy: _saving,
                  onPressed: () => _save(s),
                ),
                FermataButton(
                  key: const ValueKey('import.acceptAll'),
                  label: l10n.importAcceptAllHigh(highConfidence),
                  icon: Icons.done_all_rounded,
                  variant: FermataButtonVariant.secondary,
                  onPressed: highConfidence == 0 ? null : () => svc.acceptAllAtLeast(widget.sessionId, MatchConfidence.high),
                ),
                FermataButton(
                  label: l10n.importCancelImport,
                  variant: FermataButtonVariant.ghost,
                  onPressed: () async {
                    final ok = await ConfirmDialog.show(
                      context,
                      title: l10n.importCancelTitle,
                      message: l10n.importCancelBody,
                      confirmLabel: l10n.importCancelImport,
                      destructive: true,
                    );
                    if (ok) svc.cancel(widget.sessionId);
                  },
                ),
              ]),
              const SizedBox(height: 16),
            ]),
          ),
        ),
        if (rows.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l10n.importFilterEmpty, textAlign: TextAlign.center, style: context.type.bodySmall.copyWith(color: c.textSecondary)),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
            sliver: SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) => ReviewRow(sessionId: widget.sessionId, result: rows[i]),
            ),
          ),
      ]);
    });
  }
}

class _ProgressView extends ConsumerWidget {
  const _ProgressView({required this.state});

  final ImportSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = state;
    final phase = switch (s.phase) {
      ImportPhase.fetching => l10n.importPhaseFetching,
      ImportPhase.saving => l10n.importPhaseSaving,
      _ => s.total > 0 ? l10n.importPhaseMatching(s.processed, s.total) : l10n.importPhaseMatchingStart,
    };
    final value = s.phase == ImportPhase.matching && s.total > 0 ? (s.processed / s.total).clamp(0.0, 1.0) : null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s.playlist?.name ?? l10n.importImporting, style: context.type.title, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Semantics(
              label: phase,
              child: LinearProgressIndicator(key: const ValueKey('import.progress'), value: value, minHeight: 4),
            ),
            const SizedBox(height: 12),
            Text(phase, key: const ValueKey('import.phase'), textAlign: TextAlign.center, style: context.type.bodySmall),
            if (s.phase == ImportPhase.matching) ...[
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
                Text('${decisionLabel(l10n, MatchDecision.autoAccepted)}: ${s.count(MatchDecision.autoAccepted)}', style: context.type.caption),
                Text('${decisionLabel(l10n, MatchDecision.needsReview)}: ${s.count(MatchDecision.needsReview)}', style: context.type.caption),
                Text('${decisionLabel(l10n, MatchDecision.notFound)}: ${s.count(MatchDecision.notFound)}', style: context.type.caption),
              ]),
            ],
            if (s.phase != ImportPhase.saving) ...[
              const SizedBox(height: 24),
              Center(
                child: FermataButton(
                  key: const ValueKey('import.cancel'),
                  label: l10n.importCancelImport,
                  variant: FermataButtonVariant.secondary,
                  onPressed: () => ref.read(playlistImportProvider).cancel(s.id),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.state});

  final ImportSessionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final missing = unmatchedResults(state).length;
    final id = state.savedPlaylistId;
    return EmptyState(
      icon: Icons.playlist_add_check_rounded,
      title: l10n.importDoneTitle,
      message: missing == 0 ? l10n.importDoneAll : l10n.importDoneMissing(missing),
      actionLabel: id == null ? null : l10n.importOpenPlaylist,
      onAction: id == null ? null : () => context.go(AppRoutes.playlist(id)),
      secondaryLabel: missing == 0 ? null : l10n.importShowMissing,
      onSecondary: () => showDialog<void>(context: context, builder: (_) => MissingTracksDialog(state: state)),
    );
  }
}

/// Copyable list of tracks without a match.
class MissingTracksDialog extends StatelessWidget {
  const MissingTracksDialog({super.key, required this.state});

  final ImportSessionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final report = missingTracksReport(l10n, state);
    return AlertDialog(
      title: Text(l10n.importMissingTitle(unmatchedResults(state).length)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 360),
        child: SingleChildScrollView(child: SelectableText(report, key: const ValueKey('import.report'), style: context.type.bodySmall)),
      ),
      actions: [
        FermataButton(
          key: const ValueKey('import.report.copy'),
          label: l10n.settingsCopy,
          icon: Icons.copy_rounded,
          variant: FermataButtonVariant.secondary,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: report));
            if (context.mounted) showFermataToast(context, l10n.settingsCopied, icon: Icons.check_rounded);
          },
        ),
        FermataButton(label: l10n.actionDone, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
