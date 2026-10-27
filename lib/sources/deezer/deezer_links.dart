import '../../core/net/http_client.dart';
import '../../core/util/cancel_token.dart';
import '../base/redirects.dart';

/// Kinds of Deezer web links Fermata understands.
enum DeezerLinkKind { track, album, artist, playlist, profile }

/// A parsed Deezer link: kind + numeric id.
class DeezerLink {
  const DeezerLink(this.kind, this.id);

  final DeezerLinkKind kind;
  final String id;

  @override
  bool operator ==(Object other) => other is DeezerLink && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'DeezerLink(${kind.name}, $id)';
}

/// Parses Deezer share links and resolves short links.
///
/// Accepted forms (with or without scheme / `www.` / a language segment):
/// * `https://www.deezer.com/<lang>/playlist/<id>`, `…/track/<id>`,
///   `…/album/<id>`, `…/artist/<id>`, `…/profile/<id>` (user profile)
/// * `deezer://www.deezer.com/playlist/<id>`
/// * `https://api.deezer.com/playlist/<id>`
/// * short links `https://link.deezer.com/s/<code>` and the legacy
///   `https://deezer.page.link/<code>` → resolved by following redirects.
abstract final class DeezerLinks {
  static final _path = RegExp(
    r'^/(?:[a-z]{2}(?:-[a-z]{2})?/)?(track|album|artist|playlist|profile|user)/(\d+)/?',
    caseSensitive: false,
  );

  static bool isShortLink(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'link.deezer.com' || host == 'deezer.page.link' || host.endsWith('.page.link');
  }

  static Uri? _toUri(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;
    final withScheme = s.contains('://') ? s : 'https://$s';
    final uri = Uri.tryParse(withScheme);
    return uri == null || uri.host.isEmpty ? null : uri;
  }

  static bool _isDeezerHost(String host) {
    final h = host.toLowerCase();
    return h == 'deezer.com' || h.endsWith('.deezer.com');
  }

  /// Parses a direct (non-short) link. Returns null when not a Deezer link.
  static DeezerLink? parse(String input) {
    final uri = _toUri(input);
    if (uri == null) return null;
    // deezer://www.deezer.com/playlist/123 → host is www.deezer.com.
    if (!_isDeezerHost(uri.host)) return null;
    final m = _path.firstMatch(uri.path);
    if (m == null) return null;
    final kind = switch (m.group(1)!.toLowerCase()) {
      'track' => DeezerLinkKind.track,
      'album' => DeezerLinkKind.album,
      'artist' => DeezerLinkKind.artist,
      'playlist' => DeezerLinkKind.playlist,
      _ => DeezerLinkKind.profile,
    };
    return DeezerLink(kind, m.group(2)!);
  }

  /// Parses [input]; follows short links over the network first.
  static Future<DeezerLink?> resolve(FermataHttp http, String input, {CancelToken? cancel}) async {
    final uri = _toUri(input);
    if (uri == null) return null;
    if (!isShortLink(uri)) return parse(input);
    final target = await resolveRedirects(
      http,
      uri,
      cancel: cancel,
      stopWhen: (u) => !isShortLink(u) && parse(u.toString()) != null,
    );
    return parse(target.toString());
  }

  /// A plain numeric id, or null.
  static String? numericId(String input) {
    final s = input.trim();
    return RegExp(r'^\d+$').hasMatch(s) ? s : null;
  }
}
