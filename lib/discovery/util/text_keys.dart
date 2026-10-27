import '../../core/models/track.dart';

/// Normalized comparison keys (case-, diacritics- and punctuation-insensitive)
/// used to dedupe recommendations and to compare tracks across providers.
///
/// Deliberately simple: the full matcher lives in `lib/matching`, discovery
/// only needs "is this obviously the same song / artist".
abstract final class TextKeys {
  static const _folds = <String, String>{
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
    'æ': 'ae', 'ç': 'c', 'ć': 'c', 'č': 'c', 'ď': 'd', 'đ': 'd',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ę': 'e', 'ě': 'e',
    'ğ': 'g', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ı': 'i',
    'ł': 'l', 'ñ': 'n', 'ń': 'n', 'ň': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o', 'œ': 'oe',
    'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's', 'ß': 'ss', 'ť': 't', 'ţ': 't',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
    'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
    // Typographic apostrophes/quotes seen in provider metadata.
    '’': "'", '‘': "'", '“': '"', '”': '"',
  };

  static final _nonWord = RegExp(r"[^\p{L}\p{N}]+", unicode: true);
  static final _spaces = RegExp(r'\s+');

  /// Bracketed segments that do not change which song it is.
  static final _noiseBrackets = RegExp(
    r'[\(\[][^\)\]]*\b(feat|ft|featuring|with|remaster(ed)?|radio edit|single version|album version|explicit|clean|mono|stereo|official|audio|video|lyrics?)\b[^\)\]]*[\)\]]',
    caseSensitive: false,
  );
  static final _dashSuffix = RegExp(r'\s+-\s+.*\b(remaster(ed)?|radio edit|single version|mono|stereo)\b.*$', caseSensitive: false);
  static final _featTail = RegExp(r'\s+(feat\.?|ft\.?|featuring)\s+.*$', caseSensitive: false);

  /// Lowercase, fold diacritics, `&` → `and`, punctuation → spaces.
  static String normalize(String input) {
    final lower = input.toLowerCase();
    final b = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      b.write(_folds[ch] ?? ch);
    }
    return b
        .toString()
        .replaceAll('&', ' and ')
        .replaceAll("'", '')
        .replaceAll(_nonWord, ' ')
        .replaceAll(_spaces, ' ')
        .trim();
  }

  /// Title key without "(feat. …)", "[Remastered 2011]", " - Radio Edit".
  static String title(String title) {
    final n = normalize(stripNoise(title));
    return n.isEmpty ? normalize(title) : n;
  }

  /// [title] without feature/remaster/video noise, case and punctuation
  /// kept (for queries to other services).
  static String stripNoise(String title) {
    final t = title
        .replaceAll(_noiseBrackets, ' ')
        .replaceAll(_dashSuffix, '')
        .replaceAll(_featTail, '')
        .replaceAll(_spaces, ' ')
        .trim();
    return t.isEmpty ? title.trim() : t;
  }

  /// Artist key; a leading "the " is ignored ("The Beatles" == "Beatles").
  static String artist(String name) {
    final n = normalize(name.replaceAll(_featTail, ''));
    return n.startsWith('the ') ? n.substring(4) : n;
  }

  /// `<artist>|<title>` — same song regardless of provider.
  static String track(Track t) => '${artist(t.primaryArtist)}|${title(t.title)}';

  /// Genre key ("Hip-Hop/Rap" → "hip hop rap").
  static String genre(String genre) => normalize(genre);

  /// Splits a free-form genre tag ("Electronic; House / Techno") into parts.
  static List<String> splitGenres(String? raw) {
    if (raw == null) return const [];
    return [
      for (final part in raw.split(RegExp(r'[;,|]')))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  /// Loose equality: equal, or one contains the other as whole words.
  static bool looselyEqual(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    return ' $a '.contains(' $b ') || ' $b '.contains(' $a ');
  }
}
