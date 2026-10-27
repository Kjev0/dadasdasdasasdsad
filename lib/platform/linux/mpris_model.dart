import 'dart:convert';

import 'package:dbus/dbus.dart';

import '../../core/models/playback.dart';
import '../../core/models/track.dart';

/// Pure mapping between Fermata's playback model and MPRIS 2.2 values
/// (https://specifications.freedesktop.org/mpris-spec/latest/).
abstract final class MprisModel {
  static const identity = 'Fermata';
  static const desktopEntry = 'app.fermata.player';
  static const noTrackPath = '/org/mpris/MediaPlayer2/TrackList/NoTrack';
  static const trackPathPrefix = '/app/fermata/player/track/t';

  static const supportedUriSchemes = ['file'];
  static const supportedMimeTypes = [
    'audio/mpeg',
    'audio/mp4',
    'audio/x-m4a',
    'audio/aac',
    'audio/flac',
    'audio/x-flac',
    'audio/ogg',
    'audio/x-vorbis+ogg',
    'audio/opus',
    'audio/wav',
    'audio/x-wav',
    'audio/x-aiff',
    'audio/webm',
    'audio/x-matroska',
    'audio/x-ms-wma',
    'audio/x-ape',
    'audio/x-wavpack',
  ];

  /// A valid D-Bus object path derived from the queue entry uid (hex of its
  /// UTF-8 bytes, so any uid maps to a unique, valid path).
  static String trackIdFor(String? queueUid) {
    if (queueUid == null || queueUid.isEmpty) return noTrackPath;
    final hex = utf8.encode(queueUid).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$trackPathPrefix$hex';
  }

  /// `Playing` / `Paused` / `Stopped`.
  static String playbackStatus(PlaybackSnapshot s) {
    if (s.current == null) return 'Stopped';
    if (s.playing) return 'Playing';
    if (s.status == PlayerStatus.idle || s.status == PlayerStatus.completed) return 'Stopped';
    return 'Paused';
  }

  static String loopStatus(RepeatMode mode) => switch (mode) {
        RepeatMode.off => 'None',
        RepeatMode.one => 'Track',
        RepeatMode.all => 'Playlist',
      };

  /// Null for values outside the MPRIS enumeration.
  static RepeatMode? repeatModeFor(String loopStatus) => switch (loopStatus) {
        'None' => RepeatMode.off,
        'Track' => RepeatMode.one,
        'Playlist' => RepeatMode.all,
        _ => null,
      };

  static Duration? lengthOf(PlaybackSnapshot s) {
    final d = s.duration ?? s.track?.duration;
    return (d == null || d <= Duration.zero) ? null : d;
  }

  /// The `Metadata` property (a{sv}).
  static Map<String, DBusValue> metadata(PlaybackSnapshot s) {
    final item = s.current;
    final track = item?.track;
    if (item == null || track == null) {
      return {'mpris:trackid': DBusObjectPath(noTrackPath)};
    }
    final length = lengthOf(s);
    final url = urlOf(track);
    final art = track.artworkUrl;
    return {
      'mpris:trackid': DBusObjectPath(trackIdFor(item.uid)),
      if (length != null) 'mpris:length': DBusInt64(length.inMicroseconds),
      'xesam:title': DBusString(track.title),
      if (track.artists.isNotEmpty) 'xesam:artist': DBusArray.string(track.artists.map((a) => a.name)),
      if (track.album != null) 'xesam:album': DBusString(track.album!),
      if (track.albumArtist != null) 'xesam:albumArtist': DBusArray.string([track.albumArtist!]),
      if (track.trackNumber != null) 'xesam:trackNumber': DBusInt32(track.trackNumber!),
      if (track.discNumber != null) 'xesam:discNumber': DBusInt32(track.discNumber!),
      if (track.genre != null) 'xesam:genre': DBusArray.string([track.genre!]),
      if (url != null) 'xesam:url': DBusString(url),
      if (art != null && (art.scheme == 'https' || art.scheme == 'http' || art.scheme == 'file'))
        'mpris:artUrl': DBusString(art.toString()),
    };
  }

  /// `file://` URI for user-owned files, else the provider permalink.
  static String? urlOf(Track track) {
    final path = track.localPath;
    if (path != null && path.isNotEmpty) return Uri.file(path).toString();
    return track.permalink?.toString();
  }

  static bool canGoNext(PlaybackSnapshot s, QueueState q) {
    if (s.current == null || q.isEmpty) return false;
    return q.currentIndex < q.items.length - 1 || s.repeat == RepeatMode.all;
  }

  /// "Previous" restarts the current track, so it is always possible while
  /// something is loaded.
  static bool canGoPrevious(PlaybackSnapshot s) => s.current != null;

  static bool canPlay(PlaybackSnapshot s) => s.current != null;

  static bool canPause(PlaybackSnapshot s) => s.current != null;

  static bool canSeek(PlaybackSnapshot s) => s.current != null && lengthOf(s) != null;
}
