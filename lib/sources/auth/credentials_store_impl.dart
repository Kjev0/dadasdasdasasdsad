import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../../core/contracts/auth.dart';
import '../../core/models/auth.dart';
import '../base/json_utils.dart';
import 'build_time_credentials.dart';
import 'secure_storage.dart';

final _log = Logger('sources.auth.credentials');

/// Resolves developer credentials (client id/secret, API key) per source.
///
/// Precedence (whole record — the first origin that has a client id or API
/// key wins):
/// 1. user-entered, kept in secure storage under
///    `fermata.credentials.<sourceId>`;
/// 2. `<appSupport>/credentials.json`:
///    `{ "soundcloud": { "clientId": "…", "clientSecret": "…" }, … }`
///    (snake_case keys are accepted too);
/// 3. build-time `--dart-define` values ([BuildTimeCredentials]).
///
/// Secrets are never logged. See docs/CREDENTIALS.md.
class CredentialsStoreImpl implements CredentialsStore {
  CredentialsStoreImpl({
    required this._configFile,
    required SecureKeyValueStore secureStorage,
    Map<String, SourceCredentials>? buildTime,
  }) : _secure = secureStorage,
       _buildTime = Map.unmodifiable(buildTime ?? BuildTimeCredentials.all());

  static const keyPrefix = 'fermata.credentials.';

  static String keyFor(String sourceId) => '$keyPrefix$sourceId';

  final File _configFile;
  final SecureKeyValueStore _secure;
  final Map<String, SourceCredentials> _buildTime;
  final Map<String, SourceCredentials> _user = {};
  Map<String, SourceCredentials> _file = const {};
  final StreamController<String> _changes = StreamController<String>.broadcast();

  @override
  String get configFilePath => _configFile.path;

  /// Whether user-entered credentials survive a restart (false when the
  /// secure backend is unavailable and they only live in memory).
  bool get userCredentialsPersistent {
    final s = _secure;
    return s is! ProbedSecureStorage || s.isPersistent;
  }

  @override
  Stream<String> get changes => _changes.stream;

  @override
  Future<void> init() async {
    try {
      final all = await _secure.readAll();
      for (final entry in all.entries) {
        if (!entry.key.startsWith(keyPrefix)) continue;
        final id = entry.key.substring(keyPrefix.length);
        final creds = _decode(entry.value);
        if (creds != null && !creds.isEmpty) _user[id] = creds;
      }
    } catch (e) {
      _log.warning('Could not read user-entered credentials: ${e.runtimeType}');
    }
    _file = await _readConfigFile();
  }

  /// Re-reads `credentials.json` and notifies sources whose effective
  /// credentials changed.
  Future<void> reloadConfigFile() async {
    final before = {for (final id in _knownIds()) id: _fingerprint(get(id))};
    _file = await _readConfigFile();
    for (final id in _knownIds()) {
      if (before[id] != _fingerprint(get(id))) _changes.add(id);
    }
  }

  @override
  SourceCredentials? get(String sourceId) => _resolve(sourceId).$1;

  @override
  CredentialOrigin originOf(String sourceId) => _resolve(sourceId).$2;

  (SourceCredentials?, CredentialOrigin) _resolve(String id) {
    final user = _user[id];
    if (user != null && !user.isEmpty) return (user, CredentialOrigin.userEntered);
    final file = _file[id];
    if (file != null && !file.isEmpty) return (file, CredentialOrigin.configFile);
    final build = _buildTime[id];
    if (build != null && !build.isEmpty) return (build, CredentialOrigin.buildTime);
    return (null, CredentialOrigin.none);
  }

  @override
  Future<void> setUserCredentials(String sourceId, SourceCredentials? credentials) async {
    if (credentials == null || credentials.isEmpty) {
      _user.remove(sourceId);
      await _secure.delete(keyFor(sourceId));
    } else {
      final cleaned = _clean(credentials);
      _user[sourceId] = cleaned;
      await _secure.write(keyFor(sourceId), jsonEncode(cleaned.toJson()));
    }
    // Always notify: even identical values can change the origin shown in UI.
    _changes.add(sourceId);
  }

  Future<void> dispose() => _changes.close();

  Iterable<String> _knownIds() => {..._user.keys, ..._file.keys, ..._buildTime.keys};

  static String? _fingerprint(SourceCredentials? c) => c == null ? null : jsonEncode(c.toJson());

  static SourceCredentials _clean(SourceCredentials c) {
    String? t(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    return SourceCredentials(
      clientId: t(c.clientId),
      clientSecret: t(c.clientSecret),
      apiKey: t(c.apiKey),
      redirectUri: t(c.redirectUri),
    );
  }

  static SourceCredentials? _decode(String raw) {
    try {
      final json = jsonDecode(raw);
      return json is Map ? _fromLooseJson(json.cast<String, Object?>()) : null;
    } catch (_) {
      return null;
    }
  }

  /// Accepts camelCase (documented) and snake_case keys.
  static SourceCredentials _fromLooseJson(Map<String, Object?> j) => SourceCredentials(
    clientId: jsonString(j['clientId'] ?? j['client_id']),
    clientSecret: jsonString(j['clientSecret'] ?? j['client_secret']),
    apiKey: jsonString(j['apiKey'] ?? j['api_key']),
    redirectUri: jsonString(j['redirectUri'] ?? j['redirect_uri']),
  );

  Future<Map<String, SourceCredentials>> _readConfigFile() async {
    try {
      if (!await _configFile.exists()) return const {};
      final raw = jsonDecode(await _configFile.readAsString());
      if (raw is! Map) {
        _log.warning('Ignoring ${_configFile.path}: top level must be an object');
        return const {};
      }
      final result = <String, SourceCredentials>{};
      raw.forEach((key, value) {
        if (key is String && value is Map) {
          final c = _fromLooseJson(value.cast<String, Object?>());
          if (!c.isEmpty) result[key.trim().toLowerCase()] = c;
        }
      });
      return result;
    } on FormatException catch (e) {
      _log.warning('Ignoring invalid JSON in ${_configFile.path}: ${e.message}');
      return const {};
    } on FileSystemException catch (e) {
      _log.warning('Cannot read ${_configFile.path}: ${e.message}');
      return const {};
    }
  }
}
