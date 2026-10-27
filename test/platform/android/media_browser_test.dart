import 'package:audio_service/audio_service.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/platform/android/media_browser.dart';
import 'package:fermata/platform/android/media_session_labels.dart';
import 'package:fermata/platform/android/media_session_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  final a = track('a', title: 'Alpha');
  final b = track('b', title: 'Beta');
  final c = track('c', title: 'Gamma', artists: ['Zed']);
  final restricted = Track(
    sourceId: 'spotify',
    sourceTrackId: 'x',
    title: 'Locked',
    availability: const TrackAvailability(playback: PlaybackRights.externalOnly, offline: OfflineRights.unavailable),
  );
  const mix = Playlist(id: 'spotify:37i9:dQw', name: 'Mix: Night', kind: PlaylistKind.remote, trackCount: 2);

  MediaLibraryBrowser full({MediaSessionLabels labels = MediaSessionLabels.en}) => MediaLibraryBrowser(
        tracks: FakeTracks([a, b, c]),
        playlists: FakePlaylists([mix], {mix.id: [b, c]}),
        history: FakeHistory([c, a, restricted]),
        favorites: FakeFavorites([a, b]),
        labels: labels,
      );

  group('BrowseId', () {
    test('round-trips ids containing ":" and "|"', () {
      const id = BrowseId(BrowseKind.playlist, containerId: 'spotify:37i9:dQw', trackId: 'local:/x|y:z');
      final parsed = BrowseId.tryParse(id.toString());
      expect(parsed, id);
      expect(parsed!.isTrack, isTrue);
    });

    test('rejects foreign ids', () {
      expect(BrowseId.tryParse('u-123'), isNull);
      expect(BrowseId.tryParse('soundcloud:123'), isNull);
      expect(BrowseId.tryParse('fermata:nope::'), isNull);
      expect(BrowseId.tryParse('fermata:recent:%E0%A4%A:'), isNull);
    });
  });

  group('children', () {
    test('root lists Recently played, Playlists, Favorites (localized)', () async {
      final root = await full(labels: MediaSessionLabels.da).children(AudioService.browsableRootId);
      expect(root.map((m) => m.title), ['Senest afspillet', 'Playlister', 'Favoritter']);
      expect(root.every((m) => m.playable == false), isTrue);
    });

    test('root only offers folders whose repository exists', () async {
      final browser = MediaLibraryBrowser(favorites: FakeFavorites([a]));
      final root = await browser.children(AudioService.browsableRootId);
      expect(root.map((m) => m.title), ['Favorites']);
      expect(MediaLibraryBrowser().hasContent, isFalse);
    });

    test('recently played lists playable tracks only', () async {
      final items = await full().children(const BrowseId(BrowseKind.recent).toString());
      expect(items.map((m) => m.title), ['Gamma', 'Alpha']);
      expect(items.first.playable, isTrue);
      expect(items.first.artist, 'Zed');
      expect(items.first.extras![MediaItemExtras.trackId], c.id);
    });

    test('playlists folder lists playlists with track counts; a playlist lists its tracks', () async {
      final browser = full();
      final lists = await browser.children(const BrowseId(BrowseKind.playlists).toString());
      expect(lists.single.title, 'Mix: Night');
      expect(lists.single.displaySubtitle, '2 tracks');
      expect(lists.single.playable, isFalse);
      final tracks = await browser.children(lists.single.id);
      expect(tracks.map((m) => m.title), ['Beta', 'Gamma']);
    });

    test('unknown or track ids have no children', () async {
      final browser = full();
      expect(await browser.children('whatever'), isEmpty);
      expect(await browser.children(const BrowseId(BrowseKind.favorites, trackId: 't').toString()), isEmpty);
    });

    test('repository errors yield an empty list instead of crashing the car UI', () async {
      final browser = MediaLibraryBrowser(history: _BrokenHistory());
      expect(await browser.children(const BrowseId(BrowseKind.recent).toString()), isEmpty);
    });
  });

  group('resolve', () {
    test('a track in a playlist queues the playlist from that track', () async {
      final id = const BrowseId(BrowseKind.playlist, containerId: 'spotify:37i9:dQw').withTrack(c.id);
      final req = await full().resolve(id.toString());
      expect(req!.tracks, [b, c]);
      expect(req.startIndex, 1);
      expect(req.origin, 'playlist:spotify:37i9:dQw');
      expect(req.originLabel, 'Mix: Night');
    });

    test('a folder plays from the start', () async {
      final req = await full().resolve(const BrowseId(BrowseKind.favorites).toString());
      expect(req!.tracks, [a, b]);
      expect(req.startIndex, 0);
      expect(req.origin, 'favorites');
    });

    test('a track no longer in its folder, or a bare track id, plays alone', () async {
      final browser = full();
      final gone = await browser.resolve(const BrowseId(BrowseKind.favorites).withTrack(c.id).toString());
      expect(gone!.tracks, [c]);
      final bare = await browser.resolve(a.id);
      expect(bare!.tracks, [a]);
      expect(await browser.resolve('soundcloud:missing'), isNull);
    });
  });

  group('search', () {
    test('search returns matching tracks as playable items', () async {
      final results = await full().search('zed');
      expect(results.single.title, 'Gamma');
      expect(BrowseId.tryParse(results.single.id)!.kind, BrowseKind.search);
      expect(await full().search('   '), isEmpty);
    });

    test('resolveSearch: text → library query; empty → shuffled favorites, then recent', () async {
      final browser = full();
      final q = await browser.resolveSearch('alpha');
      expect(q!.tracks, [a]);
      expect(q.origin, 'search');
      final empty = await browser.resolveSearch('');
      expect(empty!.tracks, [a, b]);
      expect(empty.shuffle, isTrue);
      final onlyHistory = await MediaLibraryBrowser(history: FakeHistory([c])).resolveSearch('');
      expect(onlyHistory!.tracks, [c]);
      expect(onlyHistory.origin, 'history');
      expect(await MediaLibraryBrowser().resolveSearch(''), isNull);
    });
  });

  test('mostRecent for media resumption', () async {
    final item = await full().mostRecent();
    expect(item!.title, 'Gamma');
    expect(await MediaLibraryBrowser().mostRecent(), isNull);
  });
}

class _BrokenHistory extends FakeHistory {
  _BrokenHistory() : super(const []);

  @override
  Future<List<Track>> recentlyPlayed({int limit = 30}) async => throw StateError('db closed');
}
