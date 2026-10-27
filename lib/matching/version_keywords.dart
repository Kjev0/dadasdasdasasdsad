/// Keyword tables of `VersionDetector` and the qualifier vocabulary used by
/// `TitleParser`. Every entry is a folded key (see `TextKeys.plain`): lower
/// case, no accents, punctuation turned into spaces ("Re-Mix" → "re mix",
/// "Lo-Fi" → "lo fi", "Versión" → "version").
///
/// Single tokens match whole tokens; phrases match whole-word sequences.
/// Add a row to `test/matching/version_detector_test.dart` for every new
/// keyword.
abstract final class VersionKeywords {
  static const remasterPrefix = 'remaster';
  static const remasterTokens = {'mono', 'stereo', 'remastering', 'remasterizada', 'remasterizado'};

  static const liveTokens = {
    'live', 'unplugged', 'koncert', 'konzert', 'konsert', 'concierto', 'livemitschnitt', 'liveoptagelse',
    'liveinspelning', 'liveopptak',
  };
  static const livePhrases = [
    'en vivo', 'en directo', 'ao vivo', 'dal vivo', 'in concert', 'en concert', 'en public', 'live session',
    'bbc session', 'peel session', 'recorded live', 'recorded at', 'live from', 'live at', 'live in',
    // "from THE FIRST TAKE": one-take performances recorded for the channel.
    'first take',
  ];

  static const acousticTokens = {
    'acoustic', 'akustisk', 'akustik', 'akustisch', 'acustico', 'acustica', 'acoustique', 'unplugged', 'stripped',
  };
  static const acousticPhrases = ['piano version', 'piano acoustic', 'acoustic version'];

  static const instrumentalTokens = {
    'instrumental', 'instrumentals', 'instrumentale', 'instrumentalversion', 'inst', 'instr', 'instrumentaal',
  };
  static const instrumentalPhrases = ['off vocal', 'no vocals', 'no vocal', 'without vocals'];

  static const karaokeTokens = {'karaoke', 'karaokeversion'};
  static const karaokePhrases = ['backing track', 'in the style of', 'sing along', 'singalong', 'minus one'];

  static const coverTokens = {'cover', 'covers', 'tribute'};
  static const coverPhrases = ['originally performed by', 'made famous by', 'covered by'];

  static const spedTokens = {'sped', 'spedup', 'nightcore', 'speedup'};
  static const spedPhrases = ['speed up', 'sped up', 'speeded up', 'fast version', 'faster version'];

  static const slowedTokens = {'slowed', 'reverb', 'reverbed', 'daycore', 'screwed'};
  static const slowedPhrases = ['slow version', 'slowed down', 'chopped and screwed', 'chopped not slopped'];

  static const demoTokens = {'demo', 'demos', 'outtake', 'outtakes', 'worktape'};
  static const demoPhrases = [
    'rough mix', 'alternate take', 'alternative take', 'alternate version', 'alternative version', 'alt take',
    'work tape', 'early version', 'work in progress', 'rough demo',
  ];

  /// "Take 3", "Take Two", "Take II".
  static final takePattern = RegExp(
    r' take (?:\d+|one|two|three|four|five|six|seven|eight|nine|ten|ii|iii|iv|vi|vii|viii|ix) ',
  );

  static const reRecordedTokens = {
    'rerecorded', 'rerecording', 'nyindspilning', 'genindspilning', 'nyinspelning', 'nyinnspilling',
    'neuaufnahme', 'regrabacion', 'regravacao',
  };
  static const reRecordedPhrases = [
    'taylors version', 're recorded', 're recording', 're record', 'from the vault', 'new recording', 'new version',
  ];

  static const extendedTokens = {'extended', 'maxi', 'extendedmix'};
  static const extendedPhrases = [
    'club mix', 'club version', 'club edit', '12 inch', '12 version', '12 mix', 'long version', 'full length version',
    'twelve inch',
  ];

  static const radioPhrases = [
    'radio edit', 'radio version', 'radio mix', 'single edit', 'single version', 'single mix', 'short version',
    'short edit', 'radio cut', 'short mix', '7 inch', '7 version', '7 mix', '7 edit',
  ];

  static const remixTokens = {
    'remix', 'remixed', 'remixes', 'rmx', 'bootleg', 'rework', 'reworked', 'refix', 'reedit', 'flip', 'vip',
    'mashup', 'remake', '8d', 'dub', 'acapella', 'acappella', 'reprise', 'medley', 'mixed', 'redux', 'lofi',
    'bassboosted', 'hardstyle', 'phonk',
  };
  static const remixPhrases = [
    're mix', 're edit', 're work', 'mash up', 'a cappella', 'a capella', 'orchestral version', 'symphonic version',
    'lo fi', 'bass boosted', 'bass boost', 'dance version', 'jersey club',
  ];

