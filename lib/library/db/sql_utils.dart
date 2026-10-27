/// Small helpers for building SQL with bound parameters.
library;

/// Android's system SQLite (< 3.32) allows at most 999 bound variables, so
/// `IN (...)` lists are split into chunks of this size.
const int sqlChunkSize = 500;

/// `?, ?, ?` for [n] parameters.
String placeholders(int n) => List.filled(n, '?').join(', ');

/// Splits [items] into lists of at most [size] elements.
Iterable<List<T>> chunked<T>(List<T> items, [int size = sqlChunkSize]) sync* {
  for (var i = 0; i < items.length; i += size) {
    yield items.sublist(i, i + size > items.length ? items.length : i + size);
  }
}

/// Escapes `%`, `_` and `\` for `LIKE ... ESCAPE '\'`.
String escapeLike(String s) => s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

/// Milliseconds since epoch (UTC).
int nowMs() => DateTime.now().millisecondsSinceEpoch;

DateTime? msToDate(Object? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());

int boolInt(bool b) => b ? 1 : 0;

bool intBool(Object? v) => v != null && (v as num) != 0;
