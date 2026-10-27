import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/discovery.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/track.dart';
import '../../widgets/util/async_utils.dart';
import '../library/shared/revisions.dart';

/// Genres from the recommendation service (provider + library genres).
final exploreGenresProvider = FutureProvider.autoDispose<List<String>>(
  (ref) async {
    watchSources(ref);
    return ref.watch(recommendationsProvider).genres(cancel: providerCancelToken(ref));
  },
  retry: noRetry,
);

/// New album releases.
final exploreReleasesProvider = FutureProvider.autoDispose<List<Album>>(
  (ref) async {
    watchSources(ref);
    return ref.watch(recommendationsProvider).newReleases(cancel: providerCancelToken(ref));
  },
  retry: noRetry,
);

/// Trending tracks (the service's trending shelf, silo-safe and playable
/// first).
final exploreTrendingProvider = FutureProvider.autoDispose<List<Track>>(
  (ref) async {
    watchSources(ref);
    final shelves = await ref.watch(recommendationsProvider).homeShelves(cancel: providerCancelToken(ref));
    return [for (final s in shelves) if (s.kind == ShelfKind.trending) ...s.tracks];
  },
  retry: noRetry,
);

/// Playable tracks for a genre.
final genreTracksProvider = FutureProvider.autoDispose.family<List<Track>, String>(
  (ref, genre) async => ref.watch(recommendationsProvider).genreTracks(genre, cancel: providerCancelToken(ref)),
  retry: noRetry,
);

/// Playable tracks for a mood (by `MoodCategory.id`).
final moodTracksProvider = FutureProvider.autoDispose.family<List<Track>, String>(
  (ref, moodId) async {
    final service = ref.watch(recommendationsProvider);
    final mood = service.moods.firstWhere((m) => m.id == moodId);
    return service.moodTracks(mood, cancel: providerCancelToken(ref));
  },
  retry: noRetry,
);
