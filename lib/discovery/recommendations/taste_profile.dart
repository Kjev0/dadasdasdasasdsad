import 'dart:math' as math;

import '../../core/models/library.dart';
import '../../core/models/track.dart';
import '../util/text_keys.dart';

/// Weights of the on-device taste model. Defaults are documented in
/// `lib/discovery/README.md`.
class TasteTuning {
  const TasteTuning({
    this.halfLife = const Duration(days: 30),
    this.skipThreshold = const Duration(seconds: 30),
    this.skipPenalty = 0.75,
    this.favoriteBoost = 3.0,
    this.partialMinWeight = 0.25,
    this.unknownDurationPartialWeight = 0.5,
  });

  /// A play loses half its weight after this long.
  final Duration halfLife;

  /// Plays shorter than this (and shorter than half the track) are skips.
  final Duration skipThreshold;

  /// Negative weight of a skip (before time decay).
  final double skipPenalty;

  /// Constant (non-decaying) bonus per favorite track for its artist,
  /// genre and the track itself.
  final double favoriteBoost;

  /// Minimum weight of a partial (non-skip, non-completed) listen.
  final double partialMinWeight;

  /// Weight of a partial listen when the track duration is unknown.
  final double unknownDurationPartialWeight;
}

/// Accumulated affinity for one artist.
class ArtistAffinity {
  ArtistAffinity(this.key, this.name);

  /// Normalized artist key ([TextKeys.artist]).
  final String key;

  /// Display name (first seen spelling).
  final String name;

  double score = 0;
  int plays = 0;
  int skips = 0;
  int favorites = 0;

  /// Known provider artist ids: sourceId → sourceArtistId.
  final Map<String, String> sourceArtistIds = {};

  /// Genre key → weight (from this artist's played/favorite tracks).
  final Map<String, double> genres = {};

  /// Strongest genre key of this artist, or null when no genre is known.
  String? get dominantGenre {
    String? best;
    var bestScore = 0.0;
    for (final e in genres.entries) {
      if (e.value > bestScore || (e.value == bestScore && best != null && e.key.compareTo(best) < 0)) {
        best = e.key;
        bestScore = e.value;
      }
    }
    return bestScore > 0 ? best : null;
  }
}

/// Listening taste computed on device from history and favorites — never
/// leaves the device.
///
/// * Every play contributes `weight × 0.5^(age / halfLife)`.
/// * Completed plays weigh 1; partial plays weigh `listened / duration`
///   (at least [TasteTuning.partialMinWeight]); skips (shorter than
///   [TasteTuning.skipThreshold] and than half the track) weigh
///   `-skipPenalty`.
/// * Favorites add a constant [TasteTuning.favoriteBoost].
class TasteProfile {
  TasteProfile._(this.artists, this.genres, this.genreNames, this.trackScores, this.knownTracks, this.knownKeys);

  factory TasteProfile.build({
    required List<PlayRecord> history,
    required List<Track> favorites,
    required DateTime now,
    TasteTuning tuning = const TasteTuning(),
  }) {
    final artists = <String, ArtistAffinity>{};
    final genres = <String, double>{};
    final genreNames = <String, String>{};
    final trackScores = <String, double>{};
    final known = <String, Track>{};
    final keys = <String>{};

    void apply(Track t, double weight, {bool favorite = false, bool skip = false, bool play = false}) {
      known.putIfAbsent(t.id, () => t);
      keys.add(TextKeys.track(t));
      trackScores[t.id] = (trackScores[t.id] ?? 0) + weight;
      final name = t.primaryArtist.trim();
      if (name.isNotEmpty) {
        final key = TextKeys.artist(name);
        if (key.isNotEmpty) {
          final a = artists.putIfAbsent(key, () => ArtistAffinity(key, name));
          a.score += weight;
          if (play) a.plays++;
          if (skip) a.skips++;
          if (favorite) a.favorites++;
          final artistId = t.artists.first.sourceArtistId;
          if (artistId != null && artistId.isNotEmpty) a.sourceArtistIds.putIfAbsent(t.sourceId, () => artistId);
          for (final g in TextKeys.splitGenres(t.genre)) {
            final gk = TextKeys.genre(g);
            if (gk.isEmpty) continue;
            // Skips must not teach genres; only positive evidence counts here.
            if (weight > 0) a.genres[gk] = (a.genres[gk] ?? 0) + weight;
          }
        }
      }
      for (final g in TextKeys.splitGenres(t.genre)) {
        final gk = TextKeys.genre(g);
        if (gk.isEmpty) continue;
        genreNames.putIfAbsent(gk, () => g);
        genres[gk] = (genres[gk] ?? 0) + weight;
      }
    }

    for (final r in history) {
      final w = playWeight(r, tuning) * decay(now.difference(r.playedAt), tuning.halfLife);
      apply(r.track, w, skip: isSkip(r, tuning), play: true);
    }
    for (final f in favorites) {
      apply(f, tuning.favoriteBoost, favorite: true);
    }
    return TasteProfile._(artists, genres, genreNames, trackScores, known, keys);
  }

