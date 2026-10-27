import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../actions/routes.dart';
import '../design/context_ext.dart';
import '../widgets/artwork/artwork_image.dart';
import '../widgets/glass/glass_surface.dart';
import 'transport_controls.dart';

/// Mobile mini-player docked above the bottom navigation: artwork,
/// title/artist, play/pause and a progress hairline. Tap or drag up opens
/// the full-screen now-playing view. Renders nothing when idle.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  static const height = 64.0;

  void _open(BuildContext context) => context.push(AppRoutes.nowPlaying);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = context.l10n;
    final track = ref.watch(currentSnapshotProvider.select((s) => s.track));
    if (track == null) return const SizedBox.shrink();
    final progress = ref.watch(
      currentSnapshotProvider.select((s) {
        final total = s.duration?.inMilliseconds ?? 0;
        return total <= 0 ? 0.0 : (s.position.inMilliseconds / total).clamp(0.0, 1.0);
      }),
    );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
        child: GlassSurface(
          borderRadius: context.radii.mdAll,
          floating: true,
          child: Semantics(
            button: true,
            label: '${l10n.playerOpenNowPlaying}: ${track.title}, ${track.artistLine}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _open(context),
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < -200) _open(context);
              },
              child: SizedBox(
                height: height,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                      child: Row(
                        children: [
                          ArtworkImage(uri: track.artworkUrl, size: 46),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.type.body.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  track.artistLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.type.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const PlayPauseButton(size: 44, filled: false),
                          const NextButton(iconSize: 24),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 2,
                          color: c.accent,
                          backgroundColor: c.outline.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
