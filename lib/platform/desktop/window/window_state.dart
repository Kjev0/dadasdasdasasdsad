import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final _log = Logger('desktop.window');

/// Minimum window size of the main window.
const kMinWindowSize = Size(380, 600);

/// Size used on first launch / when saved bounds are unusable.
const kDefaultWindowSize = Size(1200, 780);

/// Saved geometry of the main window (logical pixels).
@immutable
class WindowBounds {
  const WindowBounds({required this.rect, this.maximized = false});

  final Rect rect;
  final bool maximized;

  Map<String, Object?> toJson() => {
        'x': rect.left,
        'y': rect.top,
        'width': rect.width,
        'height': rect.height,
        'maximized': maximized,
      };

  /// Returns null for missing or nonsensical values (NaN, non-positive size).
  static WindowBounds? fromJson(Object? json) {
    if (json is! Map) return null;
    double? d(String k) {
      final v = json[k];
      if (v is! num) return null;
      final x = v.toDouble();
      return x.isFinite ? x : null;
    }

    final x = d('x'), y = d('y'), w = d('width'), h = d('height');
    if (x == null || y == null || w == null || h == null || w <= 0 || h <= 0) return null;
    return WindowBounds(rect: Rect.fromLTWH(x, y, w, h), maximized: json['maximized'] == true);
  }

  @override
  bool operator ==(Object other) => other is WindowBounds && other.rect == rect && other.maximized == maximized;

  @override
  int get hashCode => Object.hash(rect, maximized);

  @override
  String toString() => 'WindowBounds($rect, maximized: $maximized)';
}

/// Reads/writes `AppPaths.windowStateFile` atomically (temp file + rename).
class WindowStateStore {
  WindowStateStore(this.file);

  final File file;

  Future<WindowBounds?> load() async {
    try {
      if (!await file.exists()) return null;
      return WindowBounds.fromJson(jsonDecode(await file.readAsString()));
    } catch (e) {
      _log.warning('Ignoring unreadable window state ${file.path}: $e');
      return null;
    }
  }

  Future<void> save(WindowBounds bounds) async {
    try {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(bounds.toJson()), flush: true);
      await tmp.rename(file.path);
    } catch (e) {
      _log.warning('Could not save window state: $e');
    }
  }
}

/// Makes saved bounds safe to apply:
/// * the size is clamped between [minSize] and the largest work area,
/// * when the window would not be reachable (less than [grip] logical pixels
///   of its top edge inside any work area — e.g. the monitor it was on is
///   gone), it is centered on the primary work area.
///
/// Without display information ([workAreas] empty) the size is clamped to
/// sane values and a far-off position is reset to the origin.
WindowBounds fitWindowBounds(
  WindowBounds saved,
  List<Rect> workAreas, {
  Size minSize = kMinWindowSize,
  double grip = 48,
}) {
  final r = saved.rect;
  if (workAreas.isEmpty) {
    const maxEdge = 8192.0;
    final w = r.width.clamp(minSize.width, maxEdge).toDouble();
    final h = r.height.clamp(minSize.height, maxEdge).toDouble();
    final x = (r.left.abs() > maxEdge) ? 0.0 : r.left;
    final y = (r.top.abs() > maxEdge) ? 0.0 : r.top;
    return WindowBounds(rect: Rect.fromLTWH(x, y, w, h), maximized: saved.maximized);
  }

  final maxW = workAreas.map((a) => a.width).reduce(math.max);
  final maxH = workAreas.map((a) => a.height).reduce(math.max);
  final w = r.width.clamp(math.min(minSize.width, maxW), math.max(minSize.width, maxW)).toDouble();
  final h = r.height.clamp(math.min(minSize.height, maxH), math.max(minSize.height, maxH)).toDouble();
  final sized = Rect.fromLTWH(r.left, r.top, w, h);

  // The title bar strip must be grabbable on some display.
  final titleStrip = Rect.fromLTWH(sized.left, sized.top, sized.width, math.min(32, sized.height));
  final reachable = workAreas.any((area) {
    final overlap = area.intersect(titleStrip);
    return overlap.width >= grip && overlap.height > 0;
  });
  if (reachable) return WindowBounds(rect: sized, maximized: saved.maximized);

  final primary = workAreas.first;
  final cw = math.min(w, primary.width);
  final ch = math.min(h, primary.height);
  final centered = Rect.fromLTWH(
    primary.left + (primary.width - cw) / 2,
    primary.top + (primary.height - ch) / 2,
    cw,
    ch,
  );
  return WindowBounds(rect: centered, maximized: saved.maximized);
}

/// Default bounds: [kDefaultWindowSize] (shrunk to fit) centered on the
/// primary work area, or null when there is no display information.
WindowBounds? defaultWindowBounds(List<Rect> workAreas) {
  if (workAreas.isEmpty) return null;
  final primary = workAreas.first;
  final w = math.min(kDefaultWindowSize.width, primary.width * 0.9);
  final h = math.min(kDefaultWindowSize.height, primary.height * 0.9);
  return WindowBounds(
    rect: Rect.fromLTWH(primary.left + (primary.width - w) / 2, primary.top + (primary.height - h) / 2, w, h),
  );
}
