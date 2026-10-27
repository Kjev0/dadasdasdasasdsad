/// Parses YouTube / YouTube Music links and ids.
///
/// * Videos: `youtube.com/watch?v=<id>`, `music.youtube.com/watch?v=<id>`,
///   `youtu.be/<id>`, `/shorts/<id>`, `/embed/<id>`, `/live/<id>`, or a bare
///   11-character id.
/// * Playlists: `…/playlist?list=<id>`, `watch?v=…&list=<id>`,
///   `music.youtube.com/browse/VL<id>`, or a bare playlist id (`PL…`,
///   `OLAK5uy_…` album playlists, `UU…`, `LL`, …).
abstract final class YouTubeLinks {
  static final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');
  static final _playlistId = RegExp(r'^[A-Za-z0-9_-]{13,64}$');
  static const _hosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
  };

  static Uri? _toUri(String input) {
    final s = input.trim();
    if (s.isEmpty || s.contains(' ')) return null;
    final uri = Uri.tryParse(s.contains('://') ? s : 'https://$s');
    if (uri == null || !_hosts.contains(uri.host.toLowerCase())) return null;
    return uri;
  }

  static bool isVideoId(String s) => _videoId.hasMatch(s.trim());

  /// Bare playlist ids are 13+ characters (or the special `LL` likes list);
  /// 11-character strings are video ids.
  static bool isPlaylistId(String s) {
    final t = s.trim();
    return t == 'LL' || (_playlistId.hasMatch(t) && !_videoId.hasMatch(t));
  }

  /// Whether [input] is a YouTube or YouTube Music URL.
  static bool isYouTubeUrl(String input) => _toUri(input) != null;

  /// The video id in [input], or null.
  static String? videoId(String input) {
    final s = input.trim();
    if (isVideoId(s) && !s.contains('/')) return s;
    final uri = _toUri(s);
    if (uri == null) return null;
    String? candidate;
    if (uri.host.toLowerCase() == 'youtu.be') {
      candidate = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (uri.path == '/watch') {
      candidate = uri.queryParameters['v'];
    } else if (uri.pathSegments.length >= 2 && const {'shorts', 'embed', 'live', 'v'}.contains(uri.pathSegments[0])) {
      candidate = uri.pathSegments[1];
    }
    return candidate != null && isVideoId(candidate) ? candidate : null;
  }

  /// The playlist id in [input], or null.
  static String? playlistId(String input) {
    final s = input.trim();
    if (!s.contains('/') && !s.contains('?') && isPlaylistId(s)) return s;
    final uri = _toUri(s);
    if (uri == null) return null;
    final list = uri.queryParameters['list'];
    if (list != null && (isPlaylistId(list) || list.startsWith('RD'))) return list;
    // music.youtube.com/browse/VL<playlistId>
    if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'browse' && uri.pathSegments[1].startsWith('VL')) {
      final id = uri.pathSegments[1].substring(2);
      if (isPlaylistId(id)) return id;
    }
    return null;
  }

  /// "Open in YouTube Music" for a video.
  static Uri musicWatchUrl(String videoId) => Uri.parse('https://music.youtube.com/watch?v=$videoId');

  /// Attribution link to the video on youtube.com.
  static Uri watchUrl(String videoId) => Uri.parse('https://www.youtube.com/watch?v=$videoId');

  static Uri playlistUrl(String playlistId) => Uri.parse('https://music.youtube.com/playlist?list=$playlistId');
}