  /// Artist key → affinity.
  final Map<String, ArtistAffinity> artists;

  /// Genre key → affinity.
  final Map<String, double> genres;

  /// Genre key → display name.
  final Map<String, String> genreNames;

  /// Track id → affinity (negative for tracks the user keeps skipping).
  final Map<String, double> trackScores;

  /// Every track seen in history or favorites, by id.
  final Map<String, Track> knownTracks;

  /// [TextKeys.track] of every known track (cross-provider "already heard").
  final Set<String> knownKeys;

  bool get isEmpty => knownTracks.isEmpty;

  /// `0.5^(age / halfLife)`; future timestamps count as "now".
  static double decay(Duration age, Duration halfLife) {
    if (age.isNegative || age == Duration.zero) return 1.0;
    return math.pow(0.5, age.inMilliseconds / halfLife.inMilliseconds).toDouble();
  }

  /// Short, incomplete listens: under [TasteTuning.skipThreshold] and under
  /// half of the track (so a 40 s interlude played for 25 s is not a skip).
  static bool isSkip(PlayRecord r, TasteTuning tuning) {
    if (r.completed) return false;
    if (r.listened >= tuning.skipThreshold) return false;
    final d = r.track.duration;
    return d == null || d <= Duration.zero || r.listened * 2 < d;
  }

  /// Undecayed weight of one play.
  static double playWeight(PlayRecord r, TasteTuning tuning) {
    if (r.completed) return 1.0;
    if (isSkip(r, tuning)) return -tuning.skipPenalty;
    final d = r.track.duration;
    if (d == null || d <= Duration.zero) return tuning.unknownDurationPartialWeight;
    final ratio = r.listened.inMilliseconds / d.inMilliseconds;
    return ratio.clamp(tuning.partialMinWeight, 1.0).toDouble();
  }

  /// Artists with a positive score, best first (ties by name for
  /// determinism).
  List<ArtistAffinity> topArtists({int limit = 20}) {
    final list = artists.values.where((a) => a.score > 0).toList()
      ..sort((a, b) {
        final c = b.score.compareTo(a.score);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return list.take(limit).toList();
  }

  /// Genres with a positive score, best first, as display names.
  List<String> topGenres({int limit = 5}) {
    final list = genres.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return [for (final e in list.take(limit)) genreNames[e.key] ?? e.key];
  }

  /// Artist affinity of [t]'s primary artist (0 when unknown).
  double artistScoreOf(Track t) => artists[TextKeys.artist(t.primaryArtist)]?.score ?? 0;

  /// Known tracks of the given artists with a positive score, best first.
  List<Track> knownTracksOf(Set<String> artistKeys) {
    final list = [
      for (final t in knownTracks.values)
        if (artistKeys.contains(TextKeys.artist(t.primaryArtist)) && (trackScores[t.id] ?? 0) > 0) t,
    ]..sort((a, b) {
        final c = (trackScores[b.id] ?? 0).compareTo(trackScores[a.id] ?? 0);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return list;
  }

  /// Whether the user already knows [t] (same id or same song elsewhere).
  bool knows(Track t) => knownTracks.containsKey(t.id) || knownKeys.contains(TextKeys.track(t));
}
