import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('discovery.cache');

/// One memoized result.
class CacheEntry {
  CacheEntry({
    required this.data,
    required this.storedAt,
    required this.expiresAt,
    this.variant,
    this.personal = false,
    this.persist = true,
  });

  /// JSON-encodable payload.
  final Object? data;
  final DateTime storedAt;
  final DateTime expiresAt;

  /// Extra validity key (e.g. the day of a Daily Mix, the ISO week of
  /// Discover Weekly). An entry is only reused for the same variant.
  final String? variant;

  /// Derived from listening history/favorites — purged when
  /// personalization is switched off.
  final bool personal;

  /// Written to the cache file (false = memory only).
  final bool persist;

  bool isFresh(DateTime now) => now.isBefore(expiresAt);

  Map<String, Object?> toJson() => {
        'data': data,
        'storedAt': storedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        if (variant != null) 'variant': variant,
        if (personal) 'personal': true,
      };

  static CacheEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final stored = DateTime.tryParse(raw['storedAt'] as String? ?? '');
    final expires = DateTime.tryParse(raw['expiresAt'] as String? ?? '');
    if (stored == null || expires == null) return null;
    return CacheEntry(
      data: raw['data'],
      storedAt: stored,
      expiresAt: expires,
      variant: raw['variant'] as String?,
      personal: raw['personal'] == true,
    );
  }
}

/// Memory + JSON-file memo for discovery results.
///
/// The file (in `AppPaths.cacheDir`) lets Home render instantly after a
/// restart and keeps data-saver users from refetching. Writes are
/// debounced, serialized and atomic (temp file + rename); an unreadable
/// file is ignored (it is only a cache).
class DiscoveryCache {
  DiscoveryCache(this.file, {DateTime Function()? clock, this.writeDelay = const Duration(milliseconds: 500)})
      : _clock = clock ?? DateTime.now;

  /// Null = memory only.
  final File? file;
  final Duration writeDelay;
  final DateTime Function() _clock;

  final Map<String, CacheEntry> _entries = {};
  Future<void>? _loading;
  Future<void> _writeChain = Future.value();
  Timer? _debounce;
  bool _disposed = false;

  static const _formatVersion = 1;

  /// Loads the file once (subsequent calls return the same future).
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final f = file;
    if (f == null) return;
    try {
      if (!await f.exists()) return;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map || raw['v'] != _formatVersion) return;
      final entries = raw['entries'];
      if (entries is! Map) return;
      final now = _clock();
      for (final e in entries.entries) {
        final entry = CacheEntry.fromJson(e.value);
        // Keep stale entries: data saver may still serve them.
        if (entry != null && now.difference(entry.storedAt) < const Duration(days: 30)) {
          _entries.putIfAbsent(e.key as String, () => entry);
        }
      }
    } catch (e) {
      _log.warning('Ignoring unreadable discovery cache ${f.path}', e);
    }
  }

  CacheEntry? peek(String key) => _entries[key];

  Iterable<String> get keys => _entries.keys;

  void put(String key, Object? data, {required Duration ttl, String? variant, bool personal = false, bool persist = true}) {
    final now = _clock();
    _entries[key] = CacheEntry(
        data: data, storedAt: now, expiresAt: now.add(ttl), variant: variant, personal: personal, persist: persist);
    if (persist) _scheduleWrite();
  }

  void remove(String key) {
    if (_entries.remove(key) != null) _scheduleWrite();
  }

  void removeWhere(bool Function(String key, CacheEntry entry) test) {
    final before = _entries.length;
    _entries.removeWhere(test);
    if (_entries.length != before) _scheduleWrite();
  }

  void clear() {
    _entries.clear();
    _scheduleWrite();
  }

  void _scheduleWrite() {
    if (file == null || _disposed) return;
    _debounce?.cancel();
    _debounce = Timer(writeDelay, () {
      _debounce = null;
      unawaited(_enqueueWrite());
    });
  }

  /// Writes pending changes now.
  Future<void> flush() {
    if (_debounce != null) {
      _debounce!.cancel();
      _debounce = null;
      return _enqueueWrite();
    }
    return _writeChain;
  }

  Future<void> _enqueueWrite() {
    final f = file;
    if (f == null) return Future.value();
    final snapshot = {
      'v': _formatVersion,
      'entries': {
        for (final e in _entries.entries)
          if (e.value.persist) e.key: e.value.toJson(),
      },
    };
    return _writeChain = _writeChain.then((_) => _write(f, snapshot)).catchError((Object e) {
      _log.warning('Could not write discovery cache', e);
    });
  }

  static Future<void> _write(File f, Map<String, Object?> json) async {
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(f.path);
  }

  Future<void> dispose() async {
    await flush();
    _disposed = true;
  }
}
