// Adversarial review tests for secure token / credentials storage.
// Each test demonstrates a defect; they are expected to FAIL until fixed.

import 'package:fermata/core/models/auth.dart';
import 'package:fermata/sources/auth/secure_storage.dart';
import 'package:fermata/sources/auth/secure_token_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real, persistent backend whose delete starts failing (keyring locked,
/// D-Bus hiccup, Android Keystore error) after the probe succeeded.
class _DeleteFails extends InMemoryKeyValueStore {
  bool failDeletes = false;

  @override
  Future<void> delete(String key) async {
    if (failDeletes && !key.endsWith('probe')) throw Exception('org.freedesktop.Secret.Error.IsLocked');
    return super.delete(key);
  }
}

void main() {
  test('a failed delete on the persistent backend must not be reported as success '
      '(disconnect would leave the token in the keyring)', () async {
    final backend = _DeleteFails();
    final storage = await ProbedSecureStorage.open(backend: backend);
    expect(storage.isPersistent, isTrue);
    final tokens = SecureTokenStore(storage);
    await tokens.write('soundcloud', const OAuthToken(accessToken: 'secret-access', refreshToken: 'secret-refresh'));

    backend.failDeletes = true;
    Object? error;
    try {
      // OAuthSession.disconnect() -> TokenStore.delete()
      await tokens.delete('soundcloud');
    } catch (e) {
      error = e;
    }

    // BUG: ProbedSecureStorage.delete() swallows the backend failure via
    // _guard() (switching to memory mode), so the caller believes the token
    // is gone while it is still stored in the OS keyring...
    final stillInKeyring = await backend.read(SecureTokenStore.keyFor('soundcloud'));
    expect(
      error != null || stillInKeyring == null,
      isTrue,
      reason: 'delete() reported success but the keyring still holds: $stillInKeyring',
    );

    // ...and on the next start (keyring unlocked again) the "disconnected"
    // account is back.
    backend.failDeletes = false;
    final nextStart = SecureTokenStore(await ProbedSecureStorage.open(backend: backend));
    expect(await nextStart.read('soundcloud'), isNull);
  });
}
