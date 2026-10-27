import '../../core/contracts/discovery.dart';
import '../../core/contracts/music_source.dart';
import '../../core/models/catalog.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../../core/sources/source_policies.dart';
import '../../core/util/cancel_token.dart';
import '../util/seeded_random.dart';
import '../util/text_keys.dart';
import 'discovery_context.dart';
import 'mix_builder.dart';
import 'moods.dart';
import 'shelf_ids.dart';
import 'silo.dart';

/// Non-personal discovery (works with personalization off) and
/// track/artist similarity: trending, new releases, genres, moods,
/// "similar to", similar artists and the smart-queue continuation.
class BrowseBuilders {
  BrowseBuilders(this.ctx);

  final DiscoveryContext ctx;

  DiscoveryTuning get _t => ctx.tuning;

  /// Playable tracks first (in their order), then previews.
  List<Track> _playableFirst(List<Track> tracks) => [
        for (final t in tracks) if (ctx.gateway.canPlay(t)) t,
        for (final t in tracks) if (!ctx.gateway.canPlay(t) && ctx.gateway.canPlay(t, allowPreview: true)) t,
      ];

  /// Caps tracks per artist and spaces artists, separately for playable
  /// tracks and previews so previews always stay at the end.
  List<Track> _spaced(List<Track> tracks, {required int perArtist, int maxRun = 2}) {
    List<Track> shape(Iterable<Track> l) => MixBuilder.spaceArtists(MixBuilder.capPerArtist(l, perArtist), maxRun: maxRun);
    final full = [for (final t in tracks) if (ctx.gateway.canPlay(t)) t];
    final previews = [for (final t in tracks) if (!ctx.gateway.canPlay(t)) t];
    return [...shape(full), ...shape(previews)];
  }

  List<Track> _silo(List<Track> tracks) =>
      SiloGuard.apply(tracks, preferSiloed: ctx.preferSiloed, minSiloTracks: _t.minSiloTracks);

  // ---- Trending ----------------------------------------------------------------

  /// Charts: in-app playable sources first, then metadata sources (Deezer
  /// chart previews).
  Future<List<Track>> trendingTracks({String? genre, CancelToken? cancel}) async {
    final g = ctx.gateway;
    final playable = g.supporting(SourceCapability.trending, playableOnly: true);
    final metadata = [for (final s in g.supporting(SourceCapability.trending)) if (!playable.contains(s)) s];
    final p = await Future.wait([for (final s in playable) g.trending(s, genre: genre, limit: _t.shelfLength, cancel: cancel)]);
    final m = await Future.wait([for (final s in metadata) g.trending(s, genre: genre, limit: _t.shelfLength, cancel: cancel)]);
    cancel?.throwIfCanceled();
    final merged = [...MixBuilder.interleave(p), ...MixBuilder.interleave(m)];
    return _silo(_playableFirst(MixBuilder.dedupe(merged))).take(_t.shelfLength).toList();
  }

  Future<Shelf?> trendingShelf({CancelToken? cancel}) async {
    final tracks = await trendingTracks(cancel: cancel);
    if (tracks.isEmpty) return null;
    return Shelf(
      id: ShelfIds.trending,
      title: ShelfTitles.trending,
      tracks: tracks,
      artworkUrl: _artwork(tracks),
      kind: ShelfKind.trending,
    );
  }

  // ---- New releases --------------------------------------------------------------

  Future<List<Album>> newReleases({CancelToken? cancel}) async {
    final g = ctx.gateway;
    final sources = g.supporting(SourceCapability.newReleases);
    final lists = await Future.wait([for (final s in sources) g.newReleases(s, limit: 20, cancel: cancel)]);
    cancel?.throwIfCanceled();
    final out = <Album>[];
    final keys = <String>{};
    var i = 0;
    var progressed = true;
    while (progressed && out.length < 40) {
      progressed = false;
      for (final l in lists) {
        if (i >= l.length) continue;
        progressed = true;
        final a = l[i];
        final artist = a.artists.isEmpty ? '' : TextKeys.artist(a.artists.first.name);
        if (keys.add('$artist|${TextKeys.title(a.title)}')) out.add(a);
      }
      i++;
    }
    return out;
  }

