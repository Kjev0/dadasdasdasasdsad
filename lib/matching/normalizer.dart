import 'package:flutter/foundation.dart';

import '../core/models/track.dart';
import '../core/sources/source_ids.dart';
import 'similarity.dart';
import 'text/artist_parser.dart';
import 'text/char_folding.dart';
import 'text/segments.dart';
import 'text/text_keys.dart';
import 'text/title_parser.dart';
import 'version_detector.dart';

export 'text/artist_parser.dart' show ArtistParser, ArtistSplit;
export 'text/char_folding.dart' show CharFolding;
export 'text/text_keys.dart' show FoldedText, TextKeys;
export 'text/title_parser.dart' show TitleParser, TitleParts;

/// One interpretation of a track's title/artist metadata.
///
/// Most tracks have exactly one reading. Titles of the form "X - Y" get a
/// second one where X is the artist and Y the title, because uploader-style
/// sources (SoundCloud, YouTube) often publish "Artist - Title" from a label
/// or channel account. The scorer compares every pair of readings and keeps
/// the best, so the right interpretation wins without guessing up front.
@immutable
class TrackReading {
  const TrackReading({
    required this.title,
    required this.displayTitle,
    required this.primaryArtists,
    required this.featuredArtists,
    required this.displayArtist,
    this.isArtistTitleSplit = false,
  });

  /// Normalized base title (no qualifiers, featured credits or noise).
  final FoldedText title;

  /// Cleaned title in display form (for search queries).
  final String displayTitle;
  final List<FoldedText> primaryArtists;

  /// Featured artists from the artist list *and* from "(feat. X)" in the
  /// title, de-duplicated.
  final List<FoldedText> featuredArtists;

  /// Main artist in display form ('' when unknown).
  final String displayArtist;

  /// Whether this reading parsed the artist out of an "Artist - Title" title.
  final bool isArtistTitleSplit;
}

/// A [Track] with everything the scorer and query builder need, computed
/// once.
@immutable
class NormalizedTrack {
  const NormalizedTrack({
    required this.track,
    required this.readings,
    required this.version,
    required this.versionQualifiers,
    required this.album,
    required this.albumIsSingle,
    required this.explicit,
    required this.isrc,
  });

  final Track track;

  /// Preferred reading first; never empty.
  final List<TrackReading> readings;
  final VersionInfo version;

  /// Display text of the qualifiers that make this a significantly different
  /// version ("Kygo Remix", "Live at Wembley"); added to search queries.
  final List<String> versionQualifiers;

  /// Normalized album title without edition words, or null.
  final FoldedText? album;

  /// "- Single"/"- EP" releases, or albums named like the track itself.
  final bool albumIsSingle;

  /// [Track.explicit], or the "(Explicit)"/"(Clean)" title hint.
  final bool? explicit;

  /// Upper-case ISRC without separators, or null.
  final String? isrc;

  TrackReading get primary => readings.first;
}

/// Normalizes track metadata for matching: accent and case folding,
/// punctuation, featured-artist extraction, qualifier extraction, version
/// detection and "Artist - Title" parsing.
class TrackNormalizer {
  const TrackNormalizer({
    this.uploaderStyleSources = defaultUploaderStyleSources,
    this.parser = const TitleParser(),
    this.detector = const VersionDetector(),
  });

  /// Sources where tracks are uploaded by accounts that are frequently not
  /// the artist (labels, channels, fans), so "X - Y" titles are read as
  /// "Artist - Title" first.
  static const defaultUploaderStyleSources = {SourceIds.soundcloud, SourceIds.youtube, SourceIds.audius};

  final Set<String> uploaderStyleSources;
  final TitleParser parser;
  final VersionDetector detector;

  static final _isrcJunk = RegExp(r'[\s\-_.]');

  /// Trailing album words that name an edition rather than the album.
  static const _editionTokens = {
    'deluxe', 'edition', 'expanded', 'remastered', 'remaster', 'anniversary', 'version', 'special', 'bonus',
    'track', 'tracks', 'super', 'collectors', 'ep', 'single', 'lp', 'reissue', 'complete', 'legacy',
  };

  static String? normalizeIsrc(String? isrc) {
    if (isrc == null) return null;
    final n = isrc.toUpperCase().replaceAll(_isrcJunk, '');
    return n.isEmpty ? null : n;
  }

  /// Normalized form of one artist name (see [TextKeys.artistName]).
  static FoldedText artistKey(String name) => TextKeys.artistName(name);

