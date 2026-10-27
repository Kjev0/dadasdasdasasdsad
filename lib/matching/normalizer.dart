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
/// or channel account. When Y could also be a version qualifier ("Oasis -
/// Live Forever"), the unsplit reading treats Y as a qualifier, so each
/// reading carries its own [version]. The scorer compares every pair of
/// readings and keeps the best, so the right interpretation wins without
/// guessing up front.
@immutable
class TrackReading {
  const TrackReading({
    required this.title,
    required this.displayTitle,
    required this.primaryArtists,
    required this.featuredArtists,
    required this.displayArtist,
    this.isArtistTitleSplit = false,
    this.titleQualifier = FoldedText.empty,
    this.version = VersionInfo.none,
    this.versionQualifiers = const [],
  });

  /// Normalized base title (no qualifiers, featured credits or noise).
  final FoldedText title;

  /// Normalized qualifiers that are neither a version nor a neutral edition
  /// word and therefore name *which* song this is ("pt 1" for "(Pt. 1)",
  /// "interlude", "i cant get no"). Empty for most tracks. Compared by
  /// `Similarity.qualifiedTitle`, so "Song (Pt. 1)" never equals "Song (Pt.
  /// 2)", while "Song (Part 2)" still equals "Song, Pt. 2".
  final FoldedText titleQualifier;

  /// Versions of this reading: its title qualifiers, the explicit hint and
  /// the album.
  final VersionInfo version;

  /// Display text of this reading's qualifiers that make it a significantly
  /// different version ("Kygo Remix", "Live at Wembley").
  final List<String> versionQualifiers;

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
    required this.album,
    required this.albumIsSingle,
    required this.explicit,
    required this.isrc,
  });

  final Track track;

  /// Preferred reading first; never empty.
  final List<TrackReading> readings;

  /// Versions of the preferred reading.
  VersionInfo get version => primary.version;

  /// Display text of the preferred reading's qualifiers that make it a
  /// significantly different version ("Kygo Remix", "Live at Wembley");
  /// added to search queries.
  List<String> get versionQualifiers => primary.versionQualifiers;

  /// Normalized album title without edition words, or null.
  final FoldedText? album;

  /// "- Single"/"- EP" releases, or albums named like the track itself.
  final bool albumIsSingle;

  /// [Track.explicit], or the "(Explicit)"/"(Clean)" title hint.
  final bool? explicit;

  /// Upper-case ISRC without separators, or null (also for values that are
  /// not a well-formed ISRC, e.g. "N/A" or "unknown").
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

  /// ISO 3901: country (2 letters), registrant (3 alphanumerics), year (2
  /// digits) and designation (5 digits).
  static final _isrcFormat = RegExp(r'^[A-Z]{2}[A-Z0-9]{3}\d{7}$');

  /// Trailing album words that name an edition rather than the album.
  static const _editionTokens = {
    'deluxe', 'edition', 'expanded', 'remastered', 'remaster', 'anniversary', 'version', 'special', 'bonus',
    'track', 'tracks', 'super', 'collectors', 'ep', 'single', 'lp', 'reissue', 'complete', 'legacy',
  };

  /// Upper-case ISRC without separators ("us-um7-17-03861" →
  /// "USUM71703861"), or null when [isrc] is missing or not a well-formed
  /// ISRC. Placeholders found in tags and uploader metadata ("N/A", "0",
  /// "unknown", "none") are rejected so they can never make two unrelated
  /// tracks an exact match.
  static String? normalizeIsrc(String? isrc) {
    if (isrc == null) return null;
    final n = isrc.toUpperCase().replaceAll(_isrcJunk, '');
    return _isrcFormat.hasMatch(n) ? n : null;
  }

  /// Normalized form of one artist name (see [TextKeys.artistName]).
  static FoldedText artistKey(String name) => TextKeys.artistName(name);

  /// Normalized form of a title (see [TextKeys.title]).
  static FoldedText titleKey(String title) => TextKeys.title(title);

  NormalizedTrack normalize(Track track) {
    final parts = parser.parse(track.title);
    final credits = ArtistParser.splitRefs(track.artists);
    final titleFeatured = parts.featured.expand(ArtistParser.splitNames).toList();
    final shared = VersionInfo(explicitHint: parts.explicitHint).merge(detector.detectInAlbum(track.album));

    final primaryKeys = _keys(credits.primary);
    final readingA = _reading(
      title: parts.base,
      qualifiers: parts.qualifiers,
      shared: shared,
      primaryArtists: primaryKeys,
      featuredArtists: _dedupe([..._keys(credits.featured), ..._keys(titleFeatured)], exclude: primaryKeys),
      displayArtist: credits.primary.isEmpty ? '' : _displayArtist(credits.primary.first),
    );

    var readings = [readingA];
    if (parts.hasArtistTitleSplit) {
      final left = ArtistParser.split(parts.splitArtist!);
      final leftPrimary = _keys(left.primary);
      final readingB = _reading(
        title: parts.splitTitle!,
        qualifiers: parts.splitQualifiers,
        shared: shared,
        primaryArtists: leftPrimary,
        featuredArtists: _dedupe([..._keys(left.featured), ..._keys(titleFeatured)], exclude: leftPrimary),
        displayArtist: left.primary.isEmpty ? '' : left.primary.first,
        isArtistTitleSplit: true,
      );
      final uploaderIsArtist = primaryKeys.any(
        (u) => [...leftPrimary, ..._keys(left.featured)].any((l) => Similarity.foldedName(u, l) >= 0.9),
      );
      final preferSplit = uploaderIsArtist ||
          (!parts.preferUnsplit && (uploaderStyleSources.contains(track.sourceId) || track.artists.isEmpty));
      readings = preferSplit ? [readingB, readingA] : [readingA, readingB];
    }

    final (album, albumIsSingle) = _album(track.album, readingA.title, readings.last.title);

    return NormalizedTrack(
      track: track,
      readings: List.unmodifiable(readings),
      album: album,
      albumIsSingle: albumIsSingle,
      explicit: track.explicit ?? readingA.version.explicitHint,
      isrc: normalizeIsrc(track.isrc),
    );
  }

  TrackReading _reading({
    required String title,
    required List<String> qualifiers,
    required VersionInfo shared,
    required List<FoldedText> primaryArtists,
    required List<FoldedText> featuredArtists,
    required String displayArtist,
    bool isArtistTitleSplit = false,
  }) {
    final versionQualifiers = <String>[];
    final titleQualifiers = <String>[];
    var version = VersionInfo.none;
    for (final q in qualifiers) {
      final info = detector.detectSegment(q);
      version = version.merge(info);
      if (info.isSignificant) versionQualifiers.add(q);
      if (info.isEmpty && !detector.isNeutralQualifier(q)) titleQualifiers.add(q);
    }
    return TrackReading(
      title: TextKeys.title(title),
      displayTitle: title,
      primaryArtists: primaryArtists,
      featuredArtists: featuredArtists,
      displayArtist: displayArtist,
      isArtistTitleSplit: isArtistTitleSplit,
      titleQualifier: titleQualifiers.isEmpty ? FoldedText.empty : TextKeys.title(titleQualifiers.join(' ')),
      version: version.merge(shared),
      versionQualifiers: List.unmodifiable(versionQualifiers),
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
