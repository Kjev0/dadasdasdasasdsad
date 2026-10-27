import 'dart:math' as math;

/// Small deterministic PRNG (mulberry32) with a string seed.
///
/// `dart:math`'s `Random(seed)` is not guaranteed to produce the same
/// sequence across SDK versions or platforms; daily mixes and Discover
/// Weekly must stay stable for a given day/week, so we use our own.
class SeededRandom {
  SeededRandom(int seed) : _state = seed & 0xFFFFFFFF;

  /// Seeds from a string via 32-bit FNV-1a.
  factory SeededRandom.fromString(String seed) => SeededRandom(fnv1a32(seed));

  int _state;

  static int fnv1a32(String input) {
    var hash = 0x811C9DC5;
    for (final unit in input.codeUnits) {
      hash ^= unit & 0xFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
      hash ^= unit >> 8;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  /// Next unsigned 32-bit value.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = (t ^ (t + _imul(t ^ (t >>> 7), t | 61))) & 0xFFFFFFFF;
    return (t ^ (t >>> 14)) & 0xFFFFFFFF;
  }

  /// Uniform double in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Uniform int in [0, max).
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'must be positive');
    return (nextDouble() * max).floor();
  }

  /// Fisher–Yates shuffle (returns a new list).
  List<T> shuffled<T>(Iterable<T> items) {
    final list = items.toList();
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return list;
  }

  /// Weighted random order without replacement (Efraimidis–Spirakis):
  /// higher [weight] → earlier on average. Non-positive weights go last.
  List<T> weightedOrder<T>(Iterable<T> items, double Function(T item) weight) {
    final keyed = <(double, int, T)>[];
    var index = 0;
    for (final item in items) {
      final w = weight(item);
      final u = nextDouble().clamp(1e-12, 1.0);
      // key = u^(1/w); sort descending. Use log for numeric stability.
      final key = w > 0 ? math.log(u) / w : double.negativeInfinity;
      keyed.add((key, index++, item));
    }
    keyed.sort((a, b) {
      final c = b.$1.compareTo(a.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    return [for (final k in keyed) k.$3];
  }
}

/// Calendar helpers for date/week seeds.
abstract final class DiscoveryCalendar {
  /// `yyyy-mm-dd` of [date]'s local calendar day.
  static String dayKey(DateTime date) {
    final d = date.isUtc ? date.toLocal() : date;
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// ISO-8601 week-numbering year and week (weeks start Monday; week 1
  /// contains the year's first Thursday).
  static (int year, int week) isoWeek(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    final day = DateTime.utc(local.year, local.month, local.day);
    final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
    final jan1 = DateTime.utc(thursday.year, 1, 1);
    final week = thursday.difference(jan1).inDays ~/ 7 + 1;
    return (thursday.year, week);
  }

  /// `yyyy-Www`, e.g. `2026-W44`.
  static String weekKey(DateTime date) {
    final (y, w) = isoWeek(date);
    return '$y-W${w.toString().padLeft(2, '0')}';
  }
}
