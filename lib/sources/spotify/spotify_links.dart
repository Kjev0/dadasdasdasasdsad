import '../../core/net/http_client.dart';
import '../../core/util/cancel_token.dart';
import '../base/redirects.dart';

/// Kinds of Spotify links Fermata understands.
enum SpotifyLinkKind { track, album, artist, playlist }

/// A parsed Spotify link: kind + base-62 id.
class SpotifyLink {
  const SpotifyLink(this.kind, this.id);

  final SpotifyLinkKind kind;
  final String id;

  @override
  bool operator ==(Object other) => other is SpotifyLink && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'SpotifyLink(${kind.name}, $id)';
}

/// Parses Spotify share links, URIs and ids.
///
/// Accepted forms:
/// * `https://open.spotify.com/playlist/<id>?si=…` (also `/intl-<lang>/…`,
///   `/embed/…` and the legacy `/user/<name>/playlist/<id>`);
/// * `spotify:playlist:<id>` and legacy `spotify:user:<name>:playlist:<id>`;
/// * a bare 22-character base-62 id (for [playlistId] / [trackId]);
/// * short links `https://spotify.link/<code>` / `spoti.fi/<code>` — resolved
///   by following redirects ([resolve]; the redirect chain is not documented
///   by Spotify, so a link that does not end on open.spotify.com fails).
abstract final class SpotifyLinks {
  static final _id = RegExp(r'^[A-Za-z0-9]{22}$');
  static final _uri = RegExp(r'^spotify:(?:user:[^:]+:)?(track|album|artist|playlist):([A-Za-z0-9]{22})$');
  static final _path = RegExp(
    r'^/(?:intl-[a-zA-Z-]+/)?(?:embed/)?(?:user/[^/]+/)?(track|album|artist|playlist)/([A-Za-z0-9]{22})/?$',
  );

  static bool isId(String s) => _id.hasMatch(s.trim());

  static SpotifyLinkKind _kind(String s) => SpotifyLinkKind.values.byName(s);

  static Uri? _toUri(String input) {
    final s = input.trim();
    if (s.isEmpty || s.contains(' ')) return null;
    final uri = Uri.tryParse(s.contains('://') ? s : 'https://$s');
    return uri == null || uri.host.isEmpty ? null : uri;
  }

  /// Parses a URI (`spotify:…`) or an open.spotify.com URL; null otherwise.
  static SpotifyLink? parse(String input) {
    final s = input.trim();
    final m = _uri.firstMatch(s);
    if (m != null) return SpotifyLink(_kind(m.group(1)!), m.group(2)!);
    final uri = _toUri(s);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host != 'open.spotify.com' && host != 'play.spotify.com') return null;
    final p = _path.firstMatch(uri.path);
    return p == null ? null : SpotifyLink(_kind(p.group(1)!), p.group(2)!);
  }

  static bool isShortLink(String input) {
    final host = _toUri(input)?.host.toLowerCase();
    return host == 'spotify.link' || host == 'spoti.fi' || host == 'spotify.app.link';
  }

  /// The playlist id in [input] (id, URI or URL), or null.
  static String? playlistId(String input) => _idOf(input, SpotifyLinkKind.playlist);

  /// The track id in [input] (id, URI or URL), or null.
  static String? trackId(String input) => _idOf(input, SpotifyLinkKind.track);

  static String? _idOf(String input, SpotifyLinkKind kind) {
    final s = input.trim();
    if (isId(s)) return s;
    final link = parse(s);
    return link?.kind == kind ? link!.id : null;
  }

  /// Like [parse], following short links over the network first.
  static Future<SpotifyLink?> resolve(FermataHttp http, String input, {CancelToken? cancel}) async {
    if (!isShortLink(input)) return parse(input);
    final target = await resolveRedirects(
      http,
      _toUri(input)!,
      cancel: cancel,
      stopWhen: (u) => parse(u.toString()) != null,
    );
    return parse(target.toString());
  }

  /// `https://open.spotify.com/track/<id>` — "Open in Spotify".
  static Uri trackUrl(String id) => Uri.parse('https://open.spotify.com/track/$id');
}
