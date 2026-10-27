import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../core/contracts/library.dart';
import '../../core/errors.dart';
import '../../core/models/library.dart';
import '../../core/models/track.dart';
import '../../core/platform/app_paths.dart';
import '../../core/platform/platform_info.dart';
import '../../core/util/cancel_token.dart';
import '../change_bus.dart';
import '../db/database.dart';
import '../db/sql_utils.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/track_codec.dart';
import '../repositories/track_store.dart';
import 'audio_formats.dart';
import 'folder_watcher.dart';
import 'local_file_store.dart';
import 'm3u.dart';
import 'scan_job.dart';
import 'tag_reader.dart';
import 'tag_writer.dart';

final _log = Logger('library.local');

/// Local folders: scanning, watching (desktop), tag reading/writing, M3U.
///
/// Scans run one at a time (requests queue up); each scan's stream ends
/// with a `done` progress event. Cancelling the stream subscription stops
/// the scan after the current batch.
class LocalLibraryServiceImpl implements LocalLibraryService {
  LocalLibraryServiceImpl(
    this._db,
    this._tracks,
    this._paths,
    this._bus,
    this._platform, {
    PlaylistRepository? playlists,
    Duration watchDebounce = const Duration(seconds: 2),
    this.batchSize = 32,
    DirectoryWatcherFactory? watcherFactory,
  }) : _playlists = playlists ?? SqlPlaylistRepository(_db, _bus) {
    _extensions = scannableExtensions(_platform);
    _watcher = LibraryFolderWatcher(
      extensions: _extensions,
      debounce: watchDebounce,
      factory: watcherFactory,
      onChanged: _onWatchedChange,
    );
  }

  final FermataDatabase _db;
  final TrackRepository _tracks;
  final AppPaths _paths;
  final LibraryChangeBus _bus;
  final PlatformInfo _platform;
  final PlaylistRepository _playlists;

  /// Files parsed per background-isolate batch.
  final int batchSize;

  late final Set<String> _extensions;
  late final LibraryFolderWatcher _watcher;
  Future<void> _scanQueue = Future.value();
  bool _watching = false;

  static String normalizeFolder(String path) {
    var n = p.normalize(p.absolute(path));
    while (n.length > 1 && n.endsWith(p.separator) && !RegExp(r'^[A-Za-z]:\\$').hasMatch(n)) {
      n = n.substring(0, n.length - 1);
    }
    return n;
  }

  // ---------------------------------------------------------------- folders

  @override
  Future<List<LibraryFolder>> folders() async {
    final rows = await _db.db.query('library_folders', orderBy: 'path');
    final out = <LibraryFolder>[];
    for (final r in rows) {
      final path = r['path'] as String;
      final (sql, args) = LocalFileStore.underRoot(withSeparator(path));
      final count = await _db.db.rawQuery(
        "SELECT COUNT(*) AS n FROM tracks t WHERE t.source_id = 'local' AND t.missing_since IS NULL AND $sql",
        args,
      );
      out.add(LibraryFolder(
        path: path,
        watch: intBool(r['watch']),
        lastScannedAt: msToDate(r['last_scanned_at']),
        trackCount: (count.first['n'] as num).toInt(),
      ));
    }
    return out;
  }

  /// Adds (or updates the watch flag of) a folder. Scanning is started by
  /// the caller with [scan].
  @override
  Future<void> addFolder(String path, {bool watch = true}) async {
    final folder = normalizeFolder(path);
    if (!await Directory(folder).exists()) {
      throw StorageException('folder_not_found', 'Folder does not exist: $folder');
    }
    final updated = await _db.db.update('library_folders', {'watch': boolInt(watch)}, where: 'path = ?', whereArgs: [folder]);
    if (updated == 0) {
      await _db.db.insert('library_folders', {'path': folder, 'watch': boolInt(watch), 'added_at': nowMs()});
    }
    if (_watching) {
      watch ? _watcher.watch(folder) : _watcher.unwatch(folder);
    }
    notifyLibrary(_bus, {LibraryTopic.folders});
  }

