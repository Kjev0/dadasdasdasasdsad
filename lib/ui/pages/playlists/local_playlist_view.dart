import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/track.dart';
import '../../actions/track_actions.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/feedback/toast.dart';
import '../../widgets/tracks/track_list_view.dart';
import '../../widgets/tracks/track_menu.dart';
import '../../widgets/tracks/track_tile.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/track_helpers.dart';
import 'alternatives_sheet.dart';
import 'playlist_header.dart';
import 'playlist_providers.dart';

/// A library playlist: header, reorderable track list (local playlists),
/// bulk selection (remove, queue, add to playlist, download eligible),
/// per-track availability and "find alternatives" for tracks that can't
/// play inside Fermata.
class LocalPlaylistView extends ConsumerStatefulWidget {
  const LocalPlaylistView({super.key, required this.data});

  final LocalPlaylistData data;

  @override
  ConsumerState<LocalPlaylistView> createState() => _LocalPlaylistViewState();
}

class _LocalPlaylistViewState extends ConsumerState<LocalPlaylistView> {
  final _selection = TrackSelectionController();

  /// Order shown while a move is being saved (dropped when fresh data
  /// arrives).
  List<PlaylistEntry>? _optimistic;
  LocalPlaylistData? _optimisticFor;

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Playlist get playlist => widget.data.playlist;

  bool get _editable => playlist.kind == PlaylistKind.local;

  List<PlaylistEntry> get _entries =>
      (_optimistic != null && identical(_optimisticFor, widget.data)) ? _optimistic! : widget.data.entries;

  /// [newIndex] is already adjusted for the removed item (`onReorderItem`).
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final entries = [..._entries];
    if (oldIndex == newIndex) return;
    final from = entries[oldIndex].position;
    final to = entries[newIndex].position;
    final moved = entries.removeAt(oldIndex);
    entries.insert(newIndex, moved);
    setState(() {
      _optimistic = entries;
      _optimisticFor = widget.data;
    });
    try {
      await ref.read(playlistRepositoryProvider).move(playlist.id, from, to);
    } catch (e) {
      if (!mounted) return;
      setState(() => _optimistic = null);
      showFermataToast(context, errorMessageFor(context.l10n, e) ?? context.l10n.errorGeneric, isError: true);
    }
  }

  Future<void> _removeSelected(List<Track> selected) async {
    final l10n = context.l10n;
    try {
      await ref.read(playlistRepositoryProvider).removeTracks(playlist.id, [for (final t in selected) t.id]);
      if (mounted) showFermataToast(context, l10n.playlistRemovedTracks(selected.length), icon: Icons.remove_circle_outline_rounded);
    } catch (e) {
      if (mounted) showFermataToast(context, errorMessageFor(l10n, e) ?? l10n.errorGeneric, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final links = ref.watch(playlistLinksProvider(playlist.id)).value ?? const {};
    final entries = _entries;
    final tracks = [for (final e in entries) e.track];
    bool canPlay(Track t) => playableOrLinked(t, links);
    final origin = 'playlist:${playlist.id}';
    void play({int start = 0, bool shuffle = false}) =>
        playCollection(context, ref, tracks, startIndex: start, shuffle: shuffle, origin: origin, originLabel: playlist.name, canPlay: canPlay);

    final header = LocalPlaylistHeader(
      data: widget.data,
      canPlay: tracks.any(canPlay),
      onPlay: () => play(),
      onShuffle: () => play(shuffle: true),
    );
    final insets = pageInsets(context);
    final rowHeight = context.rowExtent;

    Widget row(int i, {required bool reorderable}) {
      final entry = entries[i];
      final t = entry.track;
      final playable = isPlayableInApp(t);
      final linked = links[t.id];
      final via = linked?.where((l) => isPlayableInApp(l.$1)).firstOrNull;
      return Padding(
        key: ValueKey('entry-${entry.position}-${t.id}'),
        padding: EdgeInsets.symmetric(horizontal: insets.left),
        child: TrackTile(
          track: t,
          index: i + 1,
          showAlbum: true,
          showSource: !t.isLocal,
          playContext: TrackPlayContext(tracks: tracks, index: i, origin: origin, originLabel: playlist.name),
          // Imported tracks with a linked match play through the link.
          onTap: !playable && via != null ? () => play(start: i) : null,
          selectionMode: _selection.active,
          selected: _selection.isSelected(t.id),
          onSelectedChanged: (v) => _selection.set(t.id, v),
          onLongPress: _selection.active ? null : () => _selection.start(t.id),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!playable)
                IconButton(
                  key: ValueKey('alternatives-${t.id}'),
                  tooltip: via != null ? l10n.playlistPlaysVia(sourceDisplayName(ref, via.$1.sourceId)) : l10n.alternativesFind,
                  icon: Icon(via != null ? Icons.link_rounded : Icons.find_replace_rounded, size: 20, color: via != null ? context.colors.accentText : null),
                  onPressed: () => showAlternativesSheet(context, t),
                ),
              if (reorderable)
                ReorderableDragStartListener(
                  index: i,
                  child: Tooltip(
                    message: l10n.playerQueueReorder,
                    child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_indicator_rounded, size: 20)),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final reorderable = _editable && !_selection.active && entries.length > 1;
    Widget list;
    if (entries.isEmpty) {
      list = ListView(
        children: [
          header,
          EmptyState(
            icon: playlist.kind == PlaylistKind.smart ? Icons.rule_rounded : Icons.queue_music_rounded,
            title: playlist.kind == PlaylistKind.smart ? l10n.playlistSmartEmpty : l10n.playlistEmpty,
            message: playlist.kind == PlaylistKind.smart ? l10n.playlistSmartEmptyHint : l10n.playlistEmptyHint,
            compact: true,
          ),
        ],
      );
    } else if (reorderable) {
      list = ReorderableListView.builder(
        header: header,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(bottom: 24),
        itemExtent: rowHeight,
        itemCount: entries.length,
        onReorderItem: _onReorder,
        itemBuilder: (context, i) => row(i, reorderable: true),
      );
    } else {
      list = ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: entries.length + 1,
        itemBuilder: (context, i) => i == 0 ? header : SizedBox(height: rowHeight, child: row(i - 1, reorderable: false)),
      );
    }

    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) => Column(
        children: [
          if (_selection.active)
            TrackSelectionBar(
              selection: _selection,
              tracks: tracks,
              origin: origin,
              extraActions: [
                if (_editable)
                  TrackBulkAction(label: l10n.playlistRemoveFromPlaylist, icon: Icons.playlist_remove_rounded, onSelected: _removeSelected),
                TrackBulkAction(
                  label: l10n.shellMenuPlayNext,
                  icon: Icons.playlist_play_rounded,
                  onSelected: (s) => TrackActions(context, ref).playNext(s, origin: origin),
                ),
              ],
            ),
          Expanded(child: list),
        ],
      ),
    );
  }
}
