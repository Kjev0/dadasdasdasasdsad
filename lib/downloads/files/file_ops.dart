import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final _log = Logger('downloads.files');

/// Signature of the primitive rename used by [FileMover] (injectable so the
/// cross-device fallback can be tested).
typedef RenameFn = Future<File> Function(File source, String targetPath);

/// Moves files, falling back to copy + delete when `rename` fails (e.g.
/// `EXDEV` when the partial-download cache and the music folder live on
/// different file systems).
class FileMover {
  FileMover({RenameFn? rename}) : _rename = rename ?? ((f, t) => f.rename(t));

  final RenameFn _rename;

  Future<File> move(File source, String targetPath) async {
    await Directory(p.dirname(targetPath)).create(recursive: true);
    try {
      return await _rename(source, targetPath);
    } on FileSystemException catch (e) {
      _log.fine('rename failed (${e.osError?.errorCode}); copying ${source.path} -> $targetPath');
      // Copy to a sibling temp name first so a crash never leaves a
      // truncated file under the final name.
      final tmp = File('$targetPath.part-move');
      try {
        await source.copy(tmp.path);
        final moved = await tmp.rename(targetPath);
        await source.delete();
        return moved;
      } catch (_) {
        if (await tmp.exists()) await tmp.delete();
        rethrow;
      }
    }
  }
}

/// Recursive size of [dir] in bytes (missing dirs count as 0; symlinks are
/// not followed).
Future<int> directorySize(Directory dir) async {
  if (!await dir.exists()) return 0;
  var total = 0;
  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on FileSystemException {
          // vanished while listing
        }
      }
    }
  } on FileSystemException catch (e) {
    _log.fine('Could not list ${dir.path}', e);
  }
  return total;
}

/// Size of a file or 0 when missing.
Future<int> fileSize(String? path) async {
  if (path == null) return 0;
  try {
    return await File(path).length();
  } on FileSystemException {
    return 0;
  }
}

/// Deletes empty directories from [dir] upwards, stopping at (and never
/// deleting) [stopAt].
Future<void> removeEmptyParents(String dir, String stopAt) async {
  var current = p.normalize(dir);
  final stop = p.normalize(stopAt);
  while (p.isWithin(stop, current)) {
    final d = Directory(current);
    try {
      if (!await d.exists() || !(await d.list().isEmpty)) return;
      await d.delete();
    } on FileSystemException {
      return;
    }
    current = p.dirname(current);
  }
}

/// True when [path] is inside [root] (after normalisation).
bool isInside(String root, String path) => p.isWithin(p.normalize(root), p.normalize(path));
