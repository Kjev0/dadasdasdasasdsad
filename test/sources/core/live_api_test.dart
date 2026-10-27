// Live smoke tests against the real public Audius and Deezer APIs.
// Skipped by default (CI must not depend on the network); run with:
//   FERMATA_LIVE_TESTS=1 flutter test test/sources/core/live_api_test.dart
import 'dart:io';

import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/net/http_client.dart';
import 'package:fermata/sources/audius/audius_source.dart';
import 'package:fermata/sources/deezer/deezer_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final live = Platform.environment['FERMATA_LIVE_TESTS'] == '1';
  final skip = live ? null : 'set FERMATA_LIVE_TESTS=1 to run against the real APIs';
  late FermataHttp http;

  setUp(() => http = FermataHttp());
  tearDown(() => http.close());

  test(
    'Audius: search, track, playable stream URL',
    () async {
      final audius = AudiusSource(http: http);
      final page = await audius.searchTracks('lofi', limit: 5);
      expect(page.items, isNotEmpty);
      final playable = page.items.firstWhere((t) => t.availability.playback == PlaybackRights.full);
      final stream = await audius.resolveStream(playable);
      final client = HttpClient();
      try {
        final req = await client.getUrl(stream.uri)
          ..followRedirects = false;
        final res = await req.close();
        await res.drain<void>();
        expect(res.statusCode, anyOf(200, 302), reason: 'the stream endpoint redirects to a content node');
      } finally {
        client.close(force: true);
      }
      final trending = await audius.trending(genre: 'Electronic', limit: 3);
      expect(trending, isNotEmpty);
      expect(await audius.genres(), contains('Electronic'));
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'Deezer: search, ISRC, preview, playlist, chart',
    () async {
      final deezer = DeezerSource(http: http);
      final page = await deezer.searchTracks('daft punk', limit: 3);
      expect(page.items, isNotEmpty);
      expect(page.hasMore, isTrue);
      final byIsrc = await deezer.lookupByIsrc('GBDUW0000059');
      expect(byIsrc?.title, contains('Harder'));
      final preview = await deezer.resolveStream(byIsrc!);
      expect(preview.isPreview, isTrue);
      expect(preview.expiresAt!.isAfter(DateTime.now()), isTrue);
      final playlist = await deezer.getPlaylist('https://www.deezer.com/en/playlist/908622995');
      expect(playlist.tracks.items, isNotEmpty);
      expect(await deezer.trending(limit: 3), isNotEmpty);
      expect(await deezer.genres(), contains('Pop'));
      expect(await deezer.newReleases(limit: 3), isNotEmpty);
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
