import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../design/context_ext.dart';

/// Loading placeholder block. Shimmers only when animations are allowed
/// (`EffectiveVisuals.animate`); otherwise it is static.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius, this.circle = false});

  final double? width;
  final double height;
  final double? radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius ?? context.radii.xs),
      ),
    );
  }
}

/// Wraps skeleton content with a moving highlight when animations are on.
class SkeletonShimmer extends ConsumerStatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends ConsumerState<SkeletonShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = ref.watch(effectiveVisualsProvider.select((v) => v.animate));
    final child = Semantics(label: context.l10n.shellLoading, child: ExcludeSemantics(child: widget.child));
    if (!animate) {
      if (_controller.isAnimating) _controller.stop();
      return child;
    }
    if (!_controller.isAnimating) _controller.repeat();
    final highlight = context.colors.textPrimary.withValues(alpha: 0.06);
    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final t = _controller.value * 2 - 0.5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1 + t * 2, 0),
            end: Alignment(t * 2, 0),
            colors: [Colors.transparent, highlight, Colors.transparent],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// Skeleton for a track row (artwork + two lines + duration).
class SkeletonTrackTile extends StatelessWidget {
  const SkeletonTrackTile({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.spacing.rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Skeleton(width: 40, height: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(widthFactor: 0.6, child: const Skeleton(height: 12)),
                  const SizedBox(height: 6),
                  FractionallySizedBox(widthFactor: 0.35, child: const Skeleton(height: 10)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Skeleton(width: 32, height: 10),
          ],
        ),
      ),
    );
  }
}

/// A shimmering list of [count] track-row skeletons.
class SkeletonTrackList extends StatelessWidget {
  const SkeletonTrackList({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < count; i++) const SkeletonTrackTile()],
      ),
    );
  }
}

/// Skeleton for a [MediaCard].
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.width = 168});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Skeleton(width: width, height: width, radius: context.radii.md),
          const SizedBox(height: 10),
          Skeleton(width: width * 0.7, height: 12),
          const SizedBox(height: 6),
          Skeleton(width: width * 0.45, height: 10),
        ],
      ),
    );
  }
}
