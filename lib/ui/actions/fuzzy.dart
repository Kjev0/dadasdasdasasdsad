/// Small fuzzy matcher for the command palette. Every whitespace-separated
/// query token must match the candidate as a substring or subsequence;
/// substring, word-start and consecutive hits score higher. Case and common
/// accents are ignored (so "dansk" matches "Dansk" and "sovetimer" matches
/// "Sovetimer"). Returns null when there is no match.
double? fuzzyScore(String query, String candidate) {
  final q = foldForSearch(query).trim();
  if (q.isEmpty) return 0;
  final c = foldForSearch(candidate);
  var total = 0.0;
  for (final token in q.split(RegExp(r'\s+'))) {
    final s = _tokenScore(token, c);
    if (s == null) return null;
    total += s;
  }
  // Prefer shorter candidates for equal matches.
  return total / (1 + c.length / 60);
}

double? _tokenScore(String t, String c) => _score(t, c, preferBoundary: true) ?? _score(t, c, preferBoundary: false);

double? _score(String t, String c, {required bool preferBoundary}) {
  final idx = c.indexOf(t);
  if (idx >= 0) {
    var s = 10.0 + t.length * 2;
    if (idx == 0) {
      s += 8;
    } else if (_boundary(c, idx)) {
      s += 5;
    }
    return s;
  }
  var ci = 0;
  var prev = -2;
  var score = 0.0;
  for (var ti = 0; ti < t.length; ti++) {
    final ch = t[ti];
    // Prefer a consecutive hit, then the next word start, then any hit.
    int found;
    if (prev >= 0 && prev + 1 < c.length && c[prev + 1] == ch) {
      found = prev + 1;
    } else {
      found = -1;
      for (var j = ci; preferBoundary && j < c.length; j++) {
        if (c[j] == ch && _boundary(c, j)) {
          found = j;
          break;
        }
      }
      if (found < 0) found = c.indexOf(ch, ci);
    }
    if (found < 0) return null;
    score += 1;
    if (found == prev + 1) score += 1.5;
    if (_boundary(c, found)) score += 2;
    score -= (found - ci) * 0.05;
    prev = found;
    ci = found + 1;
  }
  return score;
}

bool _boundary(String c, int i) {
  if (i == 0) return true;
  final p = c[i - 1];
  return p == ' ' || p == '-' || p == '/' || p == '&' || p == '(' || p == '·';
}

const _fold = {
  'æ': 'ae',
  'ø': 'o',
  'å': 'a',
  'ä': 'a',
  'ö': 'o',
  'ü': 'u',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'á': 'a',
  'à': 'a',
  'í': 'i',
  'ó': 'o',
  'ú': 'u',
  'ñ': 'n',
  'ç': 'c',
  'ß': 'ss',
};

/// Lowercases and strips common diacritics.
String foldForSearch(String s) {
  final lower = s.toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    b.write(_fold[ch] ?? ch);
  }
  return b.toString();
}

/// Sorts [items] by best fuzzy score of their [texts] (the first text is the
/// title; others, e.g. keywords, count 80 %). Non-matches are dropped.
List<T> fuzzyFilter<T>(Iterable<T> items, String query, List<String> Function(T item) texts, {int? limit}) {
  if (query.trim().isEmpty) return limit == null ? items.toList() : items.take(limit).toList();
  final scored = <(T, double)>[];
  for (final item in items) {
    double? best;
    final t = texts(item);
    for (var i = 0; i < t.length; i++) {
      final s = fuzzyScore(query, t[i]);
      if (s == null) continue;
      final weighted = i == 0 ? s : s * 0.8;
      if (best == null || weighted > best) best = weighted;
    }
    if (best != null) scored.add((item, best));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  final result = [for (final (item, _) in scored) item];
  return limit == null || result.length <= limit ? result : result.sublist(0, limit);
}
