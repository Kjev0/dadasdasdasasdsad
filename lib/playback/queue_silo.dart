import 'package:logging/logging.dart';

import '../core/sources/source_ids.dart';
import '../core/sources/source_policies.dart';

final _log = Logger('playback.silo');

/// Enforces provider terms that forbid mixing streams across services in one
/// playback queue (SoundCloud API Terms — see docs/COMPLIANCE.md).
///
/// Shared by [StreamResolverImpl] (which consults and commits it) and
/// [PlaybackControllerImpl] (which resets it whenever a new queue starts).
/// A queue starts undetermined; the first non-local stream that resolves
/// fixes it as either that siloed source's queue (e.g. SoundCloud) or an open
/// queue. Local files and downloads are always allowed.
class QueueSilo {
  bool _determined = false;
  String? _silo;

  /// The siloed source this queue is bound to, or null for an open (or not
  /// yet determined) queue.
  String? get current => _silo;

  bool get isDetermined => _determined;

  /// Whether a stream from [sourceId] may play in the current queue.
  bool allows(String sourceId) {
    if (sourceId == SourceIds.local) return true;
    if (!_determined) return true;
    return SourcePolicies.canJoinSilo(_silo, sourceId);
  }

  /// Records that a stream from [sourceId] is about to play.
  void commit(String sourceId) {
    if (_determined || sourceId == SourceIds.local) return;
    _determined = true;
    _silo = SourcePolicies.of(sourceId).siloedPlayback ? sourceId : null;
    _log.fine('Queue silo fixed: ${_silo ?? 'open'}');
  }

  /// A new queue begins (play tracks / clear queue).
  void reset() {
    _determined = false;
    _silo = null;
  }
}
