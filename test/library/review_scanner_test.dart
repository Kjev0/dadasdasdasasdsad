// Review: scanner defects found by the adversarial review.
import 'dart:async';
import 'dart:io';

import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/library/scanner/local_library_service.dart';
import 'package:fermata/library/scanner/tag_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers.dart';

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

  Future<ScanProgress> scan({String? folder, bool full = false}) =>
      lib.module.localLibrary.scan(folder: folder, full: full).last;

  Future<Track?> byPath(String path) => lib.module.tracks.getTrackByPath(path);

  // -------------------------------------------------------------------------
  // Folder art added later is never applied by incremental scans, although
  // the folder watcher treats `cover.jpg` changes as relevant and starts an
  // incremental scan for them (ScanJob only re-reads files whose size/mtime
  // changed or whose *existing* artwork file vanished).
  test('folder art added after the first scan is picked up by an incremental scan', () async {
    final path = p.join(music, 'Album', '01.mp3');
    await makeAudio(path, tags: {'title': 'One', 'artist': 'A', 'album': 'Album'});
    await scan();
    expect((await byPath(path))!.artworkUrl, isNull);

    await makePng(p.join(music, 'Album', 'cover.png'));
    await scan(); // what the watcher triggers
    // BUG: still null; only a full rescan finds the new cover.
    expect((await byPath(path))!.artworkUrl, isNotNull);
  }, skip: skip);

  // -------------------------------------------------------------------------
  // saveEmbeddedArtwork() keys the cache file by (album artist, album) and
  // returns an existing file unchanged ("first image of an album wins"). When
  // the user replaces the embedded cover of an album, the re-scanned tracks
  // keep pointing at the OLD image forever (until the cache is cleared).
  test('replacing an embedded cover updates the stored artwork', () async {
    final red = await makePng(p.join(lib.root.path, 'red.png'), color: 'red');
    final blue = await makePng(p.join(lib.root.path, 'blue.png'), color: 'blue');
    final path = p.join(music, 'Alb', '01.mp3');
    final tags = {'title': 'T', 'artist': 'Art', 'album': 'Alb'};
    await makeAudio(path, tags: tags, cover: red.path);
    await scan();
    final first = (await byPath(path))!;
    final redEmbedded = readTags(File(path)).picture!.bytes;
    expect(File(first.artworkUrl!.toFilePath()).readAsBytesSync(), redEmbedded);

    // User re-tags the album with a new cover.
    await makeAudio(path, tags: tags, cover: blue.path, seconds: 3);
    File(path).setLastModifiedSync(DateTime.now().add(const Duration(seconds: 5)));
    final res = await scan();
    expect(res.updated, 1);
    final blueEmbedded = readTags(File(path)).picture!.bytes;
    expect(blueEmbedded, isNot(redEmbedded));
    final second = (await byPath(path))!;
    // BUG: the cache file still holds the red image.
    expect(File(second.artworkUrl!.toFilePath()).readAsBytesSync(), blueEmbedded);
  }, skip: skip);

  // -------------------------------------------------------------------------
  // ScanJob only skips missing-file detection when the root directory does
  // not exist. A root that exists but yields no files (unmounted mount point,
  // Android scoped storage without READ_MEDIA_AUDIO, a listing error that is
  // only recorded in `errors`) is treated as "every file was deleted":
  // unreferenced tracks are hard-deleted together with the user's tag edits
  // (override_json) and their date_added.
  test('a library root that temporarily lists no files does not destroy tag edits', () async {
    final path = p.join(music, 'song.flac');
    await makeAudio(path, tags: {'title': 'Scanned', 'artist': 'A'});
    await scan();
    final t = (await byPath(path))!;
    await lib.module.tracks.setOverride(t.id, {'title': 'My corrected title'});

    // Simulate an unmounted drive: the mount point exists but is empty.
    final stash = Directory(p.join(lib.root.path, 'stash'))..createSync();
    File(path).renameSync(p.join(stash.path, 'song.flac'));
    final res = await scan();
    expect(res.done, isTrue);

    // Drive comes back.
    File(p.join(stash.path, 'song.flac')).renameSync(path);
    await scan();
    final back = (await byPath(path))!;
    expect(back.id, t.id);
    // BUG: the override was deleted with the row during the "empty" scan.
    expect(back.title, 'My corrected title');
  }, skip: skip);

  // -------------------------------------------------------------------------
  // removeFolder() neither cancels nor waits for a scan of that folder that
  // is already running. Later batches of the scan re-insert the folder's
  // tracks after they were removed, leaving orphan rows under no library
  // folder (e.g. the user accidentally added a huge folder and removes it
  // while it is being scanned).
  test('removeFolder during a running scan of that folder leaves no tracks behind', () async {
    for (var i = 0; i < 6; i++) {
      await makeAudio(p.join(music, 'f$i.wav'), seconds: 0.2);
    }
    final service = LocalLibraryServiceImpl(
      lib.module.database,
      lib.module.tracks,
      lib.paths,
      lib.module.changes,
      const PlatformInfo(os: HostOs.linux),
      batchSize: 1,
    );
    addTearDown(service.dispose);
    final removed = Completer<void>();
    final done = Completer<void>();
    service.scan().listen((progress) {
      if (progress.added >= 1 && !removed.isCompleted) {
        removed.complete(service.removeFolder(music));
      }
    }, onDone: done.complete);
    await removed.future;
    await done.future;
    expect(await service.folders(), isEmpty);
    // BUG: the remaining batches were saved after the folder was removed.
    expect(await lib.module.tracks.count(const TrackQuery(localFilesOnly: true)), 0);
  }, skip: skip);

  // -------------------------------------------------------------------------
  // After a move/rename the old id is migrated away. A stale Track object
  // (still in the play queue / UI) that is upserted afterwards - which the
  // history recorder and setFavorite do on every play/like - resurrects the
  // old id as a non-scanned row with a dead path: a phantom local track that
  // even counts as "available offline", with the new play attached to it.
  test('a stale Track for a moved file does not resurrect a phantom library track', () async {
    final from = p.join(music, 'a.ogg');
    await makeAudio(from, tags: {'title': 'Song', 'artist': 'A'});
    await scan();
    final stale = (await byPath(from))!; // e.g. currently playing
    File(from).renameSync(p.join(music, 'renamed.ogg'));
    await scan(); // migrated to the new id
    expect(await lib.module.tracks.getTrack(stale.id), isNull);

    // Playback of the queued (stale) item ends -> recorder upserts + records.
    await lib.module.tracks.upsertTracks([stale]);
    await lib.module.history.recordPlay(PlayRecord(track: stale, playedAt: DateTime.now(), listened: const Duration(minutes: 1), completed: true));

    // BUG: two local tracks, one of them pointing at a file that no longer exists.
    expect(await lib.module.tracks.count(const TrackQuery(localFilesOnly: true)), 1);
    expect(await lib.module.tracks.count(const TrackQuery(offlineAvailableOnly: true)), 1);
  }, skip: skip);

  // -------------------------------------------------------------------------
  // Move detection only works inside ONE ScanJob. The desktop watcher
  // (_onWatchedChange) starts one scan per changed root, so a file moved
  // from one library folder to another is "missing" in the first scan and
  // "new" in the second: playlists/favorites/history stay on a dead
  // fileMissing track and the moved file starts with no references.
  test('desktop watcher: moving a file between two library folders keeps its references', () async {
    final other = p.join(lib.root.path, 'other');
    Directory(other).createSync();
    await lib.module.localLibrary.addFolder(other);
    final from = p.join(music, 'moved.ogg');
    final to = p.join(other, 'moved.ogg');
    await makeAudio(from, tags: {'title': 'Mover', 'artist': 'A'});
    await scan();
    final old = (await byPath(from))!;
    final playlist = await lib.module.playlists.createPlaylist('P');
    await lib.module.playlists.addTracks(playlist.id, [old.id]);
    await lib.module.favorites.setFavorite(old, true);

    final service = lib.module.localLibrary;
    await service.startWatching();
    await service.watchersReady;
    File(from).renameSync(to);

    // Wait for the debounced per-root scans to settle.
    Track? moved;
    for (var i = 0; i < 150; i++) {
      moved = await byPath(to);
      final oldRow = await lib.module.tracks.getTrack(old.id);
      final settled = moved != null && (oldRow == null || oldRow.availability.reason == AvailabilityReason.fileMissing);
      if (settled) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await service.stopWatching();
    moved = await byPath(to);
    expect(moved, isNotNull);
    // BUG: the playlist still points at the old, now "file missing" track.
    expect(await lib.module.playlists.playlistTrackIds(playlist.id), [moved!.id]);
    expect(await lib.module.favorites.isFavorite(moved.id), isTrue);
  }, skip: skip, timeout: const Timeout(Duration(seconds: 60)));
}
