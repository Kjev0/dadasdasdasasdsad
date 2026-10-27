// Adversarial review: title parsing defects that break the "Artist - Title"
// requirement and the "never silently replace a studio recording" rule.
//
// Every test in this file failed before the review fixes; they now guard
// against regressions (see review_fixes_test.dart for the fixes' own tests).
import 'package:fermata/core/models/matching.dart';
import 'package:fermata/matching/matching.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  final scorer = WeightedTrackScorer();
  const parser = TitleParser();

  group('REVIEW: "Artist - Title" uploads whose title contains a version keyword', () {
    // TitleParser._isQualifier treats any dash tail in which VersionDetector
    // finds a keyword token ("live", "stereo", "tribute", "cover", "remix",
    // "stripped") as a qualifier, so the "Artist - Title" split is lost, the
    // song title becomes a version tag and the artist becomes the title.
    const uploads = {
      'Oasis - Live Forever': ('Oasis', 'Live Forever'),
      "One Direction - Live While We're Young": ('One Direction', "Live While We're Young"),
      'Gym Class Heroes - Stereo Hearts': ('Gym Class Heroes', 'Stereo Hearts'),
      'Tenacious D - Tribute': ('Tenacious D', 'Tribute'),
      'Bruce Springsteen - Cover Me': ('Bruce Springsteen', 'Cover Me'),
      'R. Kelly - Remix to Ignition': ('R. Kelly', 'Remix to Ignition'),
      // _qualifierLead also swallows tails starting with a year, "From",
      // "Single", "Original", "Live", "Mono", "Album", ...
      'Prince - 1999': ('Prince', '1999'),
      'Anne-Marie - 2002': ('Anne-Marie', '2002'),
      'Beyoncé - Single Ladies': ('Beyoncé', 'Single Ladies'),
      'Hozier - From Eden': ('Hozier', 'From Eden'),
      'INXS - Original Sin': ('INXS', 'Original Sin'),
    };
    uploads.forEach((raw, expected) {
      test('"$raw" is split into artist + title', () {
        final p = parser.parse(raw);
        expect(p.splitArtist, expected.$1, reason: 'qualifiers=${p.qualifiers}');
        expect(p.splitTitle, expected.$2, reason: 'qualifiers=${p.qualifiers}');
      });
    });

    test('a SoundCloud label upload "Oasis - Live Forever" matches the Spotify studio track', () {
      final spotify = track('spotify', 's1', 'Live Forever', ['Oasis'], seconds: 276);
      final upload = track('soundcloud', 'sc1', 'Oasis - Live Forever', ['Big Brother Recordings'], seconds: 276);
      final m = scorer.score(spotify, upload);
      // Before the fix: score ~0.36, confidence none, differences {live, titleMismatch}.
      expect(m.differences, isNot(contains(MatchDifference.live)));
      expect(m.confidence.isAtLeast(MatchConfidence.high), isTrue,
          reason: 'score=${m.score} ${m.confidence} ${m.differences}');
    });

    test('the YouTube video "Prince - 1999 (Official Music Video)" matches Spotify "1999"', () {
      final m = scorer.score(
        track('spotify', 's1', '1999', ['Prince'], seconds: 379),
        track('youtube', 'y1', 'Prince - 1999 (Official Music Video)', ['Prince'], seconds: 379),
      );
      // Before the fix: 0.445 none, title 0.0 (title key "prince" vs "1999").
      expect(m.confidence.isAtLeast(MatchConfidence.high), isTrue, reason: '${m.score} ${m.breakdown}');
    });

    test('importing that SoundCloud upload finds the Deezer track (end to end)', () async {
      final deezer = FakeSource('deezer', catalog: [
        track('deezer', 'd1', 'Live Forever', ['Oasis'], seconds: 276),
      ]);
      final matcher = SourceTrackMatcher(registry: FakeRegistry([deezer]), scorer: WeightedTrackScorer());
      final original = track('soundcloud', 'sc1', 'Oasis - Live Forever', ['Big Brother Recordings'], seconds: 276);
      final result = await matcher.findMatches(original, const MatchOptions(targetSources: ['deezer']));
      // Before the fix: notFound: the original is classified as a *live* version
      // titled "Oasis", and the query sent is "Big Brother Recordings Oasis Live Forever".
      expect(result.decision, MatchDecision.autoAccepted,
          reason: 'queries=${deezer.queries} best=${result.best?.confidence} ${result.best?.differences}');
    });
  });

  group('REVIEW: bracketed non-version qualifiers are dropped from the title key', () {
    // TitleParser moves every bracket that is not feat/prod/noise/explicit
    // into `qualifiers`; only significant *version* qualifiers survive (in
    // VersionInfo). "(Pt. 1)" / "(Pt. 2)", "(Intro)", "(Interlude)" vanish,
    // so different songs compare as identical titles (title = 1.0).
    test('"(Pt. 1)" vs "(Pt. 2)" is not a high-confidence match', () {
      final o = track('deezer', 'd1', 'Father Stretch My Hands (Pt. 1)', ['Kanye West'], seconds: 135);
      final c = track('audius', 'a1', 'Father Stretch My Hands (Pt. 2)', ['Kanye West'], seconds: 130);
      final m = scorer.score(o, c);
      // Before the fix: 0.976 high, breakdown title = 1.0, no differences.
      expect(m.confidence.isAtLeast(MatchConfidence.high), isFalse,
          reason: 'score=${m.score} ${m.confidence} ${m.breakdown}');
    });

    test('the matcher does not auto-accept part 2 for part 1', () async {
      final audius = FakeSource('audius', catalog: [
        track('audius', 'a2', 'Father Stretch My Hands (Pt. 2)', ['Kanye West'], seconds: 130),
      ]);
      final matcher = SourceTrackMatcher(registry: FakeRegistry([audius]), scorer: WeightedTrackScorer());
      final original = track('deezer', 'd1', 'Father Stretch My Hands (Pt. 1)', ['Kanye West'], seconds: 135);
      final result = await matcher.findMatches(original, const MatchOptions(targetSources: ['audius']));
      expect(result.decision, isNot(MatchDecision.autoAccepted));
    });

    test('"Song (Interlude)" is not the same title as "Song"', () {
      final o = track('spotify', 's1', 'Pray', ['Artist'], seconds: 200);
      final c = track('deezer', 'd1', 'Pray (Interlude)', ['Artist'], seconds: 201);
      expect(scorer.score(o, c).breakdown[ScoreKeys.title], lessThan(1.0));
    });

    test('the same song in Spotify ("Pt. 2") and bracket ("(Part 2)") style still matches', () {
      // The flip side of the same root cause: "(Part 2)" is dropped on one
      // side only, so the real match falls to low (title 0.48).
      final o = track('spotify', 's1', 'Another Brick in the Wall, Pt. 2', ['Pink Floyd'], seconds: 239);
      final c = track('deezer', 'd1', 'Another Brick In The Wall (Part 2)', ['Pink Floyd'], seconds: 239);
      final m = scorer.score(o, c);
      expect(m.confidence.isAtLeast(MatchConfidence.medium), isTrue,
          reason: 'score=${m.score} ${m.confidence} ${m.breakdown}');
    });
  });

  group('REVIEW: remix variants that VersionDetector misses (studio silently replaced)', () {
    // These are remixes / re-edits of the studio recording. None is detected,
    // so each scores 1.0 / high against the studio original and would be
    // auto-accepted ("Never silently replace a studio recording with a remix").
    const variants = [
      'Blinding Lights (Re-Mix)',
      'Blinding Lights (Lo-Fi Version)',
      'Blinding Lights (Lofi)',
      'Blinding Lights (Bass Boosted)',
      'Blinding Lights (Dance Version)',
    ];
    final studio = track('spotify', 's1', 'Blinding Lights', ['The Weeknd'], seconds: 200);
    for (final title in variants) {
      test('"$title" is a significant version difference', () {
        final m = scorer.score(studio, track('soundcloud', 'x', title, ['The Weeknd'], seconds: 201));
        expect(m.hasSignificantVersionDifference, isTrue, reason: 'score=${m.score} ${m.confidence}');
        expect(m.confidence.isAtLeast(MatchConfidence.high), isFalse);
      });
    }
  });
}
