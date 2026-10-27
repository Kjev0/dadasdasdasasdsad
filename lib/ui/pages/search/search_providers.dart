import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/library.dart';
import '../../../core/errors.dart';
import '../../../core/models/library.dart';
import '../../../core/models/track.dart';
import '../../widgets/util/async_utils.dart';
import '../library/shared/revisions.dart';
import 'share_links.dart';

final _log = Logger('ui.pages.search');

/// Recent searches (empty when `privacy.saveSearchHistory` is off).
final recentSearchesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) async {
    watchLibrary(ref, LibraryTopic.searches);
    if (!ref.watch(settingsProvider.select((s) => s.privacy.saveSearchHistory))) return const [];
    return ref.watch(searchHistoryProvider).recent();
  },
  retry: noRetry,
);

class _LastRecorded extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

/// The query most recently saved (avoids rewriting it on every tap).
final _lastRecordedProvider = NotifierProvider<_LastRecorded, String?>(_LastRecorded.new);

/// Saves [query] as a recent search when search history is enabled.
Future<void> recordSearch(WidgetRef ref, String query) async {
  final q = query.trim();
  if (q.isEmpty || !ref.read(settingsProvider).privacy.saveSearchHistory) return;
  if (ref.read(_lastRecordedProvider) == q) return;
  ref.read(_lastRecordedProvider.notifier).set(q);
  try {
    await ref.read(searchHistoryProvider).add(q);
    ref.invalidate(recentSearchesProvider);
  } catch (e) {
    _log.fine('Could not save search: $e');
  }
}

/// Forgets the "already saved" marker (after clearing the history).
void resetRecordedSearch(WidgetRef ref) => ref.read(_lastRecordedProvider.notifier).set(null);

/// Suggestions while typing: matching recent searches and library tracks.
@immutable
class SearchSuggestions {
  const SearchSuggestions({required this.recent, required this.tracks});

  final List<String> recent;
  final List<Track> tracks;

  bool get isEmpty => recent.isEmpty && tracks.isEmpty;
}

final searchSuggestionsProvider = FutureProvider.autoDispose.family<SearchSuggestions, String>(
  (ref, query) async {
    final q = query.trim().toLowerCase();
    final recent = await ref.watch(recentSearchesProvider.future);
    final matches = [for (final r in recent) if (r.toLowerCase().contains(q) && r.toLowerCase() != q) r].take(4).toList();
    var tracks = const <Track>[];
    if (q.length >= 2) {
      try {
        tracks = await ref.watch(trackRepositoryProvider).query(TrackQuery(text: query.trim(), limit: 5));
      } catch (e) {
        _log.fine('Library suggestions failed: $e');
      }
    }
    return SearchSuggestions(recent: matches, tracks: tracks);
  },
  retry: noRetry,
);

/// The track a pasted track link points to (resolved by its source).
final sharedTrackProvider = FutureProvider.autoDispose.family<Track?, ShareLink>(
  (ref, link) async {
    final source = ref.watch(sourceRegistryProvider).byId(link.sourceId);
    if (source == null) throw UnsupportedSourceOperation(link.sourceId, 'getTrack', 'Source not available');
    final token = providerCancelToken(ref);
    return source.getTrack(link.id, cancel: token);
  },
  retry: noRetry,
);
