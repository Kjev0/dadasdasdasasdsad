import 'package:flutter/foundation.dart';

import '../version_detector.dart';
import 'char_folding.dart';
import 'segments.dart';
import 'text_keys.dart';

/// A track title taken apart.
@immutable
class TitleParts {
  const TitleParts({
    required this.base,
    this.qualifiers = const [],
    this.featured = const [],
    this.explicitHint,
    this.splitArtist,
    this.splitTitle,
    List<String>? splitQualifiers,
    this.preferUnsplit = false,
  }) : splitQualifiers = splitQualifiers ?? qualifiers;

  /// The title without qualifiers, featured credits, producer credits and
  /// noise, in display form ("Bohemian Rhapsody"). For "Artist - Title"
  /// uploads this is still the full "Artist - Title" text.
  final String base;

  /// Qualifiers of the [base] reading in display form: bracket contents and
  /// dash tails that are not featured credits, producer credits, explicit
  /// hints or noise ("Remastered 2011", "Kygo Remix", "Live at Wembley",
  /// "Pt. 1").
  final List<String> qualifiers;

  /// Featured-artist credits found in the title ("Kygo & Mø"), unsplit.
  final List<String> featured;

  /// true for "(Explicit)", false for "(Clean)", null when not stated.
  final bool? explicitHint;

  /// For "Artist - Title" style titles: the part before the dash.
  final String? splitArtist;

  /// For "Artist - Title" style titles: the part after the dash.
  final String? splitTitle;

  /// Qualifiers of the [splitArtist]/[splitTitle] reading. They differ from
  /// [qualifiers] when a dash tail can be read either way ("Oasis - Live
  /// Forever": a live version of "Oasis", or "Live Forever" by Oasis): the
  /// unsplit reading treats the tail as a qualifier, the split reading as
  /// the title.
  final List<String> splitQualifiers;

  /// The dash tail reads more naturally as a version qualifier ("Song -
  /// Kygo Remix") than as a title, so the unsplit reading should be
  /// preferred unless the uploader is the left-hand artist.
  final bool preferUnsplit;

  bool get hasArtistTitleSplit => splitArtist != null && splitTitle != null;
}

enum _SegmentKind { featured, producer, noise, explicit, qualifier }

/// How a dash tail ("Head - Tail") is read.
enum _TailKind {
  /// Certainly a qualifier ("Remastered 2011", "Radio Edit", "Official
  /// Video", "From 'Frozen'").
  qualifier,

  /// A qualifier or a title ("Live Forever", "1999", "Kygo Remix", "From
  /// Eden"): both readings are kept and the scorer picks.
  ambiguous,

  /// No qualifier signal: the title of an "Artist - Title" upload or a
  /// subtitle ("Requiem - Lacrimosa").
  title,
}

/// Parses titles from all kinds of sources: streaming-service titles
/// ("Song - Remastered 2011", "Song (feat. X)"), and uploader-style titles
/// from SoundCloud/YouTube ("Artist - Song (Official Video) [Free DL] #edm").
class TitleParser {
  const TitleParser({this.detector = const VersionDetector()});

  final VersionDetector detector;

  static final _hashtag = RegExp(r'#(?=[\p{L}\p{N}_]*\p{L})[\p{L}\p{N}_]+', unicode: true);
  static final _hardSeparator = RegExp(r'\s+(?:\||//|•|·|¦)\s+');
  static final _featLead = RegExp(r'^(?:feat\.?|ft\.?|featuring|with|w/)\s+(.+)$', caseSensitive: false);
  static final _featInner = RegExp(r'^(.*?)\s+(?:feat\.?|ft\.?|featuring)\s+(.+)$', caseSensitive: false);
  static final _prodLead = RegExp(r'^(?:prod\.?|produced|producer)(?:\s|$|\.)', caseSensitive: false);
  static final _inlineFeat =
      RegExp(r'\s+(?:feat\.|ft\.|feat|ft|featuring|w/)\s+(.+?)(?=\s+-\s+|$)', caseSensitive: false);
  static final _inlineProd =
      RegExp(r'\s+(?:prod\.|prod|produced)\s+(?:by\s+)?.+?(?=\s+-\s+|$)', caseSensitive: false);
  static final _trailingNoise = RegExp(
    r'\s+(?:official\s+(?:music\s+|lyrics?\s+|hd\s+)?(?:video|audio|visuali[sz]er)|lyrics?\s+video|video\s+oficial|'
    r'(?:official\s+)?(?:mv|pv))\s*$',
    caseSensitive: false,
  );

