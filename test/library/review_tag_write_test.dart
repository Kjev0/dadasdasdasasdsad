// Review: "verified lossless" tag writing silently rewrites the date tag.
//
// writeTagsSafely() compares a fingerprint of the tag model before and after
// the write, but the fingerprint only contains what audio_metadata_reader
// parses (FLAC: DATE as a list of *years*; MP3: TDRC/TYER parsed into an int
// `year`). The writers then emit their own representation:
//   * FLAC writer: DATE=yyyy-MM-dd  -> "2019" becomes "2019-01-01"
//     (a fabricated month/day), and a DATE the reader cannot parse
//     ("2019-05") is dropped entirely;
//   * ID3v2.4 writer: only TYER=<year> -> TDRC "2019-05-03" becomes "2019".
// Editing an unrelated field (the title) therefore changes the file's date
// tag while editTags reports a successful, lossless write.
import 'dart:io';

import 'package:fermata/core/models/track.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers.dart';

Future<void> _ffmpeg(String path, List<String> codec, Map<String, String> tags) async {
  await Directory(p.dirname(path)).create(recursive: true);
  final r = await Process.run('ffmpeg', [
    '-y', '-hide_banner', '-loglevel', 'error',
    '-f', 'lavfi', '-i', 'sine=frequency=440:duration=2',
    '-map_metadata', '-1',
    ...codec,
    for (final e in tags.entries) ...['-metadata', '${e.key}=${e.value}'],
    path,
  ]);
  if (r.exitCode != 0) throw StateError('ffmpeg failed: ${r.stderr}');
}

/// The `date` tag as ffprobe (an independent reader) sees it.
String? _probeDate(String path) {
  final r = Process.runSync('ffprobe', ['-v', 'error', '-show_entries', 'format_tags=date', '-of', 'default=nw=1:nk=1', path]);
  final out = (r.stdout as String).trim();
  return out.isEmpty ? null : out;
}

void main() {
  final skip = hasFfmpeg ? null : 'ffmpeg not installed';
  late TestLibrary lib;
  late String music;

  setUp(() async {
    lib = await openTestLibrary();
    music = p.join(lib.root.path, 'music');
    Directory(music).createSync();
    await lib.module.localLibrary.addFolder(music);
  });
  tearDown(() async => lib.dispose());

  Future<Track> scanAndGet(String path) async {
    await lib.module.localLibrary.scan().drain<void>();
    return (await lib.module.tracks.getTrackByPath(path))!;
  }

  test('FLAC: editing only the title must not rewrite DATE=2019 to 2019-01-01', () async {
    final path = p.join(music, 'year.flac');
    await _ffmpeg(path, ['-c:a', 'flac'], {'title': 'Orig', 'artist': 'A', 'date': '2019'});
    expect(_probeDate(path), '2019');
    final t = await scanAndGet(path);
    final written = await lib.module.localLibrary.editTags(t, t.copyWith(title: 'Edited'));
    expect(written, isTrue);
    // BUG: ffprobe now reports "2019-01-01".
    expect(_probeDate(path), '2019');
  }, skip: skip);

  test('FLAC: editing only the title must not drop DATE=2019-05', () async {
    final path = p.join(music, 'month.flac');
    await _ffmpeg(path, ['-c:a', 'flac'], {'title': 'Orig', 'artist': 'A', 'date': '2019-05'});
    expect(_probeDate(path), '2019-05');
    final t = await scanAndGet(path);
    final written = await lib.module.localLibrary.editTags(t, t.copyWith(title: 'Edited'));
    // Either refuse the write (override) or keep the date; dropping it is data loss.
    if (written) {
      // BUG: the DATE comment is gone.
      expect(_probeDate(path), '2019-05');
    }
  }, skip: skip);

  test('MP3 (ID3v2.4): editing only the title must keep the full recording date', () async {
    final path = p.join(music, 'v24.mp3');
    // ffmpeg's default ID3 version is 2.4: date -> TDRC.
    await _ffmpeg(path, ['-c:a', 'libmp3lame', '-b:a', '96k'], {'title': 'Orig', 'artist': 'A', 'date': '2019-05-03'});
    expect(_probeDate(path), '2019-05-03');
    final t = await scanAndGet(path);
    final written = await lib.module.localLibrary.editTags(t, t.copyWith(title: 'Edited'));
    expect(written, isTrue);
    // BUG: TDRC was replaced by TYER=2019 -> month and day lost.
    expect(_probeDate(path), '2019-05-03');
  }, skip: skip);
}
