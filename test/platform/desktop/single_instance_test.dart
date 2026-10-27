import 'dart:convert';
import 'dart:io';

import 'package:fermata/core/platform/app_paths.dart';
import 'package:fermata/platform/desktop/single_instance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late File lock;
  final opened = <SingleInstance>[];

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fermata-instance-');
    lock = AppPaths.forTesting(tmp).instanceLockFile;
  });

  tearDown(() async {
    for (final i in opened) {
      await i.close();
    }
    opened.clear();
    await tmp.delete(recursive: true);
  });

  Future<SingleInstance> primary([List<String> args = const []]) async {
    final r = await SingleInstance.acquire(lock, args);
    expect(r, isA<PrimaryInstance>());
    final instance = (r as PrimaryInstance).instance;
    opened.add(instance);
    return instance;
  }

  test('first launch becomes primary and writes its port to the lock file', () async {
    final first = await primary();
    final json = jsonDecode(await lock.readAsString()) as Map;
    expect(json['port'], first.port);
    expect(json['pid'], pid);
    expect(json['token'], matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(first.launchCommands, isEmpty);
    final mode = (await lock.stat()).mode & 0x1ff;
    expect(mode & 0x3f, 0, reason: 'lock file (with token) is owner-only');
  });

  test('second launch forwards "show" and is told to exit', () async {
    final first = await primary();
    final received = <String>[];
    first.commands.listen(received.add);

    final second = await SingleInstance.acquire(lock, const []);
    expect(second, isA<ForwardedToRunningInstance>());
    expect((second as ForwardedToRunningInstance).commands, ['show']);
    await _until(() => received.isNotEmpty);
    expect(received, ['show']);
  });

  test('CLI flags become commands for the running instance', () async {
    final first = await primary();
    final received = <String>[];
    first.commands.listen(received.add);

    await SingleInstance.acquire(lock, const ['--play-pause']);
    await SingleInstance.acquire(lock, const ['--next']);
    await SingleInstance.acquire(lock, const ['--previous', '--minimized']);
    await _until(() => received.length == 3);
    expect(received, ['play-pause', 'next', 'previous']);
  });

  test('file arguments are forwarded as open commands followed by show', () async {
    final song = File(p.join(tmp.path, 'My Song.flac'))..writeAsStringSync('x');
    final first = await primary();
    final received = <String>[];
    first.commands.listen(received.add);

    await SingleInstance.acquire(lock, [song.path, Uri.file(song.path).toString(), '/does/not/exist.mp3']);
    await _until(() => received.length == 3);
    expect(received, ['open ${song.path}', 'open ${song.path}', 'show']);
  });

  test('a stale lock (dead port) does not block startup', () async {
    final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = dead.port;
    await dead.close();
    await lock.parent.create(recursive: true);
    await lock.writeAsString(jsonEncode({'port': deadPort, 'pid': 999999}));

    final sw = Stopwatch()..start();
    final first = await primary();
    expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    expect(first.port, isNot(deadPort));
    expect((jsonDecode(await lock.readAsString()) as Map)['port'], first.port);
  });

  test('a lock pointing at an unrelated program is treated as stale', () async {
    // Something else now listens on the old port and never answers OK.
    final impostor = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    impostor.listen((s) => s.write('HTTP/1.1 400 Bad Request\r\n\r\n'));
    addTearDown(impostor.close);
    await lock.parent.create(recursive: true);
    await lock.writeAsString(jsonEncode({'port': impostor.port}));

    final r = await SingleInstance.acquire(lock, const [], timeout: const Duration(milliseconds: 500));
    expect(r, isA<PrimaryInstance>());
    opened.add((r as PrimaryInstance).instance);
  });

  test('corrupt lock files are ignored', () async {
    await lock.parent.create(recursive: true);
    await lock.writeAsString('{not json');
    await primary();
    await lock.writeAsString('{"port": "abc"}');
    await primary();
  });

  test('a re-launch with only --minimized forwards nothing', () async {
    final first = await primary();
    final received = <String>[];
    first.commands.listen(received.add);
    final r = await SingleInstance.acquire(lock, const ['--minimized']);
    expect(r, isA<ForwardedToRunningInstance>());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received, isEmpty);
  });

  test('commands without the lock-file token are rejected', () async {
    final first = await primary();
    final received = <String>[];
    first.commands.listen(received.add);
    final s = await Socket.connect(InternetAddress.loopbackIPv4, first.port);
    s.write('FERMATA/1 0000 show\n');
    await s.flush();
    final reply = await s.fold<List<int>>([], (a, b) => a..addAll(b)).timeout(const Duration(seconds: 2));
    expect(reply, isEmpty);
    s.destroy();
    expect(received, isEmpty);
  });

  test('the primary ignores clients that do not speak the protocol', () async {
    final first = await primary();
    final received = <String>[];
    first.commands.listen(received.add);
    final s = await Socket.connect(InternetAddress.loopbackIPv4, first.port);
    s.write('GET / HTTP/1.1\r\n\r\n');
    await s.flush();
    final reply = await s.fold<List<int>>([], (a, b) => a..addAll(b)).timeout(const Duration(seconds: 2));
    expect(reply, isEmpty);
    s.destroy();
    expect(received, isEmpty);
  });

  test('launch flags of the primary itself are kept as launchCommands', () async {
    final first = await primary(const ['--play-pause', '--minimized']);
    expect(first.launchCommands, ['play-pause']);
  });

  test('close removes the lock file only if it is still ours', () async {
    final first = await primary();
    opened.remove(first);
    await first.close();
    expect(await lock.exists(), isFalse);

    final second = await primary();
    await lock.writeAsString(jsonEncode({'port': 1}));
    opened.remove(second);
    await second.close();
    expect(await lock.exists(), isTrue);
  });

  test('InstanceCommands.fromArgs', () {
    expect(InstanceCommands.fromArgs(const []), ['show']);
    expect(InstanceCommands.fromArgs(const ['--minimized']), isEmpty, reason: 'autostart while running');
    expect(InstanceCommands.fromArgs(const ['--next', '--play-pause']), ['next', 'play-pause']);
    expect(InstanceCommands.fromArgs(const ['not-a-file']), ['show']);
  });
}

Future<void> _until(bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