  /// Unambiguous version words that uploaders append without brackets.
  static final _trailingVersion = RegExp(
    r'\s+((?:super\s+)?(?:sped\s+up|speed\s+up)(?:\s*(?:\+|&|and)\s*reverb)?|'
    r'slowed(?:\s+down)?(?:\s*(?:\+|&|and)\s*reverb)?|nightcore(?:\s+version)?|8d\s+audio|'
    r'remix|bootleg|rework|refix)\s*$',
    caseSensitive: false,
  );
  static final _year = RegExp(r'^(19|20)\d\d$');
  static final _cjkQuote = RegExp('[\u300C\u300E]([^\u300D\u300F]*)[\u300D\u300F]');
  static final _quotedReference = RegExp(
    '^\\s*(?:from|taken from|theme from|music from)\\s+["\u201C\u201D\u201E\u00AB\u00BB\u2018\u2019\']',
    caseSensitive: false,
  );
  static final _liveAt = RegExp(r'^(?:live (?:at|in|from|on)|recorded (?:at|live)) ');
  static final _edgePunctuation = RegExp(r'^[\s\-:,;|/~*"]+|[\s\-:,;|/~*"]+$');

  /// Tokens that make up "(Official Music Video)", "[HD]", "(Lyrics)",
  /// "[Free Download]", "(Out Now)", "(Video Oficial)", "(Letra)"...
  static const _noiseTokens = {
    'official', 'music', 'video', 'audio', 'lyric', 'lyrics', 'visualizer', 'visualiser', 'hd', 'hq', '4k', '8k',
    '1080p', '720p', '480p', 'mv', 'm', 'v', 'clip', 'videoclip', 'oficial', 'free', 'download', 'dl', 'out',
    'now', 'premiere', 'new', 'full', 'song', 'with', 'and', 'letra', 'paroles', 'sub', 'subs', 'subtitles',
    'subtitulado', 'legendado', 'cc', 'color', 'coded', 'eng', 'rom', 'han', 'high', 'quality', 'release',
    'exclusive', 'available', 'on', 'spotify', 'itunes', 'soundcloud', 'youtube', 'lyricvideo', 'officialvideo',
    'animated', 'performance', 'teaser', 'trailer',
  };
  static const _noiseCore = {
    'official', 'video', 'audio', 'lyric', 'lyrics', 'visualizer', 'visualiser', 'hd', 'hq', '4k', 'mv', 'clip',
    'videoclip', 'download', 'dl', 'premiere', 'release', 'out', 'letra', 'paroles', 'subtitles', 'subtitulado',
    'legendado', '1080p', '720p', 'oficial', 'lyricvideo', 'officialvideo', 'teaser', 'trailer',
  };
  static const _explicitTrue = {'explicit', 'explicit version', 'dirty', 'dirty version', 'explicit edit', 'uncensored'};
  static const _explicitFalse = {'clean', 'clean version', 'clean edit', 'edited', 'edited version', 'censored'};

  /// Leading words of dash tails that qualify rather than continue a title
  /// ("Song - From 'Movie'", "Song - Bonus Track", "Song - 2011").
  static final _qualifierLead = RegExp(
    r'^(?:from|taken from|theme from|feat|ft|featuring|prod|produced|bonus|live|edit|mix|version|remaster\w*|'
    r'recorded|single|ep|lp|album|original|main|deluxe|mono|stereo|(?:19|20)\d\d)(?: |$)',
  );
  static final _qualifierWord = RegExp(r'(?:^| )(?:version|mix|edit|soundtrack|ost|edition|session|sessions)(?: |$)');

  /// Version tags that uploaders put *before* the title ("Nightcore - Song").
  static const _leadingTagKinds = {
    VersionTag.sped, VersionTag.slowed, VersionTag.karaoke, VersionTag.instrumental, VersionTag.remix,
  };

