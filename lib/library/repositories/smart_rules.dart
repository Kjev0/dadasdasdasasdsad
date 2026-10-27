import '../../core/models/library.dart';
import '../db/sql_utils.dart';
import '../text/fold.dart';
import 'track_query_sql.dart';

/// Per-track facts a smart rule may look at (Dart evaluation path).
class SmartRowContext {
  const SmartRowContext({
    required this.title,
    required this.artistNorm,
    required this.artistNames,
    required this.album,
    required this.genre,
    required this.year,
    required this.durationMs,
    required this.playCount,
    required this.lastPlayed,
    required this.dateAdded,
    required this.source,
    required this.favorite,
    required this.downloaded,
  });

  /// Builds the context from a row selected with [SmartRulesSql.contextColumns].
  factory SmartRowContext.fromRow(Map<String, Object?> r) => SmartRowContext(
        title: r['title_norm'] as String? ?? '',
        artistNorm: r['artist_norm'] as String? ?? '',
        artistNames: ((r['artist_names'] as String?) ?? '').split('\u001f').where((s) => s.isNotEmpty).toSet(),
        album: r['album_norm'] as String?,
        genre: r['genre_norm'] as String?,
        year: (r['year'] as num?)?.toInt(),
        durationMs: (r['duration_ms'] as num?)?.toInt(),
        playCount: (r['play_count'] as num?)?.toInt() ?? 0,
        lastPlayed: (r['last_played'] as num?)?.toInt(),
        dateAdded: (r['date_added'] as num).toInt(),
        source: r['source_id'] as String,
        favorite: intBool(r['is_fav']),
        downloaded: intBool(r['is_dl']),
      );

  final String title;
  final String artistNorm;
  final Set<String> artistNames;
  final String? album;
  final String? genre;
  final int? year;
  final int? durationMs;
  final int playCount;
  final int? lastPlayed;
  final int dateAdded;
  final String source;
  final bool favorite;
  final bool downloaded;
}

/// Compiles [SmartRule]s to SQL (alias `t`, play stats as `ps`) and
/// evaluates the few combinations SQL cannot express in Dart.
///
/// Semantics:
/// * text fields compare folded text (accent/case-insensitive);
///   `artist equals X` matches any credited artist;
/// * `duration` values are seconds; `year`/`playCount` plain numbers;
/// * date fields (`lastPlayed`, `dateAdded`) take a number of days:
///   `inLastDays`/`lessThan` = within the last N days, `notInLastDays`/
///   `greaterThan` = not within the last N days (never-played tracks match
///   for `lastPlayed`), `equals` = on the local day N days ago;
///   `isTrue`/`isFalse` = has/has never been played;
/// * `favorite`/`downloaded` use `isTrue`/`isFalse` (or `equals` true/false).
/// Nonsensical combinations (e.g. `favorite contains`) match nothing.
abstract final class SmartRulesSql {
  /// Columns for [SmartRowContext.fromRow]; needs [playStatsJoin].
  static const contextColumns =
      't.title_norm, t.artist_norm, t.album_norm, t.genre_norm, t.year, t.duration_ms, t.date_added, t.source_id, '
      'ps.play_count, ps.last_played, '
      "(SELECT GROUP_CONCAT(ta.name_norm, '\u001f') FROM track_artists ta WHERE ta.track_id = t.id) AS artist_names, "
      '$isFavoriteSql AS is_fav, $isDownloadedSql AS is_dl';

  /// SQL for [rule], or null when it has to be evaluated in Dart.
  static SqlFragment? compile(SmartRule rule, DateTime now) {
    switch (rule.field) {
      case SmartField.title:
        return _text('t.title_norm', rule);
      case SmartField.artist:
        return _text('t.artist_norm', rule, anyArtist: true);
      case SmartField.album:
        return _text('t.album_norm', rule);
      case SmartField.genre:
        return _text('t.genre_norm', rule);
      case SmartField.source:
        return _text('t.source_id', rule);
      case SmartField.year:
        return _number('t.year', rule, 1);
      case SmartField.duration:
        return _number('t.duration_ms', rule, 1000);
      case SmartField.playCount:
        return _number('COALESCE(ps.play_count, 0)', rule, 1);
      case SmartField.lastPlayed:
        return _date('ps.last_played', rule, now);
      case SmartField.dateAdded:
        return _date('t.date_added', rule, now);
      case SmartField.favorite:
        return _bool(isFavoriteSql, rule);
      case SmartField.downloaded:
        return _bool(isDownloadedSql, rule);
    }
  }

  static String _fold(SmartRule rule) =>
      rule.field == SmartField.source ? (rule.value?.toString() ?? '').trim().toLowerCase() : foldForSearch(rule.value?.toString());

