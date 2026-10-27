import 'dart:io';

import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/library/scanner/tag_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers.dart';

/// Real audio files generated with ffmpeg once, copied into each test.
late Directory corpus;

const danishTags = {
  'title': 'Fløjte',
  'artist': 'Søren',
  'album': 'Ålborg',
  'album_artist': 'Various',
  'genre': 'Jazz',
  'date': '1999',
  'track': '3/10',
  'disc': '1/2',
  'REPLAYGAIN_TRACK_GAIN': '-6.50 dB',
  'REPLAYGAIN_ALBUM_GAIN': '-7.00 dB',
  'ISRC': 'USRC17607839',
};

Future<void> buildCorpus(Directory root) async {
  final cover = await makePng(p.join(root.path, 'cover_src.png'));
  final m = p.join(root.path, 'music');
  await makeAudio(p.join(m, 'Album A', '01.mp3'), tags: danishTags, cover: cover.path);
  await makeAudio(p.join(m, 'Album A', '02.flac'), tags: {...danishTags, 'title': 'Second', 'track': '4/10'}, cover: cover.path);
  await makeAudio(p.join(m, 'B', 'x.m4a'), tags: {'title': 'Mp4 Song', 'artist': 'M4 Artist', 'album': 'Box', 'genre': 'Pop', 'date': '2010', 'track': '1'}, cover: cover.path);
  await makeAudio(p.join(m, 'C', 'y.ogg'), tags: {'title': 'Vorbis Song', 'artist': 'Ogg Artist', 'album': 'Ogg Album', 'track': '2'});
  await makePng(p.join(m, 'C', 'Cover.PNG'), color: 'blue');
  await makeAudio(p.join(m, 'C', 'z.opus'), tags: {'title': 'Opus Song', 'artist': 'Ogg Artist', 'album': 'Ogg Album', 'track': '3'});
  await makeAudio(p.join(m, 'D', 'w.wav'), tags: {'title': 'Wave', 'artist': 'Wav Artist', 'album': 'Riff'});
  await makeAudio(p.join(m, 'D', 'v.aiff'), tags: {'title': 'Aiff Song'});
  await makeAudio(p.join(m, 'E', 'Some Artist - Some Title.mp3'));
  await makeAudio(p.join(m, 'E', '07 - Untagged.flac'));
  await makeAudio(p.join(m, '.hidden', 'h.mp3'));
  await makeAudio(p.join(m, 'F', 'f.mp3'));
  File(p.join(m, 'F', '.nomedia')).writeAsStringSync('');
  File(p.join(m, 'notes.txt')).writeAsStringSync('not audio');
  Link(p.join(m, 'G-loop')).createSync('.'); // relative symlink loop back to the root
}

Future<void> copyDir(Directory from, Directory to) async {
  final r = await Process.run('cp', ['-a', '${from.path}/.', to.path]);
  if (r.exitCode != 0) throw StateError('copy failed: ${r.stderr}');
}

