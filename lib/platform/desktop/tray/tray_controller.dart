import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../../core/contracts/playback.dart';
import '../../../core/models/playback.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../settings/app_settings.dart';
import '../../../settings/settings_store.dart';
import '../desktop_l10n.dart';
import 'tray_availability.dart';
import 'tray_backend.dart';
import 'tray_menu.dart';

final _log = Logger('desktop.tray');

/// Why the tray icon is (not) shown.
enum TrayStatus {
  /// Not started yet.
  pending,

  /// The icon is shown.
  active,

  /// `desktop.showTrayIcon` is off.
  disabledBySetting,

  /// GNOME without the AppIndicator extension.
  gnomeWithoutAppIndicator,

  /// No StatusNotifier host on the session bus.
  noStatusNotifierHost,

  /// The session bus is unreachable.
  noSessionBus,

  /// The icon file is missing from the installation.
  iconMissing,

  /// The platform refused the icon.
  failed,

  /// No tray on this platform.
  unsupported,
}

/// Owns the tray icon: creates/destroys it following `desktop.showTrayIcon`
/// and host availability, keeps the tooltip and context menu in sync with
/// playback (rebuilding only when track/playing/locale change, debounced) and
/// routes menu clicks.
class TrayController {
  TrayController({
    required this._backend,
    required this._probe,
    required SettingsStore settings,
    required this._playback,
    required this._resolveIconPath,
    AppLocalizations Function()? strings,
    this.menuDebounce = const Duration(milliseconds: 120),
  })  : _settings = settings,
        _strings = strings ?? desktopStringsFor(settings);

  final TrayBackend _backend;
  final TrayAvailabilityProbe _probe;
  final SettingsStore _settings;
  final PlaybackController _playback;
  final Future<String?> Function() _resolveIconPath;
  final AppLocalizations Function() _strings;
  final Duration menuDebounce;

  /// Called for "Show Fermata" and a left click on the icon (Windows).
  Future<void> Function()? onShowWindow;

  /// Called for "Quit Fermata".
  Future<void> Function()? onQuit;

  TrayStatus _status = TrayStatus.pending;
  bool _active = false;
  bool _disposed = false;
  bool? _lastShowSetting;
  String? _lastLocale;
  TrayMenuState? _appliedState;
  TrayMenuState? _pendingState;
  Timer? _menuTimer;
  Future<void> _chain = Future.value();
  final _subs = <StreamSubscription<Object?>>[];
  final _activeChanges = StreamController<bool>.broadcast();

  TrayStatus get status => _status;

  /// True while the icon is shown (the window may be hidden to it).
  bool get isActive => _active;

  /// Emits [isActive] whenever it changes.
  Stream<bool> get activeChanges => _activeChanges.stream;

  /// Localized explanation when the tray is not shown, null when it is.
  String? get unavailableReason => reasonText(_status, _strings());

  /// Maps a [TrayStatus] to its localized explanation (null when active).
  static String? reasonText(TrayStatus status, AppLocalizations l10n) => switch (status) {
        TrayStatus.active || TrayStatus.pending => null,
        TrayStatus.disabledBySetting => l10n.desktopTrayUnavailableDisabled,
        TrayStatus.gnomeWithoutAppIndicator => l10n.desktopTrayUnavailableGnome,
        TrayStatus.noStatusNotifierHost => l10n.desktopTrayUnavailableNoHost,
        TrayStatus.noSessionBus => l10n.desktopTrayUnavailableNoBus,
        TrayStatus.iconMissing => l10n.desktopTrayUnavailableIconMissing,
        TrayStatus.failed => l10n.desktopTrayUnavailableFailed,
        TrayStatus.unsupported => l10n.desktopTrayUnavailableUnsupported,
      };

  /// The menu state currently shown (for tests and diagnostics).
  @visibleForTesting
  TrayMenuState? get appliedState => _appliedState;

  /// Checks availability, creates the icon when allowed and starts
  /// following settings, host changes and playback.
  Future<void> start() async {
    _lastShowSetting = _settings.current.desktop.showTrayIcon;
    _lastLocale = _settings.current.localeCode;
    _subs.add(_settings.changes.listen(_onSettings));
    _subs.add(_probe.hostChanges.listen((_) => _enqueue(() => _reconcile(recreate: true))));
    _subs.add(_playback.snapshots.listen((s) => _onPlayback(s)));
    await _enqueue(_reconcile);
  }

