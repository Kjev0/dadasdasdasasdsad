import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../core/errors.dart';
import '../../core/net/http_client.dart';
import '../../core/util/cancel_token.dart';

final _log = Logger('discovery.lrclib');

/// One LRCLIB lyrics record (`/api/get`, `/api/search`).
class LrclibRecord {
  const LrclibRecord({
    required this.id,
    required this.trackName,
    required this.artistName,
    this.albumName,
    this.duration,
    this.instrumental = false,
    this.plainLyrics,
    this.syncedLyrics,
  });

  factory LrclibRecord.fromJson(Map<String, Object?> j) => LrclibRecord(
        id: (j['id'] as num?)?.toInt() ?? 0,
        trackName: j['trackName'] as String? ?? j['name'] as String? ?? '',
        artistName: j['artistName'] as String? ?? '',
        albumName: j['albumName'] as String?,
        duration: (j['duration'] as num?)?.toDouble(),
        instrumental: j['instrumental'] == true,
        plainLyrics: _nonBlank(j['plainLyrics']),
        syncedLyrics: _nonBlank(j['syncedLyrics']),
      );

  static String? _nonBlank(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

  final int id;
  final String trackName;
  final String artistName;
  final String? albumName;

  /// Seconds.
  final double? duration;
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyrics;

  bool get hasLyrics => plainLyrics != null || syncedLyrics != null;
}

/// Minimal LRCLIB API client (https://lrclib.net/docs).
///
/// * Identifies the app via `FermataHttp.userAgent` (name, version and
///   project URL as LRCLIB requires) and an optional public
///   `Lrclib-App-Id`.
/// * Requests are sequential with a small gap ([minRequestGap]) as the
///   docs ask for.
/// * 429 / 503 `Retry-After` is honoured (+ up to 30 % jitter): one retry
///   when the wait is short, otherwise all requests are suspended until
///   then and [RateLimitedException] is thrown.
class LrclibClient {
  LrclibClient(
    this._http, {
    Uri? baseUri,
    this.appId,
    this.minRequestGap = const Duration(milliseconds: 250),
    this.maxInlineWait = const Duration(seconds: 5),
    DateTime Function()? clock,
    Future<void> Function(Duration delay)? sleep,
    math.Random? random,
  })  : baseUri = baseUri ?? defaultBaseUri,
        _clock = clock ?? DateTime.now,
        _sleep = sleep ?? ((d) => Future<void>.delayed(d)),
        _random = random ?? math.Random();

  static final defaultBaseUri = Uri.parse('https://lrclib.net/');

  /// LRCLIB `/api/get` only matches within this duration difference.
  static const getDurationTolerance = Duration(seconds: 2);

  final FermataHttp _http;
  final Uri baseUri;

  /// Optional public client id from lrclib.net/developers (safe to ship).
  final String? appId;
  final Duration minRequestGap;

  /// Longest `Retry-After` waited for inline before giving up.
  final Duration maxInlineWait;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _sleep;
  final math.Random _random;

  Future<void> _queue = Future.value();
  DateTime? _lastRequest;
  DateTime? _blockedUntil;

  /// When requests are suspended because of `Retry-After`.
  DateTime? get blockedUntil => _blockedUntil;

  Uri getUri({required String trackName, required String artistName, String? albumName, int? durationSeconds}) =>
      baseUri.resolve('api/get').replace(queryParameters: {
        'track_name': trackName,
        'artist_name': artistName,
        if (albumName != null && albumName.trim().isNotEmpty) 'album_name': albumName,
        if (durationSeconds != null) 'duration': '$durationSeconds',
      });

  Uri searchUri({required String trackName, String? artistName, String? albumName}) =>
      baseUri.resolve('api/search').replace(queryParameters: {
        'track_name': trackName,
        if (artistName != null && artistName.trim().isNotEmpty) 'artist_name': artistName,
        if (albumName != null && albumName.trim().isNotEmpty) 'album_name': albumName,
      });

