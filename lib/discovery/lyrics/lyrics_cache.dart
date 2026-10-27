import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../core/contracts/discovery.dart';

final _log = Logger('discovery.lyrics.cache');

/// A cached lookup: [lyrics] is null for "LRCLIB has nothing" (negative
/// entries expire sooner so lyrics added later are picked up).
class CachedLyrics {
  const CachedLyrics(this.lyrics, this.fetchedAt);

  final Lyrics? lyrics;
  final DateTime fetchedAt;
}

/// On-disk lyrics cache: one small JSON file per track id under
/// `<cacheDir>/lyrics/` (file name = SHA-1 of the track id, so any id is a
/// valid file name on every platform).
class LyricsCache {
  LyricsCache(this.directory, {DateTime Function()? clock, this.ttl = const Duration(days: 30), this.notFoundTtl = const Duration(days: 3)})
      : _clock = clock ?? DateTime.now;

  /// Null = disabled (memory only in the service).
  final Directory? directory;
  final Duration ttl;
  final Duration notFoundTtl;
  final DateTime Function() _clock;

  static const _version = 1;

  File? fileFor(String trackId) {
    final dir = directory;
    if (dir == null) return null;
    return File(p.join(dir.path, '${sha1.convert(utf8.encode(trackId))}.json'));
  }

  /// A fresh entry for [trackId], or null (missing, expired or unreadable).
  Future<CachedLyrics?> read(String trackId) async {
    final f = fileFor(trackId);
    if (f == null) return null;
    try {
      if (!await f.exists()) return null;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map || raw['v'] != _version || raw['trackId'] != trackId) return null;
      final fetchedAt = DateTime.tryParse(raw['fetchedAt'] as String? ?? '');
      if (fetchedAt == null) return null;
      final lyricsJson = raw['lyrics'];
      final lyrics = lyricsJson is Map ? decode(lyricsJson.cast<String, Object?>()) : null;
      final age = _clock().difference(fetchedAt);
      if (age > (lyrics == null ? notFoundTtl : ttl) || age.isNegative) return null;
      return CachedLyrics(lyrics, fetchedAt);
    } catch (e) {
      _log.fine('Ignoring unreadable lyrics cache for $trackId', e);
      return null;
    }
  }

  Future<void> write(String trackId, Lyrics? lyrics) async {
    final f = fileFor(trackId);
    if (f == null) return;
    try {
      await f.parent.create(recursive: true);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'v': _version,
        'trackId': trackId,
        'fetchedAt': _clock().toIso8601String(),
        'lyrics': lyrics == null ? null : encode(lyrics),
      }));
      await tmp.rename(f.path);
    } catch (e) {
      _log.warning('Could not write lyrics cache', e);
    }
  }

  /// Removes entries older than [ttl] (housekeeping; optional).
  Future<int> prune() async {
    final dir = directory;
    if (dir == null || !await dir.exists()) return 0;
    var removed = 0;
    final cutoff = _clock().subtract(ttl);
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.json')) {
        try {
          if ((await e.lastModified()).isBefore(cutoff)) {
            await e.delete();
            removed++;
          }
        } on FileSystemException {
          // Ignore races with concurrent writers.
        }
      }
    }
    return removed;
  }

  Future<void> clear() async {
    final dir = directory;
    if (dir != null && await dir.exists()) await dir.delete(recursive: true);
  }

  static Map<String, Object?> encode(Lyrics l) => {
        if (l.plain != null) 'plain': l.plain,
        if (l.synced.isNotEmpty) 'synced': [for (final s in l.synced) [s.time.inMilliseconds, s.text]],
        if (l.instrumental) 'instrumental': true,
        'provider': l.provider,
        if (l.sourceUrl != null) 'url': l.sourceUrl.toString(),
      };

  static Lyrics decode(Map<String, Object?> j) => Lyrics(
        plain: j['plain'] as String?,
        synced: [
          for (final s in (j['synced'] as List? ?? const []))
            LyricsLine(Duration(milliseconds: ((s as List)[0] as num).toInt()), s[1] as String),
        ],
        instrumental: j['instrumental'] == true,
        provider: j['provider'] as String? ?? '',
        sourceUrl: j['url'] == null ? null : Uri.tryParse(j['url'] as String),
      );
}
