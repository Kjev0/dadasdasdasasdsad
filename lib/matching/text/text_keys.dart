import 'package:flutter/foundation.dart';

import 'char_folding.dart';

/// A comparison key plus its transliterated variant (see
/// [CharFolding.fold]). [alt] equals [key] when the source text had no
/// letters with a digraph spelling.
@immutable
class FoldedText {
  const FoldedText(this.key, {String? alt}) : alt = alt ?? key;

  static const empty = FoldedText('');

  final String key;
  final String alt;

  bool get isEmpty => key.isEmpty;
  bool get isNotEmpty => key.isNotEmpty;
  bool get hasAlt => alt != key;

  /// The key without spaces ("ac dc" → "acdc", "jay z" → "jayz").
  String get compact => key.replaceAll(' ', '');

  List<String> get tokens => key.isEmpty ? const [] : key.split(' ');

  @override
  bool operator ==(Object other) => other is FoldedText && other.key == key && other.alt == alt;

  @override
  int get hashCode => Object.hash(key, alt);

  @override
  String toString() => hasAlt ? '$key|$alt' : key;
}

/// Builds normalized comparison keys from free-form metadata text.
///
/// All keys are lower-case, accent-folded, contain only letters, digits and
/// single spaces, and treat `&`/`+` as "and".
abstract final class TextKeys {
  static final _apostrophes = RegExp("['`]");
  static final _dollar = RegExp(r'(?<=\p{L})\$|\$(?=\p{L})', unicode: true);
  static final _bang = RegExp(r'(?<=\p{L})!(?=\p{L})', unicode: true);
  static final _andSymbols = RegExp(r'\s*[&+]\s*');
  static final _nonAlnum = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// Number words and standalone roman numerals are mapped to digits so
  /// "Part Two", "Part II" and "Pt. 2" agree.
  static const _tokenMap = {
    'zero': '0',
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
    'eleven': '11',
    'twelve': '12',
    'thirteen': '13',
    'fourteen': '14',
    'fifteen': '15',
    'sixteen': '16',
    'seventeen': '17',
    'eighteen': '18',
    'nineteen': '19',
    'twenty': '20',
    'ii': '2',
    'iii': '3',
    'iv': '4',
    'vi': '6',
    'vii': '7',
    'viii': '8',
    'ix': '9',
    'xi': '11',
    'xii': '12',
    'pt': 'part',
    'vol': 'volume',
    // "Rock 'n' Roll", "Guns N' Roses".
    'n': 'and',
  };

  /// Trailing tokens that channel/uploader names carry but the artist does
  /// not ("Rogue - Topic", "Rogue Official", "Rogue VEVO").
  static const _artistSuffixTokens = {'vevo', 'official', 'topic'};

  /// Folded, lower-cased text with punctuation collapsed to single spaces.
  /// No token mapping; used for keyword detection.
  static String plain(String input, {bool transliterate = false}) {
    var s = CharFolding.fold(input, transliterate: transliterate);
    s = s.replaceAll(_dollar, 's').replaceAll(_bang, 'i').replaceAll(_apostrophes, '');
    s = s.replaceAll(_andSymbols, ' and ');
    return s.replaceAll(_nonAlnum, ' ').trim();
  }

  /// Key for titles and album names.
  static FoldedText title(String input) {
    final key = _mapTokens(plain(input));
    if (!CharFolding.hasTransliteration(input)) return FoldedText(key);
    return FoldedText(key, alt: _mapTokens(plain(input, transliterate: true)));
  }

  /// Key for a single artist name: "The" tokens and channel suffixes are
  /// dropped so "The Weeknd", "Weeknd" and "The Weeknd - Topic" agree.
  static FoldedText artistName(String input) {
    final key = _artistKey(input, transliterate: false);
    if (!CharFolding.hasTransliteration(input)) return FoldedText(key);
    return FoldedText(key, alt: _artistKey(input, transliterate: true));
  }

  static String _artistKey(String input, {required bool transliterate}) {
    final tokens = _mapTokens(plain(input, transliterate: transliterate)).split(' ')
      ..removeWhere((t) => t.isEmpty);
    while (tokens.length > 1 && _artistSuffixTokens.contains(tokens.last)) {
      tokens.removeLast();
    }
    if (tokens.isNotEmpty && tokens.last.length > 6 && tokens.last.endsWith('vevo')) {
      tokens[tokens.length - 1] = tokens.last.substring(0, tokens.last.length - 4);
    }
    final withoutThe = tokens.where((t) => t != 'the').toList();
    return (withoutThe.isEmpty ? tokens : withoutThe).join(' ');
  }

  static String _mapTokens(String plain) {
    if (plain.isEmpty) return plain;
    return plain.split(' ').map((t) => _tokenMap[t] ?? t).join(' ');
  }
}
