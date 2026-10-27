import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/library.dart';
import '../../../core/models/library.dart';
import '../../design/context_ext.dart';
import '../../design/fermata_tokens.dart';
import '../../widgets/artwork/artwork_image.dart';
import '../../widgets/controls/section_header.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/util/async_utils.dart';
import '../library/shared/labels.dart';
import '../library/shared/page_services.dart';
import '../library/shared/revisions.dart';

/// Days covered by the statistics.
const statsDays = 30;

/// Listening statistics for the last [statsDays] days.
final listeningStatsProvider = FutureProvider.autoDispose<ListeningStats>(
  (ref) async {
    watchLibrary(ref, LibraryTopic.history);
    final now = ref.watch(pageClockProvider)();
    final since = DateTime(now.year, now.month, now.day).subtract(const Duration(days: statsDays - 1));
    return ref.watch(historyRepositoryProvider).stats(since: since);
  },
  retry: noRetry,
);

/// Totals, top tracks / artists / genres and plays per day.
class ListeningStatsView extends ConsumerWidget {
  const ListeningStatsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final stats = ref.watch(listeningStatsProvider);
    final now = ref.watch(pageClockProvider)();
    return stats.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(listeningStatsProvider)),
      data: (s) {
        if (s.totalPlays == 0) {
          return EmptyState(icon: Icons.insights_rounded, title: l10n.historyStatsEmpty, compact: true);
        }
        Widget total(String label, String value) => Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: context.colors.surface, borderRadius: context.radii.mdAll),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: FermataTypography.tabular(context.type.title)),
                    const SizedBox(height: 4),
                    Text(label, style: context.type.bodySmall),
                  ],
                ),
              ),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.historyStatsPeriod(statsDays), style: context.type.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                total(l10n.historyStatsPlays, '${s.totalPlays}'),
                const SizedBox(width: 12),
                total(l10n.historyStatsTime, formatLongDuration(l10n, s.totalListened)),
              ],
            ),
            const SizedBox(height: 24),
            SectionHeader(title: l10n.historyStatsPerDay),
            PlaysPerDayChart(playsPerDay: s.playsPerDay, now: now, days: statsDays),
            if (s.topTracks.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionHeader(title: l10n.historyStatsTopTracks),
              for (final (t, n) in s.topTracks.take(10))
                ListTile(
                  key: ValueKey('top-track-${t.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox.square(dimension: 40, child: ArtworkImage(uri: t.artworkUrl, size: 40)),
                  title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(t.artistLine, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(l10n.historyPlays(n), style: context.type.bodySmall),
                ),
            ],
            if (s.topArtists.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionHeader(title: l10n.historyStatsTopArtists),
              _RankedBars(items: s.topArtists.take(8).toList()),
            ],
            if (s.topGenres.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionHeader(title: l10n.historyStatsTopGenres),
              _RankedBars(items: s.topGenres.take(8).toList()),
            ],
          ],
        );
      },
    );
  }
}

/// Horizontal ranked bars (name, count) for top artists / genres.
class _RankedBars extends StatelessWidget {
  const _RankedBars({required this.items});

  final List<(String, int)> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final top = items.map((e) => e.$2).fold(1, max);
    return Column(
      children: [
        for (final (name, n) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 140, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.body)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 8,
                        width: max(4.0, constraints.maxWidth * n / top),
                        decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(l10n.historyPlays(n), style: context.type.caption),
              ],
            ),
          ),
      ],
    );
  }
}

/// Plays per day as a small bar chart (CustomPaint; colours from tokens).
class PlaysPerDayChart extends StatelessWidget {
  const PlaysPerDayChart({super.key, required this.playsPerDay, required this.now, this.days = statsDays, this.height = 120});

  final Map<DateTime, int> playsPerDay;
  final DateTime now;
  final int days;
  final double height;

  /// Counts for the last [days] days, oldest first.
  List<int> get series {
    final today = DateTime(now.year, now.month, now.day);
    final byDay = <DateTime, int>{};
    playsPerDay.forEach((d, n) {
      final key = DateTime(d.year, d.month, d.day);
      byDay[key] = (byDay[key] ?? 0) + n;
    });
    return [
      for (var i = days - 1; i >= 0; i--) byDay[DateTime(today.year, today.month, today.day - i)] ?? 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final values = series;
    final peak = values.fold(0, max);
    final total = values.fold(0, (a, b) => a + b);
    return Semantics(
      label: context.l10n.historyChartLabel(days, total, peak),
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: PlaysChartPainter(values: values, bar: c.accent, empty: c.surfaceHigh, baseline: c.outline),
          ),
        ),
      ),
    );
  }
}

/// Paints one rounded bar per day; days without plays get a faint stub.
class PlaysChartPainter extends CustomPainter {
  const PlaysChartPainter({required this.values, required this.bar, required this.empty, required this.baseline});

  final List<int> values;
  final Color bar;
  final Color empty;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final peak = values.fold(1, max);
    final slot = size.width / values.length;
    final barWidth = max(2.0, slot * 0.6);
    final chartHeight = size.height - 2;
    final fill = Paint()..color = bar;
    final stub = Paint()..color = empty;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final h = v == 0 ? 2.0 : max(4.0, chartHeight * v / peak);
      final left = i * slot + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(left, chartHeight - h, barWidth, h), Radius.circular(min(3, barWidth / 2)));
      canvas.drawRRect(rect, v == 0 ? stub : fill);
    }
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), Paint()
      ..color = baseline
      ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(PlaysChartPainter old) =>
      old.bar != bar || old.empty != empty || old.baseline != baseline || !_same(old.values, values);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
