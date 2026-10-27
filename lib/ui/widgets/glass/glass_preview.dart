import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../design/context_ext.dart';
import '../../design/fermata_tokens.dart';
import '../brand/fermata_mark.dart';
import 'ambient_backdrop.dart';
import 'glass_spec.dart';
import 'glass_surface.dart';

/// A miniature mock of the sidebar + player bar rendered with the current
/// (or overridden) glass settings. Embedded by Settings → Liquid Glass as a
/// live preview; reacts to settings changes immediately.
class GlassPreview extends ConsumerWidget {
  const GlassPreview({super.key, this.mode, this.intensity, this.height = 200});

  /// Overrides the mode derived from settings.
  final GlassMode? mode;

  /// Overrides `appearance.glassIntensity` (e.g. while dragging a slider).
  final double? intensity;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visuals = ref.watch(effectiveVisualsProvider);
    final resolved = mode ?? GlassMode.of(visuals);
    final c = context.colors;
    final r = context.radii;
    final l10n = context.l10n;
    final label = switch (resolved) {
      GlassMode.solid => l10n.shellGlassModeSolid,
      GlassMode.translucent => l10n.shellGlassModeTranslucent,
      GlassMode.blurred => l10n.shellGlassModeBlurred,
    };

    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: r.mdAll,
          child: SizedBox(
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: c.outlineSubtle), borderRadius: r.mdAll),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AmbientBackdrop(mode: resolved),
                  // Mock page content that scrolls "behind" the glass.
                  Positioned.fill(left: 48, child: _MockContent(color: c.accent)),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 44,
                    width: 86,
                    child: GlassSurface(
                      mode: resolved,
                      intensity: intensity,
                      edges: GlassEdges.rightOnly,
                      child: const _MockSidebar(),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 44,
                    child: GlassSurface(
                      mode: resolved,
                      intensity: intensity,
                      edges: GlassEdges.topOnly,
                      child: const _MockPlayer(),
                    ),
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

class _MockSidebar extends StatelessWidget {
  const _MockSidebar();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FermataMark(size: 16),
          const SizedBox(height: 12),
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == 0 ? c.accent : c.textSecondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(height: 6, decoration: BoxDecoration(color: c.textSecondary.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(3))),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MockPlayer extends StatelessWidget {
  const _MockPlayer();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(6)), child: const Center(child: FermataMark(size: 14))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.shellGlassPreviewTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.caption.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600)),
                Text(l10n.shellGlassPreviewArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.caption.copyWith(fontSize: 10)),
              ],
            ),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: c.textPrimary, shape: BoxShape.circle),
            child: Icon(Icons.play_arrow_rounded, size: 18, color: c.bg),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _MockContent extends StatelessWidget {
  const _MockContent({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tiles = [color, c.textSecondary, c.surfaceHigh, color.withValues(alpha: 0.6), c.textTertiary, c.outline];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Wrap(
        spacing: FermataSpacing.s8,
        runSpacing: FermataSpacing.s8,
        children: [
          for (final t in tiles)
            Container(width: 64, height: 64, decoration: BoxDecoration(color: t, borderRadius: BorderRadius.circular(10))),
        ],
      ),
    );
  }
}
