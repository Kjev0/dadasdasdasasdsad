import 'package:fermata/core/models/matching.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/ui/actions/routes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'settings_harness.dart';

/// Every page of this module lays out without overflow at phone, tablet and
/// desktop sizes, inside the real shell.
void main() {
  final routes = [
    '/settings',
    for (final id in SettingsSections.all) '/settings/$id',
    '/import',
    '/import/s1',
    '/onboarding',
  ];

  for (final size in [TestSizes.compact, TestSizes.medium, TestSizes.expanded]) {
    testWidgets('no overflow at $size', (tester) async {
      final kit = FakeKit(sources: [
        oauthSource(SourceIds.soundcloud, name: 'SoundCloud'),
        FakeMusicSource(id: SourceIds.audius, displayName: 'Audius'),
      ]);
      final t = testTrack('x', sourceId: SourceIds.spotify, title: 'A rather long original track title (Extended Version)');
      kit.imports.presetResults['pl'] = [
        TrackMatchResult(
          original: t,
          candidates: [
            MatchCandidate(
              candidate: testTrack('y', sourceId: SourceIds.soundcloud, title: 'A rather long original track title (Live at Somewhere)'),
              score: 0.8,
              confidence: MatchConfidence.medium,
              differences: const {MatchDifference.live, MatchDifference.durationMismatch, MatchDifference.explicitMismatch},
              durationDelta: const Duration(seconds: -42),
            ),
          ],
          decision: MatchDecision.needsReview,
        ),
      ];
      await kit.imports.start(sourceId: SourceIds.spotify, playlistIdOrUrl: 'pl', options: const MatchOptions());
      await pumpFermata(tester, kit: kit, size: size, overrides: settingsOverrides());
      for (final route in routes) {
        await goTo(tester, route);
        expect(tester.takeException(), isNull, reason: '$route at $size');
      }
    });
  }
}
