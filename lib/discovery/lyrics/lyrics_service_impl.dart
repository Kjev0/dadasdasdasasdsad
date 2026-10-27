import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../core/contracts/discovery.dart';
import '../../core/models/track.dart';
import '../../core/net/http_client.dart';
import '../../core/platform/app_paths.dart';
import '../../core/util/cancel_token.dart';
import '../../settings/settings_store.dart';
import '../util/text_keys.dart';
import 'embedded_lyrics.dart';
import 'lrc_parser.dart';
import 'lrclib_client.dart';
import 'lyrics_cache.dart';

final _log = Logger('discovery.lyrics');

/// Attribution strings for [Lyrics.provider].
abstract final class LyricsProviders {
  static const lrclib = 'LRCLIB';

  /// Lyrics tag inside the user's own audio file.
  static const embedded = 'Embedded';

  /// A `.lrc` file next to the user's audio file.
  static const lrcFile = 'LRC file';

  static final lrclibHomepage = Uri.parse('https://lrclib.net');
}

/// Lyrics from permitted sources only:
///
/// 1. local files: a sidecar `.lrc`, then the file's embedded lyrics tag;
/// 2. LRCLIB (`/api/get` by title/artist/album/duration, falling back to
///    `/api/search` and choosing by duration), cached on disk per track
///    for 30 days (misses for 3 days).
///
/// Does nothing at all — no file reads, no network — while
/// `playback.lyricsEnabled` is off.
class LyricsServiceImpl implements LyricsService {
  LyricsServiceImpl(
    FermataHttp http,
    SettingsStore settings,
    AppPaths paths, {
    LrclibClient? client,
    EmbeddedLyricsReader? embeddedReader,
    DateTime Function()? clock,
    bool diskCache = true,
    this.searchDurationTolerance = const Duration(seconds: 3),
    this.memoryEntries = 64,
  })  : _settings = settings,
        _client = client ?? LrclibClient(http, clock: clock),
        _embedded = embeddedReader ?? readEmbeddedLyrics,
        _cache = LyricsCache(diskCache ? Directory(p.join(paths.cacheDir.path, 'lyrics')) : null, clock: clock);

  final SettingsStore _settings;
  final LrclibClient _client;
  final EmbeddedLyricsReader _embedded;
  final LyricsCache _cache;

  /// Max duration difference when choosing among `/api/search` results.
  final Duration searchDurationTolerance;
  final int memoryEntries;

  /// Insertion-ordered (Dart map literals are linked hash maps) → LRU.
  final Map<String, Lyrics?> _memory = {};

  LrclibClient get client => _client;

  LyricsCache get cache => _cache;

  @override
  Future<Lyrics?> lyricsFor(Track track, {CancelToken? cancel}) async {
    if (!_settings.current.playback.lyricsEnabled) return null;
    cancel?.throwIfCanceled();
    if (_memory.containsKey(track.id)) {
      final hit = _memory.remove(track.id);
      _memory[track.id] = hit; // LRU touch
      return hit;
    }
    final local = await _fromLocalFile(track);
    cancel?.throwIfCanceled();
    if (local != null) return _remember(track.id, local);

    final cached = await _cache.read(track.id);
    cancel?.throwIfCanceled();
    if (cached != null) return _remember(track.id, cached.lyrics);

    final lyrics = await _fromLrclib(track, cancel);
    await _cache.write(track.id, lyrics);
    return _remember(track.id, lyrics);
  }

  Lyrics? _remember(String id, Lyrics? lyrics) {
    _memory[id] = lyrics;
    while (_memory.length > memoryEntries) {
      _memory.remove(_memory.keys.first);
    }
    return lyrics;
  }

  /// Forgets cached lyrics (memory + disk).
  Future<void> clearCache() async {
    _memory.clear();
    await _cache.clear();
  }

  // ---- Local files -------------------------------------------------------------

  Future<Lyrics?> _fromLocalFile(Track track) async {
    final path = track.localPath;
    if (path == null || path.isEmpty) return null;
    try {
      final sidecar = await readSidecarLrc(path);
      if (sidecar != null) {
        final l = fromText(sidecar, provider: LyricsProviders.lrcFile);
        if (l != null) return l;
      }
      final embedded = await _embedded(path);
      if (embedded != null) return fromText(embedded, provider: LyricsProviders.embedded);
    } catch (e) {
      _log.fine('Reading local lyrics failed for ${track.id}', e);
    }
    return null;
  }

