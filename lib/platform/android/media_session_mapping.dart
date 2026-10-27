/// Pure mapping between Fermata's playback model and audio_service's
/// MediaSession model. No platform channels are touched here, so everything
/// in this file is unit-testable.
library;

import 'package:audio_service/audio_service.dart';

import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import 'media_session_labels.dart';

/// Keys used in [MediaItem.extras]. Values are always `String`/`bool`
/// (audio_service only accepts int/String/bool/double).
abstract final class MediaItemExtras {
  /// Global track id (`<sourceId>:<sourceTrackId>`).
  static const trackId = 'fermata.trackId';
  static const sourceId = 'fermata.sourceId';

  /// Queue origin, e.g. `playlist:<id>`.
  static const origin = 'fermata.origin';

  /// Present (true) when only a provider preview is playing.
  static const preview = 'fermata.preview';
}

/// Name of the custom media action that toggles the favorite flag of the
/// current track (heart button in the notification).
const toggleLikeActionName = 'fermata.toggle_like';

/// Android drawable resources for the optional like/unlike notification
/// button, e.g. `drawable/ic_fermata_favorite`. Only pass these when the
/// drawables are actually bundled in `android/app/src/main/res` — a missing
/// resource makes the notification fail to render.
class LikeControlIcons {
  const LikeControlIcons({required this.liked, required this.notLiked});

  /// Filled heart, shown while the current track is a favorite.
  final String liked;

  /// Outlined heart, shown while it is not.
  final String notLiked;
}

/// Compact notification view: previous, play/pause, next.
const compactActionIndices = [0, 1, 2];

/// Artwork URIs audio_service can load: network (http/https), files and
/// Android content URIs. Bare absolute paths are converted to `file://`.
/// Anything else (data:, custom schemes) is dropped.
Uri? artUriFor(Track track) => sessionArtUri(track.artworkUrl);

/// See [artUriFor]; for artwork that does not belong to a track (playlists).
Uri? sessionArtUri(Uri? uri) {
  if (uri == null) return null;
  switch (uri.scheme) {
    case 'http':
    case 'https':
    case 'file':
    case 'content':
      return uri;
    case '':
      return uri.path.startsWith('/') ? Uri.file(uri.path) : null;
    default:
      return null;
  }
}

/// [MediaItem] for a playable track. [id] must be unique within the queue
/// (queue items use their queue uid, browse items their browse id).
MediaItem mediaItemForTrack(
  Track track, {
  required String id,
  Duration? duration,
  String? origin,
  bool isPreview = false,
  Rating? rating,
}) {
  final artist = track.artistLine;
  final extras = <String, dynamic>{
    MediaItemExtras.trackId: track.id,
    MediaItemExtras.sourceId: track.sourceId,
    MediaItemExtras.origin: ?origin,
    if (isPreview) MediaItemExtras.preview: true,
  };
  return MediaItem(
    id: id,
    title: track.title,
    artist: artist.isEmpty ? null : artist,
    album: track.album,
    genre: track.genre,
    duration: duration ?? track.duration,
    artUri: artUriFor(track),
    playable: true,
    rating: rating,
    extras: extras,
  );
}

/// [MediaItem] for a queue entry; its id is the queue uid so the same track
/// can appear several times in the queue.
MediaItem mediaItemForQueueItem(QueueItem item, {Duration? duration, bool isPreview = false, Rating? rating}) =>
    mediaItemForTrack(
      item.track,
      id: item.uid,
      duration: duration,
      origin: item.origin,
      isPreview: isPreview,
      rating: rating,
    );

/// Value used to detect whether the current [MediaItem] must be re-sent
/// ([MediaItem.==] only compares ids, so a duration that becomes known later
/// would otherwise be missed).
Object mediaItemKey(MediaItem item) => Object.hash(
      item.id,
      item.title,
      item.artist,
      item.album,
      item.duration,
      item.artUri,
      item.rating,
      item.extras?[MediaItemExtras.preview],
    );

AudioProcessingState processingStateFor(PlayerStatus status) => switch (status) {
      PlayerStatus.idle => AudioProcessingState.idle,
      PlayerStatus.loading => AudioProcessingState.loading,
      PlayerStatus.buffering => AudioProcessingState.buffering,
      PlayerStatus.ready => AudioProcessingState.ready,
      PlayerStatus.completed => AudioProcessingState.completed,
      PlayerStatus.error => AudioProcessingState.error,
    };

AudioServiceRepeatMode repeatModeToSession(RepeatMode mode) => switch (mode) {
      RepeatMode.off => AudioServiceRepeatMode.none,
      RepeatMode.one => AudioServiceRepeatMode.one,
      RepeatMode.all => AudioServiceRepeatMode.all,
    };

/// `group` is not supported by Fermata's queue and is treated as `all`.
RepeatMode repeatModeFromSession(AudioServiceRepeatMode mode) => switch (mode) {
      AudioServiceRepeatMode.none => RepeatMode.off,
      AudioServiceRepeatMode.one => RepeatMode.one,
      AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => RepeatMode.all,
    };

AudioServiceShuffleMode shuffleModeToSession(bool shuffle) =>
    shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;

bool shuffleFromSession(AudioServiceShuffleMode mode) => mode != AudioServiceShuffleMode.none;

