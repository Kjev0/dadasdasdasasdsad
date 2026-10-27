import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/context_ext.dart';
import '../../widgets/controls/segmented_tabs.dart';
import 'collections_tabs.dart';
import 'folders/folders_tab.dart';
import 'shared/page_layout.dart';
import 'tracks/library_query.dart';
import 'tracks/tracks_tab.dart';

/// Library tabs (also accepted as `/library?tab=<id>`).
enum LibraryTab {
  tracks,
  albums,
  artists,
  folders;

  /// Parses a `tab` query value; `downloaded` opens Tracks with the
  /// "Downloaded" quick filter.
  static LibraryTab parse(String? raw) => switch (raw) {
        'albums' => LibraryTab.albums,
        'artists' => LibraryTab.artists,
        'folders' => LibraryTab.folders,
        _ => LibraryTab.tracks,
      };
}

/// Library: Tracks (sort, filters, tag editor, details), Albums, Artists
/// and Folders (manage music folders, scans, missing files, duplicates).
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key, this.tab});

  /// Initial tab id (`tracks`, `albums`, `artists`, `folders`, `downloaded`).
  final String? tab;

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  late LibraryTab _tab = LibraryTab.parse(widget.tab);

  @override
  void initState() {
    super.initState();
    _applyQuickFilter(widget.tab);
  }

  @override
  void didUpdateWidget(LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) {
      setState(() => _tab = LibraryTab.parse(widget.tab));
      _applyQuickFilter(widget.tab);
    }
  }

  void _applyQuickFilter(String? tab) {
    if (tab != 'downloaded') return;
    // After the first frame: providers must not change during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(libraryFiltersProvider.notifier).update((f) => f.copyWith(downloadedOnly: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tabs = SegmentedTabs<LibraryTab>(
      selected: _tab,
      onChanged: (t) => setState(() => _tab = t),
      tabs: [
        SegmentedTab(LibraryTab.tracks, l10n.libraryTabTracks, icon: Icons.music_note_rounded),
        SegmentedTab(LibraryTab.albums, l10n.libraryTabAlbums, icon: Icons.album_rounded),
        SegmentedTab(LibraryTab.artists, l10n.libraryTabArtists, icon: Icons.person_rounded),
        SegmentedTab(LibraryTab.folders, l10n.libraryTabFolders, icon: Icons.folder_rounded),
      ],
    );
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: l10n.navLibrary, padding: pageInsets(context).copyWith(top: isCompactWidth(context) ? 12 : 24, bottom: 8)),
          Padding(padding: pageInsets(context), child: Align(alignment: Alignment.centerLeft, child: tabs)),
          Expanded(
            child: switch (_tab) {
              LibraryTab.tracks => const LibraryTracksTab(),
              LibraryTab.albums => const LibraryAlbumsTab(),
              LibraryTab.artists => const LibraryArtistsTab(),
              LibraryTab.folders => const LibraryFoldersTab(),
            },
          ),
        ],
      ),
    );
  }
}
