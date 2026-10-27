/// Clean music metadata extracted from a YouTube video.
class YouTubeVideoMetadata {
  const YouTubeVideoMetadata({
    required this.title,
    this.artists = const [],
    this.album,
    this.year,
    this.artistFromChannel = false,
  });

  final String title;

  /// Primary artist first, then featured artists.
  final List<String> artists;
  final String? album;
  final int? year;

  /// True when the primary artist was taken from the channel name
  /// ("Artist - Topic", "ArtistVEVO", or a title without a separator).
  final bool artistFromChannel;

  @override
  String toString() => 'YouTubeVideoMetadata("$title" by ${artists.join(', ')})';
}

/// Turns YouTube video titles, channel names and auto-generated descriptions
/// into matching-friendly metadata. There is no YouTube Music API, so this
/// is a heuristic over the Data API's `snippet` (documented in
/// docs/PROVIDERS.md):
///
/// 1. Auto-generated "Art Tracks" (channel `Artist - Topic`, description
///    "Provided to YouTube by …") carry `Title · Artist · Artist`, the album
///    line and `Released on: YYYY-MM-DD` — used when present.
/// 2. `Artist - Title (Official Video)` style titles: split on the first
///    ` - ` / ` – ` / ` — ` (or `Artist "Title"`), noise in brackets removed
///    (official video/audio, lyrics, visualizer, HD/4K, MV, …), but
///    meaningful qualifiers kept (remix, live, acoustic, version, edit, …).
/// 3. Otherwise the artist is the channel name with `- Topic`, `VEVO`
///    (`TaylorSwiftVEVO` → "Taylor Swift") and `Official` removed.
///
/// `feat.` / `ft.` / `featuring` credits become additional artists.
abstract final class YouTubeMetadataParser {
  static final _separator = RegExp(r'\s+[-–—]\s+');
  static final _quoted = RegExp(r'^(.+?)\s+["“«](.+?)["”»](.*)$');
  static final _brackets = RegExp(r'\s*[(\[【]([^)\]】]*)[)\]】]');
  static final _feat = RegExp(
    r'\s*[(\[]?\s*\b(?:feat\.?|ft\.?|featuring)\s+([^)\]]+?)\s*[)\]]?\s*$',
    caseSensitive: false,
  );
  static final _artistSplit = RegExp(r'\s*,\s*|\s+(?:feat\.?|ft\.?|featuring)\s+|\s+x\s+', caseSensitive: false);
  static final _released = RegExp(r'Released on:\s*(\d{4})(?:-\d{2}-\d{2})?');

  static const _noise = [
    'official',
    'video',
    'audio',
    'lyric',
    'lyrics',
    'visualizer',
    'visualiser',
    'hd',
    'hq',
    '4k',
    'mv',
    'm/v',
    'clip officiel',
    'videoclip',
    'music video',
  ];
  static const _keep = [
    'remix',
    'live',
    'acoustic',
    'feat',
    'ft.',
    'version',
    'edit',
    'cover',
    'mix',
    'remaster',
    'instrumental',
    'extended',
    'unplugged',
    'demo',
    'session',
  ];

  /// Parses a video's [title] with its [channelTitle] and (optional)
  /// [description].
  static YouTubeVideoMetadata parse(String title, {String? channelTitle, String? description}) {
    final channel = channelTitle?.trim() ?? '';
    final artTrack = _artTrack(description);
    if (artTrack != null) return artTrack;

    final topicArtist = _topicArtist(channel);
    final cleaned = cleanTitle(title);
    if (topicArtist != null) {
      final (t, feats) = _extractFeat(cleaned);
      return YouTubeVideoMetadata(title: t, artists: [topicArtist, ...feats], artistFromChannel: true);
    }

    final quoted = _quoted.firstMatch(cleaned);
    final parts = cleaned.split(_separator);
    if (parts.length >= 2 && parts.first.trim().isNotEmpty) {
      final artistPart = parts.first.trim();
      final titlePart = parts.sublist(1).join(' - ').trim();
      final (t, feats) = _extractFeat(_unquote(titlePart));
      return YouTubeVideoMetadata(title: t, artists: [..._splitArtists(artistPart), ...feats]);
    }
    if (quoted != null) {
      final (t, feats) = _extractFeat('${quoted.group(2)!.trim()}${quoted.group(3)!}'.trim());
      return YouTubeVideoMetadata(title: t, artists: [..._splitArtists(quoted.group(1)!.trim()), ...feats]);
    }
    final (t, feats) = _extractFeat(_unquote(cleaned));
    final fromChannel = channelArtist(channel);
    return YouTubeVideoMetadata(title: t, artists: [?fromChannel, ...feats], artistFromChannel: fromChannel != null);
  }

