import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models/download.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../actions/routes.dart';
import '../actions/track_actions.dart';
import '../design/context_ext.dart';
import '../widgets/artwork/artwork_image.dart';
import '../widgets/chips/badges.dart';
import '../widgets/feedback/messages.dart';
import 'player_providers.dart';

/// Large artwork (radius 20, soft shadow), square, as big as fits.
class NowPlayingArtwork extends StatelessWidget {
  const NowPlayingArtwork({super.key, required this.track, this.maxSize = 520});

  final Track track;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = [constraints.maxWidth, constraints.maxHeight, maxSize].reduce((a, b) => a < b ? a : b);
        return Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: context.radii.lgAll,
              boxShadow: [BoxShadow(color: c.shadow, blurRadius: 40, offset: const Offset(0, 16))],
            ),
            child: ArtworkImage(
              uri: track.artworkUrl,
              borderRadius: context.radii.lgAll,
              semanticLabel: context.l10n.playerArtwork,
            ),
          ),
        );
      },
    );
  }
}

/// Title, artist (→ artist page) and album.
class NowPlayingInfo extends StatelessWidget {
  const NowPlayingInfo({super.key, required this.track, this.center = false, this.trailing});

  final Track track;
  final bool center;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final artistRoute = AppRoutes.artistForTrack(track);
    final align = center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = center ? TextAlign.center : TextAlign.start;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: align,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: textAlign, style: context.type.headline.copyWith(fontSize: 24, height: 1.2)),
              const SizedBox(height: 4),
              InkWell(
                onTap: artistRoute == null ? null : () => context.go(artistRoute),
                child: Text(track.artistLine, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: textAlign, style: context.type.body.copyWith(color: c.textSecondary)),
              ),
              if ((track.album ?? '').isNotEmpty)
                Text(track.album!, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: textAlign, style: context.type.bodySmall.copyWith(color: c.textTertiary)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Availability / source chips: "Preview" (with provider attribution, e.g.
/// "30-second preview · Deezer"), the source name, "Your file",
/// "Downloaded".
class NowPlayingChips extends ConsumerWidget {
  const NowPlayingChips({super.key, required this.track, this.center = false});

  final Track track;
  final bool center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = context.l10n;
    final isPreview = ref.watch(currentSnapshotProvider.select((s) => s.isPreview)) ||
        track.availability.playback == PlaybackRights.preview;
    final downloaded = ref.watch(downloadedIdsProvider.select((v) => v.value?.contains(track.id) ?? false));
    final provider = sourceDisplayName(ref, track.sourceId);
    final previewSeconds = track.availability.previewDuration?.inSeconds ?? 30;
    Widget chip(String label, IconData icon, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: c.surfaceHigh.withValues(alpha: 0.7),
            borderRadius: context.radii.smAll,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: context.type.caption.copyWith(color: color, fontWeight: FontWeight.w600))),
            ],
          ),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      children: [
        if (isPreview) chip(l10n.playerPreviewFrom(previewSeconds, provider), Icons.timelapse_rounded, c.warning),
        if (track.sourceId == SourceIds.local)
          chip(l10n.playerChipYourFile, Icons.folder_rounded, c.accentText)
        else
          chip(provider, Icons.graphic_eq_rounded, c.textSecondary),
        if (downloaded) chip(l10n.playerChipDownloaded, Icons.download_done_rounded, c.success),
      ],
    );
  }
}

/// Banner for the current track's playback failure with the localized
/// `AvailabilityReason`.
class PlaybackErrorBanner extends ConsumerWidget {
  const PlaybackErrorBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = context.l10n;
    final failure = ref.watch(playbackFailureProvider);
    final snap = ref.watch(currentSnapshotProvider);
    String? reason;
    var show = false;
    if (failure != null && (snap.current == null || failure.item.uid == snap.current!.uid || !failure.skipped)) {
      show = true;
      reason = failureReason(failure);
    } else if (snap.errorMessage != null) {
      show = true;
      reason = isAvailabilityReason(snap.errorMessage) ? snap.errorMessage : null;
    }
    if (!show) return const SizedBox.shrink();
    final detail = reason != null
        ? availabilityReasonText(l10n, reason)
        : failure != null
            ? (errorMessageFor(l10n, failure.error) ?? l10n.errorGeneric)
            : l10n.errorGeneric;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.14),
          borderRadius: context.radii.mdAll,
          border: Border.all(color: c.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: c.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.playerUnplayable, style: context.type.label),
                  Text(detail, style: context.type.bodySmall.copyWith(color: c.textPrimary)),
                ],
              ),
            ),
            if (failure != null)
              IconButton(
                tooltip: l10n.actionClose,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => ref.read(playbackFailureProvider.notifier).dismiss(),
              ),
          ],
        ),
      ),
    );
  }
}

enum _MoreAction { addToPlaylist, openExternal, uploader, copyLink, removeDownload }

/// Like · add to playlist · download (when eligible) · more (open on
/// provider, uploader page, copy link).
class NowPlayingActions extends ConsumerWidget {
  const NowPlayingActions({super.key, required this.track, this.extra = const []});

  final Track track;

  /// Extra controls appended to the row (lyrics/queue toggles, timer, …).
  final List<Widget> extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = TrackActions(context, ref);
    final liked = ref.watch(favoriteIdsProvider.select((v) => v.value?.contains(track.id) ?? false));
    final eligibility = ref.watch(downloadEligibilityProvider(track)).value;
    final external = actions.externalUri(track);
    final share = actions.shareUri(track);
    final uploader = uploaderUriOf(track);
    final provider = sourceDisplayName(ref, track.sourceId);
    final downloaded = eligibility?.kind == DownloadEligibilityKind.alreadyDownloaded;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        IconButton(
          tooltip: liked ? l10n.playerUnlike : l10n.playerLike,
          isSelected: liked,
          icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded),
          onPressed: () => actions.setFavorite(track, !liked),
        ),
        IconButton(
          tooltip: l10n.playerAddToPlaylist,
          icon: const Icon(Icons.playlist_add_rounded),
          onPressed: () => actions.addToPlaylist([track]),
        ),
        if (eligibility?.canDownload ?? false)
          IconButton(
            tooltip: l10n.playerDownload,
            icon: const Icon(Icons.download_rounded),
            onPressed: () => actions.download(track),
          ),
        if (downloaded)
          Tooltip(
            message: l10n.playerDownloaded,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.download_done_rounded, color: context.colors.success),
            ),
          ),
        ...extra,
        PopupMenuButton<_MoreAction>(
          tooltip: l10n.playerMore,
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (a) {
            switch (a) {
              case _MoreAction.addToPlaylist:
                actions.addToPlaylist([track]);
              case _MoreAction.openExternal:
                actions.openExternally(track);
              case _MoreAction.uploader:
                actions.openLink(uploader!);
              case _MoreAction.copyLink:
                actions.copyLink(track);
              case _MoreAction.removeDownload:
                actions.removeDownload(track);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: _MoreAction.addToPlaylist, child: Text(l10n.playerAddToPlaylist)),
            if (external != null) PopupMenuItem(value: _MoreAction.openExternal, child: Text(l10n.playerOpenOn(provider))),
            if (uploader != null) PopupMenuItem(value: _MoreAction.uploader, child: Text(l10n.playerUploaderOn(provider))),
            if (share != null) PopupMenuItem(value: _MoreAction.copyLink, child: Text(l10n.playerCopyLink)),
            if (downloaded) PopupMenuItem(value: _MoreAction.removeDownload, child: Text(l10n.shellMenuRemoveDownload)),
          ],
        ),
      ],
    );
  }
}