  void _onSettings(AppSettings s) {
    final show = s.desktop.showTrayIcon;
    if (show != _lastShowSetting) {
      _lastShowSetting = show;
      _enqueue(_reconcile);
    }
    if (s.localeCode != _lastLocale) {
      _lastLocale = s.localeCode;
      _onPlayback(_playback.snapshot);
    }
  }

  void _onPlayback(PlaybackSnapshot snapshot) {
    if (!_active || _disposed) return;
    final state = TrayMenuState.fromSnapshot(snapshot, localeName: _strings().localeName);
    if (state == (_pendingState ?? _appliedState)) return;
    _pendingState = state;
    _menuTimer?.cancel();
    _menuTimer = Timer(menuDebounce, () {
      final pending = _pendingState;
      _pendingState = null;
      if (pending != null) _enqueue(() => _applyMenu(pending));
    });
  }

  Future<void> _enqueue(Future<void> Function() op) {
    return _chain = _chain.then((_) async {
      if (_disposed) return;
      try {
        await op();
      } catch (e, st) {
        _log.warning('Tray operation failed', e, st);
      }
    });
  }

  Future<void> _reconcile({bool recreate = false}) async {
    if (!_settings.current.desktop.showTrayIcon) {
      await _destroyIcon();
      _status = TrayStatus.disabledBySetting;
      return;
    }
    final host = await _probe.check();
    if (host != TrayHostState.available) {
      await _destroyIcon();
      _status = switch (host) {
        TrayHostState.gnomeWithoutAppIndicator => TrayStatus.gnomeWithoutAppIndicator,
        TrayHostState.noHost => TrayStatus.noStatusNotifierHost,
        TrayHostState.noSessionBus => TrayStatus.noSessionBus,
        TrayHostState.unsupported => TrayStatus.unsupported,
        TrayHostState.available => TrayStatus.active,
      };
      _log.info('Tray not available: $_status');
      return;
    }
    if (_active && !recreate) return;
    if (_active) await _destroyIcon(); // re-register with a restarted host

    final path = await _resolveIconPath();
    if (path == null) {
      _status = TrayStatus.iconMissing;
      return;
    }
    final ok = await _backend.create(iconPath: path, onActivate: _onActivate, onMenuItem: _onMenuItem);
    if (!ok) {
      _status = TrayStatus.failed;
      return;
    }
    _status = TrayStatus.active;
    _setActive(true);
    await _applyMenu(TrayMenuState.fromSnapshot(_playback.snapshot, localeName: _strings().localeName));
  }

  Future<void> _applyMenu(TrayMenuState state) async {
    if (!_active) return;
    final l10n = _strings();
    _appliedState = state;
    await _backend.setMenu(state.entries(l10n));
    final tip = state.tooltip(l10n);
    // Windows truncates tooltips at 127 characters.
    await _backend.setTooltip(tip.length > 127 ? '${tip.substring(0, 126)}…' : tip);
  }

  Future<void> _destroyIcon() async {
    _menuTimer?.cancel();
    _pendingState = null;
    if (!_active) return;
    await _backend.destroy();
    _appliedState = null;
    _setActive(false);
  }

  void _setActive(bool value) {
    if (_active == value) return;
    _active = value;
    if (!_activeChanges.isClosed) _activeChanges.add(value);
  }

  void _onActivate() => _run('show', () => onShowWindow?.call() ?? Future.value());

  void _onMenuItem(String id) {
    switch (id) {
      case TrayMenuIds.playPause:
        _run(id, _playback.togglePlayPause);
      case TrayMenuIds.previous:
        _run(id, _playback.previous);
      case TrayMenuIds.next:
        _run(id, _playback.next);
      case TrayMenuIds.show:
        _run(id, () => onShowWindow?.call() ?? Future.value());
      case TrayMenuIds.quit:
        _run(id, () => onQuit?.call() ?? Future.value());
    }
  }

  void _run(String what, Future<void> Function() action) {
    unawaited(Future.sync(action).catchError((Object e, StackTrace st) {
      _log.warning('Tray action "$what" failed', e, st);
    }));
  }

  /// Simulates a click (tests / keyboard access to the same actions).
  @visibleForTesting
  void debugClick(String id) => id == 'activate' ? _onActivate() : _onMenuItem(id);

  /// Waits for queued tray operations (tests).
  @visibleForTesting
  Future<void> get idle => _chain;

  Future<void> dispose() async {
    if (_disposed) return;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _menuTimer?.cancel();
    await _chain;
    _disposed = true;
    if (_active) {
      try {
        await _backend.destroy();
      } catch (e) {
        _log.fine('Tray destroy failed: $e');
      }
      _setActive(false);
    }
    await _probe.dispose();
    await _activeChanges.close();
  }
}
