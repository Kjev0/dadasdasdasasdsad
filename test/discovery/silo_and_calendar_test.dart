import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/discovery/recommendations/silo.dart';
import 'package:fermata/discovery/util/seeded_random.dart';
import 'package:fermata/discovery/util/text_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  group('SiloGuard', () {
    final sc = [for (var i = 0; i < 6; i++) tr(SourceIds.soundcloud, 's$i', artist: 'S')];
    final au = [for (var i = 0; i < 3; i++) tr(SourceIds.audius, 'a$i', artist: 'A')];
    final local = [tr(SourceIds.local, 'l1', artist: 'L')];

    test('never mixes SoundCloud with other services (local files may stay)', () {
      final mixed = [...au, ...sc, ...local];
      expect(SiloGuard.isValid(mixed), isFalse);
      final preferSc = SiloGuard.apply(mixed, preferSiloed: true);
      expect(SiloGuard.isValid(preferSc), isTrue);
      expect({for (final t in preferSc) t.sourceId}, {SourceIds.soundcloud, SourceIds.local});
    });

    test('without preference the larger group wins', () {
      final bigOpen = [...au, ...au.map((t) => tr(SourceIds.audius, '${t.sourceTrackId}x', artist: 'A')), sc.first];
      final out = SiloGuard.apply(bigOpen);
      expect(out.every((t) => t.sourceId == SourceIds.audius), isTrue);
    });

    test('a too small SoundCloud group does not win just because it is preferred', () {
      final out = SiloGuard.apply([...au, sc.first], preferSiloed: true, minSiloTracks: 5);
      expect(out.map((t) => t.sourceId).toSet(), {SourceIds.audius});
    });

    test('restrictTo follows SourcePolicies.canJoinSilo', () {
      final all = [...au, ...sc, ...local];
      expect(SiloGuard.restrictTo(all, SourceIds.soundcloud).map((t) => t.sourceId).toSet(),
          {SourceIds.soundcloud, SourceIds.local});
      expect(SiloGuard.restrictTo(all, null).map((t) => t.sourceId).toSet(), {SourceIds.audius, SourceIds.local});
    });
  });

  group('DiscoveryCalendar', () {
    test('ISO weeks across year boundaries', () {
      expect(DiscoveryCalendar.isoWeek(DateTime(2021, 1, 3)), (2020, 53));
      expect(DiscoveryCalendar.isoWeek(DateTime(2021, 1, 4)), (2021, 1));
      expect(DiscoveryCalendar.isoWeek(DateTime(2024, 12, 30)), (2025, 1));
      expect(DiscoveryCalendar.isoWeek(DateTime(2026, 10, 27)), (2026, 44));
      expect(DiscoveryCalendar.weekKey(DateTime(2026, 1, 1)), '2026-W01');
    });

    test('day keys use the local calendar day', () {
      expect(DiscoveryCalendar.dayKey(DateTime(2026, 3, 9, 23, 59)), '2026-03-09');
    });
  });

  group('SeededRandom', () {
    test('same seed → same sequence; different seed → different', () {
      List<int> seq(String s) {
        final r = SeededRandom.fromString(s);
        return [for (var i = 0; i < 8; i++) r.nextInt(1000)];
      }

      expect(seq('a'), seq('a'));
      expect(seq('a'), isNot(seq('b')));
    });

    test('values stay in range and shuffles are permutations', () {
      final r = SeededRandom(42);
      for (var i = 0; i < 1000; i++) {
        final d = r.nextDouble();
        expect(d >= 0 && d < 1, isTrue);
      }
      final items = List.generate(20, (i) => i);
      expect(r.shuffled(items)..sort(), items);
      expect(r.weightedOrder(items, (i) => i + 1.0)..sort(), items);
    });

    test('weightedOrder favours heavy items', () {
      var heavyFirst = 0;
      for (var s = 0; s < 200; s++) {
        if (SeededRandom(s).weightedOrder(['light', 'heavy'], (x) => x == 'heavy' ? 9.0 : 1.0).first == 'heavy') heavyFirst++;
      }
      expect(heavyFirst, greaterThan(150));
    });
  });

  group('TextKeys', () {
    test('normalizes accents, punctuation, the/feat/remaster noise', () {
      expect(TextKeys.artist('The Beatles'), 'beatles');
      expect(TextKeys.artist('Beyoncé feat. Jay-Z'), 'beyonce');
      expect(TextKeys.title("Don't Stop Me Now - Remastered 2011"), 'dont stop me now');
      expect(TextKeys.title('Song (feat. X) [Official Video]'), 'song');
      expect(TextKeys.stripNoise('Song (feat. X)'), 'Song');
      expect(TextKeys.looselyEqual('song', 'song live'), isTrue);
      expect(TextKeys.looselyEqual('song', 'songbird'), isFalse);
    });
  });
}
