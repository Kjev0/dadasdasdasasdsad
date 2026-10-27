/// Kinds of Jamendo links.
enum JamendoLinkKind { track, album, artist, playlist }

class JamendoLink {
  const JamendoLink(this.kind, this.id);

  final JamendoLinkKind kind;
  final String id;

  @override
  bool operator ==(Object other) => other is JamendoLink && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'JamendoLink(${kind.name}, $id)';
}

/// Parses Jamendo web and short links without network access:
/// * `https://www.jamendo.com/(<lang>/)?track|album|artist|playlist/<id>/<slug>`
/// * legacy lists `https://www.jamendo.com/list/p<id>` (playlist) and
///   `…/list/a<id>` (album) — the `shareurl` form in API responses;
/// * short links `https://jamen.do/l/p<id>`, `/l/a<id>`, `/a/<id>` (artist),
///   `/t/<id>` (track) — the `shorturl` form.
abstract final class JamendoLinks {
  static final _digits = RegExp(r'^\d+$');
  static final _path = RegExp(r'^/(?:[a-z]{2}/)?(track|album|artist|playlist)/(\d+)(?:/|$)');
  static final _list = RegExp(r'^/(?:[a-z]{2}/)?list/([ap])(\d+)(?:/|$)');
  static final _short = RegExp(r'^/(?:l/([ap])(\d+)|([at])/(\d+))/?$');

  static bool isNumericId(String s) => _digits.hasMatch(s.trim());

  static JamendoLink? parse(String input) {
    final s = input.trim();
    if (s.isEmpty || s.contains(' ')) return null;
    final uri = Uri.tryParse(s.contains('://') ? s : 'https://$s');
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == 'jamen.do') {
      final m = _short.firstMatch(uri.path);
      if (m == null) return null;
      if (m.group(1) != null) {
        return JamendoLink(m.group(1) == 'p' ? JamendoLinkKind.playlist : JamendoLinkKind.album, m.group(2)!);
      }
      return JamendoLink(m.group(3) == 'a' ? JamendoLinkKind.artist : JamendoLinkKind.track, m.group(4)!);
    }
    if (host != 'jamendo.com' && host != 'www.jamendo.com') return null;
    final list = _list.firstMatch(uri.path);
    if (list != null) {
      return JamendoLink(list.group(1) == 'p' ? JamendoLinkKind.playlist : JamendoLinkKind.album, list.group(2)!);
    }
    final m = _path.firstMatch(uri.path);
    return m == null ? null : JamendoLink(JamendoLinkKind.values.byName(m.group(1)!), m.group(2)!);
  }

  /// The numeric id of [kind] in [input] (bare id or link), or null.
  static String? idOf(String input, JamendoLinkKind kind) {
    final s = input.trim();
    if (isNumericId(s)) return s;
    final link = parse(s);
    return link?.kind == kind ? link!.id : null;
  }
}