  static SqlFragment? _text(String col, SmartRule rule, {bool anyArtist = false}) {
    final v = _fold(rule);
    final c = 'COALESCE($col, \'\')';
    const anyArtistSql = 'EXISTS (SELECT 1 FROM track_artists ta WHERE ta.track_id = t.id AND ta.name_norm = ?)';
    switch (rule.op) {
      case SmartOperator.contains:
        return SqlFragment("$c LIKE ? ESCAPE '\\'", ['%${escapeLike(v)}%']);
      case SmartOperator.notContains:
        return SqlFragment("$c NOT LIKE ? ESCAPE '\\'", ['%${escapeLike(v)}%']);
      case SmartOperator.startsWith:
        return SqlFragment("$c LIKE ? ESCAPE '\\'", ['${escapeLike(v)}%']);
      case SmartOperator.equals:
        return anyArtist ? SqlFragment('($c = ? OR $anyArtistSql)', [v, v]) : SqlFragment('$c = ?', [v]);
      case SmartOperator.notEquals:
        return anyArtist ? SqlFragment('NOT ($c = ? OR $anyArtistSql)', [v, v]) : SqlFragment('$c <> ?', [v]);
      case SmartOperator.greaterThan:
        return SqlFragment('$c > ?', [v]);
      case SmartOperator.lessThan:
        return SqlFragment('$c < ?', [v]);
      case SmartOperator.isTrue:
        return SqlFragment("$c <> ''");
      case SmartOperator.isFalse:
        return SqlFragment("$c = ''");
      case SmartOperator.inLastDays:
      case SmartOperator.notInLastDays:
        return null;
    }
  }

  static num? _num(Object? v) => v is num ? v : num.tryParse(v?.toString().trim() ?? '');

  static SqlFragment? _number(String col, SmartRule rule, int scale) {
    if (rule.op == SmartOperator.isTrue) return SqlFragment('($col IS NOT NULL AND $col <> 0)');
    if (rule.op == SmartOperator.isFalse) return SqlFragment('($col IS NULL OR $col = 0)');
    final n = _num(rule.value);
    if (n == null) return null;
    switch (rule.op) {
      case SmartOperator.equals:
        return scale == 1 ? SqlFragment('$col = ?', [n]) : SqlFragment('($col / $scale) = ?', [n.floor()]);
      case SmartOperator.notEquals:
        return scale == 1
            ? SqlFragment('($col IS NULL OR $col <> ?)', [n])
            : SqlFragment('($col IS NULL OR ($col / $scale) <> ?)', [n.floor()]);
      case SmartOperator.greaterThan:
        return SqlFragment('$col > ?', [n * scale]);
      case SmartOperator.lessThan:
        return SqlFragment('$col < ?', [n * scale]);
      default:
        return null; // string operators on numbers: Dart
    }
  }

  static SqlFragment? _date(String col, SmartRule rule, DateTime now) {
    if (rule.op == SmartOperator.isTrue) return SqlFragment('$col IS NOT NULL');
    if (rule.op == SmartOperator.isFalse) return SqlFragment('$col IS NULL');
    final days = _num(rule.value);
    if (days == null) return null;
    final cutoff = now.subtract(Duration(milliseconds: (days * Duration.millisecondsPerDay).round())).millisecondsSinceEpoch;
    switch (rule.op) {
      case SmartOperator.inLastDays:
      case SmartOperator.lessThan:
        return SqlFragment('$col >= ?', [cutoff]);
      case SmartOperator.notInLastDays:
      case SmartOperator.greaterThan:
        return SqlFragment('($col IS NULL OR $col < ?)', [cutoff]);
      case SmartOperator.equals:
      case SmartOperator.notEquals:
        final (start, end) = _dayBounds(now, days.floor());
        return rule.op == SmartOperator.equals
            ? SqlFragment('($col >= ? AND $col < ?)', [start, end])
            : SqlFragment('($col IS NULL OR $col < ? OR $col >= ?)', [start, end]);
      default:
        return null;
    }
  }

  static (int, int) _dayBounds(DateTime now, int daysAgo) {
    final day = DateTime(now.year, now.month, now.day - daysAgo);
    final next = DateTime(day.year, day.month, day.day + 1);
    return (day.millisecondsSinceEpoch, next.millisecondsSinceEpoch);
  }

  static bool? _boolValue(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return null;
  }

