import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart' as pf;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../core/net/http_client.dart';
import '../../core/platform/app_paths.dart';
import '../../core/util/cancel_token.dart';
import '../../settings/settings_store.dart';
import '../download_errors.dart';
import '../files/file_ops.dart';

final _log = Logger('downloads.artwork');

/// Artwork storage the download manager needs (implemented by
/// [FermataArtworkCache]; tests may substitute a fake).
abstract class OfflineArtworkStore {
  /// Makes sure [url] is cached and keeps it until [unpin] (artwork of
  /// downloaded tracks must survive LRU eviction for offline use). Downloads
  /// the image only when it is not cached yet. Returns false on failure.
  Future<bool> pin(Uri url, {CancelToken? cancel});

  /// Allows [url] to be evicted again (its download was deleted).
  Future<void> unpin(Uri url);

  bool isPinned(Uri url);

  /// Bytes used by the cache on disk.
  Future<int> sizeBytes();

  /// Deletes every unpinned entry. Returns bytes freed.
  Future<int> clearUnpinned();

  /// Evicts least-recently-used unpinned entries until the configured size
  /// limit is met. Returns bytes freed.
  Future<int> trimToLimit();

  Future<void> dispose();
}

/// `CacheManager` for `cached_network_image`, rooted in
/// `<AppPaths.artworkCacheDir>/remote` and bounded by
/// `storage.artworkCacheMb` (bytes, LRU by last access) in addition to an
/// object-count cap. Pass it to widgets as
/// `CachedNetworkImage(cacheManager: artworkCache, ...)`.
///
/// Artwork of downloaded tracks is *pinned*: it counts towards the budget
/// but is never evicted, so downloaded tracks keep their covers offline.
/// Only `remote/` is managed here; artwork extracted by the local library
/// scanner (other files in `artworkCacheDir`) is never touched.
class FermataArtworkCache extends CacheManager with ImageCacheManager implements OfflineArtworkStore {
  FermataArtworkCache._(
    super.config, {
    required this.root,
    required this._repository,
    required this._pins,
    required this._http,
  });

  /// Creates the cache. Directories are created synchronously so the
  /// instance can be handed to widgets immediately.
  factory FermataArtworkCache({
    required AppPaths paths,
    required SettingsStore settings,
    required FermataHttp http,
    Duration stalePeriod = const Duration(days: 60),
    int maxObjects = 20000,
  }) {
    final root = Directory(p.join(paths.artworkCacheDir.path, 'remote'));
    final filesDir = Directory(p.join(root.path, 'files'))..createSync(recursive: true);
    final pins = _PinSet(File(p.join(root.path, 'pinned.json')))..loadSync();
    final repository = _BoundedJsonRepository(
      File(p.join(root.path, 'index.json')),
      filesDir: filesDir,
      maxBytes: () => settings.current.storage.artworkCacheMb * 1024 * 1024,
      isPinned: pins.contains,
    );
    final config = Config(
      cacheKey,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxObjects,
      repo: repository,
      fileSystem: _DirectoryFileSystem(filesDir.path),
      fileService: _FermataFileService(http),
    );
    return FermataArtworkCache._(config, root: root, repository: repository, pins: pins, http: http);
  }

  static const cacheKey = 'fermata_artwork';

  /// `<artworkCacheDir>/remote`.
  final Directory root;
  final _BoundedJsonRepository _repository;
  final _PinSet _pins;
  final FermataHttp _http;
  Future<bool>? _opened;

  /// The index must be loaded before bulk operations (otherwise every file
  /// would look orphaned).
  Future<void> _ensureOpen() => _opened ??= _repository.open();

  @override
  bool isPinned(Uri url) => _pins.contains(url.toString());

  @override
  Future<bool> pin(Uri url, {CancelToken? cancel}) async {
    if (url.scheme != 'http' && url.scheme != 'https') return false;
    final key = url.toString();
    try {
      final cached = await getFileFromCache(key);
      if (cached == null || !await cached.file.exists()) {
        final response = await _http.get(url, cancel: cancel);
        final type = response.headers['content-type'] ?? '';
        if (response.statusCode != 200 || response.bodyBytes.isEmpty || !_isImage(type, response.bodyBytes)) {
          _log.fine('Artwork not cached: HTTP ${response.statusCode} ($type) from ${url.host}');
          return false;
        }
        await putFile(key, response.bodyBytes,
            key: key, maxAge: const Duration(days: 365), fileExtension: _extension(type, url));
      }
      await _pins.add(key);
      return true;
    } on Exception catch (e) {
      _log.fine('Could not cache artwork from ${url.host}: ${redactUrls(e)}');
      return false;
    }
  }

  @override
  Future<void> unpin(Uri url) => _pins.remove(url.toString());

  @override
  Future<int> sizeBytes() => directorySize(root);

  @override
  Future<int> clearUnpinned() async {
    await _ensureOpen();
    final before = await sizeBytes();
    final objects = await _repository.getAllObjects();
    for (final o in objects) {
      if (!_pins.contains(o.key)) await removeFile(o.key);
    }
    await _deleteOrphans();
    final after = await sizeBytes();
    return before > after ? before - after : 0;
  }

