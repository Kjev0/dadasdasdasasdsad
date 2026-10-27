import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/context_ext.dart';

/// Small three-bar equalizer marking the playing row. Animates only when
/// [animate] is true (playing and animations allowed); otherwise static.
class NowPlayingGlyph extends StatefulWidget {
  const NowPlayingGlyph({super.key, required this.animate, this.size = 16, this.color});

  final bool animate;
  final double size;
  final Color? color;

  @override
  State<NowPlayingGlyph> createState() => _NowPlayingGlyphState();
}

class _NowPlayingGlyphState extends State<NowPlayingGlyph> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(NowPlayingGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _sync();
  }

  void _sync() {
    if (widget.animate) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colors.accentText;
    return Semantics(
      label: context.l10n.shellNowPlayingIndicator,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _BarsPainter(color: color, t: widget.animate ? _controller.value : null),
          ),
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter({required this.color, required this.t});

  final Color color;

  /// Animation phase 0..1, or null for the static glyph.
  final double? t;

  static const _static = [0.55, 0.9, 0.4];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final barWidth = size.width / 5;
    for (var i = 0; i < 3; i++) {
      final h = t == null ? _static[i] : 0.3 + 0.7 * (0.5 + 0.5 * math.sin((t! + i * 0.27) * 2 * math.pi)).abs();
      final height = size.height * h;
      final left = i * barWidth * 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) => oldDelegate.t != t || oldDelegate.color != color;
}
