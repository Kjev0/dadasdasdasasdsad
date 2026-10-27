import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/contracts/discovery.dart';
import '../../core/models/track.dart';
import '../design/context_ext.dart';
import '../widgets/feedback/states.dart';
import 'player_providers.dart';

/// Index of the line active at [position]: the last line whose time is
/// ≤ position, or -1 before the first line. [lines] must be time-ordered.
int activeLyricIndex(List<LyricsLine> lines, Duration position) {
  var lo = 0, hi = lines.length - 1, result = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (lines[mid].time <= position) {
      result = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return result;
}

/// Lyrics for [track]: synced lyrics auto-scroll and highlight the current
/// line (tap a line to seek there); plain lyrics are shown as text. Always
/// attributes the provider ("Lyrics: LRCLIB").
class LyricsView extends ConsumerWidget {
  const LyricsView({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = ref.watch(settingsProvider.select((s) => s.playback.lyricsEnabled));
    if (!enabled) {
      return EmptyState(icon: Icons.lyrics_outlined, title: l10n.playerLyricsDisabled, compact: true);
    }
    final lyrics = ref.watch(lyricsProvider(track));
    return lyrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        error: e,
        title: l10n.playerLyricsError,
        compact: true,
        onRetry: () => ref.invalidate(lyricsProvider(track)),
      ),
      data: (data) {
        if (data == null) return EmptyState(icon: Icons.lyrics_outlined, title: l10n.playerLyricsNotFound, compact: true);
        if (data.instrumental) return EmptyState(icon: Icons.music_note_rounded, title: l10n.playerLyricsInstrumental, compact: true);
        return Column(
          children: [
            Expanded(
              child: data.hasSynced
                  ? SyncedLyrics(lines: data.synced)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                      child: Text(data.plain ?? '', style: context.type.body.copyWith(height: 1.7)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.playerLyricsAttribution(data.provider), style: context.type.caption),
            ),
          ],
        );
      },
    );
  }
}

/// Time-synced lyric lines following the playback position.
class SyncedLyrics extends ConsumerStatefulWidget {
  const SyncedLyrics({super.key, required this.lines});

  final List<LyricsLine> lines;

  @override
  ConsumerState<SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends ConsumerState<SyncedLyrics> {
  final _keys = <int, GlobalKey>{};
  int _lastScrolled = -2;

  GlobalKey _keyFor(int i) => _keys.putIfAbsent(i, GlobalKey.new);

  void _scrollTo(int index) {
    if (index == _lastScrolled) return;
    _lastScrolled = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keyFor(index < 0 ? 0 : index).currentContext;
      if (ctx == null || !mounted) return;
      final duration = ref.read(effectiveVisualsProvider).duration(const Duration(milliseconds: 360));
      Scrollable.ensureVisible(ctx, alignment: 0.4, duration: duration, curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(currentSnapshotProvider.select((s) => s.position));
    final active = activeLyricIndex(widget.lines, position);
    _scrollTo(active);
    final duration = ref.watch(effectiveVisualsProvider).duration(const Duration(milliseconds: 220));
    // Lyrics are short: build every line so any line can be scrolled to.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < widget.lines.length; i++) _line(context, i, active, duration),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, int i, int active, Duration duration) {
    final c = context.colors;
    final l10n = context.l10n;
    final line = widget.lines[i];
    final isActive = i == active;
    return KeyedSubtree(
      key: _keyFor(i),
      child: Semantics(
        selected: isActive,
        button: true,
        hint: l10n.playerLyricsSeekTo,
        child: InkWell(
          key: ValueKey('lyric-$i'),
          borderRadius: context.radii.smAll,
          onTap: () => ref.read(playbackProvider).seek(line.time),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: AnimatedDefaultTextStyle(
              duration: duration,
              style: context.type.title.copyWith(
                color: isActive ? c.textPrimary : (i < active ? c.textTertiary : c.textSecondary),
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
              child: Text(line.text.isEmpty ? '·' : line.text),
            ),
          ),
        ),
      ),
    );
  }
}