  static SqlFragment? _bool(String predicate, SmartRule rule) {
    bool? want;
    switch (rule.op) {
      case SmartOperator.isTrue:
        want = true;
      case SmartOperator.isFalse:
        want = false;
      case SmartOperator.equals:
        want = _boolValue(rule.value);
      case SmartOperator.notEquals:
        final b = _boolValue(rule.value);
        want = b == null ? null : !b;
      default:
        want = null;
    }
    if (want == null) return null;
    return SqlFragment(want ? predicate : 'NOT $predicate');
  }

  /// Reference evaluation in Dart (used for rules [compile] rejects).
  static bool evaluate(SmartRule rule, SmartRowContext c, DateTime now) {
    final op = rule.op;
    switch (rule.field) {
      case SmartField.title:
      case SmartField.artist:
      case SmartField.album:
      case SmartField.genre:
      case SmartField.source:
        final value = switch (rule.field) {
          SmartField.title => c.title,
          SmartField.artist => c.artistNorm,
          SmartField.album => c.album ?? '',
          SmartField.genre => c.genre ?? '',
          _ => c.source,
        };
        return _evalText(value, _fold(rule), op, rule.field == SmartField.artist ? c.artistNames : null);
      case SmartField.year:
        return _evalNumber(c.year, rule, 1);
      case SmartField.duration:
        return _evalNumber(c.durationMs, rule, 1000);
      case SmartField.playCount:
        return _evalNumber(c.playCount, rule, 1);
      case SmartField.lastPlayed:
      case SmartField.dateAdded:
        final ms = rule.field == SmartField.lastPlayed ? c.lastPlayed : c.dateAdded;
        return _evalDate(ms, rule, now);
      case SmartField.favorite:
      case SmartField.downloaded:
        final actual = rule.field == SmartField.favorite ? c.favorite : c.downloaded;
        return switch (op) {
          SmartOperator.isTrue => actual,
          SmartOperator.isFalse => !actual,
          SmartOperator.equals => _boolValue(rule.value) == actual,
          SmartOperator.notEquals => _boolValue(rule.value) == !actual,
          _ => false,
        };
    }
  }

  static bool _evalText(String value, String v, SmartOperator op, Set<String>? anyOf) => switch (op) {
        SmartOperator.contains => value.contains(v),
        SmartOperator.notContains => !value.contains(v),
        SmartOperator.startsWith => value.startsWith(v),
        SmartOperator.equals => value == v || (anyOf?.contains(v) ?? false),
        SmartOperator.notEquals => !(value == v || (anyOf?.contains(v) ?? false)),
        SmartOperator.greaterThan => value.compareTo(v) > 0,
        SmartOperator.lessThan => value.compareTo(v) < 0,
        SmartOperator.isTrue => value.isNotEmpty,
        SmartOperator.isFalse => value.isEmpty,
        _ => false,
      };

  static bool _evalNumber(int? actual, SmartRule rule, int scale) {
    final op = rule.op;
    if (op == SmartOperator.isTrue) return actual != null && actual != 0;
    if (op == SmartOperator.isFalse) return actual == null || actual == 0;
    final scaled = actual == null ? null : actual ~/ scale;
    final text = rule.value?.toString().trim() ?? '';
    switch (op) {
      case SmartOperator.contains:
        return scaled != null && '$scaled'.contains(text);
      case SmartOperator.notContains:
        return scaled == null || !'$scaled'.contains(text);
      case SmartOperator.startsWith:
        return scaled != null && '$scaled'.startsWith(text);
      default:
        final n = _num(rule.value);
        if (n == null) return false;
        return switch (op) {
          SmartOperator.equals => scaled != null && scaled == n.floor(),
          SmartOperator.notEquals => scaled == null || scaled != n.floor(),
          SmartOperator.greaterThan => actual != null && actual > n * scale,
          SmartOperator.lessThan => actual != null && actual < n * scale,
          _ => false,
        };
    }
  }

  static bool _evalDate(int? ms, SmartRule rule, DateTime now) {
    final op = rule.op;
    if (op == SmartOperator.isTrue) return ms != null;
    if (op == SmartOperator.isFalse) return ms == null;
    final days = _num(rule.value);
    if (days == null) return false;
    final cutoff = now.subtract(Duration(milliseconds: (days * Duration.millisecondsPerDay).round())).millisecondsSinceEpoch;
    final (start, end) = _dayBounds(now, days.floor());
    return switch (op) {
      SmartOperator.inLastDays || SmartOperator.lessThan => ms != null && ms >= cutoff,
      SmartOperator.notInLastDays || SmartOperator.greaterThan => ms == null || ms < cutoff,
      SmartOperator.equals => ms != null && ms >= start && ms < end,
      SmartOperator.notEquals => ms == null || ms < start || ms >= end,
      _ => false,
    };
  }
}
