import '../../core/models/track.dart';
import '../util/seeded_random.dart';
import '../util/text_keys.dart';
import 'taste_profile.dart';

/// A group of related artists that becomes one Daily Mix.
class MixCluster {
  MixCluster(this.seed) : artists = [seed];

  final ArtistAffinity seed;
  final List<ArtistAffinity> artists;

  String? get genre => seed.dominantGenre;

  double get weight => artists.fold(0.0, (s, a) => s + a.score);

  Set<String> get artistKeys => {for (final a in artists) a.key};
}

/// Pure list algorithms behind mixes: clustering, 60/40 composition,
/// artist spacing and de-duplication. No I/O — fully unit-testable.
abstract final class MixBuilder {
  /// Clusters the user's top artists into at most [count] groups.
  ///
  /// Seeds are the strongest artists with distinct dominant genres (then
  /// the strongest remaining artists when there are fewer genres than
  /// mixes). Other artists join the cluster with the same genre, else the
  /// one with the most genre overlap, else the lightest cluster. Pure
  /// function of the profile → stable for a given history.
  static List<MixCluster> cluster(TasteProfile profile, int count, {int maxArtists = 40}) {
    if (count <= 0) return const [];
    final candidates = profile.topArtists(limit: maxArtists);
    if (candidates.isEmpty) return const [];
    final clusters = <MixCluster>[];
    final usedGenres = <String?>{};
    for (final a in candidates) {
      if (clusters.length >= count) break;
      final g = a.dominantGenre;
      if (g != null && usedGenres.contains(g)) continue;
      if (g == null && clusters.isNotEmpty) continue;
      usedGenres.add(g);
      clusters.add(MixCluster(a));
    }
    for (final a in candidates) {
      if (clusters.length >= count) break;
      if (clusters.any((c) => c.seed.key == a.key)) continue;
      clusters.add(MixCluster(a));
    }
    final seeds = {for (final c in clusters) c.seed.key};
    for (final a in candidates) {
      if (seeds.contains(a.key)) continue;
      _bestClusterFor(a, clusters).artists.add(a);
    }
    return clusters;
  }

  static MixCluster _bestClusterFor(ArtistAffinity a, List<MixCluster> clusters) {
    final g = a.dominantGenre;
    if (g != null) {
      for (final c in clusters) {
        if (c.genre == g) return c;
      }
    }
    MixCluster? best;
    var bestOverlap = 0.0;
    for (final c in clusters) {
      final overlap = _overlap(a.genres, c.seed.genres);
      if (overlap > bestOverlap) {
        best = c;
        bestOverlap = overlap;
      }
    }
    if (best != null) return best;
    return clusters.reduce((x, y) => y.weight < x.weight ? y : x);
  }

  static double _overlap(Map<String, double> a, Map<String, double> b) {
    var dot = 0.0;
    for (final e in a.entries) {
      dot += e.value * (b[e.key] ?? 0);
    }
    return dot;
  }

