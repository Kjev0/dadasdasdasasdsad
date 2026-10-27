import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/track.dart';
import '../../../actions/track_actions.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import 'track_helpers.dart';

/// "Download" for a collection: enqueues the tracks whose provider permits
/// user-initiated downloads (Audius, Jamendo) and reports the rest. Hidden
/// when no track can ever be downloaded (SoundCloud, Deezer, Spotify,
/// YouTube, local files).
class CollectionDownloadButton extends ConsumerStatefulWidget {
  const CollectionDownloadButton({super.key, required this.tracks, this.origin});

  final List<Track> tracks;
  final String? origin;

  @override
  ConsumerState<CollectionDownloadButton> createState() => _CollectionDownloadButtonState();
}

class _CollectionDownloadButtonState extends ConsumerState<CollectionDownloadButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (!anyDownloadable(widget.tracks)) return const SizedBox.shrink();
    return FermataButton(
      label: context.l10n.pagesDownloadEligible,
      icon: Icons.download_rounded,
      variant: FermataButtonVariant.secondary,
      busy: _busy,
      onPressed: () async {
        setState(() => _busy = true);
        await TrackActions(context, ref).downloadAll(widget.tracks, origin: widget.origin);
        if (mounted) setState(() => _busy = false);
      },
    );
  }
}