  /// "Provided to YouTube by …" description block.
  static YouTubeVideoMetadata? _artTrack(String? description) {
    if (description == null || !description.contains('Provided to YouTube by')) return null;
    final lines = description.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final i = lines.indexWhere((l) => l.contains(' · '));
    if (i < 0) return null;
    final parts = lines[i].split(' · ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return null;
    final next = i + 1 < lines.length ? lines[i + 1] : null;
    final album = next == null || next.startsWith('℗') || next.startsWith('©') || next.startsWith('Released on:')
        ? null
        : next;
    final year = int.tryParse(_released.firstMatch(description)?.group(1) ?? '');
    return YouTubeVideoMetadata(title: parts.first, artists: parts.sublist(1), album: album, year: year);
  }

  static String? _topicArtist(String channel) {
    const suffix = ' - Topic';
    if (channel.endsWith(suffix) && channel.length > suffix.length) {
      return channel.substring(0, channel.length - suffix.length).trim();
    }
    return null;
  }

  /// The artist implied by a channel name, or null for an empty name.
  static String? channelArtist(String channel) {
    var c = channel.trim();
    if (c.isEmpty) return null;
    final topic = _topicArtist(c);
    if (topic != null) return topic;
    if (c.length > 4 && c.toUpperCase().endsWith('VEVO')) {
      c = c.substring(0, c.length - 4).trim();
      // "TaylorSwiftVEVO" → "Taylor Swift"
      if (!c.contains(' ')) c = c.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ');
    }
    c = c.replaceFirst(RegExp(r'\s*[-|]?\s*(official\s*(channel|artist channel)?|music)$', caseSensitive: false), '');
    c = c.trim();
    return c.isEmpty ? channel.trim() : c;
  }

  /// Removes bracketed noise and `| Official Video` style suffixes.
  static String cleanTitle(String title) {
    var t = title.trim();
    t = t.replaceAllMapped(_brackets, (m) => _isNoise(m.group(1)!) ? '' : m.group(0)!);
    final pipes = t.split(RegExp(r'\s+[|｜]\s+'));
    if (pipes.length > 1) {
      t = [pipes.first, ...pipes.skip(1).where((p) => !_isNoise(p))].join(' | ');
    }
    // Unbracketed trailing noise ("… Official Video", "… M/V").
    for (var previous = ''; previous != t;) {
      previous = t;
      t = t.replaceFirst(_trailingNoise, '').trim();
    }
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return t.isEmpty ? title.trim() : t;
  }

  static final _trailingNoise = RegExp(
    r'\s+(?:official\s+(?:music\s+|lyric\s+)?(?:video|audio|visuali[sz]er|mv)|lyric\s+video|lyrics|m/v|mv|hd|4k)$',
    caseSensitive: false,
  );

  static bool _isNoise(String content) {
    final c = content.toLowerCase().trim();
    if (c.isEmpty) return true;
    if (_keep.any(c.contains)) return false;
    return _noise.any((n) => RegExp('(^|[^a-z])${RegExp.escape(n)}([^a-z]|\$)').hasMatch(c));
  }

  static String _unquote(String s) {
    final t = s.trim();
    final m = RegExp(r'^["“«](.+)["”»]$').firstMatch(t);
    return m == null ? t : m.group(1)!.trim();
  }

  static (String, List<String>) _extractFeat(String title) {
    final m = _feat.firstMatch(title);
    if (m == null || m.start == 0) return (title.trim(), const []);
    return (title.substring(0, m.start).trim(), _splitArtists(m.group(1)!));
  }

  static List<String> _splitArtists(String s) =>
      s.split(_artistSplit).map((a) => a.trim()).where((a) => a.isNotEmpty).toList();

  static final _iso = RegExp(r'^P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$');

  /// ISO-8601 duration (`PT4M13S`, `PT1H2M`, `P1DT2H`) from
  /// `contentDetails.duration`; null for invalid input or `P0D` (live).
  static Duration? parseDuration(String? value) {
    if (value == null) return null;
    final m = _iso.firstMatch(value.trim());
    if (m == null || value.trim() == 'P' || value.trim() == 'PT') return null;
    int n(int g) => int.tryParse(m.group(g) ?? '') ?? 0;
    final seconds = double.tryParse(m.group(5) ?? '') ?? 0;
    final d = Duration(days: n(1) * 7 + n(2), hours: n(3), minutes: n(4), milliseconds: (seconds * 1000).round());
    return d == Duration.zero ? null : d;
  }
}
