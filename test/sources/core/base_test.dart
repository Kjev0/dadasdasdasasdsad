import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/sources/base/base.dart';
import 'package:flutter_test/flutter_test.dart';

class _MinimalSource extends MusicSourceBase {
  @override
  String get id => 'minimal';

  @override
  String get displayName => 'Minimal';

  @override
  Set<SourceCapability> get capabilities => const {};

  @override
  String get limitationsNote => 'Nothing.';

  void emit(SourceAuthState s) => emitAuthState(s);
}

void main() {
  group('MusicSourceBase defaults', () {
    late _MinimalSource source;
    setUp(() => source = _MinimalSource());
    tearDown(() => source.dispose());

    test('auth is not required, credentials not needed, ready', () async {
      await source.init();
      expect(source.authState.status, SourceConnectionStatus.notRequired);
      expect(source.credentialStatus.configured, isTrue);
      expect(source.credentialStatus.origin, CredentialOrigin.none);
      expect(source.isReady, isTrue);
      expect(source.termsUrl, isNull);
    });

    test('every catalog and playback operation throws UnsupportedSourceOperation', () async {
      final track = const Track(sourceId: 'minimal', sourceTrackId: '1', title: 't');
      final calls = <String, Future<Object?> Function()>{
        'searchTracks': () => source.searchTracks('q'),
        'searchArtists': () => source.searchArtists('q'),
        'searchAlbums': () => source.searchAlbums('q'),
        'searchPlaylists': () => source.searchPlaylists('q'),
        'getTrack': () => source.getTrack('1'),
        'getArtist': () => source.getArtist('1'),
        'artistTopTracks': () => source.artistTopTracks('1'),
        'relatedArtists': () => source.relatedArtists('1'),
        'albumTracks': () => source.albumTracks('1'),
        'getPlaylist': () => source.getPlaylist('1'),
        'relatedTracks': () => source.relatedTracks('1'),
        'trending': () => source.trending(),
        'newReleases': () => source.newReleases(),
        'genres': () => source.genres(),
        'lookupByIsrc': () => source.lookupByIsrc('X'),
        'userPlaylists': () => source.userPlaylists(),
        'userLikedTracks': () => source.userLikedTracks(),
        'resolveStream': () => source.resolveStream(track),
        'connect': () => source.connect(),
      };
      for (final entry in calls.entries) {
        await expectLater(
          entry.value(),
          throwsA(isA<UnsupportedSourceOperation>()
              .having((e) => e.operation, 'operation', entry.key)
              .having((e) => e.sourceId, 'sourceId', 'minimal')),
          reason: entry.key,
        );
      }
    });

    test('download defaults to null, external playback to the own permalink', () async {
      final own = Track(sourceId: 'minimal', sourceTrackId: '1', title: 't', permalink: Uri.parse('https://x/1'));
      final other = Track(sourceId: 'other', sourceTrackId: '1', title: 't', permalink: Uri.parse('https://y/1'));
      expect(await source.authorizeDownload(own), isNull);
      expect(source.externalPlaybackUri(own), Uri.parse('https://x/1'));
      expect(source.externalPlaybackUri(other), isNull);
      await source.disconnect(); // no-op
    });

    test('emitAuthState updates state and broadcasts to several listeners', () async {
      final a = <SourceConnectionStatus>[];
      final b = <SourceConnectionStatus>[];
      source.authStateChanges.listen((s) => a.add(s.status));
      source.authStateChanges.listen((s) => b.add(s.status));
      source.emit(const SourceAuthState(status: SourceConnectionStatus.error, error: 'x'));
      await pumpEventQueue();
      expect(source.authState.status, SourceConnectionStatus.error);
      expect(source.isReady, isFalse);
      expect(a, [SourceConnectionStatus.error]);
      expect(b, [SourceConnectionStatus.error]);
      await source.dispose();
      source.emit(const SourceAuthState.notRequired()); // ignored after dispose
    });
  });

  group('PageCursor', () {
    test('offset round trip and null cursor', () {
      expect(PageCursor.decodeOffset(null), 0);
      expect(PageCursor.decodeOffset(PageCursor.encodeOffset(120)), 120);
      expect(PageCursor.decodeToken(PageCursor.encodeToken('https://x/next?a=1')), 'https://x/next?a=1');
      expect(PageCursor.decode(PageCursor.encode({'a': 1, 'b': 'c'})), {'a': 1, 'b': 'c'});
    });

    test('cursors are URL-safe without padding', () {
      final c = PageCursor.encodeOffset(7);
      expect(c, isNot(contains('=')));
      expect(Uri.encodeQueryComponent(c), c);
    });

    test('corrupted cursors throw instead of restarting', () {
      expect(() => PageCursor.decodeOffset('%%%'), throwsFormatException);
      expect(() => PageCursor.decodeOffset(PageCursor.encodeToken('t')), throwsFormatException);
    });

    test('offsetPage computes the next cursor', () {
      final full = PageCursor.offsetPage([1, 2, 3], offset: 0, limit: 3);
      expect(PageCursor.decodeOffset(full.nextCursor), 3);
      expect(PageCursor.offsetPage([1, 2], offset: 0, limit: 3).hasMore, isFalse);
      expect(PageCursor.offsetPage([1, 2, 3], offset: 7, limit: 3, total: 10).hasMore, isFalse);
      expect(PageCursor.offsetPage([1], offset: 0, limit: 3, hasMore: true).hasMore, isTrue);
      final dropped = PageCursor.offsetPage([1], offset: 10, limit: 3, consumed: 3, hasMore: true);
      expect(PageCursor.decodeOffset(dropped.nextCursor), 13);
      expect(PageCursor.offsetPage(<int>[], offset: 0, limit: 3, hasMore: true).hasMore, isFalse);
    });
  });

  group('ArtworkSizing', () {
    test('picks the smallest size covering the target, else the largest', () {
      final c = {150: 'https://a/150.jpg', 480: 'https://a/480.jpg', 1000: 'https://a/1000.jpg'};
      expect(ArtworkSizing.pick(c, targetPx: 100).toString(), 'https://a/150.jpg');
      expect(ArtworkSizing.pick(c, targetPx: 480).toString(), 'https://a/480.jpg');
      expect(ArtworkSizing.pick(c, targetPx: 500).toString(), 'https://a/1000.jpg');
      expect(ArtworkSizing.pick(c, targetPx: 3000).toString(), 'https://a/1000.jpg');
      expect(ArtworkSizing.pick({150: '', 480: null}), isNull);
    });

    test('size-keyed maps ignore mirrors', () {
      final m = {
        '150x150': 'https://a/150.jpg',
        '480x480': 'https://a/480.jpg',
        'mirrors': ['https://b'],
      };
      expect(ArtworkSizing.pickFromSizeKeyedMap(m).toString(), 'https://a/480.jpg');
      expect(ArtworkSizing.parseSizeKey('2000x'), 2000);
      expect(ArtworkSizing.parseSizeKey('mirrors'), isNull);
    });

    test('replaceSizeToken swaps the last occurrence', () {
      final u = Uri.parse('https://i1.sndcdn.com/artworks-abc-large.jpg');
      expect(ArtworkSizing.replaceSizeToken(u, '-large', '-t500x500').toString(),
          'https://i1.sndcdn.com/artworks-abc-t500x500.jpg');
    });
  });

  group('Availabilities', () {
    test('mappers', () {
      expect(Availabilities.stream().offline, OfflineRights.streamOnly);
      expect(Availabilities.stream(downloadable: true).offline, OfflineRights.downloadable);
      final p = Availabilities.preview(const Duration(seconds: 30));
      expect(p.playback, PlaybackRights.preview);
      expect(p.previewDuration, const Duration(seconds: 30));
      expect(p.reason, AvailabilityReason.previewOnly);
      expect(Availabilities.externalOnly().isPlayableInApp, isFalse);
      expect(Availabilities.unavailable(AvailabilityReason.deleted).reason, AvailabilityReason.deleted);
    });

    test('ensurePlayable throws with the reason', () {
      final t = Track(
          sourceId: 's', sourceTrackId: '1', title: 't', availability: Availabilities.externalOnly());
      expect(() => Availabilities.ensurePlayable(t),
          throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.externalOnly)));
      Availabilities.ensurePlayable(t.copyWith(availability: Availabilities.stream()));
    });

    test('staleness', () {
      expect(Availabilities.isStale(const TrackAvailability.unknown()), isTrue);
      expect(Availabilities.isStale(Availabilities.stream()), isFalse);
      expect(
          Availabilities.isStale(Availabilities.stream(checkedAt: DateTime.now().subtract(const Duration(hours: 1)))),
          isTrue);
    });
  });

  group('json utils', () {
    test('tolerant accessors', () {
      expect(jsonInt('42'), 42);
      expect(jsonInt(4.7), 4);
      expect(jsonString('  '), isNull);
      expect(jsonString(5), '5');
      expect(jsonBool(1), isTrue);
      expect(jsonBool('false'), isFalse);
      expect(jsonHttpUri('ftp://x'), isNull);
      expect(jsonHttpUri('https://x/y').toString(), 'https://x/y');
      expect(jsonYear('2001-03-12'), 2001);
      expect(jsonYear('2026-10-26T12:04:51.367029Z'), 2026);
      expect(jsonDate('2020-01-01 10:00:00')?.hour, 10);
      expect(asJsonMapList([1, {'a': 1}, 'x']), [
        {'a': 1}
      ]);
    });
  });
}
