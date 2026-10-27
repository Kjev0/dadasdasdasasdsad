/// SoundCloud identifiers and share links.
///
/// Since April 2025 SoundCloud identifies resources by URN
/// (`soundcloud:tracks:123`, `soundcloud:playlists:456`,
/// `soundcloud:users:789`, `soundcloud:system-playlists:track-stations:1`);
/// numeric `id`s are deprecated. URNs are treated as opaque keys — Fermata
/// only *builds* one from a bare numeric id (the documented format) and never
/// parses the number back out.
///
/// Share links (`https://soundcloud.com/<user>/<track>`,
/// `…/sets/<playlist>`, private `…/s-<secret>` links, `m.soundcloud.com`,
/// and `on.soundcloud.com/<code>` short links) are resolved server-side with
/// `GET /resolve?url=` — see `SoundCloudApi.resolve`.
abstract final class SoundCloudLinks {
  static final _urn = RegExp(r'^soundcloud:[a-z-]+:[^\s/?#]+$');
  static final _digits = RegExp(r'^\d+$');
  static final _secret = RegExp(r'^s-[A-Za-z0-9]+$');

  /// Hosts whose URLs `/resolve` understands.
  static const _hosts = {'soundcloud.com', 'www.soundcloud.com', 'm.soundcloud.com', 'on.soundcloud.com'};

  /// Whether [value] is a SoundCloud URN of any kind.
  static bool isUrn(String value) => _urn.hasMatch(value.trim());

  /// The URN kind (`tracks`, `playlists`, `users`, …) or null.
  static String? urnKind(String urn) {
    final s = urn.trim();
    if (!isUrn(s)) return null;
    return s.split(':')[1];
  }

  /// A track URN from a URN or a legacy numeric id; null otherwise.
  static String? trackUrn(String idOrUrn) => _urnOf(idOrUrn, 'tracks');

  /// A playlist URN from a URN or a legacy numeric id; null otherwise.
  static String? playlistUrn(String idOrUrn) => _urnOf(idOrUrn, 'playlists');

  /// A user URN from a URN or a legacy numeric id; null otherwise.
  static String? userUrn(String idOrUrn) => _urnOf(idOrUrn, 'users');

  static String? _urnOf(String idOrUrn, String kind) {
    final s = idOrUrn.trim();
    if (_digits.hasMatch(s)) return 'soundcloud:$kind:$s';
    if (isUrn(s) && urnKind(s) == kind) return s;
    return null;
  }

  /// Parses [input] as an http(s) URL (adds `https://` when missing).
  static Uri? _toUri(String input) {
    final s = input.trim();
    if (s.isEmpty || s.contains(' ')) return null;
    final uri = Uri.tryParse(s.contains('://') ? s : 'https://$s');
    if (uri == null || uri.host.isEmpty) return null;
    if (!uri.isScheme('https') && !uri.isScheme('http')) return null;
    return uri;
  }

  /// Whether [input] is a soundcloud.com / on.soundcloud.com web link.
  static bool isShareUrl(String input) {
    final uri = _toUri(input);
    return uri != null && _hosts.contains(uri.host.toLowerCase()) && uri.pathSegments.any((s) => s.isNotEmpty);
  }

  /// Whether [input] is a short link (`on.soundcloud.com/<code>`).
  static bool isShortLink(String input) => _toUri(input)?.host.toLowerCase() == 'on.soundcloud.com';

  /// Canonical form for `/resolve`: https, `soundcloud.com` host (mobile and
  /// `www.` hosts folded), tracking query parameters (`si`, `utm_*`, `ref`)
  /// removed. Short links are kept as they are. Null when not a share URL.
  static Uri? normaliseShareUrl(String input) {
    if (!isShareUrl(input)) return null;
    final uri = _toUri(input)!;
    final host = uri.host.toLowerCase();
    if (host == 'on.soundcloud.com') {
      return Uri(scheme: 'https', host: host, path: uri.path);
    }
    final query = <String, String>{
      for (final e in uri.queryParameters.entries)
        if (e.key != 'si' && e.key != 'ref' && !e.key.startsWith('utm_')) e.key: e.value,
    };
    var path = uri.path;
    if (path.length > 1 && path.endsWith('/')) path = path.substring(0, path.length - 1);
    return Uri(scheme: 'https', host: 'soundcloud.com', path: path, queryParameters: query.isEmpty ? null : query);
  }

  /// The `secret_token` of a private share link (`…/s-AbC123`), or null.
  static String? secretToken(String input) {
    final uri = _toUri(input);
    if (uri == null) return null;
    final fromQuery = uri.queryParameters['secret_token'];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
    for (final segment in uri.pathSegments.reversed) {
      if (_secret.hasMatch(segment)) return segment;
    }
    return null;
  }

  /// Extracts the URN from an API resource URL such as
  /// `https://api.soundcloud.com/playlists/soundcloud:playlists:123`.
  static String? urnFromApiUrl(String input) {
    final uri = _toUri(input);
    if (uri == null || uri.host.toLowerCase() != 'api.soundcloud.com') return null;
    for (final segment in uri.pathSegments.reversed) {
      final decoded = Uri.decodeComponent(segment);
      if (isUrn(decoded)) return decoded;
    }
    return null;
  }
}
