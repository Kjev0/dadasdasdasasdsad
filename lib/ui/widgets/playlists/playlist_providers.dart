import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/library.dart';
import '../../../core/models/catalog.dart';
import '../util/async_utils.dart';

/// All library playlists (local, smart, imported); refetches when playlists
/// change.
final userPlaylistsProvider = FutureProvider<List<Playlist>>(
  (ref) async {
    ref.watch(libraryRevisionProvider(LibraryTopic.playlists));
    return ref.watch(playlistRepositoryProvider).playlists();
  },
  retry: noRetry,
);

/// Playlists tracks can be added to by hand (not smart / remote).
final editablePlaylistsProvider = FutureProvider<List<Playlist>>(
  (ref) async {
    final all = await ref.watch(userPlaylistsProvider.future);
    return [for (final p in all) if (p.kind == PlaylistKind.local) p];
  },
  retry: noRetry,
);
