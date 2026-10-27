import '../../core/contracts/discovery.dart';

/// Result of parsing an LRC document.
class ParsedLrc {
  const ParsedLrc({required this.lines, required this.tags, required this.offset, required this.plainLines});

  /// Time-synced lines sorted by time (offset applied, never negative).
  /// Empty text marks an instrumental gap.
  final List<LyricsLine> lines;

  /// ID tags (`ar`, `ti`, `al`, `by`, `length`, `offset`, …), lowercased keys.
  final Map<String, String> tags;

  /// `[offset:±ms]` — positive values show lyrics earlier.
  final Duration offset;

  /// Lines without any timestamp (and not tags), in order.
  final List<String> plainLines;

  bool get isSynced => lines.isNotEmpty;

  /// Plain text: synced lines in order, or the untimed lines.
  String get plainText {
    final source = isSynced ? lines.map((l) => l.text) : plainLines;
    return source.join('\n').trim();
  }
}

/// Parser for LRC lyrics (simple and "enhanced" A2 flavour).
///
/// Supports:
/// * several timestamps on one line (`[00:12.00][01:02.50]Chorus`),
/// * `mm:ss`, `mm:ss.x`, `mm:ss.xx`, `mm:ss.xxx`, `mm:ss:xx` and
///   `h:mm:ss.xx`; minutes above 59 (`[75:01.00]`),
/// * ID tags (`[ar:]`, `[ti:]`, `[al:]`, `[by:]`, `[length:]`, `[re:]`,
///   `[ve:]`, `[#:comment]`) and `[offset:+/-ms]` (positive = earlier),
/// * enhanced word timings (`<00:12.30>word`) which are stripped,
/// * BOM, CRLF/CR line endings, blank lines, lines without timestamps.
abstract final class LrcParser {
  static final _timestamp = RegExp(r'^\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

  /// `[h:mm:ss.xx]` — needs the `.` fraction so `[mm:ss:xx]` stays minutes.
  static final _hourTimestamp = RegExp(r'^\[(\d{1,2}):(\d{2}):(\d{2})\.(\d{1,3})\]');
  static final _tag = RegExp(r'^\[([a-zA-Z#][a-zA-Z0-9#_-]*):([^\]]*)\]\s*$');
  static final _wordTiming = RegExp(r'<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>');

  /// Whether [text] contains at least one LRC timestamp line.
  static bool looksLikeLrc(String text) {
    for (final raw in _splitLines(text)) {
      if (_timestamp.hasMatch(raw.trimLeft()) || _hourTimestamp.hasMatch(raw.trimLeft())) return true;
    }
    return false;
  }

  static List<String> _splitLines(String text) {
    var t = text;
    if (t.startsWith('﻿')) t = t.substring(1);
    return t.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  }

  static ParsedLrc parse(String text) {
    final tags = <String, String>{};
    final timed = <(Duration, int, String)>[];
    final plain = <String>[];
    var order = 0;
    for (final raw in _splitLines(text)) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      final stamps = <Duration>[];
      while (true) {
        final h = _hourTimestamp.firstMatch(line);
        if (h != null) {
          stamps.add(Duration(
            hours: int.parse(h.group(1)!),
            minutes: int.parse(h.group(2)!),
            seconds: int.parse(h.group(3)!),
            milliseconds: _fraction(h.group(4)),
          ));
          line = line.substring(h.end);
          continue;
        }
        final m = _timestamp.firstMatch(line);
        if (m == null) break;
        final seconds = int.parse(m.group(2)!);
        if (seconds > 59) break;
        stamps.add(Duration(
          minutes: int.parse(m.group(1)!),
          seconds: seconds,
          milliseconds: _fraction(m.group(3)),
        ));
        line = line.substring(m.end);
      }
      if (stamps.isEmpty) {
        final tag = _tag.firstMatch(line);
        if (tag != null) {
          tags[tag.group(1)!.toLowerCase()] = tag.group(2)!.trim();
        } else {
          plain.add(line.replaceAll(_wordTiming, '').trim());
        }
        continue;
      }
      final content = line.replaceAll(_wordTiming, '').replaceAll(RegExp(r'\s+'), ' ').trim();
      for (final s in stamps) {
        timed.add((s, order++, content));
      }
    }
    final offsetMs = int.tryParse((tags['offset'] ?? '').replaceAll('+', '').trim()) ?? 0;
    final offset = Duration(milliseconds: offsetMs);
    timed.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    final lines = [
      for (final t in timed)
        LyricsLine(t.$1 - offset < Duration.zero ? Duration.zero : t.$1 - offset, t.$3),
    ];
    return ParsedLrc(lines: lines, tags: tags, offset: offset, plainLines: plain);
  }

  /// `5` → 500 ms, `50` → 500 ms, `500` → 500 ms.
  static int _fraction(String? digits) {
    if (digits == null || digits.isEmpty) return 0;
    final v = int.parse(digits);
    return switch (digits.length) { 1 => v * 100, 2 => v * 10, _ => v };
  }
}
