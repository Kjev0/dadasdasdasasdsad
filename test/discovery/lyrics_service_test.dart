import 'dart:convert';
import 'dart:io';

import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/net/http_client.dart';
import 'package:fermata/core/platform/app_paths.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/discovery/discovery.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

String fixture(String name) => File('test/discovery/fixtures/$name').readAsStringSync();

http.Response json(String body, [int status = 200]) =>
    http.Response(body, status, headers: {'content-type': 'application/json; charset=utf-8'});

/// Fake LRCLIB: `/api/get` and `/api/search` answers, all requests recorded.
class FakeLrclib {
  FakeLrclib({this.get, this.search = '[]', this.failWith});

  /// Body for `/api/get`; null → 404 TrackNotFound.
  String? get;
  String search;
  int? failWith;
  final requests = <Uri>[];
  final userAgents = <String?>[];

  Iterable<Uri> get gets => requests.where((u) => u.path == '/api/get');

  Iterable<Uri> get searches => requests.where((u) => u.path == '/api/search');

  MockClient get client => MockClient((request) async {
        requests.add(request.url);
        userAgents.add(request.headers['User-Agent']);
        if (failWith != null) return json('{"message":"boom"}', failWith!);
        if (request.url.path == '/api/get') {
          return get == null ? json(fixture('lrclib_get_notfound.json'), 404) : json(get!);
        }
        if (request.url.path == '/api/search') return json(search);
        return json('{}', 404);
      });
}

Track song({
  String id = 'iwtl',
  String title = 'I Want to Live',
  String artist = 'Borislav Slavov',
  String? album = "Baldur's Gate 3 (Original Game Soundtrack)",
  int? seconds = 233,
  String? localPath,
  String source = SourceIds.audius,
}) =>
    Track(
      sourceId: source,
      sourceTrackId: id,
      title: title,
      artists: artist.isEmpty ? const [] : [ArtistRef(artist)],
      album: album,
      duration: seconds == null ? null : Duration(seconds: seconds),
      localPath: localPath,
    );

