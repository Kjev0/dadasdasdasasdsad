import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/track.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/artwork/artwork_image.dart';
import '../../../widgets/chips/badges.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/dialogs/sheet.dart';
import '../../../widgets/feedback/messages.dart';
import '../../../widgets/tracks/track_format.dart';
import '../shared/labels.dart';
import 'tag_editor_dialog.dart';

/// Opens the details sheet (format, bitrate, sample rate, file, source)
/// with "Edit tags" for local files.
Future<void> showTrackDetails(BuildContext context, Track track) =>
    showFermataSheet<void>(context, builder: (_) => TrackDetailsSheet(track: track));

/// Technical details of a track.
class TrackDetailsSheet extends ConsumerWidget {
  const TrackDetailsSheet({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final f = track.format;
    final rows = <(String, String)>[
      if (track.album != null) (l10n.libraryTagAlbum, track.album!),
      if (track.albumArtist != null) (l10n.libraryTagAlbumArtist, track.albumArtist!),
      if (track.year != null) (l10n.libraryTagYear, '${track.year}'),
      if (track.genre != null) (l10n.libraryTagGenre, track.genre!),
      if (track.trackNumber != null)
        (l10n.libraryTagTrackNumber, track.discNumber != null ? '${track.discNumber}-${track.trackNumber}' : '${track.trackNumber}'),
      if (track.duration != null) (l10n.libraryDetailDuration, formatDuration(track.duration!)),
      if (f?.codec != null) (l10n.libraryDetailFormat, f!.codec!.toUpperCase()),
      if (f?.bitrateKbps != null) (l10n.libraryDetailBitrate, l10n.libraryKbps(f!.bitrateKbps!)),
      if (f?.sampleRateHz != null)
        (
          l10n.libraryDetailSampleRate,
          l10n.libraryKhz(NumberFormat.decimalPatternDigits(locale: localeNameOf(context), decimalDigits: 1).format(f!.sampleRateHz! / 1000)),
        ),
      if (f?.bitsPerSample != null) (l10n.libraryDetailBitDepth, l10n.libraryBits(f!.bitsPerSample!)),
      if (f?.channels != null) (l10n.libraryDetailChannels, '${f!.channels}'),
      if (f?.fileSizeBytes != null) (l10n.libraryDetailSize, formatBytes(context, f!.fileSizeBytes!)),
      if (track.isrc != null) ('ISRC', track.isrc!),
      if (track.replayGainTrackDb != null) (l10n.libraryDetailReplayGain, '${track.replayGainTrackDb!.toStringAsFixed(2)} dB'),
      (l10n.libraryDetailSource, track.isLocal ? l10n.libraryLocalFiles : sourceDisplayName(ref, track.sourceId)),
      (l10n.libraryDetailOffline, offlineRightsLabel(l10n, track.availability.offline)),
      if (track.localPath != null) (l10n.libraryDetailFile, track.localPath!),
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Row(
            children: [
              SizedBox.square(dimension: 56, child: ArtworkImage(uri: track.artworkUrl, size: 56)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, style: context.type.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(track.artistLine, style: context.type.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 120, child: Text(label, style: context.type.bodySmall)),
                  Expanded(child: SelectableText(value, style: context.type.body)),
                ],
              ),
            ),
          if (track.isLocal) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FermataButton(
                label: l10n.libraryEditTags,
                icon: Icons.edit_rounded,
                variant: FermataButtonVariant.secondary,
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final edited = await TagEditorDialog.show(context, track);
                  if (edited && nav.mounted) nav.pop();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
