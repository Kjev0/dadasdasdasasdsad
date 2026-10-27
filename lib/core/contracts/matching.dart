import '../models/catalog.dart';
import '../models/matching.dart';
import '../models/track.dart';
import '../util/cancel_token.dart';

/// Pure scoring of one candidate against an original. Deterministic and
/// side-effect free (unit-testable without network).
abstract class TrackScorer {
  MatchCandidate score(Track original, Track candidate);
}

/// Finds candidates for an original track on other sources (ISRC lookup
/// first, then metadata searches) and decides auto-accept / review / not found.
abstract class TrackMatcher {
  Future<TrackMatchResult> findMatches(Track original, MatchOptions options, {CancelToken? cancel});
}

enum ImportPhase { fetching, matching, reviewing, saving, done, failed, canceled }

/// Live state of a playlist import (drives the import + review screens).
class ImportSessionState {
  const ImportSessionState({
    required this.id,
    required this.phase,
    required this.source,
    required this.results,
    required this.total,
    required this.processed,
    this.playlist,
    this.error,
    this.savedPlaylistId,
  });

  final String id;
  final ImportPhase phase;

  /// Source the playlist is imported from.
  final String source;
  final Playlist? playlist;
  final List<TrackMatchResult> results;
  final int total;
  final int processed;
  final Object? error;

  /// Local playlist created when the import was saved.
  final String? savedPlaylistId;

  int count(MatchDecision d) => results.where((r) => r.decision == d).length;
}

/// Orchestrates "import a playlist from source X and find each track on
/// sources Y, Z". Results are persisted as a local playlist containing the
/// original tracks plus track links to every accepted match, so the same
/// logical track can carry several provider matches.
abstract class PlaylistImportService {
  /// Start importing [playlistIdOrUrl] from [sourceId]. Returns the session id.
  Future<String> start({required String sourceId, required String playlistIdOrUrl, required MatchOptions options});

  /// Import an already-fetched list (e.g. liked tracks or an M3U file).
  Future<String> startWithTracks({
    required String sourceId,
    required String name,
    required List<Track> tracks,
    required MatchOptions options,
  });

  Stream<ImportSessionState> watch(String sessionId);
  ImportSessionState? current(String sessionId);

  /// Review actions.
  void accept(String sessionId, String originalTrackId, MatchCandidate candidate);
  void reject(String sessionId, String originalTrackId);
  void skip(String sessionId, String originalTrackId);

  /// Accept every result whose best candidate meets [minConfidence] and has
  /// no significant version difference.
  void acceptAllAtLeast(String sessionId, MatchConfidence minConfidence);

  /// Manual search for alternatives for one track (user-typed query).
  Future<List<MatchCandidate>> searchAlternatives(String sessionId, String originalTrackId, String query,
      {String? sourceId, CancelToken? cancel});

  /// Persist as a local playlist (+ track links). Returns the playlist id.
  Future<String> save(String sessionId, {String? playlistName});

  void cancel(String sessionId);
}
