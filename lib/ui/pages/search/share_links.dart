import 'package:flutter/foundation.dart';

import '../../../core/sources/source_ids.dart';

/// What a pasted provider link points to.
enum ShareLinkKind { track, playlist, album, artist, unknown }

/// A provider share link recognised in the search field.
///
/// [id] is the provider id when the URL contains one (Spotify, Deezer,
/// YouTube, Jamendo), otherwise the normalised URL itself — SoundCloud,
/// Audius and short links are resolved by the source (`getTrack` /
/// `getPlaylist` accept share URLs).
@immutable
class ShareLink {
  const ShareLink({required this.sourceId, required this.kind, required this.id, required this.uri});

  final String sourceId;
  final ShareLinkKind kind;
  final String id;
  final Uri uri;

  /// Whether [id] is a URL rather than a provider id.
  bool get idIsUrl => id.startsWith('http');

  @override
  bool operator ==(Object other) =>
      other is ShareLink && other.sourceId == sourceId && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(sourceId, kind, id);

  @override
  String toString() => 'ShareLink($sourceId, ${kind.name}, $id)';

  /// Parses [input] (a pasted URL or `spotify:` URI). Returns null for
  /// ordinary search text and for unsupported hosts.
  static ShareLink? parse(String input) {
    final text = input.trim();
    if (text.isEmpty || text.contains(' ')) return null;
    if (text.startsWith('spotify:')) return _spotifyUri(text);
    final hasScheme = text.startsWith('http://') || text.startsWith('https://');
    if (!hasScheme && !_knownHostPrefix.hasMatch(text)) return null;
    final uri = Uri.tryParse(hasScheme ? text : 'https://$text');
    if (uri == null || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www|m)\.'), '');
    final segs = [for (final s in uri.pathSegments) if (s.isNotEmpty) s];
    final clean = uri.removeFragment().replace(scheme: 'https');
    switch (host) {
      case 'open.spotify.com' || 'play.spotify.com':
        return _spotify(segs, clean);
      case 'spotify.link':
        return ShareLink(sourceId: SourceIds.spotify, kind: ShareLinkKind.unknown, id: clean.toString(), uri: clean);
      case 'deezer.com':
        return _deezer(segs, clean);
      case 'link.deezer.com' || 'deezer.page.link':
        return ShareLink(sourceId: SourceIds.deezer, kind: ShareLinkKind.unknown, id: clean.toString(), uri: clean);
      case 'soundcloud.com':
        return _soundcloud(segs, clean);
      case 'on.soundcloud.com':
        return ShareLink(sourceId: SourceIds.soundcloud, kind: ShareLinkKind.unknown, id: clean.toString(), uri: clean);
      case 'youtube.com' || 'music.youtube.com' || 'youtu.be':
        return _youtube(host, segs, uri, clean);
      case 'audius.co':
        return _audius(segs, clean);
      case 'jamendo.com':
        return _jamendo(segs, clean);
      default:
        return null;
    }
  }

  static final _knownHostPrefix = RegExp(
    r'^(www\.|m\.)?(open\.spotify\.com|spotify\.link|deezer\.com|link\.deezer\.com|soundcloud\.com|on\.soundcloud\.com|'
    r'youtube\.com|music\.youtube\.com|youtu\.be|audius\.co|jamendo\.com)/',
    caseSensitive: false,
  );

  static const _kinds = {
    'track': ShareLinkKind.track,
    'playlist': ShareLinkKind.playlist,
    'album': ShareLinkKind.album,
    'artist': ShareLinkKind.artist,
  };

  static ShareLink? _spotifyUri(String text) {
    final parts = text.split(':');
    if (parts.length < 3) return null;
    final kind = _kinds[parts[1]];
    final id = parts.last;
    if (kind == null || id.isEmpty) return null;
    final uri = Uri.parse('https://open.spotify.com/${parts[1]}/$id');
    return ShareLink(sourceId: SourceIds.spotify, kind: kind, id: id, uri: uri);
  }

  static ShareLink? _spotify(List<String> segs, Uri uri) {
    final s = [for (final x in segs) if (!x.startsWith('intl-') && x != 'embed') x];
    // Also /user/<name>/playlist/<id>.
    for (var i = 0; i + 1 < s.length; i++) {
      final kind = _kinds[s[i]];
      if (kind != null) return ShareLink(sourceId: SourceIds.spotify, kind: kind, id: s[i + 1], uri: uri);
    }
    return null;
  }

