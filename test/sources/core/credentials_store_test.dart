import 'dart:convert';
import 'dart:io';

import 'package:fermata/core/models/auth.dart';
import 'package:fermata/sources/auth/build_time_credentials.dart';
import 'package:fermata/sources/auth/credentials_store_impl.dart';
import 'package:fermata/sources/auth/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late File file;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fermata_creds');
    file = File('${tmp.path}/credentials.json');
  });
  tearDown(() => tmp.delete(recursive: true));

  CredentialsStoreImpl store(SecureKeyValueStore secure, {Map<String, SourceCredentials>? build}) =>
      CredentialsStoreImpl(configFile: file, secureStorage: secure, buildTime: build ?? const {});

  test('precedence: user-entered > credentials.json > build time', () async {
    await file.writeAsString(
      jsonEncode({
        'soundcloud': {'clientId': 'file-id', 'clientSecret': 'file-secret'},
        'jamendo': {'client_id': 'file-jamendo'},
      }),
    );
    final secure = InMemoryKeyValueStore({
      'fermata.credentials.soundcloud': jsonEncode({'clientId': 'user-id', 'clientSecret': 'user-secret'}),
    });
    final s = store(
      secure,
      build: {
        'soundcloud': const SourceCredentials(clientId: 'build-id'),
        'jamendo': const SourceCredentials(clientId: 'build-jamendo'),
        'spotify': const SourceCredentials(clientId: 'build-spotify'),
      },
    );
    await s.init();

    expect(s.get('soundcloud')!.clientId, 'user-id');
    expect(s.get('soundcloud')!.clientSecret, 'user-secret');
    expect(s.originOf('soundcloud'), CredentialOrigin.userEntered);

    expect(s.get('jamendo')!.clientId, 'file-jamendo', reason: 'snake_case keys accepted');
    expect(s.originOf('jamendo'), CredentialOrigin.configFile);

    expect(s.get('spotify')!.clientId, 'build-spotify');
    expect(s.originOf('spotify'), CredentialOrigin.buildTime);

    expect(s.get('youtube'), isNull);
    expect(s.originOf('youtube'), CredentialOrigin.none);
    expect(s.configFilePath, file.path);
  });

  test('setUserCredentials persists, overrides, notifies, and clearing falls back', () async {
    await file.writeAsString(
      jsonEncode({
        'spotify': {'clientId': 'file-spotify'},
      }),
    );
    final secure = InMemoryKeyValueStore();
    final s = store(secure);
    await s.init();
    final changes = <String>[];
    s.changes.listen(changes.add);

    await s.setUserCredentials('spotify', const SourceCredentials(clientId: '  mine  '));
    expect(s.get('spotify')!.clientId, 'mine', reason: 'trimmed');
    expect(s.originOf('spotify'), CredentialOrigin.userEntered);
    expect(jsonDecode((await secure.read('fermata.credentials.spotify'))!), {'clientId': 'mine'});

    // Survives a restart (new store over the same secure storage).
    final again = store(secure);
    await again.init();
    expect(again.get('spotify')!.clientId, 'mine');

    await s.setUserCredentials('spotify', null);
    expect(s.get('spotify')!.clientId, 'file-spotify');
    expect(s.originOf('spotify'), CredentialOrigin.configFile);
    expect(await secure.read('fermata.credentials.spotify'), isNull);
    await pumpEventQueue();
    expect(changes, ['spotify', 'spotify']);
    await s.dispose();
  });

  test('entries without client id or API key do not count', () async {
    await file.writeAsString(
      jsonEncode({
        'soundcloud': {'clientSecret': 'only-secret'},
      }),
    );
    final s = store(InMemoryKeyValueStore(), build: {'soundcloud': const SourceCredentials(clientId: 'b')});
    await s.init();
    expect(s.originOf('soundcloud'), CredentialOrigin.buildTime);
  });

  test('invalid or missing credentials.json is ignored', () async {
    final s1 = store(InMemoryKeyValueStore());
    await s1.init();
    expect(s1.get('soundcloud'), isNull);

    await file.writeAsString('{ not json');
    final s2 = store(InMemoryKeyValueStore());
    await s2.init();
    expect(s2.get('soundcloud'), isNull);

    await file.writeAsString('[1,2]');
    final s3 = store(InMemoryKeyValueStore());
    await s3.init();
    expect(s3.get('soundcloud'), isNull);
  });

  test('reloadConfigFile notifies affected sources', () async {
    final s = store(InMemoryKeyValueStore());
    await s.init();
    final changes = <String>[];
    s.changes.listen(changes.add);
    await file.writeAsString(
      jsonEncode({
        'youtube': {'apiKey': 'k'},
      }),
    );
    await s.reloadConfigFile();
    await pumpEventQueue();
    expect(changes, ['youtube']);
    expect(s.get('youtube')!.apiKey, 'k');
  });

  test('user credentials without a secure backend are kept in memory only', () async {
    final secure = ProbedSecureStorage.memoryOnly();
    final s = store(secure);
    await s.init();
    expect(s.userCredentialsPersistent, isFalse);
    await s.setUserCredentials('jamendo', const SourceCredentials(clientId: 'j'));
    expect(s.get('jamendo')!.clientId, 'j');
    expect(
      tmp.listSync().whereType<File>().where((f) => f.path.endsWith('.json')),
      isEmpty,
      reason: 'never written to a plain file',
    );
  });

  test('BuildTimeCredentials maps dart-define names per source', () {
    final m = BuildTimeCredentials.fromValues({
      'FERMATA_SOUNDCLOUD_CLIENT_ID': 'sc',
      'FERMATA_SOUNDCLOUD_CLIENT_SECRET': 'scs',
      'FERMATA_SPOTIFY_CLIENT_ID': ' sp ',
      'FERMATA_YOUTUBE_CLIENT_ID': '',
      'FERMATA_YOUTUBE_API_KEY': 'yk',
      'FERMATA_JAMENDO_CLIENT_ID': 'ja',
      'FERMATA_AUDIUS_API_KEY': 'au',
    });
    expect(m['soundcloud']!.clientId, 'sc');
    expect(m['soundcloud']!.clientSecret, 'scs');
    expect(m['spotify']!.clientId, 'sp');
    expect(m['youtube']!.clientId, isNull);
    expect(m['youtube']!.apiKey, 'yk');
    expect(m['jamendo']!.clientId, 'ja');
    expect(m['audius']!.apiKey, 'au');
    // Nothing compiled in during tests.
    expect(BuildTimeCredentials.all(), isEmpty);
    expect(BuildTimeCredentials.defineNames, contains('FERMATA_YOUTUBE_CLIENT_SECRET'));
  });
}
