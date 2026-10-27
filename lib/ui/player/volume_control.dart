import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../design/context_ext.dart';

/// Remembers the volume before muting so unmute restores it.
class _LastVolume extends Notifier<double> {
  @override
  double build() => 0.7;

  void remember(double v) {
    if (v > 0.01) state = v;
  }
}

final _lastVolumeProvider = NotifierProvider<_LastVolume, double>(_LastVolume.new);

IconData volumeIcon(double v) => v <= 0.001
    ? Icons.volume_off_rounded
    : v < 0.5
        ? Icons.volume_down_rounded
        : Icons.volume_up_rounded;

/// Mute toggle.
class MuteButton extends ConsumerWidget {
  const MuteButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(currentSnapshotProvider.select((s) => s.volume));
    final muted = volume <= 0.001;
    final l10n = context.l10n;
    return IconButton(
      tooltip: muted ? l10n.playerUnmute : l10n.playerMute,
      icon: Icon(volumeIcon(volume)),
      onPressed: () {
        final playback = ref.read(playbackProvider);
        if (muted) {
          playback.setVolume(ref.read(_lastVolumeProvider));
        } else {
          ref.read(_lastVolumeProvider.notifier).remember(volume);
          playback.setVolume(0);
        }
      },
    );
  }
}

/// Mute button + volume slider.
class VolumeControl extends ConsumerWidget {
  const VolumeControl({super.key, this.sliderWidth = 110});

  final double sliderWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(currentSnapshotProvider.select((s) => s.volume));
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MuteButton(),
        SizedBox(
          width: sliderWidth,
          child: Slider(
            value: volume.clamp(0.0, 1.0),
            semanticFormatterCallback: (v) => '${(v * 100).round()} %',
            label: l10n.playerVolume,
            onChanged: (v) {
              ref.read(_lastVolumeProvider.notifier).remember(v);
              ref.read(playbackProvider).setVolume(v);
            },
          ),
        ),
      ],
    );
  }
}

/// Compact volume button that opens a popover slider (medium layouts).
class VolumePopoverButton extends ConsumerWidget {
  const VolumePopoverButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(currentSnapshotProvider.select((s) => s.volume));
    return MenuAnchor(
      alignmentOffset: const Offset(-60, 0),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Consumer(builder: (context, ref, _) => const VolumeControl(sliderWidth: 140)),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: context.l10n.playerVolume,
        icon: Icon(volumeIcon(volume)),
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
