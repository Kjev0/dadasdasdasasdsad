import 'package:flutter/foundation.dart';

import '../core/models/matching.dart';
import 'text/segments.dart';
import 'text/text_keys.dart';

/// A recording version detected from title qualifiers or the album name.
enum VersionTag {
  /// Remix, VIP, bootleg, flip, rework, refix, someone else's edit, dub,
  /// mash-up, 8D, a cappella, reprise, medley, "X Mix".
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
  /// "Re-Recorded"). Reported as [MatchDifference.cover]: the contract has
  /// no dedicated value and "different performance of the same song" is the
  /// closest semantic. It is significant, so never auto-accepted.
  reRecorded,
}

/// Versions a track carries plus details used to tell two versions of the
/// same kind apart (whose remix, which concert, which remaster year).
@immutable
class VersionInfo {
  const VersionInfo({this.tags = const {}, this.remixer, this.remasterYear, this.liveDetail, this.explicitHint});

  static const none = VersionInfo();

  final Set<VersionTag> tags;

  /// Normalized remixer/editor name ("kygo" for "Kygo Remix").
  final String? remixer;
  final int? remasterYear;

  /// Normalized venue/occasion of a live recording ("wembley 1986").
  final String? liveDetail;

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
        explicitHint: explicitHint ?? other.explicitHint,
      );

  @override
  String toString() => 'VersionInfo(${tags.map((t) => t.name).join(',')}'
      '${remixer == null ? '' : ', remixer: $remixer'}${liveDetail == null ? '' : ', live: $liveDetail'})';
}

extension on MatchDifference {
  bool get isSignificant => MatchCandidate.significantVersionDifferences.contains(this);
}

/// Detects [VersionTag]s in qualifier segments ("Remastered 2011",
/// "Kygo Remix", "Live at Wembley"), in full titles (brackets and dash tails)
/// and in album names. Keyword lists include common non-English forms.
///
/// Keywords are only looked for in *qualifiers* (bracketed text or the part
/// after " - "), never in the bare title, so "Live Forever" or "Acoustic
/// Love" are not mistaken for versions. The exceptions are a few unambiguous
/// trailing words ("... Remix", "... Sped Up"), which `TitleParser` moves
/// into the qualifiers before detection.
class VersionDetector {
  const VersionDetector();

  static final _yearRe = RegExp(r'^(19|20)\d\d$');
  static final _takeRe = RegExp(r' take \d+ ');
  static final _liveAlbumPrefix = RegExp(r'^live (at|in|from|on|aus|i|pa|a|en|au|im|fra) ');

