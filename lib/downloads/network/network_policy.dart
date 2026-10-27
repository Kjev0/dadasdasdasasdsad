import '../../settings/settings_store.dart';
import 'network_status.dart';

/// Why downloads are currently held back.
enum NetworkWaitReason {
  /// No connection at all.
  offline,

  /// `downloads.wifiOnly` is on and the connection is metered.
  wifiOnly,

  /// Metered connection, Wi-Fi-only is off but `downloads.warnOnMobileData`
  /// is on and the user has not confirmed mobile data for this session.
  mobileDataConfirmation,
}

/// Download network policy: combines [NetworkStatus] with the download
/// settings. Pure decision logic — the manager reacts to the result.
class DownloadNetworkPolicy {
  DownloadNetworkPolicy({required NetworkStatus network, required SettingsStore settings})
      : _network = network,
        _settings = settings;

  final NetworkStatus _network;
  final SettingsStore _settings;
  bool _mobileDataConfirmed = false;

  NetworkStatus get network => _network;

  /// Null when downloads may run now; otherwise why they must wait.
  NetworkWaitReason? evaluate() {
    final state = _network.current;
    if (!state.isConnected) return NetworkWaitReason.offline;
    if (state.isMetered) {
      final s = _settings.current.downloads;
      if (s.wifiOnly) return NetworkWaitReason.wifiOnly;
      if (s.warnOnMobileData && !_mobileDataConfirmed) return NetworkWaitReason.mobileDataConfirmation;
    }
    return null;
  }

  /// True while downloads are held until the user confirms mobile data.
  bool get needsMobileDataConfirmation => evaluate() == NetworkWaitReason.mobileDataConfirmation;

  bool get mobileDataConfirmed => _mobileDataConfirmed;

  /// The user accepted downloading over mobile data until the app restarts.
  void confirmMobileDataForSession() => _mobileDataConfirmed = true;

  /// Background work (auto-download sync) never runs on metered networks when
  /// Wi-Fi-only is on, and never offline.
  bool get allowsBackgroundSync {
    final state = _network.current;
    if (!state.isConnected) return false;
    return !(state.isMetered && _settings.current.downloads.wifiOnly);
  }
}
