import 'dart:async';

import 'package:fermata/app/services.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/ui/pages/album/album_page.dart';
import 'package:fermata/ui/pages/artist/artist_page.dart';
import 'package:fermata/ui/pages/library/tracks/tag_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'support/page_harness.dart';

Track _t(String sid, String title, {String sourceId = SourceIds.audius, int? year, String? album, String artist = 'Artist'}) =>
    testTrack(sid, sourceId: sourceId, title: title, album: album, artist: artist).copyWith(year: year);

Track _local(String sid, String title) => testTrack(sid, sourceId: SourceIds.local, title: title, album: 'Local Album').copyWith(
      format: const AudioFormatInfo(codec: 'flac', bitrateKbps: 912, sampleRateHz: 44100, bitsPerSample: 16, channels: 2, fileSizeBytes: 25000000),
      genre: 'Jazz',
    );

/// Kit + recording repository + controllable local library.
(FakeKit, RecordingTrackRepository, ControllableLocalLibrary, AppServices) _setup(List<Track> tracks) {
  final kit = FakeKit(tracks: tracks, sources: [FakeMusicSource(id: SourceIds.audius, displayName: 'Audius')]);
  final repo = RecordingTrackRepository(kit.libraryChanges, tracks);
  final local = ControllableLocalLibrary();
  return (kit, repo, local, servicesWith(kit, tracks: repo, localLibrary: local));
}

