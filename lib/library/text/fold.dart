/// Accent-, case- and punctuation-insensitive text folding used for the
/// library's `*_norm` columns and for search queries.
///
/// SQLite (as shipped by Android) has no Unicode-aware `LOWER()` and sqflite
/// cannot register custom SQL functions, so the folding happens in Dart and
/// the folded text is stored next to the original.
///
/// Rules:
/// * lower-case;
/// * Latin diacritics are removed (`é → e`, `ü → u`, `ñ → n`, ...);
/// * ligatures and special letters are expanded (`æ → ae`, `œ → oe`,
///   `ß → ss`, `þ → th`); `ø → o`, `å → a`;
/// * runs of `a` collapse to one `a`, so the Danish spellings `å`, `aa` and
///   `a` all match each other (`Århus`, `Aarhus` and `Arhus` fold to `arhus`);
/// * apostrophes are dropped (`don't → dont`), other punctuation becomes a
///   space, whitespace is collapsed and trimmed.
///
/// Letters from non-Latin scripts are kept (lower-cased).
String foldForSearch(String? input) {
  if (input == null || input.isEmpty) return '';
  final lower = input.toLowerCase();
  final out = StringBuffer();
  var lastWasSpace = true;
  for (final rune in lower.runes) {
    final mapped = _foldMap[rune];
    if (mapped != null) {
      if (mapped.isEmpty) continue;
      out.write(mapped);
      lastWasSpace = false;
      continue;
    }
    if (_isApostrophe(rune)) continue;
    if (_isWordChar(rune)) {
      out.writeCharCode(rune);
      lastWasSpace = false;
    } else if (!lastWasSpace) {
      out.write(' ');
      lastWasSpace = true;
    }
  }
  var s = out.toString().trimRight();
  // Danish/Norwegian: "aa" is the old spelling of "å" (folded to "a").
  if (s.contains('aa')) s = s.replaceAll(_aRun, 'a');
  return s;
}

/// Splits folded text into search tokens.
List<String> searchTokens(String? input) {
  final folded = foldForSearch(input);
  if (folded.isEmpty) return const [];
  return folded.split(' ').where((t) => t.isNotEmpty).toList();
}

final _aRun = RegExp('a{2,}');

bool _isApostrophe(int r) => r == 0x27 || r == 0x2019 || r == 0x2018 || r == 0x60 || r == 0xB4 || r == 0x02BC;

bool _isWordChar(int r) {
  if (r >= 0x30 && r <= 0x39) return true; // 0-9
  if (r >= 0x61 && r <= 0x7A) return true; // a-z
  if (r < 0x80) return false; // other ASCII is punctuation/space
  // General punctuation, symbols, spaces in the BMP blocks commonly found in
  // tags. Everything else (letters of other scripts, CJK, ...) is kept.
  if (r >= 0x2000 && r <= 0x2BFF) return false; // punctuation, arrows, symbols
  if (r >= 0x3000 && r <= 0x303F) return false; // CJK punctuation
  if (r >= 0xFE30 && r <= 0xFE4F) return false;
  if (r >= 0xFF00 && r <= 0xFF0F) return false; // full-width punctuation
  if (r >= 0x80 && r <= 0xBF) return false; // Latin-1 punctuation (¡ « » ¿ ...)
  if (r == 0xD7 || r == 0xF7) return false; // × ÷
  return true;
}

final Map<int, String> _foldMap = _buildFoldMap();

Map<int, String> _buildFoldMap() {
  final m = <int, String>{};
  void add(String chars, String to) {
    for (final r in chars.runes) {
      m[r] = to;
    }
  }

  add('àáâãäāăąǎȁȃạảấầẩẫậắằẳẵặ', 'a');
  add('å', 'a');
  add('æǣǽ', 'ae');
  add('çćĉċč', 'c');
  add('ďđ', 'd');
  add('ð', 'd');
  add('èéêëēĕėęěȅȇẹẻẽếềểễệ', 'e');
  add('ĝğġģ', 'g');
  add('ĥħ', 'h');
  add('ìíîïĩīĭįıǐȉȋịỉ', 'i');
  add('ĳ', 'ij');
  add('ĵ', 'j');
  add('ķ', 'k');
  add('ĺļľŀł', 'l');
  add('ñńņňŉ', 'n');
  add('òóôõöōŏőǒȍȏọỏốồổỗộớờởỡợơ', 'o');
  add('øǿ', 'o');
  add('œ', 'oe');
  add('ŕŗř', 'r');
  add('śŝşšș', 's');
  add('ß', 'ss');
  add('ţťŧț', 't');
  add('þ', 'th');
  add('ùúûüũūŭůűųǔǖǘǚǜưừứửữựụủ', 'u');
  add('ŵ', 'w');
  add('ýÿŷỳỵỷỹ', 'y');
  add('źżž', 'z');
  // Combining diacritical marks (decomposed input) are dropped.
  for (var r = 0x0300; r <= 0x036F; r++) {
    m[r] = '';
  }
  return m;
}
