import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../core/models/matching.dart';
import 'text/segments.dart';
import 'text/text_keys.dart';
import 'version_keywords.dart';

export 'version_keywords.dart' show VersionKeywords;

/// A recording version detected from title qualifiers or the album name.
enum VersionTag {
  /// Remix, VIP, bootleg, flip, rework, refix, someone else's edit, dub,
  /// mash-up, 8D, a cappella, reprise, medley, lo-fi, bass boosted, "X Mix",
  /// and any other "X Version" that is not a known neutral edition
  /// ("Dance Version", "Jay-Z Version").
  remix,
  live,
  acoustic,

  /// Extended / club / 12" / maxi versions.
  extended,

  /// Radio / single / short edits of the same recording.
  radioEdit,
  instrumental,
  karaoke,
  cover,

  /// Remastered, mono/stereo releases and "2009 Mix"-style re-mixdowns of
  /// the same performance. Never significant.
  remaster,

  /// Sped up / nightcore.
  sped,

  /// Slowed (+ reverb), daycore, chopped & screwed.
  slowed,
  demo,

  /// A new recording by the original artist ("Taylor's Version",
  /// "Re-Recorded", "Nyindspilning"). Reported as [MatchDifference.cover]:
  /// the contract has no dedicated value and "different performance of the
  /// same song" is the closest semantic. It is significant, so never
  /// auto-accepted.
  reRecorded,

  /// A version sung in another language ("Spanish Version", "Versión en
  /// Español", "På Dansk"). Like [reRecorded] it is a different vocal
  /// recording and is reported as a significant [MatchDifference.cover].
  language,
}

/// Versions a track carries plus details used to tell two versions of the
/// same kind apart (whose remix, which concert, which remaster year, which
/// language).
@immutable
class VersionInfo {
  const VersionInfo({
    this.tags = const {},
    this.remixer,
    this.remasterYear,
    this.liveDetail,
    this.language,
    this.explicitHint,
  });

  static const none = VersionInfo();

  final Set<VersionTag> tags;

  /// Normalized remixer/editor name ("kygo" for "Kygo Remix").
  final String? remixer;
  final int? remasterYear;

  /// Normalized venue/occasion of a live recording ("wembley 1986").
  final String? liveDetail;

  /// Language code of a [VersionTag.language] version ("es").
  final String? language;

  /// true for "(Explicit)"/"(Dirty)", false for "(Clean)"/"(Edited)".
  final bool? explicitHint;

  bool has(VersionTag tag) => tags.contains(tag);

  bool get isEmpty => tags.isEmpty;

  /// Whether this is a different recording than the studio original.
  bool get isSignificant => tags.any((t) => VersionDetector.differenceFor(t).isSignificant);

  VersionInfo merge(VersionInfo other) => VersionInfo(
        tags: {...tags, ...other.tags},
        remixer: remixer ?? other.remixer,
        remasterYear: remasterYear ?? other.remasterYear,
        liveDetail: liveDetail ?? other.liveDetail,
        language: language ?? other.language,
        explicitHint: explicitHint ?? other.explicitHint,
      );

  @override
  String toString() => 'VersionInfo(${tags.map((t) => t.name).join(',')}'
      '${remixer == null ? '' : ', remixer: $remixer'}${liveDetail == null ? '' : ', live: $liveDetail'}'
      '${language == null ? '' : ', language: $language'})';
}

extension on MatchDifference {
  bool get isSignificant => MatchCandidate.significantVersionDifferences.contains(this);
}

typedef _K = VersionKeywords;

/// Detects [VersionTag]s in qualifier segments ("Remastered 2011",
/// "Kygo Remix", "Live at Wembley"), in full titles (brackets and dash tails)
/// and in album names. Keyword lists (see [VersionKeywords]) include common
/// non-English forms.
///
/// Keywords are only looked for in *qualifiers* (bracketed text or the part
/// after " - "), never in the bare title, so "Live Forever" or "Acoustic
/// Love" are not mistaken for versions. The exceptions are a few unambiguous
/// trailing words ("... Remix", "... Sped Up"), which `TitleParser` moves
/// into the qualifiers before detection.
class VersionDetector {
  const VersionDetector();

  static final _liveAlbumPrefix = RegExp(r'^live (at|in|from|on|aus|i|pa|a|en|au|im|fra) ');
  static final _fromReference =
      RegExp(r'^(?:from|taken from|theme from|music from|as heard in|as featured in|featured in|as seen on) ');

