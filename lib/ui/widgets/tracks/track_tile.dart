import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/track.dart';
import '../../actions/track_actions.dart';
import '../../design/context_ext.dart';
import '../../design/fermata_tokens.dart';
import '../artwork/artwork_image.dart';
import '../chips/badges.dart';
import '../feedback/messages.dart';
import '../feedback/toast.dart';
import 'now_playing_glyph.dart';
import 'track_format.dart';
import 'track_menu.dart';

/// A track row: artwork (or index), title, artists, availability badges,
/// now-playing indicator, like button, duration and a context menu
/// (right-click / "more" button) or long-press sheet.
///
/// Tapping plays [playContext] from this track (or the track alone).
/// Unplayable tracks are dimmed and explain why on tap; external-only
/// tracks open on their provider.
class TrackTile extends ConsumerStatefulWidget {
  const TrackTile({
    super.key,
    required this.track,
    this.playContext,
    this.onTap,
    this.index,
    this.showArtwork = true,
    this.showAlbum = false,
    this.showSource = false,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectedChanged,
    this.onLongPress,
    this.trailing,
  });

  final Track track;
  final TrackPlayContext? playContext;

  /// Overrides the default "play" behaviour.
  final VoidCallback? onTap;

  /// 1-based number shown instead of artwork when [showArtwork] is false.
  final int? index;
  final bool showArtwork;
  final bool showAlbum;
  final bool showSource;

  /// In selection mode a tap toggles selection.
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  /// Overrides the default long-press (menu sheet), e.g. to enter selection.
  final VoidCallback? onLongPress;

  /// Extra trailing widget (e.g. a drag handle).
  final Widget? trailing;

  @override
  ConsumerState<TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends ConsumerState<TrackTile> {
  bool _hovered = false;
  final _moreKey = GlobalKey();

  Track get track => widget.track;

  void _openMenu({Offset? position}) =>
      showTrackMenu(context, ref, track, position: position, playContext: widget.playContext);

  void _openMenuFromButton() {
    final box = _moreKey.currentContext?.findRenderObject() as RenderBox?;
    final pos = box == null ? null : box.localToGlobal(Offset(0, box.size.height));
    _openMenu(position: pos ?? Offset.zero);
  }

  Future<void> _activate() async {
    if (widget.selectionMode) {
      widget.onSelectedChanged?.call(!widget.selected);
      return;
    }
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    final actions = TrackActions(context, ref);
    final a = track.availability;
    if (a.playback == PlaybackRights.externalOnly) {
      await actions.openExternally(track);
      return;
    }
    if (a.playback == PlaybackRights.unavailable) {
      showFermataToast(context, availabilityReasonText(context.l10n, a.reason), icon: Icons.block_rounded);
      return;
    }
    final pc = widget.playContext;
    if (pc != null) {
      await actions.play(pc.tracks, startIndex: pc.index, origin: pc.origin, originLabel: pc.originLabel);
    } else {
      await actions.play([track]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final type = context.type;
    final isCurrent = ref.watch(currentSnapshotProvider.select((s) => s.track?.id == track.id));
    final playing = isCurrent && ref.watch(currentSnapshotProvider.select((s) => s.playing));
    final animate = ref.watch(effectiveVisualsProvider.select((v) => v.animate));
    final liked = ref.watch(favoriteIdsProvider.select((v) => v.value?.contains(track.id) ?? false));
    final downloaded = ref.watch(downloadedIdsProvider.select((v) => v.value?.contains(track.id) ?? false));
    final unavailable = track.availability.playback == PlaybackRights.unavailable;
    final badgeKind = AvailabilityBadge.primaryKind(track, downloaded: downloaded);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final touch = width < 600;
    final rowHeight = context.spacing.rowHeight;

    Widget leading;
    if (widget.selectionMode) {
      leading = Checkbox(value: widget.selected, onChanged: (v) => widget.onSelectedChanged?.call(v ?? false));
    } else if (widget.showArtwork) {
      leading = SizedBox.square(
        dimension: 40,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ArtworkImage(uri: track.artworkUrl, size: 40),
            if (isCurrent)
              DecoratedBox(
                decoration: BoxDecoration(color: c.bg.withValues(alpha: 0.55), borderRadius: context.radii.smAll),
                child: Center(child: NowPlayingGlyph(animate: playing && animate)),
              ),
          ],
        ),
      );
    } else {
      leading = SizedBox(
        width: 32,
        child: Center(
          child: isCurrent
              ? NowPlayingGlyph(animate: playing && animate)
              : Text(
                  widget.index?.toString() ?? '',
                  style: FermataTypography.tabular(type.bodySmall.copyWith(color: c.textTertiary)),
                ),
        ),
      );
    }

    final titleStyle = type.body.copyWith(
      color: isCurrent ? c.accentText : c.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final subtitle = Row(
      children: [
        if (track.explicit == true) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: c.textTertiary, borderRadius: BorderRadius.circular(3)),
            child: Text('E', semanticsLabel: l10n.shellBadgeExplicit, style: type.caption.copyWith(color: c.bg, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
        ],
        if (AvailabilityBadge.isNotable(badgeKind)) ...[
          AvailabilityBadge(kind: badgeKind, sourceId: track.sourceId, reason: track.availability.reason, dense: true),
          const SizedBox(width: 6),
        ],
        if (widget.showSource) ...[
          SourceChip(sourceId: track.sourceId, dense: true),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(track.artistLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: type.bodySmall),
        ),
      ],
    );

    final showLike = !touch && (liked || _hovered || isCurrent);
    final row = Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
              const SizedBox(height: 2),
              subtitle,
            ],
          ),
        ),
        if (widget.showAlbum && wide) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(track.album ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: type.bodySmall),
          ),
        ],
        if (!touch)
          SizedBox(
            width: 40,
            child: showLike
                ? IconButton(
                    tooltip: liked ? l10n.shellMenuUnlike : l10n.shellMenuLike,
                    isSelected: liked,
                    icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 20),
                    onPressed: () => TrackActions(context, ref).setFavorite(track, !liked),
                  )
                : null,
          ),
        if (track.duration != null)
          SizedBox(
            width: 48,
            child: Text(
              formatDuration(track.duration!),
              textAlign: TextAlign.right,
              style: FermataTypography.tabular(type.bodySmall.copyWith(color: c.textTertiary)),
            ),
          ),
        if (widget.trailing != null) widget.trailing!,
        IconButton(
          key: _moreKey,
          tooltip: l10n.shellMoreOptions,
          icon: const Icon(Icons.more_horiz_rounded, size: 20),
          onPressed: _openMenuFromButton,
        ),
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Opacity(
        opacity: unavailable ? 0.5 : 1,
        child: Semantics(
          button: true,
          selected: widget.selectionMode ? widget.selected : isCurrent,
          label: '${track.title}, ${track.artistLine}',
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: context.radii.smAll,
              onTap: _activate,
              onLongPress: widget.onLongPress ?? () => _openMenu(),
              onSecondaryTapUp: (d) => _openMenu(position: d.globalPosition),
              child: Container(
                height: rowHeight,
                padding: const EdgeInsets.only(left: 8, right: 4),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? c.accent.withValues(alpha: 0.12)
                      : isCurrent
                          ? c.textPrimary.withValues(alpha: 0.04)
                          : null,
                  borderRadius: context.radii.smAll,
                ),
                child: row,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
