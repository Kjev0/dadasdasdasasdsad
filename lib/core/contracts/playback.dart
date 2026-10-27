import '../models/playback.dart';
import '../models/track.dart';
import '../util/cancel_token.dart';

/// The single source of truth for playback. Lives for the whole app
/// lifetime (independent of any page/widget), so navigation never stops audio.
///
/// Platform media sessions (Android audio_service, Linux MPRIS, Windows SMTC,
/// tray menu, hotkeys) are thin adapters that observe [snapshots]/[queue]
/// and call these methods.
abstract class PlaybackController {
  Future<void> init();

  PlaybackSnapshot get snapshot;

  /// Emits on every state change and ~4 Hz while playing.
  Stream<PlaybackSnapshot> get snapshots;

  QueueState get queue;
  Stream<QueueState> get queueStream;

  /// Discrete events (track started/ended, failures, queue ended).
  Stream<PlaybackEvent> get events;

  /// Replace the queue and start playing [tracks] at [startIndex].
  Future<void> playTracks(
    List<Track> tracks, {
    int startIndex = 0,
    String? origin,
    String? originLabel,
    bool shuffle = false,
    Duration? startPosition,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> togglePlayPause();

  /// Stop playback and release the audio device (queue is kept).
  Future<void> stop();
  Future<void> next();

  /// Restarts the current track when position > 3 s, otherwise goes back.
  Future<void> previous();
  Future<void> seek(Duration position);
  Future<void> seekRelative(Duration delta);
  Future<void> skipToIndex(int index);

  Future<void> setShuffle(bool enabled);
  Future<void> setRepeat(RepeatMode mode);
  Future<void> cycleRepeat();

  /// 0..1
  Future<void> setVolume(double volume);

  /// 0.5..2.0 where supported.
  Future<void> setSpeed(double speed);

  Future<void> enqueue(List<Track> tracks, {String? origin});
  Future<void> playNext(List<Track> tracks, {String? origin});
  Future<void> removeFromQueue(String uid);
  Future<void> moveQueueItem(int from, int to);

  /// Clears the queue; keeps the current item when [keepCurrent].
  Future<void> clearQueue({bool keepCurrent = true});

  /// [duration] null cancels. With [endOfTrack] playback pauses when the
  /// current track ends.
  Future<void> setSleepTimer(Duration? duration, {bool endOfTrack = false});

  bool get supportsSpeed;
  bool get supportsOutputDeviceSelection;
  Future<List<AudioOutputDevice>> outputDevices();
  Future<void> setOutputDevice(String deviceId);

  /// Persist queue + position immediately (also done automatically).
  Future<void> saveState();

  /// Stop, persist and release everything. Called on explicit Quit.
  Future<void> dispose();
}

/// Turns a [Track] into something playable. Order of preference:
/// 1. completed verified download, 2. user-owned local file,
/// 3. source stream (respecting availability), 4. a linked track on another
///    source (playlist-migration matches), ordered by provider preference.
abstract class StreamResolver {
  Future<ResolvedStream> resolve(Track track, {CancelToken? cancel});
}

class ResolvedStream {
  const ResolvedStream({required this.source, required this.playedTrack});

  final PlayableSource source;

  /// The track actually played (may be a linked substitute of the requested
  /// one, e.g. the SoundCloud match of an imported Spotify track).
  final Track playedTrack;
}
