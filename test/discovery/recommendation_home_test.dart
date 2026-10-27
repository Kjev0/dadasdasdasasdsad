import 'package:fermata/core/contracts/discovery.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/discovery/recommendations/mix_builder.dart';
import 'package:fermata/discovery/recommendations/recommendation_service_impl.dart';
import 'package:fermata/discovery/recommendations/shelf_ids.dart';
import 'package:fermata/discovery/recommendations/silo.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/world.dart';

List<List<String>> idsOf(List<Shelf> shelves) => [for (final s in shelves) [for (final t in s.tracks) t.id]];

void main() {
  late World w;

  setUp(() async => w = await World.create());
  tearDown(() async => w.dispose());

  group('daily mixes', () {
    test('one mix per taste cluster, 25–50 tracks, ~60 % familiar, max 3 in a row', () async {
      final mixes = await w.service(persist: false).dailyMixes();
      expect(mixes, hasLength(3));
      expect([for (final m in mixes) m.id], ['dailyMix:1', 'dailyMix:2', 'dailyMix:3']);
      expect(mixes.first.subtitle, startsWith('Alpha'));
      for (final m in mixes) {
        expect(m.title, ShelfTitles.dailyMix);
        expect(m.tracks.length, inInclusiveRange(25, 50), reason: m.id);
        expect(MixBuilder.longestArtistRun(m.tracks), lessThanOrEqualTo(3), reason: m.id);
        final familiar = m.tracks.where((t) => w.knownIds.contains(t.id)).length / m.tracks.length;
        expect(familiar, inInclusiveRange(0.35, 0.65), reason: '${m.id}: $familiar');
        expect({for (final t in m.tracks) t.id}.length, m.tracks.length);
      }
    });

    test('deterministic for a given date, different on another day', () async {
      final day = DateTime(2026, 10, 27, 8);
      final a = await w.service(at: day, persist: false).dailyMixes();
      final b = await w.service(at: day.add(const Duration(hours: 12)), persist: false).dailyMixes();
      expect(idsOf(a), idsOf(b));
      final c = await w.service(at: DateTime(2026, 10, 28, 8), persist: false).dailyMixes();
      expect(idsOf(c), isNot(idsOf(a)));
    });

    test('a cached mix is reused the same day and recomputed the next day', () async {
      final (svc, setClock) = w.serviceWithClock(DateTime(2026, 10, 27, 8));
      final first = await svc.dailyMixes();
      final reads = w.history.reads;
      expect(idsOf(await svc.dailyMixes()), idsOf(first));
      expect(w.history.reads, reads, reason: 'served from cache');
      setClock(DateTime(2026, 10, 28, 8));
      await svc.dailyMixes();
      expect(w.history.reads, greaterThan(reads));
      await svc.dispose();
    });

    test('mixes respect the SoundCloud silo', () async {
      final sc = FakeSource(SourceIds.soundcloud);
      w.registry.register(sc);
      // SoundCloud knows Alpha and has related artists with plenty of tracks.
      sc.artistIndex.add(ar(SourceIds.soundcloud, 'scA', 'Alpha'));
      sc.relatedArtistsMap['scA'] = [ar(SourceIds.soundcloud, 'scR', 'Cloud Rel')];
      sc.topTracks['scR'] = [for (var i = 0; i < 6; i++) tr(SourceIds.soundcloud, 'sc$i', artist: 'Cloud Rel')];
      for (final mix in await w.service(persist: false).dailyMixes()) {
        expect(SiloGuard.isValid(mix.tracks), isTrue, reason: mix.id);
      }
    });
  });

  group('discover weekly', () {
    test('only tracks not in the library or history, seeded per ISO week', () async {
      // A related-artist song the user already has in the library.
      w.tracks.items.add(w.audius.topTracks['r1']!.first);
      final weekly = await w.service(persist: false).discoverWeekly();
      expect(weekly, isNotNull);
      expect(weekly!.kind, ShelfKind.discoverWeekly);
      final ids = {for (final t in weekly.tracks) t.id};
      expect(ids, isNot(contains(w.audius.topTracks['r1']!.first.id)));
      expect(ids.intersection(w.knownIds), isEmpty);
      expect(ids.intersection({for (final t in w.tracks.items) t.id}), isEmpty);
      // Deezer suggestions were resolved to playable Audius equivalents.
      expect(weekly.tracks.every((t) => t.sourceId == SourceIds.audius), isTrue);
      expect(ids, contains('audius:shared_dzr0'));

      // Same ISO week (Mon 26 Oct – Sun 1 Nov 2026) → same playlist.
      final sameWeek = await w.service(at: DateTime(2026, 11, 1, 20), persist: false).discoverWeekly();
      expect([for (final t in sameWeek!.tracks) t.id], [for (final t in weekly.tracks) t.id]);
      final nextWeek = await w.service(at: DateTime(2026, 11, 2, 9), persist: false).discoverWeekly();
      expect([for (final t in nextWeek!.tracks) t.id], isNot([for (final t in weekly.tracks) t.id]));
    });
  });

  group('home', () {
    test('personalized home: continue listening, mixes, weekly, because-you-liked, then public shelves', () async {
      final shelves = await w.service(persist: false).homeShelves();
      final ids = [for (final s in shelves) s.id];
      expect(ids.first, ShelfIds.continueListening);
      expect(ids, containsAll(['dailyMix:1', ShelfIds.discoverWeekly, ShelfIds.trending, ShelfIds.newReleases, ShelfIds.recentlyAdded]));
      expect(ids.where((i) => i.startsWith(ShelfIds.becauseYouLikedPrefix)), hasLength(1));
      final because = shelves.firstWhere((s) => s.id.startsWith(ShelfIds.becauseYouLikedPrefix));
      expect(because.subtitle, 'Alpha');
      expect(because.tracks.every((t) => t.primaryArtist != 'Alpha'), isTrue);
      final trending = shelves.firstWhere((s) => s.id == ShelfIds.trending);
      expect(trending.tracks.first.sourceId, SourceIds.audius, reason: 'in-app playable source first');
      final releases = shelves.firstWhere((s) => s.id == ShelfIds.newReleases);
      expect(releases.tracks.first.title, contains('alb0_0'), reason: 'lead track of the newest album');
      for (final s in shelves) {
        expect(SiloGuard.isValid(s.tracks), isTrue, reason: s.id);
      }
    });

    test('personalization off → only non-personal shelves and history is never read', () async {
      await w.setPrivacy(personalized: false);
      final svc = w.service(persist: false);
      final shelves = await svc.homeShelves();
      expect(shelves, isNotEmpty);
      for (final s in shelves) {
        expect(ShelfIds.isPersonal(s.id), isFalse, reason: s.id);
        expect(s.kind, isNot(anyOf(ShelfKind.continueListening, ShelfKind.discoverWeekly, ShelfKind.similarArtists)));
      }
      final ids = [for (final s in shelves) s.id];
      expect(ids, containsAll([ShelfIds.trending, ShelfIds.newReleases, ShelfIds.recentlyAdded]));
      expect(ids.any((i) => i.startsWith(ShelfIds.genrePrefix)), isTrue);
      expect(await svc.dailyMixes(), isEmpty);
      expect(await svc.discoverWeekly(), isNull);
      expect(w.history.reads, 0);
      expect(w.favorites.reads, 0);
    });

    test('turning personalization off forgets cached personal shelves', () async {
      final svc = w.service(persist: false);
      await svc.dailyMixes();
      await w.setPrivacy(personalized: false);
      await Future<void>.delayed(Duration.zero);
      expect(await svc.dailyMixes(), isEmpty);
      await w.setPrivacy(personalized: true);
      await Future<void>.delayed(Duration.zero);
      final reads = w.history.reads;
      await svc.dailyMixes();
      expect(w.history.reads, greaterThan(reads), reason: 'recomputed, not served from the purged cache');
      await svc.dispose();
    });

    test('one failing source does not break the page', () async {
      w.deezer.failWith = const NetworkException('down');
      final shelves = await w.service(persist: false).homeShelves();
      final ids = [for (final s in shelves) s.id];
      expect(ids, containsAll([ShelfIds.trending, 'dailyMix:1', ShelfIds.recentlyAdded]));
      expect(w.deezer.totalCalls, greaterThan(0));
    });

    test('every source failing → local-only shelves, never throws', () async {
      w.deezer.failWith = const NetworkException('down');
      w.audius.failWith = StateError('unexpected payload');
      final shelves = await w.service(persist: false).homeShelves();
      final ids = [for (final s in shelves) s.id];
      expect(ids, containsAll([ShelfIds.continueListening, ShelfIds.recentlyAdded]));
      expect(ids, isNot(contains(ShelfIds.trending)));
    });

    test('nothing connected and a broken history → still a home page', () async {
      w.audius.ready = false;
      w.deezer.ready = false;
      final svc = RecommendationServiceImpl(w.registry, ThrowingHistory(), w.tracks, w.favorites, w.settings, w.paths,
          clock: () => World.now, persistCache: false);
      final shelves = await svc.homeShelves();
      expect([for (final s in shelves) s.id], [ShelfIds.genre('Ambient'), ShelfIds.recentlyAdded]);
      expect(shelves.firstWhere((s) => s.id == ShelfIds.recentlyAdded).tracks.first.id, 'local:loc9');
      expect(w.audius.totalCalls + w.deezer.totalCalls, 0, reason: 'not-ready sources are not called');
    });

    test('a disabled local source hides local shelves', () async {
      await w.settings.update((s) => s.copyWith(services: s.services.copyWith(disabledSources: {SourceIds.local})));
      final shelves = await w.service(persist: false).homeShelves();
      expect([for (final s in shelves) s.id], isNot(contains(ShelfIds.recentlyAdded)));
    });

    test('cancellation propagates as OperationCanceledException', () async {
      final token = CancelToken()..cancel();
      await expectLater(w.service(persist: false).homeShelves(cancel: token), throwsA(isA<OperationCanceledException>()));
    });
  });

  group('caching', () {
    test('memoized in memory and on disk; data saver serves stale; refresh recomputes', () async {
      final (svc, setClock) = w.serviceWithClock(World.now);
      final first = await svc.homeShelves();
      final calls = w.audius.totalCalls;
      await svc.homeShelves();
      expect(w.audius.totalCalls, calls, reason: 'second load from memory');
      await svc.dispose(); // flushes the cache file

      // A new process: shelves come from the cache file.
      final svc2 = w.service(at: World.now.add(const Duration(hours: 1)));
      final again = await svc2.homeShelves();
      expect(w.audius.totalCalls, calls);
      expect(idsOf(again), idsOf(first));

      // Expired, but data saver forbids implicit refetching.
      await w.setPerformance(PerformanceMode.dataSaver);
      final (svc3, _) = w.serviceWithClock(World.now.add(const Duration(hours: 7)));
      await svc3.homeShelves();
      expect(w.audius.totalCalls, calls);

      // Background sync allowed → expired entries are recomputed.
      await w.setPerformance(PerformanceMode.balanced);
      await svc3.homeShelves();
      final afterExpiry = w.audius.totalCalls;
      expect(afterExpiry, greaterThan(calls));

      // Explicit refresh always recomputes.
      setClock(World.now);
      await svc3.refresh();
      await svc3.homeShelves();
      expect(w.audius.totalCalls, greaterThan(afterExpiry));
    });

    test('a failure later serves the last good result instead of nothing', () async {
      final (svc, setClock) = w.serviceWithClock(World.now);
      final trending = (await svc.homeShelves()).firstWhere((s) => s.id == ShelfIds.trending);
      setClock(World.now.add(const Duration(hours: 8)));
      w.audius.failWith = const NetworkException('offline');
      w.deezer.failWith = const NetworkException('offline');
      final later = (await svc.homeShelves()).firstWhere((s) => s.id == ShelfIds.trending);
      expect([for (final t in later.tracks) t.id], [for (final t in trending.tracks) t.id]);
    });
  });
}
