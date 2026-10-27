// Adversarial review tests for DeezerSource / shared JSON helpers.
// Each test demonstrates a defect; they are expected to FAIL until fixed.
import 'dart:async';

import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/sources/base/json_utils.dart';
import 'package:fermata/sources/base/rate_limiter.dart';
import 'package:fermata/sources/deezer/deezer_mapper.dart';
import 'package:fermata/sources/deezer/deezer_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'helpers.dart';

Future<http.Response> _route(http.Request r) async {
  const routes = {
    '/album/302127': 'deezer_album.json',
    '/album/302127/tracks': 'deezer_album_tracks.json',
  };
  return jsonResponse(fixture(routes[r.url.path] ?? 'deezer_error_not_found.json'));
}

void main() {
  test('album metadata cache must not hand one caller\'s cancellation to another caller', () async {
    final gate = Completer<void>();
    final net = RecordingHttp((r) async {
      if (r.url.path == '/album/302127') await gate.future; // album request still in flight
      return _route(r);
    });
    final source = DeezerSource(
      http: net.fermata,
      limiter: TokenBucketRateLimiter(capacity: 50, period: const Duration(seconds: 5)),
    );
    addTearDown(source.dispose);

    // Album page opened, then the user navigates away (its CancelToken
    // fires) while a second view of the same album (e.g. the now-playing
    // "from album" panel, or the user coming straight back) loads.
    final firstCancel = CancelToken();
    final first = source.albumTracks('302127', cancel: firstCancel);
    final firstDone = first.then<Object?>((p) => p, onError: (Object e) => e);
    await pumpEventQueue();
    final second = source.albumTracks('302127'); // no cancellation at all
    final secondDone = second.then<Object?>((p) => p, onError: (Object e) => e);
    await pumpEventQueue();
    firstCancel.cancel();
    gate.complete();

    await firstDone;
    final result = await secondDone;
    // BUG: _MetaCache stores the in-flight Future created with the FIRST
    // caller's CancelToken; the second caller awaits that same Future and
    // fails with OperationCanceledException although it never cancelled.
    expect(
      result,
      isNot(isA<Exception>()),
      reason: 'second, uncancelled albumTracks() failed with $result',
    );
  });

  test('Deezer "0000-00-00" release dates must not become year -1', () {
    // Deezer uses MySQL-style zero dates for unknown release dates.
    expect(jsonYear('0000-00-00'), isNull, reason: 'jsonYear gave ${jsonYear('0000-00-00')}');
    final track = DeezerMapper.track({
      'id': 1,
      'title': 'Untitled',
      'release_date': '0000-00-00',
      'album': {'id': 2, 'title': 'A', 'release_date': '0000-00-00'},
    });
    // BUG: jsonYear() trusts DateTime.tryParse, which normalises month 0 /
    // day 0 to -0001-11-30, so the track gets year -1 (shown in the UI,
    // written to the library and used by the matching engine).
    expect(track!.year, isNull);
  });
}
