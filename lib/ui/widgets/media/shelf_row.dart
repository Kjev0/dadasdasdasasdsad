import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../design/context_ext.dart';
import '../controls/section_header.dart';

/// Titled horizontal scroller (Home/Explore shelves). On medium/expanded
/// layouts it shows previous/next arrow buttons that page by ~80 % of the
/// visible width.
class ShelfRow extends ConsumerStatefulWidget {
  const ShelfRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.itemCount,
    required this.itemBuilder,
    this.itemWidth = 168,
    this.height,
    this.spacing = 12,
    this.onSeeAll,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double itemWidth;

  /// Row height; defaults to artwork + two text lines.
  final double? height;
  final double spacing;
  final VoidCallback? onSeeAll;
  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<ShelfRow> createState() => _ShelfRowState();
}

class _ShelfRowState extends ConsumerState<ShelfRow> {
  final _controller = ScrollController();
  bool _canBack = false;
  bool _canForward = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted || !_controller.hasClients) return;
    final p = _controller.position;
    final back = p.pixels > 1;
    final forward = p.pixels < p.maxScrollExtent - 1;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  void _page(int direction) {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final target = (p.pixels + direction * p.viewportDimension * 0.8).clamp(0.0, p.maxScrollExtent);
    final duration = ref.read(effectiveVisualsProvider).duration(const Duration(milliseconds: 360));
    if (duration == Duration.zero) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(target, duration: duration, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showArrows = MediaQuery.sizeOf(context).width >= 600;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final height = widget.height ?? widget.itemWidth + 8 + 10 + 44 * textScale;
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            actionLabel: widget.onSeeAll == null ? null : l10n.shellSeeAll,
            onAction: widget.onSeeAll,
            trailing: showArrows
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.shellScrollLeft,
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: _canBack ? () => _page(-1) : null,
                      ),
                      IconButton(
                        tooltip: l10n.shellScrollRight,
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: _canForward ? () => _page(1) : null,
                      ),
                    ],
                  )
                : null,
          ),
          SizedBox(
            height: height,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              itemCount: widget.itemCount,
              separatorBuilder: (_, _) => SizedBox(width: widget.spacing),
              itemBuilder: widget.itemBuilder,
            ),
          ),
        ],
      ),
    );
  }
}
