import 'package:flutter/foundation.dart';

import 'track.dart';

enum TrackSortField { title, artist, album, year, duration, dateAdded, lastPlayed, playCount, genre }

/// Filter + sort for library track queries. All filters are AND-ed.
@immutable
class TrackQuery {
  const TrackQuery({
    this.text,
    this.sourceIds,
    this.artist,
    this.album,
    this.genre,
    this.minYear,
    this.maxYear,
    this.minDuration,
    this.maxDuration,
    this.favoritesOnly = false,
    this.downloadedOnly = false,
    this.localFilesOnly = false,
    this.offlineAvailableOnly = false,
    this.sort = TrackSortField.dateAdded,
    this.descending = true,
    this.limit,
    this.offset = 0,
  });

  /// Free-text match on title / artist / album (case- and accent-insensitive).
  final String? text;
  final Set<String>? sourceIds;
  final String? artist;
  final String? album;
  final String? genre;
  final int? minYear;
  final int? maxYear;
  final Duration? minDuration;
  final Duration? maxDuration;
  final bool favoritesOnly;

  /// Remote tracks with a completed, verified download.
  final bool downloadedOnly;

  /// User-owned local files only.
  final bool localFilesOnly;

  /// Downloaded OR user-owned (everything playable without network).
  final bool offlineAvailableOnly;
  final TrackSortField sort;
  final bool descending;
  final int? limit;
  final int offset;
}

@immutable
class AlbumSummary {
  const AlbumSummary({
    required this.title,
    required this.artist,
    required this.trackCount,
    this.year,
    this.artworkUrl,
    this.totalDuration,
  });

  final String title;
  final String artist;
  final int trackCount;
  final int? year;
  final Uri? artworkUrl;
  final Duration? totalDuration;
}

@immutable
class ArtistSummary {
  const ArtistSummary({required this.name, required this.trackCount, this.albumCount = 0, this.artworkUrl});

  final String name;
  final int trackCount;
  final int albumCount;
  final Uri? artworkUrl;
}

/// One listening event (written when a track ends; see `TrackEnded`).
@immutable
class PlayRecord {
  const PlayRecord({
    this.id,
    required this.track,
    required this.playedAt,
    required this.listened,
    required this.completed,
    this.origin,
  });

  final int? id;
  final Track track;
  final DateTime playedAt;
  final Duration listened;
  final bool completed;
  final String? origin;
}

@immutable
class ListeningStats {
  const ListeningStats({
    required this.totalPlays,
    required this.totalListened,
    required this.topTracks,
    required this.topArtists,
    required this.topGenres,
    required this.playsPerDay,
  });

  final int totalPlays;
  final Duration totalListened;
  final List<(Track, int)> topTracks;
  final List<(String, int)> topArtists;
  final List<(String, int)> topGenres;

  /// Day (local midnight) -> number of plays.
  final Map<DateTime, int> playsPerDay;
}

/// Links two [Track]s that are the same logical recording on different
/// sources (result of matching, or confirmed by the user).
@immutable
class TrackLink {
  const TrackLink({
    required this.trackId,
    required this.linkedTrackId,
    required this.confidence,
    required this.userConfirmed,
    required this.createdAt,
  });

  final String trackId;
  final String linkedTrackId;

  /// 0..1 score from the matcher (1.0 for user-confirmed or ISRC-identical).
  final double confidence;
  final bool userConfirmed;
  final DateTime createdAt;
}

@immutable
class LibraryFolder {
  const LibraryFolder({required this.path, this.watch = true, this.lastScannedAt, this.trackCount = 0});

  final String path;
  final bool watch;
  final DateTime? lastScannedAt;
  final int trackCount;
}

@immutable
class ScanProgress {
  const ScanProgress({
    required this.scannedFiles,
    required this.totalFiles,
    required this.added,
    required this.updated,
    required this.removed,
    this.currentPath,
    this.done = false,
    this.errors = const [],
  });

  final int scannedFiles;

  /// May be null while still enumerating.
  final int? totalFiles;
  final int added;
  final int updated;
  final int removed;
  final String? currentPath;
  final bool done;
  final List<String> errors;
}

/// A group of tracks believed to be duplicates of each other.
@immutable
class DuplicateGroup {
  const DuplicateGroup({required this.tracks, required this.reason});

  final List<Track> tracks;

  /// e.g. `same_hash`, `same_isrc`, `same_metadata`.
  final String reason;
}

// ---------------------------------------------------------------------------
// Smart playlists
// ---------------------------------------------------------------------------

enum SmartField { title, artist, album, genre, year, duration, playCount, lastPlayed, dateAdded, source, favorite, downloaded }

enum SmartOperator {
  contains,
  notContains,
  equals,
  notEquals,
  startsWith,
  greaterThan,
  lessThan,
  inLastDays,
  notInLastDays,
  isTrue,
  isFalse,
}

@immutable
class SmartRule {
  const SmartRule({required this.field, required this.op, this.value});

  final SmartField field;
  final SmartOperator op;

  /// String/num value; for durations seconds; for dates a number of days.
  final Object? value;

  Map<String, Object?> toJson() => {'field': field.name, 'op': op.name, 'value': value};

  factory SmartRule.fromJson(Map<String, Object?> json) => SmartRule(
        field: SmartField.values.byName(json['field'] as String),
        op: SmartOperator.values.byName(json['op'] as String),
        value: json['value'],
      );
}

@immutable
class SmartPlaylistRules {
  const SmartPlaylistRules({
    required this.rules,
    this.matchAll = true,
    this.limit,
    this.sort = TrackSortField.dateAdded,
    this.descending = true,
  });

  final List<SmartRule> rules;

  /// true = AND, false = OR.
  final bool matchAll;
  final int? limit;
  final TrackSortField sort;
  final bool descending;

  Map<String, Object?> toJson() => {
        'rules': [for (final r in rules) r.toJson()],
        'matchAll': matchAll,
        if (limit != null) 'limit': limit,
        'sort': sort.name,
        'desc': descending,
      };

  factory SmartPlaylistRules.fromJson(Map<String, Object?> json) => SmartPlaylistRules(
        rules: [
          for (final r in (json['rules'] as List? ?? const []))
            SmartRule.fromJson((r as Map).cast<String, Object?>()),
        ],
        matchAll: json['matchAll'] as bool? ?? true,
        limit: (json['limit'] as num?)?.toInt(),
        sort: TrackSortField.values.asNameMap()[json['sort']] ?? TrackSortField.dateAdded,
        descending: json['desc'] as bool? ?? true,
      );
}