  static ShareLink? _deezer(List<String> segs, Uri uri) {
    final s = segs.isNotEmpty && segs.first.length == 2 ? segs.sublist(1) : segs;
    if (s.length < 2) return null;
    final kind = _kinds[s[0]];
    if (kind == null || int.tryParse(s[1]) == null) return null;
    return ShareLink(sourceId: SourceIds.deezer, kind: kind, id: s[1], uri: uri);
  }

  static const _soundcloudReserved = {
    'discover', 'stream', 'search', 'upload', 'you', 'charts', 'pages', 'terms-of-use', 'settings', 'messages', //
  };
  static const _soundcloudUserPages = {
    'tracks', 'albums', 'sets', 'reposts', 'likes', 'followers', 'following', 'popular-tracks', 'comments', //
  };

  static ShareLink? _soundcloud(List<String> segs, Uri uri) {
    if (segs.isEmpty || _soundcloudReserved.contains(segs.first)) return null;
    final link = uri.replace(queryParameters: _keepSecret(uri));
    String url(Uri u) => u.toString().replaceFirst(RegExp(r'\?$'), '');
    if (segs.length >= 3 && segs[1] == 'sets') {
      return ShareLink(sourceId: SourceIds.soundcloud, kind: ShareLinkKind.playlist, id: url(link), uri: link);
    }
    if (segs.length >= 2 && !_soundcloudUserPages.contains(segs[1])) {
      return ShareLink(sourceId: SourceIds.soundcloud, kind: ShareLinkKind.track, id: url(link), uri: link);
    }
    final profile = uri.replace(pathSegments: [segs.first], queryParameters: const {});
    return ShareLink(sourceId: SourceIds.soundcloud, kind: ShareLinkKind.artist, id: url(profile), uri: profile);
  }

  /// SoundCloud private links carry a secret token (`?secret_token=` or a
  /// trailing `s-xxxx` path segment); tracking parameters are dropped.
  static Map<String, String>? _keepSecret(Uri uri) {
    final secret = uri.queryParameters['secret_token'];
    return secret == null ? null : {'secret_token': secret};
  }

  static ShareLink? _youtube(String host, List<String> segs, Uri raw, Uri uri) {
    if (host == 'youtu.be') {
      if (segs.isEmpty) return null;
      return ShareLink(sourceId: SourceIds.youtube, kind: ShareLinkKind.track, id: segs.first, uri: uri);
    }
    final q = raw.queryParameters;
    if (segs.isNotEmpty && segs.first == 'watch' && (q['v'] ?? '').isNotEmpty) {
      return ShareLink(sourceId: SourceIds.youtube, kind: ShareLinkKind.track, id: q['v']!, uri: uri);
    }
    if (segs.isNotEmpty && segs.first == 'playlist' && (q['list'] ?? '').isNotEmpty) {
      return ShareLink(sourceId: SourceIds.youtube, kind: ShareLinkKind.playlist, id: q['list']!, uri: uri);
    }
    if (segs.length >= 2 && segs.first == 'channel') {
      return ShareLink(sourceId: SourceIds.youtube, kind: ShareLinkKind.artist, id: segs[1], uri: uri);
    }
    return null;
  }

  static ShareLink? _audius(List<String> segs, Uri uri) {
    if (segs.isEmpty) return null;
    final link = uri.replace(queryParameters: const {});
    final url = link.toString().replaceFirst(RegExp(r'\?$'), '');
    if (segs.length >= 3 && (segs[1] == 'playlist' || segs[1] == 'album')) {
      return ShareLink(sourceId: SourceIds.audius, kind: ShareLinkKind.playlist, id: url, uri: link);
    }
    if (segs.length >= 2) return ShareLink(sourceId: SourceIds.audius, kind: ShareLinkKind.track, id: url, uri: link);
    return ShareLink(sourceId: SourceIds.audius, kind: ShareLinkKind.artist, id: url, uri: link);
  }

  static ShareLink? _jamendo(List<String> segs, Uri uri) {
    final s = segs.isNotEmpty && segs.first.length == 2 ? segs.sublist(1) : segs;
    if (s.length < 2) return null;
    final kind = _kinds[s[0]];
    if (kind == null || int.tryParse(s[1]) == null) return null;
    return ShareLink(sourceId: SourceIds.jamendo, kind: kind, id: s[1], uri: uri);
  }
}