  /// Lead track of each of the newest releases (album pages fetched in
  /// isolation; failures are skipped).
  Future<Shelf?> newReleasesShelf({CancelToken? cancel}) async {
    final albums = (await newReleases(cancel: cancel)).take(10).toList();
    final g = ctx.gateway;
    final leads = await Future.wait([
      for (final a in albums)
        () async {
          final s = ctx.registry.byId(a.sourceId);
          if (s == null || !s.isReady) return null;
          final tracks = await g.albumTracks(s, a.sourceAlbumId, cancel: cancel);
          final lead = tracks.firstOrNull;
          if (lead == null) return null;
          return lead.artworkUrl == null && a.artworkUrl != null ? lead.copyWith(artworkUrl: a.artworkUrl) : lead;
        }(),
    ]);
    cancel?.throwIfCanceled();
    final tracks = _silo(_playableFirst([for (final t in leads) ?t]));
    if (tracks.isEmpty) return null;
    return Shelf(
      id: ShelfIds.newReleases,
      title: ShelfTitles.newReleases,
      tracks: tracks,
      artworkUrl: _artwork(tracks),
      kind: ShelfKind.newReleases,
    );
  }

  // ---- Genres -------------------------------------------------------------------

  /// Genres of playable sources first, then metadata sources, then the
  /// local library; case/accents-insensitive de-duplication.
  Future<List<String>> genres({CancelToken? cancel}) async {
    final g = ctx.gateway;
    final sources = [for (final s in g.supporting(SourceCapability.genres)) if (s.id != SourceIds.local) s];
    final lists = await Future.wait([
      for (final s in sources) g.genres(s, cancel: cancel),
      ctx.library.genres(),
    ]);
    cancel?.throwIfCanceled();
    final out = <String>[];
    final keys = <String>{};
    for (final l in lists) {
      for (final name in l) {
        final k = TextKeys.genre(name);
        if (k.isNotEmpty && keys.add(k)) out.add(name.trim());
      }
    }
    return out;
  }

  Future<List<Track>> genreTracks(String genre, {CancelToken? cancel}) async {
    final g = ctx.gateway;
    final playable = g.supporting(SourceCapability.trending, playableOnly: true);
    final metadata = [for (final s in g.supporting(SourceCapability.trending)) if (!playable.contains(s)) s];
    final results = await Future.wait([
      for (final s in playable) g.trending(s, genre: genre, limit: 30, cancel: cancel),
      ctx.library.byGenre(genre, limit: 30),
    ]);
    final meta = await Future.wait([for (final s in metadata) g.trending(s, genre: genre, limit: 30, cancel: cancel)]);
    cancel?.throwIfCanceled();
    final resolved = await g.resolveAll(MixBuilder.interleave(meta), maxLookups: 10, keepPreviews: true, cancel: cancel);
    final merged = MixBuilder.dedupe([...MixBuilder.interleave(results), ...resolved]);
    return _silo(_playableFirst(merged)).take(50).toList();
  }

  Future<Shelf?> genreShelf(String genre, {CancelToken? cancel}) async {
    final tracks = (await genreTracks(genre, cancel: cancel)).take(_t.shelfLength).toList();
    if (tracks.length < 3) return null;
    return Shelf(
      id: ShelfIds.genre(genre),
      title: ShelfTitles.genre,
      subtitle: genre,
      tracks: tracks,
      artworkUrl: _artwork(tracks),
      kind: ShelfKind.genre,
    );
  }

  // ---- Moods ------------------------------------------------------------------------

