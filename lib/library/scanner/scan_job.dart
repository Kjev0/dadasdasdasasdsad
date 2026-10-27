import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show Transaction;

import '../../core/contracts/library.dart';
import '../../core/models/library.dart';
import '../../core/util/cancel_token.dart';
import '../change_bus.dart';
import '../db/database.dart';
import '../db/sql_utils.dart';
import 'file_enumerator.dart';
import 'local_file_store.dart';
import 'tag_reader.dart';

final _log = Logger('library.scanner');

/// `root` with exactly one trailing separator (prefix matching).
String withSeparator(String root) => root.endsWith(p.separator) ? root : '$root${p.separator}';

/// One run of the scanner over a set of library folders.
///
/// Phases: enumerate (background isolate) → diff against the database
/// (size + mtime) → parse new/changed files in batches (background isolate)
/// → detect moved files (same content hash) → mark/remove missing files.
class ScanJob {
  ScanJob({
    required this.db,
    required this.bus,
    required this.roots,
    required this.extensions,
    required this.artworkDir,
    required this.full,
    required this.batchSize,
    required this.emit,
    required this.cancel,
  });

  final FermataDatabase db;
  final LibraryChangeBus bus;
  final List<String> roots;
  final Set<String> extensions;
  final String artworkDir;
  final bool full;
  final int batchSize;
  final void Function(ScanProgress) emit;
  final CancelToken cancel;

  static const _maxErrors = 200;

  int _scanned = 0;
  int? _total;
  int _added = 0;
  int _updated = 0;
  int _removed = 0;
  final _errors = <String>[];

  /// Library folders (registered when the scan started) that were removed
  /// while the scan was running; their files must not be saved any more.
  Set<String> _registeredAtStart = const {};

  /// Roots (with trailing separator) that listed no files or failed while
  /// listing: a missing mount or a permission problem must not be treated as
  /// "every file was deleted".
  final _suspectRoots = <String>[];

  void _error(String e) {
    if (_errors.length < _maxErrors) _errors.add(e);
  }

  void _progress({String? current, bool done = false}) => emit(ScanProgress(
        scannedFiles: _scanned,
        totalFiles: _total,
        added: _added,
        updated: _updated,
        removed: _removed,
        currentPath: current,
        done: done,
        errors: List.unmodifiable(_errors),
      ));

  Future<void> run() async {
    final found = <String, FoundFile>{};
    final enumeratedRoots = <String>[];
    _registeredAtStart = {
      for (final r in await db.db.query('library_folders', columns: ['path'])) r['path'] as String,
    }..retainAll(roots);
    for (final root in roots) {
      cancel.throwIfCanceled();
      _progress(current: root);
      final result = await _enumerate(root, extensions);
      result.errors.forEach(_error);
      if (!Directory(root).existsSync()) {
        _log.warning('Library folder is not available; skipping missing-file detection for it');
        continue;
      }
      enumeratedRoots.add(withSeparator(root));
      if (result.files.isEmpty || result.errors.isNotEmpty) _suspectRoots.add(withSeparator(root));
      for (final f in result.files) {
        found[f.path] = f;
      }
    }
    _total = found.length;

    final existing = await LocalFileStore.rowsUnder(db.db, enumeratedRoots);
    final byPath = {for (final r in existing) r.path: r};
    final missingArt = await _missingArtwork(existing, artworkDir);

    final unchanged = <String>[];
    final toParse = <FoundFile>[];
    for (final f in found.values) {
      final row = byPath[f.path];
      final same = row != null &&
          row.size == f.size &&
          row.mtimeMs == f.mtimeMs &&
          !missingArt.contains(row.artworkUrl) &&
          !_folderArtChanged(row, f);
      if (same && !full) {
        if (row.missing) unchanged.add(row.id);
        _scanned++;
      } else {
        toParse.add(f);
      }
    }
    if (unchanged.isNotEmpty) await db.db.transaction((txn) => LocalFileStore.touch(txn, unchanged));
    _progress();

    final addedByHash = <String, String>{}; // hash -> new id (for move detection)
    for (var i = 0; i < toParse.length; i += batchSize) {
      cancel.throwIfCanceled();
      final batch = toParse.sublist(i, i + batchSize > toParse.length ? toParse.length : i + batchSize);
      final requests = [for (final f in batch) ParseRequest(f.path, f.size, f.mtimeMs, folderArt: f.folderArt)];
      final results = await _parse(requests, artworkDir);
      for (final r in results) {
        _scanned++;
        if (r.track == null) {
          _error('${r.path}: ${r.error ?? 'unreadable'}');
          continue;
        }
        if (r.tagError != null) _log.fine('Tags unreadable, used file name: ${r.tagError}');
        if (byPath.containsKey(r.path)) {
          _updated++;
        } else {
          _added++;
          if (r.hash != null) addedByHash[r.hash!] = r.track!.id;
        }
      }
      var allRemoved = false;
      await db.db.transaction((txn) async {
        final current = {for (final r in await txn.query('library_folders', columns: ['path'])) r['path'] as String};
        final removed = [for (final r in _registeredAtStart) if (!current.contains(r)) withSeparator(r)];
        allRemoved = removed.isNotEmpty && removed.length == roots.length;
        final keep = removed.isEmpty
            ? results
            : [for (final r in results) if (!removed.any(r.path.startsWith)) r];
        await LocalFileStore.saveScanned(txn, keep);
      });
      notifyLibrary(bus, {LibraryTopic.tracks});
      if (allRemoved) {
        cancel.cancel();
        cancel.throwIfCanceled();
      }
      _progress(current: batch.last.path);
    }

    cancel.throwIfCanceled();
    final gone = [for (final r in existing) if (!found.containsKey(r.path)) r];
    if (gone.isNotEmpty) await _handleGone(gone, addedByHash);
    if (addedByHash.isNotEmpty) await _adoptMissing(addedByHash);

    final now = nowMs();
    for (final root in enumeratedRoots) {
      final path = root.substring(0, root.length - p.separator.length);
      await db.db.update('library_folders', {'last_scanned_at': now}, where: 'path = ?', whereArgs: [path]);
    }
    notifyLibrary(bus, {LibraryTopic.tracks, LibraryTopic.folders});
    _progress(done: true);
  }