  /// Removes the folder; with [removeTracks] its tracks leave the library
  /// (also from playlists/favorites/history), unless another library folder
  /// still contains them. Audio files are never deleted.
  @override
  Future<void> removeFolder(String path, {bool removeTracks = true}) async {
    final folder = normalizeFolder(path);
    _watcher.unwatch(folder);
    await _db.db.transaction((txn) async {
      await txn.delete('library_folders', where: 'path = ?', whereArgs: [folder]);
      if (!removeTracks) return;
      final others = [for (final r in await txn.query('library_folders')) withSeparator(r['path'] as String)];
      final (sql, args) = LocalFileStore.underRoot(withSeparator(folder));
      final keep = others.map((o) => LocalFileStore.underRoot(o)).toList();
      final keepSql = keep.isEmpty ? '' : ' AND NOT (${keep.map((k) => k.$1).join(' OR ')})';
      await txn.rawDelete(
        "DELETE FROM tracks WHERE id IN (SELECT t.id FROM tracks t WHERE t.source_id = 'local' AND $sql$keepSql)",
        [...args, for (final k in keep) ...k.$2],
      );
    });
    notifyLibrary(_bus, {
      LibraryTopic.folders,
      if (removeTracks) ...{LibraryTopic.tracks, LibraryTopic.playlists, LibraryTopic.favorites, LibraryTopic.history, LibraryTopic.links},
    });
  }

  // ------------------------------------------------------------------- scan

  @override
  Stream<ScanProgress> scan({String? folder, bool full = false}) {
    final cancel = CancelToken();
    late final StreamController<ScanProgress> controller;
    controller = StreamController<ScanProgress>(
      onListen: () {
        _scanQueue = _scanQueue.then((_) async {
          if (cancel.isCanceled) return;
          try {
            final roots = folder != null
                ? [normalizeFolder(folder)]
                : [for (final f in await _db.db.query('library_folders', orderBy: 'path')) f['path'] as String];
            await ScanJob(
              db: _db,
              bus: _bus,
              roots: roots,
              extensions: _extensions,
              artworkDir: _paths.artworkCacheDir.path,
              full: full,
              batchSize: batchSize,
              emit: (p) {
                if (!controller.isClosed) controller.add(p);
              },
              cancel: cancel,
            ).run();
          } on OperationCanceledException {
            _log.info('Scan canceled');
          } catch (e, st) {
            _log.severe('Library scan failed', e, st);
            if (!controller.isClosed) controller.addError(e, st);
          } finally {
            await controller.close();
          }
        });
      },
      onCancel: cancel.cancel,
    );
    return controller.stream;
  }

  // ---------------------------------------------------------------- watching

  @override
  Future<void> startWatching() async {
    if (!_platform.isDesktop) return; // Android: rescan on start/resume instead.
    _watching = true;
    for (final f in await folders()) {
      if (f.watch) _watcher.watch(f.path);
    }
  }

  @override
  Future<void> stopWatching() async {
    _watching = false;
    await _watcher.close();
  }

  /// Completes when all folder watchers are ready (tests).
  Future<void> get watchersReady => _watcher.ready;

  void _onWatchedChange(Set<String> roots) {
    for (final root in roots) {
      _log.fine('Change detected in a watched folder; rescanning');
      scan(folder: root).drain<void>().catchError((Object e) => _log.warning('Watch rescan failed', e));
    }
  }

  // ------------------------------------------------------------ single files

  static Future<ScannedFile> _parseOne(ParseRequest r, String artworkDir) =>
      Isolate.run(() => parseAudioFile(r, artworkDir));

  static Future<TagWriteResult> _writeTags(String path, Track edited, Set<String> fields, String backupDir) =>
      Isolate.run(() => writeTagsSafely(path, edited, fields, backupDir));

  @override
  Future<Track?> importFile(String path) async {
    final abs = p.normalize(p.absolute(path));
    if (!_extensions.contains(extensionOf(abs))) return null;
    final file = File(abs);
    if (!await file.exists()) return null;
    final stat = await file.stat();
    final scanned = await _parseOne(ParseRequest(abs, stat.size, stat.modified.millisecondsSinceEpoch), _paths.artworkCacheDir.path);
    if (scanned.track == null) {
      _log.warning('Could not import file: ${scanned.error}');
      return null;
    }
    await _db.db.transaction((txn) => LocalFileStore.saveScanned(txn, [scanned]));
    notifyLibrary(_bus, {LibraryTopic.tracks});
    return _tracks.getTrack(scanned.track!.id);
  }

