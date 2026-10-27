import 'dart:async';

import 'package:logging/logging.dart';

import '../../settings/app_settings.dart';
import '../../settings/settings_store.dart';

final _log = Logger('downloads.sync');

/// Runs the auto-download sync periodically while
/// `performance.backgroundSync` is on (every `syncIntervalMinutes`), and
/// reconfigures itself when those settings change.
class AutoDownloadScheduler {
  AutoDownloadScheduler({required this._settings, required this._sync});

  final SettingsStore _settings;
  final Future<void> Function() _sync;
  Timer? _timer;
  StreamSubscription<AppSettings>? _sub;
  (bool, int)? _config;

  bool get isScheduled => _timer != null;

  void start() {
    _sub ??= _settings.changes.listen((_) => _apply());
    _apply();
  }

  void _apply() {
    final p = _settings.current.performance;
    final next = (p.backgroundSync, p.syncIntervalMinutes);
    if (next == _config) return;
    _config = next;
    _timer?.cancel();
    _timer = null;
    if (!p.backgroundSync) return;
    _timer = Timer.periodic(Duration(minutes: p.syncIntervalMinutes), (_) {
      _sync().catchError((Object e) => _log.warning('Periodic auto-download sync failed', e));
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _sub?.cancel();
    _sub = null;
    _config = null;
  }
}
