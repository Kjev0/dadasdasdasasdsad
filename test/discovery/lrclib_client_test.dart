import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fermata/core/errors.dart';
import 'package:fermata/core/net/http_client.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/discovery/lyrics/lrclib_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) => File('test/discovery/fixtures/$name').readAsStringSync();

http.Response json(String body, [int status = 200, Map<String, String> headers = const {}]) =>
    http.Response(body, status, headers: {'content-type': 'application/json; charset=utf-8', ...headers});

/// Records requests and answers with the scripted responses (last one repeats).
class Script {
  Script(this.responses);

  final List<http.Response Function(http.Request)> responses;
  final requests = <http.Request>[];

  MockClient get client => MockClient((request) async {
        requests.add(request);
        final i = requests.length - 1;
        return responses[i < responses.length ? i : responses.length - 1](request);
      });
}

void main() {
  group('request building', () {
    final client = LrclibClient(FermataHttp(client: MockClient((_) async => json('{}'))));

    test('/api/get carries track, artist, album and duration', () {
      final uri = client.getUri(
          trackName: 'I Want to Live', artistName: 'Borislav Slavov', albumName: "Baldur's Gate 3", durationSeconds: 233);
      expect(uri.scheme, 'https');
      expect(uri.host, 'lrclib.net');
      expect(uri.path, '/api/get');
      expect(uri.queryParameters, {
        'track_name': 'I Want to Live',
        'artist_name': 'Borislav Slavov',
        'album_name': "Baldur's Gate 3",
        'duration': '233',
      });
    });

    test('blank album and unknown duration are left out; special characters survive', () {
      final uri = client.getUri(trackName: 'AC/DC & Co? #1', artistName: 'Sigur Rós', albumName: '  ');
      expect(uri.queryParameters.keys, ['track_name', 'artist_name']);
      expect(Uri.parse(uri.toString()).queryParameters['track_name'], 'AC/DC & Co? #1');
      expect(Uri.parse(uri.toString()).queryParameters['artist_name'], 'Sigur Rós');
    });

    test('/api/search uses track_name and artist_name', () {
      final uri = client.searchUri(trackName: 'Clair de lune', artistName: 'Claude Debussy');
      expect(uri.path, '/api/search');
      expect(uri.queryParameters, {'track_name': 'Clair de lune', 'artist_name': 'Claude Debussy'});
      expect(client.searchUri(trackName: 'x').queryParameters, {'track_name': 'x'});
    });

    test('a custom base URI is honoured', () {
      final c = LrclibClient(FermataHttp(), baseUri: Uri.parse('https://example.test/lrc/'));
      expect(c.getUri(trackName: 'a', artistName: 'b').path, '/lrc/api/get');
    });
  });

  group('requests', () {
    test('GET with an app-identifying User-Agent, JSON accept and optional app id', () async {
      final script = Script([(_) => json(fixture('lrclib_get_ok.json'))]);
      final client = LrclibClient(FermataHttp(client: script.client), appId: 'fermata-test', minRequestGap: Duration.zero);
      final record = await client.get(
          trackName: 'I Want to Live', artistName: 'Borislav Slavov', albumName: 'x', durationSeconds: 233);
      final r = script.requests.single;
      expect(r.method, 'GET');
      expect(r.url.path, '/api/get');
      expect(r.headers['User-Agent'], FermataHttp.defaultUserAgent);
      expect(r.headers['User-Agent'], contains('Fermata'));
      expect(r.headers['Accept'], 'application/json');
      expect(r.headers['Lrclib-App-Id'], 'fermata-test');
      expect(record!.id, 3396226);
      expect(record.trackName, 'I Want to Live');
      expect(record.duration, 233.0);
      expect(record.instrumental, isFalse);
      expect(record.syncedLyrics, startsWith('[00:17.12]'));
      expect(record.plainLyrics, startsWith('I feel your breath'));
      expect(record.hasLyrics, isTrue);
    });

    test('no app id header unless configured', () async {
      final script = Script([(_) => json(fixture('lrclib_get_ok.json'))]);
      final client = LrclibClient(FermataHttp(client: script.client), minRequestGap: Duration.zero);
      await client.get(trackName: 'a', artistName: 'b');
      expect(script.requests.single.headers.containsKey('Lrclib-App-Id'), isFalse);
    });

    test('404 TrackNotFound is "no lyrics", not an error', () async {
      final script = Script([(_) => json(fixture('lrclib_get_notfound.json'), 404)]);
      final client = LrclibClient(FermataHttp(client: script.client), minRequestGap: Duration.zero);
      expect(await client.get(trackName: 'a', artistName: 'b', durationSeconds: 10), isNull);
      expect(await client.search(trackName: 'a'), isEmpty);
      expect(script.requests, hasLength(2));
    });

    test('search parses up to 20 records, non-UTF-8-safe text included', () async {
      final script = Script([(_) => json(fixture('lrclib_search_iwanttolive.json'))]);
      final client = LrclibClient(FermataHttp(client: script.client), minRequestGap: Duration.zero);
      final results = await client.search(trackName: 'I Want to Live', artistName: 'Borislav Slavov');
      expect(results, hasLength(20));
      expect(results.every((r) => r.artistName == 'Borislav Slavov'), isTrue);
      expect(results.first.duration, 282.0);
      final instrumental = LrclibClient(
        FermataHttp(client: Script([(_) => json(fixture('lrclib_search_instrumental.json'))]).client),
        minRequestGap: Duration.zero,
      );
      final i = await instrumental.search(trackName: 'Clair de lune');
      expect(i.every((r) => r.instrumental && !r.hasLyrics), isTrue);
    });

    test('unexpected payloads, errors and HTML pages are ApiExceptions', () async {
      Future<Object?> run(http.Response response, {bool search = false}) {
        final client = LrclibClient(FermataHttp(client: MockClient((_) async => response)), minRequestGap: Duration.zero);
        return search ? client.search(trackName: 'a') : client.get(trackName: 'a', artistName: 'b');
      }

      await expectLater(run(json('[]')), throwsA(isA<ApiException>()));
      await expectLater(run(json('{}'), search: true), throwsA(isA<ApiException>()));
      await expectLater(run(json('boom', 500)), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 500)));
      await expectLater(run(http.Response('<html></html>', 200, headers: {'content-type': 'text/html'})),
          throwsA(isA<ApiException>()));
      await expectLater(run(json('{not json')), throwsA(isA<ApiException>()));
    });

    test('requests are spaced by minRequestGap', () async {
      final sleeps = <Duration>[];
      final script = Script([(_) => json('[]')]);
      final client = LrclibClient(
        FermataHttp(client: script.client),
        minRequestGap: const Duration(milliseconds: 250),
        clock: () => DateTime(2026, 1, 1),
        sleep: (d) async => sleeps.add(d),
      );
      await Future.wait([client.search(trackName: 'a'), client.search(trackName: 'b'), client.search(trackName: 'c')]);
      expect(script.requests, hasLength(3));
      expect(sleeps, [const Duration(milliseconds: 250), const Duration(milliseconds: 250)]);
    });

    test('a canceled token sends nothing', () async {
      final script = Script([(_) => json('{}')]);
      final client = LrclibClient(FermataHttp(client: script.client), minRequestGap: Duration.zero);
      final cancel = CancelToken()..cancel();
      await expectLater(client.get(trackName: 'a', artistName: 'b', cancel: cancel), throwsA(isA<OperationCanceledException>()));
      expect(script.requests, isEmpty);
    });
  });

  group('Retry-After', () {
    test('a short 429 wait is honoured once (with jitter), then the request succeeds', () async {
      final sleeps = <Duration>[];
      final script = Script([
        (_) => json('{}', 429, {'retry-after': '2'}),
        (_) => json(fixture('lrclib_get_ok.json')),
      ]);
      final client = LrclibClient(
        FermataHttp(client: script.client),
        minRequestGap: Duration.zero,
        sleep: (d) async => sleeps.add(d),
        random: Random(7),
      );
      final record = await client.get(trackName: 'a', artistName: 'b');
      expect(record, isNotNull);
      expect(script.requests, hasLength(2));
      expect(sleeps, hasLength(1));
      expect(sleeps.single, greaterThanOrEqualTo(const Duration(seconds: 2)));
      expect(sleeps.single, lessThanOrEqualTo(const Duration(milliseconds: 2600)));
      expect(client.blockedUntil, isNull);
    });

    test('503 with Retry-After is treated like 429', () async {
      final sleeps = <Duration>[];
      final script = Script([
        (_) => json('{}', 503, {'retry-after': '1'}),
        (_) => json('[]'),
      ]);
      final client = LrclibClient(FermataHttp(client: script.client),
          minRequestGap: Duration.zero, sleep: (d) async => sleeps.add(d));
      expect(await client.search(trackName: 'a'), isEmpty);
      expect(script.requests, hasLength(2));
      expect(sleeps.single, greaterThanOrEqualTo(const Duration(seconds: 1)));
    });

    test('a long wait suspends all requests until it has passed', () async {
      var now = DateTime(2026, 5, 1, 12);
      final script = Script([
        (_) => json('{}', 429, {'retry-after': '120'}),
        (_) => json('[]'),
      ]);
      final client = LrclibClient(FermataHttp(client: script.client),
          minRequestGap: Duration.zero, clock: () => now, sleep: (_) async {}, random: Random(1));
      await expectLater(
        client.search(trackName: 'a'),
        throwsA(isA<RateLimitedException>().having((e) => e.retryAfter, 'retryAfter', greaterThanOrEqualTo(const Duration(seconds: 120)))),
      );
      expect(script.requests, hasLength(1), reason: 'no inline retry for a long wait');
      expect(client.blockedUntil, isNotNull);

      // Still blocked: nothing is sent.
      now = now.add(const Duration(seconds: 60));
      await expectLater(client.search(trackName: 'b'), throwsA(isA<RateLimitedException>()));
      expect(script.requests, hasLength(1));

      // After the wait requests flow again.
      now = now.add(const Duration(minutes: 5));
      expect(await client.search(trackName: 'c'), isEmpty);
      expect(script.requests, hasLength(2));
    });

    test('a second 429 right after the retry gives up', () async {
      final script = Script([(_) => json('{}', 429, {'retry-after': '1'})]);
      final client = LrclibClient(FermataHttp(client: script.client), minRequestGap: Duration.zero, sleep: (_) async {});
      await expectLater(client.get(trackName: 'a', artistName: 'b'), throwsA(isA<RateLimitedException>()));
      expect(script.requests, hasLength(2));
      expect(client.blockedUntil, isNotNull);
    });
  });

  test('fixtures are valid JSON', () {
    for (final f in ['lrclib_get_ok.json', 'lrclib_get_notfound.json', 'lrclib_search_iwanttolive.json', 'lrclib_search_instrumental.json']) {
      expect(() => jsonDecode(fixture(f)), returnsNormally, reason: f);
    }
  });
}