  /// Desktop only: Android's scoped storage does not reliably allow
  /// rewriting files owned by other apps, so edits there are stored as
  /// library overrides. Writable formats: see [writableTagExtensions].
  @override
  bool get supportsFileTagWriting => _platform.isDesktop;

  /// Whether editing [track] would write to its file (format + platform).
  bool canWriteTags(Track track) =>
      supportsFileTagWriting && track.isLocal && track.localPath != null && writableTagExtensions.contains(extensionOf(track.localPath!));

  @override
  Future<bool> editTags(Track track, Track edited) async {
    if (track.id != edited.id) throw ArgumentError('editTags: edited track must have the same id');
    var source = await TrackStore.sourceTrack(_db.db, track.id);
    if (source == null) {
      await _tracks.upsertTracks([track]);
      source = track;
    }
    final diff = TrackCodec.diffOverride(source, edited);
    if (diff == null) {
      await TrackStore.setOverride(_db.db, track.id, null);
      notifyLibrary(_bus, {LibraryTopic.tracks});
      return false;
    }
    var written = false;
    final path = source.localPath;
    if (canWriteTags(source) && path != null && await File(path).exists()) {
      final fields = diff.keys.toSet();
      final backupDir = p.join(_paths.cacheDir.path, 'tag-backups');
      final result = await _writeTags(path, edited, fields, backupDir);
      if (result.status == TagWriteStatus.written) {
        written = true;
        final stat = await File(path).stat();
        final scanned = await _parseOne(ParseRequest(path, stat.size, stat.modified.millisecondsSinceEpoch), _paths.artworkCacheDir.path);
        if (scanned.track != null) {
          await _db.db.transaction((txn) => LocalFileStore.saveScanned(txn, [scanned]));
          source = scanned.track!;
        }
      } else {
        _log.info('Tags not written to file (${result.status.name}); storing a library override');
      }
    }
    // Whatever the file does not hold (unwritable fields/formats) stays an override.
    await _db.db.transaction((txn) => TrackStore.setOverride(txn, track.id, TrackCodec.diffOverride(source!, edited)));
    notifyLibrary(_bus, {LibraryTopic.tracks});
    return written;
  }

  // -------------------------------------------------------------------- M3U

  @override
  Future<List<Track>> importM3u(String path) async {
    final file = File(path);
    if (!await file.exists()) throw StorageException('file_not_found', 'Playlist file not found: $path');
    final parsed = parseM3u(decodePlaylistBytes(await file.readAsBytes()), p.dirname(p.normalize(p.absolute(path))));
    if (parsed.skippedUrls.isNotEmpty) {
      _log.warning('M3U import: ${parsed.skippedUrls.length} remote URL(s) ignored (only local files are supported)');
    }
    final out = <Track>[];
    var missing = 0;
    for (final entry in parsed.entries) {
      final known = await _trackByPath(entry.path);
      final track = known ?? await importFile(entry.path);
      if (track == null) {
        missing++;
        continue;
      }
      out.add(track);
    }
    if (missing > 0) _log.warning('M3U import: $missing entr(y/ies) not found or unsupported');
    return out;
  }

  Future<Track?> _trackByPath(String path) async {
    final rows = await _db.db.rawQuery('SELECT ${TrackCodec.selectColumns} FROM tracks t WHERE t.local_path = ? LIMIT 1', [path]);
    return rows.isEmpty ? null : TrackCodec.decode(rows.first);
  }

  @override
  Future<void> exportM3u(String playlistId, String path, {bool extended = true}) async {
    final playlist = await _playlists.getPlaylist(playlistId);
    if (playlist == null) throw StorageException('playlist_not_found', 'Playlist $playlistId does not exist');
    final tracks = await _playlists.playlistTracks(playlistId);
    final skipped = tracks.where((t) => t.localPath == null).length;
    if (skipped > 0) _log.info('M3U export: $skipped track(s) without a local file were skipped');
    final abs = p.normalize(p.absolute(path));
    final content = buildM3u(
      tracks,
      p.dirname(abs),
      extended: extended,
      playlistName: playlist.name,
      lineEnding: _platform.isWindows ? '\r\n' : '\n',
    );
    await writeTextAtomically(abs, content);
  }

  Future<void> dispose() async {
    await stopWatching();
    await _scanQueue;
  }
}