  /// LRC text → synced lyrics, anything else → plain lyrics.
  static Lyrics? fromText(String text, {required String provider, Uri? sourceUrl}) {
    if (text.trim().isEmpty) return null;
    if (LrcParser.looksLikeLrc(text)) {
      final parsed = LrcParser.parse(text);
      if (parsed.isSynced) {
        return Lyrics(plain: parsed.plainText, synced: parsed.lines, provider: provider, sourceUrl: sourceUrl);
      }
    }
    return Lyrics(plain: text.trim(), provider: provider, sourceUrl: sourceUrl);
  }

  // ---- LRCLIB ------------------------------------------------------------------

  Future<Lyrics?> _fromLrclib(Track track, CancelToken? cancel) async {
    final title = TextKeys.stripNoise(track.title);
    final artist = track.primaryArtist.trim();
    if (title.isEmpty || artist.isEmpty) return null;
    final seconds = durationSeconds(track.duration);
    if (seconds != null) {
      final record = await _client.get(
        trackName: title,
        artistName: artist,
        albumName: track.album,
        durationSeconds: seconds,
        cancel: cancel,
      );
      if (record != null && (record.hasLyrics || record.instrumental)) return toLyrics(record);
    }
    final results = await _client.search(trackName: title, artistName: artist, cancel: cancel);
    final best = pickBest(results, track, tolerance: searchDurationTolerance);
    return best == null ? null : toLyrics(best);
  }

  /// LRCLIB accepts whole seconds in 1..3600.
  static int? durationSeconds(Duration? d) {
    if (d == null) return null;
    final s = (d.inMilliseconds / 1000).round();
    return s >= 1 && s <= 3600 ? s : null;
  }

  /// Best `/api/search` record for [track]: same title and artist, with
  /// lyrics (or instrumental), and — when the track's duration is known —
  /// within [tolerance] of it. Closest duration wins, then synced lyrics,
  /// then a matching album.
  static LrclibRecord? pickBest(List<LrclibRecord> records, Track track, {Duration tolerance = const Duration(seconds: 3)}) {
    final title = TextKeys.title(track.title);
    final artist = TextKeys.artist(track.primaryArtist);
    final album = track.album == null ? null : TextKeys.title(track.album!);
    final target = track.duration == null || track.duration! <= Duration.zero ? null : track.duration!.inMilliseconds / 1000;
    final scored = <(double, int, int, int, LrclibRecord)>[];
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      if (!r.hasLyrics && !r.instrumental) continue;
      if (!TextKeys.looselyEqual(TextKeys.title(r.trackName), title)) continue;
      if (!TextKeys.looselyEqual(TextKeys.artist(r.artistName), artist)) continue;
      var diff = 0.0;
      if (target != null) {
        if (r.duration == null) continue;
        diff = (r.duration! - target).abs();
        if (diff > tolerance.inMilliseconds / 1000) continue;
      }
      final synced = r.syncedLyrics != null ? 0 : 1;
      final albumMatch = album != null && r.albumName != null && TextKeys.title(r.albumName!) == album ? 0 : 1;
      scored.add(((diff * 2).roundToDouble() / 2, synced, albumMatch, i, r));
    }
    if (scored.isEmpty) return null;
    scored.sort((a, b) {
      for (final c in [a.$1.compareTo(b.$1), a.$2.compareTo(b.$2), a.$3.compareTo(b.$3), a.$4.compareTo(b.$4)]) {
        if (c != 0) return c;
      }
      return 0;
    });
    return scored.first.$5;
  }

  /// Maps a record to [Lyrics] (attribution "LRCLIB").
  static Lyrics? toLyrics(LrclibRecord r) {
    if (r.instrumental) {
      return Lyrics(instrumental: true, provider: LyricsProviders.lrclib, sourceUrl: LyricsProviders.lrclibHomepage);
    }
    final synced = r.syncedLyrics == null ? null : LrcParser.parse(r.syncedLyrics!);
    final plain = r.plainLyrics?.trim() ?? synced?.plainText;
    if ((synced == null || !synced.isSynced) && (plain == null || plain.isEmpty)) return null;
    return Lyrics(
      plain: plain,
      synced: synced?.lines ?? const [],
      provider: LyricsProviders.lrclib,
      sourceUrl: LyricsProviders.lrclibHomepage,
    );
  }
}
