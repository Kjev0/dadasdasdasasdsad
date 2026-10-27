import 'dart:async';

import '../core/contracts/matching.dart';
import '../core/models/catalog.dart';
import '../core/models/matching.dart';
import '../core/models/track.dart';
import '../core/util/cancel_token.dart';

/// Mutable in-memory state of one playlist import. Internal to
/// `PlaylistImportServiceImpl`; the outside world only sees immutable
/// [ImportSessionState] snapshots.
class MutableImportSession {
  MutableImportSession({
    required this.id,
    required this.source,
    required this.options,
    required this.progressInterval,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String id;
  final String source;
  final MatchOptions options;

  /// Minimum spacing of progress emissions while matching (phase changes
  /// are always emitted immediately). Zero emits every update.
  final Duration progressInterval;

  final cancelToken = CancelToken();
  final _controller = StreamController<ImportSessionState>.broadcast();
  final DateTime Function() _clock;
  Timer? _pendingEmit;

  ImportPhase _phase = ImportPhase.fetching;
  DateTime? _finishedAt;

  ImportPhase get phase => _phase;
  set phase(ImportPhase value) {
    _phase = value;
    _finishedAt = isTerminal ? (_finishedAt ?? _clock()) : null;
  }

  /// When the session reached done/failed/canceled (null while active).
  DateTime? get finishedAt => _finishedAt;

  Playlist? playlist;

  /// Original tracks in playlist order (may contain the same track twice).
  final List<Track> tracks = [];

  /// Whether the source playlist had more tracks than were imported (track
  /// cap, page cap, repeated cursor).
  bool truncated = false;

  /// Result per playlist position; null until that position is matched.
  List<TrackMatchResult?> results = const [];

  /// Track id → its playlist positions, in order of first occurrence (built
  /// by [prepareResults]).
  Map<String, List<int>> positionsByTrack = const {};
  int processed = 0;
  Object? error;
  String? savedPlaylistId;

  bool get isTerminal =>
      _phase == ImportPhase.done || _phase == ImportPhase.failed || _phase == ImportPhase.canceled;

  /// Sizes [results] to [tracks] and indexes the positions of every track.
  void prepareResults() {
    results = List<TrackMatchResult?>.filled(tracks.length, null);
    final positions = <String, List<int>>{};
    for (var i = 0; i < tracks.length; i++) {
      positions.putIfAbsent(tracks[i].id, () => []).add(i);
    }
    positionsByTrack = positions;
  }

  bool get isClosed => _controller.isClosed;

  ImportSessionState snapshot() => ImportSessionState(
        id: id,
        phase: phase,
        source: source,
        playlist: playlist,
        results: List.unmodifiable(results.nonNulls),
        total: phase == ImportPhase.fetching
            ? (playlist?.trackCount ?? 0) > tracks.length
                ? playlist!.trackCount!
                : tracks.length
            : tracks.length,
        processed: processed,
        error: error,
        savedPlaylistId: savedPlaylistId,
      );

  /// The current state followed by every later update.
  Stream<ImportSessionState> watch() => Stream.multi((listener) {
        listener.add(snapshot());
        if (_controller.isClosed) {
          listener.close();
          return;
        }
        final sub = _controller.stream.listen(listener.add, onError: listener.addError, onDone: listener.close);
        listener.onCancel = sub.cancel;
      });

  /// Publishes the current state; throttled to [progressInterval] unless
  /// [immediate].
  void emit({bool immediate = false}) {
    if (_controller.isClosed) return;
    if (immediate || progressInterval <= Duration.zero) {
      _pendingEmit?.cancel();
      _pendingEmit = null;
      _controller.add(snapshot());
      return;
    }
    _pendingEmit ??= Timer(progressInterval, () {
      _pendingEmit = null;
      if (!_controller.isClosed) _controller.add(snapshot());
    });
  }

  /// Positions of [trackId] in the playlist that already have a result.
  List<int> resultPositionsOf(String trackId) => [
        for (final p in positionsByTrack[trackId] ?? const <int>[])
          if (results[p] != null) p,
      ];

  /// Unique results (one per distinct original track), in playlist order.
  Iterable<TrackMatchResult> get uniqueResults sync* {
    for (final at in positionsByTrack.values) {
      final r = results[at.first];
      if (r != null) yield r;
    }
  }

  Future<void> close() async {
    _pendingEmit?.cancel();
    _pendingEmit = null;
    if (!_controller.isClosed) await _controller.close();
  }
}
