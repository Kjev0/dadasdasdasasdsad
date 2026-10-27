/// Lookup-table based accent and compatibility folding.
///
/// Dart has no built-in Unicode normalization (NFKD), so this approximates
/// "NFKD + drop combining marks + compatibility mapping" for what matters in
/// music metadata: Latin letters with diacritics, Nordic and German letters,
/// typographic punctuation, full-width forms, ligatures and super/subscript
/// digits. Emoji and decorative symbols are replaced by a space. Non-Latin
/// scripts (Cyrillic, Greek, CJK, ...) pass through unchanged so they still
/// compare equal to themselves.
abstract final class CharFolding {
  /// Lower-cases and folds [input].
  ///
  /// Letters that have a conventional two-letter spelling are folded to the
  /// bare base letter by default (ä→a, ö→o, ø→o, ü→u, å→a). With
  /// [transliterate] they use the digraph instead (ä→ae, ö/ø→oe, ü→ue,
  /// å→aa). Comparing both forms lets "Mø" match both "MO" and "Moe", and
  /// "Ålborg" match "Aalborg", without making unrelated digraphs equal.
  /// `æ` is always `ae`, `œ` always `oe`, `ß` always `ss`.
  static String fold(String input, {bool transliterate = false}) {
    final out = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      if (rune < 0x80) {
        out.writeCharCode(rune);
        continue;
      }
      if (transliterate) {
        final t = _transliterations[rune];
        if (t != null) {
          out.write(t);
          continue;
        }
      }
      final mapped = _table[rune];
      if (mapped != null) {
        out.write(mapped);
        continue;
      }
      if (isInvisible(rune) || isCombiningMark(rune)) continue;
      if (rune >= 0xFF01 && rune <= 0xFF5E) {
        // Full-width ASCII variants (ＡＢＣ, ！, ＆ ...).
        out.write(String.fromCharCode(rune - 0xFEE0).toLowerCase());
        continue;
      }
      if (isSpace(rune) || isSymbolOrEmoji(rune)) {
        out.write(' ');
        continue;
      }
      out.writeCharCode(rune);
    }
    return out.toString();
  }

  /// Whether folding [input] with and without transliteration can differ.
  static bool hasTransliteration(String input) =>
      input.toLowerCase().runes.any(_transliterations.containsKey);

  /// Removes emoji, pictographs and decorative symbols but keeps letters,
  /// case and accents. Used for human-readable (search query) text.
  static String stripSymbols(String input) {
    final out = StringBuffer();
    for (final rune in input.runes) {
      if (isInvisible(rune)) continue;
      if (isSymbolOrEmoji(rune) || isSpace(rune)) {
        out.write(' ');
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  static bool isCombiningMark(int r) =>
      (r >= 0x0300 && r <= 0x036F) ||
      (r >= 0x1AB0 && r <= 0x1AFF) ||
      (r >= 0x1DC0 && r <= 0x1DFF) ||
      (r >= 0x20D0 && r <= 0x20FF) ||
      (r >= 0xFE20 && r <= 0xFE2F);

  /// Zero-width characters, variation selectors and emoji tag characters.
  static bool isInvisible(int r) =>
      (r >= 0x200B && r <= 0x200F) ||
      r == 0x2060 ||
      r == 0xFEFF ||
      (r >= 0xFE00 && r <= 0xFE0F) ||
      (r >= 0xE0000 && r <= 0xE007F) ||
      r == 0x00AD; // soft hyphen

  static bool isSpace(int r) =>
      r == 0x00A0 || (r >= 0x2000 && r <= 0x200A) || r == 0x202F || r == 0x205F || r == 0x3000 || r == 0x1680;

  /// Emoji, pictographs, arrows, dingbats, music notes, stars, ©/®/™ ...
  static bool isSymbolOrEmoji(int r) =>
      r == 0x00A9 ||
      r == 0x00AE ||
      r == 0x2122 ||
      r == 0x2117 || // ℗
      r == 0x3030 ||
      r == 0x303D ||
      (r >= 0x2190 && r <= 0x21FF) ||
      (r >= 0x2300 && r <= 0x23FF) ||
      (r >= 0x25A0 && r <= 0x27BF) ||
      (r >= 0x2900 && r <= 0x297F) ||
      (r >= 0x2B00 && r <= 0x2BFF) ||
      (r >= 0x1F000 && r <= 0x1FAFF);

  static final Map<int, String> _transliterations = {
    for (final r in 'äæ'.runes) r: 'ae',
    for (final r in 'öøœǿ'.runes) r: 'oe',
    for (final r in 'ü'.runes) r: 'ue',
    for (final r in 'å'.runes) r: 'aa',
  };

  static final Map<int, String> _table = _buildTable();

  static Map<int, String> _buildTable() {
    final m = <int, String>{};
    void group(String target, String chars) {
      for (final r in chars.runes) {
        m[r] = target;
      }
    }

    // Latin letters with diacritics (lower case only: input is lower-cased).
    group('a', 'àáâãäåāăąǎǟǡǻȁȃȧạảấầẩẫậắằẳẵặⱥ');
    group('b', 'ḃḅḇƀ');
    group('c', 'çćĉċčƈȼḉ');
    group('d', 'ďđɗḋḍḏḑḓð');
    group('e', 'èéêëēĕėęěȅȇȩẹẻẽếềểễệɇḕḗḙḛḝ');
    group('f', 'ḟƒ');
    group('g', 'ĝğġģǧǵḡǥ');
    group('h', 'ĥħḣḥḧḩḫ');
    group('i', 'ìíîïĩīĭįıǐȉȋịỉḭḯ');
    group('j', 'ĵǰ');
    group('k', 'ķǩĸḱḳḵ');
    group('l', 'ĺļľŀłƚḷḹḻḽ');
    group('m', 'ḿṁṃ');
    group('n', 'ñńņňŉŋǹṅṇṉṋ');
    group('o', 'òóôõöøōŏőǒǫǭȍȏȫȭȯȱọỏốồổỗộớờởỡợơǿṍṏṑṓ');
    group('p', 'ṕṗ');
    group('r', 'ŕŗřȑȓṙṛṝṟ');
    group('s', 'śŝşšșſṡṣṥṧṩ');
    group('t', 'ţťŧțṫṭṯṱẗ');
    group('u', 'ùúûüũūŭůűųǔǖǘǚǜȕȗưụủứừửữựṳṵṷṹṻ');
    group('v', 'ṽṿ');
    group('w', 'ŵẁẃẅẇẉẘ');
    group('x', 'ẋẍ');
    group('y', 'ýÿŷỳỵỷỹẏẙ');
    group('z', 'źżžƶẑẓẕ');

    // Letters that are digraphs in ASCII.
    m[0x00DF] = 'ss'; // ß
    m[0x00E6] = 'ae'; // æ
    m[0x01FD] = 'ae'; // ǽ
    m[0x0153] = 'oe'; // œ
    m[0x00FE] = 'th'; // þ
    m[0x0133] = 'ij'; // ĳ

    // Cyrillic ё/й are commonly written without the diacritic.
    m[0x0451] = 'е';
    m[0x0439] = 'и';

    // Ligatures.
    m[0xFB00] = 'ff';
    m[0xFB01] = 'fi';
    m[0xFB02] = 'fl';
    m[0xFB03] = 'ffi';
    m[0xFB04] = 'ffl';
    m[0xFB05] = 'st';
    m[0xFB06] = 'st';

    // Typographic punctuation.
    group("'", '‘’‚‛′´ʼʹ');
    group('"', '“”„‟″«»‹›');
    group('-', '‐‑‒–—―−﹘﹣');
    m[0x2026] = '...'; // …
    m[0x00D7] = ' x '; // × (artist separator, "A × B")
    m[0x2715] = ' x '; // ✕
    m[0x00B7] = ' '; // ·
    m[0x2022] = ' '; // •

    // Super-/subscript digits and vulgar fractions.
    const sup = '⁰¹²³⁴⁵⁶⁷⁸⁹';
    const sub = '₀₁₂₃₄₅₆₇₈₉';
    for (var i = 0; i < 10; i++) {
      m[sup.runes.elementAt(i)] = '$i';
      m[sub.runes.elementAt(i)] = '$i';
    }
    m[0x00BD] = ' 1/2';
    m[0x00BC] = ' 1/4';
    m[0x00BE] = ' 3/4';
    return m;
  }
}
