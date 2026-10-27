import 'package:flutter/foundation.dart';

/// Purely syntactic decomposition of a title-like string into the text
/// outside brackets, the bracketed parts and the " - " separated parts.
/// No interpretation happens here; see `TitleParser` for that.
@immutable
class TextSegments {
  const TextSegments({required this.outside, required this.bracketed, required this.dashParts});

  /// Text outside any bracket, brackets replaced by a space.
  final String outside;

  /// Contents of top-level `()`, `[]`, `{}`, `【】`, `〔〕`... in order.
  /// Japanese quotation marks `「」`/`『』` are not brackets: they quote the
  /// title itself (see `TitleParser`).
  final List<String> bracketed;

  /// [outside] split on spaced dashes (" - ", " – ", "Song- Remix"). The
  /// first element is the head; it is the whole text when there is no dash.
  final List<String> dashParts;

  /// Everything that qualifies the head: bracket contents and dash tails.
  List<String> get qualifierCandidates => [...bracketed, ...dashParts.skip(1)];

  static const _open = {'(': ')', '[': ']', '{': '}', '【': '】', '〔': '〕', '（': '）', '［': '］'};

  // En/em dashes are always separators; ASCII hyphens only when spaced on at
  // least the right side ("Jay-Z", "Re-Work" stay intact).
  static final _wideDash = RegExp('\\s*[\u2013\u2014\u2015]\\s*');
  static final _dashSplit = RegExp(r'\s+-+\s+|(?<=[^\s-])-\s+');
  static final _spaces = RegExp(r'\s+');

  static TextSegments parse(String input) {
    final split = extractBrackets(input);
    return TextSegments(outside: split.$1, bracketed: split.$2, dashParts: splitDashes(split.$1));
  }

  /// Returns (text outside brackets, top-level bracket contents). Nested
  /// brackets stay inside their parent's content; an unclosed bracket runs
  /// to the end of the string (truncated titles).
  static (String, List<String>) extractBrackets(String input) {
    final outside = StringBuffer();
    final parts = <String>[];
    final stack = <String>[];
    final current = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      if (_open.containsKey(ch)) {
        if (stack.isEmpty) {
          outside.write(' ');
        } else {
          current.write(ch);
        }
        stack.add(_open[ch]!);
        continue;
      }
      if (stack.isNotEmpty && ch == stack.last) {
        stack.removeLast();
        if (stack.isEmpty) {
          final content = current.toString().trim();
          if (content.isNotEmpty) parts.add(content);
          current.clear();
          outside.write(' ');
        } else {
          current.write(ch);
        }
        continue;
      }
      if (stack.isEmpty) {
        // Stray closing brackets are dropped.
        if (!_open.containsValue(ch)) outside.write(ch);
      } else {
        current.write(ch);
      }
    }
    final rest = current.toString().trim();
    if (rest.isNotEmpty) parts.add(rest);
    return (collapse(outside.toString()), parts);
  }

  static List<String> splitDashes(String input) {
    final normalized = input.replaceAll(_wideDash, ' - ');
    return normalized.split(_dashSplit).map(collapse).where((p) => p.isNotEmpty).toList();
  }

  static String collapse(String s) => s.replaceAll(_spaces, ' ').trim();
}
