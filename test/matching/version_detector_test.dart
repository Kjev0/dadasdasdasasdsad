import 'package:fermata/core/models/matching.dart';
import 'package:fermata/matching/version_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detector = VersionDetector();

  group('detectSegment', () {
    final cases = <String, Set<VersionTag>>{
      // Remixes and someone else's edits.
      'Kygo Remix': {VersionTag.remix},
      'Remix': {VersionTag.remix},
      'VIP': {VersionTag.remix},
      'Rogue VIP': {VersionTag.remix},
      'VIP Mix': {VersionTag.remix},
      'Bootleg': {VersionTag.remix},
      'Kygo Flip': {VersionTag.remix},
      'Rework': {VersionTag.remix},
      'Re-Work': {VersionTag.remix},
      'Kygo Edit': {VersionTag.remix},
      'Dub Mix': {VersionTag.remix},
      'Tiësto Mix': {VersionTag.remix},
      '8D Audio': {VersionTag.remix},
      'Remixed by Kygo': {VersionTag.remix},
      'Re-Mix': {VersionTag.remix},
      'Lo-Fi Version': {VersionTag.remix},
      'Lofi': {VersionTag.remix},
      'Bass Boosted': {VersionTag.remix},
      'Dance Version': {VersionTag.remix},
      'Jersey Club': {VersionTag.remix},
      // Any other "X Version" is an alternative arrangement ...
      'Jay-Z Version': {VersionTag.remix},
      'Duet Version': {VersionTag.remix},
      // ... unless it only names the edition or release.
      'Studio Version': {},
      'Video Version': {},
      '2011 Version': {},
      'From "Frozen" / Soundtrack Version': {},
      // Live.
      'Live': {VersionTag.live},
      'Live at Wembley 1986': {VersionTag.live},
      'En Vivo': {VersionTag.live},
      'Ao Vivo': {VersionTag.live},
      'Live fra Roskilde': {VersionTag.live},
      'Koncertversion': {VersionTag.live},
      'Liveversion': {VersionTag.live},
      'Liveoptagelse': {VersionTag.live},
      'From THE FIRST TAKE': {VersionTag.live},
      'MTV Unplugged': {VersionTag.live, VersionTag.acoustic},
      // Acoustic.
      'Acoustic': {VersionTag.acoustic},
      'Acoustic Version': {VersionTag.acoustic},
      'Akustisk': {VersionTag.acoustic},
      'Acústico': {VersionTag.acoustic},
      'Stripped': {VersionTag.acoustic},
      'Piano Version': {VersionTag.acoustic},
      // Extended / club.
      'Extended Mix': {VersionTag.extended},
      'Extended Version': {VersionTag.extended},
      'Club Mix': {VersionTag.extended},
      '12" Version': {VersionTag.extended},
      // Radio edits.
      'Radio Edit': {VersionTag.radioEdit},
      'Single Version': {VersionTag.radioEdit},
      'Edit': {VersionTag.radioEdit},
      // Instrumental / karaoke / cover.
      'Instrumental': {VersionTag.instrumental},
      'Instrumental Version': {VersionTag.instrumental},
      'Off Vocal': {VersionTag.instrumental},
      'Karaoke Version': {VersionTag.karaoke},
      'In the Style of Adele': {VersionTag.karaoke},
      'Cover': {VersionTag.cover},
      'Originally Performed by Adele': {VersionTag.cover},
      // Remasters.
      'Remastered 2011': {VersionTag.remaster},
      '2009 Remaster': {VersionTag.remaster},
      'Remasterizado': {VersionTag.remaster},
      'Mono': {VersionTag.remaster},
      '2017 Mix': {VersionTag.remaster},
      // Tempo-altered.
      'Sped Up': {VersionTag.sped},
      'Super Sped Up': {VersionTag.sped},
      'Nightcore': {VersionTag.sped},
      'Sped Up + Reverb': {VersionTag.sped},
      'Slowed + Reverb': {VersionTag.slowed},
      'Slowed': {VersionTag.slowed},
      'Reverb': {VersionTag.slowed},
      // Demos.
      'Demo': {VersionTag.demo},
      'Demo Version': {VersionTag.demo},
      'Take 3': {VersionTag.demo},
      'Take Two': {VersionTag.demo},
      'Alternate Take': {VersionTag.demo},
      // Re-recordings.
      "Taylor's Version": {VersionTag.reRecorded},
      'Re-Recorded': {VersionTag.reRecorded},
      "Taylor's Version (From The Vault)": {VersionTag.reRecorded},
      'Nyindspilning': {VersionTag.reRecorded},
      'New Version': {VersionTag.reRecorded},
      // Language versions (a different vocal recording).
      'Spanish Version': {VersionTag.language},
      'Versión en Español': {VersionTag.language},
      'En Español': {VersionTag.language},
      'På Dansk': {VersionTag.language},
      'Dansk Version': {VersionTag.language},
      'English Lyrics': {},
      'Sub Español': {},
      // Radio edits named after the 7" single.
      '7" Version': {VersionTag.radioEdit},
      // Neutral.
      'Original Mix': {},
      'Album Version': {},
      'Bonus Track': {},
      'From "The Movie"': {},
      'Deluxe': {},
      'Radio Edit Remastered 2010': {VersionTag.radioEdit, VersionTag.remaster},
    };
    cases.forEach((segment, tags) {
      test('"$segment" → ${tags.map((t) => t.name).join(', ')}', () {
        expect(detector.detectSegment(segment).tags, tags);
      });
    });

    test('neutral qualifiers name the release, not the song or the version', () {
      for (final q in ['Original Mix', 'Album Version', 'Bonus Track', 'Deluxe', '2011', 'From "Frozen"',
          'From the Motion Picture Soundtrack', 'Japan Bonus Track', 'Explicit']) {
        expect(detector.isNeutralQualifier(q), isTrue, reason: q);
      }
      for (final q in ['Pt. 1', 'Interlude', "I Can't Get No", 'Kygo Remix', 'Monstercat Release']) {
        expect(detector.isNeutralQualifier(q), isFalse, reason: q);
      }
    });

    test('the language of a language version is extracted', () {
      expect(detector.detectSegment('Spanish Version').language, 'es');
      expect(detector.detectSegment('Versión en Español').language, 'es');
      expect(detector.detectSegment('På Dansk').language, 'da');
    });

    test('remixer, remaster year and live venue are extracted', () {
      expect(detector.detectSegment('Kygo Remix').remixer, 'kygo');
      expect(detector.detectSegment('Remixed by Kygo').remixer, 'kygo');
      expect(detector.detectSegment('Remix').remixer, isNull);
      expect(detector.detectSegment('Remastered 2011').remasterYear, 2011);
      expect(detector.detectSegment('Live at Wembley 1986').liveDetail, 'wembley 1986');
    });
  });

  group('detectInTitle', () {
    final cases = <String, Set<VersionTag>>{
      'Song (Live)': {VersionTag.live},
      'Song [Live]': {VersionTag.live},
      'Song - Live': {VersionTag.live},
      'Song - Acoustic Version': {VersionTag.acoustic},
      'Song (Kygo Remix) - Radio Edit': {VersionTag.remix, VersionTag.radioEdit},
      'Song (Instrumental)': {VersionTag.instrumental},
      // Words in the bare title are not versions.
      'Live Forever': {},
      'Acoustic Love': {},
      'Remix to Ignition': {},
    };
    cases.forEach((title, tags) {
      test('"$title"', () => expect(detector.detectInTitle(title).tags, tags));
    });
  });

  group('detectInAlbum', () {
    final cases = <String, Set<VersionTag>>{
      'Live at Wembley': {VersionTag.live},
      'Live': {VersionTag.live},
      'Alive in Tokyo (Live)': {VersionTag.live},
      'MTV Unplugged in New York': {VersionTag.live, VersionTag.acoustic},
      "Fearless (Taylor's Version)": {VersionTag.reRecorded},
      'Abbey Road (Remastered)': {VersionTag.remaster},
      'Hits (Karaoke Version)': {VersionTag.karaoke},
      'Hits (Sped Up)': {VersionTag.sped},
      // Remix/club EPs usually contain the original too.
      'Adventure (The Remixes)': {},
      'Adventure (Extended Mixes)': {},
      'Live Forever': {},
      'Stripped': {},
    };
    cases.forEach((album, tags) {
      test('"$album"', () => expect(detector.detectInAlbum(album).tags, tags));
    });
  });

  group('compare', () {
    VersionInfo v(String title) => detector.detectInTitle(title);

    test('identical versions have no difference', () {
      expect(detector.compare(v('Song (Kygo Remix)'), v('Song - Kygo Remix')), isEmpty);
      expect(detector.compare(v('Song (Live at Wembley)'), v('Song - Live At Wembley')), isEmpty);
    });

    test('different remixers are different remixes', () {
      expect(detector.compare(v('Song (Kygo Remix)'), v('Song (Tiësto Remix)')), {MatchDifference.remix});
    });

    test('remix with unknown remixer vs named remix is not flagged', () {
      expect(detector.compare(v('Song (Remix)'), v('Song (Kygo Remix)')), isEmpty);
    });

    test('different concerts are different live recordings', () {
      expect(detector.compare(v('Song (Live at Wembley)'), v('Song (Live in Tokyo)')), {MatchDifference.live});
    });

    test('language versions: same language is the same version, another language is a cover', () {
      expect(detector.compare(v('Song (Spanish Version)'), v('Song (Versión en Español)')), isEmpty);
      expect(detector.compare(v('Song (Spanish Version)'), v('Song (English Version)')), {MatchDifference.cover});
      expect(detector.compare(v('Song (Spanish Version)'), v('Song')), {MatchDifference.cover});
      expect(v('Song (Spanish Version)').isSignificant, isTrue);
    });

    test('remaster vs original is a non-significant difference', () {
      final d = detector.compare(v('Song - Remastered 2011'), v('Song'));
      expect(d, {MatchDifference.remaster});
      expect(MatchCandidate.significantVersionDifferences.intersection(d), isEmpty);
    });

    test('remasters of different years are flagged', () {
      expect(detector.compare(v('Song - 2011 Remaster'), v('Song - 2015 Remaster')), {MatchDifference.remaster});
    });

    test("re-recordings (Taylor's Version) are reported as a significant cover difference", () {
      final d = detector.compare(v("Love Story (Taylor's Version)"), v('Love Story'));
      expect(d, {MatchDifference.cover});
      expect(v("Love Story (Taylor's Version)").isSignificant, isTrue);
    });

    test('every tag maps to a MatchDifference; only remaster/radio edit are not significant', () {
      for (final tag in VersionTag.values) {
        final significant = MatchCandidate.significantVersionDifferences.contains(VersionDetector.differenceFor(tag));
        expect(significant, !(tag == VersionTag.remaster || tag == VersionTag.radioEdit), reason: tag.name);
      }
    });
  });
}
