import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'download_record.dart';

final _log = Logger('downloads.index');

/// Persistent task list: `<support>/downloads/index.json`.
///
/// Writes are atomic (temp file + flush + rename) with the previous version
/// kept as `index.json.bak`; a corrupt index falls back to the backup.
/// Saves are debounced and serialized; [flush] writes immediately.
class DownloadIndex {
  DownloadIndex(this.file, {this.debounce = const Duration(milliseconds: 400)});

  static const formatVersion = 1;

  final File file;
  final Duration debounce;

  Timer? _timer;
  List<DownloadRecord> Function()? _snapshot;
  Future<void> _chain = Future.value();

  File get backupFile => File('${file.path}.bak');

  /// Reads the index (or its backup). Malformed entries are skipped.
  Future<List<DownloadRecord>> load() async {
    return await _read(file) ?? await _read(backupFile) ?? <DownloadRecord>[];
  }

  Future<List<DownloadRecord>?> _read(File f) async {
    try {
      if (!await f.exists()) return null;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map || raw['tasks'] is! List) return null;
      final records = <DownloadRecord>[];
      for (final entry in raw['tasks'] as List) {
        try {
          records.add(DownloadRecord.fromJson((entry as Map).cast<String, Object?>()));
        } catch (e) {
          _log.warning('Skipping malformed download entry', e);
        }
      }
      return records;
    } catch (e) {
      _log.warning('Unreadable download index ${f.path}', e);
      return null;
    }
  }

  /// Schedules a save within [debounce] (throttled: further calls while a
  /// save is pending are coalesced); [snapshot] is evaluated at write time.
  void scheduleSave(List<DownloadRecord> Function() snapshot) {
    _snapshot = snapshot;
    if (_timer != null) return;
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(_enqueueWrite());
    });
  }

  /// Writes pending changes now.
  Future<void> flush([List<DownloadRecord> Function()? snapshot]) {
    if (snapshot != null) _snapshot = snapshot;
    _timer?.cancel();
    _timer = null;
    return _enqueueWrite();
  }

  Future<void> _enqueueWrite() {
    final snapshot = _snapshot;
    if (snapshot == null) return _chain;
    return _chain = _chain.then((_) => _write(snapshot())).catchError((Object e, StackTrace st) {
      _log.severe('Failed to persist download index', e, st);
    });
  }

  Future<void> _write(List<DownloadRecord> records) async {
    await file.parent.create(recursive: true);
    final json = jsonEncode({
      'version': formatVersion,
      'tasks': [for (final r in records) r.toJson()],
    });
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    if (await file.exists()) {
      try {
        await file.copy(backupFile.path);
      } on FileSystemException catch (e) {
        _log.fine('Could not refresh index backup', e);
      }
    }
    await tmp.rename(file.path);
  }

  void cancelPending() {
    _timer?.cancel();
    _timer = null;
  }
}