void main() {
  late Directory root;
  late AppPaths paths;
  late SettingsStore settings;

  setUp(() {
    root = Directory.systemTemp.createTempSync('fermata_lyrics_');
    paths = AppPaths.forTesting(root);
    settings = SettingsStore.inMemory();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  LyricsServiceImpl service(FakeLrclib lrclib,
      {DateTime Function()? clock, EmbeddedLyricsReader? embedded, bool diskCache = true}) {
    final http = FermataHttp(client: lrclib.client);
    return LyricsServiceImpl(
      http,
      settings,
      paths,
      client: LrclibClient(http, minRequestGap: Duration.zero, clock: clock),
      embeddedReader: embedded,
      clock: clock,
      diskCache: diskCache,
    );
  }

  group('settings', () {
    test('lyrics disabled → null and not a single request or file access', () async {
      await settings.update((s) => s.copyWith(playback: s.playback.copyWith(lyricsEnabled: false)));
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      var embeddedReads = 0;
      final svc = service(lrclib, embedded: (_) async {
        embeddedReads++;
        return 'text';
      });
      expect(await svc.lyricsFor(song()), isNull);
      expect(await svc.lyricsFor(song(localPath: '/music/a.flac', source: SourceIds.local)), isNull);
      expect(lrclib.requests, isEmpty);
      expect(embeddedReads, 0);
      expect(Directory(p.join(paths.cacheDir.path, 'lyrics')).existsSync(), isFalse);
    });

    test('turning lyrics on again fetches', () async {
      await settings.update((s) => s.copyWith(playback: s.playback.copyWith(lyricsEnabled: false)));
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final svc = service(lrclib);
      expect(await svc.lyricsFor(song()), isNull);
      await settings.update((s) => s.copyWith(playback: s.playback.copyWith(lyricsEnabled: true)));
      expect(await svc.lyricsFor(song()), isNotNull);
      expect(lrclib.requests, hasLength(1));
    });
  });

  group('LRCLIB lookup', () {
    test('/api/get with title, artist, album and rounded duration; attribution LRCLIB', () async {
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final lyrics = await service(lrclib).lyricsFor(song(seconds: 233));
      expect(lrclib.requests, hasLength(1));
      final q = lrclib.gets.single.queryParameters;
      expect(q, {
        'track_name': 'I Want to Live',
        'artist_name': 'Borislav Slavov',
        'album_name': "Baldur's Gate 3 (Original Game Soundtrack)",
        'duration': '233',
      });
      expect(lrclib.userAgents.single, contains('Fermata'));
      expect(lyrics!.provider, 'LRCLIB');
      expect(LyricsProviders.lrclib, 'LRCLIB');
      expect(lyrics.sourceUrl, Uri.parse('https://lrclib.net'));
      expect(lyrics.hasSynced, isTrue);
      expect(lyrics.synced.first.time, const Duration(milliseconds: 17120));
      expect(lyrics.synced.first.text, 'I feel your breath upon my neck');
      expect(lyrics.plain, startsWith('I feel your breath'));
      expect(lyrics.instrumental, isFalse);
    });

    test('title noise ("feat.", "Remastered") is stripped from the query', () async {
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      await service(lrclib).lyricsFor(song(title: 'I Want to Live (feat. Somebody) [Remastered 2011]'));
      expect(lrclib.gets.single.queryParameters['track_name'], 'I Want to Live');
    });

    test('duration is rounded to whole seconds', () {
      expect(LyricsServiceImpl.durationSeconds(const Duration(milliseconds: 233400)), 233);
      expect(LyricsServiceImpl.durationSeconds(const Duration(milliseconds: 233600)), 234);
      expect(LyricsServiceImpl.durationSeconds(Duration.zero), isNull);
      expect(LyricsServiceImpl.durationSeconds(const Duration(seconds: 3601)), isNull);
      expect(LyricsServiceImpl.durationSeconds(null), isNull);
    });

    test('get miss → search (≤ 20 results) → closest duration within tolerance wins', () async {
      final lrclib = FakeLrclib(search: fixture('lrclib_search_iwanttolive.json'));
      // The track is 234 s long: /api/get (±2 s) failed, the search holds 233.0 s records.
      final lyrics = await service(lrclib).lyricsFor(song(seconds: 234));
      expect(lrclib.gets, hasLength(1));
      expect(lrclib.searches, hasLength(1));
      expect(lrclib.searches.single.queryParameters, {'track_name': 'I Want to Live', 'artist_name': 'Borislav Slavov'});
      expect(lyrics, isNotNull);
      expect(lyrics!.provider, 'LRCLIB');
      expect(lyrics.hasSynced, isTrue);
    });

    test('pickBest: nearest duration, then synced, then album; outside tolerance → none', () {
      final records = _searchRecords();
      LrclibRecord? pick(Track t, {Duration tolerance = const Duration(seconds: 3)}) =>
          LyricsServiceImpl.pickBest(records, t, tolerance: tolerance);

      expect(pick(song(seconds: 233))!.id, 34537714, reason: 'first exact 233.0 s record');
      expect(pick(song(seconds: 239))!.id, 19442974, reason: 'among 239.0 s records the album matches');
      expect(pick(song(seconds: 236))!.id, 21993341, reason: '235.28 s is the closest to 236 s');
      expect(pick(song(seconds: 100)), isNull, reason: 'nothing within ±3 s');
      expect(pick(song(seconds: 234), tolerance: Duration.zero), isNull);
      expect(pick(song(seconds: 233, title: 'Another Song')), isNull);
      expect(pick(song(seconds: 233, artist: 'Someone Else')), isNull);
      // Without a known duration the first matching record is used.
      expect(pick(song(seconds: null))!.id, 34631214);
    });

    test('a track whose duration LRCLIB does not know is searched directly', () async {
      final lrclib = FakeLrclib(search: fixture('lrclib_search_iwanttolive.json'));
      final lyrics = await service(lrclib).lyricsFor(song(seconds: null));
      expect(lrclib.gets, isEmpty);
      expect(lrclib.searches, hasLength(1));
      expect(lyrics, isNotNull);
    });

    test('no result within the duration tolerance → null (cached as a miss)', () async {
      final lrclib = FakeLrclib(search: fixture('lrclib_search_iwanttolive.json'));
      final svc = service(lrclib);
      expect(await svc.lyricsFor(song(seconds: 100)), isNull);
      expect(await svc.lyricsFor(song(seconds: 100)), isNull);
      expect(lrclib.requests, hasLength(2), reason: 'get + search once, then the miss is remembered');
    });

    test('instrumental records are flagged, without text', () async {
      final lrclib = FakeLrclib(search: fixture('lrclib_search_instrumental.json'));
      final lyrics = await service(lrclib)
          .lyricsFor(song(id: 'cdl', title: 'Clair de lune', artist: 'Claude Debussy', album: null, seconds: 308));
      expect(lyrics!.instrumental, isTrue);
      expect(lyrics.plain, isNull);
      expect(lyrics.synced, isEmpty);
      expect(lyrics.provider, 'LRCLIB');
    });

    test('/api/get returning only plain lyrics gives unsynced lyrics', () async {
      final lrclib = FakeLrclib(
        get: '{"id":1,"trackName":"I Want to Live","artistName":"Borislav Slavov","duration":233,'
            '"instrumental":false,"plainLyrics":"line one\\nline two","syncedLyrics":null}',
      );
      final lyrics = await service(lrclib).lyricsFor(song());
      expect(lyrics!.hasSynced, isFalse);
      expect(lyrics.plain, 'line one\nline two');
    });

    test('tracks without artist or title are never looked up', () async {
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final svc = service(lrclib);
      expect(await svc.lyricsFor(song(artist: '')), isNull);
      expect(await svc.lyricsFor(song(id: 'x', title: '  ')), isNull);
      expect(lrclib.requests, isEmpty);
    });

    test('failures surface as typed errors and are not cached as misses', () async {
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'), failWith: 500);
      final svc = service(lrclib);
      await expectLater(svc.lyricsFor(song()), throwsA(isA<ApiException>()));
      lrclib.failWith = null;
      expect(await svc.lyricsFor(song()), isNotNull);
    });

    test('a canceled token stops before any request', () async {
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final cancel = CancelToken()..cancel();
      await expectLater(service(lrclib).lyricsFor(song(), cancel: cancel), throwsA(isA<OperationCanceledException>()));
      expect(lrclib.requests, isEmpty);
    });
  });

  group('cache', () {
    test('memory: the same track is fetched once', () async {
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final svc = service(lrclib, diskCache: false);
      final a = await svc.lyricsFor(song());
      final b = await svc.lyricsFor(song());
      expect(identical(a, b), isTrue);
      expect(lrclib.requests, hasLength(1));
      expect(Directory(p.join(paths.cacheDir.path, 'lyrics')).existsSync(), isFalse);
    });

    test('disk: a new service instance reads the JSON file instead of the network', () async {
      final first = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final a = await service(first).lyricsFor(song());
      final files = Directory(p.join(paths.cacheDir.path, 'lyrics')).listSync().whereType<File>().toList();
      expect(files, hasLength(1));
      expect(files.single.path, endsWith('.json'));

      final second = FakeLrclib(failWith: 500);
      final b = await service(second).lyricsFor(song());
      expect(second.requests, isEmpty);
      expect(b!.provider, 'LRCLIB');
      expect(b.plain, a!.plain);
      expect(b.synced.length, a.synced.length);
      expect(b.synced[3].time, a.synced[3].time);
      expect(b.sourceUrl, a.sourceUrl);
    });

    test('positive entries last 30 days, misses 3 days', () async {
      var now = DateTime(2026, 3, 1);
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final svc = service(lrclib, clock: () => now);
      await svc.lyricsFor(song());
      await svc.lyricsFor(song(id: 'miss', title: 'Nothing', artist: 'Nobody'));
      expect(lrclib.requests, hasLength(2));
      // The in-memory copy is per service; use fresh instances to hit the disk.
      lrclib.requests.clear();

      now = now.add(const Duration(days: 2));
      await service(lrclib, clock: () => now).lyricsFor(song());
      expect(lrclib.requests, isEmpty, reason: 'positive entry still fresh');

      lrclib.get = null;
      now = now.add(const Duration(days: 2)); // day 4: the miss (3 d) expired, the hit did not
      final later = service(lrclib, clock: () => now);
      await later.lyricsFor(song());
      expect(lrclib.requests, isEmpty);
      expect(await later.lyricsFor(song(id: 'miss', title: 'Nothing', artist: 'Nobody', seconds: null)), isNull);
      expect(lrclib.requests, isNotEmpty, reason: 'expired miss is looked up again');

      lrclib.requests.clear();
      lrclib.get = fixture('lrclib_get_ok.json');
      now = now.add(const Duration(days: 28)); // day 32: the positive entry expired
      await service(lrclib, clock: () => now).lyricsFor(song());
      expect(lrclib.gets, hasLength(1));
    });

    test('a corrupt cache file is ignored and replaced', () async {
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final svc = service(lrclib);
      await svc.lyricsFor(song());
      final file = svc.cache.fileFor(song().id)!;
      file.writeAsStringSync('{ not json');
      final fresh = service(lrclib);
      expect(await fresh.lyricsFor(song()), isNotNull);
      expect(lrclib.requests, hasLength(2));
      expect((await fresh.cache.read(song().id))!.lyrics, isNotNull);
    });

    test('clearCache forgets memory and disk', () async {
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final svc = service(lrclib);
      await svc.lyricsFor(song());
      await svc.clearCache();
      await svc.lyricsFor(song());
      expect(lrclib.requests, hasLength(2));
    });

    test('LyricsCache round-trips synced, plain and instrumental lyrics', () async {
      final cache = LyricsCache(Directory(p.join(root.path, 'c')));
      final synced = LyricsServiceImpl.toLyrics(LrclibRecord.fromJson({
        'id': 1,
        'trackName': 't',
        'artistName': 'a',
        'syncedLyrics': '[00:01.00]one\n[00:02.50]two',
      }))!;
      await cache.write('s', synced);
      await cache.write('i', const Lyrics(instrumental: true, provider: 'LRCLIB'));
      await cache.write('n', null);
      final s = (await cache.read('s'))!.lyrics!;
      expect([for (final l in s.synced) (l.time.inMilliseconds, l.text)], [(1000, 'one'), (2500, 'two')]);
      expect(s.plain, 'one\ntwo');
      expect((await cache.read('i'))!.lyrics!.instrumental, isTrue);
      final miss = await cache.read('n');
      expect(miss, isNotNull);
      expect(miss!.lyrics, isNull);
      expect(await cache.read('never-written'), isNull);
    });
  });

  group('local files', () {
    test('a sidecar .lrc next to the file wins over LRCLIB', () async {
      final dir = Directory(p.join(root.path, 'music'))..createSync();
      final audio = p.join(dir.path, 'Song.flac');
      File(audio).writeAsBytesSync([0]);
      File(p.join(dir.path, 'Song.lrc')).writeAsStringSync('[ti:Song]\n[00:01.00]Hello\n[00:03.00]World\n');
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final lyrics = await service(lrclib).lyricsFor(song(source: SourceIds.local, localPath: audio));
      expect(lrclib.requests, isEmpty);
      expect(lyrics!.provider, LyricsProviders.lrcFile);
      expect(lyrics.synced.map((l) => l.text), ['Hello', 'World']);
      expect(lyrics.plain, 'Hello\nWorld');
    });

    test('embedded lyrics: LRC text → synced, other text → plain', () async {
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final synced = await service(lrclib, embedded: (_) async => '[00:05.00]Embedded line')
          .lyricsFor(song(id: 'e1', source: SourceIds.local, localPath: '/nope/a.mp3'));
      expect(synced!.provider, LyricsProviders.embedded);
      expect(synced.hasSynced, isTrue);
      expect(synced.synced.single.time, const Duration(seconds: 5));

      final plain = await service(lrclib, embedded: (_) async => 'Just words\nin lines\n')
          .lyricsFor(song(id: 'e2', source: SourceIds.local, localPath: '/nope/b.mp3'));
      expect(plain!.hasSynced, isFalse);
      expect(plain.plain, 'Just words\nin lines');
      expect(lrclib.requests, isEmpty);
    });

    test('readEmbeddedLyrics reads the ID3 USLT frame of a real MP3', () async {
      final copy = File(p.join(root.path, 'embedded.mp3'))
        ..writeAsBytesSync(File('test/discovery/fixtures/embedded_lyrics.mp3').readAsBytesSync());
      final text = await readEmbeddedLyrics(copy.path);
      expect(text, isNotNull);
      final lyrics = LyricsServiceImpl.fromText(text!, provider: LyricsProviders.embedded)!;
      expect(lyrics.synced.map((l) => l.text), ['Hello world', 'Second line']);
      expect(await readEmbeddedLyrics(p.join(root.path, 'missing.mp3')), isNull);
      final junk = File(p.join(root.path, 'junk.mp3'))..writeAsBytesSync([1, 2, 3]);
      expect(await readEmbeddedLyrics(junk.path), isNull);
    });

    test('a local file without lyrics falls back to LRCLIB', () async {
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final lyrics = await service(lrclib, embedded: (_) async => null)
          .lyricsFor(song(id: 'l1', source: SourceIds.local, localPath: '/nope/c.mp3'));
      expect(lyrics!.provider, 'LRCLIB');
      expect(lrclib.gets, hasLength(1));
    });

    test('a failing embedded reader does not break lookup', () async {
      final lrclib = FakeLrclib(get: fixture('lrclib_get_ok.json'));
      final lyrics = await service(lrclib, embedded: (_) async => throw const FileSystemException('boom'))
          .lyricsFor(song(id: 'l2', source: SourceIds.local, localPath: '/nope/d.mp3'));
      expect(lyrics!.provider, 'LRCLIB');
    });
  });
}

List<LrclibRecord> _searchRecords() {
  // Same decoding as the client, without a network.
  final list = jsonDecode(fixture('lrclib_search_iwanttolive.json')) as List;
  return [for (final r in list) LrclibRecord.fromJson((r as Map).cast<String, Object?>())];
}
