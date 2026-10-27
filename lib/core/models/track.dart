import 'package:flutter/foundation.dart';

import '../sources/source_ids.dart';

/// What a source allows us to do when playing a track.
enum PlaybackRights {
  /// The full track can be streamed or played from disk.
  full,

  /// Only a short preview may be played (e.g. Deezer 30 s previews).
  preview,

  /// Playback is only permitted inside the provider's own app/site
  /// (e.g. YouTube Music, Spotify). We can open it externally.
  externalOnly,

  /// The track cannot be played (deleted, private, region-restricted, ...).
  unavailable,

  /// Not yet determined (e.g. imported metadata that has not been checked).
  unknown,
}

/// The four offline categories the UI must clearly distinguish.
enum OfflineRights {
  /// A file the user owns (local library). Always available offline.
  userOwned,

  /// The source explicitly permits downloading this track.
  downloadable,

  /// May be streamed but not stored for offline use.
  streamOnly,

  /// Cannot be made available offline at all.
  unavailable,
}

@immutable
class TrackAvailability {
  const TrackAvailability({
    required this.playback,
    required this.offline,
    this.reason,
    this.previewDuration,
    this.checkedAt,
  });

  const TrackAvailability.unknown()
      : playback = PlaybackRights.unknown,
        offline = OfflineRights.unavailable,
        reason = null,
        previewDuration = null,
        checkedAt = null;

  const TrackAvailability.local()
      : playback = PlaybackRights.full,
        offline = OfflineRights.userOwned,
        reason = null,
        previewDuration = null,
        checkedAt = null;

  final PlaybackRights playback;
  final OfflineRights offline;

  /// Machine-readable reason code when restricted, see [AvailabilityReason].
  final String? reason;

  /// Length of the playable preview when [playback] is [PlaybackRights.preview].
  final Duration? previewDuration;

  /// When availability was last verified against the source.
  final DateTime? checkedAt;

  bool get isPlayableInApp =>
      playback == PlaybackRights.full || playback == PlaybackRights.preview;

  TrackAvailability copyWith({
    PlaybackRights? playback,
    OfflineRights? offline,
    String? reason,
    Duration? previewDuration,
    DateTime? checkedAt,
  }) =>
      TrackAvailability(
        playback: playback ?? this.playback,
        offline: offline ?? this.offline,
        reason: reason ?? this.reason,
        previewDuration: previewDuration ?? this.previewDuration,
        checkedAt: checkedAt ?? this.checkedAt,
      );

  Map<String, Object?> toJson() => {
        'playback': playback.name,
        'offline': offline.name,
        if (reason != null) 'reason': reason,
        if (previewDuration != null) 'previewMs': previewDuration!.inMilliseconds,
        if (checkedAt != null) 'checkedAt': checkedAt!.toIso8601String(),
      };

