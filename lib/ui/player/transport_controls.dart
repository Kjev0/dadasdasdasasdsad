import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/playback.dart';
import '../design/context_ext.dart';

/// Play/pause button. Shows a spinner ring while loading/buffering.
class PlayPauseButton extends ConsumerWidget {
  const PlayPauseButton({super.key, this.size = 40, this.filled = true});

  final double size;

  /// Filled circle (primary transport) vs. plain icon (mini-player).
  final bool filled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = context.l10n;
    final snap = ref.watch(currentSnapshotProvider);
    final hasTrack = snap.current != null;
    final playing = snap.playing;
    final loading = playing && (snap.status == PlayerStatus.loading || snap.status == PlayerStatus.buffering);
    final icon = Icon(
      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: size * 0.6,
      color: filled ? c.bg : null,
    );
    final button = filled
        ? Material(
            color: hasTrack ? c.textPrimary : c.textTertiary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: hasTrack ? () => ref.read(playbackProvider).togglePlayPause() : null,
              child: SizedBox.square(dimension: size, child: Center(child: icon)),
            ),
          )
        : IconButton(
            iconSize: size * 0.6,
            onPressed: hasTrack ? () => ref.read(playbackProvider).togglePlayPause() : null,
            icon: icon,
          );
    return Tooltip(
      message: playing ? l10n.playerPause : l10n.playerPlay,
      child: Semantics(
        button: true,
        label: playing ? l10n.playerPause : l10n.playerPlay,
        excludeSemantics: true,
        enabled: hasTrack,
        onTap: hasTrack ? () => ref.read(playbackProvider).togglePlayPause() : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            button,
            if (loading)
              IgnorePointer(
                child: SizedBox.square(
                  dimension: size + 6,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PreviousButton extends ConsumerWidget {
  const PreviousButton({super.key, this.iconSize = 26});

  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(currentSnapshotProvider.select((s) => s.current != null));
    return IconButton(
      tooltip: context.l10n.playerPrevious,
      iconSize: iconSize,
      icon: const Icon(Icons.skip_previous_rounded),
      onPressed: hasTrack ? () => ref.read(playbackProvider).previous() : null,
    );
  }
}

class NextButton extends ConsumerWidget {
  const NextButton({super.key, this.iconSize = 26});

  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(currentSnapshotProvider.select((s) => s.current != null));
    return IconButton(
      tooltip: context.l10n.playerNext,
      iconSize: iconSize,
      icon: const Icon(Icons.skip_next_rounded),
      onPressed: hasTrack ? () => ref.read(playbackProvider).next() : null,
    );
  }
}

class ShuffleButton extends ConsumerWidget {
  const ShuffleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shuffle = ref.watch(currentSnapshotProvider.select((s) => s.shuffle));
    final l10n = context.l10n;
    return IconButton(
      tooltip: shuffle ? l10n.playerShuffleOn : l10n.playerShuffleOff,
      isSelected: shuffle,
      icon: const Icon(Icons.shuffle_rounded),
      selectedIcon: const Icon(Icons.shuffle_on_rounded),
      onPressed: () => ref.read(playbackProvider).setShuffle(!shuffle),
    );
  }
}

/// Cycles off → all → one.
class RepeatButton extends ConsumerWidget {
  const RepeatButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repeat = ref.watch(currentSnapshotProvider.select((s) => s.repeat));
    final l10n = context.l10n;
    final (IconData icon, String tip) = switch (repeat) {
      RepeatMode.off => (Icons.repeat_rounded, l10n.playerRepeatOff),
      RepeatMode.all => (Icons.repeat_on_rounded, l10n.playerRepeatAll),
      RepeatMode.one => (Icons.repeat_one_on_rounded, l10n.playerRepeatOne),
    };
    return IconButton(
      tooltip: tip,
      isSelected: repeat != RepeatMode.off,
      icon: Icon(icon),
      onPressed: () => ref.read(playbackProvider).cycleRepeat(),
    );
  }
}

/// Shuffle · previous · play/pause · next · repeat.
class TransportControls extends StatelessWidget {
  const TransportControls({super.key, this.playSize = 40, this.showShuffleRepeat = true});

  final double playSize;
  final bool showShuffleRepeat;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showShuffleRepeat) const ShuffleButton(),
        const PreviousButton(),
        const SizedBox(width: 6),
        PlayPauseButton(size: playSize),
        const SizedBox(width: 6),
        const NextButton(),
        if (showShuffleRepeat) const RepeatButton(),
      ],
    );
  }
}
