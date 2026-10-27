import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../core/contracts/library.dart';
import '../../core/contracts/playback.dart';
import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import 'media_browser.dart';
import 'media_button_clicks.dart';
import 'media_session_config.dart';
import 'media_session_labels.dart';
import 'media_session_mapping.dart';

final _log = Logger('platform.android.session');

/// Adapts the app-wide [PlaybackController] to audio_service (Android
/// MediaSession, media notification, lock screen, Bluetooth/headset buttons,
/// Wear OS, Android Auto).
///
/// The controller is the single source of truth: this handler only mirrors
/// its snapshots/queue into `mediaItem`, `queue` and `playbackState`, and
/// forwards every session command back to it. It never keeps its own queue.
///
/// State is published at state changes only (see [shouldPublishState]);
/// clients extrapolate the position themselves, so the controller's ~4 Hz
/// position ticks are not forwarded.
class FermataAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  FermataAudioHandler({
    required PlaybackController playback,
    this._browser,
    FavoritesRepository? favorites,
    this._tracks,
    this.likeIcons,
    this.labels = MediaSessionLabels.en,
    this.seekInterval = AndroidMediaSessionConstants.seekInterval,
    Duration multiPressWindow = const Duration(milliseconds: 400),
    TimerFactory? timerFactory,
    DateTime Function()? now,
    this.queueWindowBefore = 10,
    this.queueWindowAfter = 50,
  })  : _playback = playback,
        _favorites = favorites,
        _now = now ?? DateTime.now,
        _snapshot = playback.snapshot,
        _queue = playback.queue {
    _clicks = MediaButtonClickDetector(onGesture: _onHeadsetGesture, window: multiPressWindow, timerFactory: timerFactory);
    _subscriptions
      ..add(playback.snapshots.listen(_onSnapshot, onError: _onStreamError))
      ..add(playback.queueStream.listen(_onQueue, onError: _onStreamError));
    final favs = favorites;
    if (favs != null) {
      _subscriptions.add(favs.watchFavoriteIds().listen(_onFavoriteIds, onError: _onStreamError));
    }
    _publishAll();
  }

  final PlaybackController _playback;
  final MediaLibraryBrowser? _browser;
  final FavoritesRepository? _favorites;
  final TrackRepository? _tracks;
  final DateTime Function() _now;

  /// Like/unlike button drawables; the button is omitted when null.
  final LikeControlIcons? likeIcons;
  final MediaSessionLabels labels;

  /// Jump size for fast-forward / rewind.
  final Duration seekInterval;
  final int queueWindowBefore;
  final int queueWindowAfter;

  late final MediaButtonClickDetector _clicks;
  final _subscriptions = <StreamSubscription<Object?>>[];

  PlaybackSnapshot _snapshot;
  QueueState _queue;
  Set<String> _favoriteIds = const {};
  QueueWindow _window = QueueWindow.empty;
  PlaybackState? _lastState;
  Object? _lastMediaKey;
  List<String>? _lastQueueUids;
  String? _lastQueueTitle;
  bool _disposed = false;

  /// The queue window currently published to the session (for tests and
  /// diagnostics).
  @visibleForTesting
  QueueWindow get queueWindow => _window;

  // ---------------------------------------------------------------------------
  // Mirroring controller → session
  // ---------------------------------------------------------------------------

  void _onSnapshot(PlaybackSnapshot snapshot) {
    _snapshot = snapshot;
    _publishAll();
  }

  void _onQueue(QueueState queue) {
    _queue = queue;
    _publishAll();
  }

  void _onFavoriteIds(Set<String> ids) {
    _favoriteIds = ids;
    _publishAll();
  }

  void _onStreamError(Object error, StackTrace st) => _log.warning('Playback stream error', error, st);

  QueueItem? get _current => _snapshot.current ?? _queue.current;

  bool get _liked {
    final current = _current;
    return current != null && _favoriteIds.contains(current.track.id);
  }

  /// Absolute index of the current item in the controller's queue.
  int _currentIndex() {
    final current = _current;
    if (current == null) return -1;
    final items = _queue.items;
    final idx = _queue.currentIndex;
    if (idx >= 0 && idx < items.length && items[idx].uid == current.uid) return idx;
    return items.indexWhere((i) => i.uid == current.uid);
  }

  void _publishAll() {
    if (_disposed) return;
    final currentIndex = _currentIndex();
    _publishQueue(currentIndex);
    _publishMediaItem();
    _publishState(currentIndex);
  }

  void _publishQueue(int currentIndex) {
    final items = _queue.items;
    _window = QueueWindow.around(
      length: items.length,
      currentIndex: currentIndex,
      before: queueWindowBefore,
      after: queueWindowAfter,
    );
    final slice = items.sublist(_window.start, _window.end);
    final uids = [for (final i in slice) i.uid];
    if (!listEquals(uids, _lastQueueUids)) {
      _lastQueueUids = uids;
      queue.add([for (final i in slice) mediaItemForQueueItem(i)]);
    }
    final title = _queue.originLabel ?? '';
    if (title != _lastQueueTitle) {
      _lastQueueTitle = title;
      queueTitle.add(title);
    }
  }

  void _publishMediaItem() {
    final current = _current;
    if (current == null) {
      if (_lastMediaKey != null) {
        _lastMediaKey = null;
        mediaItem.add(null);
      }
      return;
    }
    final sameAsSnapshot = _snapshot.current?.uid == current.uid;
    final item = mediaItemForQueueItem(
      current,
      duration: sameAsSnapshot ? _snapshot.duration : null,
      isPreview: sameAsSnapshot && _snapshot.isPreview,
      rating: _favorites == null ? null : Rating.newHeartRating(_liked),
    );
    final key = mediaItemKey(item);
    if (key != _lastMediaKey) {
      _lastMediaKey = key;
      mediaItem.add(item);
    }
  }

  void _publishState(int currentIndex, {bool force = false}) {
    final now = _now();
    final next = playbackStateFor(
      snapshot: _snapshot,
      queueIndex: currentIndex < 0 ? null : _window.relative(currentIndex),
      labels: labels,
      now: now,
      likeIcons: _favorites == null ? null : likeIcons,
      liked: _liked,
      supportsSpeed: _playback.supportsSpeed,
    );
    if (force || shouldPublishState(_lastState, next, now: now)) {
      _lastState = next;
      playbackState.add(next);
    }
  }

  // ---------------------------------------------------------------------------
  // Transport commands (session → controller)
  // ---------------------------------------------------------------------------

  Future<void> _guard(String action, Future<void> Function() op) async {
    try {
      await op();
    } catch (e, st) {
      _log.warning('Media session command "$action" failed', e, st);
    }
  }

  @override
  Future<void> play() => _guard('play', () async {
        if (_queue.isEmpty && _snapshot.current == null) {
          // Resumption card / "play music" with nothing queued: start
          // something sensible instead of doing nothing.
          final request = await _browser?.resolveSearch('');
          if (request != null) return _start(request);
        }
        await _playback.play();
      });

  @override
  Future<void> pause() => _guard('pause', _playback.pause);

  /// Stops playback (queue is kept) and releases the foreground service:
  /// an `idle` processing state makes audio_service stop the service and
  /// remove the notification.
  @override
  Future<void> stop() async {
    await _guard('stop', _playback.stop);
    if (_disposed) return;
    final idle = (_lastState ?? PlaybackState()).copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    );
    _lastState = idle;
    playbackState.add(idle);
  }

  @override
  Future<void> seek(Duration position) =>
      _guard('seek', () => _playback.seek(position.isNegative ? Duration.zero : position));

  @override
  Future<void> fastForward() => _guard('fastForward', () => _playback.seekRelative(seekInterval));

  @override
  Future<void> rewind() => _guard('rewind', () => _playback.seekRelative(-seekInterval));

  @override
  Future<void> skipToNext() => _guard('skipToNext', _playback.next);

  @override
  Future<void> skipToPrevious() => _guard('skipToPrevious', _playback.previous);

  /// [index] is relative to the published queue window.
  @override
  Future<void> skipToQueueItem(int index) => _guard('skipToQueueItem', () async {
        final absolute = _window.absolute(index);
        if (absolute == null) {
          _log.fine('skipToQueueItem($index) outside of $_window');
          return;
        }
        await _playback.skipToIndex(absolute);
      });

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      _guard('setShuffleMode', () => _playback.setShuffle(shuffleFromSession(shuffleMode)));

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) =>
      _guard('setRepeatMode', () => _playback.setRepeat(repeatModeFromSession(repeatMode)));

  @override
  Future<void> setSpeed(double speed) => _guard('setSpeed', () async {
        if (!_playback.supportsSpeed || speed.isNaN) return;
        await _playback.setSpeed(speed.clamp(0.5, 2.0).toDouble());
      });

  // ---------------------------------------------------------------------------
  // Headset buttons, task removal, notification dismissal
  // ---------------------------------------------------------------------------

  /// Headset/Bluetooth buttons. The single "media" button supports
  /// single (play/pause), double (next) and triple (previous) press; the
  /// dedicated next/previous keys map directly.
  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        _clicks.press();
      case MediaButton.next:
        await skipToNext();
      case MediaButton.previous:
        await skipToPrevious();
    }
  }

  Future<void> _onHeadsetGesture(int presses) => switch (presses) {
        1 => _guard('togglePlayPause', _playback.togglePlayPause),
        2 => skipToNext(),
        _ => skipToPrevious(),
      };

  /// App swiped away from Recents. While playing, playback continues in the
  /// foreground service (the notification stays); while paused/stopped the
  /// state is saved and the service is stopped, so nothing lingers.
  @override
  Future<void> onTaskRemoved() async {
    if (_snapshot.playing) {
      _log.info('Task removed while playing; playback continues in the background');
      return;
    }
    _log.info('Task removed while paused; stopping the playback service');
    await _guard('saveState', _playback.saveState);
    await stop();
  }

  /// Notification swiped away (possible while paused): stop.
  @override
  Future<void> onNotificationDeleted() => stop();

  // ---------------------------------------------------------------------------
  // Like / rating
  // ---------------------------------------------------------------------------

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == toggleLikeActionName) {
      await _setLiked(!_liked);
      return null;
    }
    _log.fine('Ignoring unknown custom action $name');
    return super.customAction(name, extras);
  }

  /// Heart ratings from Wear OS / Android Auto / Bluetooth AVRCP clients.
  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) async {
    if (rating.getRatingStyle() != RatingStyle.heart) return;
    await _setLiked(rating.hasHeart());
  }

  Future<void> _setLiked(bool liked) async {
    final favorites = _favorites;
    final current = _current;
    if (favorites == null || current == null) return;
    final trackId = current.track.id;
    // Optimistic update; watchFavoriteIds() confirms (or reverts) it.
    _favoriteIds = liked ? {..._favoriteIds, trackId} : ({..._favoriteIds}..remove(trackId));
    _publishAll();
    await _guard('setFavorite', () => favorites.setFavorite(current.track, liked));
  }

  // ---------------------------------------------------------------------------
  // Media browser (Android Auto, Wear OS, Assistant, resumption)
  // ---------------------------------------------------------------------------

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    if (parentMediaId == AudioService.recentRootId) {
      // Android 11+ media resumption: what would resume on "play".
      final current = _current;
      if (current != null) return [mediaItemForQueueItem(current)];
      final recent = await _browser?.mostRecent();
      return recent == null ? const [] : [recent];
    }
    return await _browser?.children(parentMediaId) ?? const [];
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final item = _queueItemByUid(mediaId);
    return item == null ? null : mediaItemForQueueItem(item);
  }

  @override
  Future<List<MediaItem>> search(String query, [Map<String, dynamic>? extras]) async =>
      await _browser?.search(query) ?? const [];

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) =>
      _guard('playFromMediaId', () async {
        final index = _queue.items.indexWhere((i) => i.uid == mediaId);
        if (index >= 0) {
          await _playback.skipToIndex(index);
          await _playback.play();
          return;
        }
        final request = await _browser?.resolve(mediaId);
        if (request == null) {
          _log.info('Nothing playable for media id $mediaId');
          return;
        }
        await _start(request);
      });

  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) =>
      _guard('playFromSearch', () async {
        final request = await _browser?.resolveSearch(query);
        if (request != null) return _start(request);
        if (!_queue.isEmpty) await _playback.play();
      });

  @override
  Future<void> playMediaItem(MediaItem mediaItem) => playFromMediaId(mediaItem.id);

  Future<void> _start(PlayRequest request) => _playback.playTracks(
        request.tracks,
        startIndex: request.startIndex,
        origin: request.origin,
        originLabel: request.originLabel,
        shuffle: request.shuffle,
      );

  // ---------------------------------------------------------------------------
  // Queue edits from session clients. The controller owns the queue, so the
  // mixin's local-list implementations are replaced by forwarding.
  // ---------------------------------------------------------------------------

  @override
  Future<void> addQueueItem(MediaItem mediaItem) => addQueueItems([mediaItem]);

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) => _guard('addQueueItems', () async {
        final tracks = await _tracksFor(mediaItems);
        if (tracks.isNotEmpty) await _playback.enqueue(tracks, origin: 'media-session');
      });

  /// Inserting right after the current item maps to "play next"; any other
  /// position appends (the controller has no positional insert).
  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) => _guard('insertQueueItem', () async {
        final tracks = await _tracksFor([mediaItem]);
        if (tracks.isEmpty) return;
        final current = _window.relative(_currentIndex());
        if (current != null && index <= current + 1) {
          await _playback.playNext(tracks, origin: 'media-session');
        } else {
          await _playback.enqueue(tracks, origin: 'media-session');
        }
      });

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) => _guard('removeQueueItem', () async {
        if (_queueItemByUid(mediaItem.id) != null) await _playback.removeFromQueue(mediaItem.id);
      });

  @override
  Future<void> removeQueueItemAt(int index) => _guard('removeQueueItemAt', () async {
        final absolute = _window.absolute(index);
        if (absolute == null || absolute >= _queue.items.length) return;
        await _playback.removeFromQueue(_queue.items[absolute].uid);
      });

  /// Replacing the whole queue from a session client is not supported; the
  /// in-app queue stays authoritative.
  @override
  Future<void> updateQueue(List<MediaItem> queue) async =>
      _log.fine('Ignoring updateQueue from a media session client');

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async =>
      _log.fine('Ignoring updateMediaItem from a media session client');

  QueueItem? _queueItemByUid(String uid) {
    for (final item in _queue.items) {
      if (item.uid == uid) return item;
    }
    return null;
  }

  Future<List<Track>> _tracksFor(List<MediaItem> items) async {
    final result = <Track>[];
    for (final item in items) {
      final queued = _queueItemByUid(item.id);
      if (queued != null) {
        result.add(queued.track);
        continue;
      }
      final trackId = item.extras?[MediaItemExtras.trackId] as String? ?? BrowseId.tryParse(item.id)?.trackId;
      if (trackId == null || trackId.isEmpty) continue;
      final track = await _tracks?.getTrack(trackId);
      if (track != null) result.add(track);
    }
    return result;
  }

  /// Stops mirroring. Does not stop playback.
  Future<void> dispose() async {
    _disposed = true;
    _clicks.dispose();
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }
}
