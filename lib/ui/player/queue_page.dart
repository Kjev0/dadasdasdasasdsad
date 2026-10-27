import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/playback.dart';
import '../design/context_ext.dart';
import '../design/fermata_tokens.dart';
import '../widgets/artwork/artwork_image.dart';
import '../widgets/dialogs/dialogs.dart';
import '../widgets/feedback/states.dart';
import '../widgets/feedback/toast.dart';
import '../widgets/tracks/now_playing_glyph.dart';
import '../widgets/tracks/track_format.dart';
import 'playing_from.dart';

/// Origin marking tracks appended by the smart queue.
const smartQueueOrigin = 'smart-queue';

/// Full queue page (`/queue`).
class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: QueueList(showTitle: true)),
    );
  }
}

/// Now playing + up next (drag to reorder → `moveQueueItem`, swipe or menu
/// to remove, "play next"), clear queue, and the previously played items.
/// Used by [QueuePage] and the now-playing queue panel.
class QueueList extends ConsumerWidget {
  const QueueList({super.key, this.showTitle = false, this.padding = const EdgeInsets.symmetric(horizontal: 16)});

  final bool showTitle;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final queue = ref.watch(queueStateProvider).value ?? ref.watch(playbackProvider).queue;
    final playing = ref.watch(currentSnapshotProvider.select((s) => s.playing));
    final animate = ref.watch(effectiveVisualsProvider.select((v) => v.animate));
    final playback = ref.read(playbackProvider);

    final title = showTitle
        ? Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Semantics(header: true, child: Text(l10n.navQueue, style: context.type.headline)),
                if (queue.upNext.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _confirmClear(context, ref),
                    icon: const Icon(Icons.clear_all_rounded),
                    label: Text(l10n.playerQueueClear),
                  ),
              ],
            ),
          )
        : null;

    if (queue.isEmpty) {
      return Padding(
        padding: padding,
        child: Column(
          children: [
            ?title,
            Expanded(
              child: EmptyState(
                icon: Icons.queue_music_rounded,
                title: l10n.playerQueueEmpty,
                message: l10n.playerQueueEmptyHint,
              ),
            ),
          ],
        ),
      );
    }

    final current = queue.current;
    final upNext = queue.upNext;
    final previous = queue.previous;
    final base = queue.currentIndex < 0 ? 0 : queue.currentIndex + 1;
    final origin = playingFromLabel(context, queue);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?title,
        if (current != null) ...[
          _SectionLabel(l10n.playerQueueNowPlaying, trailing: origin == null ? null : l10n.playerPlayingFrom(origin)),
          QueueRow(
            item: current,
            leading: NowPlayingGlyph(animate: playing && animate),
            highlighted: true,
            onTap: () => playback.togglePlayPause(),
          ),
          const SizedBox(height: 16),
        ],
        _SectionLabel(
          l10n.playerQueueUpNext,
          trailing: l10n.playerQueueCount(upNext.length),
          action: !showTitle && upNext.isNotEmpty
              ? TextButton(onPressed: () => _confirmClear(context, ref), child: Text(l10n.playerQueueClear))
              : null,
        ),
      ],
    );

    final footer = previous.isEmpty
        ? const SizedBox(height: 24)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _SectionLabel(l10n.playerQueueHistory),
              for (var i = previous.length - 1; i >= 0; i--)
                Opacity(
                  opacity: 0.7,
                  child: QueueRow(
                    key: ValueKey('history-${previous[i].uid}'),
                    item: previous[i],
                    onTap: () => playback.skipToIndex(i),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          );

    return ReorderableListView.builder(
      padding: padding,
      header: header,
      footer: footer,
      buildDefaultDragHandles: false,
      itemCount: upNext.length,
      onReorderItem: (oldIndex, newIndex) {
        if (oldIndex == newIndex) return;
        playback.moveQueueItem(base + oldIndex, base + newIndex);
      },
      itemBuilder: (context, i) {
        final item = upNext[i];
        final absolute = base + i;
        return Dismissible(
          key: ValueKey('queue-${item.uid}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: context.colors.danger.withValues(alpha: 0.18),
            child: Icon(Icons.delete_outline_rounded, color: context.colors.danger),
          ),
          onDismissed: (_) {
            playback.removeFromQueue(item.uid);
            showFermataToast(context, l10n.playerQueueRemoved, icon: Icons.remove_circle_outline_rounded);
          },
          child: ReorderableDelayedDragStartListener(
            index: i,
            child: QueueRow(
              item: item,
              onTap: () => playback.skipToIndex(absolute),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    tooltip: l10n.shellMoreOptions,
                    icon: const Icon(Icons.more_horiz_rounded, size: 20),
                    onSelected: (v) {
                      if (v == 'next') {
                        if (absolute != base) playback.moveQueueItem(absolute, base);
                      } else {
                        playback.removeFromQueue(item.uid);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'next', child: Text(l10n.playerQueuePlayNext)),
                      PopupMenuItem(value: 'remove', child: Text(l10n.playerQueueRemove)),
                    ],
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: Tooltip(
                      message: l10n.playerQueueReorder,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.playerQueueClearTitle,
      message: l10n.playerQueueClearMessage,
      confirmLabel: l10n.playerQueueClear,
      destructive: true,
    );
    if (ok) await ref.read(playbackProvider).clearQueue(keepCurrent: true);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.trailing, this.action});

  final String label;
  final String? trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              header: true,
              child: Text(label, style: context.type.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 12),
          if (trailing != null)
            Expanded(child: Text(trailing!, style: context.type.caption, maxLines: 1, overflow: TextOverflow.ellipsis))
          else
            const Spacer(),
          if (action != null) Flexible(child: action!),
        ],
      ),
    );
  }
}

/// One queue entry (artwork, title, artist, "Suggested" label for
/// smart-queue items, duration).
class QueueRow extends StatelessWidget {
  const QueueRow({super.key, required this.item, this.onTap, this.trailing, this.leading, this.highlighted = false});

  final QueueItem item;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? leading;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = item.track;
    final suggested = item.origin == smartQueueOrigin;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: context.radii.smAll,
        onTap: onTap,
        child: SizedBox(
          height: context.rowExtent,
          child: Row(
            children: [
              const SizedBox(width: 4),
              SizedBox.square(
                dimension: 40,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ArtworkImage(uri: t.artworkUrl, size: 40),
                    if (leading != null)
                      DecoratedBox(
                        decoration: BoxDecoration(color: c.bg.withValues(alpha: 0.55), borderRadius: context.radii.smAll),
                        child: Center(child: leading),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: highlighted ? c.accentText : c.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        if (suggested) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              borderRadius: context.radii.xsAll,
                              border: Border.all(color: c.accentText.withValues(alpha: 0.5)),
                            ),
                            child: Text(context.l10n.playerQueueSuggested, style: context.type.caption.copyWith(color: c.accentText, fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(child: Text(t.artistLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.bodySmall)),
                      ],
                    ),
                  ],
                ),
              ),
              if (t.duration != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(formatDuration(t.duration!), style: FermataTypography.tabular(context.type.bodySmall.copyWith(color: c.textTertiary))),
                ),
              ?trailing,
              if (trailing == null) const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
