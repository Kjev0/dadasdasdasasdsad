import 'dart:async';

import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestLibrary lib;
  setUp(() async => lib = await openTestLibrary());
  tearDown(() async => lib.dispose());

  group('favorites', () {
    test('setFavorite upserts the track and toggles', () async {
      final fav = lib.module.favorites;
      final t = remoteTrack('1', title: 'Remote only');
      expect(await fav.isFavorite(t.id), isFalse);
      await fav.setFavorite(t, true);
      expect(await fav.isFavorite(t.id), isTrue);
      expect((await lib.module.tracks.getTrack(t.id))!.title, 'Remote only');
      await fav.setFavorite(t, true); // idempotent
      await fav.setFavorite(remoteTrack('2'), true);
      expect((await fav.favorites()).map((t) => t.id), ['soundcloud:2', 'soundcloud:1']);
      await fav.setFavorite(t, false);
      expect((await fav.favorites()).map((t) => t.id), ['soundcloud:2']);
    });

    test('watchFavoriteIds emits current set and every change', () async {
      final fav = lib.module.favorites;
      await fav.setFavorite(remoteTrack('1'), true);
      final emitted = <Set<String>>[];
      final sub = fav.watchFavoriteIds().listen(emitted.add);
      await pumpEventQueue();
      expect(emitted, [
        {'soundcloud:1'},
      ]);
      await fav.setFavorite(remoteTrack('2'), true);
      await pumpEventQueue();
      await fav.setFavorite(remoteTrack('1'), false);
      await pumpEventQueue();
      expect(emitted.last, {'soundcloud:2'});
      expect(emitted.length, 3);
      await lib.module.maintenance.deleteAllUserData();
      await pumpEventQueue();
      expect(emitted.last, isEmpty);
      // A second, independent subscriber gets the current state immediately.
      final first = await fav.watchFavoriteIds().first;
      expect(first, isEmpty);
      await sub.cancel();
    });
  });

  group('history', () {
    test('recordPlay, history paging, recentlyPlayed, playCount, clear', () async {
      final h = lib.module.history;
      final a = remoteTrack('a', genre: 'Jazz');
      final b = remoteTrack('b', artists: ['B', 'Feat'], genre: 'Rock');
      final base = DateTime(2024, 3, 1, 12);
      await h.recordPlay(PlayRecord(track: a, playedAt: base, listened: const Duration(seconds: 40), completed: false, origin: 'search'));
      await h.recordPlay(PlayRecord(track: b, playedAt: base.add(const Duration(hours: 1)), listened: const Duration(minutes: 3), completed: true));
      await h.recordPlay(PlayRecord(track: a, playedAt: base.add(const Duration(days: 1)), listened: const Duration(minutes: 2), completed: true));

      final all = await h.history();
      expect(all.map((r) => r.track.id), ['soundcloud:a', 'soundcloud:b', 'soundcloud:a']);
      expect(all.last.origin, 'search');
      expect(all.last.listened, const Duration(seconds: 40));
      final older = await h.history(before: all[1].playedAt);
      expect(older.single.playedAt, base);
      expect((await h.history(limit: 1)).single.track.id, 'soundcloud:a');
      expect((await h.recentlyPlayed()).map((t) => t.id), ['soundcloud:a', 'soundcloud:b']);
      expect(await h.playCount('soundcloud:a'), 2);
      expect(await h.playCount('soundcloud:none'), 0);
      // Played tracks are stored (offline history).
      expect(await lib.module.tracks.getTrack('soundcloud:b'), isNotNull);
      await h.clearHistory();
      expect(await h.history(), isEmpty);
    });

    test('stats: totals, top tracks/artists/genres, plays per day', () async {
      final h = lib.module.history;
      final a = remoteTrack('a', artists: ['Alpha'], genre: 'Jazz');
      final b = remoteTrack('b', artists: ['Beta', 'Alpha'], genre: 'Rock');
      final c = remoteTrack('c', artists: ['Alpha'], genre: 'jazz');
      final d1 = DateTime(2024, 5, 1, 9);
      final d2 = DateTime(2024, 5, 2, 23, 30);
      for (final (t, at) in [(a, d1), (a, d1.add(const Duration(hours: 2))), (b, d2), (c, d2), (a, d2)]) {
        await h.recordPlay(PlayRecord(track: t, playedAt: at, listened: const Duration(minutes: 1), completed: true));
      }
      await h.recordPlay(PlayRecord(track: b, playedAt: DateTime(2023, 1, 1), listened: const Duration(minutes: 10), completed: true));

      final s = await h.stats();
      expect(s.totalPlays, 6);
      expect(s.totalListened, const Duration(minutes: 15));
      expect(s.topTracks.first.$1.id, 'soundcloud:a');
      expect(s.topTracks.first.$2, 3);
      expect(s.topArtists.first, ('Alpha', 4)); // primary artist only
      expect(s.topArtists[1], ('Beta', 2));
      expect(s.topGenres.first.$2, 4); // Jazz + jazz folded
      expect(s.topGenres.first.$1.toLowerCase(), 'jazz');
      expect(s.playsPerDay[DateTime(2024, 5, 1)], 2);
      expect(s.playsPerDay[DateTime(2024, 5, 2)], 3);
      expect(s.playsPerDay[DateTime(2023, 1, 1)], 1);

      final since = await h.stats(since: DateTime(2024, 5, 2));
      expect(since.totalPlays, 3);
      expect(since.playsPerDay.keys, [DateTime(2024, 5, 2)]);
    });
  });

  group('track links', () {
    setUp(() async {
      await lib.module.tracks.upsertTracks([
        remoteTrack('sp1', source: 'spotify'),
        remoteTrack('sc1'),
        remoteTrack('au1', source: 'audius'),
        remoteTrack('dz1', source: 'deezer'),
        remoteTrack('lonely'),
      ]);
    });

    test('symmetric, transitive groups sorted by confidence', () async {
      final links = lib.module.links;
      await links.link('spotify:sp1', 'soundcloud:sc1', confidence: 0.9);
      await links.link('audius:au1', 'soundcloud:sc1', confidence: 0.8);
      await links.link('deezer:dz1', 'spotify:sp1', confidence: 1.0, userConfirmed: true);

      final fromSpotify = await links.linkedTracks('spotify:sp1');
      expect(fromSpotify.map((e) => e.$1.id), ['deezer:dz1', 'soundcloud:sc1', 'audius:au1']);
      expect(fromSpotify.first.$2.userConfirmed, isTrue);
      expect(fromSpotify.last.$2.confidence, closeTo(0.72, 1e-9)); // 0.9 * 0.8
      expect(fromSpotify.last.$2.userConfirmed, isFalse);
      expect(fromSpotify.every((e) => e.$2.trackId == 'spotify:sp1'), isTrue);

      final fromAudius = await links.linkedTracks('audius:au1');
      expect(fromAudius.map((e) => e.$1.id).toSet(), {'soundcloud:sc1', 'spotify:sp1', 'deezer:dz1'});
      expect(await links.linkedTracks('soundcloud:lonely'), isEmpty);

      await links.unlink('soundcloud:sc1', 'spotify:sp1');
      expect((await links.linkedTracks('spotify:sp1')).map((e) => e.$1.id), ['deezer:dz1']);
    });

    test('re-linking upserts but never downgrades a confirmed link', () async {
      final links = lib.module.links;
      await links.link('spotify:sp1', 'soundcloud:sc1', confidence: 0.6);
      await links.link('soundcloud:sc1', 'spotify:sp1', confidence: 0.7);
      var l = (await links.linkedTracks('spotify:sp1')).single.$2;
      expect(l.confidence, 0.7);
      await links.link('spotify:sp1', 'soundcloud:sc1', confidence: 1.0, userConfirmed: true);
      await links.link('spotify:sp1', 'soundcloud:sc1', confidence: 0.4);
      l = (await links.linkedTracks('spotify:sp1')).single.$2;
      expect(l.confidence, 1.0);
      expect(l.userConfirmed, isTrue);
      expect((await lib.module.database.db.query('track_links')).length, 1);
    });

    test('links require library tracks and distinct ids', () async {
      final links = lib.module.links;
      await expectLater(links.link('spotify:sp1', 'x:unknown', confidence: 1), throwsA(isA<StorageException>()));
      expect(() => links.link('spotify:sp1', 'spotify:sp1', confidence: 1), throwsArgumentError);
    });

    test('group keys put transitive members together', () async {
      final links = lib.module.links;
      await links.link('spotify:sp1', 'soundcloud:sc1', confidence: 0.9);
      await links.link('soundcloud:sc1', 'audius:au1', confidence: 0.9);
      final keys = await links.groupKeys(['spotify:sp1', 'audius:au1', 'soundcloud:lonely']);
      expect(keys['spotify:sp1'], keys['audius:au1']);
      expect(keys['soundcloud:lonely'], 'soundcloud:lonely');
    });
  });

  group('search history', () {
    test('dedupe, most recent first, remove, clear', () async {
      final s = lib.module.searchHistory;
      await s.add('Beatles');
      await s.add('  adele ');
      await s.add('beatles'); // dedupe, latest spelling wins and moves up
      await s.add('   ');
      expect(await s.recent(), ['beatles', 'adele']);
      expect(await s.recent(limit: 1), ['beatles']);
      await s.remove('ADELE');
      expect(await s.recent(), ['beatles']);
      await s.clear();
      expect(await s.recent(), isEmpty);
    });

    test('capped at 50 entries', () async {
      final s = lib.module.searchHistory;
      for (var i = 0; i < 60; i++) {
        await s.add('query $i');
      }
      final all = await s.recent(limit: 100);
      expect(all.length, 50);
      expect(all.first, 'query 59');
      expect(all.last, 'query 10');
    });

    test('respects privacy.saveSearchHistory', () async {
      final settings = SettingsStore.inMemory(const AppSettings(privacy: PrivacySettings(saveSearchHistory: false)));
      final other = await openTestLibrary(settings: settings);
      addTearDown(other.dispose);
      await other.module.searchHistory.add('secret');
      expect(await other.module.searchHistory.recent(), isEmpty);
      await settings.update((s) => s.copyWith(privacy: s.privacy.copyWith(saveSearchHistory: true)));
      await other.module.searchHistory.add('ok');
      expect(await other.module.searchHistory.recent(), ['ok']);
    });
  });

  test('downloaded index follows a stream', () async {
    await lib.module.tracks.upsertTracks([remoteTrack('1'), remoteTrack('2')]);
    final ctrl = StreamController<Set<String>>();
    lib.module.attachDownloads(ctrl.stream);
    ctrl.add({'soundcloud:1'});
    await pumpEventQueue();
    await lib.module.downloadedIndex.flush();
    expect((await lib.module.tracks.query(const TrackQuery(downloadedOnly: true))).map((t) => t.id), ['soundcloud:1']);
    ctrl.add({'soundcloud:2'});
    await pumpEventQueue();
    await lib.module.downloadedIndex.flush();
    expect((await lib.module.tracks.query(const TrackQuery(downloadedOnly: true))).map((t) => t.id), ['soundcloud:2']);
    await ctrl.close();
  });
}