  /// Search seeds (two per source, picked per day) + genre charts + local
  /// files tagged with the mood's genres.
  Future<List<Track>> moodTracks(MoodCategory mood, {CancelToken? cancel}) async {
    final def = Moods.of(mood);
    final g = ctx.gateway;
    final rng = SeededRandom.fromString('mood:${mood.id}:${DiscoveryCalendar.dayKey(ctx.clock())}');
    final playable = [for (final s in g.playable) if (s.id != SourceIds.local) s];
    final futures = <Future<List<Track>>>[
      for (final s in playable)
        for (final q in rng.shuffled(def.queriesFor(s.id)).take(2)) g.search(s, q, limit: 20, cancel: cancel),
      for (final s in playable)
        if (s.supports(SourceCapability.trending))
          for (final genre in def.genresFor(s.id).take(2)) g.trending(s, genre: genre, limit: 20, cancel: cancel),
      for (final genre in mood.genres.take(3)) ctx.library.byGenre(genre, limit: 20),
    ];
    final metaFutures = <Future<List<Track>>>[
      for (final s in g.metadataOnly)
        if (s.supports(SourceCapability.trending))
          for (final genre in def.genresFor(s.id).take(1)) g.trending(s, genre: genre, limit: 20, cancel: cancel),
    ];
    final results = await Future.wait(futures);
    final meta = await Future.wait(metaFutures);
    cancel?.throwIfCanceled();
    final resolved = await g.resolveAll(MixBuilder.interleave(meta), maxLookups: 10, keepPreviews: true, cancel: cancel);
    final merged = MixBuilder.dedupe([...MixBuilder.interleave(results), ...resolved]);
    return _spaced(_silo(_playableFirst(merged)), perArtist: 3).take(50).toList();
  }

  // ---- Similar --------------------------------------------------------------------

  /// Tracks similar to [track]: related tracks from its own source, from
  /// the same song found on other sources (SoundCloud related when ready,
  /// Audius related-artist tracks, Deezer radio resolved to playable
  /// sources), then the artist's other tracks and local files.
  Future<List<Track>> similarTo(Track track, {int limit = 25, CancelToken? cancel}) async {
    final silo = SourcePolicies.of(track.sourceId).siloedPlayback ? track.sourceId : null;
    final lists = await _similarLists(track, filter: silo == null ? null : (id) => SourcePolicies.canJoinSilo(silo, id), cancel: cancel);
    final seedKey = TextKeys.track(track);
    var out = [
      for (final t in lists)
        if (t.id != track.id && TextKeys.track(t) != seedKey) t,
    ];
    out = _playableFirst(out);
    out = silo != null ? SiloGuard.restrictTo(out, silo) : _silo(out);
    return _spaced(out, perArtist: 4).take(limit).toList();
  }

  /// Related candidates of [seed] (primary related lists interleaved, then
  /// same-artist fallbacks). [filter] restricts the sources used.
  Future<List<Track>> _similarLists(Track seed, {bool Function(String sourceId)? filter, CancelToken? cancel}) async {
    final g = ctx.gateway;
    bool ok(String id) => filter?.call(id) ?? true;
    final related = <Future<List<Track>>>[];
    final own = ctx.sourceOf(seed);
    if (own != null && own.supports(SourceCapability.relatedTracks)) {
      related.add(g.relatedTracks(own, seed.sourceTrackId, limit: 20, cancel: cancel).then((l) =>
          own.supports(SourceCapability.stream) ? l : g.resolveAll(l, maxLookups: 10, keepPreviews: true, sourceFilter: filter, cancel: cancel)));
    }
    for (final s in g.supporting(SourceCapability.relatedTracks)) {
      if (s.id == seed.sourceId || s.id == SourceIds.local) continue;
      final playable = s.supports(SourceCapability.stream);
      if (playable && !ok(s.id)) continue;
      related.add(() async {
        final eq = await g.findEquivalent(s, seed, cancel: cancel);
        if (eq == null) return const <Track>[];
        final l = await g.relatedTracks(s, eq.sourceTrackId, limit: 20, cancel: cancel);
        return playable ? l : await g.resolveAll(l, maxLookups: 10, keepPreviews: true, sourceFilter: filter, cancel: cancel);
      }());
    }
    final fallback = <Future<List<Track>>>[
      for (final s in g.playable)
        if (s.id != SourceIds.local && ok(s.id) && s.supports(SourceCapability.artistPages))
          () async {
            final known = s.id == seed.sourceId && seed.artists.isNotEmpty ? seed.artists.first.sourceArtistId : null;
            final a = await g.findArtist(s, seed.primaryArtist, knownId: known, cancel: cancel);
            return a == null ? const <Track>[] : await g.topTracks(s, a.sourceArtistId, limit: 10, cancel: cancel);
          }(),
      if (seed.primaryArtist.isNotEmpty) ctx.library.byArtist(seed.primaryArtist, limit: 15),
      for (final genre in TextKeys.splitGenres(seed.genre).take(1)) ctx.library.byGenre(genre, limit: 15),
    ];
    final r = await Future.wait(related);
    final f = await Future.wait(fallback);
    cancel?.throwIfCanceled();
    return MixBuilder.dedupe([...MixBuilder.interleave(r), ...MixBuilder.interleave(f)]);
  }

