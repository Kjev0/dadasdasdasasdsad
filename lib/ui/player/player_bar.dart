import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../actions/routes.dart';
import '../actions/track_actions.dart';
import '../design/context_ext.dart';
import '../widgets/artwork/artwork_image.dart';
import '../shell/shell_location.dart';
import '../widgets/glass/glass_surface.dart';
import 'mini_mode.dart';
import 'player_menus.dart';
import 'seek_bar.dart';
import 'transport_controls.dart';
import 'volume_control.dart';

/// Desktop/tablet bottom player bar (88 px): now-playing info + like,
/// transport + seek, and a right cluster (lyrics, queue, output device,
/// volume, speed, sleep timer, mini player). Narrower bars collapse the
/// right cluster into fewer controls so nothing overflows.
class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key});

  static const height = 88.0;

  /// Largest text scale used inside the fixed-height bar.
  static const maxTextScale = 1.2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fixed-height chrome: text scaling is clamped here (pages scale fully).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: SizedBox(
        height: height,
        child: GlassSurface(
          edges: GlassEdges.topOnly,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final full = w >= 1100;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: const _NowPlayingInfo()),
                    Expanded(flex: 4, child: const _CenterControls()),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: full ? const _RightClusterFull() : const _RightClusterCompact(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NowPlayingInfo extends ConsumerWidget {
  const _NowPlayingInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = context.l10n;
    final track = ref.watch(currentSnapshotProvider.select((s) => s.track));
    final liked = track != null && ref.watch(favoriteIdsProvider.select((v) => v.value?.contains(track.id) ?? false));
    if (track == null) {
      return Row(
        children: [
          const ArtworkImage(uri: null, size: 56),
          const SizedBox(width: 12),
          Flexible(
            child: Text(l10n.playerNothingPlaying, style: context.type.bodySmall, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
    }
    final artistRoute = AppRoutes.artistForTrack(track);
    return Row(
      children: [
        Semantics(
          button: true,
          label: l10n.playerOpenNowPlaying,
          child: InkWell(
            borderRadius: context.radii.smAll,
            onTap: () => context.push(AppRoutes.nowPlaying),
            child: ArtworkImage(uri: track.artworkUrl, size: 56),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => context.push(AppRoutes.nowPlaying),
                child: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: artistRoute == null ? null : () => context.go(artistRoute),
                child: Text(
                  track.artistLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.bodySmall.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: liked ? l10n.playerUnlike : l10n.playerLike,
          isSelected: liked,
          icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 20),
          onPressed: () => TrackActions(context, ref).setFavorite(track, !liked),
        ),
      ],
    );
  }
}

class _CenterControls extends ConsumerWidget {
  const _CenterControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(currentSnapshotProvider.select((s) => s.position));
    final duration = ref.watch(currentSnapshotProvider.select((s) => s.duration));
    final buffered = ref.watch(currentSnapshotProvider.select((s) => s.bufferedPosition));
    final hasTrack = ref.watch(currentSnapshotProvider.select((s) => s.current != null));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const FittedBox(fit: BoxFit.scaleDown, child: TransportControls(playSize: 38)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SeekBar(
            position: position,
            duration: duration,
            buffered: buffered,
            onSeek: hasTrack ? (d) => ref.read(playbackProvider).seek(d) : null,
          ),
        ),
      ],
    );
  }
}

class _LyricsButton extends ConsumerWidget {
  const _LyricsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTrack = ref.watch(currentSnapshotProvider.select((s) => s.current != null));
    return IconButton(
      tooltip: context.l10n.playerLyrics,
      icon: const Icon(Icons.lyrics_rounded),
      onPressed: hasTrack ? () => context.push(AppRoutes.nowPlayingView('lyrics')) : null,
    );
  }
}

class _QueueButton extends StatelessWidget {
  const _QueueButton();

  @override
  Widget build(BuildContext context) {
    final selected = ShellLocation.of(context)?.path == AppRoutes.queue;
    return IconButton(
      tooltip: context.l10n.playerQueue,
      isSelected: selected,
      icon: const Icon(Icons.queue_music_rounded),
      onPressed: () => selected ? context.go(AppRoutes.home) : context.go(AppRoutes.queue),
    );
  }
}

class _RightClusterFull extends StatelessWidget {
  const _RightClusterFull();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LyricsButton(),
        _QueueButton(),
        OutputDeviceButton(),
        VolumeControl(sliderWidth: 100),
        SpeedButton(),
        SleepTimerButton(),
        MiniModeButton(),
      ],
    );
  }
}

class _RightClusterCompact extends StatelessWidget {
  const _RightClusterCompact();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [_LyricsButton(), _QueueButton(), VolumePopoverButton(), SleepTimerButton(), _MoreButton()],
    );
  }
}

enum _More { outputDevice, speed, mini }

/// Overflow for the compact cluster: output device, speed, mini player.
class _MoreButton extends ConsumerWidget {
  const _MoreButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final mini = ref.watch(miniWindowControllerProvider) != null;
    final l10n = context.l10n;
    final items = [
      if (playback.supportsOutputDeviceSelection) (_More.outputDevice, l10n.playerOutputDevice, Icons.speaker_rounded),
      if (playback.supportsSpeed) (_More.speed, l10n.playerSpeed, Icons.speed_rounded),
      if (mini) (_More.mini, l10n.playerMiniPlayer, Icons.picture_in_picture_alt_rounded),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Builder(
      builder: (anchor) => PopupMenuButton<_More>(
        tooltip: l10n.playerMore,
        icon: const Icon(Icons.more_horiz_rounded),
        itemBuilder: (_) => [
          for (final (value, label, icon) in items)
            PopupMenuItem(
              value: value,
              child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)]),
            ),
        ],
        onSelected: (v) async {
          switch (v) {
            case _More.outputDevice:
              await OutputDeviceButton.open(anchor, ref);
            case _More.speed:
              await SpeedButton.open(anchor, ref);
            case _More.mini:
              await ref.read(miniModeProvider.notifier).enter();
          }
        },
      ),
    );
  }
}
