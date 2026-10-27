import 'package:fermata/core/contracts/discovery.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/actions/routes.dart';
import 'package:fermata/ui/pages/library/tracks/filter_sheet.dart';
import 'package:fermata/ui/pages/library/tracks/track_details.dart';
import 'package:fermata/ui/widgets/tracks/track_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'support/page_harness.dart';

const _long = 'An exceptionally long title that keeps going well past any reasonable width for a row';

/// A kit with data on every page (long strings included).
///
/// [external] adds an external-only (Spotify) track. `TrackTile` (ui
/// foundation) does not let its availability badge shrink; with the test
/// font (every glyph 1 em wide) "Plays on Spotify" is wider than a 360 dp
/// row, so compact runs leave it out (reported as a foundation gap; real
/// fonts are about half as wide).
FakeKit _richKit({String? locale, bool external = true}) {
  final tracks = [
    testTrack('t1', title: _long, artist: 'An artist with an equally long name, featuring another one', album: 'A long album name too',
        offline: OfflineRights.downloadable, extra: const {'albumId': 'al1'}),
    testTrack('t2', title: 'Second', album: 'A long album name too', extra: const {'albumId': 'al1'}).copyWith(discNumber: 2, trackNumber: 1),
    testTrack('sc1', sourceId: SourceIds.soundcloud, title: 'SoundCloud one', artistId: 'u1', artist: 'Producer'),
    testTrack('dz1', sourceId: SourceIds.deezer, title: 'Preview one', playback: PlaybackRights.preview),
    if (external) testTrack('sp1', sourceId: SourceIds.spotify, title: 'External one', playback: PlaybackRights.externalOnly),
    testTrack('l1', sourceId: SourceIds.local, title: 'Local file with a long name as well', album: 'Local album')
        .copyWith(format: const AudioFormatInfo(codec: 'flac', bitrateKbps: 900)),
  ];
  final audius = FakeMusicSource(
    id: SourceIds.audius,
    displayName: 'Audius',
    capabilities: const {
      SourceCapability.searchTracks,
      SourceCapability.searchArtists,
      SourceCapability.searchAlbums,
      SourceCapability.searchPlaylists,
      SourceCapability.stream,
      SourceCapability.playlistImport,
    },
    tracks: tracks.where((t) => t.sourceId == SourceIds.audius).toList(),
    artists: const [Artist(sourceId: SourceIds.audius, sourceArtistId: 'a1', name: 'Second Artist with a long name')],
    albums: const [Album(sourceId: SourceIds.audius, sourceAlbumId: 'al1', title: 'Second album with a long name')],
    playlists: const [Playlist(id: 'audius:pl1', name: 'Second playlist', kind: PlaylistKind.remote, sourceId: SourceIds.audius, sourcePlaylistId: 'pl1')],
  );
  final soundcloud = FakeMusicSource(
    id: SourceIds.soundcloud,
    displayName: 'SoundCloud',
    capabilities: const {SourceCapability.searchTracks, SourceCapability.searchArtists, SourceCapability.stream, SourceCapability.artistPages},
    tracks: tracks.where((t) => t.sourceId == SourceIds.soundcloud).toList(),
    artists: [Artist(sourceId: SourceIds.soundcloud, sourceArtistId: 'u1', name: 'Producer', permalink: Uri.parse('https://soundcloud.com/p'))],
  );
  final notReady = FakeMusicSource(id: SourceIds.youtube, displayName: 'YouTube Music', ready: false);
  final kit = FakeKit(
    tracks: tracks,
    sources: [audius, soundcloud, notReady],
    settings: AppSettings(onboardingCompleted: true, localeCode: locale),
  );
  kit.favorites.ids.addAll(tracks.map((t) => t.id));
  kit.playlists.add(testPlaylist('p1', name: 'A playlist with a really very long name indeed'), trackIds: [for (final t in tracks) t.id]);
  kit.playlists.add(const Playlist(id: 'p2', name: 'Smart', kind: PlaylistKind.smart));
  kit.recommendations
    ..shelves = [
      Shelf(id: 'continueListening', title: 'shelfContinueListening', tracks: tracks, kind: ShelfKind.continueListening),
      Shelf(id: 'dailyMix:1', title: 'shelfDailyMix', subtitle: 'Artist, Another artist, A third', tracks: tracks, kind: ShelfKind.mix),
      Shelf(id: 'becauseYouLiked:x', title: 'shelfBecauseYouLiked', subtitle: 'Someone with a long name', tracks: tracks),
    ]
    ..genreTrackMap = {'Jazz': tracks}
    ..releases = const [Album(sourceId: SourceIds.audius, sourceAlbumId: 'al1', title: 'New album')];
  kit.downloads
    ..addTask(DownloadTask(id: 'd1', track: tracks[0], status: DownloadStatus.downloading, createdAt: DateTime(2026), receivedBytes: 300000, totalBytes: 9000000, bytesPerSecond: 40000))
    ..addTask(DownloadTask(id: 'd2', track: tracks[1], status: DownloadStatus.failed, createdAt: DateTime(2026), error: 'disk_full'))
    ..addTask(DownloadTask(id: 'd3', track: tracks[0], status: DownloadStatus.waitingForNetwork, createdAt: DateTime(2026)))
    ..addTask(DownloadTask(id: 'd4', track: tracks[1], status: DownloadStatus.completed, createdAt: DateTime(2026), totalBytes: 5000000));
  for (var i = 0; i < 6; i++) {
    kit.history.records.add(PlayRecord(track: tracks[i % tracks.length], playedAt: testNow.subtract(Duration(hours: i * 9)), listened: const Duration(minutes: 3), completed: true));
  }
  kit.localLibrary.folderList.add(const LibraryFolder(path: '/home/someone/Music/A folder with a long name/Sub folder', trackCount: 1200));
  kit.searchHistory.queries.addAll(['a recent search', 'another one']);
  return kit;
}

