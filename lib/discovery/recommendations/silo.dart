import '../../core/models/track.dart';
import '../../core/sources/source_policies.dart';

/// Enforces the playback silo of siloed sources (SoundCloud API Terms): a
/// generated shelf/mix is either "one siloed source + local files" or
/// contains no siloed-source tracks at all.
abstract final class SiloGuard {
  static bool _siloed(Track t) => !t.isLocal && SourcePolicies.of(t.sourceId).siloedPlayback;

  /// Whether [tracks] already respect the silo rule.
  static bool isValid(Iterable<Track> tracks) {
    String? silo;
    var hasOpen = false;
    for (final t in tracks) {
      if (t.isLocal) continue;
      if (_siloed(t)) {
        if (silo != null && silo != t.sourceId) return false;
        silo = t.sourceId;
      } else {
        hasOpen = true;
      }
    }
    return !(silo != null && hasOpen);
  }

  /// Picks one consistent group from ranked [tracks], keeping their order:
  ///
  /// * the open group (every non-siloed source + local files), or
  /// * one siloed source + local files.
  ///
  /// With [preferSiloed] (e.g. `services.preferSoundCloudInDiscovery`) the
  /// largest siloed group wins as soon as it has [minSiloTracks] remote
  /// tracks; otherwise the larger group wins (ties → open group).
  static List<Track> apply(List<Track> tracks, {bool preferSiloed = false, int minSiloTracks = 5}) {
    final silos = <String, int>{};
    for (final t in tracks) {
      if (_siloed(t)) silos[t.sourceId] = (silos[t.sourceId] ?? 0) + 1;
    }
    if (silos.isEmpty) return tracks;
    final locals = tracks.where((t) => t.isLocal).length;
    final openCount = tracks.where((t) => !_siloed(t)).length;
    final best = silos.entries.reduce((a, b) => b.value > a.value ? b : a);
    final useSilo = (preferSiloed && best.value >= minSiloTracks) || best.value + locals > openCount;
    return useSilo ? restrictTo(tracks, best.key) : tracks.where((t) => !_siloed(t)).toList();
  }

  /// Keeps only tracks that may play in a queue whose silo is [silo]
  /// (`null` = open queue), see [SourcePolicies.canJoinSilo].
  static List<Track> restrictTo(Iterable<Track> tracks, String? silo) =>
      [for (final t in tracks) if (SourcePolicies.canJoinSilo(silo, t.sourceId)) t];
}
