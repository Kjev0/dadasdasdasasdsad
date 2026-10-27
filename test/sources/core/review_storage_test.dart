// Adversarial review tests for secure token / credentials storage.
// Each test demonstrates a defect; they are expected to FAIL until fixed.
import 'dart:convert';

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

/// A working Secret Service whose login keyring is locked at startup: the
/// first call blocks while GNOME shows the "unlock your keyring" prompt
/// (flutter_secure_storage_linux calls secret_service_unlock_sync), then
/// everything works.
class _LockedAtStartup extends InMemoryKeyValueStore {
  _LockedAtStartup(super.initial);
  bool _unlocked = false;

  Future<void> _prompt() async {
    if (_unlocked) return;
    await Future<void>.delayed(const Duration(milliseconds: 4500)); // user types the password
    _unlocked = true;
  }

  @override
  Future<String?> read(String key) async {
    await _prompt();
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    await _prompt();
    return super.write(key, value);
  }
}

void main() {
  test('a locked-but-working keyring (unlock prompt answered after 4.5 s) is not treated as '
      '"no secure storage" for the whole session', () async {
    final stored = jsonEncodeToken(const OAuthToken(accessToken: 'a', refreshToken: 'r'));
    final backend = _LockedAtStartup({SecureTokenStore.keyFor('spotify'): stored});
    // Production default probe timeout (4 s).
    final storage = await ProbedSecureStorage.open(backend: backend);
    final tokens = SecureTokenStore(storage);

    // BUG: the 4 s probe timeout is shorter than an interactive keyring
    // unlock; the store then stays memory-only for the entire session (no
    // re-probe): the stored Spotify token is invisible (account shows as
    // disconnected) and a reconnect is not persisted either.
    expect(storage.isPersistent, isTrue, reason: 'keyring was unlocked by the user and works');
    expect(await tokens.read('spotify'), isNotNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

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

String jsonEncodeToken(OAuthToken t) => jsonEncode(t.toJson());
