import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../core/errors.dart';
import '../core/net/http_client.dart';
import '../core/platform/app_paths.dart';
import '../core/platform/platform_info.dart';
import '../core/util/cancel_token.dart';
import '../settings/settings_store.dart';
import 'updates/semver.dart';

final _log = Logger('discovery.updates');

/// A downloadable file of a release.
@immutable
class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.downloadUrl, this.sizeBytes});

  final String name;
  final Uri downloadUrl;
  final int? sizeBytes;

  Map<String, Object?> toJson() => {'name': name, 'url': downloadUrl.toString(), if (sizeBytes != null) 'size': sizeBytes};

  static ReleaseAsset? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final url = Uri.tryParse(raw['url'] as String? ?? '');
    final name = raw['name'] as String?;
    if (url == null || name == null) return null;
    return ReleaseAsset(name: name, downloadUrl: url, sizeBytes: (raw['size'] as num?)?.toInt());
  }
}

enum UpdateStatus {
  /// The installed version is the latest (or newer).
  upToDate,

  /// A newer release exists — show [UpdateCheckResult.releaseNotesUrl].
  updateAvailable,

  /// The repository has no published release yet.
  noReleases,
}

/// Outcome of an update check. Fermata never downloads or installs
/// updates itself; the UI links to the release page.
@immutable
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    required this.checkedAt,
    this.latestVersion,
    this.releaseName,
    this.releaseNotesUrl,
    this.releaseNotes,
    this.publishedAt,
    this.assets = const [],
  });

  final UpdateStatus status;
  final String currentVersion;
  final String? latestVersion;
  final String? releaseName;

  /// The release's GitHub page (notes + downloads).
  final Uri? releaseNotesUrl;

  /// Markdown body of the release.
  final String? releaseNotes;
  final DateTime? publishedAt;

  /// Assets for the current platform only (APK on Android, installers /
  /// archives for Linux or Windows).
  final List<ReleaseAsset> assets;
  final DateTime checkedAt;

  bool get updateAvailable => status == UpdateStatus.updateAvailable;

  Map<String, Object?> toJson() => {
        'status': status.name,
        'current': currentVersion,
        'checkedAt': checkedAt.toIso8601String(),
        if (latestVersion != null) 'latest': latestVersion,
        if (releaseName != null) 'name': releaseName,
        if (releaseNotesUrl != null) 'url': releaseNotesUrl.toString(),
        if (releaseNotes != null) 'notes': releaseNotes,
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
        'assets': [for (final a in assets) a.toJson()],
      };

  static UpdateCheckResult? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final status = UpdateStatus.values.asNameMap()[raw['status']];
    final checkedAt = DateTime.tryParse(raw['checkedAt'] as String? ?? '');
    final current = raw['current'] as String?;
    if (status == null || checkedAt == null || current == null) return null;
    return UpdateCheckResult(
      status: status,
      currentVersion: current,
      checkedAt: checkedAt,
      latestVersion: raw['latest'] as String?,
      releaseName: raw['name'] as String?,
      releaseNotesUrl: raw['url'] == null ? null : Uri.tryParse(raw['url'] as String),
      releaseNotes: raw['notes'] as String?,
      publishedAt: raw['publishedAt'] == null ? null : DateTime.tryParse(raw['publishedAt'] as String),
      assets: [for (final a in (raw['assets'] as List? ?? const [])) ?ReleaseAsset.fromJson(a)],
    );
  }
}

/// Opt-in update check against the project's GitHub Releases.
///
/// * [checkIfDue] does nothing unless `updates.checkForUpdates` is on, and
///   queries GitHub at most once per [minInterval] (default: a day; the last
///   check survives restarts in `<supportDir>/update_check.json`).
/// * [checkNow] is for an explicit "Check for updates" button: it skips the
///   daily limit (the click itself is the consent).
/// * Compares the release tag with the installed version (SemVer) and
///   returns the release page URL and the asset names for this platform.
/// * No auto-download, no auto-install: updating stays a user action.
class UpdateChecker {
  UpdateChecker(
    this._http,
    this._settings,
    AppPaths paths, {
    PlatformInfo? platform,
    Future<String> Function()? currentVersion,
    DateTime Function()? clock,
    Uri? endpoint,
    this.minInterval = const Duration(days: 1),
  })  : _platform = platform ?? PlatformInfo.current(),
        _currentVersion = currentVersion ?? _packageVersion,
        _clock = clock ?? DateTime.now,
        endpoint = endpoint ?? defaultEndpoint,
        _stateFile = File(p.join(paths.supportDir.path, 'update_check.json'));