  /// Moved files keep their references; unreferenced missing files are
  /// removed, referenced ones are marked missing (shown as unavailable).
  Future<void> _handleGone(List<LocalRow> gone, Map<String, String> addedByHash) async {
    var changedRefs = false;
    await db.db.transaction((txn) async {
      final referenced = await LocalFileStore.referenced(txn, [for (final g in gone) g.id]);
      final now = nowMs();
      for (final g in gone) {
        var movedTo = g.hash == null ? null : addedByHash.remove(g.hash);
        // The file may already have been added by an earlier scan of another
        // library folder (watcher: one scan per changed root).
        movedTo ??= await _existingCopy(txn, g);
        if (movedTo != null) {
          await LocalFileStore.migrate(txn, g.id, movedTo);
          // Counted as an update of the moved track rather than add + remove.
          _added--;
          _updated++;
          changedRefs = true;
        } else if (referenced.contains(g.id) || _suspectRoots.any(g.path.startsWith)) {
          if (!g.missing) {
            await txn.update('tracks', {'missing_since': now}, where: 'id = ?', whereArgs: [g.id]);
            _removed++;
          }
        } else {
          await txn.delete('tracks', where: 'id = ?', whereArgs: [g.id]);
          if (!g.missing) _removed++;
        }
      }
    });
    notifyLibrary(bus, {
      LibraryTopic.tracks,
      if (changedRefs) ...{LibraryTopic.playlists, LibraryTopic.favorites, LibraryTopic.history, LibraryTopic.links},
    });
  }

  /// Another present local track with the content of [g] (a file moved here
  /// by an earlier scan), if its file exists.
  Future<String?> _existingCopy(Transaction txn, LocalRow g) async {
    if (g.hash == null) return null;
    final rows = await txn.rawQuery(
      "SELECT id, local_path FROM tracks WHERE source_id = 'local' AND file_hash = ? AND id <> ? AND missing_since IS NULL",
      [g.hash, g.id],
    );
    for (final r in rows) {
      final path = r['local_path'] as String?;
      if (path != null && path != g.path && File(path).existsSync()) return r['id'] as String;
    }
    return null;
  }

  /// Files added by this scan whose content matches a track that an earlier
  /// scan (of another library folder) marked missing: a move across folders.
  Future<void> _adoptMissing(Map<String, String> addedByHash) async {
    var changed = false;
    await db.db.transaction((txn) async {
      for (final e in addedByHash.entries) {
        final rows = await txn.rawQuery(
          "SELECT id FROM tracks WHERE source_id = 'local' AND file_hash = ? AND id <> ? AND missing_since IS NOT NULL LIMIT 1",
          [e.key, e.value],
        );
        if (rows.isEmpty) continue;
        await LocalFileStore.migrate(txn, rows.first['id'] as String, e.value);
        _added--;
        _updated++;
        changed = true;
      }
    });
    if (changed) {
      notifyLibrary(bus, {LibraryTopic.tracks, LibraryTopic.playlists, LibraryTopic.favorites, LibraryTopic.history, LibraryTopic.links});
    }
  }

  /// Whether the folder art next to [f] differs from what the stored track
  /// uses (new, replaced or removed cover); embedded artwork wins over it.
  bool _folderArtChanged(LocalRow row, FoundFile f) {
    final url = row.artworkUrl;
    if (url != null && url.startsWith('file:')) {
      try {
        if (p.isWithin(artworkDir, Uri.parse(url).toFilePath())) return false; // embedded
      } catch (_) {
        return true;
      }
    }
    final expected = f.folderArt == null ? null : Uri.file(f.folderArt!).toString();
    return url != expected;
  }

  static Future<EnumerationResult> _enumerate(String root, Set<String> extensions) =>
      Isolate.run(() => enumerateAudioFiles(root, extensions));

  static Future<List<ScannedFile>> _parse(List<ParseRequest> requests, String artworkDir) =>
      Isolate.run(() => parseAudioBatch(requests, artworkDir));

  /// Artwork URLs (in the artwork cache) whose file was deleted, e.g. by
  /// "clear artwork cache"; their tracks are re-read to restore the image.
  static Future<Set<String?>> _missingArtwork(List<LocalRow> rows, String artworkDir) {
    final urls = {
      for (final r in rows)
        if (r.artworkUrl != null && r.artworkUrl!.startsWith('file:')) r.artworkUrl!,
    }.toList();
    if (urls.isEmpty) return Future.value(<String?>{});
    return Isolate.run(() {
      final out = <String?>{};
      for (final u in urls) {
        try {
          if (!File(Uri.parse(u).toFilePath()).existsSync()) out.add(u);
        } catch (_) {
          out.add(u);
        }
      }
      return out;
    });
  }
}
