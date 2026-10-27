import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/context_ext.dart';
import '../widgets/brand/fermata_mark.dart';
import '../widgets/glass/glass_surface.dart';
import 'destinations.dart';

/// Medium-layout navigation rail (scrolls when the window is short, so it
/// never overflows).
class FermataNavRail extends StatelessWidget {
  const FermataNavRail({super.key, required this.location});

  static const width = 80.0;

  final Uri location;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = NavDestination.matching(location.path);
    Widget item(NavDestination d) => _RailItem(
          icon: d.icon,
          label: d.label(l10n),
          selected: active == d,
          onTap: () => context.go(d.path),
        );
    return SizedBox(
      width: width,
      child: GlassSurface(
        edges: GlassEdges.rightOnly,
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.only(top: 20, bottom: 12), child: FermataMark(size: 28)),
            Expanded(
              child: SingleChildScrollView(
                child: Column(children: [for (final d in NavDestination.railItems) item(d)]),
              ),
            ),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: item(NavDestination.settings)),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: context.radii.smAll,
          child: Container(
            width: 72,
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? c.accent.withValues(alpha: 0.16) : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 20, color: selected ? c.accentText : c.textSecondary),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption.copyWith(
                    fontSize: 11,
                    color: selected ? c.textPrimary : c.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
