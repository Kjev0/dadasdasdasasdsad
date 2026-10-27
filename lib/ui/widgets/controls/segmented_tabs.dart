import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../design/context_ext.dart';

/// One option of [SegmentedTabs].
class SegmentedTab<T> {
  const SegmentedTab(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Pill-style tab switcher (Library tabs, filters). Horizontally scrollable
/// when it doesn't fit.
class SegmentedTabs<T> extends ConsumerWidget {
  const SegmentedTabs({super.key, required this.tabs, required this.selected, required this.onChanged});

  final List<SegmentedTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final duration = ref.watch(effectiveVisualsProvider).duration(const Duration(milliseconds: 120));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: context.radii.smAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tab in tabs)
              Semantics(
                selected: tab.value == selected,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onChanged(tab.value),
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: tab.value == selected ? c.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tab.value == selected ? c.outline : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tab.icon != null) ...[
                          Icon(tab.icon, size: 16, color: tab.value == selected ? c.accentText : c.textSecondary),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          tab.label,
                          style: context.type.label.copyWith(
                            color: tab.value == selected ? c.textPrimary : c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