  @override
  Future<int> trimToLimit() async {
    await _ensureOpen();
    final over = await _repository.getObjectsOverCapacity(config.maxNrOfCacheObjects);
    var freed = 0;
    for (final o in over) {
      freed += _repository.sizeOf(o);
      await removeFile(o.key);
    }
    return freed;
  }

  /// Removes files in `files/` that the index does not know (crash leftovers).
  Future<void> _deleteOrphans() async {
    final known = {for (final o in await _repository.getAllObjects()) o.relativePath};
    final dir = _repository.filesDir;
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && !known.contains(p.basename(entity.path))) {
        try {
          await entity.delete();
        } on FileSystemException {
          // ignore
        }
      }
    }
  }

  static bool _isImage(String contentType, List<int> bytes) {
    if (contentType.toLowerCase().startsWith('image/')) return true;
    if (bytes.length < 4) return false;
    // JPEG, PNG, GIF, WebP (RIFF....WEBP)
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    return bytes.length > 12 && bytes[0] == 0x52 && bytes[8] == 0x57 && bytes[9] == 0x45;
  }

  static String _extension(String contentType, Uri url) {
    final mime = contentType.split(';').first.trim().toLowerCase();
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
    }
    final ext = p.extension(url.path).replaceFirst('.', '').toLowerCase();
    return const {'png', 'webp', 'gif', 'jpg', 'jpeg'}.contains(ext) ? ext : 'jpg';
  }

  @override
  Future<void> dispose() async {
    await _pins.flush();
    await super.dispose();
  }
}

/// Image fetches for `cached_network_image` over FermataHttp's client with
/// Fermata's User-Agent.
class _FermataFileService extends HttpFileService {
  _FermataFileService(this._http) : super(httpClient: _http.raw);

  final FermataHttp _http;

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) =>
      super.get(url, headers: {'User-Agent': _http.userAgent, ...?headers});
}

/// Places cache files in a fixed directory (instead of the platform temp dir
/// used by flutter_cache_manager's default `IOFileSystem`).
class _DirectoryFileSystem implements FileSystem {
  _DirectoryFileSystem(String path) : _dir = const LocalFileSystem().directory(path);

  final pf.Directory _dir;

  @override
  Future<pf.File> createFile(String name) async {
    if (!await _dir.exists()) await _dir.create(recursive: true);
    return _dir.childFile(name);
  }
}

/// JSON index that additionally enforces a byte budget (LRU by `touched`)
/// and never evicts pinned keys.
class _BoundedJsonRepository extends JsonCacheInfoRepository {
  _BoundedJsonRepository(super.file, {required this.filesDir, required this.maxBytes, required this.isPinned})
      : super.withFile();

  final Directory filesDir;
  final int Function() maxBytes;
  final bool Function(String key) isPinned;

  int sizeOf(CacheObject o) {
    final known = o.length;
    if (known != null && known > 0) return known;
    try {
      return File(p.join(filesDir.path, o.relativePath)).lengthSync();
    } on FileSystemException {
      return 0;
    }
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async {
    final all = await getAllObjects();
    final budget = maxBytes();
    var bytes = 0;
    var count = 0;
    final unpinned = <CacheObject>[];
    for (final o in all) {
      if (isPinned(o.key)) {
        bytes += sizeOf(o);
        count++;
      } else {
        unpinned.add(o);
      }
    }
    // Newest first; everything that no longer fits is evicted.
    unpinned.sort((a, b) => (b.touched ?? DateTime(0)).compareTo(a.touched ?? DateTime(0)));
    final over = <CacheObject>[];
    for (final o in unpinned) {
      final size = sizeOf(o);
      if (count + 1 > capacity || bytes + size > budget) {
        over.add(o);
      } else {
        bytes += size;
        count++;
      }
    }
    return over;
  }

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) async =>
      (await super.getOldObjects(maxAge)).where((o) => !isPinned(o.key)).toList();
}

/// Persistent set of pinned cache keys (atomic JSON writes).
class _PinSet {
  _PinSet(this._file);

  final File _file;
  final _keys = <String>{};
  Future<void> _writes = Future.value();

  bool contains(String key) => _keys.contains(key);

  void loadSync() {
    try {
      if (_file.existsSync()) {
        final raw = jsonDecode(_file.readAsStringSync());
        if (raw is List) _keys.addAll(raw.whereType<String>());
      }
    } catch (e) {
      _log.warning('Ignoring unreadable artwork pin list', e);
    }
  }

  Future<void> add(String key) async {
    if (_keys.add(key)) await _save();
  }

  Future<void> remove(String key) async {
    if (_keys.remove(key)) await _save();
  }

  Future<void> flush() => _writes;

  Future<void> _save() {
    final snapshot = jsonEncode(_keys.toList());
    return _writes = _writes.then((_) async {
      try {
        await _file.parent.create(recursive: true);
        final tmp = File('${_file.path}.tmp');
        await tmp.writeAsString(snapshot, flush: true);
        await tmp.rename(_file.path);
      } on FileSystemException catch (e) {
        _log.warning('Could not persist artwork pins', e);
      }
    });
  }
}
