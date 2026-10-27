import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/ui/pages/library/shared/track_helpers.dart';
import 'package:fermata/ui/pages/search/search_controller.dart';
import 'package:fermata/ui/pages/search/share_links.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

void main() {
  group('ShareLink.parse', () {
    test('plain text is not a link', () {
      expect(ShareLink.parse('daft punk'), isNull);
      expect(ShareLink.parse('https://example.com/playlist/1'), isNull);
      expect(ShareLink.parse(''), isNull);
    });

    test('Spotify playlist / track / album / artist and spotify: URIs', () {
      final p = ShareLink.parse('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=abc')!;
      expect((p.sourceId, p.kind, p.id), (SourceIds.spotify, ShareLinkKind.playlist, '37i9dQZF1DXcBWIGoYBM5M'));
      expect(ShareLink.parse('https://open.spotify.com/intl-de/track/4uLU6hMCjMI75M1A2tKUQC')!.kind, ShareLinkKind.track);
      expect(ShareLink.parse('open.spotify.com/album/1A2GTWGtFfWp7KSQTwWOyo')!.kind, ShareLinkKind.album);
      final uri = ShareLink.parse('spotify:artist:0OdUWJ0sBjDrqHygGUXeCF')!;
      expect((uri.kind, uri.id), (ShareLinkKind.artist, '0OdUWJ0sBjDrqHygGUXeCF'));
    });

    test('Deezer with language prefix; short links stay URLs', () {
      final t = ShareLink.parse('https://www.deezer.com/en/track/3135556')!;
      expect((t.sourceId, t.kind, t.id), (SourceIds.deezer, ShareLinkKind.track, '3135556'));
      expect(ShareLink.parse('https://www.deezer.com/playlist/908622995')!.kind, ShareLinkKind.playlist);
      final short = ShareLink.parse('https://link.deezer.com/s/30xyz')!;
      expect((short.kind, short.idIsUrl), (ShareLinkKind.unknown, true));
    });

    test('SoundCloud sets, tracks and profiles keep the URL as id', () {
      final set = ShareLink.parse('https://soundcloud.com/user-1/sets/summer-mix?utm_source=x')!;
      expect((set.sourceId, set.kind), (SourceIds.soundcloud, ShareLinkKind.playlist));
      expect(set.id, 'https://soundcloud.com/user-1/sets/summer-mix');
      final track = ShareLink.parse('https://m.soundcloud.com/user-1/a-song')!;
      expect(track.kind, ShareLinkKind.track);
      expect(ShareLink.parse('https://soundcloud.com/user-1/likes')!.kind, ShareLinkKind.artist);
      expect(ShareLink.parse('https://soundcloud.com/discover'), isNull);
      expect(ShareLink.parse('https://on.soundcloud.com/AbC123')!.kind, ShareLinkKind.unknown);
    });

    test('YouTube watch / playlist / youtu.be; Audius; Jamendo', () {
      expect(ShareLink.parse('https://music.youtube.com/playlist?list=PL123')!.id, 'PL123');
      final w = ShareLink.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=10')!;
      expect((w.kind, w.id), (ShareLinkKind.track, 'dQw4w9WgXcQ'));
      expect(ShareLink.parse('https://youtu.be/dQw4w9WgXcQ')!.id, 'dQw4w9WgXcQ');
      expect(ShareLink.parse('https://audius.co/artist/playlist/chill-1')!.kind, ShareLinkKind.playlist);
      expect(ShareLink.parse('https://audius.co/artist/song-1')!.kind, ShareLinkKind.track);
      final j = ShareLink.parse('https://www.jamendo.com/track/1886257/song')!;
      expect((j.sourceId, j.kind, j.id), (SourceIds.jamendo, ShareLinkKind.track, '1886257'));
    });
  });

  group('GroupedResults', () {
    final sc = SourceSearchResults(
      sourceId: SourceIds.soundcloud,
      tracks: Page([testTrack('s1', sourceId: SourceIds.soundcloud, title: 'Alpha'), testTrack('s2', sourceId: SourceIds.soundcloud, title: 'Beta')]),
    );
    final au = SourceSearchResults(
      sourceId: SourceIds.audius,
      tracks: Page([testTrack('a1', title: 'Gamma'), testTrack('a2', title: 'Daft Punk')]),
      artists: const Page([Artist(sourceId: SourceIds.audius, sourceArtistId: 'x', name: 'Daft Punk')]),
    );

    test('groups in provider order (SoundCloud first by default)', () {
      final g = GroupedResults.from('zzz', {SourceIds.audius: au, SourceIds.soundcloud: sc}, SourceIds.defaultPreference);
      expect(g.sources, [SourceIds.soundcloud, SourceIds.audius]);
      expect(g.top, sc.tracks.items.first);
      expect(g.tracks.map((t) => t.sourceTrackId), ['s2', 'a1', 'a2']);
    });

    test('user order wins; exact artist name is the top result', () {
      final g = GroupedResults.from('daft punk', {SourceIds.soundcloud: sc, SourceIds.audius: au}, [SourceIds.audius, SourceIds.soundcloud]);
      expect(g.top, isA<Artist>());
      expect(g.tracks.first.sourceTrackId, 'a1');
      expect(g.artists, isEmpty);
    });

    test('filter to one source and errors are separated', () {
      final failed = SourceSearchResults(sourceId: SourceIds.jamendo, error: StateError('x'));
      final g = GroupedResults.from('q', {SourceIds.soundcloud: sc, SourceIds.audius: au, SourceIds.jamendo: failed}, SourceIds.defaultPreference,
          only: SourceIds.audius);
      expect(g.sources, [SourceIds.audius]);
      expect(g.errors, isEmpty);
      final all = GroupedResults.from('q', {SourceIds.jamendo: failed}, SourceIds.defaultPreference);
      expect(all.isEmpty, isTrue);
      expect(all.errors.keys, [SourceIds.jamendo]);
    });
  });

  group('silo-safe play context', () {
    final tracks = [
      testTrack('a1'),
      testTrack('s1', sourceId: SourceIds.soundcloud),
      testTrack('l1', sourceId: SourceIds.local),
      testTrack('a2'),
      testTrack('s2', sourceId: SourceIds.soundcloud),
    ];

    test('a SoundCloud track queues only SoundCloud + local files', () {
      final ctx = siloSafeContext(tracks, 4);
      expect(ctx.tracks.map((t) => t.sourceTrackId), ['s1', 'l1', 's2']);
      expect(ctx.tracks[ctx.index].sourceTrackId, 's2');
    });

    test('another service queues no SoundCloud track', () {
      final ctx = siloSafeContext(tracks, 3);
      expect(ctx.tracks.map((t) => t.sourceTrackId), ['a1', 'l1', 'a2']);
      expect(ctx.index, 2);
    });

    test('SiloPartition gives the same contexts', () {
      final p = SiloPartition(tracks);
      for (var i = 0; i < tracks.length; i++) {
        final a = p.contextFor(i);
        final b = siloSafeContext(tracks, i);
        expect(a.tracks, b.tracks);
        expect(a.tracks[a.index], tracks[i]);
      }
    });

    test('orderByPreference keeps unknown ids last', () {
      expect(orderByPreference(['zz', 'audius', 'soundcloud'], SourceIds.defaultPreference), ['soundcloud', 'audius', 'zz']);
    });
  });
}