void main() {
  final skip = hasFfmpeg ? null : 'ffmpeg not installed';

  setUpAll(() async {
    if (!hasFfmpeg) return;
    corpus = await tempDir('corpus');
    await buildCorpus(corpus);
  });
  tearDownAll(() async {
    if (hasFfmpeg) await corpus.delete(recursive: true);
  });

  late TestLibrary lib;
  late String music;

  setUp(() async {
    lib = await openTestLibrary();
    if (!hasFfmpeg) return;
    final dir = Directory(p.join(lib.root.path, 'data'))..createSync();
    await copyDir(corpus, dir);
    music = p.join(dir.path, 'music');
    await lib.module.localLibrary.addFolder(music);
  });
  tearDown(() async => lib.dispose());

  Future<ScanProgress> scan({bool full = false, String? folder}) async {
    final events = await lib.module.localLibrary.scan(full: full, folder: folder).toList();
    expect(events, isNotEmpty);
    expect(events.last.done, isTrue);
    return events.last;
  }

  Future<Track> byPath(String rel) async {
    final t = await lib.module.tracks.getTrackByPath(p.join(music, rel));
    expect(t, isNotNull, reason: rel);
    return t!;
  }

  group('scan', () {
    test('reads tags of every format, skips hidden/.nomedia/links loops', () async {
      final events = await lib.module.localLibrary.scan().toList();
      expect(events.first.totalFiles, isNull); // still enumerating
      final last = events.last;
      expect(last.done, isTrue);
      expect(last.totalFiles, 9);
      expect(last.added, 9);
      expect(last.scannedFiles, 9);
      expect(last.errors, isEmpty);
      expect(await lib.module.tracks.count(const TrackQuery(localFilesOnly: true)), 9);
      expect(await lib.module.tracks.getTrackByPath(p.join(music, '.hidden', 'h.mp3')), isNull);
      expect(await lib.module.tracks.getTrackByPath(p.join(music, 'F', 'f.mp3')), isNull);

      final mp3 = await byPath('Album A/01.mp3');
      expect(mp3.id, 'local:${localTrackIdFor(p.join(music, 'Album A', '01.mp3'))}');
      expect(mp3.title, 'Fløjte');
      expect(mp3.artistLine, 'Søren');
      expect(mp3.album, 'Ålborg');
      expect(mp3.albumArtist, 'Various');
      expect(mp3.genre, 'Jazz');
      expect(mp3.year, 1999);
      expect(mp3.trackNumber, 3);
      expect(mp3.discNumber, 1);
      expect(mp3.isrc, 'USRC17607839');
      expect(mp3.replayGainTrackDb, -6.5);
      expect(mp3.replayGainAlbumDb, -7.0);
      expect(mp3.duration!.inMilliseconds, closeTo(2000, 150));
      expect(mp3.availability, const TrackAvailability.local());
      expect(mp3.format!.codec, 'mp3');
      expect(mp3.format!.bitrateKbps, greaterThan(50));
      expect(mp3.format!.fileSizeBytes, File(p.join(music, 'Album A', '01.mp3')).lengthSync());

      final flac = await byPath('Album A/02.flac');
      expect(flac.title, 'Second');
      expect(flac.albumArtist, 'Various');
      expect(flac.trackNumber, 4);
      expect(flac.replayGainTrackDb, -6.5);
      expect(flac.format!.codec, 'flac');
      expect(flac.format!.sampleRateHz, 44100);

      // Embedded artwork is stored once per album in the artwork cache.
      expect(mp3.artworkUrl!.scheme, 'file');
      expect(mp3.artworkUrl, flac.artworkUrl);
      final art = File(mp3.artworkUrl!.toFilePath());
      expect(art.existsSync(), isTrue);
      expect(p.isWithin(lib.paths.artworkCacheDir.path, art.path), isTrue);
      expect(art.readAsBytesSync().sublist(1, 4), 'PNG'.codeUnits);

      final m4a = await byPath('B/x.m4a');
      expect(m4a.title, 'Mp4 Song');
      expect(m4a.genre, 'Pop');
      expect(m4a.year, 2010);
      expect(m4a.format!.codec, 'aac');
      expect(m4a.artworkUrl, isNotNull);
      expect(m4a.artworkUrl, isNot(mp3.artworkUrl));

      final ogg = await byPath('C/y.ogg');
      expect(ogg.title, 'Vorbis Song');
      expect(ogg.trackNumber, 2);
      // No embedded art: folder art (case-insensitive name) is used directly.
      expect(ogg.artworkUrl, Uri.file(p.join(music, 'C', 'Cover.PNG')));
      final opus = await byPath('C/z.opus');
      expect(opus.title, 'Opus Song');
      expect(opus.format!.codec, 'opus');
      expect(opus.duration!.inMilliseconds, closeTo(2000, 150));

      final wav = await byPath('D/w.wav');
      expect(wav.title, 'Wave');
      expect(wav.artistLine, 'Wav Artist');
      expect(wav.format!.codec, 'pcm');
      expect((await byPath('D/v.aiff')).title, 'Aiff Song');

      // File-name fallback.
      final named = await byPath('E/Some Artist - Some Title.mp3');
      expect(named.title, 'Some Title');
      expect(named.artistLine, 'Some Artist');
      final numbered = await byPath('E/07 - Untagged.flac');
      expect(numbered.title, 'Untagged');
      expect(numbered.trackNumber, 7);
      expect(numbered.artists, isEmpty);

      final folders = await lib.module.localLibrary.folders();
      expect(folders.single.trackCount, 9);
      expect(folders.single.lastScannedAt, isNotNull);
      expect((await lib.module.tracks.albums()).map((a) => a.title), containsAll(['Ålborg', 'Box', 'Ogg Album', 'Riff']));
    }, skip: skip);

    test('incremental rescan skips unchanged files; full re-reads all', () async {
      await scan();
      final mp3Before = await byPath('Album A/01.mp3');
      final dateAdded = (await lib.module.database.db.query('tracks', columns: ['date_added'], where: 'id = ?', whereArgs: [mp3Before.id])).single;

      final again = await scan();
      expect((again.added, again.updated, again.removed), (0, 0, 0));
      expect(again.scannedFiles, 9);

      // Re-tag one file (size/mtime change) -> exactly one update.
      final target = p.join(music, 'C', 'y.ogg');
      await makeAudio(target, tags: {'title': 'Retagged', 'artist': 'Ogg Artist'}, seconds: 3);
      File(target).setLastModifiedSync(DateTime.now().add(const Duration(seconds: 5)));
      final changed = await scan();
      expect((changed.added, changed.updated, changed.removed), (0, 1, 0));
      expect((await byPath('C/y.ogg')).title, 'Retagged');

      final full = await scan(full: true);
      expect(full.updated, 9);
      final after = (await lib.module.database.db.query('tracks', columns: ['date_added'], where: 'id = ?', whereArgs: [mp3Before.id])).single;
      expect(after['date_added'], dateAdded['date_added']);
    }, skip: skip);

    test('missing files: unreferenced removed, referenced marked missing, then restored', () async {
      await scan();
      final keep = await byPath('D/w.wav');
      final drop = await byPath('D/v.aiff');
      final playlist = await lib.module.playlists.createPlaylist('P');
      await lib.module.playlists.addTracks(playlist.id, [keep.id]);
      final wavBytes = File(keep.localPath!).readAsBytesSync();
      File(keep.localPath!).deleteSync();
      File(drop.localPath!).deleteSync();

      final res = await scan();
      expect(res.removed, 2);
      expect(await lib.module.tracks.getTrack(drop.id), isNull);
      final missing = (await lib.module.tracks.getTrack(keep.id))!;
      expect(missing.availability.reason, AvailabilityReason.fileMissing);
      expect(await lib.module.playlists.playlistTrackIds(playlist.id), [keep.id]);
      expect((await lib.module.localLibrary.folders()).single.trackCount, 7);
      expect((await scan()).removed, 0); // not counted twice

      File(keep.localPath!).writeAsBytesSync(wavBytes);
      await scan();
      expect((await lib.module.tracks.getTrack(keep.id))!.availability.playback, PlaybackRights.full);
    }, skip: skip);

    test('moved/renamed files keep playlists, favorites and history', () async {
      await scan();
      final old = await byPath('B/x.m4a');
      final playlist = await lib.module.playlists.createPlaylist('P');
      await lib.module.playlists.addTracks(playlist.id, [old.id]);
      await lib.module.favorites.setFavorite(old, true);
      await lib.module.history.recordPlay(PlayRecord(track: old, playedAt: DateTime(2024), listened: const Duration(minutes: 1), completed: true));
      await lib.module.tracks.setOverride(old.id, {'title': 'My title'});

      Directory(p.join(music, 'Moved')).createSync();
      File(old.localPath!).renameSync(p.join(music, 'Moved', 'renamed.m4a'));
      final res = await scan();
      expect((res.added, res.updated, res.removed), (0, 1, 0));
      final moved = await byPath('Moved/renamed.m4a');
      expect(moved.id, isNot(old.id));
      expect(await lib.module.tracks.getTrack(old.id), isNull);
      expect(await lib.module.playlists.playlistTrackIds(playlist.id), [moved.id]);
      expect(await lib.module.favorites.isFavorite(moved.id), isTrue);
      expect(await lib.module.history.playCount(moved.id), 1);
      expect(moved.title, 'My title');
    }, skip: skip);

    test('duplicate files are detected by content hash', () async {
      File(p.join(music, 'Album A', '01.mp3')).copySync(p.join(music, 'E', 'copy of 01.mp3'));
      await scan();
      final groups = await lib.module.tracks.findDuplicates();
      final hash = groups.firstWhere((g) => g.reason == 'same_hash');
      expect(hash.tracks.map((t) => p.basename(t.localPath!)).toSet(), {'01.mp3', 'copy of 01.mp3'});
    }, skip: skip);

    test('deleted artwork cache is regenerated by an incremental scan', () async {
      await scan();
      final art = File((await byPath('Album A/01.mp3')).artworkUrl!.toFilePath());
      art.deleteSync();
      final res = await scan();
      expect(res.updated, 2); // both tracks of the album
      expect(art.existsSync(), isTrue);
    }, skip: skip);

    test('removeFolder removes its tracks; scanning one folder only', () async {
      final extra = Directory(p.join(lib.root.path, 'extra'))..createSync();
      await makeAudio(p.join(extra.path, 'e.mp3'), tags: {'title': 'Extra'});
      await lib.module.localLibrary.addFolder(extra.path, watch: false);
      final one = await scan(folder: extra.path);
      expect(one.added, 1);
      expect(await lib.module.tracks.count(const TrackQuery(localFilesOnly: true)), 1);
      await scan();
      expect(await lib.module.tracks.count(const TrackQuery(localFilesOnly: true)), 10);
      final folders = await lib.module.localLibrary.folders();
      expect(folders.firstWhere((f) => f.path == extra.path).watch, isFalse);
      await lib.module.localLibrary.removeFolder(music);
      expect(await lib.module.tracks.count(const TrackQuery(localFilesOnly: true)), 1);
      expect((await lib.module.localLibrary.folders()).map((f) => f.path), [extra.path]);
      await lib.module.localLibrary.removeFolder(extra.path, removeTracks: false);
      expect(await lib.module.tracks.count(const TrackQuery(localFilesOnly: true)), 1);
      expect(File(p.join(extra.path, 'e.mp3')).existsSync(), isTrue); // files are never deleted
    }, skip: skip);

    test('stale Track objects (queue, UI) do not overwrite scanned tags', () async {
      await scan();
      final t = await byPath('C/y.ogg');
      final stale = t.copyWith(title: 'Stale title from an old queue');
      await lib.module.tracks.upsertTracks([stale]);
      await lib.module.favorites.setFavorite(stale, true);
      expect((await lib.module.tracks.getTrack(t.id))!.title, 'Vorbis Song');
      expect(await lib.module.favorites.isFavorite(t.id), isTrue);
    }, skip: skip);

    test('importFile adds a single file outside library folders', () async {
      final outside = await makeAudio(p.join(lib.root.path, 'loose', 'Loose Artist - Loose.ogg'));
      final t = await lib.module.localLibrary.importFile(outside.path);
      expect(t, isNotNull);
      expect(t!.title, 'Loose');
      expect(t.artistLine, 'Loose Artist');
      expect(await lib.module.localLibrary.importFile(p.join(lib.root.path, 'nope.mp3')), isNull);
      final txt = File(p.join(lib.root.path, 'a.txt'))..writeAsStringSync('x');
      expect(await lib.module.localLibrary.importFile(txt.path), isNull);
      await scan(); // scanning folders does not remove the imported file
      expect(await lib.module.tracks.getTrack(t.id), isNotNull);
    }, skip: skip);
  });
}
