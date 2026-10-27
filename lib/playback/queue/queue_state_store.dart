import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('playback.persistence');

/// What the engine persists between runs.
class PersistedPlaybackState {
  const PersistedPlaybackState({required this.queue, required this.position, this.savedAt});

  /// [PlayQueue.toJson] output.
  final Map<String, Object?> queue;
  final Duration position;
  final DateTime? savedAt;

  static const version = 1;

  Map<String, Object?> toJson() => {
        'version': version,
        'savedAt': (savedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'positionMs': position.inMilliseconds,
        'queue': queue,
      };

  static PersistedPlaybackState? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final queue = raw['queue'];
    if (queue is! Map) return null;
    final ms = raw['positionMs'];
    return PersistedPlaybackState(
      queue: queue.cast<String, Object?>(),
      position: Duration(milliseconds: ms is num && ms >= 0 ? ms.toInt() : 0),
      savedAt: raw['savedAt'] is String ? DateTime.tryParse(raw['savedAt'] as String) : null,
    );
  }
}

/// JSON file with atomic writes (temp file + rename), serialized so an older
/// snapshot can never overwrite a newer one.
class QueueStateStore {
  QueueStateStore(this.file);

  final File file;
  Future<void> _chain = Future.value();

  Future<void> write(PersistedPlaybackState state) {
    final json = jsonEncode(state.toJson());
    return _chain = _chain.then((_) => _writeAtomic(json)).catchError((Object e, StackTrace st) {
      _log.warning('Could not persist playback state to ${file.path}', e, st);
    });
  }

  Future<void> _writeAtomic(String json) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(file.path);
  }

  /// Returns null when the file is missing or unreadable.
  Future<PersistedPlaybackState?> read() async {
    await _chain;
    try {
      if (!await file.exists()) return null;
      return PersistedPlaybackState.fromJson(jsonDecode(await file.readAsString()));
    } catch (e, st) {
      _log.warning('Ignoring unreadable playback state ${file.path}', e, st);
      return null;
    }
  }

  /// Completes when all pending writes are on disk.
  Future<void> flush() => _chain;
}
