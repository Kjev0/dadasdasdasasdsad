import 'dart:io';

import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/platform/app_paths.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/discovery/recommendations/discovery_context.dart';
import 'package:fermata/discovery/recommendations/recommendation_service_impl.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';

import 'fakes.dart';

/// A small, fully scripted music world:
///
/// * Audius (playable): artists Alpha (Electronic), Beta (Rock), Gamma
///   (Jazz) with related artists Rel 1–6, top tracks, related tracks,
///   trending, genre charts, new releases.
/// * Deezer (metadata/preview only): chart, an "Alpha" artist with related
///   artists, radio-style related tracks — some songs also exist on Audius.
/// * Local library: ten "Local Hero" ambient files.
/// * History: 15 Alpha, 12 Beta, 10 Gamma plays over the last 20 days;
///   favorites: three Alpha songs.
class World {
  World._(this.root, this.paths, this.settings, this.audius, this.deezer, this.registry, this.tracks, this.history,
      this.favorites);

  static Future<World> create({bool withDeezer = true}) async {
    final root = await Directory.systemTemp.createTemp('fermata_discovery_');
    final paths = AppPaths.forTesting(root);
    final settings = SettingsStore.inMemory();
    final audius = FakeSource(SourceIds.audius);
    final deezer = FakeSource.metadata(SourceIds.deezer);
    final registry = FakeRegistry(settings, [audius, if (withDeezer) deezer]);
    final w = World._(root, paths, settings, audius, deezer, registry, FakeTracks(), FakeHistory(), FakeFavorites());
    w._populate();
    return w;
  }

  final Directory root;
  final AppPaths paths;
  final SettingsStore settings;
  final FakeSource audius;
  final FakeSource deezer;
  final FakeRegistry registry;
  final FakeTracks tracks;
  final FakeHistory history;
  final FakeFavorites favorites;

  static final now = DateTime(2026, 10, 27, 10);

  final Map<String, List<Track>> known = {};

  Track _a(String id, String artist, String artistId, String genre) =>
      tr(SourceIds.audius, id, title: '$artist $id', artist: artist, artistId: artistId, genre: genre);

