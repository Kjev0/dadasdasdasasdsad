import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/track.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/tracks/track_list_view.dart';
import '../../../widgets/tracks/track_menu.dart';
import '../../../widgets/tracks/track_tile.dart';
import 'track_details.dart';

/// Virtualized track list like `TrackListView`, plus a per-row details
/// button (format details, tag editor for local files) and an optional
/// [header] / [footer]. Long-press enters selection mode with the shared
/// bulk-action bar.
class LibraryTrackList extends ConsumerStatefulWidget {
  const LibraryTrackList({
    super.key,
    required this.tracks,
    required this.origin,
    this.originLabel,
    this.header,
    this.footer,
    this.extraBulkActions = const [],
    this.padding = EdgeInsets.zero,
    this.showSource = false,
  });

  final List<Track> tracks;
  final String origin;
  final String? originLabel;
  final Widget? header;
  final Widget? footer;
  final List<TrackBulkAction> extraBulkActions;
  final EdgeInsetsGeometry padding;
  final bool showSource;

  @override
  ConsumerState<LibraryTrackList> createState() => _LibraryTrackListState();
}

class _LibraryTrackListState extends ConsumerState<LibraryTrackList> {
  final _selection = TrackSelectionController();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rowHeight = context.rowExtent;
    final tracks = widget.tracks;
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) => CustomScrollView(
        slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header),
          if (_selection.active)
            SliverPersistentHeader(
              pinned: true,
              delegate: _BarDelegate(
                TrackSelectionBar(
                  selection: _selection,
                  tracks: tracks,
                  origin: widget.origin,
                  extraActions: widget.extraBulkActions,
                ),
              ),
            ),
          SliverPadding(
            padding: widget.padding,
            sliver: SliverFixedExtentList(
              itemExtent: rowHeight,
              delegate: SliverChildBuilderDelegate(
                childCount: tracks.length,
                (context, i) {
                  final t = tracks[i];
                  return TrackTile(
                    key: ValueKey('lib-${t.id}#$i'),
                    track: t,
                    showAlbum: true,
                    showSource: widget.showSource,
                    playContext: TrackPlayContext(tracks: tracks, index: i, origin: widget.origin, originLabel: widget.originLabel),
                    selectionMode: _selection.active,
                    selected: _selection.isSelected(t.id),
                    onSelectedChanged: (v) => _selection.set(t.id, v),
                    onLongPress: _selection.active ? null : () => _selection.start(t.id),
                    trailing: IconButton(
                      tooltip: l10n.libraryTrackDetails,
                      icon: const Icon(Icons.info_outline_rounded, size: 20),
                      onPressed: () => showTrackDetails(context, t),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.footer != null) SliverToBoxAdapter(child: widget.footer),
        ],
      ),
    );
  }
}

class _BarDelegate extends SliverPersistentHeaderDelegate {
  const _BarDelegate(this.child);

  final Widget child;

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(_BarDelegate oldDelegate) => true;
}
