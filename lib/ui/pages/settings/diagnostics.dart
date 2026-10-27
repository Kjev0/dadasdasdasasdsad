import 'dart:convert';
import 'dart:io';

import '../../../core/contracts/auth.dart';
import '../../../core/contracts/music_source.dart';
import '../../../core/platform/platform_info.dart';
import '../../../settings/app_settings.dart';
import 'settings_hooks.dart';

/// Builds the "Export diagnostics" report: version, platform, non-secret
/// environment summary, settings and recent logs. Never includes tokens,
/// credentials or account names.
String buildDiagnosticsReport({
  required DateTime now,
  required PlatformInfo platform,
  required AppSettings settings,
  required List<MusicSource> sources,
  required CredentialsStore credentials,
  required TokenStore tokens,
  required String locale,
  AppVersion? version,
  String? logFilePath,
  String recentLogs = '',
}) {
  final b = StringBuffer()
    ..writeln('Fermata diagnostics')
    ..writeln('Generated: ${now.toUtc().toIso8601String()}')
    ..writeln('Version: ${version?.display ?? 'unknown'}')
    ..writeln('Platform: ${platform.os.name}')
    ..writeln('OS version: ${_safe(() => Platform.operatingSystemVersion)}')
    ..writeln('Dart: ${_safe(() => Platform.version.split(' ').first)}')
    ..writeln('Locale: $locale (setting: ${settings.localeCode ?? 'system'})')
    ..writeln('Token storage: ${tokens.isPersistent ? 'secure storage' : 'memory only (no keyring)'}')
    ..writeln('Log file: ${logFilePath ?? 'not available'}')
    ..writeln()
    ..writeln('Sources:');
  for (final s in sources) {
    final cred = s.credentialStatus;
    b.writeln('  ${s.id}: status=${s.authState.status.name}, ready=${s.isReady}, '
        'credentials=${cred.configured ? 'configured' : 'missing ${cred.missing.join('+')}'}, '
        'origin=${credentials.originOf(s.id).name}');
  }
  b
    ..writeln()
    ..writeln('Settings:')
    ..writeln(const JsonEncoder.withIndent('  ').convert(settings.toJson()))
    ..writeln()
    ..writeln('Recent log:')
    ..writeln(recentLogs.isEmpty ? '(empty)' : recentLogs);
  return b.toString();
}

String _safe(String Function() read) {
  try {
    return read();
  } catch (_) {
    return 'unknown';
  }
}
