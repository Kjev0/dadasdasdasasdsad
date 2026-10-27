import 'dart:async';
import 'dart:io';

import 'package:fermata/core/models/auth.dart';
import 'package:fermata/sources/auth/secure_storage.dart';
import 'package:fermata/sources/auth/secure_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backend that fails like a missing Secret Service.
class _ThrowingStore implements SecureKeyValueStore {
  int calls = 0;
  @override
  Future<String?> read(String key) async => throw _err();
  @override
  Future<void> write(String key, String value) async => throw _err();
  @override
  Future<void> delete(String key) async => throw _err();
  @override
  Future<Map<String, String>> readAll() async => throw _err();
  Exception _err() {
    calls++;
    return Exception('org.freedesktop.DBus.Error.ServiceUnknown');
  }
}

/// Backend whose calls never complete (D-Bus waiting for a keyring prompt).
class _HangingStore implements SecureKeyValueStore {
  @override
  Future<String?> read(String key) => Completer<String?>().future;
  @override
  Future<void> write(String key, String value) => Completer<void>().future;
  @override
  Future<void> delete(String key) => Completer<void>().future;
  @override
  Future<Map<String, String>> readAll() => Completer<Map<String, String>>().future;
}

/// Backend that silently drops writes.
class _ForgetfulStore extends InMemoryKeyValueStore {
  @override
  Future<void> write(String key, String value) async {}
}

/// Works for the probe, then breaks (keyring locked mid-session).
class _BreaksLater extends InMemoryKeyValueStore {
  bool broken = false;
  @override
  Future<void> write(String key, String value) async {
    if (broken) throw Exception('locked');
    return super.write(key, value);
  }

  @override
  Future<String?> read(String key) async {
    if (broken) throw Exception('locked');
    return super.read(key);
  }
}

void main() {
  final token = OAuthToken(
    accessToken: 'secret-access',
    refreshToken: 'secret-refresh',
    expiresAt: DateTime.utc(2026, 10, 27, 13),
    scopes: const ['a', 'b'],
  );

  group('ProbedSecureStorage', () {
    test('working backend is persistent and leaves no probe key behind', () async {
      final backend = InMemoryKeyValueStore();
      final s = await ProbedSecureStorage.open(backend: backend);
      expect(s.isPersistent, isTrue);
      expect(await backend.readAll(), isEmpty);
      await s.write('k', 'v');
      expect(await backend.read('k'), 'v');
    });

    test('throwing backend -> in-memory fallback, nothing reaches the backend', () async {
      final backend = _ThrowingStore();
      final s = await ProbedSecureStorage.open(backend: backend);
      expect(s.isPersistent, isFalse);
      final probeCalls = backend.calls;
      await s.write('k', 'v');
      expect(await s.read('k'), 'v');
      expect(backend.calls, probeCalls);
    });

    test('hanging backend times out -> in-memory', () async {
      final s = await ProbedSecureStorage.open(
        backend: _HangingStore(),
        probeTimeout: const Duration(milliseconds: 100),
      );
      expect(s.isPersistent, isFalse);
      await s.write('k', 'v');
      expect(await s.read('k'), 'v');
    });

    test('backend that does not keep values -> in-memory', () async {
      final s = await ProbedSecureStorage.open(backend: _ForgetfulStore());
      expect(s.isPersistent, isFalse);
    });

    test('degrades to memory when the backend fails later, keeping session values', () async {
      final backend = _BreaksLater();
      final s = await ProbedSecureStorage.open(backend: backend);
      expect(s.isPersistent, isTrue);
      await s.write('a', '1');
      backend.broken = true;
      await s.write('b', '2');
      expect(s.isPersistent, isFalse);
      expect(await s.read('a'), '1');
      expect(await s.read('b'), '2');
    });

    test('FlutterSecureKeyValueStore adapter (plugin mock)', () async {
      FlutterSecureStorage.setMockInitialValues({'x': '1'});
      final s = await ProbedSecureStorage.open(backend: FlutterSecureKeyValueStore());
      expect(s.isPersistent, isTrue);
      expect(await s.read('x'), '1');
      await s.write('y', '2');
      expect((await s.readAll())['y'], '2');
    });
  });

  group('SecureTokenStore', () {
    test('JSON round trip under fermata.token.<sourceId>', () async {
      final backend = InMemoryKeyValueStore();
      final store = SecureTokenStore(await ProbedSecureStorage.open(backend: backend));
      await store.write('spotify', token);
      final raw = await backend.read('fermata.token.spotify');
      expect(raw, contains('"access":"secret-access"'));
      final back = await store.read('spotify');
      expect(back!.accessToken, 'secret-access');
      expect(back.refreshToken, 'secret-refresh');
      expect(back.expiresAt, DateTime.utc(2026, 10, 27, 13));
      expect(back.scopes, ['a', 'b']);
      expect(store.isPersistent, isTrue);
    });

    test('delete and deleteAll only touch token keys', () async {
      final backend = InMemoryKeyValueStore({'fermata.credentials.soundcloud': '{}'});
      final store = SecureTokenStore(await ProbedSecureStorage.open(backend: backend));
      await store.write('a', token);
      await store.write('b', token);
      await store.delete('a');
      expect(await store.read('a'), isNull);
      await store.deleteAll();
      expect(await store.read('b'), isNull);
      expect(await backend.read('fermata.credentials.soundcloud'), '{}');
    });

    test('corrupted entries are discarded', () async {
      final backend = InMemoryKeyValueStore({'fermata.token.x': 'not json'});
      final store = SecureTokenStore(await ProbedSecureStorage.open(backend: backend));
      expect(await store.read('x'), isNull);
      expect(await backend.read('fermata.token.x'), isNull);
    });

    test('without a secure backend tokens stay in memory and never hit disk', () async {
      final tmp = await Directory.systemTemp.createTemp('fermata_tokens');
      addTearDown(() => tmp.delete(recursive: true));
      final store = SecureTokenStore(await ProbedSecureStorage.open(backend: _ThrowingStore()));
      expect(store.isPersistent, isFalse);
      await store.write('soundcloud', token);
      expect((await store.read('soundcloud'))!.accessToken, 'secret-access');
      expect(tmp.listSync(recursive: true), isEmpty);
    });

    test('InMemoryTokenStore behaves the same', () async {
      final store = InMemoryTokenStore();
      expect(store.isPersistent, isFalse);
      await store.write('a', token);
      expect((await store.read('a'))!.accessToken, 'secret-access');
      await store.deleteAll();
      expect(await store.read('a'), isNull);
    });
  });
}
