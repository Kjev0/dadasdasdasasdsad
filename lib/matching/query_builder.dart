import 'normalizer.dart';
import 'text/char_folding.dart';
import 'text/segments.dart';

/// Builds the metadata search queries used to find an original on a target
/// source, most specific first.
class SearchQueryBuilder {
  const SearchQueryBuilder({
    this.uploaderStyleSources = TrackNormalizer.defaultUploaderStyleSources,
    this.maxQueries = 3,
  });

  /// Sources where uploads are commonly titled "Artist - Title" and an extra
  /// "title + artist" query helps their text search.
  final Set<String> uploaderStyleSources;
  final int maxQueries;

  // Characters that some providers interpret as query syntax
  // (Spotify "artist:", quotes, boolean operators).
  static final _syntax = RegExp(r'["“”:*\\(){}\[\]|]');

  /// Queries for [original] on [targetSourceId]:
  /// 1. "primary artist + clean title (+ version qualifiers)"
  /// 2. "clean title (+ version qualifiers)"
  /// 3. uploader-style targets only: "title + artist"
  ///
  /// Version qualifiers of significant versions ("Kygo Remix", "Live") are
  /// kept so a remix is searched as a remix; remaster/radio-edit qualifiers
  /// and album names are never added (they narrow searches too much).
  List<String> build(NormalizedTrack original, String targetSourceId) {
    final reading = original.primary;
    final title = _clean(reading.displayTitle);
    final artist = _clean(reading.displayArtist);
    final version = _clean(original.versionQualifiers.join(' '));
    final titleWithVersion = _join([title, version]);

    final queries = <String>[
      if (artist.isNotEmpty) _join([artist, titleWithVersion]),
      titleWithVersion,
      if (artist.isNotEmpty && uploaderStyleSources.contains(targetSourceId)) _join([titleWithVersion, artist]),
    ];
    final seen = <String>{};
    return [
      for (final q in queries)
        if (q.isNotEmpty && seen.add(q.toLowerCase())) q,
    ].take(maxQueries).toList();
  }

  /// A single query from free text typed by the user (symbols stripped).
  static String sanitize(String text) => _clean(text);

  static String _clean(String text) =>
      TextSegments.collapse(CharFolding.stripSymbols(text).replaceAll(_syntax, ' '));

  static String _join(List<String> parts) => TextSegments.collapse(parts.where((p) => p.isNotEmpty).join(' '));
}
