import 'dart:async';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import 'audio_formats.dart';

final _log = Logger('library.watcher');

/// Creates a watcher for a directory (overridable in tests).
typedef DirectoryWatcherFactory = Watcher Function(String path);

/// Watches library folders (desktop) and reports, after a quiet period of
/// [debounce], which roots had relevant changes (audio files or folder art).
class LibraryFolderWatcher {
  LibraryFolderWatcher({
    required this.extensions,
    required this.onChanged,
    this.debounce = const Duration(seconds: 2),
    DirectoryWatcherFactory? factory,
  }) : _factory = factory ?? ((path) => DirectoryWatcher(path));

  final Set<String> extensions;
  final Duration debounce;
  final void Function(Set<String> roots) onChanged;
  final DirectoryWatcherFactory _factory;

  final _subs = <String, StreamSubscription<WatchEvent>>{};
  final _watchers = <String, Watcher>{};
  final _pending = <String>{};
  Timer? _timer;

  Set<String> get watchedRoots => _watchers.keys.toSet();

  bool _relevant(String path) {
    final ext = extensionOf(path);
    if (extensions.contains(ext)) return true;
    if (folderArtNames.contains(p.basename(path).toLowerCase())) return true;
    // Directory renames/removals arrive as events without an audio extension.
    return ext.isEmpty;
  }

  void watch(String root) {
    if (_watchers.containsKey(root)) return;
    final Watcher w;
    try {
      w = _factory(root);
    } catch (e) {
      _log.warning('Cannot watch library folder', e);
      return;
    }
    _watchers[root] = w;
    _subs[root] = w.events.listen(
      (event) {
        if (!_relevant(event.path)) return;
        _pending.add(root);
        _timer?.cancel();
        _timer = Timer(debounce, _flush);
      },
      onError: (Object e, StackTrace st) => _log.warning('Folder watcher error', e, st),
    );
  }

  void unwatch(String root) {
    _subs.remove(root)?.cancel();
    _watchers.remove(root);
    _pending.remove(root);
  }

  /// Completes when every watcher has finished its initial directory scan.
  Future<void> get ready => Future.wait([for (final w in _watchers.values) w.ready]);

  void _flush() {
    _timer = null;
    if (_pending.isEmpty) return;
    final roots = {..._pending};
    _pending.clear();
    onChanged(roots);
  }

  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
    final subs = [..._subs.values];
    _subs.clear();
    _watchers.clear();
    await Future.wait([for (final s in subs) s.cancel()]);
  }
}
