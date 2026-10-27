import 'package:fermata/core/models/track.dart';
import 'package:fermata/matching/normalizer.dart';
import 'package:fermata/matching/version_detector.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  group('CharFolding.fold', () {
    const cases = {
      'Beyoncé': 'beyonce',
      'Mötley Crüe': 'motley crue',
      'Sigur Rós': 'sigur ros',
      'Ærø': 'aero',
      'Øresund': 'oresund',
      'Ålborg': 'alborg',
      'Straße': 'strasse',
      'Łódź': 'lodz',
      'Œuvre': 'oeuvre',
      'Þór': 'thor',
      'Ｆｕｌｌｗｉｄｔｈ': 'fullwidth',
      'ﬁre': 'fire',
      'Señorita': 'senorita',
      'Ça Plane Pour Moi': 'ca plane pour moi',
      'Dvořák': 'dvorak',
      'Café́': 'cafe', // decomposed accent (combining mark)
      'Zero​width': 'zerowidth',
    };
    cases.forEach((input, expected) {
      test('"$input" → "$expected"', () => expect(CharFolding.fold(input), expected));
    });

    test('non-Latin scripts pass through (lower-cased)', () {
      expect(CharFolding.fold('Кино'), 'кино');
      expect(CharFolding.fold('坂本龍一'), '坂本龍一');
    });

    test('Danish/German letters have a digraph transliteration variant', () {
      expect(CharFolding.fold('Mø', transliterate: true), 'moe');
      expect(CharFolding.fold('Ålborg', transliterate: true), 'aalborg');
      expect(CharFolding.fold('Björk', transliterate: true), 'bjoerk');
      expect(CharFolding.fold('Über', transliterate: true), 'ueber');
      // æ is "ae" in both forms, so it is consistent either way.
      expect(CharFolding.fold('Æ'), 'ae');
      expect(CharFolding.fold('Æ', transliterate: true), 'ae');
    });
  });

  group('TextKeys', () {
    const titles = {
      'Rock & Roll': 'rock and roll',
      'Rock + Roll': 'rock and roll',
      "Rock 'n' Roll": 'rock and roll',
      'Don’t Stop Me Now': 'dont stop me now',
      'Part Two': 'part 2',
      'Pt. II': 'part 2',
      'Symphony No. 5 in C minor': 'symphony no 5 in c minor',
      '  Lots   of\tspace  ': 'lots of space',
      'Fire 🔥🔥 Song ♪': 'fire song',
      'Hello, World!': 'hello world',
      'ŠKODA – Jízda': 'skoda jizda',
    };
    titles.forEach((input, expected) {
      test('title "$input" → "$expected"', () => expect(TextKeys.title(input).key, expected));
    });

    const artists = {
      'The Beatles': 'beatles',
      'Rogue - Topic': 'rogue',
      'TaylorSwiftVEVO': 'taylorswift',
      'Rogue Official': 'rogue',
      'P!nk': 'pink',
      'Ke\$ha': 'kesha',
      'A\$AP Rocky': 'asap rocky',
      'The The': 'the the',
      'Topic': 'topic',
      'Sigur Rós': 'sigur ros',
    };
    artists.forEach((input, expected) {
      test('artist "$input" → "$expected"', () => expect(TextKeys.artistName(input).key, expected));
    });

    test('alt key only differs when transliteration applies', () {
      expect(TextKeys.artistName('Mø').hasAlt, isTrue);
      expect(TextKeys.artistName('Mø').alt, 'moe');
      expect(TextKeys.artistName('Moe').hasAlt, isFalse);
    });
  });

  group('ArtistParser', () {
    final cases = <String, (List<String>, List<String>)>{
      'Simon & Garfunkel': (['Simon', 'Garfunkel'], []),
      'Simon and Garfunkel': (['Simon', 'Garfunkel'], []),
      'Kygo og Mø': (['Kygo', 'Mø'], []),
      'Rogue x Kygo': (['Rogue', 'Kygo'], []),
      'Rogue × Kygo': (['Rogue', 'Kygo'], []),
      'Florence + The Machine': (['Florence', 'The Machine'], []),
      'A, B; C': (['A', 'B', 'C'], []),
      'A vs. B': (['A', 'B'], []),
      'Rogue feat. Kygo & Mø': (['Rogue'], ['Kygo', 'Mø']),
      'Rogue ft Kygo': (['Rogue'], ['Kygo']),
      'Rogue (feat. Kygo)': (['Rogue'], ['Kygo']),
      'Rogue with Kygo': (['Rogue'], ['Kygo']),
      'AC/DC': (['AC/DC'], []),
      'Jay-Z': (['Jay-Z'], []),
    };
    cases.forEach((input, expected) {
      test('split "$input"', () {
        final s = ArtistParser.split(input);
        expect(s.primary, expected.$1);
        expect(s.featured, expected.$2);
      });
    });

    test('splitRefs: first credit is primary, later credits featured', () {
      final s = ArtistParser.splitRefs(const [ArtistRef('Calvin Harris & Dua Lipa'), ArtistRef('Young Thug')]);
      expect(s.primary, ['Calvin Harris', 'Dua Lipa']);
      expect(s.featured, ['Young Thug']);
    });
  });

  group('TitleParser', () {
    const parser = TitleParser();
    final cases = <String, ({String base, List<String> q, List<String> feat})>{
      'Bohemian Rhapsody - Remastered 2011': (base: 'Bohemian Rhapsody', q: ['Remastered 2011'], feat: []),
      'Bohemian Rhapsody – Live Aid': (base: 'Bohemian Rhapsody', q: ['Live Aid'], feat: []),
      'Song (feat. Kygo & Mø)': (base: 'Song', q: [], feat: ['Kygo & Mø']),
      'Song [ft. Kygo]': (base: 'Song', q: [], feat: ['Kygo']),
      'Song featuring Kygo': (base: 'Song', q: [], feat: ['Kygo']),
      'Song (with Ariana Grande)': (base: 'Song', q: [], feat: ['Ariana Grande']),
      'Song ft. Kygo - Radio Edit': (base: 'Song', q: ['Radio Edit'], feat: ['Kygo']),
      'Song (Kygo Remix feat. Mø)': (base: 'Song', q: ['Kygo Remix'], feat: ['Mø']),
      'Song (Live at Wembley) [Remastered]': (base: 'Song', q: ['Live at Wembley', 'Remastered'], feat: []),
      'Song (Official Music Video)': (base: 'Song', q: [], feat: []),
      'Song [Official Lyric Video] (HD)': (base: 'Song', q: [], feat: []),
      'Song Official Video': (base: 'Song', q: [], feat: []),
      'Song | Official Video': (base: 'Song', q: [], feat: []),
      'Song (prod. Metro Boomin)': (base: 'Song', q: [], feat: []),
      'Song prod. by Metro Boomin': (base: 'Song', q: [], feat: []),
      'Song 🔥 #edm #house2024': (base: 'Song', q: [], feat: []),
      'Song - From "The Movie"': (base: 'Song', q: ['From "The Movie"'], feat: []),
      'Song - Bonus Track': (base: 'Song', q: ['Bonus Track'], feat: []),
      'Nightcore - Song': (base: 'Song', q: ['Nightcore'], feat: []),
      'Blinding Lights Sped Up': (base: 'Blinding Lights', q: ['Sped Up'], feat: []),
      'Blinding Lights slowed + reverb': (base: 'Blinding Lights', q: ['slowed + reverb'], feat: []),
      '(I Can\'t Get No) Satisfaction': (base: 'Satisfaction', q: ["I Can't Get No"], feat: []),
    };
    cases.forEach((input, expected) {
      test('parse "$input"', () {
        final p = parser.parse(input);
        expect(p.base, expected.base, reason: 'base');
        expect(p.qualifiers, expected.q, reason: 'qualifiers');
        expect(p.featured, expected.feat, reason: 'featured');
      });
    });

    test('explicit/clean hints', () {
      expect(parser.parse('Song (Explicit)').explicitHint, isTrue);
      expect(parser.parse('Song [Clean]').explicitHint, isFalse);
      expect(parser.parse('Song').explicitHint, isNull);
      expect(parser.parse('Song (Explicit)').base, 'Song');
    });

    test('"Artist - Title" uploads are split', () {
      final p = parser.parse('Rogue - Adventure [Monstercat Release]');
      expect(p.hasArtistTitleSplit, isTrue);
      expect(p.splitArtist, 'Rogue');
      expect(p.splitTitle, 'Adventure');
    });

    test('"Artist - Title (Kygo Remix)" keeps the remix qualifier', () {
      final p = parser.parse('Rogue - Adventure (Kygo Remix) [Free Download]');
      expect(p.splitArtist, 'Rogue');
      expect(p.splitTitle, 'Adventure');
      expect(p.qualifiers, ['Kygo Remix']);
    });

    test('a qualifier after the dash is not an artist/title split', () {
      expect(parser.parse('Hey Jude - Remastered 2015').hasArtistTitleSplit, isFalse);
      expect(parser.parse('Song - Single Version').hasArtistTitleSplit, isFalse);
    });

    test('hyphenated words are not dash separators', () {
      final p = parser.parse('Re-Work It (Jay-Z Version)');
      expect(p.base, 'Re-Work It');
      expect(p.hasArtistTitleSplit, isFalse);
    });
  });

  group('TrackNormalizer', () {
    const normalizer = TrackNormalizer();

    test('SoundCloud label upload prefers the "Artist - Title" reading', () {
      final n = normalizer.normalize(track('soundcloud', '1', 'Rogue - Adventure', ['Monstercat']));
      expect(n.readings, hasLength(2));
      expect(n.primary.isArtistTitleSplit, isTrue);
      expect(n.primary.title.key, 'adventure');
      expect(n.primary.primaryArtists.single.key, 'rogue');
      expect(n.primary.displayArtist, 'Rogue');
    });

    test('streaming title with a subtitle keeps the full title first', () {
      final n = normalizer.normalize(track('spotify', '1', 'Requiem - Lacrimosa', ['Mozart']));
      expect(n.primary.isArtistTitleSplit, isFalse);
      expect(n.readings.last.isArtistTitleSplit, isTrue);
    });

    test('uploader equal to the left part prefers the split on any source', () {
      final n = normalizer.normalize(track('deezer', '1', 'Rogue - Adventure', ['Rogue']));
      expect(n.primary.isArtistTitleSplit, isTrue);
    });

    test('YouTube VEVO channel names are cleaned for display', () {
      final n = normalizer.normalize(track('youtube', '1', 'Adventure (Official Video)', ['RogueVEVO']));
      expect(n.primary.displayArtist, 'Rogue');
      expect(n.primary.primaryArtists.single.key, 'rogue');
    });

    test('featured artists from the title merge with the artist list', () {
      final n = normalizer.normalize(track('spotify', '1', 'Song (feat. Mø)', ['Kygo', 'Mø', 'Rogue']));
      expect(n.primary.featuredArtists.map((a) => a.key), ['mo', 'rogue']);
      expect(n.primary.title.key, 'song');
    });

    test('version comes from title qualifiers and album', () {
      final n = normalizer.normalize(track('spotify', '1', 'Hey Jude', ['Beatles'], album: 'Live at the BBC'));
      expect(n.version.has(VersionTag.live), isTrue);
      expect(n.versionQualifiers, isEmpty);
      final remix = normalizer.normalize(track('spotify', '2', 'Song (Kygo Remix) [Remastered]', ['A']));
      expect(remix.versionQualifiers, ['Kygo Remix']);
    });

    test('album keys drop edition words and detect singles', () {
      final n = normalizer.normalize(track('spotify', '1', 'Song', ['A'], album: 'Greatest Hits (Deluxe Edition)'));
      expect(n.album!.key, 'greatest hits');
      expect(n.albumIsSingle, isFalse);
      final single = normalizer.normalize(track('spotify', '2', 'Song', ['A'], album: 'Song - Single'));
      expect(single.albumIsSingle, isTrue);
      final named = normalizer.normalize(track('spotify', '3', 'Song', ['A'], album: 'Song'));
      expect(named.albumIsSingle, isTrue);
    });

    test('explicit falls back to the title hint', () {
      expect(normalizer.normalize(track('x', '1', 'Song (Explicit)', ['A'])).explicit, isTrue);
      expect(normalizer.normalize(track('x', '1', 'Song (Clean)', ['A'], explicit: true)).explicit, isTrue);
    });

    test('ISRC normalization is case- and separator-insensitive', () {
      expect(TrackNormalizer.normalizeIsrc(' us-abc-12-34567 '), 'USABC1234567');
      expect(TrackNormalizer.normalizeIsrc('USABC1234567'), 'USABC1234567');
      expect(TrackNormalizer.normalizeIsrc('  '), isNull);
      expect(TrackNormalizer.normalizeIsrc(null), isNull);
    });
  });
}
