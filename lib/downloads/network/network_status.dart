import 'dart:async';

import 'package:flutter/foundation.dart';

/// Kind of the active network connection (coarse, policy-relevant).
enum NetworkKind { none, wifi, ethernet, mobile, other }

/// Snapshot of the device's connectivity as far as download policy cares.
@immutable
class NetworkState {
  const NetworkState({required this.kind, required this.isMetered});

  const NetworkState.offline()
      : kind = NetworkKind.none,
        isMetered = false;

  const NetworkState.wifi()
      : kind = NetworkKind.wifi,
        isMetered = false;

  const NetworkState.mobile()
      : kind = NetworkKind.mobile,
        isMetered = true;

  final NetworkKind kind;

  /// True for cellular data (and other connections the OS reports as
  /// metered). Downloads honour `downloads.wifiOnly` on metered networks.
  final bool isMetered;

  bool get isConnected => kind != NetworkKind.none;

  @override
  bool operator ==(Object other) => other is NetworkState && other.kind == kind && other.isMetered == isMetered;

  @override
  int get hashCode => Object.hash(kind, isMetered);

  @override
  String toString() => 'NetworkState(${kind.name}${isMetered ? ', metered' : ''})';
}

/// Connectivity as seen by downloads and the stream resolver.
///
/// The production implementation is `ConnectivityNetworkStatus`
/// (connectivity_plus); tests use a fake. Bootstrap owns the instance and
/// calls [init] once before handing it to services.
abstract class NetworkStatus {
  /// Latest known state. Before [init] completes this is an optimistic
  /// "connected, unmetered" value so desktop downloads are never blocked by a
  /// missing connectivity backend.
  NetworkState get current;

  /// Emits whenever [current] changes (distinct values only).
  Stream<NetworkState> get changes;

  bool get isConnected => current.isConnected;

  /// Whether the active connection is metered (mobile data).
  bool get isMetered => current.isConnected && current.isMetered;

  /// Async variant for callers that want a fresh answer — matches the
  /// `Future<bool> Function()? isMetered` hook of `StreamResolverImpl`.
  Future<bool> isMeteredNow() async => isMetered;

  Future<void> init();

  Future<void> dispose();
}
