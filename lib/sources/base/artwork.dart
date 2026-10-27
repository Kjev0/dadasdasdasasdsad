/// Picks the best image URL for a requested display size.
///
/// Providers return artwork in a few fixed sizes (Audius `150x150` /
/// `480x480` / `1000x1000`, Deezer `cover_small` 56 / `cover_medium` 250 /
/// `cover_big` 500 / `cover_xl` 1000, SoundCloud `-large` 100 / `-t500x500`).
/// Sources map them to pixel sizes and let [ArtworkSizing.pick] choose.
abstract final class ArtworkSizing {
  /// Thumbnail in lists.
  static const int thumbnail = 150;

  /// Default for [Track.artworkUrl] — sharp on cards and the mini player.
  static const int standard = 500;

  /// Now-playing / full-screen artwork.
  static const int large = 1000;

  /// Returns the smallest candidate whose size is at least [targetPx]
  /// (sizes within 10 % below the target count, so Audius' 480 px serves a
  /// 500 px request); falls back to the largest available. Null/empty URLs
  /// are ignored.
  static Uri? pick(Map<int, Object?> candidates, {int targetPx = standard}) {
    final valid = <int, Uri>{};
    candidates.forEach((size, raw) {
      final uri = _uri(raw);
      if (uri != null) valid[size] = uri;
    });
    if (valid.isEmpty) return null;
    final sizes = valid.keys.toList()..sort();
    final threshold = targetPx * 0.9;
    for (final s in sizes) {
      if (s >= threshold) return valid[s];
    }
    return valid[sizes.last];
  }

  /// Parses square size keys such as `480x480` or `2000x` → 480 / 2000.
  static int? parseSizeKey(String key) {
    final m = RegExp(r'^(\d+)x(\d*)$').firstMatch(key.trim());
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// Picks from a map keyed by `WxH` strings (Audius-style artwork maps).
  /// Non-size keys (e.g. `mirrors`) are ignored.
  static Uri? pickFromSizeKeyedMap(Map<String, Object?> map, {int targetPx = standard}) {
    final candidates = <int, Object?>{};
    map.forEach((key, value) {
      final size = parseSizeKey(key);
      if (size != null) candidates[size] = value;
    });
    return pick(candidates, targetPx: targetPx);
  }

  /// Replaces a size token inside a URL (e.g. SoundCloud `-large.jpg` →
  /// `-t500x500.jpg`). Returns [url] unchanged when [from] does not occur.
  static Uri replaceSizeToken(Uri url, String from, String to) {
    final s = url.toString();
    final i = s.lastIndexOf(from);
    if (i < 0) return url;
    return Uri.parse(s.replaceRange(i, i + from.length, to));
  }

  static Uri? _uri(Object? raw) {
    if (raw is Uri) return raw;
    if (raw is! String || raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return null;
    return uri;
  }
}