  static final defaultEndpoint = Uri.parse('https://api.github.com/repos/kjev0/dadasdasdasasdsad/releases/latest');

  final FermataHttp _http;
  final SettingsStore _settings;
  final PlatformInfo _platform;
  final Future<String> Function() _currentVersion;
  final DateTime Function() _clock;
  final File _stateFile;
  final Uri endpoint;
  final Duration minInterval;

  _State? _state;

  static Future<String> _packageVersion() async => (await PackageInfo.fromPlatform()).version;

  /// The last stored result (from this or an earlier session).
  Future<UpdateCheckResult?> lastResult() async => (await _loadState()).result;

  /// Automatic check (e.g. at startup): null when disabled by the user or
  /// when the last check is younger than [minInterval] (then the stored
  /// result is not re-reported). Network failures return null and are
  /// retried on the next due check.
  Future<UpdateCheckResult?> checkIfDue({CancelToken? cancel}) async {
    if (!_settings.current.updates.checkForUpdates) return null;
    final state = await _loadState();
    final last = state.lastAttempt;
    if (last != null && _clock().difference(last) < minInterval && !_clock().isBefore(last)) return null;
    try {
      return await checkNow(cancel: cancel);
    } on OperationCanceledException {
      rethrow;
    } on FermataException catch (e) {
      _log.info('Update check failed: ${e.code}');
      return null;
    }
  }

