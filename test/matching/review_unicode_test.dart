// Adversarial review: Unicode / non-Latin title handling.
//
// Every test in this file failed before the review fixes; they now guard
// against regressions (see review_fixes_test.dart for the fixes' own tests).
import 'package:fermata/core/models/matching.dart';
import 'package:fermata/matching/matching.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  const parser = TitleParser();
  final scorer = WeightedTrackScorer();

  group('REVIEW: CJK quotation marks are treated as qualifier brackets', () {
    // TextSegments._open includes 「」 and 『』, which are Japanese *quotation
    // marks* around the song title (YOASOBI「夜に駆ける」, 米津玄師『Lemon』).
    // Their content is classified as a qualifier and dropped, so the title
    // key becomes the artist name.
    test('「…」 content stays in the title', () {
      final p = parser.parse('YOASOBI「夜に駆ける」 Official Music Video');
      expect(p.qualifiers, isNot(contains('夜に駆ける')));
      expect('${p.base} ${p.splitTitle ?? ''}', contains('夜に駆ける'));
    });

    test('a J-pop YouTube upload matches the Spotify track', () {
      final m = scorer.score(
        track('spotify', 's1', '夜に駆ける', ['YOASOBI'], seconds: 261),
        track('youtube', 'y1', 'YOASOBI「夜に駆ける」 Official Music Video', ['Ayase / YOASOBI'], seconds: 262),
      );
      // Before the fix: 0.445 none with title 0.0.
      expect(m.confidence.isAtLeast(MatchConfidence.medium), isTrue, reason: '${m.score} ${m.breakdown}');
    });
  });
}
