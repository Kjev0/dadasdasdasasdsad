import 'dart:convert';

import 'package:collection/collection.dart';

import '../../core/models/track.dart';
import '../text/fold.dart';

/// Track JSON keys a user may override with tag edits.
const editableTrackKeys = <String>{
  'title',
  'artists',
  'album',
  'albumArtist',
  'year',
  'genre',
  'trackNo',
  'discNo',
  'isrc',
  'explicit',
  'artwork',
};

const _deepEq = DeepCollectionEquality();

/// Converts between [Track] objects and `tracks` rows.
///
/// The `json` column holds the track as delivered by its source (scanner or
/// provider); `override_json` holds the user's tag edits as a partial Track
/// JSON map (a `null` value clears the field). The denormalized columns
/// (`title`, `*_norm`, ...) always reflect the *effective* track, i.e. the
/// source values with the overrides applied.
abstract final class TrackCodec {
  /// Columns used by [decode]; select these (with a `t.` alias) to read tracks.
  static const selectColumns = 't.json, t.override_json, t.missing_since';

  static Map<String, Object?> decodeJson(String raw) => (jsonDecode(raw) as Map).cast<String, Object?>();

  /// Applies [override] on top of the source JSON.
  static Track applyOverride(Map<String, Object?> json, Map<String, Object?>? override) {
    if (override == null || override.isEmpty) return Track.fromJson(json);
    return Track.fromJson({...json, ...override});
  }

  /// Builds the effective track from a row containing [selectColumns].
  static Track decode(Map<String, Object?> row) {
    final json = decodeJson(row['json'] as String);
    final ovRaw = row['override_json'] as String?;
    var track = applyOverride(json, ovRaw == null ? null : decodeJson(ovRaw));
    if (row['missing_since'] != null && track.isLocal) {
      track = track.copyWith(
        availability: const TrackAvailability(
          playback: PlaybackRights.unavailable,
          offline: OfflineRights.userOwned,
          reason: AvailabilityReason.fileMissing,
        ),
      );
    }
    return track;
  }

  /// The override needed to turn [base] into [edited] (only editable keys).
  /// Returns null when nothing differs.
  static Map<String, Object?>? diffOverride(Track base, Track edited) {
    final a = base.toJson();
    final b = edited.toJson();
    final out = <String, Object?>{};
    for (final key in editableTrackKeys) {
      if (!_deepEq.equals(a[key], b[key])) out[key] = b[key];
    }
    return out.isEmpty ? null : out;
  }

  /// Denormalized columns for the effective [t] (without `json`,
  /// `override_json`, `date_added` and file columns).
  static Map<String, Object?> columns(Track t) {
    final artistLine = t.artistLine;
    final albumNorm = t.album == null ? null : foldForSearch(t.album);
    final albumArtistName = (t.albumArtist != null && t.albumArtist!.trim().isNotEmpty) ? t.albumArtist! : t.primaryArtist;
    return {
      'id': t.id,
      'source_id': t.sourceId,
      'source_track_id': t.sourceTrackId,
      'title': t.title,
      'title_norm': foldForSearch(t.title),
      'artist': artistLine,
      'artist_norm': foldForSearch(artistLine),
      'primary_artist': t.primaryArtist,
      'album': t.album,
      'album_norm': albumNorm,
      'album_artist': t.albumArtist,
      'album_artist_norm': foldForSearch(albumArtistName),
      'genre': t.genre,
      'genre_norm': t.genre == null ? null : foldForSearch(t.genre),
      'year': t.year,
      'duration_ms': t.duration?.inMilliseconds,
      'isrc': normalizeIsrc(t.isrc),
      'track_no': t.trackNumber,
      'disc_no': t.discNumber,
      'artwork_url': t.artworkUrl?.toString(),
      'search_norm': foldForSearch('${t.title} $artistLine ${t.album ?? ''} ${t.albumArtist ?? ''}'),
      'local_path': t.localPath,
    };
  }

  /// Upper-case ISRC without separators, or null when empty.
  static String? normalizeIsrc(String? isrc) {
    if (isrc == null) return null;
    final s = isrc.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    return s.isEmpty ? null : s;
  }
}
