import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../design/context_ext.dart';
import '../../design/fermata_tokens.dart';
import 'glass_spec.dart';

/// Which edges of a [GlassSurface] get the hairline border.
@immutable
class GlassEdges {
  const GlassEdges({this.top = false, this.right = false, this.bottom = false, this.left = false});

  static const all = GlassEdges(top: true, right: true, bottom: true, left: true);
  static const none = GlassEdges();
  static const topOnly = GlassEdges(top: true);
  static const rightOnly = GlassEdges(right: true);
  static const bottomOnly = GlassEdges(bottom: true);

  final bool top;
  final bool right;
  final bool bottom;
  final bool left;

  bool get isAll => top && right && bottom && left;

  bool get isNone => !top && !right && !bottom && !left;

  @override
  bool operator ==(Object other) =>
      other is GlassEdges && other.top == top && other.right == right && other.bottom == bottom && other.left == left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);
}

/// Surface used for floating/chrome UI (sidebar, player bar, mini-player,
/// bottom navigation, sheets).
///
/// * glass off → solid surface,
/// * glass on + blur allowed → `BackdropFilter` clipped to [borderRadius] +
///   translucent fill, hairline border, top highlight and inner sheen,
/// * glass on + blur disabled (performance/battery modes) → translucent
///   tinted fill without blur.
///
/// Mode changes cross-fade (duration scaled by motion preferences). The
/// [child] is never rebuilt by a mode change, so its state survives.
class GlassSurface extends ConsumerWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.edges = GlassEdges.all,
    this.padding = EdgeInsets.zero,
    this.raised = false,
    this.floating = false,
    this.mode,
    this.intensity,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final GlassEdges edges;
  final EdgeInsetsGeometry padding;

  /// Use `surfaceRaised` as the base colour (sheets, popovers).
  final bool raised;

  /// Floating surfaces get a soft shadow.
  final bool floating;

  /// Overrides the mode derived from settings (used by [GlassPreview]).
  final GlassMode? mode;

  /// Overrides `appearance.glassIntensity`.
  final double? intensity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visuals = ref.watch(effectiveVisualsProvider);
    final c = context.colors;
    final resolvedMode = mode ?? GlassMode.of(visuals);
    final spec = GlassSpec.resolve(
      c,
      resolvedMode,
      intensity ?? visuals.glassIntensity,
      base: raised ? c.surfaceRaised : c.surface,
    );
    final duration = visuals.duration(FermataMotion.baseEmphasis);

    Widget surface = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, ?current],
            ),
            child: _GlassLayer(
              key: ValueKey(resolvedMode),
              spec: spec,
              borderRadius: borderRadius,
              edges: edges,
            ),
          ),
        ),
        Padding(padding: padding, child: child),
      ],
    );

    if (floating) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: surface,
      );
    }
    return surface;
  }
}

class _GlassLayer extends StatelessWidget {
  const _GlassLayer({super.key, required this.spec, required this.borderRadius, required this.edges});

  final GlassSpec spec;
  final BorderRadius borderRadius;
  final GlassEdges edges;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: spec.border);
    final Border border = edges.isAll
        ? Border.all(color: spec.border)
        : Border(
            top: edges.top ? side : BorderSide.none,
            right: edges.right ? side : BorderSide.none,
            bottom: edges.bottom ? side : BorderSide.none,
            left: edges.left ? side : BorderSide.none,
          );
    // Flutter only supports a border radius with uniform borders.
    final useRadius = edges.isAll || edges.isNone;

    Widget fill = DecoratedBox(
      decoration: BoxDecoration(
        color: spec.fill,
        borderRadius: useRadius ? borderRadius : null,
        border: border,
      ),
      child: spec.mode == GlassMode.solid
          ? const SizedBox.expand()
          : Stack(
              fit: StackFit.expand,
              children: [
                // Subtle diagonal sheen.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [spec.sheen, spec.sheen.withValues(alpha: 0)],
                      stops: const [0, 0.55],
                    ),
                  ),
                ),
                // Soft highlight along the top edge.
                if (edges.top)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            spec.highlight.withValues(alpha: 0),
                            spec.highlight,
                            spec.highlight.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );

    if (spec.mode == GlassMode.blurred) {
      fill = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: spec.sigma, sigmaY: spec.sigma),
        child: fill,
      );
    }
    if (spec.mode != GlassMode.solid) {
      fill = ClipRRect(borderRadius: borderRadius, child: fill);
    }
    return fill;
  }
}
