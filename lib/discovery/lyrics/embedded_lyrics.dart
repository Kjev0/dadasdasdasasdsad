import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

/// Reads lyrics stored in an audio file's tags; null when none.
typedef EmbeddedLyricsReader = Future<String?> Function(String path);

/// Lyrics from tags via `audio_metadata_reader` (ID3 `USLT`, Vorbis/FLAC
/// `LYRICS`, MP4 `©lyr`, APE `LYRICS`). `SYLT` (binary synced ID3 frames)
/// is not exposed by the package; LRC text inside `USLT`/`LYRICS` is
/// detected and parsed as synced lyrics by the service. Runs in a
/// background isolate (tag parsing is synchronous file I/O).
Future<String?> readEmbeddedLyrics(String path) => Isolate.run(() {
      try {
        final file = File(path);
        if (!file.existsSync()) return null;
        final lyrics = readMetadata(file, getImage: false).lyrics;
        return lyrics == null || lyrics.trim().isEmpty ? null : lyrics;
      } catch (_) {
        // Unsupported or corrupt file: simply no embedded lyrics.
        return null;
      }
    });

/// A sidecar `.lrc` next to the audio file (`Song.flac` → `Song.lrc`).
Future<String?> readSidecarLrc(String audioPath) async {
  for (final ext in const ['.lrc', '.LRC']) {
    final f = File(p.setExtension(audioPath, ext));
    try {
      if (await f.exists()) {
        final text = await f.readAsString();
        if (text.trim().isNotEmpty) return text;
      }
    } on FileSystemException {
      return null;
    } on FormatException {
      // Not UTF-8; try Latin-1 which never fails.
      return String.fromCharCodes(await f.readAsBytes());
    }
  }
  return null;
}
