import 'dart:convert';
import 'dart:typed_data';

import '../../../core/contracts/library.dart';
import '../../../settings/app_settings.dart';
import '../../../settings/settings_store.dart';

/// Settings and library backup files (Settings → Privacy).
abstract final class DataTransfer {
  static const _encoder = JsonEncoder.withIndent('  ');

  /// The current settings as a JSON file. Settings never contain secrets
  /// (tokens and credentials live in secure storage).
  static Uint8List encodeSettings(AppSettings settings) =>
      Uint8List.fromList(utf8.encode(_encoder.convert(settings.toJson())));

  /// Parses a settings file; throws [FormatException] for anything that is
  /// not a Fermata settings object.
  static AppSettings decodeSettings(Uint8List bytes) {
    final Object? raw;
    try {
      raw = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const FormatException('Not a Fermata settings file');
    }
    if (raw is! Map || !raw.containsKey('schemaVersion')) throw const FormatException('Not a Fermata settings file');
    return AppSettings.fromJson(raw.cast<String, Object?>());
  }

  /// Replaces the settings with an imported file, keeping the onboarding
  /// state of this installation.
  static Future<void> importSettings(SettingsStore store, Uint8List bytes) async {
    final imported = decodeSettings(bytes);
    await store.replace(imported.copyWith(onboardingCompleted: store.current.onboardingCompleted));
  }

  static Future<Uint8List> exportLibrary(LibraryMaintenance maintenance) async =>
      Uint8List.fromList(utf8.encode(_encoder.convert(await maintenance.exportBackup())));

  /// Parses a library backup; throws [FormatException] when it isn't a JSON
  /// object.
  static Map<String, Object?> decodeLibrary(Uint8List bytes) {
    final Object? raw;
    try {
      raw = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const FormatException('Not a Fermata backup');
    }
    if (raw is! Map) throw const FormatException('Not a Fermata backup');
    return raw.cast<String, Object?>();
  }

  /// `fermata-<what>-2026-10-27.<ext>`
  static String fileName(String what, String ext, DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'fermata-$what-${now.year}-${two(now.month)}-${two(now.day)}.$ext';
  }
}
