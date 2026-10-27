import 'dart:io';

import 'package:path/path.dart' as p;

import 'audio_formats.dart';

/// An audio file found on disk.
class FoundFile {
  const FoundFile(this.path, this.size, this.mtimeMs, {this.folderArt});

  final String path;
  final int size;
  final int mtimeMs;

  /// `cover.jpg`/`folder.jpg`/... next to the file, if any.
  final String? folderArt;
}

/// Result of [enumerateAudioFiles].
class EnumerationResult {
  const EnumerationResult(this.files, this.errors);

  final List<FoundFile> files;
  final List<String> errors;
}

/// Recursively lists audio files under [root] (synchronous; run it in a
/// background isolate).
///
/// * hidden directories/files (name starting with `.`) are skipped, as are
///   directories containing a `.nomedia` marker;
/// * symbolic links are followed, but every directory is visited at most
///   once (by resolved path), so link loops terminate;
/// * only files whose extension is in [extensions] are returned.
EnumerationResult enumerateAudioFiles(String root, Set<String> extensions) {
  final files = <FoundFile>[];
  final errors = <String>[];
  final visited = <String>{};
  final artNames = {for (var i = 0; i < folderArtNames.length; i++) folderArtNames[i]: i};

  void walk(Directory dir) {
    final String real;
    try {
      real = dir.resolveSymbolicLinksSync();
    } on FileSystemException catch (e) {
      errors.add('${dir.path}: ${e.message}');
      return;
    }
    if (!visited.add(real)) return;
    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException catch (e) {
      errors.add('${dir.path}: ${e.message}');
      return;
    }
    final names = {for (final e in entries) p.basename(e.path).toLowerCase(): e};
    if (names.containsKey('.nomedia')) return;

    String? folderArt;
    var bestRank = 1 << 30;
    for (final entry in names.entries) {
      final rank = artNames[entry.key];
      if (rank != null && rank < bestRank && entry.value is! Directory) {
        bestRank = rank;
        folderArt = entry.value.path;
      }
    }

    final subdirs = <Directory>[];
    final audio = <String>[];
    for (final e in entries) {
      final base = p.basename(e.path);
      if (base.startsWith('.')) continue;
      if (e is Directory) {
        subdirs.add(e);
      } else if (e is File) {
        if (extensions.contains(extensionOf(base))) audio.add(e.path);
      } else if (e is Link) {
        try {
          final type = FileSystemEntity.typeSync(e.path); // follows the link
          if (type == FileSystemEntityType.directory) {
            subdirs.add(Directory(e.path));
          } else if (type == FileSystemEntityType.file && extensions.contains(extensionOf(base))) {
            audio.add(e.path);
          }
        } on FileSystemException catch (err) {
          errors.add('${e.path}: ${err.message}');
        }
      }
    }
    audio.sort();
    for (final path in audio) {
      try {
        final stat = File(path).statSync();
        if (stat.type == FileSystemEntityType.notFound) continue;
        files.add(FoundFile(path, stat.size, stat.modified.millisecondsSinceEpoch, folderArt: folderArt));
      } on FileSystemException catch (e) {
        errors.add('$path: ${e.message}');
      }
    }
    subdirs.sort((a, b) => a.path.compareTo(b.path));
    for (final d in subdirs) {
      walk(d);
    }
  }

  final rootDir = Directory(root);
  if (!rootDir.existsSync()) return EnumerationResult(const [], ['$root: folder not found']);
  walk(rootDir);
  return EnumerationResult(files, errors);
}
