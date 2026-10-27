import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../design/context_ext.dart';
import '../brand/fermata_mark.dart';

/// Turns an artwork [Uri] into an [ImageProvider]. Returns null for
/// unsupported URIs (the placeholder is shown).
typedef ArtworkImageResolver = ImageProvider? Function(Uri uri);

/// Default resolver: `http(s)` → [NetworkImage] (memory cache only),
/// `file:` / absolute paths → [FileImage].
///
/// Bootstrap may override [artworkImageResolverProvider] with a resolver
/// backed by the downloads module's disk cache (`FermataArtworkCache` +
/// `CachedNetworkImageProvider`) — see `lib/ui/design/README.md`.
ImageProvider? defaultArtworkResolver(Uri uri) {
  switch (uri.scheme) {
    case 'http' || 'https':
      return NetworkImage(uri.toString());
    case 'file':
      return FileImage(File(uri.toFilePath()));
    case '':
      return uri.path.startsWith('/') ? FileImage(File(uri.path)) : null;
    default:
      return null;
  }
}

/// How artwork URIs become images. Override in bootstrap for disk caching.
final artworkImageResolverProvider = Provider<ArtworkImageResolver>((ref) => defaultArtworkResolver);

/// Album/track artwork with a fermata-mark placeholder, size-aware decoding
/// (`EffectiveVisuals.artworkPixels`) and a fade-in that respects motion
/// preferences.
class ArtworkImage extends ConsumerWidget {
  const ArtworkImage({
    super.key,
    required this.uri,
    this.size,
    this.borderRadius,
    this.circle = false,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  final Uri? uri;

  /// Square edge length. Null = fill the incoming constraints.
  final double? size;
  final BorderRadius? borderRadius;

  /// Clip to a circle (artists).
  final bool circle;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visuals = ref.watch(effectiveVisualsProvider);
    final resolver = ref.watch(artworkImageResolverProvider);
    final radius = borderRadius ?? context.radii.smAll;

    Widget content(double logical) {
      final provider = uri == null ? null : resolver(uri!);
      if (provider == null) return ArtworkPlaceholder(size: logical);
      final px = visuals.artworkPixels(logical, MediaQuery.devicePixelRatioOf(context));
      final fade = visuals.duration(const Duration(milliseconds: 220));
      return Image(
        image: ResizeImage(provider, width: px, policy: ResizeImagePolicy.fit, height: px),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
        frameBuilder: (context, child, frame, sync) {
          if (sync || fade == Duration.zero) return child;
          return AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: fade, curve: Curves.easeOutCubic, child: child);
        },
        errorBuilder: (_, _, _) => ArtworkPlaceholder(size: logical),
      );
    }

    Widget clipped(double logical) {
      final child = content(logical);
      return circle ? ClipOval(child: child) : ClipRRect(borderRadius: radius, child: child);
    }

    if (size != null) return SizedBox.square(dimension: size, child: clipped(size!));
    return LayoutBuilder(
      builder: (context, c) {
        final logical = c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 300.0;
        return clipped(logical);
      },
    );
  }
}

/// Neutral artwork placeholder with the fermata mark.
class ArtworkPlaceholder extends StatelessWidget {
  const ArtworkPlaceholder({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surfaceHigh),
      child: Center(child: FermataMark(size: (size * 0.38).clamp(10.0, 120.0), color: c.textTertiary)),
    );
  }
}