  /// Folded tokens of [segment]. Compound version words are split when the
  /// prefix is known ("Koncertversion" → koncert version, "Liveversion" →
  /// live version), so they hit the same keywords.
  static List<String> tokensOf(String segment) {
    final key = TextKeys.plain(segment);
    if (key.isEmpty) return const [];
    final out = <String>[];
    for (final t in key.split(' ')) {
      final suffix = _K.compoundSuffixes.firstWhereOrNull((x) => t.length > x.length + 2 && t.endsWith(x));
      final prefix = suffix == null ? null : t.substring(0, t.length - suffix.length);
      if (prefix != null && _K.isStrongVocabulary(prefix)) {
        out
          ..add(prefix)
          ..add(suffix!);
      } else {
        out.add(t);
      }
    }
    return out;
  }

  /// Detects tags in one qualifier segment (bracket content or dash tail).
  VersionInfo detectSegment(String segment) {
    final tokens = tokensOf(segment);
    if (tokens.isEmpty) return VersionInfo.none;
    final key = tokens.join(' ');
    if (_K.originalMarkers.contains(key)) return VersionInfo.none;
    final padded = ' $key ';
    final tokenSet = tokens.toSet();
    bool anyToken(Set<String> set) => tokenSet.any(set.contains);
    bool anyPhrase(List<String> phrases) => phrases.any((p) => padded.contains(' $p '));

    final tags = <VersionTag>{};
    int? year;
    String? remixer;
    String? liveDetail;

    final yearMix = tokens.length >= 2 && _K.isYear(tokens[tokens.length - 2]) && tokens.last == 'mix';
    if (tokens.any((t) => t.startsWith(_K.remasterPrefix)) ||
        anyToken(_K.remasterTokens) ||
        padded.contains(' re master') ||
        yearMix) {
      tags.add(VersionTag.remaster);
      year = tokens.where(_K.isYear).map(int.parse).firstOrNull;
    }
    if (anyToken(_K.liveTokens) || anyPhrase(_K.livePhrases)) {
      tags.add(VersionTag.live);
      liveDetail = _liveDetail(tokens);
    }
    if (anyToken(_K.acousticTokens) || anyPhrase(_K.acousticPhrases)) tags.add(VersionTag.acoustic);
    if (anyToken(_K.instrumentalTokens) || anyPhrase(_K.instrumentalPhrases)) tags.add(VersionTag.instrumental);
    if (anyToken(_K.karaokeTokens) || anyPhrase(_K.karaokePhrases)) tags.add(VersionTag.karaoke);
    if (anyToken(_K.coverTokens) || anyPhrase(_K.coverPhrases)) tags.add(VersionTag.cover);
    final sped = anyToken(_K.spedTokens) || anyPhrase(_K.spedPhrases);
    if (sped) tags.add(VersionTag.sped);
    // "Sped Up + Reverb" is a sped-up version; bare "reverb" alone means
    // "slowed + reverb".
    final slowed = anyToken(_K.slowedTokens.difference(const {'reverb', 'reverbed'})) ||
        anyPhrase(_K.slowedPhrases) ||
        (!sped && (tokenSet.contains('reverb') || tokenSet.contains('reverbed')));
    if (slowed) tags.add(VersionTag.slowed);
    if (anyToken(_K.demoTokens) || anyPhrase(_K.demoPhrases) || _K.takePattern.hasMatch(padded)) {
      tags.add(VersionTag.demo);
    }
    if (anyToken(_K.reRecordedTokens) || anyPhrase(_K.reRecordedPhrases)) tags.add(VersionTag.reRecorded);
    if (anyToken(_K.extendedTokens) || anyPhrase(_K.extendedPhrases)) tags.add(VersionTag.extended);
    final radio = anyPhrase(_K.radioPhrases) || key == 'edit';
    if (radio) tags.add(VersionTag.radioEdit);
    final language = _language(tokens);
    if (language != null) tags.add(VersionTag.language);

    // Remixes: explicit keywords, or "<name> mix" / "<name> edit".
    var remixIndex = tokens.indexWhere(_K.remixTokens.contains);
    if (remixIndex < 0) {
      for (final phrase in _K.remixPhrases) {
        final i = _phraseIndex(tokens, phrase);
        if (i >= 0) {
          remixIndex = i;
          break;
        }
      }
    }
    if (remixIndex < 0 && !yearMix) {
      for (final word in const ['mix', 'edit']) {
        final i = tokens.lastIndexOf(word);
        if (i < 0) continue;
        // "(Mix)" alone is a remix; "(Edit)" alone is a radio edit.
        if (i == 0 && word == 'edit') continue;
        if (i == 0 || !_K.mixNeutral.contains(tokens[i - 1]) && !_K.isYear(tokens[i - 1])) {
          remixIndex = i;
          break;
        }
      }
    }
    if (remixIndex >= 0) {
      tags.add(VersionTag.remix);
      remixer = _remixer(tokens, remixIndex);
    } else if (tags.isEmpty) {
      // Any other "X Version" ("Dance Version", "Jay-Z Version", "TV
      // Version") is an alternative arrangement unless every word is a
      // neutral edition word ("Album Version", "Deluxe Version").
      final v = tokens.indexWhere(_K.versionWords.contains);
      if (v >= 0) {
        final named = tokens.where((t) => !_K.isNeutralToken(t) && !_K.mixNeutral.contains(t)).toList();
        if (named.isNotEmpty) {
          tags.add(VersionTag.remix);
          remixer = named.join(' ');
        }
      }
    }

    bool? explicit;
    if (_K.explicitTrue.contains(key)) explicit = true;
    if (_K.explicitFalse.contains(key)) explicit = false;

    return VersionInfo(
      tags: tags,
      remixer: remixer,
      remasterYear: year,
      liveDetail: liveDetail,
      language: language,
      explicitHint: explicit,
    );
  }

