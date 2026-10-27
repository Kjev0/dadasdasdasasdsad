import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Structured logging: one JSON object per line in `<support>/logs/fermata.log`
/// (rotated at 2 MB, 3 files kept) plus readable console output in debug.
///
/// Usage everywhere: `final _log = Logger('module.sub');` and
/// `_log.info('message', error, stackTrace)`. Never log tokens or secrets.
class AppLogging {
  AppLogging._();

  static IOSink? _sink;
  static File? _file;
  static StreamSubscription<LogRecord>? _sub;
  static const _maxBytes = 2 * 1024 * 1024;
  static const _keep = 3;
  static int _written = 0;

  static File? get currentLogFile => _file;

  static Future<void> init({Directory? logsDir, Level level = Level.INFO}) async {
    hierarchicalLoggingEnabled = true;
    Logger.root.level = kDebugMode ? Level.FINE : level;
    if (logsDir != null) {
      await logsDir.create(recursive: true);
      _file = File(p.join(logsDir.path, 'fermata.log'));
      await _rotateIfNeeded();
      _sink = _file!.openWrite(mode: FileMode.append);
      _written = await _file!.length();
    }
    await _sub?.cancel();
    _sub = Logger.root.onRecord.listen(_onRecord);
    FlutterError.onError = (details) {
      Logger('flutter').severe(details.exceptionAsString(), details.exception, details.stack);
      if (kDebugMode) FlutterError.dumpErrorToConsole(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      Logger('uncaught').severe('Uncaught error', error, stack);
      return true;
    };
  }

  static void _onRecord(LogRecord r) {
    if (kDebugMode || r.level >= Level.WARNING) {
      final err = r.error == null ? '' : ' | ${r.error}';
      debugPrint('[${r.level.name}] ${r.loggerName}: ${r.message}$err');
    }
    final sink = _sink;
    if (sink == null) return;
    final line = jsonEncode({
      't': r.time.toIso8601String(),
      'l': r.level.name,
      'n': r.loggerName,
      'm': r.message,
      if (r.error != null) 'e': r.error.toString(),
      if (r.stackTrace != null && r.level >= Level.SEVERE) 's': r.stackTrace.toString(),
    });
    sink.writeln(line);
    _written += line.length + 1;
    if (_written > _maxBytes) {
      unawaited(_rotateNow());
    }
  }

  static Future<void> _rotateNow() async {
    final sink = _sink;
    _sink = null;
    await sink?.flush();
    await sink?.close();
    await _rotateIfNeeded(force: true);
    _sink = _file!.openWrite(mode: FileMode.append);
    _written = 0;
  }

  static Future<void> _rotateIfNeeded({bool force = false}) async {
    final f = _file;
    if (f == null || !await f.exists()) return;
    if (!force && await f.length() < _maxBytes) return;
    for (var i = _keep - 1; i >= 1; i--) {
      final older = File('${f.path}.$i');
      if (await older.exists()) await older.rename('${f.path}.${i + 1}');
    }
    await f.rename('${f.path}.1');
  }

  /// Concatenated recent logs for "Export diagnostics".
  static Future<String> readRecent({int maxBytes = 512 * 1024}) async {
    final f = _file;
    if (f == null || !await f.exists()) return '';
    await _sink?.flush();
    final bytes = await f.readAsBytes();
    final start = bytes.length > maxBytes ? bytes.length - maxBytes : 0;
    return utf8.decode(bytes.sublist(start), allowMalformed: true);
  }

  static Future<void> close() async {
    await _sub?.cancel();
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}
