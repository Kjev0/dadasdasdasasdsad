import 'package:flutter/material.dart';

import '../../design/context_ext.dart';
import '../glass/glass_surface.dart';

/// Modal bottom sheet on a [GlassSurface] (glass/translucent/solid per the
/// user's settings) with a drag handle. Use for action sheets and pickers.
Future<T?> showFermataSheet<T>(BuildContext context, {required WidgetBuilder builder, double maxWidth = 640}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    constraints: BoxConstraints(maxWidth: maxWidth),
    builder: (sheetContext) {
      final radius = BorderRadius.vertical(top: Radius.circular(sheetContext.radii.xl));
      return GlassSurface(
        raised: true,
        floating: true,
        borderRadius: radius,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: sheetContext.colors.outline, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Flexible(child: builder(sheetContext)),
            ],
          ),
        ),
      );
    },
  );
}