  /// Words in front of "mix"/"edit" that do not name a remixer.
  static const mixNeutral = {
    'original', 'radio', 'extended', 'club', 'album', 'single', 'mono', 'stereo', 'main', 'clean', 'dirty',
    'explicit', 'instrumental', 'short', 'long', '12', '7', 'maxi', 'inch', 'the', 'full', 'final', 'new', 'video',
    'edit', 'version', 'and', 'a', 'an', 're', 'rough', 'dub', 'vocal',
  };

  static const explicitTrue = {'explicit', 'explicit version', 'dirty', 'dirty version', 'explicit edit', 'uncensored'};
  static const explicitFalse = {
    'clean', 'clean version', 'clean edit', 'edited', 'edited version', 'censored', 'radio clean',
  };

  /// Neutral qualifiers that explicitly denote the original recording.
  static const originalMarkers = {'original mix', 'original version', 'album version', 'original', 'main version'};

  /// "Version" in the languages qualifiers commonly use.
  static const versionWords = {'version', 'versio', 'versao', 'versione', 'versionen', 'versjon', 'fassung'};

  /// Compound tokens are split before these suffixes when the prefix is a
  /// known word ("koncertversion" → "koncert version").
  static const compoundSuffixes = ['versionen', 'version', 'versjon'];

  /// Words that describe a release or edition of the *same* recording
  /// ("Album Version", "Bonus Track", "Japan Deluxe Edition", "From the
  /// Motion Picture Soundtrack"). A "word Version" made of these is not a
  /// different version.
  static const neutralWords = {
    'album', 'original', 'main', 'single', 'ep', 'lp', 'cd', 'vinyl', 'digital', 'deluxe', 'edition', 'expanded',
    'special', 'anniversary', 'bonus', 'track', 'tracks', 'hidden', 'standard', 'regular', 'explicit', 'clean',
    'dirty', 'edited', 'censored', 'uncensored', 'uncut', 'unedited', 'full', 'complete', 'final', 'vocal', 'video',
    'music', 'official', 'us', 'uk', 'usa', 'international', 'intl', 'european', 'japan', 'soundtrack', 'ost',
    'film', 'movie', 'motion', 'picture', 'score', 'series', 'musical', 'theme', 'collectors', 'reissue', 'legacy',
    'remastered', 'remaster', 'mono', 'stereo', 'lyric', 'lyrics', 'audio', 'visualizer', 'visualiser',
  };

  /// Glue words that never decide anything on their own.
  static const connectorWords = {
    'the', 'a', 'an', 'and', 'of', 'from', 'to', 'by', 'at', 'in', 'on', 'for', 'with', 'de', 'del', 'la', 'le',
    'el', 'en', 'em', 'auf', 'pa', 'i', 'na', 'som', 'og', 'und', 'y', 'et', 'taken',
  };

  /// Language names (folded, several languages) → language code. A
  /// qualifier naming a language ("Spanish Version", "Versión en Español",
  /// "På Dansk") is a different vocal recording.
  static const languages = <String, String>{
    'spanish': 'es', 'espanol': 'es', 'castellano': 'es', 'espanola': 'es',
    'english': 'en', 'ingles': 'en', 'anglais': 'en', 'englisch': 'en', 'inglese': 'en', 'engelsk': 'en',
    'engelska': 'en', 'engels': 'en',
    'french': 'fr', 'francais': 'fr', 'frances': 'fr', 'franzosisch': 'fr', 'francese': 'fr', 'fransk': 'fr',
    'franska': 'fr',
    'german': 'de', 'deutsch': 'de', 'deutsche': 'de', 'aleman': 'de', 'allemand': 'de', 'tedesco': 'de',
    'tysk': 'de', 'tyska': 'de', 'duits': 'de',
    'italian': 'it', 'italiano': 'it', 'italien': 'it', 'italienisch': 'it', 'italiensk': 'it',
    'portuguese': 'pt', 'portugues': 'pt', 'portugais': 'pt', 'portugiesisch': 'pt', 'portuguesa': 'pt',
    'japanese': 'ja', 'japones': 'ja', 'japonais': 'ja', 'japanisch': 'ja', 'nihongo': 'ja', 'japansk': 'ja',
    'japanska': 'ja',
    'korean': 'ko', 'coreano': 'ko', 'coreen': 'ko', 'koreanisch': 'ko', 'koreansk': 'ko',
    'chinese': 'zh', 'mandarin': 'zh', 'cantonese': 'zh', 'chino': 'zh', 'chinois': 'zh', 'chinesisch': 'zh',
    'kinesisk': 'zh',
    'danish': 'da', 'dansk': 'da', 'danske': 'da', 'danois': 'da', 'danes': 'da', 'danisch': 'da',
    'swedish': 'sv', 'svenska': 'sv', 'svensk': 'sv', 'suedois': 'sv', 'sueco': 'sv', 'schwedisch': 'sv',
    'norwegian': 'no', 'norsk': 'no', 'norvegien': 'no', 'noruego': 'no', 'norwegisch': 'no',
    'dutch': 'nl', 'nederlands': 'nl', 'nederlandse': 'nl', 'neerlandais': 'nl', 'niederlandisch': 'nl',
    'finnish': 'fi', 'suomi': 'fi', 'suomeksi': 'fi',
    'polish': 'pl', 'polski': 'pl',
    'russian': 'ru', 'russkiy': 'ru', 'ruso': 'ru', 'russe': 'ru', 'russisch': 'ru', 'russisk': 'ru',
    'turkish': 'tr', 'turkce': 'tr', 'turkisch': 'tr',
    'arabic': 'ar', 'arabe': 'ar', 'arabisch': 'ar',
    'hindi': 'hi', 'greek': 'el', 'griego': 'el', 'hebrew': 'he', 'hebreo': 'he', 'catalan': 'ca', 'catala': 'ca',
    'icelandic': 'is', 'islenska': 'is', 'tagalog': 'tl', 'filipino': 'tl',
    'spanglish': 'es-en',
  };