  void _populate() {
    const main = {'Alpha': ('a1', 'Electronic', 15), 'Beta': ('b1', 'Rock', 12), 'Gamma': ('g1', 'Jazz', 10)};
    const rel = {
      'r1': ('Rel One', 'Electronic'),
      'r2': ('Rel Two', 'Electronic'),
      'r3': ('Rel Three', 'Electronic'),
      'r4': ('Rel Four', 'Rock'),
      'r5': ('Rel Five', 'Rock'),
      'r6': ('Rel Six', 'Jazz'),
    };
    for (final e in main.entries) {
      final (id, genre, n) = e.value;
      final ks = [for (var i = 0; i < n; i++) _a('${e.key.toLowerCase()}$i', e.key, id, genre)];
      final fresh = [for (var i = 0; i < 5; i++) _a('${e.key.toLowerCase()}New$i', e.key, id, genre)];
      known[e.key] = ks;
      audius.artistIndex.add(ar(SourceIds.audius, id, e.key));
      audius.topTracks[id] = [...ks, ...fresh];
      audius.catalog.addAll([...ks, ...fresh]);
    }
    for (final e in rel.entries) {
      final (name, genre) = e.value;
      audius.artistIndex.add(ar(SourceIds.audius, e.key, name));
      final ts = [for (var i = 0; i < 6; i++) _a('${e.key}_$i', name, e.key, genre)];
      audius.topTracks[e.key] = ts;
      audius.catalog.addAll(ts);
    }
    audius.relatedArtistsMap['a1'] = [for (final id in ['r1', 'r2', 'r3']) ar(SourceIds.audius, id, rel[id]!.$1)];
    audius.relatedArtistsMap['b1'] = [for (final id in ['r4', 'r5']) ar(SourceIds.audius, id, rel[id]!.$1)];
    audius.relatedArtistsMap['g1'] = [for (final id in ['r6', 'r1']) ar(SourceIds.audius, id, rel[id]!.$1)];
    // Provider "related" for some known tracks.
    for (final k in ['beta0', 'beta1', 'gamma0', 'gamma1', 'alpha0', 'alpha1']) {
      final rs = [for (var i = 0; i < 5; i++) _a('rt_${k}_$i', 'Related Act ${k.substring(0, 1)}$i', 'ra$k$i', 'Mixed')];
      audius.related[k] = rs;
      audius.catalog.addAll(rs);
    }
    audius.trendingList.addAll([for (var i = 0; i < 30; i++) _a('trend$i', 'Trend Artist ${i % 10}', 't$i', 'Pop')]);
    for (final g in ['Electronic', 'Rock', 'Jazz', 'Pop', 'Ambient', 'Lo-Fi']) {
      audius.trendingByGenre[g] = [for (var i = 0; i < 8; i++) _a('g${g}_$i', '$g Star $i', 'gs$g$i', g)];
    }
    audius.genreList.addAll(['Electronic', 'Rock', 'Jazz']);
    for (var i = 0; i < 3; i++) {
      final album = Album(sourceId: SourceIds.audius, sourceAlbumId: 'alb$i', title: 'Fresh Album $i', artists: [ArtistRef('Newcomer $i')]);
      audius.releases.add(album);
      audius.albums['alb$i'] = [for (var j = 0; j < 3; j++) _a('alb${i}_$j', 'Newcomer $i', 'n$i', 'Pop')];
    }
    // Mood seeds.
    audius.catalog.addAll([
      for (var i = 0; i < 6; i++)
        _a('focus$i', 'Calm Mind $i', 'cm$i', 'Ambient focus music deep study beats concentration'),
    ]);

    // Deezer: chart previews, related artists/radio, songs shared with Audius.
    deezer.trendingList.addAll([
      for (var i = 0; i < 10; i++) tr(SourceIds.deezer, 'dz$i', title: 'Chart $i', artist: 'Chart Star $i', genre: 'Pop'),
    ]);
    deezer.trendingByGenre['Pop'] = [for (var i = 0; i < 4; i++) tr(SourceIds.deezer, 'dzp$i', title: 'Pop $i', artist: 'Pop Act $i')];
    deezer.artistIndex.add(ar(SourceIds.deezer, 'dzA', 'Alpha'));
    deezer.relatedArtistsMap['dzA'] = [ar(SourceIds.deezer, 'dzR1', 'Deezer Rel')];
    deezer.topTracks['dzR1'] = [
      for (var i = 0; i < 3; i++) tr(SourceIds.deezer, 'dzr$i', title: 'Deezer Rel Song $i', artist: 'Deezer Rel'),
    ];
    // Only song 0 exists on Audius → resolvable.
    audius.catalog.add(tr(SourceIds.audius, 'shared_dzr0', title: 'Deezer Rel Song 0', artist: 'Deezer Rel'));
    deezer.catalog.add(tr(SourceIds.deezer, 'dzSeed', title: 'Seed Song', artist: 'Alpha'));
    deezer.related['dzSeed'] = [
      for (var i = 0; i < 4; i++) tr(SourceIds.deezer, 'dzs$i', title: 'Shared Hit $i', artist: 'Shared Artist'),
      tr(SourceIds.deezer, 'dzOnly', title: 'Deezer Exclusive', artist: 'Nobody Else'),
    ];
    for (var i = 0; i < 4; i++) {
      audius.catalog.add(tr(SourceIds.audius, 'shared$i', title: 'Shared Hit $i', artist: 'Shared Artist'));
    }
    deezer.genreList.addAll(['Pop', 'Rock']);
    deezer.releases.add(Album(sourceId: SourceIds.deezer, sourceAlbumId: 'dzalb', title: 'Fresh Album 0', artists: [ArtistRef('Newcomer 0')]));

    // Local library.
    for (var i = 0; i < 10; i++) {
      tracks.items.add(tr(SourceIds.local, 'loc$i', title: 'Local Tune $i', artist: 'Local Hero', genre: 'Ambient'));
    }

    // History over the last 20 days, favorites.
    var minute = 0;
    for (final e in known.entries) {
      for (final t in e.value) {
        history.play(t, now.subtract(Duration(days: minute % 20, minutes: minute)));
        minute++;
      }
    }
    favorites.items.addAll(known['Alpha']!.take(3));
  }

  RecommendationServiceImpl service({DateTime? at, bool persist = true, DiscoveryTuning tuning = const DiscoveryTuning()}) {
    final clock = at ?? now;
    return RecommendationServiceImpl(registry, history, tracks, favorites, settings, paths,
        clock: () => clock, persistCache: persist, tuning: tuning);
  }

  /// Service with a mutable clock.
  (RecommendationServiceImpl, void Function(DateTime)) serviceWithClock(DateTime start) {
    var t = start;
    final svc = RecommendationServiceImpl(registry, history, tracks, favorites, settings, paths, clock: () => t);
    return (svc, (DateTime next) => t = next);
  }

  Future<void> setPrivacy({required bool personalized}) =>
      settings.update((s) => s.copyWith(privacy: s.privacy.copyWith(personalizedRecommendations: personalized)));

  Future<void> setPerformance(PerformanceMode mode) => settings.applyPerformanceMode(mode);

  Set<String> get knownIds => {for (final r in history.records) r.track.id, for (final f in favorites.items) f.id};

  Future<void> dispose() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
