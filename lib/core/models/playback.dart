import 'package:flutter/foundation.dart';

import 'track.dart';

enum RepeatMode { off, all, one }

enum PlayerStatus { idle, loading, buffering, ready, completed, error }

/// Requested stream quality. Sources map this to what they actually offer.
enum AudioQuality { low, normal, high, lossless }

/// One entry in the play queue. The same track may appear several times,
/// so each entry has its own [uid].
@immutable
class QueueItem {
  const QueueItem({required this.uid, required this.track, this.origin, this.addedManually = false});

  final String uid;
  final Track track;

  /// Where the item came from, e.g. `playlist:<id>`, `album:<id>`, `search`,
  /// `smart-queue`. Used for "Playing from ..." labels and smart queue.
  final String? origin;

  /// True when added with "Play next"/"Add to queue" (kept on reshuffle).
  final bool addedManually;

  Map<String, Object?> toJson() => {
        'uid': uid,
        'track': track.toJson(),
        if (origin != null) 'origin': origin,
        if (addedManually) 'manual': true,
      };

  factory QueueItem.fromJson(Map<String, Object?> json) => QueueItem(
        uid: json['uid'] as String,
        track: Track.fromJson((json['track'] as Map).cast<String, Object?>()),
        origin: json['origin'] as String?,
        addedManually: json['manual'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) => other is QueueItem && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}

/// Immutable view of the queue. [items] is in *play order* (already shuffled
/// when shuffle is on). [currentIndex] is -1 when nothing is loaded.
@immutable
class QueueState {
  const QueueState({required this.items, required this.currentIndex, this.originLabel});

  const QueueState.empty()
      : items = const [],
        currentIndex = -1,
        originLabel = null;

  final List<QueueItem> items;
  final int currentIndex;

  /// Human-readable "Playing from" label, e.g. a playlist name.
  final String? originLabel;

  QueueItem? get current =>
      currentIndex >= 0 && currentIndex < items.length ? items[currentIndex] : null;

  List<QueueItem> get upNext =>
      currentIndex < 0 ? items : items.sublist((currentIndex + 1).clamp(0, items.length));

  List<QueueItem> get previous =>
      currentIndex <= 0 ? const [] : items.sublist(0, currentIndex);

  bool get isEmpty => items.isEmpty;
}

/// Snapshot of the player, emitted on every state change and periodically
/// (~4 Hz) while playing so the UI can update the position.
@immutable
class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.current,
    this.playing = false,
    this.status = PlayerStatus.idle,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration,
    this.volume = 1.0,
    this.speed = 1.0,
    this.shuffle = false,
    this.repeat = RepeatMode.off,
    this.errorMessage,
    this.sleepTimerEndsAt,
    this.sleepAtEndOfTrack = false,
    this.isPreview = false,
  });

  final QueueItem? current;
  final bool playing;
  final PlayerStatus status;
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;

  /// User volume 0..1 (before normalization gain).
  final double volume;
  final double speed;
  final bool shuffle;
  final RepeatMode repeat;
  final String? errorMessage;
  final DateTime? sleepTimerEndsAt;
  final bool sleepAtEndOfTrack;

  /// True when only a provider preview of the current track is playing.
  final bool isPreview;

  Track? get track => current?.track;

  PlaybackSnapshot copyWith({
    QueueItem? current,
    bool clearCurrent = false,
    bool? playing,
    PlayerStatus? status,
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
    double? volume,
    double? speed,
    bool? shuffle,
    RepeatMode? repeat,
    String? errorMessage,
    bool clearError = false,
    DateTime? sleepTimerEndsAt,
    bool clearSleepTimer = false,
    bool? sleepAtEndOfTrack,
    bool? isPreview,
  }) =>
      PlaybackSnapshot(
        current: clearCurrent ? null : (current ?? this.current),
        playing: playing ?? this.playing,
        status: status ?? this.status,
        position: position ?? this.position,
        bufferedPosition: bufferedPosition ?? this.bufferedPosition,
        duration: duration ?? this.duration,
        volume: volume ?? this.volume,
        speed: speed ?? this.speed,
        shuffle: shuffle ?? this.shuffle,
        repeat: repeat ?? this.repeat,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        sleepTimerEndsAt: clearSleepTimer ? null : (sleepTimerEndsAt ?? this.sleepTimerEndsAt),
        sleepAtEndOfTrack: sleepAtEndOfTrack ?? this.sleepAtEndOfTrack,
        isPreview: isPreview ?? this.isPreview,
      );
}

/// Discrete playback events (as opposed to continuous snapshots).
sealed class PlaybackEvent {
  const PlaybackEvent();
}

class TrackStarted extends PlaybackEvent {
  const TrackStarted(this.item, this.startedAt);
  final QueueItem item;
  final DateTime startedAt;
}

/// Emitted when a track stops being current (finished, skipped, or replaced).
class TrackEnded extends PlaybackEvent {
  const TrackEnded({
    required this.item,
    required this.startedAt,
    required this.listened,
    required this.completed,
  });

  final QueueItem item;
  final DateTime startedAt;

  /// Wall-clock time actually spent playing (excludes pauses).
  final Duration listened;

  /// True when it reached the natural end (not skipped).
  final bool completed;
}

class PlaybackFailed extends PlaybackEvent {
  const PlaybackFailed(this.item, this.error, {this.skipped = false});
  final QueueItem item;
  final Object error;

  /// True when the engine automatically skipped to the next playable item.
  final bool skipped;
}

class QueueEnded extends PlaybackEvent {
  const QueueEnded();
}

/// A resolved, directly playable media location.
@immutable
class PlayableSource {
  const PlayableSource({
    required this.uri,
    this.headers = const {},
    this.isLocalFile = false,
    this.isPreview = false,
    this.expiresAt,
    this.mimeType,
  });

  final Uri uri;
  final Map<String, String> headers;
  final bool isLocalFile;
  final bool isPreview;

  /// Signed stream URLs expire; the engine re-resolves after this time.
  final DateTime? expiresAt;
  final String? mimeType;
}

@immutable
class AudioOutputDevice {
  const AudioOutputDevice({required this.id, required this.name, this.isDefault = false});

  final String id;
  final String name;
  final bool isDefault;

  @override
  bool operator ==(Object other) => other is AudioOutputDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
