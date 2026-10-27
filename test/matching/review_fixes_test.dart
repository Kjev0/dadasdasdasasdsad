// Tests for the fixes made after the adversarial review (see the review_*
// files for the reviewer's own reproductions).
import 'package:fermata/core/contracts/matching.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/matching.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/matching/matching.dart';
import 'package:fermata/matching/playlist_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Always answers with the same next cursor (a broken paging API).
class _LoopingSource extends FakeSource {
  _LoopingSource() : super('spotify');

  @override
  Future<PlaylistDetail> getPlaylist(String idOrUrl, {String? cursor, CancelToken? cancel}) async => PlaylistDetail(
        playlist: const Playlist(id: 'spotify:loop', name: 'Loop', kind: PlaylistKind.remote, sourceId: 'spotify'),
        tracks: Page([track('spotify', 'l${cursor ?? 0}', 'Song ${cursor ?? 0}', ['A'], seconds: 200)], nextCursor: '1'),
      );
}

PlaylistImportServiceImpl _service(
  FakeSource source, {
  ImportSettings settings = const ImportSettings(progressInterval: Duration.zero),
  DateTime Function()? clock,
  InMemoryTrackRepository? tracks,
  InMemoryPlaylistRepository? playlists,
}) {
  final registry = FakeRegistry([source]);
  final scorer = WeightedTrackScorer();
  return PlaylistImportServiceImpl(
    registry: registry,
    matcher: SourceTrackMatcher(registry: registry, scorer: scorer),
    scorer: scorer,
    trackRepository: tracks ?? InMemoryTrackRepository(),
    playlistRepository: playlists ?? InMemoryPlaylistRepository(),
    linkRepository: InMemoryLinkRepository(),
    settings: settings,
    clock: clock,
  );
}

Future<void> _reviewing(PlaylistImportServiceImpl service, String id) =>
    service.watch(id).firstWhere((s) => s.phase == ImportPhase.reviewing).timeout(const Duration(seconds: 5));