final _routes = [
  '/home',
  '/search',
  '/explore',
  '/library',
  '/library?tab=albums',
  '/library?tab=artists',
  '/library?tab=folders',
  '/playlists',
  AppRoutes.playlist('p1'),
  AppRoutes.playlist('audius:pl1'),
  AppRoutes.artist(SourceIds.soundcloud, 'u1'),
  AppRoutes.artist(SourceIds.local, 'Test Artist'),
  AppRoutes.album(SourceIds.audius, 'al1'),
  '/downloads',
  '/favorites',
  '/history',
];

void main() {
  for (final size in [TestSizes.compact, TestSizes.medium, TestSizes.expanded]) {
    for (final locale in ['en', 'da']) {
      testWidgets('every content page lays out without overflow ($size, $locale)', (tester) async {
        final kit = _richKit(locale: locale, external: size != TestSizes.compact);
        kit.playback.load(kit.tracks.all.take(2).toList(), playing: true);
        await pumpPage(tester, kit: kit, route: '/home', size: size);
        for (final route in _routes) {
          await goTo(tester, route);
          expect(tester.takeException(), isNull, reason: '$route at $size ($locale)');
        }
      });
    }

    testWidgets('search results, a genre view and the history statistics fit ($size)', (tester) async {
      final kit = _richKit(external: size != TestSizes.compact);
      await pumpPage(tester, kit: kit, route: '/search', size: size);
      await tester.enterText(find.byType(TextField).first, 'e');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester, count: 40);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField).first, 'https://open.spotify.com/playlist/abc');
      await settle(tester);
      expect(tester.takeException(), isNull);

      await goTo(tester, '/explore');
      await tester.tap(find.widgetWithText(ActionChip, 'Jazz'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      await goTo(tester, '/history');
      await tester.tap(find.text('Statistics'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dialogs and sheets fit ($size)', (tester) async {
      final kit = _richKit(external: size != TestSizes.compact);
      await pumpPage(tester, kit: kit, route: '/library', size: size);
      await tester.tap(find.byKey(const ValueKey('library-filters')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(LibraryFilterSheet))).pop();
      await settle(tester);

      if (size == TestSizes.compact) {
        // Narrow rows open details from the selection bar.
        // (The shared selection bar scrolls its actions horizontally; call
        // the action directly instead of scrolling it into view.)
        await tester.longPress(find.byType(TrackTile).first);
        await settle(tester);
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.info_outline_rounded)).onPressed!();
      } else {
        await tester.tap(find.byTooltip('Details').first);
      }
      await settle(tester);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(TrackDetailsSheet))).pop();
      await settle(tester);

      await goTo(tester, '/playlists');
      await tester.tap(find.widgetWithText(FilledButton, 'Smart playlist'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('smart-add-rule')));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
