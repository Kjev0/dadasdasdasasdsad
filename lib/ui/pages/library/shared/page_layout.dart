import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/context_ext.dart';
import '../../../widgets/artwork/artwork_image.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/feedback/skeleton.dart';
import '../../../widgets/feedback/states.dart';

/// Horizontal page padding for the current window width (16 on compact,
/// the density gutter on medium/expanded).
EdgeInsets pageInsets(BuildContext context) {
  final p = context.spacing.pagePadding(MediaQuery.sizeOf(context).width);
  return EdgeInsets.symmetric(horizontal: p.left);
}

/// True below the compact breakpoint (600 dp).
bool isCompactWidth(BuildContext context) => MediaQuery.sizeOf(context).width < 600;

/// Large page title with an optional subtitle and actions. On compact
/// widths the actions wrap below the title so nothing overflows.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Shown before the title (e.g. a back button for in-page detail views).
  final Widget? leading;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final compact = isCompactWidth(context);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: compact ? context.type.title.copyWith(fontSize: 24) : context.type.headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: context.type.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
    final head = Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(child: titleBlock),
        if (!compact && actions.isNotEmpty) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: padding ?? pageInsets(context).copyWith(top: compact ? 16 : 24, bottom: 12),
      child: compact && actions.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                head,
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
              ],
            )
          : head,
    );
  }
}

/// Renders an [AsyncValue]: [loading] (a skeleton by default), a localized
/// error with retry, or [data]. Keeps showing data while refreshing.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
    this.compactError = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;
  final bool compactError;

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        error: (e, _) => ErrorState(error: e, onRetry: onRetry, compact: compactError),
        loading: () => loading ?? const SkeletonTrackList(),
      );
}

/// Skeleton for a horizontal shelf of cards.
class SkeletonShelf extends StatelessWidget {
  const SkeletonShelf({super.key, this.count = 6, this.cardWidth = 160});

  final int count;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Skeleton(width: 180, height: 18),
          const SizedBox(height: 16),
          SizedBox(
            height: cardWidth + 48,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: double.infinity,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < count; i++) ...[
                      SkeletonCard(width: cardWidth),
                      const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a collection header (artwork + title lines).
class SkeletonHeader extends StatelessWidget {
  const SkeletonHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = isCompactWidth(context);
    final art = Skeleton(width: compact ? 140 : 200, height: compact ? 140 : 200, radius: context.radii.lg);
    final lines = Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: const [
        Skeleton(width: 80, height: 10),
        SizedBox(height: 12),
        Skeleton(width: 220, height: 24),
        SizedBox(height: 12),
        Skeleton(width: 140, height: 12),
      ],
    );
    return SkeletonShimmer(
      child: Padding(
        padding: pageInsets(context).copyWith(top: 24, bottom: 16),
        child: compact
            ? Column(children: [art, const SizedBox(height: 16), lines])
            : Row(children: [art, const SizedBox(width: 24), Expanded(child: lines)]),
      ),
    );
  }
}

/// Up to four artworks in a 2×2 mosaic (one artwork fills the square).
class ArtworkMosaic extends StatelessWidget {
  const ArtworkMosaic({super.key, required this.uris, required this.size, this.borderRadius});

  final List<Uri> uris;
  final double size;
  final BorderRadius? borderRadius;

  /// Distinct artworks of [all], in order, at most four.
  static List<Uri> pick(Iterable<Uri?> all) {
    final seen = <String>{};
    final out = <Uri>[];
    for (final u in all) {
      if (u == null || !seen.add(u.toString())) continue;
      out.add(u);
      if (out.length == 4) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? context.radii.lgAll;
    if (uris.length < 4) {
      return SizedBox.square(
        dimension: size,
        child: ArtworkImage(uri: uris.isEmpty ? null : uris.first, size: size, borderRadius: radius),
      );
    }
    final half = size / 2;
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox.square(
        dimension: size,
        child: Wrap(
          children: [
            for (final u in uris.take(4))
              SizedBox.square(dimension: half, child: ArtworkImage(uri: u, size: half, borderRadius: BorderRadius.zero)),
          ],
        ),
      ),
    );
  }
}

/// Header for a track collection (playlist, album, artist, mix): artwork,
/// eyebrow (kind), title, subtitle, meta line, description and actions.
/// Side-by-side on medium/expanded widths, stacked on compact.
class CollectionHeader extends StatelessWidget {
  const CollectionHeader({
    super.key,
    required this.title,
    required this.artwork,
    this.eyebrow,
    this.subtitle,
    this.meta,
    this.description,
    this.actions = const [],
    this.leading,
  });

  final String title;

  /// Square artwork widget (sized by the header via [artworkSize]).
  final Widget Function(double size) artwork;
  final String? eyebrow;
  final String? subtitle;
  final String? meta;
  final String? description;
  final List<Widget> actions;

  /// e.g. a back button shown above the header.
  final Widget? leading;

  static double artworkSize(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w < 600 ? 148 : (w < 1024 ? 180 : 216);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final compact = isCompactWidth(context);
    final size = artworkSize(context);
    final align = compact ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = compact ? TextAlign.center : TextAlign.start;
    final info = Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null)
          Text(eyebrow!.toUpperCase(), style: context.type.caption.copyWith(color: c.accentText, letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: textAlign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: compact ? context.type.title.copyWith(fontSize: 24) : context.type.display.copyWith(fontSize: 34),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, textAlign: textAlign, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.type.body),
        ],
        if (meta != null) ...[
          const SizedBox(height: 4),
          Text(meta!, textAlign: textAlign, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.type.bodySmall),
        ],
        if (description != null && description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(description!, textAlign: textAlign, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.type.bodySmall),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: compact ? WrapAlignment.center : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      ],
    );
    return Padding(
      padding: pageInsets(context).copyWith(top: compact ? 12 : 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) Align(alignment: Alignment.centerLeft, child: leading),
          if (compact)
            Column(children: [SizedBox.square(dimension: size, child: artwork(size)), const SizedBox(height: 16), info])
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox.square(dimension: size, child: artwork(size)),
                const SizedBox(width: 24),
                Expanded(child: info),
              ],
            ),
        ],
      ),
    );
  }
}

/// "Play" + "Shuffle" buttons for a collection header. Disabled when
/// [enabled] is false (nothing playable).
class PlayShuffleButtons extends StatelessWidget {
  const PlayShuffleButtons({super.key, required this.onPlay, required this.onShuffle, this.enabled = true});

  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FermataButton(label: l10n.pagesPlay, icon: Icons.play_arrow_rounded, onPressed: enabled ? onPlay : null),
        FermataButton(
          label: l10n.pagesShuffle,
          icon: Icons.shuffle_rounded,
          variant: FermataButtonVariant.secondary,
          onPressed: enabled ? onShuffle : null,
        ),
      ],
    );
  }
}

/// Back button for in-page detail views (Explore genre/mood, Home shelf).
class BackHeaderButton extends StatelessWidget {
  const BackHeaderButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: onPressed,
      );
}

/// Inline notice row (info / warning) with an optional action.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.actionLabel,
    this.onAction,
    this.warning = false,
    this.title,
  });

  final String message;
  final String? title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = warning ? c.warning : c.accentText;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: c.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: context.radii.mdAll,
        border: Border.all(color: c.outlineSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) Text(title!, style: context.type.label),
                Text(message, style: context.type.bodySmall),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
