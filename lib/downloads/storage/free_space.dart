import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final _log = Logger('downloads.storage');

/// Free disk space for a path without spawning `df`:
/// * Linux / Android (64-bit ABIs): `statvfs(3)` via `dart:ffi`,
/// * Windows: `GetDiskFreeSpaceExW` (kernel32),
/// * anything else or any failure: null ("unknown").
abstract final class FreeSpace {
  static Future<int?> bytesAvailable(String path) async {
    try {
      final existing = _nearestExisting(path);
      if (existing == null) return null;
      if (Platform.isLinux || Platform.isAndroid) return _statvfs(existing);
      if (Platform.isWindows) return _windows(existing);
    } catch (e) {
      _log.fine('Free space query failed for $path', e);
    }
    return null;
  }

  static String? _nearestExisting(String path) {
    var current = p.normalize(p.absolute(path));
    while (true) {
      if (Directory(current).existsSync()) return current;
      final parent = p.dirname(current);
      if (parent == current) return null;
      current = parent;
    }
  }

  // ---- POSIX --------------------------------------------------------------

  static const _lp64 = {Abi.linuxX64, Abi.linuxArm64, Abi.linuxRiscv64, Abi.androidArm64, Abi.androidX64};

  static int? _statvfs(String path) {
    // `struct statvfs` on LP64 glibc/bionic: unsigned long f_bsize (0),
    // f_frsize (8), fsblkcnt_t f_blocks (16), f_bfree (24), f_bavail (32), ...
    // 32-bit ABIs use a different layout and are not supported.
    if (!_lp64.contains(Abi.current())) return null;
    final libc = DynamicLibrary.process();
    final statvfs =
        libc.lookupFunction<Int32 Function(Pointer<Uint8>, Pointer<Uint8>), int Function(Pointer<Uint8>, Pointer<Uint8>)>(
            'statvfs');
    final malloc = libc.lookupFunction<Pointer<Uint8> Function(IntPtr), Pointer<Uint8> Function(int)>('malloc');
    final free = libc.lookupFunction<Void Function(Pointer<Uint8>), void Function(Pointer<Uint8>)>('free');

    final encoded = utf8.encode(path);
    final cPath = malloc(encoded.length + 1);
    final buf = malloc(256); // sizeof(struct statvfs) is 112 on LP64
    if (cPath.address == 0 || buf.address == 0) {
      if (cPath.address != 0) free(cPath);
      if (buf.address != 0) free(buf);
      return null;
    }
    try {
      final pathBytes = cPath.asTypedList(encoded.length + 1);
      pathBytes.setAll(0, encoded);
      pathBytes[encoded.length] = 0;
      if (statvfs(cPath, buf) != 0) return null;
      final words = buf.cast<Uint64>();
      final bsize = words[0];
      final frsize = words[1];
      final bavail = words[4];
      return bavail * (frsize != 0 ? frsize : bsize);
    } finally {
      free(cPath);
      free(buf);
    }
  }

  // ---- Windows ------------------------------------------------------------

  static int? _windows(String path) {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final getDiskFreeSpaceEx = kernel32.lookupFunction<
        Int32 Function(Pointer<Uint16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>),
        int Function(Pointer<Uint16>, Pointer<Uint64>, Pointer<Uint64>, Pointer<Uint64>)>('GetDiskFreeSpaceExW');
    final localAlloc =
        kernel32.lookupFunction<Pointer<Uint8> Function(Uint32, IntPtr), Pointer<Uint8> Function(int, int)>('LocalAlloc');
    final localFree =
        kernel32.lookupFunction<Pointer<Uint8> Function(Pointer<Uint8>), Pointer<Uint8> Function(Pointer<Uint8>)>('LocalFree');
    const lptr = 0x0040; // LMEM_FIXED | LMEM_ZEROINIT

    final units = path.codeUnits;
    final wPath = localAlloc(lptr, (units.length + 1) * 2);
    final out = localAlloc(lptr, 3 * 8);
    if (wPath.address == 0 || out.address == 0) {
      if (wPath.address != 0) localFree(wPath);
      if (out.address != 0) localFree(out);
      return null;
    }
    try {
      final chars = wPath.cast<Uint16>().asTypedList(units.length + 1);
      chars.setAll(0, units);
      chars[units.length] = 0;
      final values = out.cast<Uint64>();
      final ok = getDiskFreeSpaceEx(wPath.cast<Uint16>(), values, values.elementAt(1), values.elementAt(2));
      if (ok == 0) return null;
      return values[0]; // bytes available to the calling user (quota aware)
    } finally {
      localFree(wPath);
      localFree(out);
    }
  }
}
