import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/models/track.dart';

/// One playable entry of an M3U playlist.
class M3uEntry {
  const M3uEntry({required this.path, this.title, this.duration});

  /// Absolute, normalized local path.
  final String path;

  /// `#EXTINF` display text (usually `Artist - Title`).
  final String? title;
  final Duration? duration;
}

/// Result of [parseM3u].
class M3uParseResult {
  const M3uParseResult(this.entries, this.skippedUrls);

  final List<M3uEntry> entries;

  /// Remote URLs (http, https, ...) that were ignored.
  final List<String> skippedUrls;
}

/// Decodes playlist bytes: UTF-8 (with or without BOM), else Latin-1 (old
/// `.m3u` files written by Windows players).
String decodePlaylistBytes(List<int> bytes) {
  var data = bytes;
  if (data.length >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF) data = data.sublist(3);
  try {
    return utf8.decode(data);
  } on FormatException {
    return latin1.decode(data);
  }
}

final _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]+://');
final _extinf = RegExp(r'^#EXTINF:\s*(-?\d+(?:\.\d+)?)?[^,]*,(.*)$');

/// Parses M3U/M3U8 [content]. Relative paths are resolved against
/// [baseDir]; `file://` URIs are converted; other URLs are skipped.
/// Windows-style separators are accepted on every platform.
M3uParseResult parseM3u(String content, String baseDir) {
  final entries = <M3uEntry>[];
  final skipped = <String>[];
  String? pendingTitle;
  Duration? pendingDuration;
  for (final raw in const LineSplitter().convert(content)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) {
      final m = _extinf.firstMatch(line);
      if (m != null) {
        final secs = double.tryParse(m.group(1) ?? '');
        pendingDuration = (secs == null || secs < 0) ? null : Duration(milliseconds: (secs * 1000).round());
        final t = m.group(2)!.trim();
        pendingTitle = t.isEmpty ? null : t;
      }
      continue;
    }
    String? path;
    if (line.toLowerCase().startsWith('file://')) {
      try {
        path = Uri.parse(line).toFilePath();
      } catch (_) {
        path = null;
      }
    } else if (_scheme.hasMatch(line)) {
      skipped.add(line);
    } else {
      path = _resolve(line, baseDir);
    }
    if (path != null) entries.add(M3uEntry(path: path, title: pendingTitle, duration: pendingDuration));
    pendingTitle = null;
    pendingDuration = null;
  }
  return M3uParseResult(entries, skipped);
}

String _resolve(String line, String baseDir) {
  var candidate = line;
  final isWindowsAbs = RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(candidate) || candidate.startsWith(r'\\');
  if (p.style != p.Style.windows && !isWindowsAbs) candidate = candidate.replaceAll(r'\', '/');
  if (p.isAbsolute(candidate) || isWindowsAbs) return p.normalize(candidate);
  return p.normalize(p.join(baseDir, candidate));
}

/// Builds an extended M3U8 document for [tracks] (only tracks with a local
/// file). Paths inside [exportDir] are written relative to it.
String buildM3u(List<Track> tracks, String exportDir, {bool extended = true, String? playlistName, String lineEnding = '\n'}) {
  final out = StringBuffer();
  if (extended) {
    out.write('#EXTM3U$lineEnding');
    if (playlistName != null && playlistName.isNotEmpty) out.write('#PLAYLIST:$playlistName$lineEnding');
  }
  final dir = p.normalize(p.absolute(exportDir));
  for (final t in tracks) {
    final path = t.localPath;
    if (path == null) continue;
    if (extended) {
      final secs = t.duration == null ? -1 : (t.duration!.inMilliseconds / 1000).round();
      final label = t.artists.isEmpty ? t.title : '${t.artistLine} - ${t.title}';
      out.write('#EXTINF:$secs,${label.replaceAll(RegExp(r'[\r\n]+'), ' ')}$lineEnding');
    }
    final abs = p.normalize(p.absolute(path));
    out.write(p.isWithin(dir, abs) ? p.relative(abs, from: dir) : abs);
    out.write(lineEnding);
  }
  return out.toString();
}

/// Writes [content] as UTF-8 atomically (temp file + rename).
Future<void> writeTextAtomically(String path, String content) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final tmp = File('$path.tmp');
  await tmp.writeAsString(content, encoding: utf8, flush: true);
  await tmp.rename(path);
}
