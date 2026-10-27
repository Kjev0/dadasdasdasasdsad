import 'package:flutter/foundation.dart';

import '../models/catalog.dart';
import '../models/track.dart';
import '../util/cancel_token.dart';

@immutable
class LyricsLine {
  const LyricsLine(this.time, this.text);
  final Duration time;
  final String text;
}

@immutable
class Lyrics {
  const Lyrics({this.plain, this.synced = const [], this.instrumental = false, required this.provider, this.sourceUrl});

  final String? plain;

  /// Empty when only plain lyrics are available.
  final List<LyricsLine> synced;
  final bool instrumental;

  /// Attribution, e.g. "LRCLIB".
  final String provider;
  final Uri? sourceUrl;

  bool get hasSynced => synced.isNotEmpty;
}

/// Lyrics from permitted sources only (LRCLIB; embedded tags of local files).
abstract class LyricsService {
  Future<Lyrics?> lyricsFor(Track track, {CancelToken? cancel});
}

/// A titled shelf of tracks for Home/Explore (e.g. "Daily Mix 1").
@immutable
class Shelf {
  const Shelf({required this.id, required this.title, this.subtitle, required this.tracks, this.artworkUrl, this.kind = ShelfKind.mix});

  final String id;

  /// Localization key or literal title.
  final String title;
  final String? subtitle;
  final List<Track> tracks;
  final Uri? artworkUrl;
  final ShelfKind kind;
}

enum ShelfKind { mix, discoverWeekly, newReleases, trending, recentlyPlayed, similarArtists, genre, mood, continueListening }

@immutable
class MoodCategory {
  const MoodCategory({required this.id, required this.labelKey, required this.queries, this.genres = const []});

  final String id;

  /// Localization key (e.g. `moodFocus`).
  final String labelKey;

  /// Search seeds used to build the playlist on permitted sources.
  final List<String> queries;
  final List<String> genres;
}

/// Local, privacy-first recommendations. Computed on device from listening
/// history + provider "related"/"trending" endpoints. When personalization
/// is disabled only non-personal shelves (trending, new releases, genres)
/// are returned.
abstract class RecommendationService {
  Future<List<Shelf>> homeShelves({CancelToken? cancel});

  Future<List<Shelf>> dailyMixes({int count = 4, CancelToken? cancel});

  /// Weekly-seeded discovery playlist of tracks not in the library.
  Future<Shelf?> discoverWeekly({CancelToken? cancel});

  Future<List<Track>> similarTo(Track track, {int limit = 25, CancelToken? cancel});

  Future<List<Artist>> similarArtists(String artistName, {int limit = 12, CancelToken? cancel});

  Future<List<Album>> newReleases({CancelToken? cancel});

  Future<List<String>> genres({CancelToken? cancel});

  Future<List<Track>> genreTracks(String genre, {CancelToken? cancel});

  List<MoodCategory> get moods;

  Future<List<Track>> moodTracks(MoodCategory mood, {CancelToken? cancel});

  /// Tracks to append when the queue ends and "smart queue/autoplay" is on.
  Future<List<Track>> smartQueueContinuation(List<Track> recent, {int limit = 10, CancelToken? cancel});
}
