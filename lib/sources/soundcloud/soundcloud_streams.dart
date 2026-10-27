import 'package:logging/logging.dart';

import '../../core/errors.dart';
import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import '../../core/util/cancel_token.dart';
import '../base/json_utils.dart';
import 'soundcloud_api.dart';
import 'soundcloud_rate_limits.dart';

final _log = Logger('sources.soundcloud.streams');

/// The stream variant chosen from a `Streams` object.
class SoundCloudStreamChoice {
  const SoundCloudStreamChoice(this.field, this.url);

  /// The `Streams` field, e.g. `hls_aac_160_url`.
  final String field;
  final Uri url;

  bool get isHls => field.startsWith('hls_');

  String get mimeType => isHls ? 'application/vnd.apple.mpegurl' : 'audio/mpeg';
}

/// Resolves SoundCloud streams via `GET /tracks/{urn}/streams` and caches the
/// resolved (signed) URLs for their lifetime, so replaying or seeking back
/// does not spend another of the ~1,500 daily play requests.
///
/// Format choice (Streams schema + SoundCloud's 2025/2026 streaming
/// migration: AAC HLS preferred, progressive `http_mp3_128_url` removed in
/// Aug 2026, Opus not supported via HLS): AAC 160 → AAC 96 → MP3 128 HLS →
/// progressive MP3 (only if an old response still has it). `low` quality
/// prefers AAC 96. Preview playback uses `preview_mp3_128_url` only. Both
/// media_kit (libmpv) and ExoPlayer play HLS.
///
/// Audio is never written to disk here — the API terms allow session
/// caching only and the cache holds URLs, not audio.
class SoundCloudStreams {
  SoundCloudStreams(this._api, {DateTime Function()? clock, this.fallbackTtl = const Duration(minutes: 10)})
    : _clock = clock ?? DateTime.now;

  final SoundCloudApi _api;
  final DateTime Function() _clock;

  /// Lifetime assumed for a resolved URL without an `Expires` parameter.
  final Duration fallbackTtl;

  static const _maxEntries = 64;
  static const _safety = Duration(seconds: 30);
  final Map<String, PlayableSource> _cache = {};

  static const _full = ['hls_aac_160_url', 'hls_aac_96_url', 'hls_mp3_128_url', 'http_mp3_128_url'];
  static const _low = ['hls_aac_96_url', 'hls_mp3_128_url', 'hls_aac_160_url', 'http_mp3_128_url'];
  static const _preview = ['preview_mp3_128_url'];

  /// Picks the best available variant (see class docs); null when none.
  static SoundCloudStreamChoice? pick(
    Map<String, Object?> streams, {
    required bool preview,
    required AudioQuality quality,
  }) {
    final order = preview ? _preview : (quality == AudioQuality.low ? _low : _full);
    for (final field in order) {
      final url = jsonHttpUri(streams[field]);
      if (url != null) return SoundCloudStreamChoice(field, url);
    }
    return null;
  }

  /// Number of cached, still valid stream URLs (diagnostics/tests).
  int get cachedCount {
    _evictExpired();
    return _cache.length;
  }

  /// Drops all cached URLs (credentials changed, account switched).
  void clear() => _cache.clear();

  /// A playable source for the track [urn]. Throws
  /// [UnplayableTrackException] (deleted / region restricted / not
  /// streamable) or [RateLimitedException].
  Future<PlayableSource> resolve(
    Track track,
    String urn, {
    required bool preview,
    required AudioQuality quality,
    String? secretToken,
    CancelToken? cancel,
  }) async {
    final key = '$urn|${preview ? 'preview' : (quality == AudioQuality.low ? 'low' : 'full')}';
    _evictExpired();
    final cached = _cache[key];
    if (cached != null) return cached;

    final Object? json;
    try {
      json = await _api.getJson(
        _api.uri('tracks/${SoundCloudApi.seg(urn)}/streams', {'secret_token': secretToken}),
        group: SoundCloudRateGroup.streams,
        cancel: cancel,
      );
    } on ApiException catch (e) {
      throw _unplayable(track, e);
    }
    final choice = pick(asJsonMap(json), preview: preview, quality: quality);
    if (choice == null) {
      throw UnplayableTrackException(
        track.id,
        preview ? AvailabilityReason.previewOnly : AvailabilityReason.notStreamable,
        message: 'SoundCloud returned no usable stream for ${track.id}',
      );
    }
    final SoundCloudSignedStream signed;
    try {
      signed = await _api.signStream(choice.url, cancel: cancel);
    } on ApiException catch (e) {
      throw _unplayable(track, e);
    }
    final source = PlayableSource(
      uri: signed.uri,
      headers: signed.headers,
      isPreview: preview,
      expiresAt: signed.expiresAt ?? _clock().add(fallbackTtl),
      mimeType: choice.mimeType,
    );
    _log.fine('Resolved ${track.id} via ${choice.field}');
    if (_cache.length >= _maxEntries) _cache.remove(_cache.keys.first);
    _cache[key] = source;
    return source;
  }

  FermataException _unplayable(Track track, ApiException e) => switch (e.statusCode) {
    404 => UnplayableTrackException(track.id, AvailabilityReason.deleted),
    // `/streams` errors for blocked tracks (creator restriction, paywall or
    // geo-block); private tracks without a valid secret token also land here.
    403 => UnplayableTrackException(track.id, AvailabilityReason.regionRestricted),
    _ => e,
  };

  void _evictExpired() {
    final now = _clock();
    _cache.removeWhere((_, s) => s.expiresAt != null && !now.isBefore(s.expiresAt!.subtract(_safety)));
  }
}
