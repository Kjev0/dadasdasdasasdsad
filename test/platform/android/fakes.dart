import 'dart:async';

import 'package:fermata/core/contracts/library.dart';
import 'package:fermata/core/contracts/playback.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';

Track track(String id, {String title = 'Song', List<String> artists = const ['Artist'], String? album, Duration? duration, Uri? art}) =>
    Track(
      sourceId: 'soundcloud',
      sourceTrackId: id,
      title: title,
      artists: [for (final a in artists) ArtistRef(a)],
      album: album,
      duration: duration,
      artworkUrl: art,
      availability: const TrackAvailability(playback: PlaybackRights.full, offline: OfflineRights.streamOnly),
    );

QueueItem qi(String uid, Track t, {String? origin}) => QueueItem(uid: uid, track: t, origin: origin);

/// Records every call; state is pushed by the test via [emitSnapshot] /
/// [emitQueue].
class FakePlaybackController implements PlaybackController {
  FakePlaybackController({this._snapshot = const PlaybackSnapshot(), this._queue = const QueueState.empty()});

  final calls = <String>[];
  final _snapshots = StreamController<PlaybackSnapshot>.broadcast(sync: true);
  final _queues = StreamController<QueueState>.broadcast(sync: true);
  final _events = StreamController<PlaybackEvent>.broadcast(sync: true);
  PlaybackSnapshot _snapshot;
  QueueState _queue;
  bool speedSupported = true;
  List<Track>? lastPlayedTracks;
  int? lastStartIndex;
  String? lastOrigin;
  String? lastOriginLabel;
  bool? lastShuffle;

  /// When set, the fake emits an idle snapshot on stop() like a real engine.
  bool goIdleOnStop = true;

  void emitSnapshot(PlaybackSnapshot s) {
    _snapshot = s;
    _snapshots.add(s);
  }

  void emitQueue(QueueState q) {
    _queue = q;
    _queues.add(q);
  }

  @override
  Future<void> init() async {}

  @override
  PlaybackSnapshot get snapshot => _snapshot;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  QueueState get queue => _queue;

  @override
  Stream<QueueState> get queueStream => _queues.stream;

  @override
  Stream<PlaybackEvent> get events => _events.stream;

  @override
  Future<void> playTracks(List<Track> tracks,
      {int startIndex = 0, String? origin, String? originLabel, bool shuffle = false, Duration? startPosition}) async {
    calls.add('playTracks');
    lastPlayedTracks = tracks;
    lastStartIndex = startIndex;
    lastOrigin = origin;
    lastOriginLabel = originLabel;
    lastShuffle = shuffle;
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> togglePlayPause() async => calls.add('toggle');

  @override
  Future<void> stop() async {
    calls.add('stop');
    if (goIdleOnStop) emitSnapshot(_snapshot.copyWith(playing: false, status: PlayerStatus.idle));
  }

  @override
  Future<void> next() async => calls.add('next');

  @override
  Future<void> previous() async => calls.add('previous');

  @override
  Future<void> seek(Duration position) async => calls.add('seek:${position.inMilliseconds}');

  @override
  Future<void> seekRelative(Duration delta) async => calls.add('seekRelative:${delta.inSeconds}');

  @override
  Future<void> skipToIndex(int index) async => calls.add('skipToIndex:$index');

  @override
  Future<void> setShuffle(bool enabled) async => calls.add('shuffle:$enabled');

  @override
  Future<void> setRepeat(RepeatMode mode) async => calls.add('repeat:${mode.name}');

  @override
  Future<void> cycleRepeat() async => calls.add('cycleRepeat');

  @override
  Future<void> setVolume(double volume) async => calls.add('volume:$volume');

  @override
  Future<void> setSpeed(double speed) async => calls.add('speed:$speed');

  @override
  Future<void> enqueue(List<Track> tracks, {String? origin}) async =>
      calls.add('enqueue:${tracks.map((t) => t.id).join(',')}');

  @override
  Future<void> playNext(List<Track> tracks, {String? origin}) async =>
      calls.add('playNext:${tracks.map((t) => t.id).join(',')}');

  @override
  Future<void> removeFromQueue(String uid) async => calls.add('remove:$uid');

  @override
  Future<void> moveQueueItem(int from, int to) async => calls.add('move:$from:$to');

  @override
  Future<void> clearQueue({bool keepCurrent = true}) async => calls.add('clear');

  @override
  Future<void> setSleepTimer(Duration? duration, {bool endOfTrack = false}) async => calls.add('sleep');

  @override
  bool get supportsSpeed => speedSupported;

  @override
  bool get supportsOutputDeviceSelection => false;

  @override
  Future<List<AudioOutputDevice>> outputDevices() async => const [];

  @override
  Future<void> setOutputDevice(String deviceId) async {}

  @override
  Future<void> saveState() async => calls.add('save');

  @override
  Future<void> dispose() async {
    await _snapshots.close();
    await _queues.close();
    await _events.close();
  }
}

class FakeFavorites implements FavoritesRepository {
  FakeFavorites([Iterable<Track> initial = const []]) : _tracks = [...initial];

