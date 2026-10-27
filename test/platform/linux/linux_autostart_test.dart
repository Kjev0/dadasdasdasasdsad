@TestOn('linux')
library;

import 'dart:io';

import 'package:fermata/core/errors.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/platform/desktop/startup/startup_manager.dart';
import 'package:fermata/platform/linux/linux_autostart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late Directory config;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fermata-autostart-');
    config = Directory(p.join(tmp.path, 'xdg-config'));
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  LinuxAutostart autostart({String? exe, String? path, Map<String, String>? env}) => LinuxAutostart(
        environment: env ?? {'XDG_CONFIG_HOME': config.path, 'HOME': tmp.path, 'PATH': path ?? ''},
        executable: exe ?? '/opt/fermata/fermata',
      );

  test('creates and removes \$XDG_CONFIG_HOME/autostart/app.fermata.player.desktop', () async {
    final a = autostart();
    final file = File(p.join(config.path, 'autostart', 'app.fermata.player.desktop'));
    expect(a.file.path, file.path);
    expect(await a.isEnabled(), isFalse);

    await a.enable(startMinimized: true);
    expect(await file.exists(), isTrue);
    expect(await a.isEnabled(), isTrue);
    final entry = LinuxAutostart.parseDesktopEntry(await file.readAsString());
    expect(entry['Type'], 'Application');
    expect(entry['Name'], 'Fermata');
    expect(entry['Exec'], '/opt/fermata/fermata --minimized');
    expect(entry['Icon'], 'app.fermata.player');
    expect(entry['X-GNOME-Autostart-enabled'], 'true');

    await a.enable(startMinimized: false);
    expect(LinuxAutostart.parseDesktopEntry(await file.readAsString())['Exec'], '/opt/fermata/fermata');

    await a.disable();
    expect(await file.exists(), isFalse);
    expect(await a.isEnabled(), isFalse);
    await a.disable(); // idempotent
  });

  test('falls back to ~/.config when XDG_CONFIG_HOME is unset or relative', () {
    final a = autostart(env: {'HOME': tmp.path, 'XDG_CONFIG_HOME': 'relative/dir'});
    expect(a.file.path, p.join(tmp.path, '.config', 'autostart', 'app.fermata.player.desktop'));
  });

  test('an entry disabled by the desktop (Hidden=true) counts as off', () async {
    final a = autostart();
    await a.enable(startMinimized: false);
    await a.file.writeAsString('${await a.file.readAsString()}Hidden=true\n');
    expect(await a.isEnabled(), isFalse);
  });

  test('uses the launcher on PATH when it links to the installed binary', () async {
    final install = Directory(p.join(tmp.path, 'opt', 'fermata'))..createSync(recursive: true);
    final exe = File(p.join(install.path, 'fermata'))..writeAsStringSync('ELF');
    final bin = Directory(p.join(tmp.path, 'bin'))..createSync();
    Link(p.join(bin.path, 'fermata')).createSync(exe.path);

    final a = autostart(exe: exe.path, path: bin.path);
    expect(a.launcherPath(), p.join(bin.path, 'fermata'));
    await a.enable(startMinimized: true);
    expect(LinuxAutostart.parseDesktopEntry(await a.file.readAsString())['Exec'], '${p.join(bin.path, 'fermata')} --minimized');
  });

  test('uses a wrapper script that execs the bundle', () {
    final install = Directory(p.join(tmp.path, 'lib', 'fermata'))..createSync(recursive: true);
    final exe = File(p.join(install.path, 'fermata'))..writeAsStringSync('ELF');
    final bin = Directory(p.join(tmp.path, 'bin'))..createSync();
    File(p.join(bin.path, 'fermata')).writeAsStringSync('#!/bin/sh\nexec "${install.path}/fermata" "\$@"\n');
    expect(autostart(exe: exe.path, path: bin.path).launcherPath(), p.join(bin.path, 'fermata'));
  });

  test('build directories and unrelated launchers use the binary itself', () {
    final build = Directory(p.join(tmp.path, 'src', 'build', 'linux', 'x64', 'release', 'bundle'))
      ..createSync(recursive: true);
    final exe = File(p.join(build.path, 'fermata'))..writeAsStringSync('ELF');
    final bin = Directory(p.join(tmp.path, 'bin'))..createSync();
    Link(p.join(bin.path, 'fermata')).createSync(exe.path);
    expect(autostart(exe: exe.path, path: bin.path).launcherPath(), exe.path);

    final installed = File(p.join(tmp.path, 'opt', 'fermata2', 'fermata'))..createSync(recursive: true);
    File(p.join(bin.path, 'other')).writeAsStringSync('');
    expect(autostart(exe: installed.path, path: bin.path).launcherPath(), installed.path);
  });

  test('Exec arguments with spaces or specials are quoted per the Desktop Entry spec', () async {
    expect(LinuxAutostart.quoteExecArg('/opt/fermata/fermata'), '/opt/fermata/fermata');
    expect(LinuxAutostart.quoteExecArg('/home/me/My Apps/fermata'), '"/home/me/My Apps/fermata"');
    expect(LinuxAutostart.quoteExecArg(r'/x/$HOME"a`b\c'), r'"/x/\$HOME\"a\`b\\c"');
    expect(LinuxAutostart.quoteExecArg('/x/100%'), '/x/100%%');

    final a = autostart(exe: '/home/me/My Apps/fermata');
    await a.enable(startMinimized: true);
    expect(LinuxAutostart.parseDesktopEntry(await a.file.readAsString())['Exec'], '"/home/me/My Apps/fermata" --minimized');
  });

  test('StartupManagerImpl drives the Linux backend and wraps failures', () async {
    final manager = StartupManagerImpl(platform: const PlatformInfo(os: HostOs.linux), backend: autostart());
    expect(manager.isSupported, isTrue);
    await manager.setEnabled(true, startMinimized: true);
    expect(await manager.isEnabled(), isTrue);
    await manager.setEnabled(false);
    expect(await manager.isEnabled(), isFalse);

    // Unwritable config dir → typed error.
    final blocker = File(p.join(tmp.path, 'not-a-dir'))..writeAsStringSync('');
    final broken = StartupManagerImpl(
      platform: const PlatformInfo(os: HostOs.linux),
      backend: LinuxAutostart(environment: {'XDG_CONFIG_HOME': blocker.path}, executable: '/opt/fermata/fermata'),
    );
    await expectLater(broken.setEnabled(true), throwsA(isA<StorageException>()));
    expect(await broken.isEnabled(), isFalse);
  });
}
