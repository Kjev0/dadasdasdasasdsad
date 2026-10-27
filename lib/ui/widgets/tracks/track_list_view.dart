import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/track.dart';
import '../../actions/track_actions.dart';
import '../../design/context_ext.dart';
import 'track_menu.dart';
import 'track_tile.dart';

/// Selection state shared by a track list and its bulk-action bar.
class TrackSelectionController extends ChangeNotifier {
  final Set<String> _ids = {};
  bool _active = false;

  /// Whether selection mode is on (taps toggle instead of play).
  bool get active => _active;
  Set<String> get selectedIds => Set.unmodifiable(_ids);
  int get count => _ids.length;

  bool isSelected(String trackId) => _ids.contains(trackId);

  void start([String? firstId]) {
    _active = true;
    if (firstId != null) _ids.add(firstId);
    notifyListeners();
  }

  void toggle(String trackId) {
    _ids.contains(trackId) ? _ids.remove(trackId) : _ids.add(trackId);
    notifyListeners();
  }

  void set(String trackId, bool selected) {
    selected ? _ids.add(trackId) : _ids.remove(trackId);
    notifyListeners();
  }

  void selectAll(Iterable<Track> tracks) {
    _ids.addAll(tracks.map((t) => t.id));
    notifyListeners();
  }

  void clear({bool exit = true}) {
    _ids.clear();
    if (exit) _active = false;
    notifyListeners();
  }

  List<Track> selectedFrom(List<Track> tracks) => [for (final t in tracks) if (_ids.contains(t.id)) t];
}

/// A bulk action shown in the selection bar.
class TrackBulkAction {
  const TrackBulkAction({required this.label, required this.icon, required this.onSelected});

  final String label;
  final IconData icon;
  final Future<void> Function(List<Track> selected) onSelected;
}

/// Virtualized track list (fixed row extent) with an optional [header] and
/// a selection mode for bulk actions (long-press a row or call
/// `selection.start()`). Default bulk actions: play, add to queue, add to
/// playlist, download eligible; pages can add more via [extraBulkActions].
class TrackListView extends ConsumerStatefulWidget {
  const TrackListView({
    super.key,
    required this.tracks,
    this.origin,
    this.originLabel,
    this.header,
    this.showArtwork = true,
    this.showAlbum = false,
    this.showSource = false,
    this.showIndex = false,
    this.selectable = true,
    this.selection,
    this.extraBulkActions = const [],
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.controller,
    this.footer,
  });

  final List<Track> tracks;

  /// Queue origin for plays from this list (e.g. `playlist:<id>`).
  final String? origin;
  final String? originLabel;
  final Widget? header;
  final Widget? footer;
  final bool showArtwork;
  final bool showAlbum;
  final bool showSource;
  final bool showIndex;
  final bool selectable;
  final TrackSelectionController? selection;
  final List<TrackBulkAction> extraBulkActions;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  ConsumerState<TrackListView> createState() => _TrackListViewState();
}

class _TrackListViewState extends ConsumerState<TrackListView> {
  TrackSelectionController? _own;

  TrackSelectionController get _selection => widget.selection ?? (_own ??= TrackSelectionController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowHeight = context.rowExtent;
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) {
        final sel = _selection;
        return CustomScrollView(
          controller: widget.controller,
          slivers: [
            if (widget.header != null) SliverToBoxAdapter(child: widget.header),
            if (sel.active)
              SliverPersistentHeader(
                pinned: true,
                delegate: _BulkBarDelegate(
                  child: TrackSelectionBar(
                    selection: sel,
                    tracks: widget.tracks,
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
                  childCount: widget.tracks.length,
                  (context, i) {
                    final t = widget.tracks[i];
                    return TrackTile(
                      key: ValueKey('${t.id}#$i'),
                      track: t,
                      index: i + 1,
                      showArtwork: widget.showArtwork && !widget.showIndex,
                      showAlbum: widget.showAlbum,
                      showSource: widget.showSource,
                      playContext: TrackPlayContext(
                        tracks: widget.tracks,
                        index: i,
                        origin: widget.origin,
                        originLabel: widget.originLabel,
                      ),
                      selectionMode: sel.active,
                      selected: sel.isSelected(t.id),
                      onSelectedChanged: (v) => sel.set(t.id, v),
                      onLongPress: widget.selectable && !sel.active ? () => sel.start(t.id) : null,
                    );
                  },
                ),
              ),
            ),
            if (widget.footer != null) SliverToBoxAdapter(child: widget.footer),
          ],
        );
      },
    );
  }
}

/// Bar shown in selection mode: count, select all / clear, bulk actions.
class TrackSelectionBar extends ConsumerWidget {
  const TrackSelectionBar({
    super.key,
    required this.selection,
    required this.tracks,
    this.origin,
    this.extraActions = const [],
  });

  final TrackSelectionController selection;
  final List<Track> tracks;
  final String? origin;
  final List<TrackBulkAction> extraActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = context.l10n;
    final selected = selection.selectedFrom(tracks);
    final actions = TrackActions(context, ref);
    final all = [
      TrackBulkAction(label: l10n.shellMenuPlay, icon: Icons.play_arrow_rounded, onSelected: (s) => actions.play(s, origin: origin)),
      TrackBulkAction(label: l10n.shellMenuAddToQueue, icon: Icons.queue_music_rounded, onSelected: (s) => actions.addToQueue(s, origin: origin)),
      TrackBulkAction(label: l10n.shellMenuAddToPlaylist, icon: Icons.playlist_add_rounded, onSelected: (s) => actions.addToPlaylist(s)),
      if (selected.any(TrackActions.policyAllowsDownload))
        TrackBulkAction(label: l10n.shellMenuDownload, icon: Icons.download_rounded, onSelected: (s) => actions.downloadAll(s, origin: origin)),
      ...extraActions,
    ];
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        border: Border(bottom: BorderSide(color: c.outlineSubtle)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.shellClearSelection,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => selection.clear(),
          ),
          Text(l10n.shellSelectedCount(selection.count), style: context.type.label),
          const SizedBox(width: 8),
          TextButton(onPressed: () => selection.selectAll(tracks), child: Text(l10n.shellSelectAll)),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final a in all)
                      IconButton(
                        tooltip: a.label,
                        icon: Icon(a.icon),
                        onPressed: selected.isEmpty
                            ? null
                            : () async {
                                await a.onSelected(selected);
                                selection.clear();
                              },
                      ),
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

class _BulkBarDelegate extends SliverPersistentHeaderDelegate {
  const _BulkBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(_BulkBarDelegate oldDelegate) => true;
}
