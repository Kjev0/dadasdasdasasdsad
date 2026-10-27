import '../../core/contracts/discovery.dart';
import '../../core/contracts/music_source.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../../core/util/cancel_token.dart';
import '../util/seeded_random.dart';
import '../util/text_keys.dart';
import 'discovery_context.dart';
import 'mix_builder.dart';
import 'shelf_ids.dart';
import 'silo.dart';
import 'taste_profile.dart';

/// Shelves derived from the user's listening history and favorites:
/// continue listening, Daily Mixes, Discover Weekly, "because you liked".
/// Only called when personalization is enabled.
class PersonalBuilders {
  PersonalBuilders(this.ctx);

  final DiscoveryContext ctx;

  DiscoveryTuning get _t => ctx.tuning;

  // ---- Continue listening --------------------------------------------------

  Future<Shelf?> continueListening({CancelToken? cancel}) async {
    List<Track> recent;
    try {
      recent = await ctx.history.recentlyPlayed(limit: _t.shelfLength);
    } catch (_) {
      return null;
    }
    cancel?.throwIfCanceled();
    final playable = [for (final t in recent) if (ctx.gateway.canPlay(t, allowPreview: true)) t];
    if (playable.isEmpty) return null;
    return _shelf(ShelfIds.continueListening, ShelfTitles.continueListening, playable, ShelfKind.continueListening);
  }

  // ---- Daily mixes -----------------------------------------------------------

  /// Up to [count] mixes: one per artist cluster, seeded with the calendar
  /// day so they stay identical for the whole day.
  Future<List<Shelf>> dailyMixes(TasteProfile profile, int count, {CancelToken? cancel}) async {
    final clusters = MixBuilder.cluster(profile, count);
    if (clusters.isEmpty) return const [];
    final day = DiscoveryCalendar.dayKey(ctx.clock());
    final pools = await Future.wait([for (final c in clusters) _clusterDiscoveries(c, profile, cancel: cancel)]);
    cancel?.throwIfCanceled();
    final shelves = <Shelf>[];
    for (var i = 0; i < clusters.length; i++) {
      final c = clusters[i];
      final known = [for (final t in profile.knownTracksOf(c.artistKeys)) if (ctx.gateway.canPlay(t)) t];
      // One silo per mix (SoundCloud terms), decided on the combined pool.
      final allowed = {
        for (final t in SiloGuard.apply([...known, ...pools[i]], preferSiloed: ctx.preferSiloed, minSiloTracks: _t.minSiloTracks))
          t.id,
      };
      final tracks = MixBuilder.compose(
        known: [for (final t in known) if (allowed.contains(t.id)) t],
        discoveries: [for (final t in pools[i]) if (allowed.contains(t.id)) t],
        rng: SeededRandom.fromString('dailyMix:$day:${c.seed.key}'),
        knownWeight: (t) => profile.trackScores[t.id] ?? 0.1,
        minLength: _t.mixMinLength,
        maxLength: _t.mixMaxLength,
        familiarShare: _t.familiarShare,
        maxRun: _t.maxArtistRun,
      );
      if (tracks.length < _t.mixMinPublish) continue;
      shelves.add(Shelf(
        id: ShelfIds.dailyMix(shelves.length + 1),
        title: ShelfTitles.dailyMix,
        subtitle: [for (final a in c.artists.take(3)) a.name].join(', '),
        tracks: tracks,
        artworkUrl: _artwork(tracks),
        kind: ShelfKind.mix,
      ));
    }
    return shelves;
  }

