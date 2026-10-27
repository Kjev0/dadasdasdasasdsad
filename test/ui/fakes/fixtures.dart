import 'package:fermata/core/contracts/discovery.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';

/// Builds a test track. `id` = `<sourceId>:<sid>`.
Track testTrack(
  String sid, {
  String sourceId = SourceIds.audius,
  String? title,
  String artist = 'Test Artist',
  String? artistId,
  String? album,
  Duration duration = const Duration(minutes: 3, seconds: 30),
  PlaybackRights playback = PlaybackRights.full,
  OfflineRights offline = OfflineRights.streamOnly,
  String? reason,
  Uri? artworkUrl,
  Uri? permalink,
  Map<String, String> extra = const {},
  bool? explicit,
}) =>
    Track(
      sourceId: sourceId,
      sourceTrackId: sid,
      title: title ?? 'Track $sid',
      artists: [ArtistRef(artist, sourceArtistId: artistId)],
      album: album,
      duration: duration,
      artworkUrl: artworkUrl,
      permalink: permalink ?? (sourceId == SourceIds.local ? null : Uri.parse('https://example.org/$sourceId/$sid')),
      localPath: sourceId == SourceIds.local ? '/music/$sid.flac' : null,
      explicit: explicit,
      availability: sourceId == SourceIds.local
          ? const TrackAvailability.local()
          : TrackAvailability(playback: playback, offline: offline, reason: reason),
      extra: extra,
    );

/// [count] tracks `t1..tN` from [sourceId].
List<Track> testTracks(int count, {String sourceId = SourceIds.audius, String prefix = 't'}) =>
    [for (var i = 1; i <= count; i++) testTrack('$prefix$i', sourceId: sourceId, title: 'Song $i', artist: 'Artist $i')];

Playlist testPlaylist(String id, {String? name, int? trackCount, PlaylistKind kind = PlaylistKind.local}) =>
    Playlist(id: id, name: name ?? 'Playlist $id', kind: kind, trackCount: trackCount);

/// Synced lyrics with one line every [step].
Lyrics testSyncedLyrics(List<String> lines, {Duration step = const Duration(seconds: 10), String provider = 'LRCLIB'}) => Lyrics(
      provider: provider,
      synced: [for (var i = 0; i < lines.length; i++) LyricsLine(step * i, lines[i])],
      plain: lines.join('\n'),
    );
