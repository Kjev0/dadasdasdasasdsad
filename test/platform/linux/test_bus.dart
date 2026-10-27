import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';

/// A private D-Bus session bus (`dbus-daemon`) for integration tests, with
/// no activatable services, so tests never touch the developer's session.
class TestBus {
  TestBus._(this._process, this._dir, this.address);

  final Process _process;
  final Directory _dir;

  /// e.g. `unix:path=/tmp/fermata-bus-xxx/bus,guid=...`
  final String address;

  static bool get available =>
      Platform.isLinux && Process.runSync('which', ['dbus-daemon']).exitCode == 0;

  static Future<TestBus> start() async {
    final dir = await Directory.systemTemp.createTemp('fermata-bus-');
    final config = File('${dir.path}/bus.conf');
    await config.writeAsString('''<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:path=${dir.path}/bus</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
''');
    final process = await Process.start('dbus-daemon', ['--config-file=${config.path}', '--nofork', '--print-address=1']);
    final address = await process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 10));
    process.stderr.drain<void>();
    return TestBus._(process, dir, address.trim());
  }

  DBusClient client() => DBusClient(DBusAddress(address));

  /// Environment for child processes (playerctl, gdbus) on this bus.
  Map<String, String> get environment => {'DBUS_SESSION_BUS_ADDRESS': address};

  Future<void> stop() async {
    _process.kill();
    await _process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      _process.kill(ProcessSignal.sigkill);
      return -1;
    });
    try {
      await _dir.delete(recursive: true);
    } catch (_) {}
  }
}
