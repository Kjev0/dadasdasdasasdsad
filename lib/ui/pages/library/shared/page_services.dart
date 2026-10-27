import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../../../app/providers.dart';
import '../../../../core/errors.dart';
import '../../../../core/platform/app_paths.dart';
import '../../../../core/platform/platform_info.dart';

final _log = Logger('ui.pages.files');

/// Audio extensions offered by "Import a file" (the scanner decides what it
/// can actually read).
const audioFileExtensions = ['mp3', 'flac', 'm4a', 'mp4', 'aac', 'ogg', 'oga', 'opus', 'wav', 'aiff', 'aif', 'aifc', 'wma'];

/// Native file dialogs used by the content pages. Overridable through
/// [pageFilePickerProvider] (tests use an in-memory fake).
abstract class PageFilePicker {
  /// A directory chosen by the user, or null when canceled.
  Future<String?> pickDirectory({String? title});

  /// One audio file, or null.
  Future<String?> pickAudioFile({String? title});

  /// One image (playlist artwork), or null.
  Future<String?> pickImage({String? title});

  /// One `.m3u` / `.m3u8` file, or null.
  Future<String?> pickPlaylistFile({String? title});

  /// Asks where to save [fileName]; [write] writes the content to a local
  /// path. Returns a user-facing location (path or URI) or null when
  /// canceled.
  Future<String?> exportFile({required String fileName, required Future<void> Function(String path) write, String? title});
}

/// [PageFilePicker] backed by `file_picker` (desktop portals / Android SAF).
class SystemFilePicker implements PageFilePicker {
  const SystemFilePicker({required this.platform, required this.paths});

  final PlatformInfo platform;
  final AppPaths paths;

  Future<String?> _pick(FileType type, {List<String>? extensions, String? title}) async {
    final file = await FilePicker.pickFile(
      dialogTitle: title,
      type: type,
      allowedExtensions: extensions,
    );
    return file?.path;
  }

  @override
  Future<String?> pickDirectory({String? title}) => FilePicker.getDirectoryPath(dialogTitle: title);

  @override
  Future<String?> pickAudioFile({String? title}) =>
      // Android pickers filter custom extensions poorly; use the audio type.
      platform.isAndroid ? _pick(FileType.audio, title: title) : _pick(FileType.custom, extensions: audioFileExtensions, title: title);

  @override
  Future<String?> pickImage({String? title}) => _pick(FileType.image, title: title);

  @override
  Future<String?> pickPlaylistFile({String? title}) =>
      platform.isAndroid ? _pick(FileType.any, title: title) : _pick(FileType.custom, extensions: const ['m3u', 'm3u8'], title: title);

  @override
  Future<String?> exportFile({required String fileName, required Future<void> Function(String path) write, String? title}) async {
    // Write to a temp file first; the save dialog receives the bytes (works
    // with Android content URIs as well as desktop paths).
    final tmpDir = Directory(p.join(paths.cacheDir.path, 'exports'));
    await tmpDir.create(recursive: true);
    final tmp = File(p.join(tmpDir.path, fileName));
    await write(tmp.path);
    final bytes = await tmp.readAsBytes();
    final saved = await FilePicker.saveFile(fileName: fileName, bytes: Uint8List.fromList(bytes), dialogTitle: title);
    try {
      await tmp.delete();
    } catch (_) {}
    if (saved == null) return null;
    if (platform.isDesktop && saved.scheme == 'file') {
      // Re-export in place so paths inside the playlist can be relative to
      // the chosen folder.
      try {
        await write(saved.toFilePath());
      } catch (e) {
        _log.fine('In-place re-export failed (kept the first copy): $e');
      }
      return saved.toFilePath();
    }
    return saved.toString();
  }
}

final pageFilePickerProvider = Provider<PageFilePicker>(
  (ref) => SystemFilePicker(platform: ref.watch(platformInfoProvider), paths: ref.watch(appPathsProvider)),
);

/// Stores custom playlist artwork chosen by the user.
abstract class PlaylistArtworkStore {
  /// Copies [sourcePath] into app storage for [playlistId]; returns the
  /// `file:` URI to save in `Playlist.artworkUrl`.
  Future<Uri> store(String playlistId, String sourcePath);
}

/// Copies artwork into `<support>/playlist_artwork/` (one file per
/// playlist; older copies are removed).
class FilePlaylistArtworkStore implements PlaylistArtworkStore {
  const FilePlaylistArtworkStore(this.paths);

  final AppPaths paths;

  @override
  Future<Uri> store(String playlistId, String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw StorageException('artwork_missing', 'Image not found: $sourcePath');
    final dir = Directory(p.join(paths.supportDir.path, 'playlist_artwork'));
    await dir.create(recursive: true);
    final safeId = playlistId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final ext = p.extension(sourcePath).toLowerCase();
    final target = File(p.join(dir.path, '$safeId-${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.img' : ext}'));
    try {
      await source.copy(target.path);
    } on FileSystemException catch (e) {
      throw StorageException('artwork_copy_failed', 'Could not copy artwork', cause: e);
    }
    await for (final entity in dir.list()) {
      final name = p.basename(entity.path);
      if (entity is File && name.startsWith('$safeId-') && entity.path != target.path) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
    return Uri.file(target.path);
  }
}

final playlistArtworkStoreProvider =
    Provider<PlaylistArtworkStore>((ref) => FilePlaylistArtworkStore(ref.watch(appPathsProvider)));

/// Wall clock for greetings and day grouping (overridable in tests).
final pageClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// File-name-safe version of a playlist name.
String safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final trimmed = cleaned.replaceAll(RegExp(r'[. ]+$'), '');
  return trimmed.isEmpty ? 'playlist' : (trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed);
}
