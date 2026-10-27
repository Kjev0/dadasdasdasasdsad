import 'dart:convert';
import 'dart:io';

import 'package:fermata/core/errors.dart';
import 'package:fermata/core/net/http_client.dart';
import 'package:fermata/core/platform/app_paths.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/discovery/discovery.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

SemVer v(String s) => SemVer.parse(s);

const linux = PlatformInfo(os: HostOs.linux);
const windows = PlatformInfo(os: HostOs.windows);
const android = PlatformInfo(os: HostOs.android);

/// A trimmed `releases/latest` payload as returned by api.github.com.
Map<String, Object?> release({String tag = 'v1.2.0'}) => {
      'tag_name': tag,
      'name': 'Fermata $tag',
      'html_url': 'https://github.com/kjev0/dadasdasdasasdsad/releases/tag/$tag',
      'body': '## Changes\n- Faster start',
      'published_at': '2026-10-01T12:00:00Z',
      'prerelease': false,
      'assets': [
        for (final (name, size) in [
          ('fermata-1.2.0-linux-x64.tar.gz', 40000000),
          ('fermata-1.2.0-x86_64.AppImage', 50000000),
          ('fermata-1.2.0-linux-x64.tar.gz.sha256', 90),
          ('fermata-1.2.0-windows-x64.zip', 45000000),
          ('fermata-setup-1.2.0.exe', 46000000),
          ('fermata-1.2.0-arm64-v8a.apk', 30000000),
          ('SHA256SUMS.txt', 400),
          ('source.tar.gz', 1000),
        ])
          {
            'name': name,
            'size': size,
            'browser_download_url': 'https://github.com/kjev0/dadasdasdasasdsad/releases/download/$tag/$name',
          },
      ],
    };

http.Response ghJson(Object body, {int status = 200, Map<String, String> headers = const {}}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8', ...headers},
    );

