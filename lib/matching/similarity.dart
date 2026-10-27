import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'text/text_keys.dart';

/// Result of comparing two artist credits.
@immutable
class ArtistOverlap {
  const ArtistOverlap({required this.primary, required this.featured, required this.hasFeatured});

  /// How well the main artists agree (0..1); null when either side has no
  /// artist at all.
  final double? primary;

  /// Share of non-main artists (featured guests and further collaborators)
  /// found on the other side (0..1); 1.0 when neither side has any.
  final double featured;

  /// Whether either side credits more than one artist.
  final bool hasFeatured;
}

/// String similarity measures. All return values are in 0..1 (1 = equal)
/// and expect pre-normalized keys (see `TextKeys`) unless noted.
abstract final class Similarity {
  /// Featured names count as present on the other side at this similarity.
  static const featuredMatchThreshold = 0.85;

  /// Tokens count as equal in [fuzzyTokenJaccard] at this Jaro-Winkler score.
  static const fuzzyTokenThreshold = 0.9;

  // ---------------------------------------------------------------------
  // Primitive measures
  // ---------------------------------------------------------------------

  /// Levenshtein edit distance over Unicode code points.
  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    final s = a.runes.toList(), t = b.runes.toList();
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    var prev = List<int>.generate(t.length + 1, (i) => i);
    var curr = List<int>.filled(t.length + 1, 0);
    for (var i = 1; i <= s.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= t.length; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        curr[j] = math.min(math.min(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[t.length];
  }

  /// 1 - distance / max length.
  static double levenshteinSimilarity(String a, String b) {
    if (a == b) return 1;
    final maxLen = math.max(a.runes.length, b.runes.length);
    if (maxLen == 0) return 1;
    return 1 - levenshtein(a, b) / maxLen;
  }

  static double jaro(String a, String b) {
    if (a == b) return a.isEmpty ? 0 : 1;
    final s = a.runes.toList(), t = b.runes.toList();
    if (s.isEmpty || t.isEmpty) return 0;
    final window = math.max(0, math.max(s.length, t.length) ~/ 2 - 1);
    final sMatched = List<bool>.filled(s.length, false);
    final tMatched = List<bool>.filled(t.length, false);
    var matches = 0;
    for (var i = 0; i < s.length; i++) {
      final from = math.max(0, i - window);
      final to = math.min(t.length - 1, i + window);
      for (var j = from; j <= to; j++) {
        if (tMatched[j] || s[i] != t[j]) continue;
        sMatched[i] = tMatched[j] = true;
        matches++;
        break;
      }
    }
    if (matches == 0) return 0;
    var transpositions = 0;
    var k = 0;
    for (var i = 0; i < s.length; i++) {
      if (!sMatched[i]) continue;
      while (!tMatched[k]) {
        k++;
      }
      if (s[i] != t[k]) transpositions++;
      k++;
    }
    final m = matches.toDouble();
    return (m / s.length + m / t.length + (m - transpositions / 2) / m) / 3;
  }

  /// Jaro-Winkler: Jaro boosted by up to [maxPrefix] common leading chars.
  static double jaroWinkler(String a, String b, {double prefixScale = 0.1, int maxPrefix = 4}) {
    final j = jaro(a, b);
    if (j == 0) return 0;
    var prefix = 0;
    final s = a.runes.toList(), t = b.runes.toList();
    while (prefix < maxPrefix && prefix < s.length && prefix < t.length && s[prefix] == t[prefix]) {
      prefix++;
    }
    return j + prefix * prefixScale * (1 - j);
  }

  /// |A ∩ B| / |A ∪ B|; 1 for two empty sets.
  static double jaccard<T>(Set<T> a, Set<T> b) {
    if (a.isEmpty && b.isEmpty) return 1;
    final inter = a.intersection(b).length;
    return inter / (a.length + b.length - inter);
  }

  /// Jaccard over whitespace tokens.
  static double tokenSetJaccard(String a, String b) => jaccard(_tokens(a).toSet(), _tokens(b).toSet());

  /// Jaccard where tokens of length ≥ 4 also match when their Jaro-Winkler
  /// similarity is ≥ [threshold] (tolerates typos: "adventrue").
  static double fuzzyTokenJaccard(List<String> a, List<String> b, {double threshold = fuzzyTokenThreshold}) {
    final sa = a.toSet().toList(), sb = b.toSet().toList();
    if (sa.isEmpty && sb.isEmpty) return 1;
    if (sa.isEmpty || sb.isEmpty) return 0;
    final used = List<bool>.filled(sb.length, false);
    var matched = 0;
    final pending = <String>[];
    for (final x in sa) {
      final i = sb.indexOf(x);
      if (i >= 0 && !used[i]) {
        used[i] = true;
        matched++;
      } else {
        pending.add(x);
      }
    }
    for (final x in pending) {
      if (x.length < 4) continue;
      for (var i = 0; i < sb.length; i++) {
        if (used[i] || sb[i].length < 4) continue;
        if (jaroWinkler(x, sb[i]) >= threshold) {
          used[i] = true;
          matched++;
          break;
        }
      }
    }
    return matched / (sa.length + sb.length - matched);
  }

  // ---------------------------------------------------------------------
  // Domain measures
  // ---------------------------------------------------------------------

  /// Similarity of two normalized titles.
  ///
  /// Blends whole-string edit similarity (typos), fuzzy token overlap
  /// (extra/missing words) and Jaro-Winkler (shared beginnings). Word-order
  /// swaps score ≥ 0.95. Different numbers ("Part 2" vs "Part 3",
  /// "1999" vs "2000") are penalized hard because they denote different
  /// songs.
  static double title(String a, String b) {
    if (a.isEmpty || b.isEmpty) return a == b ? 1 : 0;
    if (a == b) return 1;
    if (a.replaceAll(' ', '') == b.replaceAll(' ', '')) return 1;
    final ta = _tokens(a), tb = _tokens(b);
    var s = 0.45 * levenshteinSimilarity(a, b) + 0.35 * fuzzyTokenJaccard(ta, tb) + 0.20 * jaroWinkler(a, b);
    if (_sortedJoin(ta) == _sortedJoin(tb)) s = math.max(s, 0.95);
    final na = ta.where(_isNumber).toSet(), nb = tb.where(_isNumber).toSet();
    if (!setEquals(na, nb)) s *= 0.6;
    return s.clamp(0.0, 1.0);
  }

  /// Similarity of two normalized single artist names.
  static double name(String a, String b) {
    if (a.isEmpty || b.isEmpty) return a == b ? 1 : 0;
    if (a == b) return 1;
    if (a.replaceAll(' ', '') == b.replaceAll(' ', '')) return 1;
    final ta = _tokens(a), tb = _tokens(b);
    if (_sortedJoin(ta) == _sortedJoin(tb)) return 1;
    final blend = 0.5 * jaroWinkler(a, b) + 0.5 * levenshteinSimilarity(a, b);
    return math.max(blend, jaccard(ta.toSet(), tb.toSet()));
  }

  /// [title] over both folding variants (so "Ålborg" ≈ "Aalborg").
  static double foldedTitle(FoldedText a, FoldedText b) => _bestVariant(a, b, title);

  /// [name] over both folding variants (so "Mø" ≈ "MO" ≈ "Moe").
  static double foldedName(FoldedText a, FoldedText b) => _bestVariant(a, b, name);

  /// Compares two artist credits order-insensitively.
  ///
  /// * primary: average of "A's main artist found among all of B's
  ///   artists" and vice versa, or the similarity of the joined main credit
  ///   lines, whichever is higher. This tolerates services that list a
  ///   collaborator as a second main artist vs. as a featured artist.
  /// * featured: every artist except each side's first must be found on the
  ///   other side (by similarity or token containment).
  static ArtistOverlap artistOverlap({
    required List<FoldedText> primaryA,
    required List<FoldedText> featuredA,
    required List<FoldedText> primaryB,
    required List<FoldedText> featuredB,
  }) {
    final allA = [...primaryA, ...featuredA];
    final allB = [...primaryB, ...featuredB];
    double? primary;
    if (primaryA.isNotEmpty && primaryB.isNotEmpty) {
      final directional = (_best(primaryA.first, allB) + _best(primaryB.first, allA)) / 2;
      final line = foldedName(_join(primaryA), _join(primaryB));
      primary = math.max(directional, line);
    }
    final restA = allA.skip(1).toList();
    final restB = allB.skip(1).toList();
    if (restA.isEmpty && restB.isEmpty) {
      return ArtistOverlap(primary: primary, featured: 1, hasFeatured: false);
    }
    final tokensA = allA.expand((n) => n.tokens).toSet();
    final tokensB = allB.expand((n) => n.tokens).toSet();
    bool found(FoldedText x, List<FoldedText> other, Set<String> otherTokens) =>
        _best(x, other) >= featuredMatchThreshold || (x.tokens.isNotEmpty && otherTokens.containsAll(x.tokens));
    final matched = restA.where((x) => found(x, allB, tokensB)).length + restB.where((x) => found(x, allA, tokensA)).length;
    return ArtistOverlap(primary: primary, featured: matched / (restA.length + restB.length), hasFeatured: true);
  }

  static double _best(FoldedText x, List<FoldedText> candidates) {
    var best = 0.0;
    for (final c in candidates) {
      best = math.max(best, foldedName(x, c));
      if (best == 1) break;
    }
    return best;
  }

  static FoldedText _join(List<FoldedText> names) =>
      FoldedText(names.map((n) => n.key).join(' '), alt: names.map((n) => n.alt).join(' '));

  static double _bestVariant(FoldedText a, FoldedText b, double Function(String, String) f) {
    var s = f(a.key, b.key);
    if (s < 1 && a.hasAlt) s = math.max(s, f(a.alt, b.key));
    if (s < 1 && b.hasAlt) s = math.max(s, f(a.key, b.alt));
    if (s < 1 && a.hasAlt && b.hasAlt) s = math.max(s, f(a.alt, b.alt));
    return s;
  }

  static final _number = RegExp(r'^\d+$');

  static bool _isNumber(String t) => _number.hasMatch(t);

  static List<String> _tokens(String s) => s.isEmpty ? const [] : s.split(' ').where((t) => t.isNotEmpty).toList();

  static String _sortedJoin(List<String> tokens) => ([...tokens]..sort()).join(' ');
}