  /// Whether [segment] only names the edition or release of the same
  /// recording ("Original Mix", "Album Version", "Bonus Track", "Deluxe",
  /// "From 'Movie'", "2011"), so it neither changes the version nor the
  /// song. Qualifiers that are neither versions nor neutral ("Pt. 1",
  /// "Interlude", "I Can't Get No") belong to the title.
  bool isNeutralQualifier(String segment) {
    final tokens = tokensOf(segment);
    if (tokens.isEmpty) return true;
    final key = tokens.join(' ');
    if (_K.originalMarkers.contains(key) || _K.explicitTrue.contains(key) || _K.explicitFalse.contains(key)) {
      return true;
    }
    if (_fromReference.hasMatch('$key ')) return true;
    return tokens.every(_K.isNeutralToken);
  }

  /// Merges the tags of several qualifier segments.
  VersionInfo detectSegments(Iterable<String> segments) =>
      segments.fold(VersionInfo.none, (acc, s) => acc.merge(detectSegment(s)));

  /// Version info of a full title: bracket contents and dash tails are
  /// inspected, the head is not. Prefer `TrackNormalizer`, which also moves
  /// unbracketed trailing keywords ("Song Sped Up") into the qualifiers.
  VersionInfo detectInTitle(String title) => detectSegments(TextSegments.parse(title).qualifierCandidates);

  /// Version info implied by an album name ("Live at Wembley", "MTV
  /// Unplugged", "Fearless (Taylor's Version)", "X (Sped Up)").
  ///
  /// Remix, extended and radio-edit tags are ignored for albums: remix/club
  /// EPs ("Adventure (The Remixes)") usually also contain the original mix,
  /// and each remix carries its own tag in the track title.
  VersionInfo detectInAlbum(String? album) {
    if (album == null || album.trim().isEmpty) return VersionInfo.none;
    final segments = TextSegments.parse(album);
    var info = detectSegments(segments.qualifierCandidates);
    final head = segments.dashParts.isEmpty ? '' : TextKeys.plain(segments.dashParts.first);
    final padded = ' $head ';
    final extra = <VersionTag>{};
    if (head == 'live' ||
        _liveAlbumPrefix.hasMatch(head) ||
        head.endsWith(' live') ||
        _K.livePhrases.any((p) => padded.contains(' $p ') && p != 'recorded at' && p != 'first take')) {
      extra.add(VersionTag.live);
    }
    if (padded.contains(' unplugged ')) extra.addAll(const {VersionTag.live, VersionTag.acoustic});
    // "Stripped" is a well-known studio album title, so only for tracks.
    if (_K.acousticTokens.any((t) => t != 'stripped' && padded.contains(' $t '))) {
      extra.add(VersionTag.acoustic);
    }
    if (padded.contains(' karaoke ')) extra.add(VersionTag.karaoke);
    if (padded.contains(' instrumentals ') || padded.contains(' instrumental versions ')) {
      extra.add(VersionTag.instrumental);
    }
    if (padded.contains(' tribute to ')) extra.add(VersionTag.cover);
    if (padded.contains(' sped up ') || padded.contains(' nightcore ')) extra.add(VersionTag.sped);
    if (padded.contains(' slowed ')) extra.add(VersionTag.slowed);
    info = info.merge(VersionInfo(tags: extra));
    final kept = info.tags.difference(const {VersionTag.remix, VersionTag.extended, VersionTag.radioEdit});
    return VersionInfo(
      tags: kept,
      remasterYear: info.remasterYear,
      liveDetail: info.liveDetail,
      language: info.language,
      explicitHint: info.explicitHint,
    );
  }

