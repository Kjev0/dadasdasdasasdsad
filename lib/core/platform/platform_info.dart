import 'dart:io';

import 'package:flutter/foundation.dart';

/// Central platform checks (keeps `Platform.isX` out of feature code and
/// makes it overridable in tests).
class PlatformInfo {
  const PlatformInfo({required this.os});

  factory PlatformInfo.current() {
    if (kIsWeb) return const PlatformInfo(os: HostOs.other);
    if (Platform.isAndroid) return const PlatformInfo(os: HostOs.android);
    if (Platform.isLinux) return const PlatformInfo(os: HostOs.linux);
    if (Platform.isWindows) return const PlatformInfo(os: HostOs.windows);
    if (Platform.isMacOS) return const PlatformInfo(os: HostOs.macos);
    return const PlatformInfo(os: HostOs.other);
  }

  final HostOs os;

  bool get isAndroid => os == HostOs.android;
  bool get isLinux => os == HostOs.linux;
  bool get isWindows => os == HostOs.windows;
  bool get isDesktop => os == HostOs.linux || os == HostOs.windows || os == HostOs.macos;
  bool get isMobile => os == HostOs.android;

  /// Backdrop blur is supported by Flutter on all targets; low-end devices
  /// are handled by performance modes rather than here.
  bool get supportsBlur => true;
}

enum HostOs { android, linux, windows, macos, other }
