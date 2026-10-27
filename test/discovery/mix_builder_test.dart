import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/discovery/recommendations/mix_builder.dart';
import 'package:fermata/discovery/recommendations/taste_profile.dart';
import 'package:fermata/discovery/util/seeded_random.dart';
import 'package:fermata/discovery/util/text_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

List<Track> tracksOf(String prefix, String artist, int n, {String source = 'audius'}) =>
    [for (var i = 0; i < n; i++) tr(source, '$prefix$i', title: '$prefix song $i', artist: artist)];

void main() {
  group('compose', () {
    final known = [
      ...tracksOf('k', 'Known A', 12),
      ...tracksOf('l', 'Known B', 12),
      ...tracksOf('m', 'Known C', 12),
    ];
    final discoveries = [
      for (var i = 0; i < 40; i++) tr('audius', 'd$i', title: 'Disc $i', artist: 'New ${i % 8}'),
    ];

    test('25–50 tracks, ~60 % familiar, no artist more than 3× in a row', () {
      final mix = MixBuilder.compose(known: known, discoveries: discoveries, rng: SeededRandom.fromString('x'));
      expect(mix.length, inInclusiveRange(25, 50));
      final familiar = mix.where((t) => t.sourceTrackId.startsWith(RegExp('[klm]'))).length;
      expect(familiar / mix.length, closeTo(0.6, 0.05));
      expect(MixBuilder.longestArtistRun(mix), lessThanOrEqualTo(3));
      expect({for (final t in mix) t.id}.length, mix.length, reason: 'no duplicates');
    });

    test('is deterministic for a seed and varies across seeds', () {
      List<String> ids(String seed) => [
            for (final t in MixBuilder.compose(known: known, discoveries: discoveries, rng: SeededRandom.fromString(seed))) t.id,
          ];
      expect(ids('2026-10-27'), ids('2026-10-27'));
      expect(ids('2026-10-27'), isNot(ids('2026-10-28')));
    });

    test('known songs found again on another provider are not "discoveries"', () {
      final mix = MixBuilder.compose(
        known: [tr('audius', 'a', title: 'Same Song', artist: 'X')],
        discoveries: [tr('deezer', 'b', title: 'Same Song (Remastered 2011)', artist: 'X'), ...tracksOf('d', 'Y', 3)],
        rng: SeededRandom(1),
      );
      expect(mix.where((t) => TextKeys.title(t.title) == 'same song'), hasLength(1));
    });

    test('uses everything when there is less material than the minimum', () {
      final mix = MixBuilder.compose(
        known: tracksOf('k', 'A', 3),
        discoveries: [...tracksOf('d', 'B', 3), ...tracksOf('e', 'C', 3)],
        rng: SeededRandom(7),
      );
      expect(mix, hasLength(9));
    });

    test('fills from discoveries when there are few favorites', () {
      final mix = MixBuilder.compose(known: tracksOf('k', 'A', 2), discoveries: discoveries, rng: SeededRandom(3));
      expect(mix.length, greaterThanOrEqualTo(25));
    });
  });

  group('spaceArtists', () {
    test('breaks up long runs and keeps the rest of the order', () {
      final input = [...tracksOf('a', 'A', 7), ...tracksOf('b', 'B', 3)];
      final out = MixBuilder.spaceArtists(input, maxRun: 3);
      expect(MixBuilder.longestArtistRun(out), lessThanOrEqualTo(3));
      expect(out.first.id, input.first.id);
    });

    test('drops what cannot be placed without breaking the rule', () {
      final out = MixBuilder.spaceArtists(tracksOf('a', 'A', 6), maxRun: 3);
      expect(out, hasLength(3));
    });
  });

  test('interleave round-robins and dedupes by id and song', () {
    final a = [tr('audius', '1', title: 'One', artist: 'X'), tr('audius', '2', title: 'Two', artist: 'X')];
    final b = [tr('deezer', '9', title: 'One', artist: 'X'), tr('deezer', '8', title: 'Three', artist: 'Y')];
    expect([for (final t in MixBuilder.interleave([a, b])) t.id], ['audius:1', 'audius:2', 'deezer:8']);
    expect(MixBuilder.interleave([a, b], limit: 1), hasLength(1));
  });

  test('capPerArtist', () {
    final out = MixBuilder.capPerArtist([...tracksOf('a', 'A', 5), ...tracksOf('b', 'B', 1)], 2);
    expect(out, hasLength(3));
  });

  group('cluster', () {
    final now = DateTime(2026, 10, 27);
    PlayRecord p(String id, String artist, String genre, int n) =>
        PlayRecord(track: tr('audius', id, artist: artist, genre: genre), playedAt: now, listened: Duration(seconds: 200 * n), completed: true);

    test('one cluster per dominant genre, related artists join their genre', () {
      final profile = TasteProfile.build(
        history: [
          for (var i = 0; i < 5; i++) p('r$i', 'Rocker', 'Rock', 1),
          for (var i = 0; i < 4; i++) p('j$i', 'Jazzer', 'Jazz', 1),
          for (var i = 0; i < 3; i++) p('q$i', 'Rocker Two', 'Rock', 1),
          for (var i = 0; i < 2; i++) p('e$i', 'Beeper', 'Electronic', 1),
        ],
        favorites: const [],
        now: now,
      );
      final clusters = MixBuilder.cluster(profile, 3);
      expect([for (final c in clusters) c.seed.name], ['Rocker', 'Jazzer', 'Beeper']);
      expect(clusters.first.artistKeys, {'rocker', 'rocker two'});
      // Asking for more mixes than genres: the next strongest artist seeds one.
      expect([for (final c in MixBuilder.cluster(profile, 4)) c.seed.name], ['Rocker', 'Jazzer', 'Beeper', 'Rocker Two']);
    });

    test('fills with strong artists when there are fewer genres than mixes', () {
      final profile = TasteProfile.build(
        history: [
          for (var i = 0; i < 5; i++) p('a$i', 'A', 'Pop', 1),
          for (var i = 0; i < 4; i++) p('b$i', 'B', 'Pop', 1),
          for (var i = 0; i < 3; i++) p('c$i', 'C', 'Pop', 1),
        ],
        favorites: const [],
        now: now,
      );
      expect([for (final c in MixBuilder.cluster(profile, 2)) c.seed.name], ['A', 'B']);
      expect(MixBuilder.cluster(TasteProfile.build(history: const [], favorites: const [], now: now), 4), isEmpty);
    });
  });
}
