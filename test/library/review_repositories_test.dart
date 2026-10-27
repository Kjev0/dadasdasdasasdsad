// Review: repository / M3U defects found by the adversarial review.
import 'dart:io';

import 'package:fermata/core/models/track.dart';
import 'package:fermata/library/scanner/m3u.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers.dart';

void main() {
  late TestLibrary lib;

  setUp(() async => lib = await openTestLibrary());
  tearDown(() async => lib.dispose());

  // -------------------------------------------------------------------------
  // buildM3u writes paths inside the export dir relative to it. A file whose
  // relative path starts with '#' ("#1 Crush.mp3", "#9 Dream.flac") is then
  // written as a line starting with '#', which parseM3u (and every other M3U
  // reader) treats as a comment: the entry silently disappears on import.
  test('M3U round-trip keeps a file whose name starts with "#"', () {
    final dir = p.join(lib.root.path, 'music');
    final track = Track(
      sourceId: 'local',
      sourceTrackId: 'x',
      title: '#9 Dream',
      artists: const [ArtistRef('John Lennon')],
      duration: const Duration(seconds: 290),
      localPath: p.join(dir, '#9 Dream.mp3'),
      availability: const TrackAvailability.local(),
    );
    final text = buildM3u([track], dir);
    final parsed = parseM3u(text, dir);
    // BUG: parsed.entries is empty.
    expect(parsed.entries.map((e) => e.path), [track.localPath]);
  });

  // -------------------------------------------------------------------------
  // importBackup(merge: true) is documented as "existing data is kept and the
  // backup is added", and TrackLinkRepository promises a user-confirmed link
  // is never downgraded. _importLinks uses INSERT OR REPLACE, so restoring an
  // older backup silently downgrades links the user confirmed since.
  test('merge restore does not downgrade a link the user confirmed after the backup', () async {
    final a = remoteTrack('a');
    final b = remoteTrack('b', source: 'deezer');
    await lib.module.tracks.upsertTracks([a, b]);
    await lib.module.links.link(a.id, b.id, confidence: 0.6);
    final backup = await lib.module.maintenance.exportBackup();

    await lib.module.links.link(a.id, b.id, confidence: 1.0, userConfirmed: true);
    await lib.module.maintenance.importBackup(backup);

    final linked = await lib.module.links.linkedTracks(a.id);
    // BUG: confirmed=false, confidence=0.6 after the merge.
    expect(linked.single.$2.userConfirmed, isTrue);
    expect(linked.single.$2.confidence, 1.0);
  });

  // Same root cause for tag edits: _importTracks calls setOverride() with
  // the backup's override for every existing track, replacing newer edits.
  test('merge restore does not replace a newer tag edit with the backup one', () async {
    final a = remoteTrack('a', title: 'Source title');
    await lib.module.tracks.upsertTracks([a]);
    await lib.module.tracks.setOverride(a.id, {'title': 'Old edit'});
    final backup = await lib.module.maintenance.exportBackup();

    await lib.module.tracks.setOverride(a.id, {'title': 'Newer edit'});
    await lib.module.maintenance.importBackup(backup);
    // BUG: 'Old edit' wins.
    expect((await lib.module.tracks.getTrack(a.id))!.title, 'Newer edit');
  });

  // ...and for playlists: entries added after the backup are dropped,
  // because _importPlaylists deletes and re-inserts playlists by id.
  test('merge restore keeps playlist entries added after the backup', () async {
    final a = remoteTrack('a');
    final b = remoteTrack('b');
    await lib.module.tracks.upsertTracks([a, b]);
    final pl = await lib.module.playlists.createPlaylist('Mix');
    await lib.module.playlists.addTracks(pl.id, [a.id]);
    final backup = await lib.module.maintenance.exportBackup();

    await lib.module.playlists.addTracks(pl.id, [b.id]);
    await lib.module.maintenance.importBackup(backup);
    // BUG: b was removed from the playlist by a *merge* restore.
    expect(await lib.module.playlists.playlistTrackIds(pl.id), containsAll([a.id, b.id]));
  });

  // -------------------------------------------------------------------------
  // findDuplicates clusters "same_metadata" candidates by comparing each
  // duration with the previous one only (chaining), so tracks far more than
  // the documented ±2 s apart end up in one group.
  test('same_metadata duplicates respect the ±2 s duration window', () async {
    await lib.module.tracks.upsertTracks([
      remoteTrack('d1', title: 'Song', artists: ['Band'], seconds: 100),
      remoteTrack('d2', title: 'Song', artists: ['Band'], seconds: 102),
      remoteTrack('d3', title: 'Song', artists: ['Band'], seconds: 104),
      remoteTrack('d4', title: 'Song', artists: ['Band'], seconds: 106),
    ]);
    final groups = await lib.module.tracks.findDuplicates();
    for (final g in groups) {
      final secs = g.tracks.map((t) => t.duration!.inSeconds).toList()..sort();
      // BUG: one group spanning 100..106 s.
      expect(secs.last - secs.first, lessThanOrEqualTo(2), reason: 'group ${g.reason}: $secs');
    }
  });

  test('sanity: temp dir exists', () => expect(Directory(lib.root.path).existsSync(), isTrue));
}