  /// Queries GitHub now (explicit user action). Throws typed
  /// [FermataException]s on failure.
  Future<UpdateCheckResult> checkNow({CancelToken? cancel}) async {
    final state = await _loadState();
    final now = _clock();
    state.lastAttempt = now;
    await _saveState(state);
    final current = await _currentVersion();
    final response = await _http.get(endpoint,
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          if (state.etag != null && state.release != null) 'If-None-Match': state.etag!,
        },
        cancel: cancel);
    Map<String, Object?>? release;
    switch (response.statusCode) {
      case 200:
        final json = FermataHttp.decodeJsonResponse(response);
        if (json is! Map) throw const ApiException(200, 'Unexpected GitHub release payload');
        release = json.cast<String, Object?>();
        state.etag = response.headers['etag'];
        state.release = release;
      case 304:
        release = state.release;
      case 404:
        state.etag = null;
        state.release = null;
      case 403 || 429 when response.headers['x-ratelimit-remaining'] == '0' || response.statusCode == 429:
        final reset = int.tryParse(response.headers['x-ratelimit-reset'] ?? '');
        final retry = reset == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(reset * 1000).difference(_clock());
        throw RateLimitedException('GitHub API rate limit', retryAfter: retry == null || retry.isNegative ? null : retry);
      default:
        FermataHttp.decodeJsonResponse(response); // throws ApiException
    }
    final result = release == null
        ? UpdateCheckResult(status: UpdateStatus.noReleases, currentVersion: current, checkedAt: now)
        : evaluate(release, currentVersion: current, platform: _platform, checkedAt: now);
    state.result = result;
    await _saveState(state);
    return result;
  }

  /// Compares a GitHub release object with [currentVersion].
  static UpdateCheckResult evaluate(
    Map<String, Object?> release, {
    required String currentVersion,
    required PlatformInfo platform,
    required DateTime checkedAt,
  }) {
    final tag = (release['tag_name'] as String? ?? '').trim();
    final latest = SemVer.tryParse(tag);
    final current = SemVer.tryParse(currentVersion);
    final newer = latest != null && current != null && latest > current;
    if (latest == null) _log.warning('Release tag "$tag" is not a semantic version');
    final assets = [
      for (final a in (release['assets'] as List? ?? const []))
        if (a is Map) ?_asset(a.cast<String, Object?>()),
    ];
    return UpdateCheckResult(
      status: newer ? UpdateStatus.updateAvailable : UpdateStatus.upToDate,
      currentVersion: currentVersion,
      latestVersion: latest?.toString() ?? (tag.isEmpty ? null : tag),
      releaseName: release['name'] as String?,
      releaseNotesUrl: Uri.tryParse(release['html_url'] as String? ?? ''),
      releaseNotes: release['body'] as String?,
      publishedAt: DateTime.tryParse(release['published_at'] as String? ?? ''),
      assets: assetsFor(platform, assets),
      checkedAt: checkedAt,
    );
  }

  static ReleaseAsset? _asset(Map<String, Object?> a) {
    final name = a['name'] as String?;
    final url = Uri.tryParse(a['browser_download_url'] as String? ?? '');
    if (name == null || url == null || !url.hasScheme) return null;
    return ReleaseAsset(name: name, downloadUrl: url, sizeBytes: (a['size'] as num?)?.toInt());
  }

  static const _checksumExts = ['.sha256', '.sha512', '.sha1', '.md5', '.asc', '.sig', '.minisig', '.txt'];

  /// Release assets relevant to [platform]:
  /// * Android: `.apk`;
  /// * Linux: names containing "linux", or `.AppImage`, `.deb`, `.rpm`,
  ///   `.flatpak`, `.snap`, `.sh` installers;
  /// * Windows: names containing "windows"/"win64"/"win32", or `.exe`,
  ///   `.msi`, `.msix`, `.appx`.
  /// Checksums/signatures are omitted.
  static List<ReleaseAsset> assetsFor(PlatformInfo platform, List<ReleaseAsset> assets) {
    bool matches(ReleaseAsset a) {
      final n = a.name.toLowerCase();
      if (_checksumExts.any(n.endsWith)) return false;
      bool ext(List<String> exts) => exts.any(n.endsWith);
      return switch (platform.os) {
        HostOs.android => ext(const ['.apk']),
        HostOs.linux => (n.contains('linux') && !ext(const ['.apk', '.exe', '.msi'])) ||
            ext(const ['.appimage', '.deb', '.rpm', '.flatpak', '.snap', '.sh']),
        HostOs.windows => ((n.contains('windows') || n.contains('win64') || n.contains('win32')) &&
                !ext(const ['.apk', '.deb', '.rpm', '.appimage'])) ||
            ext(const ['.exe', '.msi', '.msix', '.appx']),
        HostOs.macos => n.contains('mac') || ext(const ['.dmg', '.pkg']),
        HostOs.other => false,
      };
    }

    return [for (final a in assets) if (matches(a)) a];
  }

  // ---- Persistence ------------------------------------------------------------

  Future<_State> _loadState() async {
    final cached = _state;
    if (cached != null) return cached;
    final state = _State();
    try {
      if (await _stateFile.exists()) {
        final raw = jsonDecode(await _stateFile.readAsString());
        if (raw is Map) {
          state.lastAttempt = DateTime.tryParse(raw['lastAttempt'] as String? ?? '');
          state.etag = raw['etag'] as String?;
          state.release = raw['release'] is Map ? (raw['release'] as Map).cast<String, Object?>() : null;
          state.result = UpdateCheckResult.fromJson(raw['result']);
        }
      }
    } catch (e) {
      _log.fine('Ignoring unreadable update state', e);
    }
    return _state = state;
  }

  Future<void> _saveState(_State s) async {
    try {
      await _stateFile.parent.create(recursive: true);
      final tmp = File('${_stateFile.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        if (s.lastAttempt != null) 'lastAttempt': s.lastAttempt!.toIso8601String(),
        if (s.etag != null) 'etag': s.etag,
        if (s.release != null) 'release': s.release,
        if (s.result != null) 'result': s.result!.toJson(),
      }));
      await tmp.rename(_stateFile.path);
    } catch (e) {
      _log.warning('Could not persist update state', e);
    }
  }
}

class _State {
  DateTime? lastAttempt;
  String? etag;
  Map<String, Object?>? release;
  UpdateCheckResult? result;
}
