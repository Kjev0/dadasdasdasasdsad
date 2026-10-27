import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/track.dart';
import '../../../core/sources/source_ids.dart';
import '../../design/context_ext.dart';
import '../feedback/messages.dart';

/// Display name for a source id: the registered source's `displayName`,
/// otherwise a built-in fallback (never a logo).
String sourceDisplayName(WidgetRef ref, String sourceId) {
  final source = ref.read(sourceRegistryProvider).byId(sourceId);
  if (source != null) return source.displayName;
  return builtInSourceName(sourceId);
}

/// Built-in provider names for well-known ids.
String builtInSourceName(String sourceId) => switch (sourceId) {
      SourceIds.soundcloud => 'SoundCloud',
      SourceIds.audius => 'Audius',
      SourceIds.deezer => 'Deezer',
      SourceIds.spotify => 'Spotify',
      SourceIds.youtube => 'YouTube Music',
      SourceIds.jamendo => 'Jamendo',
      SourceIds.local => 'Local',
      _ => sourceId,
    };

/// Small text chip naming a provider ("SoundCloud"). Text only — provider
/// logos are never shown. Local files read "Local file".
class SourceChip extends ConsumerWidget {
  const SourceChip({super.key, required this.sourceId, this.dense = false});

  final String sourceId;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final label = sourceId == SourceIds.local ? context.l10n.shellFileYourFile : sourceDisplayName(ref, sourceId);
    return _Pill(label: label, color: c.textSecondary, dense: dense);
  }
}

/// The badge categories: the four offline categories plus preview,
/// external-only, downloaded and unavailable.
enum AvailabilityBadgeKind { userOwned, downloadable, streamOnly, unavailableOffline, preview, external, downloaded, unavailable }

/// Availability badge with icon + label.
class AvailabilityBadge extends ConsumerWidget {
  const AvailabilityBadge({super.key, required this.kind, this.sourceId, this.reason, this.dense = false});

  /// Badge for the most important state of [track] (unavailable > external >
  /// preview > downloaded > offline category).
  factory AvailabilityBadge.forTrack(Track track, {Key? key, bool downloaded = false, bool dense = false}) =>
      AvailabilityBadge(
        key: key,
        kind: primaryKind(track, downloaded: downloaded),
        sourceId: track.sourceId,
        reason: track.availability.reason,
        dense: dense,
      );

  final AvailabilityBadgeKind kind;

  /// Needed for [AvailabilityBadgeKind.external] ("Plays on Spotify").
  final String? sourceId;

  /// `AvailabilityReason` shown as tooltip for unavailable tracks.
  final String? reason;
  final bool dense;

  /// The most relevant badge for a track.
  static AvailabilityBadgeKind primaryKind(Track track, {bool downloaded = false}) {
    final a = track.availability;
    if (a.playback == PlaybackRights.unavailable) return AvailabilityBadgeKind.unavailable;
    if (a.playback == PlaybackRights.externalOnly) return AvailabilityBadgeKind.external;
    if (a.playback == PlaybackRights.preview) return AvailabilityBadgeKind.preview;
    if (downloaded) return AvailabilityBadgeKind.downloaded;
    return offlineKind(a.offline);
  }

  /// Badge for one of the four offline categories.
  static AvailabilityBadgeKind offlineKind(OfflineRights rights) => switch (rights) {
        OfflineRights.userOwned => AvailabilityBadgeKind.userOwned,
        OfflineRights.downloadable => AvailabilityBadgeKind.downloadable,
        OfflineRights.streamOnly => AvailabilityBadgeKind.streamOnly,
        OfflineRights.unavailable => AvailabilityBadgeKind.unavailableOffline,
      };

  /// Whether a compact track row should show a badge for [kind] (the
  /// ordinary "stream only"/offline categories are omitted to reduce noise).
  static bool isNotable(AvailabilityBadgeKind kind) => switch (kind) {
        AvailabilityBadgeKind.unavailable ||
        AvailabilityBadgeKind.external ||
        AvailabilityBadgeKind.preview ||
        AvailabilityBadgeKind.downloaded =>
          true,
        _ => false,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = context.l10n;
    final (IconData icon, String label, Color color) = switch (kind) {
      AvailabilityBadgeKind.userOwned => (Icons.folder_rounded, l10n.offlineUserOwned, c.accentText),
      AvailabilityBadgeKind.downloadable => (Icons.download_rounded, l10n.offlineDownloadable, c.textSecondary),
      AvailabilityBadgeKind.streamOnly => (Icons.wifi_rounded, l10n.offlineStreamOnly, c.textSecondary),
      AvailabilityBadgeKind.unavailableOffline => (Icons.cloud_off_rounded, l10n.offlineUnavailable, c.textSecondary),
      AvailabilityBadgeKind.preview => (Icons.timelapse_rounded, l10n.shellBadgePreview, c.warning),
      AvailabilityBadgeKind.external => (
          Icons.open_in_new_rounded,
          l10n.shellBadgeExternal(sourceId == null ? '' : sourceDisplayName(ref, sourceId!)),
          c.textSecondary,
        ),
      AvailabilityBadgeKind.downloaded => (Icons.download_done_rounded, l10n.shellBadgeDownloaded, c.success),
      AvailabilityBadgeKind.unavailable => (Icons.block_rounded, l10n.shellBadgeUnavailable, c.danger),
    };
    final pill = _Pill(label: label, color: color, icon: icon, dense: dense);
    if (kind == AvailabilityBadgeKind.unavailable && reason != null) {
      return Tooltip(message: availabilityReasonText(l10n, reason), child: pill);
    }
    return pill;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon, this.dense = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = context.type.caption.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: dense ? 11 : 12);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 1 : 3),
      decoration: BoxDecoration(
        borderRadius: context.radii.xsAll,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