  // Single-token keywords.
  static const _remasterPrefix = 'remaster';
  static const _remasterTokens = {'mono', 'stereo', 'remastering', 'remasterizada', 'remasterizado'};
  static const _liveTokens = {'live', 'unplugged', 'koncert', 'konzert', 'concierto', 'livemitschnitt'};
  static const _livePhrases = [
    'en vivo', 'en directo', 'ao vivo', 'dal vivo', 'in concert', 'en concert', 'en public', 'live session',
    'bbc session', 'peel session', 'recorded live', 'recorded at', 'live from', 'live at', 'live in',
  ];
  static const _acousticTokens = {
    'acoustic', 'akustisk', 'akustik', 'akustisch', 'acustico', 'acustica', 'acoustique', 'unplugged', 'stripped',
  };
  static const _acousticPhrases = ['piano version', 'piano acoustic', 'acoustic version'];
  static const _instrumentalTokens = {
    'instrumental', 'instrumentals', 'instrumentale', 'instrumentalversion', 'inst', 'instr', 'instrumentaal',
  };
  static const _instrumentalPhrases = ['off vocal', 'no vocals', 'no vocal', 'without vocals'];
  static const _karaokeTokens = {'karaoke', 'karaokeversion'};
  static const _karaokePhrases = ['backing track', 'in the style of', 'sing along', 'singalong', 'minus one'];
  static const _coverTokens = {'cover', 'covers', 'tribute'};
  static const _coverPhrases = ['originally performed by', 'made famous by', 'covered by'];
  static const _spedTokens = {'sped', 'spedup', 'nightcore', 'speedup'};
  static const _spedPhrases = ['speed up', 'sped up', 'speeded up', 'fast version', 'faster version'];
  static const _slowedTokens = {'slowed', 'reverb', 'reverbed', 'daycore', 'screwed'};
  static const _slowedPhrases = ['slow version', 'slowed down', 'chopped and screwed', 'chopped not slopped'];
  static const _demoTokens = {'demo', 'demos', 'outtake', 'outtakes', 'worktape'};
  static const _demoPhrases = [
    'rough mix', 'alternate take', 'alternative take', 'alternate version', 'alternative version', 'alt take',
    'work tape', 'early version', 'work in progress', 'rough demo',
  ];
  static const _reRecordedTokens = {'rerecorded', 'rerecording'};
  static const _reRecordedPhrases = ['taylors version', 're recorded', 're recording', 're record', 'from the vault', 'new recording'];
  static const _extendedTokens = {'extended', 'maxi', 'extendedmix'};
  static const _extendedPhrases = [
    'club mix', 'club version', 'club edit', '12 inch', '12 version', '12 mix', 'long version', 'full length version',
    'twelve inch',
  ];
  static const _radioPhrases = [
    'radio edit', 'radio version', 'radio mix', 'single edit', 'single version', 'single mix', 'short version',
    'short edit', 'radio cut', 'short mix',
  ];
  static const _remixTokens = {
    'remix', 'remixed', 'remixes', 'rmx', 'bootleg', 'rework', 'reworked', 'refix', 'reedit', 'flip', 'vip',
    'mashup', 'remake', '8d', 'dub', 'acapella', 'acappella', 'reprise', 'medley', 'mixed', 'redux',
  };
  static const _remixPhrases = ['re edit', 're work', 'mash up', 'a cappella', 'a capella', 'orchestral version', 'symphonic version'];

  /// Words in front of "mix"/"edit" that do not name a remixer.
  static const _mixNeutral = {
    'original', 'radio', 'extended', 'club', 'album', 'single', 'mono', 'stereo', 'main', 'clean', 'dirty',
    'explicit', 'instrumental', 'short', 'long', '12', 'maxi', 'inch', 'the', 'full', 'final', 'new', 'video',
    'edit', 'version', 'and', 'a', 'an', 're', 'rough', 'dub', 'vocal',
  };
  static const _explicitTrue = {'explicit', 'explicit version', 'dirty', 'dirty version', 'explicit edit', 'uncensored'};
  static const _explicitFalse = {'clean', 'clean version', 'clean edit', 'edited', 'edited version', 'censored', 'radio clean'};

  /// Neutral qualifiers that explicitly denote the original recording.
  static const _originalMarkers = {'original mix', 'original version', 'album version', 'original', 'main version'};

