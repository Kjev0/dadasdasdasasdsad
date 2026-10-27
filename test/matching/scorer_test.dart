import 'package:fermata/core/models/matching.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/matching/scorer.dart';
import 'package:fermata/matching/scoring_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  final scorer = WeightedTrackScorer();
  final studio = track('spotify', 'o1', 'Adventure', ['Rogue'], album: 'Adventure', seconds: 210, year: 2016);

  MatchCandidate score(Track original, Track candidate) => scorer.score(original, candidate);

  group('ISRC', () {
    test('identical ISRC (case/whitespace-insensitive) → exact, score ≥ 0.98', () {
      final o = track('spotify', '1', 'Song', ['A'], isrc: 'USABC1234567', seconds: 200);
      final c = track('deezer', '2', 'Song (2011 Remaster)', ['A'], isrc: ' us-abc-12-34567', seconds: 201);
      final m = score(o, c);
      expect(m.confidence, MatchConfidence.exact);
      expect(m.matchedByIsrc, isTrue);
      expect(m.score, greaterThanOrEqualTo(0.98));
      expect(m.breakdown[ScoreKeys.isrc], 1);
    });

    test('identical ISRC but a remix tag → flagged and capped', () {
      final o = track('spotify', '1', 'Song', ['A'], isrc: 'USABC1234567', seconds: 200);
      final c = track('deezer', '2', 'Song (Kygo Remix)', ['A'], isrc: 'USABC1234567', seconds: 200);
      final m = score(o, c);
      expect(m.matchedByIsrc, isTrue);
      expect(m.confidence, MatchConfidence.low);
      expect(m.differences, contains(MatchDifference.remix));
      expect(m.score, lessThan(MatchThresholds.medium));
    });

    test('different ISRCs are not penalized (same recording, several releases)', () {
      final o = track('spotify', '1', 'Song', ['A'], isrc: 'USABC1234567', seconds: 200);
      final c = track('deezer', '2', 'Song', ['A'], isrc: 'GBXYZ7654321', seconds: 200);
      final m = score(o, c);
      expect(m.confidence, MatchConfidence.high);
      expect(m.breakdown[ScoreKeys.isrc], 0);
    });
  });

  group('studio original vs other versions is never high/medium', () {
    final versions = <String, MatchDifference>{
      'Adventure (Kygo Remix)': MatchDifference.remix,
      'Adventure (Rogue VIP)': MatchDifference.remix,
      'Adventure - Live at Wembley': MatchDifference.live,
      'Adventure (Acoustic)': MatchDifference.acoustic,
      'Adventure (Akustisk)': MatchDifference.acoustic,
      'Adventure (Extended Mix)': MatchDifference.extended,
      'Adventure (Instrumental)': MatchDifference.instrumental,
      'Adventure (Karaoke Version)': MatchDifference.karaoke,
      'Adventure (Cover)': MatchDifference.cover,
      'Adventure (Sped Up)': MatchDifference.sped,
      'Adventure Sped Up': MatchDifference.sped,
      'Nightcore - Adventure': MatchDifference.sped,
      'Adventure (Slowed + Reverb)': MatchDifference.slowed,
      'Adventure (Demo)': MatchDifference.demo,
      "Adventure (Taylor's Version)": MatchDifference.cover,
    };
    versions.forEach((title, diff) {
      test('"$title"', () {
        // Same duration and artist: only the version differs.
        final m = score(studio, track('deezer', 'c', title, ['Rogue'], album: 'Adventure', seconds: 210));
        expect(m.differences, contains(diff));
        expect(m.hasSignificantVersionDifference, isTrue);
        expect(m.confidence.isAtLeast(MatchConfidence.medium), isFalse, reason: 'confidence ${m.confidence}');
        expect(m.score, lessThan(MatchThresholds.medium));
        expect(m.breakdown[ScoreKeys.version], 0);
      });
    });

    test('and vice versa: a remix original does not match the studio version', () {
      final remix = track('soundcloud', 'r', 'Adventure (Kygo Remix)', ['Rogue'], seconds: 210);
      final m = score(remix, track('deezer', 'c', 'Adventure', ['Rogue'], seconds: 210));
      expect(m.differences, contains(MatchDifference.remix));
      expect(m.confidence, MatchConfidence.low);
    });

    test('album-level live recording vs studio', () {
      final m = score(studio, track('deezer', 'c', 'Adventure', ['Rogue'], album: 'Live at Red Rocks', seconds: 210));
      expect(m.differences, contains(MatchDifference.live));
      expect(m.confidence, MatchConfidence.low);
    });
  });

  group('matching versions', () {
    test('same remix matches with high confidence', () {
      final o = track('spotify', '1', 'Adventure - Kygo Remix', ['Rogue', 'Kygo'], seconds: 240);
      final c = track('deezer', '2', 'Adventure (Kygo Remix)', ['Rogue'], seconds: 241);
      final m = score(o, c);
      expect(m.hasSignificantVersionDifference, isFalse);
      expect(m.confidence, MatchConfidence.high);
    });

    test('different remixers are different remixes', () {
      final o = track('spotify', '1', 'Adventure - Kygo Remix', ['Rogue'], seconds: 240);
      final c = track('deezer', '2', 'Adventure (Tiësto Remix)', ['Rogue'], seconds: 240);
      expect(score(o, c).differences, contains(MatchDifference.remix));
    });

    test('remaster-only difference is allowed (flagged, not capped)', () {
      final o = track('spotify', '1', 'Bohemian Rhapsody - Remastered 2011', ['Queen'], seconds: 355);
      final c = track('deezer', '2', 'Bohemian Rhapsody', ['Queen'], seconds: 354);
      final m = score(o, c);
      expect(m.differences, contains(MatchDifference.remaster));
      expect(m.hasSignificantVersionDifference, isFalse);
      expect(m.confidence, MatchConfidence.high);
      expect(m.breakdown[ScoreKeys.version], 0.9);
    });

    test('explicit "Original Mix" equals the plain title', () {
      final o = track('spotify', '1', 'Strobe - Original Mix', ['deadmau5'], seconds: 637);
      final c = track('deezer', '2', 'Strobe', ['deadmau5'], seconds: 637);
      expect(score(o, c).confidence, MatchConfidence.high);
      expect(score(o, c).differences, isEmpty);
    });
  });

  group('duration bands', () {
    final cases = <int, ({MatchConfidence confidence, bool flagged})>{
      0: (confidence: MatchConfidence.high, flagged: false),
      2: (confidence: MatchConfidence.high, flagged: false),
      4: (confidence: MatchConfidence.high, flagged: false),
      8: (confidence: MatchConfidence.high, flagged: true),
      15: (confidence: MatchConfidence.medium, flagged: true),
      25: (confidence: MatchConfidence.medium, flagged: true),
      45: (confidence: MatchConfidence.low, flagged: true),
      -90: (confidence: MatchConfidence.low, flagged: true),
    };
    cases.forEach((delta, expected) {
      test('Δ ${delta}s → ${expected.confidence.name}', () {
        final m = score(studio, track('deezer', 'c', 'Adventure', ['Rogue'], album: 'Adventure', seconds: 210 + delta));
        expect(m.confidence, expected.confidence);
        expect(m.differences.contains(MatchDifference.durationMismatch), expected.flagged);
        expect(m.durationDelta, Duration(seconds: delta));
      });
    });

    test('score is monotonic in the duration difference', () {
      double at(int delta) =>
          score(studio, track('deezer', 'c', 'Adventure', ['Rogue'], album: 'Adventure', seconds: 210 + delta)).score;
      final scores = [for (final d in [0, 3, 6, 12, 20, 40]) at(d)];
      for (var i = 1; i < scores.length; i++) {
        expect(scores[i], lessThanOrEqualTo(scores[i - 1]));
      }
    });

    test('unknown duration on one side is neutral', () {
      final m = score(studio, track('deezer', 'c', 'Adventure', ['Rogue'], album: 'Adventure'));
      expect(m.confidence, MatchConfidence.high);
      expect(m.durationDelta, isNull);
      expect(m.breakdown.containsKey(ScoreKeys.duration), isFalse);
    });

    test('band function', () {
      expect(DurationBands.score(const Duration(milliseconds: 1500)), 1);
      expect(DurationBands.score(const Duration(seconds: 5)), closeTo(0.85, 1e-9));
      expect(DurationBands.score(const Duration(seconds: 10)), closeTo(0.45, 1e-9));
      expect(DurationBands.score(const Duration(seconds: 31)), 0);
    });
  });

  group('explicit / clean', () {
    test('explicit vs clean is flagged and capped at medium (a censored edit is never auto-accepted)', () {
      final o = track('spotify', '1', 'Song', ['A'], seconds: 200, explicit: true);
      final clean = score(o, track('deezer', '2', 'Song', ['A'], seconds: 200, explicit: false));
      final same = score(o, track('deezer', '3', 'Song', ['A'], seconds: 200, explicit: true));
      expect(clean.differences, contains(MatchDifference.explicitMismatch));
      expect(clean.confidence, MatchConfidence.medium);
      expect(same.confidence, MatchConfidence.high);
      expect(clean.score, lessThan(same.score));
      // ... and the other way round: a clean original vs the explicit one.
      final cleanOriginal = track('spotify', '4', 'Song', ['A'], seconds: 200, explicit: false);
      expect(score(cleanOriginal, track('deezer', '5', 'Song', ['A'], seconds: 200, explicit: true)).confidence,
          MatchConfidence.medium);
    });

    test('"(Clean)" in the title counts as clean', () {
      final o = track('spotify', '1', 'Song', ['A'], seconds: 200, explicit: true);
      final m = score(o, track('youtube', '2', 'A - Song (Clean)', ['A Music'], seconds: 200));
      expect(m.differences, contains(MatchDifference.explicitMismatch));
    });

    test('unknown explicit flag is neutral', () {
      final o = track('spotify', '1', 'Song', ['A'], seconds: 200, explicit: true);
      final m = score(o, track('soundcloud', '2', 'Song', ['A'], seconds: 200));
      expect(m.differences, isNot(contains(MatchDifference.explicitMismatch)));
      expect(m.breakdown.containsKey(ScoreKeys.explicit), isFalse);
    });
  });

  group('artists', () {
    test('featured artists are order-insensitive', () {
      final o = track('spotify', '1', 'Song', ['Kygo', 'Mø', 'Rogue'], seconds: 200);
      final m = score(o, track('deezer', '2', 'Song', ['Kygo', 'Rogue', 'Mø'], seconds: 200));
      expect(m.breakdown[ScoreKeys.featured], 1);
      expect(m.confidence, MatchConfidence.high);
    });

    test('features in the artist list match "(feat. X)" in the title', () {
      final o = track('spotify', '1', 'Firestone', ['Kygo', 'Conrad Sewell'], seconds: 271);
      final m = score(o, track('soundcloud', '2', 'Firestone (feat. Conrad Sewell)', ['Kygo'], seconds: 271));
      expect(m.breakdown[ScoreKeys.featured], 1);
      expect(m.differences, isEmpty);
      expect(m.confidence, MatchConfidence.high);
    });

    test('a missing featured artist is flagged but not disqualifying', () {
      final o = track('spotify', '1', 'Firestone', ['Kygo', 'Conrad Sewell'], seconds: 271);
      final m = score(o, track('deezer', '2', 'Firestone', ['Kygo'], seconds: 271));
      expect(m.differences, contains(MatchDifference.featuredArtistMismatch));
      expect(m.confidence, MatchConfidence.high);
    });

    test('same title by a different artist is not a match', () {
      final o = track('spotify', '1', 'Hello', ['Adele'], seconds: 295);
      final m = score(o, track('deezer', '2', 'Hello', ['Lionel Richie'], seconds: 270));
      expect(m.differences, contains(MatchDifference.artistMismatch));
      expect(m.confidence.isAtLeast(MatchConfidence.medium), isFalse);
    });

    test('Danish letters: Mø ≈ MØ ≈ MO', () {
      final o = track('spotify', '1', 'Final Song', ['MØ'], seconds: 236);
      expect(score(o, track('deezer', '2', 'Final Song', ['Mø'], seconds: 236)).confidence, MatchConfidence.high);
      expect(score(o, track('youtube', '3', 'Final Song', ['MO'], seconds: 236)).confidence, MatchConfidence.high);
    });

    test('"The" prefix and accents are ignored', () {
      final o = track('spotify', '1', 'Blinding Lights', ['The Weeknd'], seconds: 200);
      expect(score(o, track('deezer', '2', 'Blinding Lights', ['Weeknd'], seconds: 200)).confidence, MatchConfidence.high);
      final b = track('spotify', '3', 'Halo', ['Beyoncé'], seconds: 261);
      expect(score(b, track('deezer', '4', 'Halo', ['Beyonce'], seconds: 261)).confidence, MatchConfidence.high);
    });
  });

  group('SoundCloud/YouTube uploads', () {
    test('"Artist - Title" uploaded by a label account', () {
      final c = track('soundcloud', '2', 'Rogue - Adventure [Monstercat Release]', ['Monstercat'], seconds: 211);
      final m = score(studio, c);
      expect(m.confidence, MatchConfidence.high);
      expect(m.breakdown[ScoreKeys.artistTitleSplit], 1);
    });

    test('label upload as the original, streaming track as candidate', () {
      final o = track('soundcloud', '1', 'Rogue - Adventure (Free Download)', ['Monstercat Uncaged'], seconds: 210);
      expect(score(o, track('spotify', '2', 'Adventure', ['Rogue'], seconds: 210)).confidence, MatchConfidence.high);
    });

    test('YouTube official video from a VEVO channel', () {
      final c = track('youtube', '2', 'Rogue - Adventure (Official Video)', ['RogueVEVO'], seconds: 213);
      expect(score(studio, c).confidence, MatchConfidence.high);
    });

    test('label upload without the artist in the title is not a match', () {
      final m = score(studio, track('soundcloud', '2', 'Adventure', ['Monstercat'], seconds: 210));
      expect(m.differences, contains(MatchDifference.artistMismatch));
      expect(m.confidence.isAtLeast(MatchConfidence.medium), isFalse);
    });

    test('remix upload by a label is still a remix', () {
      final c = track('soundcloud', '2', 'Rogue - Adventure (Kygo Remix)', ['Monstercat'], seconds: 210);
      expect(score(studio, c).differences, contains(MatchDifference.remix));
    });
  });

  group('missing metadata', () {
    test('no album on one side is not penalized', () {
      final withAlbum = score(studio, track('deezer', '2', 'Adventure', ['Rogue'], album: 'Adventure', seconds: 210));
      final noAlbum = score(studio, track('deezer', '3', 'Adventure', ['Rogue'], seconds: 210));
      expect(noAlbum.breakdown.containsKey(ScoreKeys.album), isFalse);
      expect(noAlbum.confidence, MatchConfidence.high);
      expect(noAlbum.score, closeTo(withAlbum.score, 0.02));
    });

    test('no duration and no album anywhere still matches title + artist', () {
      final o = track('local', '1', 'Adventure', ['Rogue']);
      expect(score(o, track('deezer', '2', 'Adventure', ['Rogue'])).confidence, MatchConfidence.high);
    });

    test('candidate without artists is at most medium', () {
      final m = score(studio, track('youtube', '2', 'Adventure', const [], seconds: 210));
      expect(m.confidence.isAtLeast(MatchConfidence.high), isFalse);
      expect(m.breakdown.containsKey(ScoreKeys.artist), isFalse);
    });

    test('single vs album release is not an album mismatch', () {
      final m = score(studio, track('deezer', '2', 'Adventure', ['Rogue'], album: 'Best of Monstercat 2016', seconds: 210));
      expect(m.differences, isNot(contains(MatchDifference.albumMismatch)));
    });

    test('different albums are flagged but the match stays high', () {
      final o = track('spotify', '1', 'Song', ['A'], album: 'First Album', seconds: 200);
      final m = score(o, track('deezer', '2', 'Song', ['A'], album: 'Totally Different Record', seconds: 200));
      expect(m.differences, contains(MatchDifference.albumMismatch));
      expect(m.confidence, MatchConfidence.high);
    });

    test('year far apart is flagged', () {
      final m = score(studio, track('deezer', '2', 'Adventure', ['Rogue'], seconds: 210, year: 2022));
      expect(m.differences, contains(MatchDifference.yearMismatch));
    });
  });

  group('misc', () {
    test('unrelated song by the same artist → none', () {
      final o = track('spotify', '1', 'Hello', ['Adele'], seconds: 295);
      final m = score(o, track('deezer', '2', 'Someone Like You', ['Adele'], seconds: 285));
      expect(m.confidence, MatchConfidence.none);
      expect(m.differences, contains(MatchDifference.titleMismatch));
    });

    test('preview-only candidates are flagged', () {
      final c = track('deezer', '2', 'Adventure', ['Rogue'], seconds: 210, playback: PlaybackRights.preview);
      final m = score(studio, c);
      expect(m.differences, contains(MatchDifference.previewOnly));
      expect(m.confidence, MatchConfidence.high);
    });

    test('score stays consistent with the confidence band', () {
      // Weak title but everything else agrees: capped at low, so the score
      // must not exceed the low band.
      final o = track('spotify', '1', 'Hello', ['Adele'], seconds: 295);
      final m = score(o, track('deezer', '2', 'Hello World', ['Adele'], seconds: 295));
      expect(m.confidence, MatchConfidence.low);
      expect(m.score, lessThan(MatchThresholds.medium));
    });

    test('scoring is deterministic and in 0..1', () {
      final c = track('deezer', '2', 'Adventure (Live)', ['Rogue'], seconds: 230);
      final a = score(studio, c), b = score(studio, c);
      expect(a.score, b.score);
      expect(a.score, inInclusiveRange(0, 1));
      expect(a.breakdown, b.breakdown);
    });

    test('confidence band helper and ordering', () {
      const config = ScoringConfig();
      expect(config.band(0.95), MatchConfidence.high);
      expect(config.band(0.75), MatchConfidence.medium);
      expect(config.band(0.5), MatchConfidence.low);
      expect(config.band(0.2), MatchConfidence.none);
      expect(MatchConfidence.exact.isAtLeast(MatchConfidence.high), isTrue);
      expect(MatchConfidence.low.isAtLeast(MatchConfidence.medium), isFalse);
      expect(MatchConfidence.high.cappedAt(MatchConfidence.low), MatchConfidence.low);
      expect(MatchConfidence.none.cappedAt(MatchConfidence.low), MatchConfidence.none);
    });
  });
}
