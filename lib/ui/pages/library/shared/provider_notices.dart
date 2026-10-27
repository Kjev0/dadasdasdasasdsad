import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/track.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/chips/badges.dart';
import 'track_helpers.dart';

/// Labels a track list that contains preview-only or external-only tracks
/// ("30-second preview · Deezer", "Plays on Spotify") so users know up front
/// what will play inside Fermata.
class TrackListNotices extends ConsumerWidget {
  const TrackListNotices({super.key, required this.tracks, this.padding = EdgeInsets.zero});

  final List<Track> tracks;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    final previews = <String, int>{};
    final external = <String>{};
    for (final t in tracks) {
      if (isPreviewTrack(t)) {
        previews.putIfAbsent(t.sourceId, () => t.availability.previewDuration?.inSeconds ?? 30);
      } else if (isExternalTrack(t)) {
        external.add(t.sourceId);
      }
    }
    if (previews.isEmpty && external.isEmpty) return const SizedBox.shrink();
    Widget pill(IconData icon, String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: context.radii.xsAll,
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(text, style: context.type.caption.copyWith(color: color), overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in previews.entries)
            pill(Icons.timelapse_rounded, l10n.playerPreviewFrom(e.value, sourceDisplayName(ref, e.key)), c.warning),
          for (final id in external)
            pill(Icons.open_in_new_rounded, l10n.shellBadgeExternal(sourceDisplayName(ref, id)), c.textSecondary),
        ],
      ),
    );
  }
}
