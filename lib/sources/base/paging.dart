import 'dart:convert';

import '../../core/models/catalog.dart';

/// Opaque pagination cursors shared by all providers.
///
/// Cursors are URL-safe base64 of a small JSON object, so a provider can
/// store whatever it needs (an offset, a provider "next" URL, a page token)
/// without callers depending on the format. Callers must treat cursors as
/// opaque strings and only pass back what a [Page.nextCursor] returned.
abstract final class PageCursor {
  /// Encodes arbitrary JSON-serialisable [state].
  static String encode(Map<String, Object?> state) =>
      base64Url.encode(utf8.encode(jsonEncode(state))).replaceAll('=', '');

  /// Decodes a cursor produced by [encode]. Returns null for a null cursor.
  /// Throws [FormatException] for a corrupted cursor (never silently restarts
  /// at the first page, which could make pagers loop forever).
  static Map<String, Object?>? decode(String? cursor) {
    if (cursor == null || cursor.isEmpty) return null;
    try {
      final padded = cursor.padRight(cursor.length + (4 - cursor.length % 4) % 4, '=');
      final raw = jsonDecode(utf8.decode(base64Url.decode(padded)));
      if (raw is Map) return raw.cast<String, Object?>();
    } on FormatException {
      // fall through
    }
    throw FormatException('Invalid page cursor', cursor);
  }

  /// Cursor for offset/limit (index/limit) style APIs.
  static String encodeOffset(int offset) => encode({'o': offset});

  /// Offset stored in [cursor]; 0 for a null cursor (first page).
  static int decodeOffset(String? cursor) {
    final state = decode(cursor);
    if (state == null) return 0;
    final o = state['o'];
    if (o is int && o >= 0) return o;
    throw FormatException('Cursor does not hold an offset', cursor);
  }

  /// Cursor for APIs that hand out an opaque "next" token or URL.
  static String encodeToken(String token) => encode({'t': token});

  /// Token stored in [cursor], or null for a null cursor.
  static String? decodeToken(String? cursor) {
    final state = decode(cursor);
    if (state == null) return null;
    final t = state['t'];
    if (t is String) return t;
    throw FormatException('Cursor does not hold a token', cursor);
  }

  /// Builds a page for offset-based APIs.
  ///
  /// [hasMore] wins when given (e.g. the API returned a `next` link);
  /// otherwise more pages are assumed when [total] says so, or — without a
  /// total — when the page came back full.
  ///
  /// [consumed] is the number of raw entries the API returned (before
  /// mapping dropped unusable ones); it defaults to `items.length` and is
  /// what the next offset advances by.
  static Page<T> offsetPage<T>(
    List<T> items, {
    required int offset,
    required int limit,
    int? total,
    bool? hasMore,
    int? consumed,
  }) {
    final count = consumed ?? items.length;
    final more = hasMore ?? (total != null ? offset + count < total : count >= limit && count > 0);
    return Page(items, nextCursor: more && count > 0 ? encodeOffset(offset + count) : null, total: total);
  }
}
