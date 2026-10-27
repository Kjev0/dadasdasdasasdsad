import 'package:audio_service/audio_service.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/platform/android/media_session_labels.dart';
import 'package:fermata/platform/android/media_session_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  final now = DateTime(2026, 3, 1, 10);
  const icons = LikeControlIcons(liked: 'drawable/ic_fav', notLiked: 'drawable/ic_fav_border');

  group('MediaItem mapping', () {
    test('queue item → MediaItem with uid id, artist line, album, duration, art and extras', () {
      final t = track('42',
          title: 'Blue',
          artists: ['Ann', 'Bo'],
          album: 'Sky',
          duration: const Duration(minutes: 3),
          art: Uri.parse('https://img.example/a.jpg'));
      final item = mediaItemForQueueItem(qi('u1', t, origin: 'playlist:p1'));
      expect(item.id, 'u1');
      expect(item.title, 'Blue');
      expect(item.artist, 'Ann, Bo');
      expect(item.album, 'Sky');
      expect(item.duration, const Duration(minutes: 3));
      expect(item.artUri, Uri.parse('https://img.example/a.jpg'));
      expect(item.playable, isTrue);
      expect(item.extras, {
        MediaItemExtras.trackId: 'soundcloud:42',
        MediaItemExtras.sourceId: 'soundcloud',
        MediaItemExtras.origin: 'playlist:p1',
      });
    });

    test('engine duration overrides metadata; preview flag lands in extras', () {
      final t = track('1', duration: const Duration(minutes: 4));
      final item = mediaItemForQueueItem(qi('u', t), duration: const Duration(seconds: 30), isPreview: true);
      expect(item.duration, const Duration(seconds: 30));
      expect(item.extras![MediaItemExtras.preview], isTrue);
    });

    test('empty artist list yields null artist', () {
      expect(mediaItemForQueueItem(qi('u', track('1', artists: const []))).artist, isNull);
    });

    test('art URIs: http(s)/file/content kept, bare paths → file://, others dropped', () {
      Uri? art(String s) => artUriFor(track('1', art: Uri.parse(s)));
      expect(art('http://a/b.png'), Uri.parse('http://a/b.png'));
      expect(art('file:///music/cover.jpg'), Uri.parse('file:///music/cover.jpg'));
      expect(art('content://media/external/images/1'), Uri.parse('content://media/external/images/1'));
      expect(art('/sdcard/Music/cover.jpg'), Uri.file('/sdcard/Music/cover.jpg'));
      expect(art('data:image/png;base64,AAAA'), isNull);
      expect(art('relative/cover.jpg'), isNull);
      expect(artUriFor(track('1')), isNull);
    });

    test('mediaItemKey changes when the duration becomes known (MediaItem == compares ids only)', () {
      final t = track('1');
      final a = mediaItemForQueueItem(qi('u', t));
      final b = mediaItemForQueueItem(qi('u', t), duration: const Duration(minutes: 2));
      expect(a == b, isTrue);
      expect(mediaItemKey(a) == mediaItemKey(b), isFalse);
      expect(mediaItemKey(a), mediaItemKey(mediaItemForQueueItem(qi('u', t))));
    });
  });

  group('enum mapping', () {
    test('PlayerStatus → AudioProcessingState covers every status', () {
      expect({for (final s in PlayerStatus.values) s: processingStateFor(s)}, {
        PlayerStatus.idle: AudioProcessingState.idle,
        PlayerStatus.loading: AudioProcessingState.loading,
        PlayerStatus.buffering: AudioProcessingState.buffering,
        PlayerStatus.ready: AudioProcessingState.ready,
        PlayerStatus.completed: AudioProcessingState.completed,
        PlayerStatus.error: AudioProcessingState.error,
      });
    });

    test('repeat round-trips; group → all', () {
      for (final m in RepeatMode.values) {
        expect(repeatModeFromSession(repeatModeToSession(m)), m);
      }
      expect(repeatModeFromSession(AudioServiceRepeatMode.group), RepeatMode.all);
    });

    test('shuffle round-trips; group counts as shuffled', () {
      expect(shuffleModeToSession(true), AudioServiceShuffleMode.all);
      expect(shuffleModeToSession(false), AudioServiceShuffleMode.none);
      expect(shuffleFromSession(AudioServiceShuffleMode.group), isTrue);
      expect(shuffleFromSession(AudioServiceShuffleMode.none), isFalse);
    });
  });

  group('controls', () {
    test('prev, play/pause, next; compact indices 0,1,2', () {
      final paused = controlsFor(playing: false, labels: MediaSessionLabels.en);
      expect(paused.map((c) => c.action), [MediaAction.skipToPrevious, MediaAction.play, MediaAction.skipToNext]);
      final playing = controlsFor(playing: true, labels: MediaSessionLabels.en);
      expect(playing.map((c) => c.action), [MediaAction.skipToPrevious, MediaAction.pause, MediaAction.skipToNext]);
      expect(compactActionIndices, [0, 1, 2]);
      // Default audio_service drawables are kept.
      expect(playing[1].androidIcon, MediaControl.pause.androidIcon);
    });

    test('labels are localized', () {
      final da = controlsFor(playing: true, labels: MediaSessionLabels.da);
      expect(da.map((c) => c.label), ['Forrige', 'Pause', 'Næste']);
    });

    test('like action only when drawables are configured; icon/label follow liked state', () {
      expect(controlsFor(playing: true, labels: MediaSessionLabels.en).length, 3);
      final notLiked = controlsFor(playing: true, labels: MediaSessionLabels.en, likeIcons: icons);
      expect(notLiked.length, 4);
      expect(notLiked[3].action, MediaAction.custom);
      expect(notLiked[3].customAction!.name, toggleLikeActionName);
      expect(notLiked[3].androidIcon, 'drawable/ic_fav_border');
      expect(notLiked[3].label, MediaSessionLabels.en.like);
      final liked = controlsFor(playing: true, labels: MediaSessionLabels.en, likeIcons: icons, liked: true);
      expect(liked[3].androidIcon, 'drawable/ic_fav');
      expect(liked[3].label, MediaSessionLabels.en.unlike);
    });

    test('system actions; setSpeed only when supported', () {
      expect(systemActionsFor(), {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToQueueItem,
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
        MediaAction.setSpeed,
      });
      expect(systemActionsFor(supportsSpeed: false).contains(MediaAction.setSpeed), isFalse);
    });
  });

  group('playbackStateFor', () {
    test('maps every field of the snapshot', () {
      final s = PlaybackSnapshot(
        current: qi('u', track('1')),
        playing: true,
        status: PlayerStatus.buffering,
        position: const Duration(seconds: 12),
        bufferedPosition: const Duration(seconds: 40),
        speed: 1.25,
        shuffle: true,
        repeat: RepeatMode.one,
      );
      final st = playbackStateFor(snapshot: s, queueIndex: 3, labels: MediaSessionLabels.en, now: now);
      expect(st.processingState, AudioProcessingState.buffering);
      expect(st.playing, isTrue);
      expect(st.updatePosition, const Duration(seconds: 12));
      expect(st.bufferedPosition, const Duration(seconds: 40));
      expect(st.speed, 1.25);
      expect(st.updateTime, now);
      expect(st.queueIndex, 3);
      expect(st.shuffleMode, AudioServiceShuffleMode.all);
      expect(st.repeatMode, AudioServiceRepeatMode.one);
      expect(st.androidCompactActionIndices, [0, 1, 2]);
      expect(st.controls[1].action, MediaAction.pause);
      expect(st.errorMessage, isNull);
    });

    test('error status carries the message', () {
      const s = PlaybackSnapshot(status: PlayerStatus.error, errorMessage: 'Track unavailable');
      final st = playbackStateFor(snapshot: s, queueIndex: null, labels: MediaSessionLabels.en, now: now);
      expect(st.processingState, AudioProcessingState.error);
      expect(st.errorMessage, 'Track unavailable');
      expect(st.errorCode, isNotNull);
    });
  });

  group('shouldPublishState (no update storm)', () {
    PlaybackState stateAt(Duration pos, DateTime at, {bool playing = true, PlayerStatus status = PlayerStatus.ready}) =>
        playbackStateFor(
          snapshot: PlaybackSnapshot(playing: playing, status: status, position: pos),
          queueIndex: 0,
          labels: MediaSessionLabels.en,
          now: at,
        );

    test('first state is always published', () {
      expect(shouldPublishState(null, stateAt(Duration.zero, now), now: now), isTrue);
    });

    test('regular position ticks while playing are not published', () {
      final last = stateAt(const Duration(seconds: 10), now);
      for (var i = 1; i <= 40; i++) {
        final t = now.add(Duration(milliseconds: 250 * i));
        final next = stateAt(Duration(milliseconds: 10000 + 250 * i), t);
        expect(shouldPublishState(last, next, now: t), isFalse, reason: 'tick $i');
      }
    });

    test('a seek (position jump) is published', () {
      final last = stateAt(const Duration(seconds: 10), now);
      final t = now.add(const Duration(seconds: 1));
      expect(shouldPublishState(last, stateAt(const Duration(seconds: 90), t), now: t), isTrue);
    });

    test('a stall while "playing" is published once drift exceeds the tolerance', () {
      final last = stateAt(const Duration(seconds: 10), now);
      final t = now.add(const Duration(seconds: 3));
      expect(shouldPublishState(last, stateAt(const Duration(seconds: 10), t), now: t), isTrue);
    });

    test('paused position is static; seeking while paused is published', () {
      final last = stateAt(const Duration(seconds: 10), now, playing: false);
      final t = now.add(const Duration(seconds: 30));
      expect(shouldPublishState(last, stateAt(const Duration(seconds: 10), t, playing: false), now: t), isFalse);
      expect(shouldPublishState(last, stateAt(const Duration(seconds: 50), t, playing: false), now: t), isTrue);
    });

    test('discrete changes are published', () {
      final last = stateAt(const Duration(seconds: 10), now);
      expect(shouldPublishState(last, stateAt(const Duration(seconds: 10), now, playing: false), now: now), isTrue);
      expect(
          shouldPublishState(last, stateAt(const Duration(seconds: 10), now, status: PlayerStatus.buffering), now: now),
          isTrue);
      final withIndex = playbackStateFor(
        snapshot: const PlaybackSnapshot(playing: true, status: PlayerStatus.ready, position: Duration(seconds: 10)),
        queueIndex: 1,
        labels: MediaSessionLabels.en,
        now: now,
      );
      expect(shouldPublishState(last, withIndex, now: now), isTrue);
      final liked = playbackStateFor(
        snapshot: const PlaybackSnapshot(playing: true, status: PlayerStatus.ready, position: Duration(seconds: 10)),
        queueIndex: 0,
        labels: MediaSessionLabels.en,
        now: now,
        likeIcons: icons,
        liked: true,
      );
      final unliked = playbackStateFor(
        snapshot: const PlaybackSnapshot(playing: true, status: PlayerStatus.ready, position: Duration(seconds: 10)),
        queueIndex: 0,
        labels: MediaSessionLabels.en,
        now: now,
        likeIcons: icons,
      );
      expect(shouldPublishState(unliked, liked, now: now), isTrue);
    });

    test('extrapolation honours speed', () {
      final last = playbackStateFor(
        snapshot: const PlaybackSnapshot(playing: true, status: PlayerStatus.ready, position: Duration(seconds: 10), speed: 2),
        queueIndex: 0,
        labels: MediaSessionLabels.en,
        now: now,
      );
      expect(extrapolatedPosition(last, now.add(const Duration(seconds: 5))), const Duration(seconds: 20));
    });
  });

  group('QueueWindow', () {
    test('small queues are published whole', () {
      expect(QueueWindow.around(length: 30, currentIndex: 12), const QueueWindow(0, 30));
      expect(QueueWindow.around(length: 0, currentIndex: -1), QueueWindow.empty);
    });

    test('large queues are windowed around the current item and shifted at the edges', () {
      expect(QueueWindow.around(length: 5000, currentIndex: 2000), const QueueWindow(1990, 2051));
      expect(QueueWindow.around(length: 5000, currentIndex: 3), const QueueWindow(0, 61));
      expect(QueueWindow.around(length: 5000, currentIndex: 4999), const QueueWindow(4939, 5000));
      expect(QueueWindow.around(length: 5000, currentIndex: -1), const QueueWindow(0, 61));
    });

    test('relative/absolute index conversion', () {
      const w = QueueWindow(100, 161);
      expect(w.relative(100), 0);
      expect(w.relative(160), 60);
      expect(w.relative(161), isNull);
      expect(w.relative(99), isNull);
      expect(w.absolute(5), 105);
      expect(w.absolute(61), isNull);
      expect(w.absolute(-1), isNull);
    });
  });

  test('MediaSessionLabels.forLocale', () {
    expect(MediaSessionLabels.forLocale('da'), same(MediaSessionLabels.da));
    expect(MediaSessionLabels.forLocale('da_DK'), same(MediaSessionLabels.da));
    expect(MediaSessionLabels.forLocale('da-DK.UTF-8'), same(MediaSessionLabels.da));
    expect(MediaSessionLabels.forLocale('en_US'), same(MediaSessionLabels.en));
    expect(MediaSessionLabels.forLocale(null), same(MediaSessionLabels.en));
    expect(MediaSessionLabels.en.trackCount(1), '1 track');
    expect(MediaSessionLabels.da.trackCount(12), '12 numre');
  });
}
