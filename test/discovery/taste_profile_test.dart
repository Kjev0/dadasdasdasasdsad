import 'package:fermata/core/models/library.dart';
import 'package:fermata/discovery/recommendations/taste_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

PlayRecord play(String id, String artist, DateTime at,
        {int listened = 200, int seconds = 200, bool completed = true, String? genre, String source = 'audius'}) =>
    PlayRecord(
      track: tr(source, id, artist: artist, seconds: seconds, genre: genre),
      playedAt: at,
      listened: Duration(seconds: listened),
      completed: completed,
    );

void main() {
  const tuning = TasteTuning();
  final now = DateTime(2026, 10, 27, 12);

  group('time decay', () {
    test('halves every half-life', () {
      expect(TasteProfile.decay(Duration.zero, tuning.halfLife), 1.0);
      expect(TasteProfile.decay(tuning.halfLife, tuning.halfLife), closeTo(0.5, 1e-9));
      expect(TasteProfile.decay(tuning.halfLife * 2, tuning.halfLife), closeTo(0.25, 1e-9));
      expect(TasteProfile.decay(const Duration(days: -3), tuning.halfLife), 1.0, reason: 'future plays count as now');
    });
  });

  group('play weights', () {
    test('completed play weighs 1', () {
      expect(TasteProfile.playWeight(play('a', 'A', now), tuning), 1.0);
    });

    test('a short, incomplete listen is a skip with a penalty', () {
      final r = play('a', 'A', now, listened: 10, completed: false);
      expect(TasteProfile.isSkip(r, tuning), isTrue);
      expect(TasteProfile.playWeight(r, tuning), -tuning.skipPenalty);
    });

    test('short interlude played past half is not a skip', () {
      final r = play('a', 'A', now, listened: 25, seconds: 40, completed: false);
      expect(TasteProfile.isSkip(r, tuning), isFalse);
      expect(TasteProfile.playWeight(r, tuning), closeTo(25 / 40, 1e-9));
    });

    test('partial listens weigh the listened share, at least the minimum', () {
      expect(TasteProfile.playWeight(play('a', 'A', now, listened: 100, completed: false), tuning), closeTo(0.5, 1e-9));
      // 40 s of 400 s: not a skip (≥ 30 s) but only 10 % → clamped to 0.25.
      final r = play('a', 'A', now, listened: 40, seconds: 400, completed: false);
      expect(TasteProfile.isSkip(r, tuning), isFalse);
      expect(TasteProfile.playWeight(r, tuning), tuning.partialMinWeight);
    });
  });

  group('profile', () {
    test('artist affinity sums decayed plays, skips subtract, favorites add a constant', () {
      final p = TasteProfile.build(
        history: [
          play('1', 'Alpha', now), // 1.0
          play('2', 'Alpha', now.subtract(tuning.halfLife)), // 0.5
          play('3', 'Beta', now), // 1.0
          play('4', 'Beta', now, listened: 5, completed: false), // -0.75
          play('5', 'Gamma', now.subtract(tuning.halfLife * 2)), // 0.25
        ],
        favorites: [tr('audius', '6', artist: 'Gamma')], // +3
        now: now,
      );
      expect(p.artists['alpha']!.score, closeTo(1.5, 1e-9));
      expect(p.artists['beta']!.score, closeTo(0.25, 1e-9));
      expect(p.artists['beta']!.skips, 1);
      expect(p.artists['gamma']!.score, closeTo(3.25, 1e-9));
      expect(p.artists['gamma']!.favorites, 1);
      expect([for (final a in p.topArtists()) a.name], ['Gamma', 'Alpha', 'Beta']);
    });

    test('an artist the user keeps skipping drops out of the top artists', () {
      final p = TasteProfile.build(
        history: [
          play('1', 'Skipped', now, listened: 3, completed: false),
          play('2', 'Skipped', now, listened: 3, completed: false),
          play('3', 'Liked', now),
        ],
        favorites: const [],
        now: now,
      );
      expect(p.artists['skipped']!.score, lessThan(0));
      expect([for (final a in p.topArtists()) a.key], ['liked']);
      expect(p.trackScores['audius:1'], lessThan(0));
      expect(p.knownTracksOf({'skipped'}), isEmpty, reason: 'skipped tracks are not "favorites" in mixes');
    });

    test('genre affinity uses positive evidence and keeps display names', () {
      final p = TasteProfile.build(
        history: [
          play('1', 'A', now, genre: 'Hip-Hop/Rap'),
          play('2', 'B', now, genre: 'Electronic; House'),
          play('3', 'B', now, genre: 'Electronic'),
        ],
        favorites: const [],
        now: now,
      );
      expect(p.topGenres(limit: 3), ['Electronic', 'Hip-Hop/Rap', 'House']);
      expect(p.artists['b']!.dominantGenre, 'electronic');
    });

    test('knows the same song across providers and remembers artist ids', () {
      final p = TasteProfile.build(
        history: [
          PlayRecord(
            track: tr('audius', 'x1', title: 'Night Drive (feat. Someone)', artist: 'The Synths', artistId: 'u42'),
            playedAt: now,
            listened: const Duration(minutes: 3),
            completed: true,
          ),
        ],
        favorites: const [],
        now: now,
      );
      expect(p.knows(tr('deezer', '99', title: 'Night Drive', artist: 'Synths')), isTrue);
      expect(p.knows(tr('deezer', '98', title: 'Day Drive', artist: 'Synths')), isFalse);
      expect(p.artists['synths']!.sourceArtistIds, {'audius': 'u42'});
    });
  });
}