  TitleParts parse(String raw) {
    final common = <String>[];
    final featured = <String>[];
    bool? explicit;

    void take(String segment) {
      final (kind, payload) = _classify(segment);
      switch (kind) {
        case _SegmentKind.featured:
          featured.add(payload!);
        case _SegmentKind.explicit:
          explicit = payload == 'true';
        case _SegmentKind.qualifier:
          final inner = _featInner.firstMatch(segment);
          if (inner != null) {
            common.add(inner[1]!.trim());
            featured.add(inner[2]!.trim());
          } else {
            common.add(segment.trim());
          }
        case _SegmentKind.producer:
        case _SegmentKind.noise:
          break;
      }
    }

    var s = _unquoteCjk(CharFolding.stripSymbols(raw).replaceAll(_hashtag, ' '));
    s = TextSegments.collapse(s);

    // "Title | Official Video", "Artist - Title // Free DL".
    final hard = s.split(_hardSeparator);
    s = hard.first;
    hard.skip(1).forEach(take);

    final (outside, bracketed) = TextSegments.extractBrackets(s);
    bracketed.forEach(take);
    s = outside;

    s = s.replaceAllMapped(_inlineFeat, (m) {
      featured.add(m[1]!.trim());
      return '';
    });
    s = s.replaceAll(_inlineProd, '').replaceAll(_trailingNoise, '');

    final parts = TextSegments.splitDashes(s);
    if (parts.isEmpty) parts.add('');
    if (parts.length >= 2 && _isLeadingTag(parts.first)) {
      common.add(parts.removeAt(0));
    }
    final head = parts.first;
    final rest = <String>[];
    final ambiguous = <String>[];
    var titleSeen = false;
    for (final p in parts.skip(1)) {
      switch (_tailKind(p)) {
        case _TailKind.qualifier:
          take(p);
        case _TailKind.ambiguous when titleSeen:
          // "Artist - Title - Live at X": the title is already known.
          take(p);
        case _TailKind.ambiguous:
          rest.add(p);
          ambiguous.add(p);
        case _TailKind.title:
          rest.add(p);
          titleSeen = true;
      }
    }

    String stripTrailing(String text, List<String> into) {
      final m = _trailingVersion.firstMatch(text);
      if (m == null) return text;
      into.add(m[1]!);
      return text.substring(0, m.start);
    }

    String? splitArtist;
    String? splitTitle;
    String base;
    final baseOnly = <String>[];
    final splitOnly = <String>[];
    var preferUnsplit = false;
    if (rest.isNotEmpty) {
      splitArtist = _clean(head);
      splitTitle = _clean(stripTrailing(rest.join(' - '), splitOnly));
      if (splitArtist.isEmpty || splitTitle.isEmpty) {
        splitArtist = splitTitle = null;
      }
      if (ambiguous.length == rest.length) {
        // Every tail could be a qualifier: read "Head (Tail)" and "Artist =
        // Head, Title = Tail" and let the scorer decide.
        base = _clean(head);
        baseOnly.addAll(rest);
        preferUnsplit = rest.every(_looksLikeQualifier);
      } else {
        base = _clean([head, ...rest].join(' - '));
      }
    } else {
      base = _clean(stripTrailing(head, common));
    }
    if (base.isEmpty) base = _clean(raw);

    return TitleParts(
      base: base,
      qualifiers: List.unmodifiable([...common, ...baseOnly]),
      featured: List.unmodifiable(featured),
      explicitHint: explicit,
      splitArtist: splitArtist,
      splitTitle: splitTitle,
      splitQualifiers: List.unmodifiable([...common, ...splitOnly]),
      preferUnsplit: preferUnsplit,
    );
  }

  (_SegmentKind, String?) _classify(String segment) {
    final trimmed = segment.trim();
    final feat = _featLead.firstMatch(trimmed);
    if (feat != null) return (_SegmentKind.featured, feat[1]!.trim());
    if (_prodLead.hasMatch(trimmed)) return (_SegmentKind.producer, null);
    final key = TextKeys.plain(trimmed);
    if (key.isEmpty) return (_SegmentKind.noise, null);
    if (_explicitTrue.contains(key)) return (_SegmentKind.explicit, 'true');
    if (_explicitFalse.contains(key)) return (_SegmentKind.explicit, 'false');
    final tokens = key.split(' ');
    if (tokens.every((t) => _noiseTokens.contains(t) || _year.hasMatch(t)) && tokens.any(_noiseCore.contains)) {
      return (_SegmentKind.noise, null);
    }
    return (_SegmentKind.qualifier, null);
  }

  _TailKind _tailKind(String part) {
    final key = TextKeys.plain(part);
    if (key.isEmpty) return _TailKind.qualifier;
    final (kind, _) = _classify(part);
    if (kind != _SegmentKind.qualifier) return _TailKind.qualifier;
    if (_quotedReference.hasMatch(part)) return _TailKind.qualifier;
    final info = detector.detectSegment(part);
    final neutral = detector.isNeutralQualifier(part);
    final signal = info.tags.isNotEmpty || neutral || _qualifierLead.hasMatch(key) || _qualifierWord.hasMatch(key);
    if (!signal) return _TailKind.title;
    // Only qualifier vocabulary ("Remastered 2011", "Live at the BBC",
    // "Single Version"): never a song title. A single word ("Live",
    // "Tribute", "1999") or a tail with other words ("Live Forever", "Kygo
    // Remix", "Single Ladies") may be either.
    final tokens = VersionDetector.tokensOf(part);
    if ((info.tags.isNotEmpty || neutral) && tokens.length >= 2 && tokens.every(VersionKeywords.isVocabulary)) {
      return _TailKind.qualifier;
    }
    return _TailKind.ambiguous;
  }

  /// "Kygo Remix", "Jay-Z Version", "Live at Wembley": shaped like a
  /// version qualifier rather than a title.
  static bool _looksLikeQualifier(String part) {
    final tokens = VersionDetector.tokensOf(part);
    if (tokens.length < 2) return false;
    return VersionKeywords.qualifierEndings.contains(tokens.last) || _liveAt.hasMatch(tokens.join(' '));
  }

  /// Japanese quotation marks around a title ("YOASOBI「夜に駆ける」MV",
  /// "米津玄師『Lemon』") act like the dash of "Artist - Title".
  static String _unquoteCjk(String input) => input.replaceAllMapped(_cjkQuote, (m) {
        final before = input.substring(0, m.start).trim();
        return before.isEmpty ? ' ${m[1]} - ' : ' - ${m[1]} - ';
      });

  bool _isLeadingTag(String part) {
    final key = TextKeys.plain(part);
    if (key.isEmpty || key.split(' ').length > 3) return false;
    return detector.detectSegment(part).tags.any(_leadingTagKinds.contains);
  }

  static String _clean(String s) => TextSegments.collapse(s).replaceAll(_edgePunctuation, '');
}