  /// Detects tags in one qualifier segment (bracket content or dash tail).
  VersionInfo detectSegment(String segment) {
    final key = TextKeys.plain(segment);
    if (key.isEmpty || _originalMarkers.contains(key)) return VersionInfo.none;
    final padded = ' $key ';
    final tokens = key.split(' ');
    final tokenSet = tokens.toSet();
    bool anyToken(Set<String> set) => tokenSet.any(set.contains);
    bool anyPhrase(List<String> phrases) => phrases.any((p) => padded.contains(' $p '));

    final tags = <VersionTag>{};
    int? year;
    String? remixer;
    String? liveDetail;

    final yearMix = tokens.length >= 2 && _yearRe.hasMatch(tokens[tokens.length - 2]) && tokens.last == 'mix';
    if (tokens.any((t) => t.startsWith(_remasterPrefix)) ||
        anyToken(_remasterTokens) ||
        padded.contains(' re master') ||
        yearMix) {
      tags.add(VersionTag.remaster);
      year = tokens.where(_yearRe.hasMatch).map(int.parse).firstOrNullValue;
    }
    if (anyToken(_liveTokens) || anyPhrase(_livePhrases)) {
      tags.add(VersionTag.live);
      liveDetail = _liveDetail(tokens);
    }
    if (anyToken(_acousticTokens) || anyPhrase(_acousticPhrases)) tags.add(VersionTag.acoustic);
    if (anyToken(_instrumentalTokens) || anyPhrase(_instrumentalPhrases)) tags.add(VersionTag.instrumental);
    if (anyToken(_karaokeTokens) || anyPhrase(_karaokePhrases)) tags.add(VersionTag.karaoke);
    if (anyToken(_coverTokens) || anyPhrase(_coverPhrases)) tags.add(VersionTag.cover);
    final sped = anyToken(_spedTokens) || anyPhrase(_spedPhrases);
    if (sped) tags.add(VersionTag.sped);
    // "Sped Up + Reverb" is a sped-up version; bare "reverb" alone means
    // "slowed + reverb".
    final slowed = anyToken(_slowedTokens.difference(const {'reverb', 'reverbed'})) ||
        anyPhrase(_slowedPhrases) ||
        (!sped && (tokenSet.contains('reverb') || tokenSet.contains('reverbed')));
    if (slowed) tags.add(VersionTag.slowed);
    if (anyToken(_demoTokens) || anyPhrase(_demoPhrases) || _takeRe.hasMatch(padded)) tags.add(VersionTag.demo);
    if (anyToken(_reRecordedTokens) || anyPhrase(_reRecordedPhrases)) tags.add(VersionTag.reRecorded);
    if (anyToken(_extendedTokens) || anyPhrase(_extendedPhrases)) tags.add(VersionTag.extended);
    final radio = anyPhrase(_radioPhrases) || key == 'edit';
    if (radio) tags.add(VersionTag.radioEdit);

    // Remixes: explicit keywords, or "<name> mix" / "<name> edit".
    var remixIndex = tokens.indexWhere(_remixTokens.contains);
    if (remixIndex < 0) {
      for (final phrase in _remixPhrases) {
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
        if (i == 0 || !_mixNeutral.contains(tokens[i - 1]) && !_yearRe.hasMatch(tokens[i - 1])) {
          remixIndex = i;
          break;
        }
      }
    }
    if (remixIndex >= 0) {
      tags.add(VersionTag.remix);
      remixer = _remixer(tokens, remixIndex);
    }

    bool? explicit;
    if (_explicitTrue.contains(key)) explicit = true;
    if (_explicitFalse.contains(key)) explicit = false;

    return VersionInfo(
      tags: tags,
      remixer: remixer,
      remasterYear: year,
      liveDetail: liveDetail,
      explicitHint: explicit,
    );
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
        _livePhrases.any((p) => padded.contains(' $p ') && p != 'recorded at')) {
      extra.add(VersionTag.live);
    }
    if (padded.contains(' unplugged ')) extra.addAll(const {VersionTag.live, VersionTag.acoustic});
    // "Stripped" is a well-known studio album title, so only for tracks.
    if (_acousticTokens.any((t) => t != 'stripped' && padded.contains(' $t '))) {
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
      explicitHint: info.explicitHint,
    );
  }

  /// Version differences between two tracks. Tags present on one side only
  /// are differences; two remixes by different remixers, two live
  /// recordings of different occasions and two remasters of different years
  /// are differences too.
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
      };

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
    final rest = tokens.where((t) => !_liveStopwords.contains(t) && !t.startsWith(_remasterPrefix)).join(' ');
    return rest.isEmpty ? null : rest;
  }

  static String? _remixer(List<String> tokens, int keywordIndex) {
    final byIndex = tokens.indexOf('by');
    if (byIndex >= 0 && byIndex < tokens.length - 1) {
      return tokens.sublist(byIndex + 1).where((t) => !_remixTokens.contains(t)).join(' ').trimOrNull;
    }
    final start = (keywordIndex - 4).clamp(0, keywordIndex);
    final name = tokens
        .sublist(start, keywordIndex.clamp(0, tokens.length))
        .where((t) => !_mixNeutral.contains(t) && !_yearRe.hasMatch(t) && t != 'feat' && t != 'ft')
        .join(' ');
    return name.trimOrNull;
  }
}

extension on Iterable<int> {
  int? get firstOrNullValue => isEmpty ? null : first;
}

extension on String {
  String? get trimOrNull {
    final t = trim();
    return t.isEmpty ? null : t;
  }
}