  /// Exact lookup (`/api/get`); null when LRCLIB has no such track
  /// (404 `TrackNotFound`).
  Future<LrclibRecord?> get({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    CancelToken? cancel,
  }) async {
    final json = await _request(
      getUri(trackName: trackName, artistName: artistName, albumName: albumName, durationSeconds: durationSeconds),
      cancel: cancel,
    );
    if (json == null) return null;
    if (json is! Map) throw const ApiException(200, 'Unexpected LRCLIB response');
    return LrclibRecord.fromJson(json.cast<String, Object?>());
  }

  /// Fuzzy search (`/api/search`, at most 20 results, no pagination).
  Future<List<LrclibRecord>> search({
    required String trackName,
    String? artistName,
    String? albumName,
    CancelToken? cancel,
  }) async {
    final json = await _request(searchUri(trackName: trackName, artistName: artistName, albumName: albumName),
        cancel: cancel);
    if (json == null) return const [];
    if (json is! List) throw const ApiException(200, 'Unexpected LRCLIB search response');
    return [
      for (final r in json)
        if (r is Map) LrclibRecord.fromJson(r.cast<String, Object?>()),
    ];
  }

  /// Serialized request; returns decoded JSON, or null for 404.
  Future<Object?> _request(Uri uri, {CancelToken? cancel}) {
    final completer = Completer<Object?>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await _send(uri, cancel));
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<Object?> _send(Uri uri, CancelToken? cancel) async {
    for (var attempt = 1;; attempt++) {
      cancel?.throwIfCanceled();
      final blocked = _blockedUntil;
      if (blocked != null && _clock().isBefore(blocked)) {
        throw RateLimitedException('LRCLIB asked us to wait', retryAfter: blocked.difference(_clock()));
      }
      final last = _lastRequest;
      if (last != null) {
        final wait = minRequestGap - _clock().difference(last);
        if (wait > Duration.zero) await _sleep(wait);
      }
      cancel?.throwIfCanceled();
      _lastRequest = _clock();
      http.Response response;
      Duration? retryAfter;
      try {
        response = await _http.send('GET', uri,
            headers: {'Accept': 'application/json', 'Lrclib-App-Id': ?appId},
            retry: RetryPolicy.none,
            cancel: cancel);
      } on RateLimitedException catch (e) {
        retryAfter = e.retryAfter ?? const Duration(seconds: 30);
        if (!await _backoff(retryAfter, attempt)) rethrow;
        continue;
      }
      final status = response.statusCode;
      if (status == 404) return null;
      if (status == 503 || status == 429) {
        retryAfter = _parseRetryAfter(response.headers['retry-after']) ?? const Duration(seconds: 10);
        if (await _backoff(retryAfter, attempt)) continue;
        throw RateLimitedException('LRCLIB is overloaded (HTTP $status)', retryAfter: retryAfter);
      }
      if (status < 200 || status >= 300) {
        throw ApiException(status, 'HTTP $status from LRCLIB', body: _truncate(response.body));
      }
      final type = response.headers['content-type'] ?? '';
      if (!type.contains('json')) {
        throw ApiException(status, 'LRCLIB returned $type instead of JSON', body: _truncate(response.body));
      }
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException catch (e) {
        throw ApiException(status, 'Invalid JSON from LRCLIB', cause: e);
      }
    }
  }

  /// Waits out a short `Retry-After` once (with jitter). Longer waits
  /// suspend the client until then. Returns whether to retry now.
  Future<bool> _backoff(Duration retryAfter, int attempt) async {
    final jittered = retryAfter * (1 + _random.nextDouble() * 0.3);
    if (attempt == 1 && retryAfter <= maxInlineWait) {
      _log.fine('LRCLIB Retry-After ${retryAfter.inMilliseconds} ms, retrying once');
      await _sleep(jittered);
      return true;
    }
    _blockedUntil = _clock().add(jittered);
    _log.info('LRCLIB rate limit: pausing lyrics requests for ${jittered.inSeconds} s');
    return false;
  }

  static Duration? _parseRetryAfter(String? value) {
    final seconds = int.tryParse(value?.trim() ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static String _truncate(String s) => s.length > 500 ? s.substring(0, 500) : s;
}