double _y(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

void main() {
  group('tracks: sort and filters', () {
    testWidgets('sort by title, then flip the direction', (tester) async {
      final (kit, repo, _, services) = _setup([_t('1', 'Charlie'), _t('2', 'Alpha'), _t('3', 'Bravo')]);
      await pumpPage(tester, kit: kit, services: services, route: '/library');
      expect(repo.lastQuery!.sort, TrackSortField.dateAdded);
      await tester.tap(find.byKey(const ValueKey('library-sort')));
      await settle(tester);
      await tester.tap(find.text('Title').last);
      await settle(tester);
      expect(repo.lastQuery!.sort, TrackSortField.title);
      expect(repo.lastQuery!.descending, isFalse);
      expect(_y(tester, 'Alpha'), lessThan(_y(tester, 'Bravo')));
      expect(_y(tester, 'Bravo'), lessThan(_y(tester, 'Charlie')));
      await tester.tap(find.byKey(const ValueKey('library-sort')));
      await settle(tester);
      await tester.tap(find.text('Title').last);
      await settle(tester);
      expect(repo.lastQuery!.descending, isTrue);
      expect(_y(tester, 'Charlie'), lessThan(_y(tester, 'Alpha')));
    });

    testWidgets('filter sheet: downloaded, source, year and duration filters reach the query', (tester) async {
      final (kit, repo, _, services) = _setup([
        _t('1', 'Old song', year: 1990),
        _t('2', 'New song', year: 2020),
        _local('l1', 'My file'),
      ]);
      repo.downloadedIds.add('audius:2');
      await pumpPage(tester, kit: kit, services: services, route: '/library');
      await tester.tap(find.byKey(const ValueKey('library-filters')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('f-downloaded')));
      await settle(tester);
      expect(repo.lastQuery!.downloadedOnly, isTrue);
      await tester.tap(find.byKey(const ValueKey('f-downloaded')));
      await tester.tap(find.byKey(const ValueKey('f-source-audius')));
      await settle(tester);
      expect(repo.lastQuery!.sourceIds, {SourceIds.audius});
      await tester.enterText(find.byKey(const ValueKey('f-min-year')), '2000');
      await settle(tester);
      expect(repo.lastQuery!.minYear, 2000);
      await tester.enterText(find.byKey(const ValueKey('f-max-dur')), '10');
      await settle(tester);
      expect(repo.lastQuery!.maxDuration, const Duration(minutes: 10));
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.text('New song'), findsOneWidget);
      expect(find.text('Old song'), findsNothing);
      expect(find.text('My file'), findsNothing);
      // Badge with the number of active filters.
      expect(find.descendant(of: find.byType(Badge), matching: find.text('3')), findsOneWidget);
    });

    testWidgets('"Downloaded" quick filter', (tester) async {
      final (kit, repo, _, services) = _setup([_t('1', 'Streamed'), _t('2', 'Offline copy')]);
      repo.downloadedIds.add('audius:2');
      await pumpPage(tester, kit: kit, services: services, route: '/library');
      await tester.tap(find.byKey(const ValueKey('quick-downloaded')));
      await settle(tester);
      expect(repo.lastQuery!.downloadedOnly, isTrue);
      expect(find.text('Offline copy'), findsOneWidget);
      expect(find.text('Streamed'), findsNothing);
    });

    testWidgets('/library?tab=downloaded opens with the Downloaded filter', (tester) async {
      final (kit, repo, _, services) = _setup([_t('1', 'Streamed')]);
      await pumpPage(tester, kit: kit, services: services, route: '/library?tab=downloaded');
      expect(repo.lastQuery!.downloadedOnly, isTrue);
      expect(find.text('Nothing matches these filters.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Clear filters'));
      await settle(tester);
      expect(repo.lastQuery!.downloadedOnly, isFalse);
      expect(find.text('Streamed'), findsOneWidget);
    });

    testWidgets('text filter', (tester) async {
      final (kit, repo, _, services) = _setup([_t('1', 'Blue in Green'), _t('2', 'So What')]);
      await pumpPage(tester, kit: kit, services: services, route: '/library');
      await tester.enterText(find.byType(TextField).first, 'blue');
      await settle(tester);
      expect(repo.lastQuery!.text, 'blue');
      expect(find.text('So What'), findsNothing);
    });

    testWidgets('empty library offers to add a folder or import a file', (tester) async {
      final (kit, _, _, services) = _setup(const []);
      await pumpPage(tester, kit: kit, services: services, route: '/library');
      expect(find.text('Your library is empty'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add folder'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Import a file'), findsOneWidget);
    });

    testWidgets('import a single file', (tester) async {
      final (kit, _, local, services) = _setup([_t('1', 'Existing')]);
      final picker = FakePageFilePicker()..audioFile = '/downloads/new.flac';
      await pumpPage(tester, kit: kit, services: services, route: '/library', picker: picker);
      await tester.tap(find.byTooltip('Import a file'));
      await settle(tester);
      expect(local.called('importFile'), isTrue);
      expect(find.textContaining("This file can't be added."), findsOneWidget);
      local.importResult = _local('new', 'Fresh import');
      await tester.tap(find.byTooltip('Import a file'));
      await settle(tester);
      expect(find.text('Added "Fresh import"'), findsOneWidget);
    });
  });

  group('details and tag editor', () {
    testWidgets('format details; tags written to the file', (tester) async {
      final track = _local('l1', 'Take Five');
      final (kit, _, local, services) = _setup([track]);
      await pumpPage(tester, kit: kit, services: services, route: '/library');
      await tester.tap(find.byTooltip('Details'));
      await settle(tester);
      expect(find.text('FLAC'), findsOneWidget);
      expect(find.text('912 kbps'), findsOneWidget);
      expect(find.text('44.1 kHz'), findsOneWidget);
      expect(find.text('16-bit'), findsOneWidget);
      await tester.tap(find.text('Edit tags'));
      await settle(tester);
      expect(find.textContaining('Changes are written to the file'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Take Five (Live)');
      await tester.enterText(find.widgetWithText(TextField, 'Year'), '1959');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      expect(local.edits.single.title, 'Take Five (Live)');
      expect(local.edits.single.year, 1959);
      expect(local.edits.single.id, track.id);
      expect(find.text('Tags saved to the file'), findsOneWidget);
    });

    testWidgets('where the file cannot be written the edit is a library override', (tester) async {
      final (kit, _, local, services) = _setup([_local('l1', 'Take Five')]);
      local.supportsFileTagWriting = false;
      await pumpPage(tester, kit: kit, services: services, route: '/library');
      await tester.tap(find.byTooltip('Details'));
      await settle(tester);
      await tester.tap(find.text('Edit tags'));
      await settle(tester);
      expect(find.textContaining("the file isn't changed"), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      expect(find.text("Saved in your library (the file wasn't changed)"), findsOneWidget);
    });

    test('editedTrack clears empty fields and keeps ids', () {
      final original = _local('l1', 'Song').copyWith(year: 2001, artists: const [ArtistRef('A', sourceArtistId: 'a1')]);
      final edited = editedTrack(original,
          title: ' New ', artists: 'A; B', album: '', albumArtist: '', year: '', genre: 'Rock', trackNumber: '3', discNumber: '');
      expect(edited.title, 'New');
      expect(edited.artists, const [ArtistRef('A', sourceArtistId: 'a1'), ArtistRef('B')]);
      expect(edited.album, isNull);
      expect(edited.year, isNull);
      expect(edited.genre, 'Rock');
      expect(edited.trackNumber, 3);
      expect(edited.localPath, original.localPath);
    });
  });

  group('folders', () {
    testWidgets('add, scan progress, watch toggle and remove', (tester) async {
      final (kit, _, local, services) = _setup(const []);
      local.folderList.add(const LibraryFolder(path: '/music/jazz', trackCount: 12));
      final scans = StreamController<ScanProgress>();
      addTearDown(scans.close);
      local.scanController = scans;
      final picker = FakePageFilePicker()..directory = '/music/rock';
      await pumpPage(tester, kit: kit, services: services, route: '/library?tab=folders', picker: picker);
      expect(find.text('jazz'), findsOneWidget);
      expect(find.text('12 tracks · Not scanned yet'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Add folder'));
      await settle(tester);
      expect(local.addCalls.last, ('/music/rock', true));
      expect(local.called('scan'), isTrue);
      scans.add(const ScanProgress(scannedFiles: 3, totalFiles: 10, added: 2, updated: 1, removed: 0, currentPath: '/music/rock/a.flac'));
      await settle(tester);
      expect(find.text('Scanning 3 of 10 files'), findsOneWidget);
      expect(find.text('2 added · 1 updated · 0 removed'), findsOneWidget);
      scans.add(const ScanProgress(scannedFiles: 10, totalFiles: 10, added: 9, updated: 1, removed: 0, done: true));
      await settle(tester);
      expect(find.text('Scan complete'), findsOneWidget);

      // Watch toggle (desktop) re-adds the folder with the new flag.
      await tester.tap(find.byType(Switch).first);
      await settle(tester);
      expect(local.addCalls.last, ('/music/jazz', false));

      await tester.tap(find.byTooltip('Remove folder').first);
      await settle(tester);
      expect(find.text('Remove this folder?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await settle(tester);
      expect(local.removeCalls, ['/music/jazz']);
    });

    testWidgets('missing files tool removes tracks from the library', (tester) async {
      final (kit, repo, _, services) = _setup(const []);
      repo.missing = [_local('gone', 'Vanished')];
      await pumpPage(tester, kit: kit, services: services, route: '/library?tab=folders');
      await tester.tap(find.widgetWithText(FilledButton, 'Missing files'));
      await settle(tester);
      expect(find.text('Vanished'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove from library'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await settle(tester);
      expect(repo.called('removeTracks'), isTrue);
    });

    testWidgets('duplicates tool groups by reason', (tester) async {
      final (kit, repo, _, services) = _setup(const []);
      repo.duplicates = [
        DuplicateGroup(tracks: [_local('d1', 'Twice'), _t('d2', 'Twice')], reason: 'same_isrc'),
      ];
      await pumpPage(tester, kit: kit, services: services, route: '/library?tab=folders');
      await tester.tap(find.widgetWithText(FilledButton, 'Duplicates'));
      await settle(tester);
      expect(find.text('Same recording (ISRC)'), findsOneWidget);
      expect(find.text('Twice'), findsNWidgets(2));
    });

    testWidgets('no folders', (tester) async {
      final (kit, _, _, services) = _setup(const []);
      await pumpPage(tester, kit: kit, services: services, route: '/library?tab=folders');
      expect(find.text('No music folders yet'), findsOneWidget);
    });
  });

  group('albums and artists', () {
    testWidgets('albums grid opens the album', (tester) async {
      final (kit, _, _, services) = _setup([_t('1', 'One', album: 'Kind of Blue', artist: 'Miles Davis'), _t('2', 'Two', album: 'Kind of Blue', artist: 'Miles Davis')]);
      await pumpPage(tester, kit: kit, services: services, route: '/library?tab=albums');
      expect(find.text('Kind of Blue'), findsOneWidget);
      await tester.tap(find.text('Kind of Blue'));
      await settle(tester);
      final page = tester.widget<AlbumPage>(find.byType(AlbumPage));
      expect((page.sourceId, page.albumId), (SourceIds.local, 'Kind of Blue'));
    });

    testWidgets('artists grid opens the artist', (tester) async {
      final (kit, _, _, services) = _setup([_t('1', 'One', artist: 'Nina Simone')]);
      await pumpPage(tester, kit: kit, services: services, route: '/library');
      await tester.tap(find.text('Artists'));
      await settle(tester);
      await tester.tap(find.text('Nina Simone'));
      await settle(tester);
      final page = tester.widget<ArtistPage>(find.byType(ArtistPage));
      expect((page.sourceId, page.artistId), (SourceIds.local, 'Nina Simone'));
    });
  });
}
