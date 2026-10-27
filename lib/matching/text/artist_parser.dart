import 'package:flutter/foundation.dart';

import '../../core/models/track.dart';
import 'segments.dart';

/// Artist names split into the main credit and featured guests (display
/// text, not yet normalized).
@immutable
class ArtistSplit {
  const ArtistSplit({this.primary = const [], this.featured = const []});

  final List<String> primary;
  final List<String> featured;

  bool get isEmpty => primary.isEmpty && featured.isEmpty;
}

/// Splits artist credits on collaboration separators.
///
/// Splitting is a canonicalization applied identically to both sides of a
/// comparison: "Simon & Garfunkel", "Simon and Garfunkel" and
/// ["Simon", "Garfunkel"] all become {simon, garfunkel}; the scorer also
/// compares the joined credit line, so bands whose names contain a
/// separator ("Tyler, The Creator") still match unsplit spellings.
abstract final class ArtistParser {
  /// "A feat. B", "A ft B", "A featuring B", "A w/ B", "A with B".
  static final featSeparator = RegExp(r'\s+(?:feat\.?|ft\.?|featuring|w/|with)\s+', caseSensitive: false);

  /// "A & B", "A and B", "A og B" (da/no), "A och B" (sv), "A und B" (de),
  /// "A et B" (fr), "A y B" (es), "A + B", "A x B", "A × B", "A vs. B",
  /// "A, B", "A; B", "A / B" (spaced only: "AC/DC" stays intact).
  static final separator = RegExp(
    r'\s*[,;]\s*|\s+/\s+|\s+(?:&|and|og|och|und|et|y|\+|x|×|vs\.?|versus)\s+|\s*[&+×]\s*(?=\S)',
    caseSensitive: false,
  );

  static final _featLead = RegExp(r'^(?:feat\.?|ft\.?|featuring|with|w/)\s+(.+)$', caseSensitive: false);

  /// Splits one credit string ("Rogue feat. Kygo & Mø") into primary and
  /// featured names.
  static ArtistSplit split(String credit) {
    final (outside, brackets) = TextSegments.extractBrackets(credit);
    final featured = <String>[];
    for (final b in brackets) {
      final m = _featLead.firstMatch(b);
      if (m != null) featured.addAll(splitNames(m[1]!));
    }
    final groups = outside.split(featSeparator);
    final primary = splitNames(groups.first);
    for (final g in groups.skip(1)) {
      featured.addAll(splitNames(g));
    }
    return ArtistSplit(primary: primary, featured: featured);
  }

  /// Splits on separators only (every name has the same role).
  static List<String> splitNames(String names) =>
      names.split(separator).map((n) => TextSegments.collapse(n)).where((n) => n.isNotEmpty).toList();

  /// Splits a track's artist list: the first credit is the main artist
  /// (possibly a collaboration), later credits are featured.
  static ArtistSplit splitRefs(List<ArtistRef> artists) {
    if (artists.isEmpty) return const ArtistSplit();
    final first = split(artists.first.name);
    final featured = [...first.featured];
    for (final a in artists.skip(1)) {
      final s = split(a.name);
      featured
        ..addAll(s.primary)
        ..addAll(s.featured);
    }
    return ArtistSplit(primary: first.primary, featured: featured);
  }
}