void main() {
  group('SemVer', () {
    test('numeric, not lexicographic, ordering', () {
      expect(v('1.2.10') > v('1.2.9'), isTrue);
      expect(v('1.10.0') > v('1.9.9'), isTrue);
      expect(v('2.0.0') > v('1.99.99'), isTrue);
      expect(v('1.0.0') > v('1.0.0'), isFalse);
      expect(v('0.9.9') < v('1.0.0'), isTrue);
    });

    test('lenient tags: v prefix, missing parts, build metadata, whitespace', () {
      expect(v('v1.2.3'), v('1.2.3'));
      expect(v('V1.2'), v('1.2.0'));
      expect(v('3'), v('3.0.0'));
      expect(v(' 1.0.0 '), v('1.0.0'));
      expect(v('1.0.0+42'), v('1.0.0'), reason: 'build metadata is ignored for precedence');
      expect(v('1.0.0+42').build, '42');
      expect(v('1.2.3-rc.1+7').toString(), '1.2.3-rc.1+7');
      expect(SemVer.tryParse('latest'), isNull);
      expect(SemVer.tryParse(''), isNull);
      expect(SemVer.tryParse('1.2.3.4'), isNull);
      expect(() => SemVer.parse('nope'), throwsFormatException);
    });

    test('pre-releases rank below their release, identifiers per SemVer 2.0', () {
      final order = ['1.0.0-alpha', '1.0.0-alpha.1', '1.0.0-alpha.beta', '1.0.0-beta', '1.0.0-beta.2', '1.0.0-beta.11', '1.0.0-rc.1', '1.0.0'];
      for (var i = 1; i < order.length; i++) {
        expect(v(order[i - 1]) < v(order[i]), isTrue, reason: '${order[i - 1]} < ${order[i]}');
        expect(v(order[i]) > v(order[i - 1]), isTrue);
      }
      expect(v('1.0.0-beta').isPreRelease, isTrue);
      expect(v('1.0.0').isPreRelease, isFalse);
    });
  });

  group('evaluate', () {
    final at = DateTime(2026, 10, 27);
    UpdateCheckResult run(String current, {PlatformInfo platform = linux, Map<String, Object?>? rel}) =>
        UpdateChecker.evaluate(rel ?? release(), currentVersion: current, platform: platform, checkedAt: at);

    test('newer release → updateAvailable with notes URL and metadata', () {
      final r = run('1.1.0');
      expect(r.status, UpdateStatus.updateAvailable);
      expect(r.updateAvailable, isTrue);
      expect(r.latestVersion, '1.2.0');
      expect(r.currentVersion, '1.1.0');
      expect(r.releaseName, 'Fermata v1.2.0');
      expect(r.releaseNotesUrl, Uri.parse('https://github.com/kjev0/dadasdasdasasdsad/releases/tag/v1.2.0'));
      expect(r.releaseNotes, contains('Faster start'));
      expect(r.publishedAt, DateTime.utc(2026, 10, 1, 12));
      expect(r.checkedAt, at);
    });

    test('same or older release → upToDate', () {
      expect(run('1.2.0').status, UpdateStatus.upToDate);
      expect(run('1.2.0+7').status, UpdateStatus.upToDate, reason: 'pubspec build number');
      expect(run('1.3.0').status, UpdateStatus.upToDate);
      expect(run('1.2.0').updateAvailable, isFalse);
    });

    test('a pre-release build is older than its final release', () {
      expect(run('1.2.0-beta.1').status, UpdateStatus.updateAvailable);
    });

    test('unparseable tags never claim an update', () {
      final r = run('1.0.0', rel: release(tag: 'nightly'));
      expect(r.status, UpdateStatus.upToDate);
      expect(r.latestVersion, 'nightly');
      expect(run('weird', rel: release()).status, UpdateStatus.upToDate);
    });

    test('assets are filtered per platform; checksums and source archives omitted', () {
      List<String> names(PlatformInfo p) => [for (final a in run('1.0.0', platform: p).assets) a.name];
      expect(names(linux), ['fermata-1.2.0-linux-x64.tar.gz', 'fermata-1.2.0-x86_64.AppImage']);
      expect(names(windows), ['fermata-1.2.0-windows-x64.zip', 'fermata-setup-1.2.0.exe']);
      expect(names(android), ['fermata-1.2.0-arm64-v8a.apk']);
      expect(names(const PlatformInfo(os: HostOs.other)), isEmpty);
      final a = run('1.0.0', platform: android).assets.single;
      expect(a.downloadUrl.toString(), endsWith('/download/v1.2.0/fermata-1.2.0-arm64-v8a.apk'));
      expect(a.sizeBytes, 30000000);
    });

    test('results survive a JSON round-trip', () {
      final r = run('1.0.0');
      final back = UpdateCheckResult.fromJson(jsonDecode(jsonEncode(r.toJson())))!;
      expect(back.status, r.status);
      expect(back.latestVersion, r.latestVersion);
      expect(back.releaseNotesUrl, r.releaseNotesUrl);
      expect(back.checkedAt, r.checkedAt);
      expect([for (final a in back.assets) a.name], [for (final a in r.assets) a.name]);
      expect(UpdateCheckResult.fromJson('nope'), isNull);
      expect(UpdateCheckResult.fromJson({'status': 'bogus'}), isNull);
    });
  });

  group('UpdateChecker', () {
    late Directory root;
    late AppPaths paths;
    late SettingsStore settings;
    late List<http.Request> requests;
    late http.Response Function(http.Request) respond;
    late DateTime now;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fermata_updates_');
      paths = AppPaths.forTesting(root);
      settings = SettingsStore.inMemory();
      requests = [];
      respond = (_) => ghJson(release());
      now = DateTime(2026, 10, 27, 9);
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    UpdateChecker checker({String version = '1.0.0', PlatformInfo platform = linux}) {
      final client = MockClient((request) async {
        requests.add(request);
        return respond(request);
      });
      return UpdateChecker(FermataHttp(client: client), settings, paths,
          platform: platform, currentVersion: () async => version, clock: () => now);
    }

    Future<void> optIn([bool on = true]) =>
        settings.update((s) => s.copyWith(updates: s.updates.copyWith(checkForUpdates: on)));

    test('is opt-in: disabled by default, nothing is requested or stored', () async {
      expect(settings.current.updates.checkForUpdates, isFalse);
      expect(await checker().checkIfDue(), isNull);
      expect(requests, isEmpty);
      expect(File('${paths.supportDir.path}/update_check.json').existsSync(), isFalse);
    });

    test('queries the project releases endpoint with identifying headers', () async {
      await optIn();
      final result = await checker().checkIfDue();
      expect(requests, hasLength(1));
      final r = requests.single;
      expect(r.method, 'GET');
      expect(r.url.toString(), 'https://api.github.com/repos/kjev0/dadasdasdasasdsad/releases/latest');
      expect(r.url, UpdateChecker.defaultEndpoint);
      expect(r.headers['User-Agent'], contains('Fermata'));
      expect(r.headers['Accept'], 'application/vnd.github+json');
      expect(r.headers.containsKey('If-None-Match'), isFalse);
      expect(result!.status, UpdateStatus.updateAvailable);
      expect(result.latestVersion, '1.2.0');
      expect([for (final a in result.assets) a.name], hasLength(2));
    });

    test('at most one automatic check per day, also across restarts', () async {
      await optIn();
      final first = checker();
      expect(await first.checkIfDue(), isNotNull);
      now = now.add(const Duration(hours: 23));
      expect(await first.checkIfDue(), isNull);
      expect(await checker().checkIfDue(), isNull, reason: 'a new instance reads update_check.json');
      expect(requests, hasLength(1));

      final restarted = checker();
      final last = await restarted.lastResult();
      expect(last!.latestVersion, '1.2.0');
      expect(last.updateAvailable, isTrue);

      now = now.add(const Duration(hours: 2));
      expect(await checker().checkIfDue(), isNotNull);
      expect(requests, hasLength(2));
    });

    test('a clock set back does not block checks forever', () async {
      await optIn();
      expect(await checker().checkIfDue(), isNotNull);
      now = now.subtract(const Duration(days: 3));
      expect(await checker().checkIfDue(), isNotNull);
    });

    test('revalidates with the ETag; 304 reuses the stored release', () async {
      await optIn();
      respond = (_) => ghJson(release(), headers: {'etag': 'W/"abc"'});
      await checker().checkIfDue();
      respond = (r) => http.Response('', 304);
      now = now.add(const Duration(days: 2));
      final again = await checker(version: '1.2.0').checkIfDue();
      expect(requests.last.headers['If-None-Match'], 'W/"abc"');
      expect(again!.status, UpdateStatus.upToDate);
      expect(again.latestVersion, '1.2.0');
    });

    test('no release published yet → noReleases', () async {
      await optIn();
      respond = (_) => ghJson({'message': 'Not Found'}, status: 404);
      final r = await checker().checkIfDue();
      expect(r!.status, UpdateStatus.noReleases);
      expect(r.updateAvailable, isFalse);
      expect(r.latestVersion, isNull);
    });

    test('network and API failures are swallowed by checkIfDue, typed for checkNow', () async {
      await optIn();
      respond = (_) => ghJson({'message': 'boom'}, status: 500);
      final c = checker();
      expect(await c.checkIfDue(), isNull);
      await expectLater(c.checkNow(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 500)));
    });

    test('GitHub rate limit → RateLimitedException with the reset time', () async {
      final reset = now.add(const Duration(minutes: 20));
      respond = (_) => ghJson({'message': 'API rate limit exceeded'}, status: 403, headers: {
            'x-ratelimit-remaining': '0',
            'x-ratelimit-reset': '${reset.millisecondsSinceEpoch ~/ 1000}',
          });
      await expectLater(
        checker().checkNow(),
        throwsA(isA<RateLimitedException>().having((e) => e.retryAfter, 'retryAfter', const Duration(minutes: 20))),
      );
      await optIn();
      expect(await checker().checkIfDue(), isNull);
    });

    test('checkNow (explicit button) ignores the daily limit', () async {
      await optIn();
      final c = checker();
      await c.checkIfDue();
      final r = await c.checkNow();
      expect(r.status, UpdateStatus.updateAvailable);
      expect(requests, hasLength(2));
    });

    test('switching the setting off stops automatic checks again', () async {
      await optIn();
      await checker().checkIfDue();
      await optIn(false);
      now = now.add(const Duration(days: 5));
      expect(await checker().checkIfDue(), isNull);
      expect(requests, hasLength(1));
    });

    test('a corrupt state file is ignored', () async {
      await optIn();
      File('${paths.supportDir.path}/update_check.json').writeAsStringSync('}{');
      expect(await checker().checkIfDue(), isNotNull);
    });

    test('never downloads assets', () async {
      await optIn();
      await checker().checkNow();
      expect(requests.every((r) => r.url.host == 'api.github.com'), isTrue);
    });
  });
}