  final List<Track> _tracks;
  final _ids = StreamController<Set<String>>.broadcast(sync: true);
  final setCalls = <(String, bool)>[];

  Set<String> get ids => {for (final t in _tracks) t.id};

  @override
  Future<bool> isFavorite(String trackId) async => ids.contains(trackId);

  @override
  Future<void> setFavorite(Track track, bool favorite) async {
    setCalls.add((track.id, favorite));
    _tracks.removeWhere((t) => t.id == track.id);
    if (favorite) _tracks.add(track);
    _ids.add(ids);
  }

  @override
  Future<List<Track>> favorites() async => List.of(_tracks);

  @override
  Stream<Set<String>> watchFavoriteIds() async* {
    yield ids;
    yield* _ids.stream;
  }
}

class FakeHistory implements HistoryRepository {
  FakeHistory(this.recent);

  final List<Track> recent;

  @override
  Future<List<Track>> recentlyPlayed({int limit = 30}) async => recent.take(limit).toList();

  @override
  Future<void> clearHistory() async {}

  @override
  Future<List<PlayRecord>> history({int limit = 200, DateTime? before}) async => const [];

  @override
  Future<int> playCount(String trackId) async => 0;

  @override
  Future<void> recordPlay(PlayRecord record) async {}

  @override
  Future<ListeningStats> stats({DateTime? since}) => throw UnimplementedError();
}

class FakePlaylists implements PlaylistRepository {
  FakePlaylists(this.lists, this.tracksById);

  final List<Playlist> lists;
  final Map<String, List<Track>> tracksById;

  @override
  Future<List<Playlist>> playlists() async => lists;

  @override
  Future<Playlist?> getPlaylist(String id) async {
    for (final p in lists) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<List<Track>> playlistTracks(String id) async => tracksById[id] ?? const [];

  @override
  Future<List<String>> playlistTrackIds(String id) async => [for (final t in tracksById[id] ?? const <Track>[]) t.id];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class FakeTracks implements TrackRepository {
  FakeTracks(this.all);

  final List<Track> all;
  TrackQuery? lastQuery;

  @override
  Future<Track?> getTrack(String id) async {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<List<Track>> query(TrackQuery query) async {
    lastQuery = query;
    final text = query.text?.toLowerCase() ?? '';
    return all.where((t) => t.title.toLowerCase().contains(text) || t.artistLine.toLowerCase().contains(text)).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

/// Timer that only fires when the test calls [fire].
class ManualTimer implements Timer {
  ManualTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

class ManualTimers {
  final created = <ManualTimer>[];

  Timer call(Duration d, void Function() cb) {
    final t = ManualTimer(d, cb);
    created.add(t);
    return t;
  }

  void fireAll() {
    for (final t in List.of(created)) {
      t.fire();
    }
  }

  int get active => created.where((t) => t.isActive).length;
}

/// A clock the test advances manually.
class TestClock {
  TestClock([DateTime? start]) : now = start ?? DateTime(2026, 1, 1, 12);

  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
}
