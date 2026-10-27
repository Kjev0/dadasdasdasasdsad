import 'package:fermata/app/services.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/ui/pages/import/import_page.dart';
import 'package:fermata/ui/pages/playlists/playlist_detail_page.dart';
import 'package:fermata/ui/pages/playlists/playlists_page.dart';
import 'package:fermata/ui/pages/playlists/smart_rules_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'support/page_harness.dart';

(FakeKit, RecordingPlaylistRepository, ControllableLocalLibrary, AppServices) _setup({List<Track> tracks = const []}) {
  final kit = FakeKit(tracks: tracks);
  final playlists = RecordingPlaylistRepository(kit.libraryChanges, kit.trackRepo);
  final local = ControllableLocalLibrary();
  return (kit, playlists, local, servicesWith(kit, playlists: playlists, localLibrary: local));
}

Future<void> _openMenu(WidgetTester tester, String playlistId, String item) async {
  await tester.tap(find.byKey(ValueKey('playlist-menu-$playlistId')).first);
  await settle(tester);
  await tester.tap(find.text(item).last);
  await settle(tester);
}

/// Text inside the routed page (the expanded sidebar lists playlists too).
Finder _inPage(String text) => find.descendant(of: find.byType(PlaylistsPage), matching: find.text(text));

void main() {
  testWidgets('lists local, smart and imported playlists; filters; grid ↔ list', (tester) async {
    final (kit, repo, _, services) = _setup(tracks: testTracks(2));
    repo.add(testPlaylist('p1', name: 'Morning'), trackIds: ['audius:t1', 'audius:t2']);
    repo.add(const Playlist(id: 'p2', name: 'Rules', kind: PlaylistKind.smart));
    repo.add(const Playlist(id: 'p3', name: 'From Spotify', kind: PlaylistKind.local, sourceId: SourceIds.spotify, sourcePlaylistId: 'x'));
    await pumpPage(tester, kit: kit, services: services, route: '/playlists');
    expect(_inPage('Morning'), findsOneWidget);
    expect(find.text('Playlist · 2 tracks'), findsOneWidget);
    expect(find.text('Smart playlist · 0 tracks'), findsOneWidget);
    expect(find.text('Imported from Spotify · 0 tracks'), findsOneWidget);
    await tester.tap(find.text('Smart'));
    await settle(tester);
    expect(_inPage('Morning'), findsNothing);
    expect(_inPage('Rules'), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.tap(find.byKey(const ValueKey('playlists-view-toggle')));
    await settle(tester);
    expect(find.byKey(const ValueKey('playlist-row-p1')), findsOneWidget);
  });

  testWidgets('create a playlist with a description', (tester) async {
    final (kit, repo, _, services) = _setup();
    await pumpPage(tester, kit: kit, services: services, route: '/playlists');
    expect(_inPage('No playlists yet'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'New playlist').first);
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('playlist-name')), 'Road trip');
    await tester.enterText(find.byKey(const ValueKey('playlist-description')), 'Long drives');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await settle(tester);
    final created = (await repo.playlists()).single;
    expect((created.name, created.description), ('Road trip', 'Long drives'));
    expect(_inPage('Road trip'), findsOneWidget);
  });

  testWidgets('edit details, auto-download (explained) and delete (confirmed)', (tester) async {
    final (kit, repo, _, services) = _setup();
    repo.add(testPlaylist('p1', name: 'Morning'));
    await pumpPage(tester, kit: kit, services: services, route: '/playlists');

    await _openMenu(tester, 'p1', 'Edit details');
    await tester.enterText(find.byKey(const ValueKey('playlist-name')), 'Mornings');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(repo.updated.last.name, 'Mornings');

    await _openMenu(tester, 'p1', 'Download automatically');
    expect(find.textContaining('None of the streaming services allow that today'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Turn on'));
    await settle(tester);
    expect(repo.updated.last.autoDownload, isTrue);
    expect(kit.downloads.calls, contains('syncAutoDownloads'));

    await _openMenu(tester, 'p1', 'Delete');
    expect(find.text('Delete "Mornings"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect(await repo.playlists(), isEmpty);
  });

  testWidgets('artwork: pick an image, copy it, update the playlist', (tester) async {
    final (kit, repo, _, services) = _setup();
    repo.add(testPlaylist('p1', name: 'Morning'));
    final picker = FakePageFilePicker()..image = '/pictures/cover.jpg';
    final artwork = FakeArtworkStore();
    await pumpPage(tester, kit: kit, services: services, route: '/playlists', picker: picker, artwork: artwork);
    await _openMenu(tester, 'p1', 'Change artwork');
    expect(artwork.stored.single, ('p1', '/pictures/cover.jpg'));
    expect(repo.updated.last.artworkUrl.toString(), 'file:///support/playlist_artwork/p1.jpg');
    expect(find.text('Artwork updated'), findsOneWidget);
  });

  testWidgets('M3U import creates a playlist; export writes through the library', (tester) async {
    final (kit, repo, local, services) = _setup();
    local.m3uTracks = [testTrack('m1', sourceId: SourceIds.local), testTrack('m2', sourceId: SourceIds.local)];
    final picker = FakePageFilePicker()..playlistFile = '/music/Party.m3u8';
    await pumpPage(tester, kit: kit, services: services, route: '/playlists', picker: picker);
    await tester.tap(find.byKey(const ValueKey('playlists-import-menu')));
    await settle(tester);
    await tester.tap(find.text('Import M3U file'));
    await settle(tester);
    final p = (await repo.playlists()).single;
    expect(p.name, 'Party');
    expect(repo.entries[p.id], ['local:m1', 'local:m2']);
    expect(find.text('Imported 2 tracks into Party'), findsOneWidget);

    await _openMenu(tester, p.id, 'Export as M3U');
    expect(picker.calls, contains('exportFile:Party.m3u8'));
    expect(local.exported.single, (p.id, '/exports/out.m3u8'));
  });

  testWidgets('remove duplicates reports the count', (tester) async {
    final (kit, repo, _, services) = _setup(tracks: testTracks(2));
    repo.add(testPlaylist('p1', name: 'Dupes'), trackIds: ['audius:t1', 'audius:t1', 'audius:t2', 'audius:t2']);
    await pumpPage(tester, kit: kit, services: services, route: '/playlists');
    await _openMenu(tester, 'p1', 'Remove duplicates');
    expect(find.text('Removed 2 duplicates'), findsOneWidget);
    expect(repo.entries['p1'], ['audius:t1', 'audius:t2']);
  });

  testWidgets('import from a service opens the import page', (tester) async {
    final (kit, _, _, services) = _setup();
    await pumpPage(tester, kit: kit, services: services, route: '/playlists');
    await tester.tap(find.byKey(const ValueKey('playlists-import-menu')));
    await settle(tester);
    await tester.tap(find.text('Import from a service').last);
    await settle(tester);
    expect(find.byType(ImportPage), findsOneWidget);
  });

  testWidgets('tapping a card opens the playlist; quick-play plays it', (tester) async {
    final (kit, repo, _, services) = _setup(tracks: testTracks(2));
    repo.add(testPlaylist('p1', name: 'Morning'), trackIds: ['audius:t1', 'audius:t2']);
    await pumpPage(tester, kit: kit, services: services, route: '/playlists');
    await tester.tap(find.byTooltip('Play').first);
    await settle(tester);
    expect(kit.playback.argsOf('playTracks')[2], 'playlist:p1');
    await tester.tap(_inPage('Morning'));
    await settle(tester);
    expect(tester.widget<PlaylistDetailPage>(find.byType(PlaylistDetailPage)).playlistId, 'p1');
  });

  group('smart playlist editor', () {
    testWidgets('rules, match mode, limit, sort and a live preview count', (tester) async {
      final tracks = [
        testTrack('j1', title: 'One', artist: 'Miles').copyWith(genre: 'Jazz', year: 1959),
        testTrack('j2', title: 'Two', artist: 'Coltrane').copyWith(genre: 'Jazz', year: 1965),
        testTrack('r1', title: 'Three', artist: 'Queen').copyWith(genre: 'Rock', year: 1975),
      ];
      final (kit, repo, _, services) = _setup(tracks: tracks);
      await pumpPage(tester, kit: kit, services: services, route: '/playlists');
      await tester.tap(find.widgetWithText(FilledButton, 'Smart playlist'));
      await settle(tester);
      expect(find.text('New smart playlist'), findsOneWidget);
      // Default first rule: artist contains …
      await tester.enterText(find.byKey(const ValueKey('smart-name')), 'Jazz classics');
      await tester.tap(find.byKey(const ValueKey('rule-0-field')));
      await settle(tester);
      await tester.tap(find.text('Genre').last);
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('rule-0-value')), 'jazz');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(find.text('2 tracks match'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('smart-add-rule')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('rule-1-field')));
      await settle(tester);
      await tester.tap(find.text('Year').last);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('rule-1-op')));
      await settle(tester);
      await tester.tap(find.text('is more than').last);
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('rule-1-value')), '1960');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(find.text('1 track matches'), findsOneWidget);

      await tester.tap(find.text('any rule'));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      // Jazz OR after 1960: both jazz tracks and the 1975 rock track.
      expect(find.text('3 tracks match'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('smart-limit')), '1');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(find.text('1 track matches'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('smart-save')));
      await settle(tester);
      final rules = repo.lastRules!;
      expect(rules.matchAll, isFalse);
      expect(rules.limit, 1);
      expect(rules.rules.map((r) => (r.field, r.op, r.value)), [
        (SmartField.genre, SmartOperator.contains, 'jazz'),
        (SmartField.year, SmartOperator.greaterThan, 1960),
      ]);
      expect((await repo.playlists()).single.name, 'Jazz classics');
    });

    testWidgets('save stays disabled until rules are complete', (tester) async {
      final (kit, _, _, services) = _setup();
      await pumpPage(tester, kit: kit, services: services, route: '/playlists');
      await tester.tap(find.widgetWithText(FilledButton, 'Smart playlist'));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('smart-name')), 'X');
      await settle(tester);
      final save = tester.widget<FilledButton>(find.descendant(of: find.byKey(const ValueKey('smart-save')), matching: find.byType(FilledButton)));
      expect(save.onPressed, isNull);
    });
  });

  group('rule evaluation (preview)', () {
    final ctx = SmartPreviewContext(
      tracks: [
        testTrack('a', title: 'Alpha', artist: 'X').copyWith(duration: const Duration(minutes: 2)),
        testTrack('b', title: 'Beta', artist: 'Y').copyWith(duration: const Duration(minutes: 7)),
        testTrack('c', sourceId: SourceIds.local, title: 'Gamma', artist: 'Y'),
      ],
      favorites: {'audius:a'},
      downloaded: {'audius:b'},
      playCounts: {'audius:a': 5},
      lastPlayed: {'audius:a': DateTime(2026, 10, 20)},
      now: DateTime(2026, 10, 27),
    );

    int count(List<SmartRule> rules, {bool all = true}) =>
        evaluateSmartRules(SmartPlaylistRules(rules: rules, matchAll: all), ctx).count;

    test('text, number, duration, flags, dates and source', () {
      expect(count(const [SmartRule(field: SmartField.artist, op: SmartOperator.equals, value: 'y')]), 2);
      expect(count(const [SmartRule(field: SmartField.title, op: SmartOperator.notContains, value: 'a')]), 0);
      expect(count(const [SmartRule(field: SmartField.duration, op: SmartOperator.greaterThan, value: 300)]), 1);
      expect(count(const [SmartRule(field: SmartField.favorite, op: SmartOperator.isTrue)]), 1);
      expect(count(const [SmartRule(field: SmartField.downloaded, op: SmartOperator.isFalse)]), 2);
      expect(count(const [SmartRule(field: SmartField.playCount, op: SmartOperator.greaterThan, value: 3)]), 1);
      expect(count(const [SmartRule(field: SmartField.lastPlayed, op: SmartOperator.inLastDays, value: 14)]), 1);
      expect(count(const [SmartRule(field: SmartField.lastPlayed, op: SmartOperator.notInLastDays, value: 14)]), 2);
      expect(count(const [SmartRule(field: SmartField.source, op: SmartOperator.equals, value: 'local')]), 1);
      expect(
        count(const [
          SmartRule(field: SmartField.favorite, op: SmartOperator.isTrue),
          SmartRule(field: SmartField.source, op: SmartOperator.equals, value: 'local'),
        ], all: false),
        2,
      );
    });

    test('date-added rules make the preview approximate', () {
      final p = evaluateSmartRules(
        const SmartPlaylistRules(rules: [SmartRule(field: SmartField.dateAdded, op: SmartOperator.inLastDays, value: 7)]),
        ctx,
      );
      expect(p.approximate, isTrue);
    });

    test('operators per field', () {
      expect(operatorsFor(SmartField.favorite), [SmartOperator.isTrue, SmartOperator.isFalse]);
      expect(operatorsFor(SmartField.year), contains(SmartOperator.greaterThan));
      expect(operatorsFor(SmartField.title), isNot(contains(SmartOperator.greaterThan)));
    });
  });
}