  /// Related artists of [artistName] from every source that knows the
  /// artist (playable first), de-duplicated by name.
  Future<List<Artist>> similarArtists(String artistName, {int limit = 12, CancelToken? cancel}) async {
    final g = ctx.gateway;
    final key = TextKeys.artist(artistName);
    final lists = await Future.wait([
      for (final s in g.supporting(SourceCapability.artistPages))
        if (s.id != SourceIds.local)
          () async {
            final a = await g.findArtist(s, artistName, cancel: cancel);
            return a == null ? const <Artist>[] : await g.relatedArtists(s, a.sourceArtistId, limit: limit, cancel: cancel);
          }(),
    ]);
    cancel?.throwIfCanceled();
    final out = <Artist>[];
    final keys = <String>{key};
    var i = 0;
    var progressed = true;
    while (progressed && out.length < limit) {
      progressed = false;
      for (final l in lists) {
        if (i >= l.length) continue;
        progressed = true;
        if (keys.add(TextKeys.artist(l[i].name)) && out.length < limit) out.add(l[i]);
      }
      i++;
    }
    return out;
  }

  // ---- Smart queue ------------------------------------------------------------------

  /// Continuation for a queue that ran out: tracks related to the last few
  /// of [recent], never one of [recent], only full in-app playable tracks
  /// that may join the queue's silo.
  Future<List<Track>> smartQueueContinuation(List<Track> recent, {int limit = 10, CancelToken? cancel}) async {
    if (recent.isEmpty || limit <= 0) return const [];
    final silo = SourcePolicies.siloOf([for (final t in recent) t.sourceId]);
    bool fits(String id) => SourcePolicies.canJoinSilo(silo, id);
    final excludeIds = {for (final t in recent) t.id};
    final excludeKeys = {for (final t in recent) TextKeys.track(t)};
    final seeds = <Track>[];
    final seedKeys = <String>{};
    for (final t in recent.reversed) {
      if (seedKeys.add(TextKeys.track(t))) seeds.add(t);
      if (seeds.length == 3) break;
    }
    final perSeed = await Future.wait([for (final s in seeds) _similarLists(s, filter: fits, cancel: cancel)]);
    cancel?.throwIfCanceled();
    final merged = MixBuilder.interleave(perSeed);
    final candidates = [
      for (final t in merged)
        if (!excludeIds.contains(t.id) && !excludeKeys.contains(TextKeys.track(t))) t,
    ];
    final resolved = await ctx.gateway.resolveAll(candidates, maxLookups: 10, sourceFilter: fits, cancel: cancel);
    final out = [
      for (final t in MixBuilder.dedupe(resolved))
        if (fits(t.sourceId) &&
            ctx.gateway.canPlay(t) &&
            !excludeIds.contains(t.id) &&
            !excludeKeys.contains(TextKeys.track(t)))
          t,
    ];
    return MixBuilder.spaceArtists(MixBuilder.capPerArtist(out, 3), maxRun: 2).take(limit).toList();
  }

  static Uri? _artwork(List<Track> tracks) {
    for (final t in tracks) {
      if (t.artworkUrl != null) return t.artworkUrl;
    }
    return null;
  }
}