/// Notification buttons: previous, play/pause, next and — only when
/// [likeIcons] is given — a like/unlike custom action.
List<MediaControl> controlsFor({
  required bool playing,
  required MediaSessionLabels labels,
  LikeControlIcons? likeIcons,
  bool liked = false,
}) =>
    [
      MediaControl.skipToPrevious.copyWith(label: labels.previous),
      if (playing) MediaControl.pause.copyWith(label: labels.pause) else MediaControl.play.copyWith(label: labels.play),
      MediaControl.skipToNext.copyWith(label: labels.next),
      if (likeIcons != null)
        MediaControl.custom(
          androidIcon: liked ? likeIcons.liked : likeIcons.notLiked,
          label: liked ? labels.unlike : labels.like,
          name: toggleLikeActionName,
        ),
    ];

/// Non-button actions enabled on the session (seek bar, Android Auto queue,
/// shuffle/repeat, speed).
Set<MediaAction> systemActionsFor({bool supportsSpeed = true}) => {
      MediaAction.seek,
      MediaAction.seekForward,
      MediaAction.seekBackward,
      MediaAction.skipToQueueItem,
      MediaAction.setShuffleMode,
      MediaAction.setRepeatMode,
      if (supportsSpeed) MediaAction.setSpeed,
    };

/// Full [PlaybackState] for a controller snapshot. [queueIndex] is relative
/// to the queue that was published to the session (see [QueueWindow]).
PlaybackState playbackStateFor({
  required PlaybackSnapshot snapshot,
  required int? queueIndex,
  required MediaSessionLabels labels,
  required DateTime now,
  LikeControlIcons? likeIcons,
  bool liked = false,
  bool supportsSpeed = true,
}) {
  final processing = processingStateFor(snapshot.status);
  final isError = processing == AudioProcessingState.error;
  return PlaybackState(
    controls: controlsFor(playing: snapshot.playing, labels: labels, likeIcons: likeIcons, liked: liked),
    androidCompactActionIndices: compactActionIndices,
    systemActions: systemActionsFor(supportsSpeed: supportsSpeed),
    processingState: processing,
    playing: snapshot.playing,
    updatePosition: snapshot.position,
    bufferedPosition: snapshot.bufferedPosition,
    speed: snapshot.speed,
    updateTime: now,
    errorCode: isError ? 1 : null,
    errorMessage: isError ? (snapshot.errorMessage ?? 'Playback error') : null,
    repeatMode: repeatModeToSession(snapshot.repeat),
    shuffleMode: shuffleModeToSession(snapshot.shuffle),
    queueIndex: queueIndex,
  );
}

/// Position the session clients extrapolate from [state] at [now]
/// (same formula as [PlaybackState.position], but with an explicit clock).
Duration extrapolatedPosition(PlaybackState state, DateTime now) {
  if (!state.playing || state.processingState != AudioProcessingState.ready) return state.updatePosition;
  final elapsedMs = now.difference(state.updateTime).inMilliseconds;
  return state.updatePosition + Duration(milliseconds: (elapsedMs * state.speed).round());
}

/// Whether [next] must be broadcast given the last published state.
///
/// audio_service clients extrapolate the position from `updatePosition`,
/// `updateTime` and `speed`, so the controller's ~4 Hz position ticks are NOT
/// forwarded. A new state is only sent when something discrete changed, or
/// when the real position drifted more than [tolerance] from the
/// extrapolated one (seek, stall, track restart).
bool shouldPublishState(
  PlaybackState? last,
  PlaybackState next, {
  required DateTime now,
  Duration tolerance = const Duration(milliseconds: 1500),
}) {
  if (last == null) return true;
  if (last.processingState != next.processingState ||
      last.playing != next.playing ||
      last.speed != next.speed ||
      last.queueIndex != next.queueIndex ||
      last.repeatMode != next.repeatMode ||
      last.shuffleMode != next.shuffleMode ||
      last.errorMessage != next.errorMessage ||
      !_sameControls(last.controls, next.controls) ||
      !_sameSet(last.systemActions, next.systemActions)) {
    return true;
  }
  final drift = (extrapolatedPosition(last, now) - next.updatePosition).abs();
  return drift > tolerance;
}

bool _sameControls(List<MediaControl> a, List<MediaControl> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i] || a[i].customAction?.name != b[i].customAction?.name) return false;
  }
  return true;
}

bool _sameSet<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);

/// The slice of the play queue that is published to the MediaSession.
///
/// audio_service sends the whole queue over the platform channel on every
/// change and (with `preloadArtwork`) downloads artwork for every entry, so
/// a 5 000-track queue must not be published as a whole. Android Auto and
/// the system UI only show a short queue anyway.
class QueueWindow {
  const QueueWindow(this.start, this.end);

  static const empty = QueueWindow(0, 0);

  /// Inclusive start index into the full queue.
  final int start;

  /// Exclusive end index into the full queue.
  final int end;

  int get length => end - start;

  /// Window-relative index of the absolute queue [index], or null when it is
  /// outside the window.
  int? relative(int index) => index >= start && index < end ? index - start : null;

  /// Absolute queue index of the window-relative [index], or null when out of
  /// range.
  int? absolute(int index) => index >= 0 && index < length ? start + index : null;

  /// Window of at most `before + 1 + after` entries around [currentIndex].
  /// The window is shifted (not shrunk) at the queue edges.
  factory QueueWindow.around({
    required int length,
    required int currentIndex,
    int before = 10,
    int after = 50,
  }) {
    final size = before + 1 + after;
    if (length <= size) return QueueWindow(0, length);
    final anchor = currentIndex < 0 ? 0 : currentIndex;
    final start = (anchor - before).clamp(0, length - size);
    return QueueWindow(start, start + size);
  }

  @override
  bool operator ==(Object other) => other is QueueWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'QueueWindow($start..$end)';
}
