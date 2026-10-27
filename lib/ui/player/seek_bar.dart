import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/context_ext.dart';
import '../design/fermata_tokens.dart';
import '../widgets/tracks/track_format.dart';

/// Seek bar with elapsed / remaining labels (tabular figures).
///
/// * Drag or tap to seek; while dragging the labels preview the target and
///   [onSeek] fires once when the drag ends.
/// * Keyboard: ←/→ seek by [step], Home/End jump to start/end (when focused).
/// * Screen readers get a slider with increase/decrease actions.
class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    this.buffered = Duration.zero,
    required this.onSeek,
    this.showLabels = true,
    this.step = const Duration(seconds: 5),
    this.thickness = 4,
  });

  final Duration position;

  /// Null/zero = unknown (bar disabled).
  final Duration? duration;
  final Duration buffered;
  final ValueChanged<Duration>? onSeek;
  final bool showLabels;
  final Duration step;
  final double thickness;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragFraction;
  bool _hover = false;
  bool _focused = false;
  final _focusNode = FocusNode(debugLabel: 'SeekBar');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  int get _totalMs => widget.duration?.inMilliseconds ?? 0;
  bool get _enabled => widget.onSeek != null && _totalMs > 0;

  double get _fraction {
    if (_dragFraction != null) return _dragFraction!;
    if (_totalMs <= 0) return 0;
    return (widget.position.inMilliseconds / _totalMs).clamp(0.0, 1.0);
  }

  Duration _at(double fraction) => Duration(milliseconds: (fraction.clamp(0.0, 1.0) * _totalMs).round());

  Duration get _shownPosition => _dragFraction != null ? _at(_dragFraction!) : widget.position;

  void _seekTo(Duration d) {
    if (!_enabled) return;
    final clamped = Duration(milliseconds: d.inMilliseconds.clamp(0, _totalMs));
    widget.onSeek!(clamped);
  }

  double _fractionFor(Offset local, double width) => width <= 0 ? 0 : (local.dx / width).clamp(0.0, 1.0);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      _seekTo(widget.position + widget.step);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _seekTo(widget.position - widget.step);
    } else if (key == LogicalKeyboardKey.home) {
      _seekTo(Duration.zero);
    } else if (key == LogicalKeyboardKey.end) {
      _seekTo(widget.duration! - const Duration(seconds: 1));
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final labelStyle = FermataTypography.tabular(context.type.caption.copyWith(color: c.textSecondary));
    final total = widget.duration ?? Duration.zero;
    final shown = _shownPosition;
    final remaining = total - shown;
    final active = _hover || _focused || _dragFraction != null;
    final buffered = _totalMs <= 0 ? 0.0 : (widget.buffered.inMilliseconds / _totalMs).clamp(0.0, 1.0);

    final bar = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _enabled ? (d) => _seekTo(_at(_fractionFor(d.localPosition, width))) : null,
          onHorizontalDragStart: _enabled ? (d) => setState(() => _dragFraction = _fractionFor(d.localPosition, width)) : null,
          onHorizontalDragUpdate: _enabled ? (d) => setState(() => _dragFraction = _fractionFor(d.localPosition, width)) : null,
          onHorizontalDragEnd: _enabled
              ? (_) {
                  final f = _dragFraction;
                  setState(() => _dragFraction = null);
                  if (f != null) _seekTo(_at(f));
                }
              : null,
          onHorizontalDragCancel: () => setState(() => _dragFraction = null),
          child: SizedBox(
            height: 24,
            child: CustomPaint(
              painter: _SeekPainter(
                fraction: _fraction,
                buffered: buffered,
                active: active,
                enabled: _enabled,
                thickness: widget.thickness,
                activeColor: _enabled ? (active ? c.accent : c.textPrimary) : c.textTertiary,
                bufferedColor: c.textTertiary.withValues(alpha: 0.5),
                trackColor: c.outline,
                thumbColor: c.textPrimary,
                focusColor: c.accent.withValues(alpha: 0.35),
                focused: _focused,
              ),
            ),
          ),
        );
      },
    );

    final semantic = Semantics(
      slider: true,
      enabled: _enabled,
      label: l10n.playerSeek,
      value: formatDuration(shown),
      increasedValue: formatDuration(shown + widget.step),
      decreasedValue: formatDuration(shown - widget.step > Duration.zero ? shown - widget.step : Duration.zero),
      onIncrease: _enabled ? () => _seekTo(widget.position + widget.step) : null,
      onDecrease: _enabled ? () => _seekTo(widget.position - widget.step) : null,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: _enabled,
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: bar,
        ),
      ),
    );

    if (!widget.showLabels) return semantic;
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            formatDuration(shown),
            key: const ValueKey('seek-elapsed'),
            textAlign: TextAlign.right,
            style: labelStyle,
            semanticsLabel: l10n.playerElapsed(formatDuration(shown)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: semantic),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          child: Text(
            total == Duration.zero ? '--:--' : '-${formatDuration(remaining)}',
            key: const ValueKey('seek-remaining'),
            style: labelStyle,
            semanticsLabel: l10n.playerRemaining(formatDuration(remaining)),
          ),
        ),
      ],
    );
  }
}

class _SeekPainter extends CustomPainter {
  const _SeekPainter({
    required this.fraction,
    required this.buffered,
    required this.active,
    required this.enabled,
    required this.thickness,
    required this.activeColor,
    required this.bufferedColor,
    required this.trackColor,
    required this.thumbColor,
    required this.focusColor,
    required this.focused,
  });

  final double fraction;
  final double buffered;
  final bool active;
  final bool enabled;
  final double thickness;
  final Color activeColor;
  final Color bufferedColor;
  final Color trackColor;
  final Color thumbColor;
  final Color focusColor;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    final h = active ? thickness + 1 : thickness;
    final y = size.height / 2;
    final radius = Radius.circular(h / 2);
    RRect seg(double from, double to) =>
        RRect.fromRectAndRadius(Rect.fromLTRB(size.width * from, y - h / 2, size.width * to, y + h / 2), radius);

    canvas.drawRRect(seg(0, 1), Paint()..color = trackColor);
    if (buffered > 0) canvas.drawRRect(seg(0, buffered), Paint()..color = bufferedColor);
    if (fraction > 0) canvas.drawRRect(seg(0, fraction), Paint()..color = activeColor);
    if (enabled && (active || focused)) {
      final center = Offset(size.width * fraction, y);
      if (focused) canvas.drawCircle(center, 10, Paint()..color = focusColor);
      canvas.drawCircle(center, 6, Paint()..color = thumbColor);
    }
  }

  @override
  bool shouldRepaint(_SeekPainter old) =>
      old.fraction != fraction ||
      old.buffered != buffered ||
      old.active != active ||
      old.enabled != enabled ||
      old.focused != focused ||
      old.activeColor != activeColor ||
      old.trackColor != trackColor;
}
