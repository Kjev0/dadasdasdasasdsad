import 'package:audio_service/audio_service.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/platform/android/fermata_audio_handler.dart';
import 'package:fermata/platform/android/media_browser.dart';
import 'package:fermata/platform/android/media_session_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  final a = track('a', title: 'Alpha', duration: const Duration(minutes: 3));
  final b = track('b', title: 'Beta', duration: const Duration(minutes: 4));
  final c = track('c', title: 'Gamma');
  final items = [qi('u1', a, origin: 'playlist:p'), qi('u2', b), qi('u3', c)];
  final queue = QueueState(items: items, currentIndex: 0, originLabel: 'Road trip');
  const icons = LikeControlIcons(liked: 'drawable/ic_fav', notLiked: 'drawable/ic_fav_border');

  late FakePlaybackController playback;
  late TestClock clock;
  late ManualTimers timers;
  late List<PlaybackState> states;
  late List<MediaItem?> mediaItems;
  late List<List<MediaItem>> queues;

  Future<FermataAudioHandler> create({
    FakeFavorites? favorites,
    MediaLibraryBrowser? browser,
    LikeControlIcons? likeIcons,
    FakeTracks? tracks,
  }) async {
    final h = FermataAudioHandler(
      playback: playback,
      favorites: favorites,
      browser: browser,
      tracks: tracks,
      likeIcons: likeIcons,
      now: clock.call,
      timerFactory: timers.call,
    );
    h.playbackState.listen(states.add);
    h.mediaItem.listen(mediaItems.add);
    h.queue.listen(queues.add);
    await settle();
    return h;
  }

  PlaybackSnapshot playingAt(Duration position, {QueueItem? current, bool playing = true, Duration? duration}) =>
      PlaybackSnapshot(
        current: current ?? items[0],
        playing: playing,
        status: PlayerStatus.ready,
        position: position,
        duration: duration ?? const Duration(minutes: 3),
      );

  setUp(() {
    clock = TestClock();
    timers = ManualTimers();
    states = [];
    mediaItems = [];
    queues = [];
    playback = FakePlaybackController(snapshot: playingAt(Duration.zero), queue: queue);
  });

  group('mirroring', () {
    test('publishes mediaItem, queue and playbackState from the controller at construction', () async {
      final h = await create();
      await settle();
      expect(mediaItems.last!.id, 'u1');
      expect(mediaItems.last!.title, 'Alpha');
      expect(mediaItems.last!.duration, const Duration(minutes: 3));
      expect(queues.last.map((m) => m.id), ['u1', 'u2', 'u3']);
      expect(h.queueTitle.value, 'Road trip');
      final st = states.last;
      expect(st.playing, isTrue);
      expect(st.processingState, AudioProcessingState.ready);
      expect(st.queueIndex, 0);
      expect(st.controls.map((c) => c.action), [MediaAction.skipToPrevious, MediaAction.pause, MediaAction.skipToNext]);
      expect(st.androidCompactActionIndices, [0, 1, 2]);
      await h.dispose();
    });

    test('4 Hz position ticks do not cause playbackState/mediaItem/queue updates', () async {
      final h = await create();
      await settle();
      final s0 = states.length, m0 = mediaItems.length, q0 = queues.length;
      for (var i = 1; i <= 40; i++) {
        clock.advance(const Duration(milliseconds: 250));
        playback.emitSnapshot(playingAt(Duration(milliseconds: 250 * i)));
      }
      await settle();
      expect(states.length, s0, reason: 'no update storm');
      expect(mediaItems.length, m0);
      expect(queues.length, q0);
      await h.dispose();
    });

    test('seek, pause, buffering and track changes are published', () async {
      final h = await create();
      await settle();
      var n = states.length;

      clock.advance(const Duration(seconds: 1));
      playback.emitSnapshot(playingAt(const Duration(seconds: 120)));
      await settle();
      expect(states.length, ++n);
      expect(states.last.updatePosition, const Duration(seconds: 120));
      expect(states.last.updateTime, clock.now);

      playback.emitSnapshot(playingAt(const Duration(seconds: 120), playing: false));
      await settle();
      expect(states.length, ++n);
      expect(states.last.playing, isFalse);
      expect(states.last.controls[1].action, MediaAction.play);

      playback.emitSnapshot(playingAt(const Duration(seconds: 120)).copyWith(status: PlayerStatus.buffering));
      await settle();
      expect(states.length, ++n);
      expect(states.last.processingState, AudioProcessingState.buffering);

      playback.emitQueue(QueueState(items: items, currentIndex: 1));
      playback.emitSnapshot(playingAt(Duration.zero, current: items[1], duration: const Duration(minutes: 4)));
      await settle();
      expect(states.last.queueIndex, 1);
      expect(mediaItems.last!.id, 'u2');
      expect(mediaItems.last!.duration, const Duration(minutes: 4));
      await h.dispose();
    });

    test('mediaItem is re-sent when the engine learns the duration', () async {
      playback = FakePlaybackController(
        snapshot: PlaybackSnapshot(current: items[2], status: PlayerStatus.loading),
        queue: QueueState(items: items, currentIndex: 2),
      );
      final h = await create();
      expect(mediaItems.last!.duration, isNull);
      final before = mediaItems.length;
      playback.emitSnapshot(PlaybackSnapshot(current: items[2], status: PlayerStatus.ready, duration: const Duration(seconds: 200)));
      await settle();
      expect(mediaItems.length, before + 1);
      expect(mediaItems.last!.duration, const Duration(seconds: 200));
      await h.dispose();
    });

    test('empty controller publishes no media item and idle state', () async {
      playback = FakePlaybackController();
      final h = await create();
      expect(mediaItems.last, isNull);
      expect(states.last.processingState, AudioProcessingState.idle);
      expect(states.last.queueIndex, isNull);
      expect(queues.last, isEmpty);
      await h.dispose();
    });

    test('large queues are published as a window; skipToQueueItem maps back', () async {
      final big = [for (var i = 0; i < 500; i++) qi('q$i', track('$i'))];
      playback = FakePlaybackController(
        snapshot: PlaybackSnapshot(current: big[200], playing: true, status: PlayerStatus.ready),
        queue: QueueState(items: big, currentIndex: 200),
      );
      final h = await create();
      expect(queues.last.length, 61);
      expect(queues.last.first.id, 'q190');
      expect(states.last.queueIndex, 10);
      await h.skipToQueueItem(0);
      await h.skipToQueueItem(60);
      await h.skipToQueueItem(61); // outside the window → ignored
      expect(playback.calls, ['skipToIndex:190', 'skipToIndex:250']);
      await h.dispose();
    });
  });

  group('commands are forwarded to the controller', () {
    test('transport', () async {
      final h = await create();
      await h.play();
      await h.pause();
      await h.seek(const Duration(seconds: 42));
      await h.seek(const Duration(seconds: -3));
      await h.skipToNext();
      await h.skipToPrevious();
      await h.skipToQueueItem(2);
      await h.fastForward();
      await h.rewind();
      await h.setShuffleMode(AudioServiceShuffleMode.all);
      await h.setShuffleMode(AudioServiceShuffleMode.none);
      await h.setRepeatMode(AudioServiceRepeatMode.one);
      await h.setRepeatMode(AudioServiceRepeatMode.group);
      await h.setSpeed(1.5);
      await h.setSpeed(4);
      expect(playback.calls, [
        'play',
        'pause',
        'seek:42000',
        'seek:0',
        'next',
        'previous',
        'skipToIndex:2',
        'seekRelative:15',
        'seekRelative:-15',
        'shuffle:true',
        'shuffle:false',
        'repeat:one',
        'repeat:all',
        'speed:1.5',
        'speed:2.0',
      ]);
      await h.dispose();
    });

    test('setSpeed is ignored when the backend does not support it', () async {
      playback.speedSupported = false;
      final h = await create();
      await h.setSpeed(1.5);
      expect(playback.calls, isEmpty);
      expect(states.last.systemActions.contains(MediaAction.setSpeed), isFalse);
      await h.dispose();
    });

    test('stop() stops the controller and publishes idle (releases the service)', () async {
      playback.goIdleOnStop = false; // even if the engine reports something else
      final h = await create();
      await h.stop();
      await settle();
      expect(playback.calls, ['stop']);
      expect(states.last.processingState, AudioProcessingState.idle);
      expect(states.last.playing, isFalse);
      await h.dispose();
    });

    test('controller failures are contained (no exception into the platform channel)', () async {
      final h = FermataAudioHandler(playback: _ThrowingController(playback), now: clock.call);
      await expectLater(h.play(), completes);
      await expectLater(h.skipToNext(), completes);
      await h.dispose();
    });
  });

  group('lifecycle callbacks', () {
    test('onTaskRemoved while playing keeps playing', () async {
      final h = await create();
      await h.onTaskRemoved();
      expect(playback.calls, isEmpty);
      await h.dispose();
    });

    test('onTaskRemoved while paused saves and stops', () async {
      playback = FakePlaybackController(snapshot: playingAt(const Duration(seconds: 5), playing: false), queue: queue);
      final h = await create();
      await h.onTaskRemoved();
      await settle();
      expect(playback.calls, ['save', 'stop']);
      expect(states.last.processingState, AudioProcessingState.idle);
      await h.dispose();
    });

    test('onNotificationDeleted stops', () async {
      final h = await create();
      await h.onNotificationDeleted();
      expect(playback.calls, ['stop']);
      await h.dispose();
    });
  });

  group('headset buttons', () {
    test('single press toggles after the multi-press window', () async {
      final h = await create();
      await h.click();
      expect(playback.calls, isEmpty);
      timers.fireAll();
      await settle();
      expect(playback.calls, ['toggle']);
      await h.dispose();
    });

    test('double press → next, triple press → previous', () async {
      final h = await create();
      await h.click(MediaButton.media);
      await h.click(MediaButton.media);
      timers.fireAll();
      await settle();
      expect(playback.calls, ['next']);
      playback.calls.clear();
      await h.click(MediaButton.media);
      await h.click(MediaButton.media);
      await h.click(MediaButton.media);
      await settle();
      expect(playback.calls, ['previous']);
      await h.dispose();
    });

    test('dedicated next/previous keys act immediately', () async {
      final h = await create();
      await h.click(MediaButton.next);
      await h.click(MediaButton.previous);
      expect(playback.calls, ['next', 'previous']);
      expect(timers.created, isEmpty);
      await h.dispose();
    });
  });

  group('like action', () {
    test('omitted without drawables; toggles favorites with drawables', () async {
      final favorites = FakeFavorites();
      final h = await create(favorites: favorites, likeIcons: icons);
      await settle();
      expect(states.last.controls.length, 4);
      expect(states.last.controls[3].androidIcon, 'drawable/ic_fav_border');

      await h.customAction(toggleLikeActionName);
      await settle();
      expect(favorites.setCalls, [('soundcloud:a', true)]);
      expect(states.last.controls[3].androidIcon, 'drawable/ic_fav');
      expect(mediaItems.last!.rating, const Rating.newHeartRating(true));

      await h.customAction(toggleLikeActionName);
      await settle();
      expect(favorites.setCalls.last, ('soundcloud:a', false));
      expect(states.last.controls[3].androidIcon, 'drawable/ic_fav_border');
      await h.dispose();

      states.clear();
      final noIcons = await create(favorites: FakeFavorites());
      expect(states.last.controls.length, 3);
      await noIcons.dispose();
    });

    test('heart rating from a client sets the favorite', () async {
      final favorites = FakeFavorites();
      final h = await create(favorites: favorites);
      await h.setRating(const Rating.newHeartRating(true));
      await h.setRating(const Rating.newThumbRating(true)); // ignored
      expect(favorites.setCalls, [('soundcloud:a', true)]);
      await h.dispose();
    });
  });

  group('browsing / Android Auto', () {
    test('resumption root returns the current queue item', () async {
      final h = await create();
      final recent = await h.getChildren(AudioService.recentRootId);
      expect(recent.single.id, 'u1');
      await h.dispose();
    });

    test('resumption root falls back to history when nothing is queued', () async {
      playback = FakePlaybackController();
      final h = await create(browser: MediaLibraryBrowser(history: FakeHistory([b])));
      final recent = await h.getChildren(AudioService.recentRootId);
      expect(recent.single.title, 'Beta');
      await h.dispose();
    });

    test('playFromMediaId with a queue uid jumps within the queue', () async {
      final h = await create();
      await h.playFromMediaId('u3');
      expect(playback.calls, ['skipToIndex:2', 'play']);
      await h.dispose();
    });

    test('playFromMediaId with a browse id queues the folder from that track', () async {
      final h = await create(browser: MediaLibraryBrowser(favorites: FakeFavorites([a, b, c])));
      final id = const BrowseId(BrowseKind.favorites).withTrack(b.id).toString();
      await h.playFromMediaId(id);
      expect(playback.calls, ['playTracks']);
      expect(playback.lastPlayedTracks, [a, b, c]);
      expect(playback.lastStartIndex, 1);
      expect(playback.lastOrigin, 'favorites');
      await h.dispose();
    });

    test('play() with nothing queued shuffles favorites', () async {
      playback = FakePlaybackController();
      final h = await create(browser: MediaLibraryBrowser(favorites: FakeFavorites([a, b])));
      await h.play();
      expect(playback.calls, ['playTracks']);
      expect(playback.lastShuffle, isTrue);
      await h.dispose();
    });

    test('playFromSearch queries the library', () async {
      final tracks = FakeTracks([a, b, c]);
      final h = await create(browser: MediaLibraryBrowser(tracks: tracks));
      await h.playFromSearch('gamma');
      expect(playback.lastPlayedTracks, [c]);
      expect(playback.lastOrigin, 'search');
      await h.dispose();
    });
  });

  group('queue edits from session clients', () {
    test('remove forwards the queue uid; updateQueue is ignored', () async {
      final h = await create();
      await h.removeQueueItemAt(1);
      await h.removeQueueItem(MediaItem(id: 'u3', title: 'Gamma'));
      await h.removeQueueItem(MediaItem(id: 'nope', title: 'x'));
      await h.updateQueue(const []);
      expect(playback.calls, ['remove:u2', 'remove:u3']);
      expect(queues.last.length, 3, reason: 'local queue never diverges from the controller');
      await h.dispose();
    });

    test('add/insert resolve tracks via extras and the track repository', () async {
      final d = track('d');
      final h = await create(tracks: FakeTracks([d]));
      final item = mediaItemForTrack(d, id: 'whatever');
      await h.addQueueItem(item);
      await h.insertQueueItem(1, item);
      await h.insertQueueItem(3, item);
      expect(playback.calls, ['enqueue:${d.id}', 'playNext:${d.id}', 'enqueue:${d.id}']);
      await h.dispose();
    });
  });
}

/// Controller whose commands all throw.
class _ThrowingController extends FakePlaybackController {
  _ThrowingController(FakePlaybackController base) : super(snapshot: base.snapshot, queue: base.queue);

  @override
  Future<void> play() async => throw StateError('boom');

  @override
  Future<void> next() async => throw StateError('boom');

  @override
  Future<void> playTracks(List<Track> tracks,
          {int startIndex = 0, String? origin, String? originLabel, bool shuffle = false, Duration? startPosition}) async =>
      throw StateError('boom');
}
