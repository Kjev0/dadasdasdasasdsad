import 'dart:convert';

import 'package:logging/logging.dart';

import '../../core/contracts/auth.dart';
import '../../core/models/auth.dart';
import 'secure_storage.dart';

final _log = Logger('sources.auth.tokens');

/// [TokenStore] on top of the platform secure storage.
///
/// Keys: `fermata.token.<sourceId>`, value: `OAuthToken.toJson()` as JSON.
/// When the secure backend is unavailable (see [ProbedSecureStorage]) tokens
/// live in memory only and [isPersistent] is false — the UI then explains
/// that the user has to reconnect after a restart. Tokens are never logged
/// and never written to plain files.
class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage);

  /// Opens the platform secure storage (with the availability probe) and
  /// returns a ready store. Prefer sharing one [ProbedSecureStorage] with
  /// `CredentialsStoreImpl` via the default constructor.
  static Future<SecureTokenStore> open({SecureKeyValueStore? backend}) async =>
      SecureTokenStore(await ProbedSecureStorage.open(backend: backend));

  static const keyPrefix = 'fermata.token.';

  static String keyFor(String sourceId) => '$keyPrefix$sourceId';

  final ProbedSecureStorage _storage;

  @override
  bool get isPersistent => _storage.isPersistent;

  @override
  Future<OAuthToken?> read(String sourceId) async {
    final raw = await _storage.read(keyFor(sourceId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is Map) return OAuthToken.fromJson(json.cast<String, Object?>());
    } catch (e) {
      // Do not include the raw value: it is a secret.
      _log.warning('Discarding unreadable stored token for $sourceId (${e.runtimeType})');
    }
    await _storage.delete(keyFor(sourceId));
    return null;
  }

  @override
  Future<void> write(String sourceId, OAuthToken token) =>
      _storage.write(keyFor(sourceId), jsonEncode(token.toJson()));

  @override
  Future<void> delete(String sourceId) => _storage.delete(keyFor(sourceId));

  @override
  Future<void> deleteAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(keyPrefix)) await _storage.delete(key);
    }
  }
}

/// A [TokenStore] that only keeps tokens in memory. Used in tests and as an
/// explicit "do not persist" option; behaves like [SecureTokenStore] with an
/// unavailable backend.
class InMemoryTokenStore implements TokenStore {
  final Map<String, OAuthToken> _tokens = {};

  @override
  bool get isPersistent => false;

  @override
  Future<OAuthToken?> read(String sourceId) async => _tokens[sourceId];

  @override
  Future<void> write(String sourceId, OAuthToken token) async => _tokens[sourceId] = token;

  @override
  Future<void> delete(String sourceId) async => _tokens.remove(sourceId);

  @override
  Future<void> deleteAll() async => _tokens.clear();
}
