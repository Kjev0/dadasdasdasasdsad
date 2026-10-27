import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/contracts/library.dart';
import '../../../../core/models/library.dart';
import '../../../../core/models/track.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../widgets/util/async_utils.dart';
import '../shared/revisions.dart';

/// Sort options offered by the Library (the subset of [TrackSortField] the
/// spec lists).
const librarySortFields = [
  TrackSortField.title,
  TrackSortField.artist,
  TrackSortField.album,
  TrackSortField.year,
  TrackSortField.duration,
  TrackSortField.dateAdded,
  TrackSortField.playCount,
];

/// Localized name of a sort field.
String sortFieldLabel(AppLocalizations l10n, TrackSortField f) => switch (f) {
      TrackSortField.title => l10n.librarySortTitle,
      TrackSortField.artist => l10n.librarySortArtist,
      TrackSortField.album => l10n.librarySortAlbum,
      TrackSortField.year => l10n.librarySortYear,
      TrackSortField.duration => l10n.librarySortDuration,
      TrackSortField.dateAdded => l10n.librarySortDateAdded,
      TrackSortField.playCount => l10n.librarySortPlayCount,
      TrackSortField.lastPlayed => l10n.librarySortLastPlayed,
      TrackSortField.genre => l10n.librarySortGenre,
    };

/// Sort + filters of the Library's track list.
@immutable
class LibraryFilters {
  const LibraryFilters({
    this.text = '',
    this.sort = TrackSortField.dateAdded,
    this.descending = true,
    this.sources,
    this.downloadedOnly = false,
    this.localFilesOnly = false,
    this.offlineOnly = false,
    this.favoritesOnly = false,
    this.genre,
    this.minYear,
    this.maxYear,
    this.minDuration,
    this.maxDuration,
  });

  final String text;
  final TrackSortField sort;
  final bool descending;

  /// Null = every source.
  final Set<String>? sources;
  final bool downloadedOnly;
  final bool localFilesOnly;
  final bool offlineOnly;
  final bool favoritesOnly;
  final String? genre;
  final int? minYear;
  final int? maxYear;
  final Duration? minDuration;
  final Duration? maxDuration;

  /// Number of active filters (sort and text excluded).
  int get activeCount => [
        sources != null,
        downloadedOnly,
        localFilesOnly,
        offlineOnly,
        favoritesOnly,
        genre != null,
        minYear != null || maxYear != null,
        minDuration != null || maxDuration != null,
      ].where((x) => x).length;

  TrackQuery toQuery() => TrackQuery(
        text: text.trim().isEmpty ? null : text.trim(),
        sourceIds: sources,
        genre: genre,
        minYear: minYear,
        maxYear: maxYear,
        minDuration: minDuration,
        maxDuration: maxDuration,
        favoritesOnly: favoritesOnly,
        downloadedOnly: downloadedOnly,
        localFilesOnly: localFilesOnly,
        offlineAvailableOnly: offlineOnly,
        sort: sort,
        descending: descending,
      );

  LibraryFilters copyWith({
    String? text,
    TrackSortField? sort,
    bool? descending,
    Set<String>? sources,
    bool clearSources = false,
    bool? downloadedOnly,
    bool? localFilesOnly,
    bool? offlineOnly,
    bool? favoritesOnly,
    String? genre,
    bool clearGenre = false,
    int? minYear,
    bool clearMinYear = false,
    int? maxYear,
    bool clearMaxYear = false,
    Duration? minDuration,
    bool clearMinDuration = false,
    Duration? maxDuration,
    bool clearMaxDuration = false,
  }) =>
      LibraryFilters(
        text: text ?? this.text,
        sort: sort ?? this.sort,
        descending: descending ?? this.descending,
        sources: clearSources ? null : (sources ?? this.sources),
        downloadedOnly: downloadedOnly ?? this.downloadedOnly,
        localFilesOnly: localFilesOnly ?? this.localFilesOnly,
        offlineOnly: offlineOnly ?? this.offlineOnly,
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
        genre: clearGenre ? null : (genre ?? this.genre),
        minYear: clearMinYear ? null : (minYear ?? this.minYear),
        maxYear: clearMaxYear ? null : (maxYear ?? this.maxYear),
        minDuration: clearMinDuration ? null : (minDuration ?? this.minDuration),
        maxDuration: clearMaxDuration ? null : (maxDuration ?? this.maxDuration),
      );

  /// Same sort and text, no filters.
  LibraryFilters cleared() => LibraryFilters(text: text, sort: sort, descending: descending);
}

/// Holds the Library filters for the session.
class LibraryFiltersController extends Notifier<LibraryFilters> {
  @override
  LibraryFilters build() => const LibraryFilters();

  void set(LibraryFilters filters) => state = filters;

  void update(LibraryFilters Function(LibraryFilters f) change) => state = change(state);

  /// Picks a sort field; choosing the current field flips the direction.
  /// Text fields sort ascending by default, numbers/dates descending.
  void sortBy(TrackSortField field) {
    if (field == state.sort) {
      state = state.copyWith(descending: !state.descending);
    } else {
      final textual = field == TrackSortField.title || field == TrackSortField.artist || field == TrackSortField.album;
      state = state.copyWith(sort: field, descending: !textual);
    }
  }
}

final libraryFiltersProvider = NotifierProvider<LibraryFiltersController, LibraryFilters>(LibraryFiltersController.new);

/// Library tracks for the current filters; refetches on library changes.
final libraryTracksProvider = FutureProvider.autoDispose<List<Track>>(
  (ref) async {
    final filters = ref.watch(libraryFiltersProvider);
    watchLibrary(ref, LibraryTopic.tracks);
    if (filters.favoritesOnly) watchLibrary(ref, LibraryTopic.favorites);
    if (filters.sort == TrackSortField.playCount) watchLibrary(ref, LibraryTopic.history);
    if (filters.downloadedOnly || filters.offlineOnly) ref.watch(downloadedIdsProvider);
    return ref.watch(trackRepositoryProvider).query(filters.toQuery());
  },
  retry: noRetry,
);

/// Genres in the library (for the genre filter).
final libraryGenresProvider = FutureProvider.autoDispose<List<String>>(
  (ref) async {
    watchLibrary(ref, LibraryTopic.tracks);
    final genres = await ref.watch(trackRepositoryProvider).genres();
    return [...genres]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  },
  retry: noRetry,
);