  /// Unheard tracks around a cluster: provider related tracks of the
  /// user's favorite tracks, top tracks of related artists, the cluster
  /// artists' other tracks, metadata sources (Deezer) resolved to playable
  /// equivalents, and local files of the same artists/genre.
  Future<List<Track>> _clusterDiscoveries(MixCluster c, TasteProfile profile, {CancelToken? cancel}) async {
    final g = ctx.gateway;
    final artists = [...c.artists]..sort((a, b) => b.score.compareTo(a.score));
    final lists = <Future<List<Track>>>[];
    for (final a in artists.take(2)) {
      for (final s in g.playable) {
        if (s.id == SourceIds.local) continue;
        // ownTracks is generous: the most played ones are usually known
        // already, the unheard rest are the best discoveries.
        lists.add(_artistNeighbourhood(s, a, relatedCount: 3, perArtist: 5, ownTracks: 20, cancel: cancel));
      }
      for (final s in g.metadataOnly) {
        lists.add(_artistNeighbourhood(s, a, relatedCount: 3, perArtist: 3, ownTracks: 0, cancel: cancel)
            .then((l) => g.resolveAll(l, maxLookups: 8, cancel: cancel)));
      }
      lists.add(ctx.library.byArtist(a.name));
    }
    for (final t in profile.knownTracksOf(c.artistKeys).take(2)) {
      lists.add(_relatedOf(t, cancel: cancel));
    }
    final genreName = c.genre == null ? null : profile.genreNames[c.genre!];
    if (genreName != null) lists.add(ctx.library.byGenre(genreName));
    final results = await Future.wait(lists);
    cancel?.throwIfCanceled();
    return [
      for (final t in MixBuilder.interleave(results))
        if (!profile.knows(t) && g.canPlay(t)) t,
    ];
  }

  /// Related tracks of [t] from its own source (resolved when that source
  /// is metadata-only).
  Future<List<Track>> _relatedOf(Track t, {CancelToken? cancel}) async {
    final s = ctx.sourceOf(t);
    if (s == null) return const [];
    final related = await ctx.gateway.relatedTracks(s, t.sourceTrackId, limit: 15, cancel: cancel);
    if (s.supports(SourceCapability.stream)) return related;
    return ctx.gateway.resolveAll(related, maxLookups: 8, cancel: cancel);
  }

  /// Top tracks of up to [relatedCount] related artists of [a] on [s]
  /// (excluding artists the user already knows when [skipKnown]) plus up to
  /// [ownTracks] of [a]'s own tracks.
  Future<List<Track>> _artistNeighbourhood(
    MusicSource s,
    ArtistAffinity a, {
    required int relatedCount,
    required int perArtist,
    required int ownTracks,
    Set<String> skipArtistKeys = const {},
    CancelToken? cancel,
  }) async {
    if (!s.supports(SourceCapability.artistPages)) return const [];
    final g = ctx.gateway;
    final artist = await g.findArtist(s, a.name, knownId: a.sourceArtistIds[s.id], cancel: cancel);
    if (artist == null) return const [];
    final related = (await g.relatedArtists(s, artist.sourceArtistId, limit: relatedCount * 2, cancel: cancel))
        .where((r) => !skipArtistKeys.contains(TextKeys.artist(r.name)))
        .take(relatedCount)
        .toList();
    final lists = await Future.wait([
      if (ownTracks > 0) g.topTracks(s, artist.sourceArtistId, limit: ownTracks, cancel: cancel),
      for (final r in related) g.topTracks(s, r.sourceArtistId, limit: perArtist, cancel: cancel),
    ]);
    return MixBuilder.interleave(lists);
  }

  // ---- Discover Weekly ---------------------------------------------------------

  /// Weekly (ISO year+week seeded) playlist of tracks the user has never
  /// played, favorited or added: top tracks of artists related to their
  /// top artists and provider "related" tracks of their top tracks.
  Future<Shelf?> discoverWeekly(TasteProfile profile, {CancelToken? cancel}) async {
    final top = profile.topArtists(limit: 6);
    if (top.isEmpty) return null;
    final g = ctx.gateway;
    final knownArtists = {for (final a in profile.artists.values) if (a.score > 0) a.key};
    final lists = <Future<List<Track>>>[];
    for (final a in top) {
      for (final s in [...g.playable, ...g.metadataOnly]) {
        if (s.id == SourceIds.local) continue;
        final playable = s.supports(SourceCapability.stream);
        final f = _artistNeighbourhood(s, a,
            relatedCount: 4, perArtist: 3, ownTracks: 0, skipArtistKeys: knownArtists, cancel: cancel);
        lists.add(playable ? f : f.then((l) => g.resolveAll(l, maxLookups: 10, cancel: cancel)));
      }
    }
    for (final t in profile.knownTracksOf({for (final a in top) a.key}).take(5)) {
      lists.add(_relatedOf(t, cancel: cancel));
    }
    final results = await Future.wait(lists);
    cancel?.throwIfCanceled();
    var candidates = [
      for (final t in MixBuilder.interleave(results))
        if (!profile.knows(t) && g.canPlay(t)) t,
    ];
    final inLibrary = await ctx.library.inLibrary(candidates);
    candidates = [for (final t in candidates) if (!inLibrary.contains(t.id)) t];
    candidates = SiloGuard.apply(candidates, preferSiloed: ctx.preferSiloed, minSiloTracks: _t.minSiloTracks);
    candidates = MixBuilder.capPerArtist(candidates, 2);
    if (candidates.isEmpty) return null;
    final week = DiscoveryCalendar.weekKey(ctx.clock());
    final rank = {for (var i = 0; i < candidates.length; i++) candidates[i].id: i};
    final ordered = SeededRandom.fromString('discoverWeekly:$week').weightedOrder(candidates, (t) {
      // New artists first; relevance decays with rank.
      final fresh = knownArtists.contains(TextKeys.artist(t.primaryArtist)) ? 0.4 : 1.0;
      return fresh / (1 + rank[t.id]! * 0.05);
    });
    final tracks = MixBuilder.spaceArtists(ordered.take(_t.weeklyLength).toList(), maxRun: 1);
    if (tracks.isEmpty) return null;
    return _shelf(ShelfIds.discoverWeekly, ShelfTitles.discoverWeekly, tracks, ShelfKind.discoverWeekly);
  }

