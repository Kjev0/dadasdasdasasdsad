import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../design/context_ext.dart';
import '../artwork/artwork_image.dart';

/// Card for albums, playlists, artists (circle) and shelves: artwork,
/// title, subtitle and a quick-play button revealed on hover/focus (always
/// visible on touch layouts when [onPlay] is set).
class MediaCard extends ConsumerStatefulWidget {
  const MediaCard({
    super.key,
    required this.title,
    this.subtitle,
    this.artworkUrl,
    this.circle = false,
    this.width = 168,
    this.onTap,
    this.onPlay,
    this.onSecondaryTap,
    this.badge,
    this.placeholderIcon,
  });

  final String title;
  final String? subtitle;
  final Uri? artworkUrl;

  /// Circular artwork (artists).
  final bool circle;
  final double width;
  final VoidCallback? onTap;

  /// Quick play; hidden when null.
  final VoidCallback? onPlay;

  /// Right-click / long-press (e.g. a context menu).
  final void Function(Offset globalPosition)? onSecondaryTap;

  /// Small widget over the artwork's top-left corner (e.g. a badge).
  final Widget? badge;

  /// Used instead of the artwork placeholder when no artwork exists.
  final IconData? placeholderIcon;

  @override
  ConsumerState<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends ConsumerState<MediaCard> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = context.radii;
    final visuals = ref.watch(effectiveVisualsProvider);
    final touch = MediaQuery.sizeOf(context).width < 600;
    final showPlay = widget.onPlay != null && (touch || _hover || _focus);
    final radius = widget.circle ? BorderRadius.circular(widget.width) : r.mdAll;
    // The card has 4 px inner padding on each side.
    final artSize = widget.width - 8;

    Widget art = widget.artworkUrl == null && widget.placeholderIcon != null
        ? Container(
            decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: radius),
            child: Icon(widget.placeholderIcon, size: artSize * 0.3, color: c.textTertiary),
          )
        : ArtworkImage(uri: widget.artworkUrl, circle: widget.circle, borderRadius: radius);

    art = SizedBox.square(
      dimension: artSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          art,
          if (widget.badge != null) Positioned(left: 8, top: 8, child: widget.badge!),
          if (widget.onPlay != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: AnimatedOpacity(
                opacity: showPlay ? 1 : 0,
                duration: visuals.duration(const Duration(milliseconds: 120)),
                child: IgnorePointer(
                  ignoring: !showPlay,
                  child: Material(
                    color: c.accent,
                    shape: const CircleBorder(),
                    elevation: 4,
                    shadowColor: c.shadow,
                    child: IconButton(
                      tooltip: context.l10n.playerPlay,
                      icon: Icon(Icons.play_arrow_rounded, color: c.onAccent),
                      onPressed: widget.onPlay,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Semantics(
          button: widget.onTap != null,
          label: [widget.title, ?widget.subtitle].join(', '),
          excludeSemantics: false,
          child: InkWell(
            onTap: widget.onTap,
            onFocusChange: (f) => setState(() => _focus = f),
            onLongPress: widget.onSecondaryTap == null
                ? null
                : () {
                    final box = context.findRenderObject() as RenderBox?;
                    widget.onSecondaryTap!(box?.localToGlobal(box.size.center(Offset.zero)) ?? Offset.zero);
                  },
            onSecondaryTapUp: widget.onSecondaryTap == null ? null : (d) => widget.onSecondaryTap!(d.globalPosition),
            borderRadius: r.mdAll,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: widget.circle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  art,
                  const SizedBox(height: 10),
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: widget.circle ? TextAlign.center : TextAlign.start,
                    style: context.type.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: widget.circle ? TextAlign.center : TextAlign.start,
                      style: context.type.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
