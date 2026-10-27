import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../core/platform/app_paths.dart';

final _log = Logger('desktop.instance');

/// Commands exchanged between instances.
abstract final class InstanceCommands {
  static const show = 'show';
  static const playPause = 'play-pause';
  static const next = 'next';
  static const previous = 'previous';

  /// `open <absolute path>` — play a local file ("Open with Fermata").
  static const openPrefix = 'open ';

  static const _flags = {'--play-pause': playPause, '--next': next, '--previous': previous};

  /// Translates command-line arguments into commands for the running
  /// instance: media flags, then `open <file>` for existing file paths;
  /// `show` when there is nothing else (and after opening files).
  static List<String> fromArgs(List<String> args) {
    final commands = <String>[];
    var opened = false;
    for (final arg in args) {
      final flag = _flags[arg];
      if (flag != null) {
        commands.add(flag);
        continue;
      }
      if (arg.startsWith('-')) continue;
      final path = arg.startsWith('file://') ? _filePath(arg) : arg;
      if (path != null && FileSystemEntity.isFileSync(path)) {
        commands.add('$openPrefix${p.absolute(path)}');
        opened = true;
      }
    }
    if (commands.isEmpty || opened) commands.add(show);
    return commands;
  }

  static String? _filePath(String uri) {
    try {
      return Uri.parse(uri).toFilePath();
    } catch (_) {
      return null;
    }
  }
}

/// Result of [SingleInstance.acquire].
sealed class InstanceAcquisition {
  const InstanceAcquisition();
}

/// This process is the primary instance.
class PrimaryInstance extends InstanceAcquisition {
  const PrimaryInstance(this.instance);
  final SingleInstance instance;
}

/// Another instance is running and accepted [commands]; this process should
/// exit.
class ForwardedToRunningInstance extends InstanceAcquisition {
  const ForwardedToRunningInstance(this.commands);
  final List<String> commands;
}

/// Keeps Fermata single-instance: the primary instance listens on an
/// ephemeral loopback TCP port written to `AppPaths.instanceLockFile`; later
/// launches connect, forward their command (`show`, `play-pause`, `next`,
/// `previous`, `open <path>`) and exit.
///
/// Protocol (one line each way, UTF-8): client sends
/// `FERMATA/1 <cmd>[\t<cmd>...]\n`, server answers `OK\n`. A lock file whose
/// port does not answer with `OK` (crashed instance, port reused by another
/// program) is treated as stale and replaced.
class SingleInstance {
  SingleInstance._(this._server, this._lockFile, this.launchCommands) {
    _server.listen(_onClient, onError: (Object e) => _log.warning('Instance server error: $e'));
  }

  static const _magic = 'FERMATA/1';

  final ServerSocket _server;
  final File _lockFile;
  final _commands = StreamController<String>.broadcast();

  /// Commands derived from this process's own arguments, other than `show`
  /// (e.g. `--play-pause` on the very first launch). The lifecycle
  /// controller runs them after start-up.
  final List<String> launchCommands;

  /// Commands sent by later launches, in arrival order.
  Stream<String> get commands => _commands.stream;

  int get port => _server.port;

  /// Call before `runApp`. Returns the primary instance, or forwards [args]
  /// to the running instance and exits the process with code 0.
  static Future<SingleInstance> ensure(AppPaths paths, List<String> args) async {
    final result = await acquire(paths.instanceLockFile, args);
    switch (result) {
      case PrimaryInstance(:final instance):
        return instance;
      case ForwardedToRunningInstance(:final commands):
        _log.info('Fermata is already running; forwarded $commands');
        exit(0);
    }
  }

  /// Testable core of [ensure]: never exits the process.
  static Future<InstanceAcquisition> acquire(
    File lockFile,
    List<String> args, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final commands = InstanceCommands.fromArgs(args);
    final existingPort = await _readPort(lockFile);
    if (existingPort != null && await _forward(existingPort, commands, timeout)) {
      return ForwardedToRunningInstance(commands);
    }
    if (existingPort != null) _log.info('Replacing stale instance lock (port $existingPort)');

    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    try {
      await _writeLock(lockFile, server.port);
    } catch (e) {
      // Without a lock file later launches cannot find us; keep running.
      _log.warning('Could not write instance lock ${lockFile.path}: $e');
    }
    final launch = commands.where((c) => c != InstanceCommands.show).toList(growable: false);
    return PrimaryInstance(SingleInstance._(server, lockFile, launch));
  }

  static Future<int?> _readPort(File lockFile) async {
    try {
      if (!await lockFile.exists()) return null;
      final json = jsonDecode(await lockFile.readAsString());
      final port = json is Map ? json['port'] : null;
      return port is int && port > 0 && port < 65536 ? port : null;
    } catch (_) {
      return null; // corrupt → stale
    }
  }

  static Future<void> _writeLock(File lockFile, int port) async {
    await lockFile.parent.create(recursive: true);
    final tmp = File('${lockFile.path}.$pid.tmp');
    await tmp.writeAsString(jsonEncode({'port': port, 'pid': pid}), flush: true);
    await tmp.rename(lockFile.path);
  }

  /// True when a Fermata instance on [port] acknowledged [commands].
  static Future<bool> _forward(int port, List<String> commands, Duration timeout) async {
    Socket? socket;
    try {
      socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: timeout);
      socket.write('$_magic ${commands.join('\t')}\n');
      await socket.flush();
      final reply = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first
          .timeout(timeout, onTimeout: () => '');
      return reply == 'OK';
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  void _onClient(Socket socket) {
    // Only loopback connections can reach a loopback-bound server.
    late final StreamSubscription<String> sub;
    // Drop clients that never send a line.
    final watchdog = Timer(const Duration(seconds: 5), () {
      sub.cancel();
      socket.destroy();
    });
    sub = utf8.decoder.bind(socket).transform(const LineSplitter()).take(1).listen(
      (line) {
        watchdog.cancel();
        if (!line.startsWith('$_magic ')) {
          socket.destroy();
          return;
        }
        socket.write('OK\n');
        socket.flush().whenComplete(socket.close).ignore();
        for (final cmd in line.substring(_magic.length + 1).split('\t')) {
          if (cmd.isNotEmpty && !_commands.isClosed) _commands.add(cmd);
        }
      },
      onError: (Object _) {
        watchdog.cancel();
        socket.destroy();
      },
      onDone: watchdog.cancel,
      cancelOnError: true,
    );
  }

  /// Stops listening and removes the lock file if it is still ours.
  Future<void> close() async {
    final port = _server.port;
    await _server.close();
    await _commands.close();
    try {
      if (await _readPort(_lockFile) == port) await _lockFile.delete();
    } catch (_) {}
  }
}
