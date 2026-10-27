import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../util/async_utils.dart';
import 'artwork_image.dart';

final _log = Logger('ui.artwork.palette');

/// Colours extracted from artwork for backdrops and gradients.
///
/// Cheap by design: the artwork is decoded at ≤ 32×32 px and colours are
/// counted in a 4-bit-per-channel histogram.
class ArtworkPalette {
  const ArtworkPalette({required this.dominant, required this.vibrant, required this.muted});

  /// Most frequent colour.
  final Color dominant;

  /// Most saturated, reasonably frequent colour (falls back to [dominant]).
  final Color vibrant;

  /// Least saturated frequent colour (falls back to [dominant]).
  final Color muted;

  /// Extracts a palette from raw RGBA bytes. Returns null when the image has
  /// no opaque pixels.
  static ArtworkPalette? fromRgba(Uint8List rgba) {
    final counts = <int, _Bucket>{};
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      if (rgba[i + 3] < 128) continue;
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      (counts[key] ??= _Bucket()).add(r, g, b);
    }
    if (counts.isEmpty) return null;
    final buckets = counts.values.toList()..sort((a, b) => b.count.compareTo(a.count));
    final dominant = buckets.first;
    final total = buckets.fold<int>(0, (s, b) => s + b.count);

    _Bucket? vibrant;
    var vibrantScore = 0.0;
    _Bucket? muted;
    var mutedScore = 0.0;
    for (final b in buckets) {
      final hsl = HSLColor.fromColor(b.color);
      final share = b.count / total;
      if (share < 0.01) continue;
      if (hsl.lightness > 0.2 && hsl.lightness < 0.85) {
        final v = share * hsl.saturation * hsl.saturation;
        if (v > vibrantScore) {
          vibrantScore = v;
          vibrant = b;
        }
      }
      final m = share * (1 - hsl.saturation);
      if (m > mutedScore) {
        mutedScore = m;
        muted = b;
      }
    }
    return ArtworkPalette(
      dominant: dominant.color,
      vibrant: (vibrant ?? dominant).color,
      muted: (muted ?? dominant).color,
    );
  }

  /// Decodes [provider] at a tiny size and extracts its palette. Returns null
  /// when the image can't be loaded.
  static Future<ArtworkPalette?> fromImageProvider(ImageProvider provider, {int sample = 32}) async {
    final resized = ResizeImage(provider, width: sample, height: sample, policy: ResizeImagePolicy.fit);
    final stream = resized.resolve(ImageConfiguration.empty);
    final completer = Completer<ui.Image?>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image.clone());
        info.dispose();
      },
      onError: (error, _) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    stream.addListener(listener);
    try {
      final image = await completer.future;
      if (image == null) return null;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) return null;
        return fromRgba(data.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    } catch (e) {
      _log.fine('Palette extraction failed: $e');
      return null;
    } finally {
      stream.removeListener(listener);
    }
  }
}

class _Bucket {
  int count = 0;
  int _r = 0, _g = 0, _b = 0;

  void add(int r, int g, int b) {
    count++;
    _r += r;
    _g += g;
    _b += b;
  }

  Color get color => Color.fromARGB(255, _r ~/ count, _g ~/ count, _b ~/ count);
}

/// Palette of an artwork URI (null while unknown or on failure).
final artworkPaletteProvider = FutureProvider.autoDispose.family<ArtworkPalette?, Uri>(
  (ref, uri) async {
    final provider = ref.watch(artworkImageResolverProvider)(uri);
    if (provider == null) return null;
    return ArtworkPalette.fromImageProvider(provider);
  },
  retry: noRetry,
);
