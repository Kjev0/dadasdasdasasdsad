import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/library.dart';
import '../../../core/models/library.dart';
import '../../../core/models/track.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../design/fermata_tokens.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/controls/segmented_tabs.dart';
import '../../widgets/dialogs/dialogs.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/feedback/skeleton.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/feedback/toast.dart';
import '../../widgets/tracks/track_tile.dart';
import '../../widgets/util/async_utils.dart';
import '../library/shared/labels.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/page_services.dart';
import '../library/shared/revisions.dart';
import '../library/shared/track_helpers.dart';
import 'history_stats.dart';

/// Records per page.
const historyPageSize = 200;

/// The most recent plays.
final historyProvider = FutureProvider.autoDispose<List<PlayRecord>>(
  (ref) async {
    watchLibrary(ref, LibraryTopic.history);
    return ref.watch(historyRepositoryProvider).history(limit: historyPageSize);
  },
  retry: noRetry,
);

/// Groups [records] (newest first) by local calendar day.
List<(DateTime, List<PlayRecord>)> groupByDay(List<PlayRecord> records) {
  final out = <(DateTime, List<PlayRecord>)>[];
  for (final r in records) {
    final t = r.playedAt.toLocal();
    final day = DateTime(t.year, t.month, t.day);
    if (out.isEmpty || out.last.$1 != day) out.add((day, []));
    out.last.$2.add(r);
  }
  return out;
}

enum _HistoryTab { recent, stats }

/// History: recently played grouped by day, clear history, listening
/// statistics, and a notice while history recording is turned off.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  _HistoryTab _tab = _HistoryTab.recent;
  final _older = <PlayRecord>[];
  bool _loadingMore = false;
  bool _exhausted = false;
  List<PlayRecord>? _base;

  Future<void> _clear() async {
    final l10n = context.l10n;
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.historyClearTitle,
      message: l10n.historyClearMessage,
      confirmLabel: l10n.historyClear,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(historyRepositoryProvider).clearHistory();
      _older.clear();
      ref.invalidate(historyProvider);
      ref.invalidate(listeningStatsProvider);
      if (mounted) showFermataToast(context, l10n.historyCleared, icon: Icons.delete_sweep_rounded);
    } catch (e) {
      if (mounted) showFermataToast(context, errorMessageFor(l10n, e) ?? l10n.errorGeneric, isError: true);
    }
  }

  Future<void> _loadMore(List<PlayRecord> current) async {
    if (current.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final more = await ref.read(historyRepositoryProvider).history(limit: historyPageSize, before: current.last.playedAt);
      if (!mounted) return;
      setState(() {
        _older.addAll(more);
        _exhausted = more.length < historyPageSize;
      });
    } catch (e) {
      if (mounted) showFermataToast(context, errorMessageFor(context.l10n, e) ?? context.l10n.errorGeneric, isError: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recording = ref.watch(settingsProvider.select((s) => s.privacy.recordHistory));
    final history = ref.watch(historyProvider);
    final insets = pageInsets(context);
    final hasHistory = (history.value ?? const []).isNotEmpty;

    final top = <Widget>[
      PageHeader(
        title: l10n.navHistory,
        padding: EdgeInsets.only(top: isCompactWidth(context) ? 16 : 24, bottom: 12),
        actions: [
          if (hasHistory)
            FermataButton(
              key: const ValueKey('history-clear'),
              label: l10n.historyClear,
              icon: Icons.delete_sweep_rounded,
              variant: FermataButtonVariant.secondary,
              onPressed: _clear,
            ),
        ],
      ),
      if (!recording) ...[
        InlineNotice(
          key: const ValueKey('history-off'),
          icon: Icons.history_toggle_off_rounded,
          warning: true,
          message: l10n.historyRecordingOff,
          actionLabel: l10n.pagesOpenSettings,
          onAction: () => context.go(AppRoutes.settingsSection(SettingsSections.privacy)),
        ),
        const SizedBox(height: 12),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedTabs<_HistoryTab>(
          selected: _tab,
          onChanged: (t) => setState(() => _tab = t),
          tabs: [
            SegmentedTab(_HistoryTab.recent, l10n.historyRecent, icon: Icons.history_rounded),
            SegmentedTab(_HistoryTab.stats, l10n.historyStats, icon: Icons.insights_rounded),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];

    final List<Widget> body;
    if (_tab == _HistoryTab.stats) {
      body = [const ListeningStatsView()];
    } else {
      body = history.when(
        loading: () => [const SkeletonTrackList()],
        error: (e, _) => [ErrorState(error: e, onRetry: () => ref.invalidate(historyProvider))],
        data: (records) {
          if (!identical(_base, records)) {
            // Fresh first page (new plays or a clear): drop older pages.
            _base = records;
            _older.clear();
            _exhausted = records.length < historyPageSize;
          }
          final all = [...records, ..._older];
          if (all.isEmpty) {
            return [
              EmptyState(
                icon: Icons.history_rounded,
                title: l10n.historyEmptyTitle,
                message: recording ? l10n.historyEmptyMessage : l10n.historyRecordingOff,
              ),
            ];
          }
          return _dayGroups(context, all);
        },
      );
    }

    return Scaffold(
      body: ListView(
        padding: insets.copyWith(bottom: 32),
        children: [
          ...top,
          ...body,
          if (_tab == _HistoryTab.recent && hasHistory && !_exhausted)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FermataButton(
                  label: l10n.pagesLoadMore,
                  variant: FermataButtonVariant.secondary,
                  busy: _loadingMore,
                  onPressed: () => _loadMore([...?history.value, ..._older]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _dayGroups(BuildContext context, List<PlayRecord> all) {
    final l10n = context.l10n;
    final now = ref.watch(pageClockProvider)();
    final out = <Widget>[];
    for (final (day, records) in groupByDay(all)) {
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
        child: Semantics(
          header: true,
          child: Text(dayLabel(context, l10n, day, now), key: ValueKey('day-${day.toIso8601String()}'), style: context.type.label),
        ),
      ));
      final tracks = <Track>[for (final r in records) r.track];
      for (var i = 0; i < records.length; i++) {
        final r = records[i];
        out.add(TrackTile(
          key: ValueKey('history-${r.id ?? '${r.track.id}-${r.playedAt.millisecondsSinceEpoch}'}'),
          track: r.track,
          playContext: siloSafeContext(tracks, i, origin: 'history', originLabel: l10n.navHistory),
          trailing: roomyRows(context)
              ? Text(
                  timeLabel(context, r.playedAt.toLocal()),
                  style: FermataTypography.tabular(context.type.caption),
                )
              : null,
        ));
      }
    }
    return out;
  }
}
