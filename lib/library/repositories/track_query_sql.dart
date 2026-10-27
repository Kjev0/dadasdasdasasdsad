import '../../core/models/library.dart';
import '../../core/sources/source_ids.dart';
import '../db/sql_utils.dart';
import '../text/fold.dart';

/// A piece of SQL with its bound arguments.
class SqlFragment {
  const SqlFragment(this.sql, [this.args = const []]);

  final String sql;
  final List<Object?> args;

  static const empty = SqlFragment('');

  bool get isEmpty => sql.isEmpty;
}

/// Joins per-track play statistics as `ps.play_count` / `ps.last_played`.
const playStatsJoin =
    'LEFT JOIN (SELECT track_id, COUNT(*) AS play_count, MAX(played_at) AS last_played '
    'FROM play_history GROUP BY track_id) ps ON ps.track_id = t.id';

/// Effective local-file / download predicates (alias `t`).
const isLocalFileSql = "(t.source_id = '${SourceIds.local}' AND t.local_path IS NOT NULL)";
const isDownloadedSql = '(t.id IN (SELECT track_id FROM downloaded_tracks))';
const isFavoriteSql = '(t.id IN (SELECT track_id FROM favorites))';
const isOfflineAvailableSql = '(($isLocalFileSql AND t.missing_since IS NULL) OR $isDownloadedSql)';

/// Translates [TrackQuery] filters and sorting to SQL over `tracks t`.
abstract final class TrackQuerySql {
  /// `WHERE` body (without the keyword) for [q]; empty when unfiltered.
  static SqlFragment where(TrackQuery q) {
    final parts = <String>[];
    final args = <Object?>[];
    final text = textMatch(q.text, 't.search_norm');
    if (!text.isEmpty) {
      parts.add(text.sql);
      args.addAll(text.args);
    }
    final sources = q.sourceIds;
    if (sources != null) {
      if (sources.isEmpty) {
        parts.add('0');
      } else {
        parts.add('t.source_id IN (${placeholders(sources.length)})');
        args.addAll(sources);
      }
    }
    if (q.artist != null) {
      final a = artistMatch(q.artist!);
      parts.add(a.sql);
      args.addAll(a.args);
    }
    if (q.album != null) {
      parts.add('t.album_norm = ?');
      args.add(foldForSearch(q.album));
    }
    if (q.genre != null) {
      parts.add('t.genre_norm = ?');
      args.add(foldForSearch(q.genre));
    }
    if (q.minYear != null) {
      parts.add('t.year >= ?');
      args.add(q.minYear);
    }
    if (q.maxYear != null) {
      parts.add('t.year <= ?');
      args.add(q.maxYear);
    }
    if (q.minDuration != null) {
      parts.add('t.duration_ms >= ?');
      args.add(q.minDuration!.inMilliseconds);
    }
    if (q.maxDuration != null) {
      parts.add('t.duration_ms <= ?');
      args.add(q.maxDuration!.inMilliseconds);
    }
    if (q.favoritesOnly) parts.add(isFavoriteSql);
    if (q.downloadedOnly) parts.add(isDownloadedSql);
    if (q.localFilesOnly) parts.add(isLocalFileSql);
    if (q.offlineAvailableOnly) parts.add(isOfflineAvailableSql);
    if (parts.isEmpty) return SqlFragment.empty;
    return SqlFragment(parts.join(' AND '), args);
  }

  /// Every folded token of [text] must occur in [column].
  static SqlFragment textMatch(String? text, String column) {
    final tokens = searchTokens(text);
    if (tokens.isEmpty) return SqlFragment.empty;
    return SqlFragment(
      tokens.map((_) => "$column LIKE ? ESCAPE '\\'").join(' AND '),
      [for (final t in tokens) '%${escapeLike(t)}%'],
    );
  }

  /// Tracks credited to [artist] (any position) or with it as album artist.
  static SqlFragment artistMatch(String artist) {
    final norm = foldForSearch(artist);
    return SqlFragment(
      '(t.album_artist_norm = ? OR EXISTS (SELECT 1 FROM track_artists ta WHERE ta.track_id = t.id AND ta.name_norm = ?))',
      [norm, norm],
    );
  }

  /// Whether sorting by [field] needs [playStatsJoin].
  static bool needsPlayStats(TrackSortField field) =>
      field == TrackSortField.lastPlayed || field == TrackSortField.playCount;

  /// `ORDER BY` body; nulls sort last in both directions, ties are broken by
  /// title and id so paging is stable.
  static String orderBy(TrackSortField field, bool descending) {
    final dir = descending ? 'DESC' : 'ASC';
    final String primary;
    switch (field) {
      case TrackSortField.title:
        primary = 't.title_norm $dir';
      case TrackSortField.artist:
        primary = "t.artist_norm = '' ASC, t.artist_norm $dir, t.album_norm ASC, t.disc_no ASC, t.track_no ASC";
      case TrackSortField.album:
        primary = 't.album_norm IS NULL ASC, t.album_norm $dir, t.album_artist_norm ASC, t.disc_no ASC, t.track_no ASC';
      case TrackSortField.year:
        primary = 't.year IS NULL ASC, t.year $dir';
      case TrackSortField.duration:
        primary = 't.duration_ms IS NULL ASC, t.duration_ms $dir';
      case TrackSortField.dateAdded:
        primary = 't.date_added $dir';
      case TrackSortField.lastPlayed:
        primary = 'ps.last_played IS NULL ASC, ps.last_played $dir';
      case TrackSortField.playCount:
        primary = 'COALESCE(ps.play_count, 0) $dir';
      case TrackSortField.genre:
        primary = 't.genre_norm IS NULL ASC, t.genre_norm $dir';
    }
    return '$primary, t.title_norm ASC, t.id ASC';
  }

  /// `LIMIT/OFFSET` clause (with leading space) or empty.
  static String limitClause(int? limit, int offset) {
    if (limit == null && offset <= 0) return '';
    return ' LIMIT ${limit ?? -1} OFFSET ${offset < 0 ? 0 : offset}';
  }
}