  factory TrackAvailability.fromJson(Map<String, Object?> json) => TrackAvailability(
        playback: PlaybackRights.values.asNameMap()[json['playback']] ?? PlaybackRights.unknown,
        offline: OfflineRights.values.asNameMap()[json['offline']] ?? OfflineRights.unavailable,
        reason: json['reason'] as String?,
        previewDuration:
            json['previewMs'] == null ? null : Duration(milliseconds: (json['previewMs'] as num).toInt()),
        checkedAt: json['checkedAt'] == null ? null : DateTime.tryParse(json['checkedAt'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is TrackAvailability &&
      other.playback == playback &&
      other.offline == offline &&
      other.reason == reason &&
      other.previewDuration == previewDuration;

  @override
  int get hashCode => Object.hash(playback, offline, reason, previewDuration);
}

/// Stable reason codes for restricted availability. UI maps these to
/// localized explanations.
abstract final class AvailabilityReason {
  static const deleted = 'deleted';
  static const private = 'private';
  static const regionRestricted = 'region_restricted';
  static const subscriptionRequired = 'subscription_required';
  static const notStreamable = 'not_streamable';
  static const previewOnly = 'preview_only';
  static const externalOnly = 'external_only';
  static const fileMissing = 'file_missing';
  static const notAuthorized = 'not_authorized';
  static const credentialsMissing = 'credentials_missing';
  static const offline = 'offline';
  static const unknown = 'unknown';
}

@immutable
class ArtistRef {
  const ArtistRef(this.name, {this.sourceArtistId});

  final String name;
  final String? sourceArtistId;

  Map<String, Object?> toJson() => {
        'name': name,
        if (sourceArtistId != null) 'id': sourceArtistId,
      };

  factory ArtistRef.fromJson(Map<String, Object?> json) =>
      ArtistRef(json['name'] as String, sourceArtistId: json['id'] as String?);

  @override
  bool operator ==(Object other) =>
      other is ArtistRef && other.name == name && other.sourceArtistId == sourceArtistId;

  @override
  int get hashCode => Object.hash(name, sourceArtistId);

  @override
  String toString() => name;
}

@immutable
class AudioFormatInfo {
  const AudioFormatInfo({
    this.codec,
    this.bitrateKbps,
    this.sampleRateHz,
    this.channels,
    this.bitsPerSample,
    this.fileSizeBytes,
  });

  final String? codec;
  final int? bitrateKbps;
  final int? sampleRateHz;
  final int? channels;
  final int? bitsPerSample;
  final int? fileSizeBytes;

  Map<String, Object?> toJson() => {
        if (codec != null) 'codec': codec,
        if (bitrateKbps != null) 'bitrate': bitrateKbps,
        if (sampleRateHz != null) 'sampleRate': sampleRateHz,
        if (channels != null) 'channels': channels,
        if (bitsPerSample != null) 'bits': bitsPerSample,
        if (fileSizeBytes != null) 'size': fileSizeBytes,
      };

  factory AudioFormatInfo.fromJson(Map<String, Object?> json) => AudioFormatInfo(
        codec: json['codec'] as String?,
        bitrateKbps: (json['bitrate'] as num?)?.toInt(),
        sampleRateHz: (json['sampleRate'] as num?)?.toInt(),
        channels: (json['channels'] as num?)?.toInt(),
        bitsPerSample: (json['bits'] as num?)?.toInt(),
        fileSizeBytes: (json['size'] as num?)?.toInt(),
      );
}

/// A single recording from one source.
///
/// [id] is globally unique: `"<sourceId>:<sourceTrackId>"` (see [Track.makeId]).
/// The same logical song on two providers is two [Track]s connected through
/// track links in the library (see `TrackLinkRepository`).
@immutable
class Track {
  const Track({
    required this.sourceId,
    required this.sourceTrackId,
    required this.title,
    this.artists = const [],
    this.album,
    this.albumArtist,
    this.duration,
    this.isrc,
    this.explicit,
    this.year,
    this.genre,
    this.trackNumber,
    this.discNumber,
    this.artworkUrl,
    this.permalink,
    this.localPath,
    this.availability = const TrackAvailability.unknown(),
    this.format,
    this.replayGainTrackDb,
    this.replayGainAlbumDb,
    this.extra = const {},
  });

  static String makeId(String sourceId, String sourceTrackId) => '$sourceId:$sourceTrackId';

  String get id => makeId(sourceId, sourceTrackId);

  final String sourceId;
  final String sourceTrackId;
  final String title;

  /// Primary artist first, then featured artists.
  final List<ArtistRef> artists;
  final String? album;
  final String? albumArtist;
  final Duration? duration;
  final String? isrc;
  final bool? explicit;
  final int? year;
  final String? genre;
  final int? trackNumber;
  final int? discNumber;

  /// Remote artwork (https) or a local file (`file://`).
  final Uri? artworkUrl;

  /// Link back to the track on the provider (needed for attribution).
  final Uri? permalink;

  /// Absolute path for user-owned local files. Downloaded copies of remote
  /// tracks are NOT stored here; ask the DownloadManager instead.
  final String? localPath;
  final TrackAvailability availability;
  final AudioFormatInfo? format;
  final double? replayGainTrackDb;
  final double? replayGainAlbumDb;

  /// Provider-specific extra fields (stream URNs, permalink slugs, ...).
  final Map<String, String> extra;

  bool get isLocal => sourceId == SourceIds.local;

  String get primaryArtist => artists.isEmpty ? '' : artists.first.name;

  String get artistLine => artists.map((a) => a.name).join(', ');

  Track copyWith({
    String? title,
    List<ArtistRef>? artists,
    String? album,
    String? albumArtist,
    Duration? duration,
    String? isrc,
    bool? explicit,
    int? year,
    String? genre,
    int? trackNumber,
    int? discNumber,
    Uri? artworkUrl,
    Uri? permalink,
    String? localPath,
    TrackAvailability? availability,
    AudioFormatInfo? format,
    double? replayGainTrackDb,
    double? replayGainAlbumDb,
    Map<String, String>? extra,
  }) =>
      Track(
        sourceId: sourceId,
        sourceTrackId: sourceTrackId,
        title: title ?? this.title,
        artists: artists ?? this.artists,
        album: album ?? this.album,
        albumArtist: albumArtist ?? this.albumArtist,
        duration: duration ?? this.duration,
        isrc: isrc ?? this.isrc,
        explicit: explicit ?? this.explicit,
        year: year ?? this.year,
        genre: genre ?? this.genre,
        trackNumber: trackNumber ?? this.trackNumber,
        discNumber: discNumber ?? this.discNumber,
        artworkUrl: artworkUrl ?? this.artworkUrl,
        permalink: permalink ?? this.permalink,
        localPath: localPath ?? this.localPath,
        availability: availability ?? this.availability,
        format: format ?? this.format,
        replayGainTrackDb: replayGainTrackDb ?? this.replayGainTrackDb,
        replayGainAlbumDb: replayGainAlbumDb ?? this.replayGainAlbumDb,
        extra: extra ?? this.extra,
      );

  Map<String, Object?> toJson() => {
        'source': sourceId,
        'sid': sourceTrackId,
        'title': title,
        'artists': [for (final a in artists) a.toJson()],
        if (album != null) 'album': album,
        if (albumArtist != null) 'albumArtist': albumArtist,
        if (duration != null) 'durationMs': duration!.inMilliseconds,
        if (isrc != null) 'isrc': isrc,
        if (explicit != null) 'explicit': explicit,
        if (year != null) 'year': year,
        if (genre != null) 'genre': genre,
        if (trackNumber != null) 'trackNo': trackNumber,
        if (discNumber != null) 'discNo': discNumber,
        if (artworkUrl != null) 'artwork': artworkUrl.toString(),
        if (permalink != null) 'permalink': permalink.toString(),
        if (localPath != null) 'path': localPath,
        'availability': availability.toJson(),
        if (format != null) 'format': format!.toJson(),
        if (replayGainTrackDb != null) 'rgTrack': replayGainTrackDb,
        if (replayGainAlbumDb != null) 'rgAlbum': replayGainAlbumDb,
        if (extra.isNotEmpty) 'extra': extra,
      };

  factory Track.fromJson(Map<String, Object?> json) => Track(
        sourceId: json['source'] as String,
        sourceTrackId: json['sid'] as String,
        title: json['title'] as String? ?? '',
        artists: [
          for (final a in (json['artists'] as List? ?? const []))
            ArtistRef.fromJson((a as Map).cast<String, Object?>()),
        ],
        album: json['album'] as String?,
        albumArtist: json['albumArtist'] as String?,
        duration: json['durationMs'] == null
            ? null
            : Duration(milliseconds: (json['durationMs'] as num).toInt()),
        isrc: json['isrc'] as String?,
        explicit: json['explicit'] as bool?,
        year: (json['year'] as num?)?.toInt(),
        genre: json['genre'] as String?,
        trackNumber: (json['trackNo'] as num?)?.toInt(),
        discNumber: (json['discNo'] as num?)?.toInt(),
        artworkUrl: json['artwork'] == null ? null : Uri.tryParse(json['artwork'] as String),
        permalink: json['permalink'] == null ? null : Uri.tryParse(json['permalink'] as String),
        localPath: json['path'] as String?,
        availability: json['availability'] == null
            ? const TrackAvailability.unknown()
            : TrackAvailability.fromJson((json['availability'] as Map).cast<String, Object?>()),
        format: json['format'] == null
            ? null
            : AudioFormatInfo.fromJson((json['format'] as Map).cast<String, Object?>()),
        replayGainTrackDb: (json['rgTrack'] as num?)?.toDouble(),
        replayGainAlbumDb: (json['rgAlbum'] as num?)?.toDouble(),
        extra: (json['extra'] as Map?)?.cast<String, String>() ?? const {},
      );

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Track($id, "$title" by $artistLine)';
}