void main() {
  final scorer = WeightedTrackScorer();
  const parser = TitleParser();
  const normalizer = TrackNormalizer();

  group('"Artist - Title" vs. "Title - Qualifier" (F4)', () {
    test('a tail that may be either keeps both readings, each with its own version', () {
      final p = parser.parse('Oasis - Live Forever');
      expect(p.base, 'Oasis');
      expect(p.qualifiers, ['Live Forever']);
      expect((p.splitArtist, p.splitTitle), ('Oasis', 'Live Forever'));
      expect(p.splitQualifiers, isEmpty);
      final n = normalizer.normalize(track('soundcloud', '1', 'Oasis - Live Forever', ['Big Brother Recordings']));
      expect(n.primary.isArtistTitleSplit, isTrue);
      expect(n.primary.version.isEmpty, isTrue);
      expect(n.readings.last.version.has(VersionTag.live), isTrue);
    });

    test('pure qualifier tails still produce a single reading', () {
      for (final t in ['Song - Remastered 2011', 'Song - Radio Edit', 'Song - Single Version', 'Song - Bonus Track',
          'Song - Live at the BBC', 'Gangsta\'s Paradise - From "Dangerous Minds"']) {
        expect(parser.parse(t).hasArtistTitleSplit, isFalse, reason: t);
      }
    });

    test('"Song - Kygo Remix" prefers the qualifier reading even on SoundCloud', () {
      final n = normalizer.normalize(track('soundcloud', '1', 'Adventure - Kygo Remix', ['Kygo']));
      expect(n.primary.isArtistTitleSplit, isFalse);
      expect(n.versionQualifiers, ['Kygo Remix']);
      expect(n.readings.last.versionQualifiers, ['Remix'], reason: 'split reading: "Kygo" + trailing "Remix"');
    });

    test('a streaming "Song - Live" is still a live version of Song', () {
      final m = scorer.score(
        track('spotify', '1', 'Song', ['Queen'], seconds: 200),
        track('deezer', '2', 'Song - Live at Wembley', ['Queen'], seconds: 205),
      );
      expect(m.differences, contains(MatchDifference.live));
      expect(m.confidence, MatchConfidence.low);
    });

    test('a remix in the split title is still detected ("Prince - Purple Rain Remix")', () {
      final m = scorer.score(
        track('spotify', '1', 'Purple Rain', ['Prince'], seconds: 520),
        track('soundcloud', '2', 'Prince - Purple Rain Remix', ['DJ X'], seconds: 520),
      );
      expect(m.differences, contains(MatchDifference.remix));
      expect(m.confidence.isAtLeast(MatchConfidence.medium), isFalse);
    });
  });

  group('title qualifiers (F1)', () {
    FoldedText k(String s) => TextKeys.title(s);

    test('Similarity.qualifiedTitle', () {
      final none = FoldedText.empty;
      expect(Similarity.qualifiedTitle(k('song'), k('part 1'), k('song'), k('part 2')), lessThan(0.75));
      expect(Similarity.qualifiedTitle(k('song'), k('part 2'), k('song part 2'), none), 1.0);
      expect(Similarity.qualifiedTitle(k('song'), k('interlude'), k('song'), none), lessThan(0.6));
      expect(Similarity.qualifiedTitle(k('satisfaction'), k('i cant get no'), k('satisfaction'), none), 1.0);
      expect(Similarity.qualifiedTitle(k('song'), k('love theme'), k('song'), k('other words')), closeTo(0.9, 1e-9));
      expect(Similarity.qualifiedTitle(k('song'), none, k('song'), none), 1.0);
    });

    test('subtitles on one side only still match ("(I Can\'t Get No) Satisfaction")', () {
      final m = scorer.score(
        track('spotify', '1', "(I Can't Get No) Satisfaction - Mono Version", ['The Rolling Stones'], seconds: 223),
        track('deezer', '2', 'Satisfaction', ['The Rolling Stones'], seconds: 223),
      );
      expect(m.confidence, MatchConfidence.high);
    });

    test('junk brackets on one side do not hurt ("[Monstercat Release]")', () {
      final m = scorer.score(
        track('spotify', '1', 'Adventure', ['Rogue'], seconds: 200),
        track('soundcloud', '2', 'Rogue - Adventure [Monstercat Release]', ['Monstercat'], seconds: 200),
      );
      expect(m.confidence, MatchConfidence.high);
    });

    test('a language version is a significant difference ("Spanish Version")', () {
      final m = scorer.score(
        track('spotify', '1', "Hips Don't Lie", ['Shakira'], seconds: 218),
        track('deezer', '2', "Hips Don't Lie (Spanish Version)", ['Shakira'], seconds: 218),
      );
      expect(m.hasSignificantVersionDifference, isTrue);
      expect(m.confidence, MatchConfidence.low);
    });
  });

  group('ISRC (F3, F8)', () {
    test('normalizeIsrc keeps well-formed codes and rejects placeholders', () {
      expect(TrackNormalizer.normalizeIsrc(' us-um7-17-03861 '), 'USUM71703861');
      for (final junk in ['N/A', 'n/a', '0', 'unknown', 'none', '', 'USUM7170386', 'USUM717038612', '12ABC1234567']) {
        expect(TrackNormalizer.normalizeIsrc(junk), isNull, reason: junk);
      }
    });

    test('curated catalogs: an identical ISRC survives another script for the artist', () {
      final m = scorer.score(
        track('deezer', '1', 'Lemon', ['米津玄師'], seconds: 255, isrc: 'JPU901800001'),
        track('spotify', '2', 'Lemon', ['Kenshi Yonezu'], seconds: 256, isrc: 'JPU901800001'),
      );
      expect(m.confidence, MatchConfidence.exact);
      expect(m.matchedByIsrc, isTrue);
    });

    test('an identical ISRC with a very different duration is ignored and flagged in the breakdown', () {
      final m = scorer.score(
        track('spotify', '1', 'Song', ['A'], seconds: 200, isrc: 'USABC1234567'),
        track('deezer', '2', 'Song', ['A'], seconds: 230, isrc: 'USABC1234567'),
      );
      expect(m.confidence, isNot(MatchConfidence.exact));
      expect(m.matchedByIsrc, isFalse);
      expect(m.breakdown[ScoreKeys.isrc], MatchThresholds.isrcContradicted);
    });

    test('uploader platforms need title and artist to agree as well', () {
      final o = track('spotify', '1', 'Adventure', ['Rogue'], seconds: 210, isrc: 'GBABC1600001');
      final fan = scorer.score(o, track('audius', '2', 'Adventure', ['xX Fan Uploads Xx'], seconds: 210, isrc: 'GBABC1600001'));
      expect(fan.confidence, isNot(MatchConfidence.exact));
      final artist = scorer.score(o, track('audius', '3', 'Adventure', ['Rogue'], seconds: 211, isrc: 'GBABC1600001'));
      expect(artist.confidence, MatchConfidence.exact);
    });
  });

  group('ranking (F11)', () {
    test('band ceilings stay out of the next band\'s bucket', () {
      final original = track('spotify', 's1', 'Adventure', ['Rogue'], seconds: 210);
      final noArtist = scorer.score(original, track('audius', 'a1', 'Adventure', const [], seconds: 210));
      expect(noArtist.confidence, MatchConfidence.medium);
      expect((noArtist.score * 100).round(), lessThan(88));
    });
  });

  group('matcher rate-limit gate (F6)', () {
    test('a short block makes the next track wait, then ask again', () async {
      final deezer = FakeSource('deezer', catalog: [track('deezer', 'd1', 'Firestone', ['Kygo'], seconds: 271)])
        ..rateLimitTimes = 3
        ..rateLimitRetryAfter = const Duration(milliseconds: 5);
      final matcher = SourceTrackMatcher(
        registry: FakeRegistry([deezer]),
        scorer: WeightedTrackScorer(),
        settings: const MatcherSettings(rateLimit: RateLimitPolicy(maxRetries: 2)),
      );
      const options = MatchOptions(targetSources: ['deezer']);
      final first = await matcher.findMatches(track('spotify', 's1', 'Adventure', ['Rogue'], seconds: 210), options);
      expect((first.error as SourceMatchFailures).errors['deezer'], isA<RateLimitedException>());
      expect(deezer.searchCalls, 3, reason: 'one query, three attempts, then the remaining queries are skipped');
      final second = await matcher.findMatches(track('spotify', 's2', 'Firestone', ['Kygo'], seconds: 271), options);
      expect(second.error, isNull);
      expect(second.decision, MatchDecision.autoAccepted);
    });

    test('a long block skips the source until it ends', () async {
      var now = DateTime(2026, 10, 27, 12);
      final spotify = FakeSource('spotify', catalog: [track('spotify', 'x1', 'Firestone', ['Kygo'], seconds: 271)])
        ..rateLimitTimes = 1
        ..rateLimitRetryAfter = const Duration(hours: 1);
      final matcher = SourceTrackMatcher(
        registry: FakeRegistry([spotify]),
        scorer: WeightedTrackScorer(),
        clock: () => now,
      );
      const options = MatchOptions(targetSources: ['spotify']);
      final t = track('deezer', 'd1', 'Firestone', ['Kygo'], seconds: 271);
      await matcher.findMatches(t, options);
      expect(spotify.searchCalls, 1);
      expect(matcher.rateLimitedUntil('spotify'), now.add(const Duration(hours: 1)));
      final skipped = await matcher.findMatches(t, options);
      expect(spotify.searchCalls, 1);
      expect((skipped.error as SourceMatchFailures).errors['spotify'], isA<RateLimitedException>());
      now = now.add(const Duration(hours: 2));
      expect(matcher.rateLimitedUntil('spotify'), isNull);
      final again = await matcher.findMatches(t, options);
      expect(again.decision, MatchDecision.autoAccepted);
    });
  });

  group('import truncation (F13)', () {
    test('a repeated cursor is reported as truncated', () async {
      final service = _service(_LoopingSource());
      final id = await service.start(sourceId: 'spotify', playlistIdOrUrl: 'loop', options: const MatchOptions());
      await _reviewing(service, id);
      expect(service.report(id)!.truncated, isTrue);
    });

    test('the page cap is reported as truncated', () async {
      final spotify = FakeSource('spotify')..pageSize = 2;
      spotify.playlists['p'] = (
        const Playlist(id: 'spotify:p', name: 'P', kind: PlaylistKind.remote, sourceId: 'spotify'),
        [for (var i = 0; i < 5; i++) track('spotify', 's$i', 'Song $i', ['A'])],
      );
      final service = _service(spotify, settings: const ImportSettings(progressInterval: Duration.zero, maxPages: 2));
      final id = await service.start(sourceId: 'spotify', playlistIdOrUrl: 'p', options: const MatchOptions());
      await _reviewing(service, id);
      expect(service.current(id)!.total, 4);
      expect(service.report(id)!.truncated, isTrue);
    });

    test('a playlist that exactly fits is not truncated; one more track is', () async {
      for (final (count, truncated) in [(4, false), (5, true)]) {
        final spotify = FakeSource('spotify')..pageSize = 2;
        spotify.playlists['p'] = (
          const Playlist(id: 'spotify:p', name: 'P', kind: PlaylistKind.remote, sourceId: 'spotify'),
          [for (var i = 0; i < count; i++) track('spotify', 's$i', 'Song $i', ['A'])],
        );
        final service = _service(spotify, settings: const ImportSettings(progressInterval: Duration.zero, maxTracks: 4));
        final id = await service.start(sourceId: 'spotify', playlistIdOrUrl: 'p', options: const MatchOptions());
        await _reviewing(service, id);
        expect(service.report(id)!.truncated, truncated, reason: '$count tracks');
      }
    });

    test('startWithTracks beyond the cap is truncated', () async {
      final service = _service(FakeSource('spotify'), settings: const ImportSettings(progressInterval: Duration.zero, maxTracks: 2));
      final id = await service.startWithTracks(
        sourceId: 'spotify',
        name: 'Liked',
        tracks: [for (var i = 0; i < 3; i++) track('spotify', 's$i', 'Song $i', ['A'])],
        options: const MatchOptions(),
      );
      await _reviewing(service, id);
      expect(service.report(id)!.truncated, isTrue);
    });
  });

  group('ImportReport.fromPositions (F14)', () {
    test('unmatched positions are skipped, positions are playlist positions', () {
      final a = track('spotify', 'a', 'A', ['X']);
      final b = track('spotify', 'b', 'B', ['X']);
      final report = ImportReport.fromPositions([
        null,
        TrackMatchResult(original: a, candidates: const [], decision: MatchDecision.notFound),
        null,
        TrackMatchResult(original: b, candidates: const [], decision: MatchDecision.skipped),
      ]);
      expect(report.total, 2);
      expect(report.missing.map((m) => m.position), [1, 3]);
    });
  });

  group('session lifecycle (F15, F17)', () {
    test('finished sessions beyond the limit or past their TTL are forgotten when an import starts', () async {
      var now = DateTime(2026, 10, 27, 12);
      final service = _service(
        FakeSource('spotify'),
        clock: () => now,
        settings: const ImportSettings(
          progressInterval: Duration.zero,
          maxFinishedSessions: 1,
          finishedSessionTtl: Duration(minutes: 30),
        ),
      );
      Future<String> start() =>
          service.startWithTracks(sourceId: 'spotify', name: 'x', tracks: const [], options: const MatchOptions());
      final a = await start();
      final b = await start();
      await _reviewing(service, a);
      await _reviewing(service, b);
      service.cancel(a);
      now = now.add(const Duration(minutes: 1));
      service.cancel(b);
      final c = await start();
      expect(service.sessionIds, [b, c], reason: 'only the newest finished session is kept');
      await _reviewing(service, c);
      now = now.add(const Duration(hours: 1));
      final d = await start();
      expect(service.sessionIds, [c, d], reason: 'b expired; c is still in review and never evicted');
      expect(service.current(a), isNull);
    });

    test('searchAlternatives reports an unknown track through the future', () async {
      final service = _service(FakeSource('spotify'));
      final id = await service.startWithTracks(
          sourceId: 'spotify', name: 'x', tracks: [track('spotify', 's1', 'A', ['X'])], options: const MatchOptions());
      await _reviewing(service, id);
      await expectLater(service.searchAlternatives(id, 'spotify:nope', ''), throwsArgumentError);
    });
  });

  group('logs (F16)', () {
    test('playlist links are redacted', () {
      expect(PlaylistFetcher.redact('https://soundcloud.com/artist/sets/mix/s-AbC123xyz?si=abc&utm_source=x'),
          'soundcloud.com/artist/sets/mix/s-…?…');
      expect(PlaylistFetcher.redact('https://www.youtube.com/playlist?list=PLsecret'), 'www.youtube.com/playlist?…');
      expect(PlaylistFetcher.redact('37i9dQZF1DX'), '37i9dQZF1DX');
    });
  });

  group('saving policy-restricted originals (F7)', () {
    test('Spotify originals and the playlist cover are stored without artwork and marked', () async {
      final art = Uri.parse('https://i.scdn.co/image/abc');
      final spotify = FakeSource('spotify')..pageSize = 10;
      spotify.playlists['p'] = (
        Playlist(id: 'spotify:p', name: 'P', kind: PlaylistKind.remote, sourceId: 'spotify', artworkUrl: art),
        [
          Track(sourceId: 'spotify', sourceTrackId: 's1', title: 'Song', artists: const [ArtistRef('A')],
              artworkUrl: art, permalink: Uri.parse('https://open.spotify.com/track/s1')),
        ],
      );
      final tracks = InMemoryTrackRepository();
      final playlists = InMemoryPlaylistRepository();
      final service = _service(spotify, tracks: tracks, playlists: playlists);
      final id = await service.start(sourceId: 'spotify', playlistIdOrUrl: 'p', options: const MatchOptions());
      await _reviewing(service, id);
      final playlistId = await service.save(id);
      final stored = tracks.tracks['spotify:s1']!;
      expect(stored.artworkUrl, isNull);
      expect(stored.permalink, isNotNull, reason: 'attribution back-link stays');
      expect(stored.extra[ImportSaver.minimizedMarker], '1');
      expect(playlists.byId[playlistId]!.artworkUrl, isNull);
    });

    test('other sources keep their artwork', () async {
      final art = Uri.parse('https://cdn.example/a.jpg');
      final repoTracks = InMemoryTrackRepository();
      final saver = ImportSaver(tracks: repoTracks, playlists: InMemoryPlaylistRepository(), links: InMemoryLinkRepository());
      expect(saver.minimizedSources, {'spotify'});
      await saver.save(
        sourceId: 'deezer',
        sourcePlaylist: null,
        originals: [Track(sourceId: 'deezer', sourceTrackId: 'd1', title: 'Song', artworkUrl: art)],
        results: const [],
      );
      expect(repoTracks.tracks['deezer:d1']!.artworkUrl, art);
      expect(repoTracks.tracks['deezer:d1']!.extra, isEmpty);
    });
  });

  test('single review actions on a large session stay cheap (F5)', () async {
    // "Accept all" on 10 000 tracks is covered in review_import_test.dart.
    final service = _service(FakeSource('spotify'));
    final big = [for (var i = 0; i < 5000; i++) track('spotify', 'b$i', 'Song $i', ['A'])];
    final id = await service.startWithTracks(sourceId: 'spotify', name: 'Big', tracks: big, options: const MatchOptions());
    await service.watch(id).firstWhere((s) => s.phase == ImportPhase.reviewing).timeout(const Duration(seconds: 60));
    final sw = Stopwatch()..start();
    for (var i = 0; i < 200; i++) {
      service.skip(id, big[i].id);
    }
    expect(sw.elapsedMilliseconds, lessThan(2000));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
