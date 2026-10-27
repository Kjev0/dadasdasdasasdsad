import 'dart:convert';
import 'dart:io';

import 'package:fermata/core/contracts/library.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/library/scanner/tag_reader.dart';
import 'package:fermata/library/scanner/tag_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers.dart';

void main() {
  final skip = hasFfmpeg ? null : 'ffmpeg not installed';
  late TestLibrary lib;
  late String music;

  Future<void> scan() => lib.module.localLibrary.scan().drain<void>();

  Future<Track> byPath(String rel) async => (await lib.module.tracks.getTrackByPath(p.join(music, rel)))!;

  setUp(() async {
    lib = await openTestLibrary();
    music = p.join(lib.root.path, 'music');
    Directory(music).createSync();
    await lib.module.localLibrary.addFolder(music);
  });
  tearDown(() async => lib.dispose());

  group('editTags', () {
    test('writes FLAC/MP3 files when lossless and re-reads them', () async {
      final simple = {'title': 'Old', 'artist': 'Old Artist', 'album': 'Old Album', 'genre': 'Rock', 'date': '2001', 'track': '5'};
      await makeAudio(p.join(music, 'a.flac'), tags: simple);
      await makeAudio(p.join(music, 'b.mp3'), tags: simple);
      await scan();
      expect(lib.module.localLibrary.supportsFileTagWriting, isTrue);
      for (final name in ['a.flac', 'b.mp3']) {
        final t = await byPath(name);
        final edited = t.copyWith(title: 'Nyt Navn æøå', artists: const [ArtistRef('Ny Kunstner'), ArtistRef('Gæst')], year: 2022, genre: 'Jazz');
        final written = await lib.module.localLibrary.editTags(t, edited);
        expect(written, isTrue, reason: name);
        final fromFile = readTags(File(t.localPath!));
        expect(fromFile.title, 'Nyt Navn æøå');
        expect(fromFile.artists, ['Ny Kunstner', 'Gæst']);
        expect(fromFile.year, 2022);
        expect(fromFile.genre, 'Jazz');
        expect(fromFile.album, 'Old Album'); // untouched fields survive
        expect(fromFile.trackNumber, 5);
        final stored = (await lib.module.tracks.getTrack(t.id))!;
        expect(stored.title, 'Nyt Navn æøå');
        expect(await lib.module.tracks.overrideOf(t.id), isNull); // everything is in the file
        expect(await lib.module.tracks.count(const TrackQuery(text: 'nyt navn aeo')), greaterThanOrEqualTo(1));
      }
      // A rescan after the write changes nothing.
      final res = await lib.module.localLibrary.scan().last;
      expect((res.added, res.updated, res.removed), (0, 0, 0));
    }, skip: skip);

    test('WAV: ASCII edits are written, non-ASCII ones become overrides', () async {
      final path = p.join(music, 'w.wav');
      await makeAudio(path, tags: {'title': 'Wave', 'artist': 'Plain', 'album': 'Riff'});
      await scan();
      final t = await byPath('w.wav');
      expect(await lib.module.localLibrary.editTags(t, t.copyWith(title: 'New Wave')), isTrue);
      expect(readTags(File(path)).title, 'New Wave');
      expect(readTags(File(path)).album, 'Riff');
      final before = File(path).readAsBytesSync();
      final t2 = (await lib.module.tracks.getTrack(t.id))!;
      // The RIFF INFO writer only encodes ASCII.
      expect(await lib.module.localLibrary.editTags(t2, t2.copyWith(title: 'Bølge')), isFalse);
      expect(File(path).readAsBytesSync(), before);
      expect((await lib.module.tracks.getTrack(t.id))!.title, 'Bølge');
    }, skip: skip);

    test('falls back to a library override when writing would lose tags', () async {
      final path = p.join(music, 'rg.flac');
      await makeAudio(path, tags: {'title': 'Has RG', 'REPLAYGAIN_TRACK_GAIN': '-3.00 dB', 'DISCNUMBER': '1'});
      await scan();
      final t = await byPath('rg.flac');
      final before = File(path).readAsBytesSync();
      final written = await lib.module.localLibrary.editTags(t, t.copyWith(title: 'Edited'));
      expect(written, isFalse);
      expect(File(path).readAsBytesSync(), before); // restored byte-for-byte
      expect((await lib.module.tracks.getTrack(t.id))!.title, 'Edited');
      expect(await lib.module.tracks.overrideOf(t.id), {'title': 'Edited'});
      // The override survives a full rescan (file values stay underneath).
      await lib.module.localLibrary.scan(full: true).drain<void>();
      expect((await lib.module.tracks.getTrack(t.id))!.title, 'Edited');
      expect((await lib.module.tracks.getTrack(t.id))!.replayGainTrackDb, -3.0);
      // Editing back to the file value removes the override.
      await lib.module.localLibrary.editTags(t, t.copyWith(title: 'Has RG'));
      expect(await lib.module.tracks.overrideOf(t.id), isNull);
    }, skip: skip);

    test('read-only formats, remote tracks and Android use overrides', () async {
      await makeAudio(p.join(music, 'c.ogg'), tags: {'title': 'Ogg'});
      await makeAudio(p.join(music, 'd.m4a'), tags: {'title': 'M4a'});
      await scan();
      for (final name in ['c.ogg', 'd.m4a']) {
        final t = await byPath(name);
        final before = File(t.localPath!).readAsBytesSync();
        expect(await lib.module.localLibrary.editTags(t, t.copyWith(album: 'X')), isFalse);
        expect(File(t.localPath!).readAsBytesSync(), before);
        expect((await lib.module.tracks.getTrack(t.id))!.album, 'X');
      }
      final remote = remoteTrack('r1', title: 'Remote');
      expect(await lib.module.localLibrary.editTags(remote, remote.copyWith(title: 'Mine')), isFalse);
      expect((await lib.module.tracks.getTrack(remote.id))!.title, 'Mine');

      final android = await openTestLibrary(platform: const PlatformInfo(os: HostOs.android));
      addTearDown(android.dispose);
      expect(android.module.localLibrary.supportsFileTagWriting, isFalse);
    }, skip: skip);

    test('writeTagsSafely reports unsupported formats', () async {
      final ogg = await makeAudio(p.join(music, 'e.ogg'), tags: {'title': 'x'});
      final t = remoteTrack('x', title: 'y');
      expect(writeTagsSafely(ogg.path, t, {'title'}, lib.paths.cacheDir.path).status, TagWriteStatus.unsupported);
      expect(writableFieldsFor('.flac'), contains('albumArtist'));
      expect(writableFieldsFor('.m4a'), isEmpty);
    }, skip: skip);
  });

  group('M3U', () {
    test('export (extended, relative, UTF-8) and import round-trip', () async {
      await makeAudio(p.join(music, 'Ærø', '01 - Første.mp3'), tags: {'title': 'Første', 'artist': 'Øresund'});
      await makeAudio(p.join(music, 'two.flac'), tags: {'title': 'Two', 'artist': 'B'});
      await scan();
      final first = await byPath(p.join('Ærø', '01 - Første.mp3'));
      final second = await byPath('two.flac');
      final remote = remoteTrack('r');
      await lib.module.tracks.upsertTracks([remote]);
      final pl = await lib.module.playlists.createPlaylist('Danske');
      await lib.module.playlists.addTracks(pl.id, [first.id, remote.id, second.id]);

      final out = p.join(music, 'danske.m3u8');
      await lib.module.localLibrary.exportM3u(pl.id, out);
      final text = utf8.decode(File(out).readAsBytesSync());
      expect(text, startsWith('#EXTM3U\n#PLAYLIST:Danske\n'));
      expect(text, contains('#EXTINF:2,Øresund - Første\n'));
      expect(text, contains('\n${p.join('Ærø', '01 - Første.mp3')}\n')); // relative inside the export dir
      expect(text, contains('\ntwo.flac\n'));
      expect(text, isNot(contains('soundcloud'))); // remote tracks have no file

      final imported = await lib.module.localLibrary.importM3u(out);
      expect(imported.map((t) => t.id), [first.id, second.id]);

      // Non-extended export writes paths only; outside the dir -> absolute.
      final plain = p.join(lib.root.path, 'elsewhere', 'plain.m3u');
      await lib.module.localLibrary.exportM3u(pl.id, plain, extended: false);
      expect(File(plain).readAsLinesSync(), [first.localPath, second.localPath]);
      await expectLater(lib.module.localLibrary.exportM3u('nope', plain), throwsA(isA<StorageException>()));
    }, skip: skip);

    test('import: absolute/relative/file:// paths, URLs ignored, unknown files imported, missing skipped, Latin-1', () async {
      await makeAudio(p.join(music, 'known.mp3'), tags: {'title': 'Known'});
      await scan();
      final outside = await makeAudio(p.join(lib.root.path, 'outside', 'Café.ogg'), tags: {'title': 'Outside'});
      final m3u = File(p.join(lib.root.path, 'outside', 'list.m3u'));
      final body = [
        '#EXTM3U',
        '#EXTINF:2,Someone - Known',
        p.join(music, 'known.mp3'),
        'https://example.com/stream.mp3',
        '#EXTINF:-1,Outside',
        'Café.ogg',
        Uri.file(p.join(music, 'known.mp3')).toString(),
        'missing.mp3',
        '',
      ].join('\r\n');
      m3u.writeAsBytesSync(latin1.encode(body));
      final tracks = await lib.module.localLibrary.importM3u(m3u.path);
      expect(tracks.map((t) => t.title), ['Known', 'Outside', 'Known']);
      expect(tracks[1].localPath, outside.path);
      expect(await lib.module.tracks.getTrackByPath(outside.path), isNotNull);
      await expectLater(lib.module.localLibrary.importM3u(p.join(lib.root.path, 'none.m3u')), throwsA(isA<StorageException>()));
    }, skip: skip);
  });

  group('watching', () {
    test('desktop: file changes trigger a debounced incremental scan', () async {
      await makeAudio(p.join(music, 'first.mp3'), tags: {'title': 'First'});
      await scan();
      final service = lib.module.localLibrary;
      await service.startWatching();
      await service.watchersReady;

      final changes = lib.module.changes.changes.where((t) => t.contains(LibraryTopic.folders));
      final scanned = changes.first.timeout(const Duration(seconds: 20));
      await makeAudio(p.join(music, 'sub', 'new.ogg'), tags: {'title': 'Arrived'});
      await scanned;
      // Wait until the debounced scan has stored the track.
      Track? t;
      for (var i = 0; i < 100 && t == null; i++) {
        t = await lib.module.tracks.getTrackByPath(p.join(music, 'sub', 'new.ogg'));
        if (t == null) await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(t?.title, 'Arrived');

      File(p.join(music, 'first.mp3')).deleteSync();
      for (var i = 0; i < 100; i++) {
        if (await lib.module.tracks.getTrackByPath(p.join(music, 'first.mp3')) == null) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(await lib.module.tracks.getTrackByPath(p.join(music, 'first.mp3')), isNull);
      await service.stopWatching();
    }, skip: skip, timeout: const Timeout(Duration(seconds: 60)));

    test('Android: no watching', () async {
      final android = await openTestLibrary(platform: const PlatformInfo(os: HostOs.android));
      addTearDown(android.dispose);
      final dir = Directory(p.join(android.root.path, 'm'))..createSync();
      await android.module.localLibrary.addFolder(dir.path);
      await android.module.localLibrary.startWatching(); // no-op, must not throw
      await android.module.localLibrary.stopWatching();
    });
  });

  test('canceling a scan subscription stops it cleanly', () async {
    for (var i = 0; i < 6; i++) {
      await makeAudio(p.join(music, 'f$i.wav'), seconds: 0.2);
    }
    final service = lib.module.localLibrary;
    final sub = service.scan().listen(null);
    await sub.cancel();
    // A following scan still runs to completion.
    final last = await service.scan().last;
    expect(last.done, isTrue);
    expect(await lib.module.tracks.count(const TrackQuery(localFilesOnly: true)), 6);
  }, skip: skip);

  test('addFolder rejects missing folders', () async {
    await expectLater(lib.module.localLibrary.addFolder(p.join(lib.root.path, 'does-not-exist')), throwsA(isA<StorageException>()));
  });
}
