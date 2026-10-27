import 'dart:async';
import 'dart:io';

import 'package:fermata/core/contracts/playback.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/playback/queue/queue_state_store.dart';

export 'fake_audio_backend.dart';

Track track(String id, {Duration? duration, double? rgTrack, double? rgAlbum, String source = 'local'}) => Track(
      sourceId: source,
      sourceTrackId: id,
      title: 'Title $id',
      artists: [ArtistRef('Artist $id')],
      duration: duration,
      replayGainTrackDb: rgTrack,
      replayGainAlbumDb: rgAlbum,
    );

/// URI the [FakeStreamResolver] returns by default for a track.
String uriOf(Track t) => 'file:///music/${t.sourceTrackId}.flac';

/// Programmable [StreamResolver].
class FakeStreamResolver implements StreamResolver {
  /// Per track id: a [PlayableSource], a [ResolvedStream] or an exception.
  final results = <String, Object>{};

  /// Optional per-call override (called before [results]).
  Object? Function(Track track, int call)? onResolve;

  final calls = <String>[];

  int callsFor(String trackId) => calls.where((c) => c == trackId).length;

  @override
  Future<ResolvedStream> resolve(Track track, {CancelToken? cancel}) async {
    calls.add(track.id);
    final n = callsFor(track.id);
    final r = onResolve?.call(track, n) ?? results[track.id];
    cancel?.throwIfCanceled();
    if (r is Exception) throw r;
    if (r is Error) throw r;
    if (r is ResolvedStream) return r;
    if (r is PlayableSource) return ResolvedStream(source: r, playedTrack: track);
    return ResolvedStream(
      source: PlayableSource(uri: Uri.parse(uriOf(track)), isLocalFile: true),
      playedTrack: track,
    );
  }

  void unplayable(Track t, [String reason = AvailabilityReason.regionRestricted]) =>
      results[t.id] = UnplayableTrackException(t.id, reason);
}

/// [QueueStateStore] keeping the state in memory (usable under fakeAsync).
class MemoryQueueStateStore extends QueueStateStore {
  MemoryQueueStateStore() : super(File('/nonexistent/fermata-test-state.json'));

  PersistedPlaybackState? saved;
  int writes = 0;

  @override
  Future<void> write(PersistedPlaybackState state) async {
    writes++;
    saved = state;
  }

  @override
  Future<PersistedPlaybackState?> read() async => saved;

  @override
  Future<void> flush() async {}
}
