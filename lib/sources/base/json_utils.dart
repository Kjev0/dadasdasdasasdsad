/// Tolerant accessors for decoded JSON (`Object?` trees from `jsonDecode`).
///
/// Provider APIs are not always consistent about types (numbers as strings,
/// `null` vs missing keys, empty strings for "no value"). These helpers keep
/// mappers short and never throw on unexpected shapes.
library;

/// Returns [value] as a JSON object, or an empty map.
Map<String, Object?> asJsonMap(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const <String, Object?>{};

/// Returns [value] as a JSON object, or null when it is not one.
Map<String, Object?>? asJsonMapOrNull(Object? value) => value is Map ? value.cast<String, Object?>() : null;

/// Returns [value] as a list of JSON objects (non-object entries are skipped).
List<Map<String, Object?>> asJsonMapList(Object? value) => value is List
    ? [
        for (final e in value)
          if (e is Map) e.cast<String, Object?>(),
      ]
    : const <Map<String, Object?>>[];

/// A non-empty trimmed string, or null.
String? jsonString(Object? value) {
  if (value == null) return null;
  final s = value is String ? value : (value is num || value is bool ? value.toString() : null);
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}

/// An int from a number or a numeric string, or null.
int? jsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? double.tryParse(value.trim())?.toInt();
  return null;
}

/// A double from a number or a numeric string, or null.
double? jsonDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// A bool from a bool, 0/1 or "true"/"false", or null.
bool? jsonBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
        return true;
      case 'false':
      case '0':
        return false;
    }
  }
  return null;
}

/// An absolute http(s) URI, or null for empty/invalid values.
Uri? jsonHttpUri(Object? value) {
  final s = jsonString(value);
  if (s == null) return null;
  final uri = Uri.tryParse(s);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) return null;
  return uri;
}

/// Parses ISO-8601 dates as well as plain `yyyy-MM-dd` / `yyyy-MM-dd HH:mm:ss`.
DateTime? jsonDate(Object? value) {
  final s = jsonString(value);
  if (s == null) return null;
  return DateTime.tryParse(s) ?? DateTime.tryParse(s.replaceFirst(' ', 'T'));
}

/// The year of a date string (`2001-03-12` → 2001), or null.
int? jsonYear(Object? value) {
  final date = jsonDate(value);
  if (date != null) return date.year;
  final s = jsonString(value);
  if (s != null && s.length >= 4) {
    final y = int.tryParse(s.substring(0, 4));
    if (y != null && y > 1000) return y;
  }
  return null;
}