  /// Normalized form of a title (see [TextKeys.title]).
  static FoldedText titleKey(String title) => TextKeys.title(title);

  NormalizedTrack normalize(Track track) {
    final parts = parser.parse(track.title);
    final credits = ArtistParser.splitRefs(track.artists);
    final titleFeatured = parts.featured.expand(ArtistParser.splitNames).toList();

    final primaryKeys = _keys(credits.primary);
    final readingA = TrackReading(
      title: TextKeys.title(parts.base),
      displayTitle: parts.base,
      primaryArtists: primaryKeys,
      featuredArtists: _dedupe([..._keys(credits.featured), ..._keys(titleFeatured)], exclude: primaryKeys),
      displayArtist: credits.primary.isEmpty ? '' : _displayArtist(credits.primary.first),
    );

    var readings = [readingA];
    if (parts.hasArtistTitleSplit) {
      final left = ArtistParser.split(parts.splitArtist!);
      final leftPrimary = _keys(left.primary);
      final readingB = TrackReading(
        title: TextKeys.title(parts.splitTitle!),
        displayTitle: parts.splitTitle!,
        primaryArtists: leftPrimary,
        featuredArtists: _dedupe([..._keys(left.featured), ..._keys(titleFeatured)], exclude: leftPrimary),
        displayArtist: left.primary.isEmpty ? '' : left.primary.first,
        isArtistTitleSplit: true,
      );
      final uploaderIsArtist = primaryKeys.any(
        (u) => [...leftPrimary, ..._keys(left.featured)].any((l) => Similarity.foldedName(u, l) >= 0.9),
      );
      final preferSplit =
          uploaderStyleSources.contains(track.sourceId) || uploaderIsArtist || track.artists.isEmpty;
      readings = preferSplit ? [readingB, readingA] : [readingA, readingB];
    }

    final version = detector
        .detectSegments(parts.qualifiers)
        .merge(VersionInfo(explicitHint: parts.explicitHint))
        .merge(detector.detectInAlbum(track.album));
    final versionQualifiers = [
      for (final q in parts.qualifiers)
        if (detector.detectSegment(q).isSignificant) q,
    ];

    final (album, albumIsSingle) = _album(track.album, readingA.title, readings.last.title);

    return NormalizedTrack(
      track: track,
      readings: List.unmodifiable(readings),
      version: version,
      versionQualifiers: List.unmodifiable(versionQualifiers),
      album: album,
      albumIsSingle: albumIsSingle,
      explicit: track.explicit ?? version.explicitHint,
      isrc: normalizeIsrc(track.isrc),
    );
  }

  (FoldedText?, bool) _album(String? rawAlbum, FoldedText titleA, FoldedText titleB) {
    if (rawAlbum == null || rawAlbum.trim().isEmpty) return (null, false);
    final segments = TextSegments.parse(rawAlbum);
    final markedSingle = segments.qualifierCandidates.any((q) {
      final k = TextKeys.plain(q);
      return k == 'single' || k == 'ep' || k == 'the single';
    });
    final base = segments.dashParts.isEmpty ? rawAlbum : segments.dashParts.first;
    final folded = TextKeys.title(base);
    final album = FoldedText(_stripEdition(folded.key), alt: _stripEdition(folded.alt));
    if (album.isEmpty) return (null, false);
    final sameAsTitle = album.key == titleA.key || album.key == titleB.key;
    return (album, markedSingle || sameAsTitle);
  }

  static String _stripEdition(String key) {
    final tokens = key.split(' ');
    while (tokens.length > 1 && _editionTokens.contains(tokens.last)) {
      tokens.removeLast();
    }
    return tokens.join(' ');
  }

  static List<FoldedText> _keys(Iterable<String> names) =>
      [for (final n in names) TextKeys.artistName(n)].where((k) => k.isNotEmpty).toList();

  static List<FoldedText> _dedupe(List<FoldedText> names, {List<FoldedText> exclude = const []}) {
    final seen = {for (final e in exclude) e.key};
    return [
      for (final n in names)
        if (seen.add(n.key)) n,
    ];
  }

  /// Display form of a channel/uploader name ("Rogue - Topic" → "Rogue").
  static String _displayArtist(String name) {
    final cleaned = CharFolding.stripSymbols(name)
        .replaceAll(RegExp(r'\s*-\s*topic$', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?<=\S)vevo$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+(?:official|vevo)$', caseSensitive: false), '');
    return TextSegments.collapse(cleaned);
  }
}
