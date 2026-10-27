import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'app_settings.dart';
import 'performance_profiles.dart';

final _log = Logger('settings');

/// Plain-Dart source of truth for settings (usable from services and from
/// the Android media service without widgets). Persisted as JSON with an
/// atomic write (temp file + rename) and a `.bak` copy for recovery.
class SettingsStore {
  SettingsStore._(this._file, this._current);

  /// Loads settings from [file]; falls back to the backup, then defaults.
  static Future<SettingsStore> load(File file) async {
    final settings = await _read(file) ?? await _read(File('${file.path}.bak')) ?? const AppSettings();
    return SettingsStore._(file, settings);
  }

  /// In-memory store for tests.
  factory SettingsStore.inMemory([AppSettings initial = const AppSettings()]) => SettingsStore._(null, initial);

  final File? _file;
  AppSettings _current;
  final _controller = StreamController<AppSettings>.broadcast();
  Future<void> _writeChain = Future.value();
  Timer? _debounce;

  AppSettings get current => _current;

  /// Emits the new value after every change.
  Stream<AppSettings> get changes => _controller.stream;

  String? get filePath => _file?.path;

  Future<void> update(AppSettings Function(AppSettings current) change) => replace(change(_current));

  Future<void> replace(AppSettings next) async {
    if (identical(next, _current)) return;
    _current = next;
    _controller.add(next);
    _scheduleWrite();
  }

  Future<void> applyPerformanceMode(PerformanceMode mode) => update((s) => PerformanceProfiles.apply(s, mode));

  /// Granular performance changes switch the mode to custom.
  Future<void> updatePerformance(PerformanceSettings Function(PerformanceSettings p) change) =>
      update((s) => PerformanceProfiles.markCustom(s.copyWith(performance: change(s.performance))));

  Future<void> restoreDefaults({Set<SettingsSection>? sections}) async {
    if (sections == null) {
      // Keep onboarding state so users are not sent through it again.
      await replace(AppSettings(onboardingCompleted: _current.onboardingCompleted));
      return;
    }
    var s = _current;
    for (final section in sections) {
      s = s.resetSection(section);
    }
    await replace(s);
  }

  Future<void> exportTo(String path) async {
    final json = const JsonEncoder.withIndent('  ').convert(_current.toJson());
    await File(path).writeAsString(json, flush: true);
  }

  /// Throws [FormatException] for invalid files.
  Future<void> importFrom(String path) async {
    final raw = jsonDecode(await File(path).readAsString());
    if (raw is! Map) throw const FormatException('Not a Fermata settings file');
    await replace(AppSettings.fromJson(raw.cast<String, Object?>()));
  }

  /// Write pending changes now (e.g. before exit).
  Future<void> flush() {
    _debounce?.cancel();
    _debounce = null;
    return _enqueueWrite();
  }

  void _scheduleWrite() {
    if (_file == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _debounce = null;
      _enqueueWrite();
    });
  }

  Future<void> _enqueueWrite() {
    final file = _file;
    if (file == null) return Future.value();
    final snapshot = _current;
    return _writeChain = _writeChain.then((_) => _write(file, snapshot)).catchError((Object e, StackTrace st) {
      _log.severe('Failed to persist settings', e, st);
    });
  }

  static Future<void> _write(File file, AppSettings settings) async {
    await file.parent.create(recursive: true);
    final json = const JsonEncoder.withIndent('  ').convert(settings.toJson());
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    if (await file.exists()) {
      try {
        await file.copy('${file.path}.bak');
      } on FileSystemException catch (e) {
        _log.warning('Could not write settings backup', e);
      }
    }
    await tmp.rename(file.path);
  }

  static Future<AppSettings?> _read(File file) async {
    try {
      if (!await file.exists()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return null;
      return AppSettings.fromJson(raw.cast<String, Object?>());
    } catch (e, st) {
      _log.warning('Ignoring unreadable settings file ${file.path}', e, st);
      return null;
    }
  }

  Future<void> dispose() async {
    await flush();
    await _controller.close();
  }
}
