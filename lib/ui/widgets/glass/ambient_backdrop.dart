import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../design/context_ext.dart';
import '../artwork/artwork_image.dart';
import '../artwork/artwork_palette.dart';
import 'glass_spec.dart';

/// The ambient layer the shell paints behind glass surfaces so the glass
/// has something to refract:
/// * blur allowed → heavily blurred artwork (or an accent tint without
///   artwork) under a background-coloured scrim,
/// * blur off → a cheap gradient from the artwork's palette,
/// * glass off → plain background.
///
/// The scrim strength ([GlassSpec.scrimAlpha]) is what guarantees text
/// contrast on glass (see `glass_spec.dart`).
class AmbientBackdrop extends ConsumerWidget {
  const AmbientBackdrop({super.key, this.artworkUrl, this.mode, this.forceArtwork = false});

  final Uri? artworkUrl;

  /// Overrides the mode derived from settings.
  final GlassMode? mode;

  /// Paint the artwork backdrop even when glass is off (now-playing view).
  final bool forceArtwork;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visuals = ref.watch(effectiveVisualsProvider);
    final c = context.colors;
    var resolved = mode ?? GlassMode.of(visuals);
    if (forceArtwork && resolved == GlassMode.solid) {
      resolved = visuals.blur ? GlassMode.blurred : GlassMode.translucent;
    }
    final scrim = c.bg.withValues(alpha: GlassSpec.scrimAlpha(c));

    Widget layer;
    if (resolved == GlassMode.solid) {
      layer = ColoredBox(key: const ValueKey('solid'), color: c.bg);
    } else if (resolved == GlassMode.blurred && artworkUrl != null) {
      layer = Stack(
        key: ValueKey('blur:$artworkUrl'),
        fit: StackFit.expand,
        children: [
          ColoredBox(color: c.bg),
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.decal),
            child: Transform.scale(
              scale: 1.3,
              child: ArtworkImage(uri: artworkUrl, borderRadius: BorderRadius.zero, size: null),
            ),
          ),
          ColoredBox(color: scrim),
        ],
      );
    } else {
      final palette = artworkUrl == null ? null : ref.watch(artworkPaletteProvider(artworkUrl!)).value;
      final colors = palette == null
          ? [Color.alphaBlend(c.accent.withValues(alpha: 0.10), c.bg), c.bg, c.bg]
          : [palette.vibrant, palette.dominant, c.bg];
      layer = Stack(
        key: ValueKey('gradient:${palette?.dominant}:${c.accent}'),
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          if (palette != null) ColoredBox(color: scrim),
        ],
      );
    }

    return ExcludeSemantics(
      child: AnimatedSwitcher(
        duration: visuals.duration(const Duration(milliseconds: 360)),
        layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
        child: layer,
      ),
    );
  }
}