  /// Version differences between two tracks. Tags present on one side only
  /// are differences; two remixes by different remixers, two live
  /// recordings of different occasions, two different languages and two
  /// remasters of different years are differences too.
  Set<MatchDifference> compare(VersionInfo a, VersionInfo b) {
    final diffs = <MatchDifference>{};
    for (final tag in {...a.tags, ...b.tags}) {
      if (a.has(tag) != b.has(tag)) diffs.add(differenceFor(tag));
    }
    if (a.has(VersionTag.remix) && b.has(VersionTag.remix) && !_sameName(a.remixer, b.remixer)) {
      diffs.add(MatchDifference.remix);
    }
    if (a.has(VersionTag.live) && b.has(VersionTag.live) && !_sameName(a.liveDetail, b.liveDetail)) {
      diffs.add(MatchDifference.live);
    }
    if (a.has(VersionTag.language) &&
        b.has(VersionTag.language) &&
        a.language != null &&
        b.language != null &&
        a.language != b.language) {
      diffs.add(MatchDifference.cover);
    }
    if (a.has(VersionTag.remaster) &&
        b.has(VersionTag.remaster) &&
        a.remasterYear != null &&
        b.remasterYear != null &&
        a.remasterYear != b.remasterYear) {
      diffs.add(MatchDifference.remaster);
    }
    return diffs;
  }

  static MatchDifference differenceFor(VersionTag tag) => switch (tag) {
        VersionTag.remix => MatchDifference.remix,
        VersionTag.live => MatchDifference.live,
        VersionTag.acoustic => MatchDifference.acoustic,
        VersionTag.extended => MatchDifference.extended,
        VersionTag.radioEdit => MatchDifference.radioEdit,
        VersionTag.instrumental => MatchDifference.instrumental,
        VersionTag.karaoke => MatchDifference.karaoke,
        VersionTag.cover => MatchDifference.cover,
        VersionTag.remaster => MatchDifference.remaster,
        VersionTag.sped => MatchDifference.sped,
        VersionTag.slowed => MatchDifference.slowed,
        VersionTag.demo => MatchDifference.demo,
        VersionTag.reRecorded => MatchDifference.cover,
        VersionTag.language => MatchDifference.cover,
      };

  /// Language code when [tokens] name a sung language: "Spanish Version",
  /// "Versión en Español", "En/In/Auf/På + language", or the language
  /// alone. Lyric/subtitle videos ("English Lyrics") do not count.
  static String? _language(List<String> tokens) {
    final i = tokens.indexWhere(_K.languages.containsKey);
    if (i < 0 || tokens.any(_K.lyricWords.contains)) return null;
    final cue = tokens.length == 1 ||
        tokens.any(_K.versionWords.contains) ||
        (i > 0 && _K.languagePrepositions.contains(tokens[i - 1]));
    return cue ? _K.languages[tokens[i]] : null;
  }

  /// Unknown on either side counts as "same": we only flag a difference we
  /// can actually see.
  static bool _sameName(String? a, String? b) {
    if (a == null || b == null || a.isEmpty || b.isEmpty) return true;
    if (a == b) return true;
    final ca = a.replaceAll(' ', ''), cb = b.replaceAll(' ', '');
    return ca == cb || ca.contains(cb) || cb.contains(ca);
  }

  static const _liveStopwords = {
    'live', 'at', 'in', 'from', 'on', 'the', 'version', 'recorded', 'session', 'sessions', 'en', 'vivo',
    'directo', 'ao', 'dal', 'concert', 'remastered', 'remaster', 'and', 'performance',
  };

  /// Index of the first token of [phrase] within [tokens], or -1.
  static int _phraseIndex(List<String> tokens, String phrase) {
    final words = phrase.split(' ');
    for (var i = 0; i + words.length <= tokens.length; i++) {
      var ok = true;
      for (var j = 0; j < words.length && ok; j++) {
        ok = tokens[i + j] == words[j];
      }
      if (ok) return i;
    }
    return -1;
  }

  static String? _liveDetail(List<String> tokens) {
    final rest = tokens.where((t) => !_liveStopwords.contains(t) && !t.startsWith(_K.remasterPrefix)).join(' ');
    return rest.isEmpty ? null : rest;
  }

  static String? _remixer(List<String> tokens, int keywordIndex) {
    final byIndex = tokens.indexOf('by');
    if (byIndex >= 0 && byIndex < tokens.length - 1) {
      return tokens.sublist(byIndex + 1).where((t) => !_K.remixTokens.contains(t)).join(' ').trimOrNull;
    }
    final start = (keywordIndex - 4).clamp(0, keywordIndex);
    final name = tokens
        .sublist(start, keywordIndex.clamp(0, tokens.length))
        .where((t) => !_K.mixNeutral.contains(t) && !_K.isYear(t) && t != 'feat' && t != 'ft')
        .join(' ');
    return name.trimOrNull;
  }
}

extension on String {
  String? get trimOrNull {
    final t = trim();
    return t.isEmpty ? null : t;
  }
}
