import 'package:logging/logging.dart';

import '../core/contracts/music_source.dart';
import 'import_session.dart';
import 'util/async_utils.dart';

/// Reads a source playlist page by page into an import session.
class PlaylistFetcher {
  const PlaylistFetcher({
    required this.maxTracks,
    required this.maxPages,
    this.rateLimit = const RateLimitPolicy(maxRetries: 3),
  });

  /// Fetching stops after this many tracks.
  final int maxTracks;

  /// Safety cap on pages (guards against cursor loops).
  final int maxPages;

  /// Retry policy for each page request.
  final RateLimitPolicy rateLimit;

  static final _log = Logger('matching.import');
  static final _secretSegment = RegExp(r'^s-[A-Za-z0-9_-]+$');

  /// Follows `nextCursor` until the last page, [maxTracks], [maxPages] or a
  /// repeated cursor. Stopping before the end of the playlist sets
  /// [MutableImportSession.truncated].
  Future<void> fetch(MutableImportSession s, MusicSource source, String idOrUrl) async {
    String? cursor;
    final seenCursors = <String>{};
    for (var page = 0; page < maxPages; page++) {
      s.cancelToken.throwIfCanceled();
      final requestCursor = cursor;
      final detail = await withRateLimitRetry(
        () => source.getPlaylist(idOrUrl, cursor: requestCursor, cancel: s.cancelToken),
        policy: rateLimit,
        cancel: s.cancelToken,
        log: _log,
        label: '${source.id} playlist page ${page + 1}',
      );
      s.playlist ??= detail.playlist;
      final items = detail.tracks.items;
      final room = maxTracks - s.tracks.length;
      s.tracks.addAll(items.take(room));
      s.emit();
      final next = detail.tracks.nextCursor;
      if (items.length > room || (next != null && s.tracks.length >= maxTracks)) {
        return _truncated(s, 'playlist truncated at $maxTracks tracks');
      }
      if (next == null) return;
      if (!seenCursors.add(next)) return _truncated(s, '${source.id} repeated a page cursor; stopping');
      cursor = next;
    }
    _truncated(s, 'stopped after $maxPages pages');
  }

  static void _truncated(MutableImportSession s, String why) {
    s.truncated = true;
    _log.warning('import ${s.id}: $why');
  }

  /// [ref] safe for logs, which users attach to bug reports: a URL loses
  /// its query, fragment and secret path tokens (SoundCloud private sets end
  /// in "/s-XXXX"; unlisted YouTube lists are a `list=` query); a bare id is
  /// kept.
  static String redact(String ref) {
    final trimmed = ref.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return trimmed;
    final path = [
      for (final seg in uri.pathSegments)
        if (seg.isNotEmpty) _secretSegment.hasMatch(seg) ? 's-…' : seg,
    ].join('/');
    return '${uri.host}/$path${uri.hasQuery ? '?…' : ''}';
  }
}