  /// Prepositions of "En Español", "In English", "Auf Deutsch", "På Dansk".
  static const languagePrepositions = {'en', 'in', 'auf', 'pa', 'em', 'na', 'i', 'sung'};

  /// Words of lyric/subtitle videos ("English Lyrics", "Sub Español"): a
  /// language there names the subtitles, not the recording.
  static const lyricWords = {
    'lyric', 'lyrics', 'sub', 'subs', 'subtitle', 'subtitles', 'subtitled', 'subtitulado', 'subtitulada',
    'legendado', 'legenda', 'translation', 'translated', 'traduccion', 'traducida', 'traducao', 'traduzione',
    'letra', 'paroles', 'romanized', 'romaji', 'rom', 'han', 'eng', 'color', 'coded', 'cc', 'testo', 'tekst',
  };

  /// Last words that make a multi-word dash tail read as a version
  /// qualifier ("Song - Kygo Remix", "Song - Jay-Z Version").
  static const qualifierEndings = {
    'remix', 'mix', 'edit', 'version', 'rework', 'bootleg', 'flip', 'vip', 'refix', 'dub', 'remaster', 'remastered',
    'rmx', 'reedit', 'mashup', 'cover', 'demo', 'instrumental', 'karaoke', 'acoustic', 'unplugged',
  };

  static final _year = RegExp(r'^(19|20)\d\d$');
  static final _ordinal = RegExp(r'^\d+(?:st|nd|rd|th)$');

  /// Every token that appears in a keyword or phrase (glue words excluded).
  static final Set<String> keywordTokens = {
    ...remasterTokens, ...liveTokens, ...acousticTokens, ...instrumentalTokens, ...karaokeTokens, ...coverTokens,
    ...spedTokens, ...slowedTokens, ...demoTokens, ...reRecordedTokens, ...extendedTokens, ...remixTokens,
    for (final p in [
      ...livePhrases, ...acousticPhrases, ...instrumentalPhrases, ...karaokePhrases, ...coverPhrases,
      ...spedPhrases, ...slowedPhrases, ...demoPhrases, ...reRecordedPhrases, ...extendedPhrases, ...radioPhrases,
      ...remixPhrases, ...originalMarkers, ...explicitTrue, ...explicitFalse,
    ])
      ...p.split(' '),
    'mix', 'edit', 'take',
  }..removeAll(connectorWords);

  static bool isYear(String token) => _year.hasMatch(token);

  /// Whether [token] belongs to qualifier vocabulary at all (keywords,
  /// edition words, version words, languages, years, glue words).
  static bool isVocabulary(String token) =>
      isStrongVocabulary(token) || connectorWords.contains(token) || isYear(token) || _ordinal.hasMatch(token);

  /// Vocabulary that carries meaning on its own (not glue words or years).
  static bool isStrongVocabulary(String token) =>
      token.startsWith(remasterPrefix) ||
      keywordTokens.contains(token) ||
      neutralWords.contains(token) ||
      versionWords.contains(token) ||
      languages.containsKey(token);

  /// Neutral words, glue words, years and ordinals.
  static bool isNeutralToken(String token) =>
      neutralWords.contains(token) ||
      connectorWords.contains(token) ||
      versionWords.contains(token) ||
      isYear(token) ||
      _ordinal.hasMatch(token);
}