  // ---- Because you liked <artist> ------------------------------------------

  /// Related music for one of the user's most-favorited artists (picked
  /// per day among the top three).
  Future<Shelf?> becauseYouLiked(TasteProfile profile, List<Track> favorites, {CancelToken? cancel}) async {
    if (favorites.isEmpty) return null;
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final f in favorites) {
      final k = TextKeys.artist(f.primaryArtist);
      if (k.isEmpty) continue;
      counts[k] = (counts[k] ?? 0) + 1;
      names.putIfAbsent(k, () => f.primaryArtist);
    }
    if (counts.isEmpty) return null;
    final ranked = counts.keys.toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    final day = DiscoveryCalendar.dayKey(ctx.clock());
    final pick = ranked[SeededRandom.fromString('becauseYouLiked:$day').nextInt(ranked.length.clamp(1, 3))];
    final affinity = profile.artists[pick] ?? ArtistAffinity(pick, names[pick]!);
    final g = ctx.gateway;
    final lists = <Future<List<Track>>>[
      for (final t in favorites.where((f) => TextKeys.artist(f.primaryArtist) == pick).take(2)) _relatedOf(t, cancel: cancel),
      for (final s in g.playable)
        if (s.id != SourceIds.local)
          _artistNeighbourhood(s, affinity, relatedCount: 4, perArtist: 3, ownTracks: 0, cancel: cancel),
      for (final s in g.metadataOnly)
        _artistNeighbourhood(s, affinity, relatedCount: 4, perArtist: 2, ownTracks: 0, cancel: cancel)
            .then((l) => g.resolveAll(l, maxLookups: 8, cancel: cancel)),
    ];
    final results = await Future.wait(lists);
    cancel?.throwIfCanceled();
    final favoriteIds = {for (final f in favorites) f.id};
    var tracks = [
      for (final t in MixBuilder.interleave(results))
        if (!favoriteIds.contains(t.id) && TextKeys.artist(t.primaryArtist) != pick && g.canPlay(t)) t,
    ];
    tracks = SiloGuard.apply(tracks, preferSiloed: ctx.preferSiloed, minSiloTracks: _t.minSiloTracks);
    tracks = MixBuilder.spaceArtists(MixBuilder.capPerArtist(tracks, 3), maxRun: 2).take(20).toList();
    if (tracks.length < 5) return null;
    return Shelf(
      id: ShelfIds.becauseYouLiked(pick),
      title: ShelfTitles.becauseYouLiked,
      subtitle: affinity.name,
      tracks: tracks,
      artworkUrl: _artwork(tracks),
      kind: ShelfKind.similarArtists,
    );
  }

  static Uri? _artwork(List<Track> tracks) {
    for (final t in tracks) {
      if (t.artworkUrl != null) return t.artworkUrl;
    }
    return null;
  }

  static Shelf _shelf(String id, String title, List<Track> tracks, ShelfKind kind) =>
      Shelf(id: id, title: title, tracks: tracks, artworkUrl: _artwork(tracks), kind: kind);
}