  /// Composes a mix of ~[familiarShare] known tracks and the rest
  /// discoveries, [minLength]..[maxLength] long when enough material
  /// exists (shorter otherwise — nothing is invented). Both pools are
  /// ordered by [rng] (known tracks weighted by [knownWeight]) and spread
  /// evenly; then [spaceArtists] guarantees no artist plays more than
  /// [maxRun] times in a row.
  static List<Track> compose({
    required List<Track> known,
    required List<Track> discoveries,
    required SeededRandom rng,
    double Function(Track t)? knownWeight,
    int minLength = 25,
    int maxLength = 50,
    double familiarShare = 0.6,
    int maxRun = 3,
  }) {
    final k = dedupe(known);
    final knownIds = {for (final t in k) t.id};
    final knownKeys = {for (final t in k) TextKeys.track(t)};
    final d = dedupe([
      for (final t in discoveries)
        if (!knownIds.contains(t.id) && !knownKeys.contains(TextKeys.track(t))) t,
    ]);
    final available = k.length + d.length;
    if (available == 0) return const [];
    // Aim for familiar/0.6 total so the ratio holds; clamp to the range.
    var target = k.isEmpty ? d.length : (k.length / familiarShare).round();
    target = target.clamp(minLength, maxLength);
    if (target > available) target = available;

    var knownTarget = (target * familiarShare).round();
    var discTarget = target - knownTarget;
    if (knownTarget > k.length) {
      discTarget += knownTarget - k.length;
      knownTarget = k.length;
    }
    if (discTarget > d.length) {
      knownTarget = (knownTarget + discTarget - d.length).clamp(0, k.length);
      discTarget = d.length;
    }
    final total = knownTarget + discTarget;

    final kw = knownWeight ?? (_) => 1.0;
    final kOrdered = rng.weightedOrder(k, (t) => kw(t).clamp(0.01, double.infinity)).take(knownTarget).toList();
    // Earlier discoveries are more relevant: weight decays with rank.
    final dRank = {for (var i = 0; i < d.length; i++) d[i].id: i};
    final dOrdered = rng.weightedOrder(d, (t) => 1 / (1 + dRank[t.id]! * 0.15)).take(discTarget).toList();

    // Even spread (Bresenham): known track when behind its quota.
    final out = <Track>[];
    var ki = 0, di = 0;
    for (var pos = 0; pos < total; pos++) {
      final wantKnown = ki < kOrdered.length && (di >= dOrdered.length || ki * total < knownTarget * (pos + 1));
      out.add(wantKnown ? kOrdered[ki++] : dOrdered[di++]);
    }
    return spaceArtists(out, maxRun: maxRun);
  }

  /// Reorders [tracks] so that no artist appears more than [maxRun] times
  /// in a row, keeping the order otherwise. Tracks that cannot be placed
  /// without breaking the rule (e.g. only one artist left) are dropped.
  static List<Track> spaceArtists(List<Track> tracks, {int maxRun = 3}) {
    final pending = [...tracks];
    final out = <Track>[];
    while (pending.isNotEmpty) {
      final idx = pending.indexWhere((t) => _runAfter(out, TextKeys.artist(t.primaryArtist)) < maxRun);
      if (idx < 0) break;
      out.add(pending.removeAt(idx));
    }
    return out;
  }

  /// Length of the run of [artistKey] at the end of [list].
  static int _runAfter(List<Track> list, String artistKey) {
    var run = 0;
    for (var i = list.length - 1; i >= 0; i--) {
      if (TextKeys.artist(list[i].primaryArtist) != artistKey) break;
      run++;
    }
    return run;
  }

  /// Longest same-artist run in [tracks] (for tests and assertions).
  static int longestArtistRun(List<Track> tracks) {
    var best = 0, run = 0;
    String? prev;
    for (final t in tracks) {
      final a = TextKeys.artist(t.primaryArtist);
      run = a == prev ? run + 1 : 1;
      prev = a;
      if (run > best) best = run;
    }
    return best;
  }

  /// Removes duplicates by id and by [TextKeys.track] (first wins).
  static List<Track> dedupe(Iterable<Track> tracks) {
    final ids = <String>{};
    final keys = <String>{};
    return [
      for (final t in tracks)
        if (ids.add(t.id) && keys.add(TextKeys.track(t))) t,
    ];
  }

  /// Round-robin merge of several ranked lists (diversifies sources and
  /// seeds), de-duplicated.
  static List<Track> interleave(List<List<Track>> lists, {int? limit}) {
    final out = <Track>[];
    final ids = <String>{};
    final keys = <String>{};
    var i = 0;
    var progressed = true;
    while (progressed && (limit == null || out.length < limit)) {
      progressed = false;
      for (final l in lists) {
        if (i < l.length) {
          progressed = true;
          final t = l[i];
          if (ids.add(t.id) && keys.add(TextKeys.track(t))) {
            out.add(t);
            if (limit != null && out.length >= limit) break;
          }
        }
      }
      i++;
    }
    return out;
  }

  /// Keeps at most [maxPerArtist] tracks per artist (first wins).
  static List<Track> capPerArtist(Iterable<Track> tracks, int maxPerArtist) {
    final counts = <String, int>{};
    return [
      for (final t in tracks)
        if ((counts[TextKeys.artist(t.primaryArtist)] = (counts[TextKeys.artist(t.primaryArtist)] ?? 0) + 1) <=
            maxPerArtist)
          t,
    ];
  }
}
