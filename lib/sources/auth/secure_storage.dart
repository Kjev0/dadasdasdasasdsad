import 'dart:async';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';

final _log = Logger('sources.auth.storage');

/// Minimal secure key/value interface used by the token and credentials
/// stores (lets tests and the in-memory fallback share one code path).
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// All entries (used to enumerate `fermata.*` keys).
  Future<Map<String, String>> readAll();
}

/// `flutter_secure_storage` backend: Android Keystore-backed encrypted
/// storage, Windows Credential Manager/DPAPI, Linux Secret Service
/// (libsecret).
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              lOptions: LinuxOptions(),
              wOptions: WindowsOptions(),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();
}

/// Process-memory store: the fallback when no secure backend works, and the
/// implementation used in tests. Nothing is ever written to disk.
class InMemoryKeyValueStore implements SecureKeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(_values);
}

/// Wraps a secure backend that might not work (Linux without a running
/// Secret Service / unlocked keyring, headless sessions).
///
/// [open] runs a guarded write → read → delete probe with a timeout. If it
/// fails, every operation goes to an in-memory store instead, [isPersistent]
/// is false and a warning is logged — secrets are never written to plain
/// files. If the backend starts failing later, the store degrades the same
/// way at that moment.
class ProbedSecureStorage implements SecureKeyValueStore {
  ProbedSecureStorage._(this._backend, this._persistent);

  /// Probe key; never holds real data.
  static const probeKey = 'fermata.probe';

  /// Opens [backend] (default: [FlutterSecureKeyValueStore]) and probes it.
  static Future<ProbedSecureStorage> open({
    SecureKeyValueStore? backend,
    Duration probeTimeout = const Duration(seconds: 4),
    Random? random,
  }) async {
    final store = backend ?? FlutterSecureKeyValueStore();
    final ok = await probe(store, timeout: probeTimeout, random: random);
    if (!ok) {
      _log.warning('Secure storage is unavailable (no Secret Service / keyring?). '
          'Tokens and credentials are kept in memory for this session only.');
    }
    return ProbedSecureStorage._(store, ok);
  }

  /// An always in-memory instance (tests, or platforms without a backend).
  factory ProbedSecureStorage.memoryOnly() => ProbedSecureStorage._(InMemoryKeyValueStore(), false);

  /// Write → read → delete round trip; false on any error, mismatch or
  /// timeout (the Secret Service can hang when no keyring daemon answers).
  static Future<bool> probe(SecureKeyValueStore store, {Duration timeout = const Duration(seconds: 4), Random? random}) async {
    final value = 'probe-${(random ?? Random()).nextInt(1 << 30)}';
    try {
      return await () async {
        await store.write(probeKey, value);
        final read = await store.read(probeKey);
        await store.delete(probeKey);
        return read == value;
      }()
          .timeout(timeout);
    } catch (e) {
      _log.fine('Secure storage probe failed: $e');
      return false;
    }
  }

  final SecureKeyValueStore _backend;
  final InMemoryKeyValueStore _memory = InMemoryKeyValueStore();
  bool _persistent;

  /// False when values only live in memory for this session.
  bool get isPersistent => _persistent;

  SecureKeyValueStore get _active => _persistent ? _backend : _memory;

  Future<T> _guard<T>(Future<T> Function(SecureKeyValueStore s) op) async {
    if (!_persistent) return op(_memory);
    try {
      return await op(_backend).timeout(const Duration(seconds: 10));
    } catch (e) {
      _log.warning('Secure storage failed; continuing in memory for this session: $e');
      // Carry over what we can so the session keeps working.
      _persistent = false;
      return op(_memory);
    }
  }

  @override
  Future<String?> read(String key) => _guard((s) => s.read(key));

  @override
  Future<void> write(String key, String value) async {
    // Mirror into memory so a later backend failure does not lose the value.
    await _memory.write(key, value);
    await _guard((s) => s.write(key, value));
  }

  @override
  Future<void> delete(String key) async {
    await _memory.delete(key);
    await _guard((s) => s.delete(key));
  }

  @override
  Future<Map<String, String>> readAll() => _guard((s) => s.readAll());

  /// Exposed for diagnostics.
  SecureKeyValueStore get activeBackend => _active;
}
