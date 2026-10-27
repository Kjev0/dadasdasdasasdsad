import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';

import '../../core/platform/platform_info.dart';
import 'network_status.dart';

final _log = Logger('downloads.network');

/// [NetworkStatus] backed by `connectivity_plus`.
///
/// * Android: Wi-Fi/Ethernet are unmetered; cellular, satellite, Bluetooth
///   tethering and unknown transports are treated as metered (connectivity_plus
///   does not expose `ConnectivityManager.isActiveNetworkMetered`).
/// * Linux (NetworkManager over D-Bus) / Windows: only an explicit `mobile`
///   connection without Wi-Fi/Ethernet is metered. When the backend is not
///   available (e.g. no NetworkManager) we assume "connected, unmetered" so
///   downloads are never blocked by a missing daemon.
class ConnectivityNetworkStatus extends NetworkStatus {
  ConnectivityNetworkStatus({Connectivity? connectivity, PlatformInfo? platform})
      : _connectivity = connectivity,
        _platform = platform ?? PlatformInfo.current();

  Connectivity? _connectivity;
  final PlatformInfo _platform;
  final _controller = StreamController<NetworkState>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _initialized = false;

  NetworkState _current = const NetworkState.wifi();

  @override
  NetworkState get current => _current;

  @override
  Stream<NetworkState> get changes => _controller.stream;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final connectivity = _connectivity ??= Connectivity();
    try {
      _set(mapResults(await connectivity.checkConnectivity(), mobilePlatform: _platform.isMobile));
    } catch (e) {
      _log.info('Connectivity backend unavailable; assuming an unmetered connection', e);
    }
    try {
      _sub = connectivity.onConnectivityChanged.listen(
        (results) => _set(mapResults(results, mobilePlatform: _platform.isMobile)),
        onError: (Object e) => _log.fine('Connectivity stream error (ignored)', e),
      );
    } catch (e) {
      _log.info('Connectivity change stream unavailable', e);
    }
  }

  @override
  Future<bool> isMeteredNow() async {
    final connectivity = _connectivity;
    if (connectivity != null) {
      try {
        _set(mapResults(await connectivity.checkConnectivity(), mobilePlatform: _platform.isMobile));
      } catch (_) {
        // keep the last known state
      }
    }
    return isMetered;
  }

  void _set(NetworkState next) {
    if (next == _current) return;
    _log.fine('Network changed: $_current -> $next');
    _current = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  /// Maps connectivity_plus results to a [NetworkState]. Public for tests.
  static NetworkState mapResults(List<ConnectivityResult> results, {required bool mobilePlatform}) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return const NetworkState.offline();
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return const NetworkState(kind: NetworkKind.ethernet, isMetered: false);
    }
    // Satellite links are reported alongside `mobile` and are always metered.
    if (results.contains(ConnectivityResult.wifi) && !results.contains(ConnectivityResult.satellite)) {
      return const NetworkState.wifi();
    }
    if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.satellite)) {
      return const NetworkState.mobile();
    }
    // vpn / bluetooth / other without a known underlying transport.
    return NetworkState(kind: NetworkKind.other, isMetered: mobilePlatform);
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _controller.close();
  }
}
