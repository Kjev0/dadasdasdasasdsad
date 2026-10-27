import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../design/context_ext.dart';

/// The fermata mark (an arch over a dot), painted in code so placeholders
/// never depend on asset files.
class FermataMark extends StatelessWidget {
  const FermataMark({super.key, this.size = 24, this.color});

  final double size;

  /// Defaults to the accent colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: FermataMarkPainter(color ?? context.colors.accent)),
    );
  }
}

/// Paints the fermata glyph into its canvas size (square).
class FermataMarkPainter extends CustomPainter {
  const FermataMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final origin = Offset((size.width - s) / 2, (size.height - s) / 2);
    final stroke = s * 0.09;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    // Arch: upper half of an ellipse.
    final arch = Rect.fromLTWH(origin.dx + s * 0.12, origin.dy + s * 0.2, s * 0.76, s * 0.76);
    canvas.drawArc(arch, math.pi, math.pi, false, paint);
    // Dot under the arch.
    canvas.drawCircle(
      Offset(origin.dx + s / 2, origin.dy + s * 0.6),
      s * 0.085,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(FermataMarkPainter oldDelegate) => oldDelegate.color != color;
}

/// Brand logo: the branding agent's SVG (`assets/branding/logo_mark.svg`)
/// when bundled, otherwise the painted [FermataMark]; plus the wordmark.
class FermataLogo extends StatelessWidget {
  const FermataLogo({super.key, this.markSize = 28, this.showWordmark = true});

  static const markAsset = 'assets/branding/logo_mark.svg';

  final double markSize;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = SvgPicture.asset(
      markAsset,
      width: markSize,
      height: markSize,
      excludeFromSemantics: true,
      placeholderBuilder: (_) => FermataMark(size: markSize),
      errorBuilder: (_, _, _) => FermataMark(size: markSize),
    );
    if (!showWordmark) return Semantics(label: context.l10n.appName, child: mark);
    return Semantics(
      label: context.l10n.appName,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: 10),
          Text(
            context.l10n.appName,
            style: context.type.title.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          ),
        ],
      ),
    );
  }
}
