import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('playback.persistence');

/// What the engine persists between runs.
class PersistedPlaybackState {
  const PersistedPlaybackState({
    required this.queue,
    required this.position,
    this.savedAt,
    this.encodedQueueFields = const {},
  });

  /// [PlayQueue.toJson] output (possibly without the fields that are given
  /// pre-encoded in [encodedQueueFields]).
  final Map<String, Object?> queue;
  final Duration position;
  final DateTime? savedAt;

  /// Already JSON-encoded values for keys of the `queue` object (e.g. the
  /// large `items` array), so periodic position saves of big queues do not
  /// re-encode thousands of tracks.
  final Map<String, String> encodedQueueFields;

  static const version = 1;

  String get _savedAtIso => (savedAt ?? DateTime.now()).toUtc().toIso8601String();

  Map<String, Object?> toJson() => {
        'version': version,
        'savedAt': _savedAtIso,
        'positionMs': position.inMilliseconds,
        'queue': {
          for (final e in encodedQueueFields.entries) e.key: jsonDecode(e.value),
          ...queue,
        },
      };

  /// The JSON document written to disk.
  String encode() {
    if (encodedQueueFields.isEmpty) return jsonEncode(toJson());
    final b = StringBuffer()
      ..write('{"version":$version,"savedAt":')
      ..write(jsonEncode(_savedAtIso))
      ..write(',"positionMs":${position.inMilliseconds},"queue":{');
    var first = true;
    void field(String key, String rawJson) {
      if (!first) b.write(',');
      first = false;
      b
        ..write(jsonEncode(key))
        ..write(':')
        ..write(rawJson);
    }

    encodedQueueFields.forEach(field);
    for (final e in queue.entries) {
      if (!encodedQueueFields.containsKey(e.key)) field(e.key, jsonEncode(e.value));
    }
    b.write('}}');
    return b.toString();
  }

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
    final json = state.encode();
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
