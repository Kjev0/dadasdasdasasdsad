import 'dart:io';

import 'package:fermata/core/contracts/downloads.dart';
import 'package:fermata/core/contracts/library.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/playback/stream_resolver_impl.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSource extends Fake implements MusicSource {
  FakeSource(this.id, this.capabilities);

  @override
  final String id;

  @override
  final Set<SourceCapability> capabilities;

  /// Per sourceTrackId: PlayableSource or exception. Default: a stream URL.
  final results = <String, Object>{};
  final calls = <(String, AudioQuality)>[];

  @override
  bool supports(SourceCapability c) => capabilities.contains(c);

  @override
  Future<PlayableSource> resolveStream(Track track, {AudioQuality quality = AudioQuality.high, CancelToken? cancel}) async {
    calls.add((track.sourceTrackId, quality));
    final r = results[track.sourceTrackId];
    if (r is Exception) throw r;
    if (r is PlayableSource) return r;
    return PlayableSource(
      uri: Uri.parse('https://$id.example/${track.sourceTrackId}.mp3'),
      headers: {'Authorization': 'OAuth $id-token'},
    );
  }
}

class FakeRegistry extends Fake implements SourceRegistry {
  FakeRegistry(List<MusicSource> sources) : _byId = {for (final s in sources) s.id: s};
  final Map<String, MusicSource> _byId;

  @override
  MusicSource? byId(String id) => _byId[id];
}

class FakeDownloads extends Fake implements DownloadManager {
  final files = <String, String>{};

  @override
  Future<String?> localFileFor(String trackId) async => files[trackId];
}

class FakeLinks extends Fake implements TrackLinkRepository {
  final links = <String, List<(Track, TrackLink)>>{};

  @override
  Future<List<(Track, TrackLink)>> linkedTracks(String trackId) async => links[trackId] ?? const [];

  void add(Track from, Track to, double confidence) {
    (links[from.id] ??= []).add((
      to,
      TrackLink(
        trackId: from.id,
        linkedTrackId: to.id,
        confidence: confidence,
        userConfirmed: false,
        createdAt: DateTime(2026),
      ),
    ));
  }
}

const streamCaps = {SourceCapability.stream, SourceCapability.searchTracks};
const full = TrackAvailability(playback: PlaybackRights.full, offline: OfflineRights.streamOnly);
const previewAvail = TrackAvailability(playback: PlaybackRights.preview, offline: OfflineRights.unavailable);

Track remote(String source, String id, {TrackAvailability availability = full}) =>
    Track(sourceId: source, sourceTrackId: id, title: 'Song $id', availability: availability);

void main() {
  late Directory dir;
  late FakeSource soundcloud;
  late FakeSource audius;
  late FakeSource deezer;
  late FakeSource spotify;
  late FakeDownloads downloads;
  late FakeLinks links;
  late SettingsStore settings;
  var metered = false;

  StreamResolverImpl resolver() => StreamResolverImpl(
        sources: FakeRegistry([soundcloud, audius, deezer, spotify]),
        downloads: downloads,
        links: links,
        settings: settings,
        isMetered: () async => metered,
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fermata_resolver_');
    soundcloud = FakeSource(SourceIds.soundcloud, streamCaps);
    audius = FakeSource(SourceIds.audius, streamCaps);
    deezer = FakeSource(SourceIds.deezer, {SourceCapability.previewOnly});
    spotify = FakeSource(SourceIds.spotify, {SourceCapability.externalPlayback, SourceCapability.playlistImport});
    downloads = FakeDownloads();
    links = FakeLinks();
    settings = SettingsStore.inMemory();
    metered = false;
  });
  tearDown(() => dir.delete(recursive: true));

  Future<String> makeFile(String name) async {
    final f = File('${dir.path}/$name');
    await f.writeAsBytes([1, 2, 3]);
    return f.path;
  }

  test('a verified download wins over the source stream', () async {
    final t = remote(SourceIds.soundcloud, '1');
    downloads.files[t.id] = await makeFile('1.mp3');
    final r = await resolver().resolve(t);
    expect(r.source.isLocalFile, isTrue);
    expect(r.source.uri, Uri.file(downloads.files[t.id]!));
    expect(r.playedTrack, t);
    expect(soundcloud.calls, isEmpty);
  });

  test('a registered download whose file vanished falls through to the stream', () async {
    final t = remote(SourceIds.soundcloud, '1');
    downloads.files[t.id] = '${dir.path}/gone.mp3';
    final r = await resolver().resolve(t);
    expect(r.source.isLocalFile, isFalse);
    expect(soundcloud.calls.single.$1, '1');
  });

  test('user-owned local files play when present, else file_missing', () async {
    final path = await makeFile('song.flac');
    final local = Track(sourceId: SourceIds.local, sourceTrackId: 'x', title: 'x', localPath: path,
        availability: const TrackAvailability.local());
    final r = await resolver().resolve(local);
    expect(r.source.uri, Uri.file(path));
    expect(r.source.isLocalFile, isTrue);

    final missing = Track(sourceId: SourceIds.local, sourceTrackId: 'y', title: 'y', localPath: '${dir.path}/nope.flac');
    await expectLater(
      resolver().resolve(missing),
      throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.fileMissing)),
    );
  });

  test('stream quality follows settings and the metered state; headers pass through', () async {
    await settings.update((s) => s.copyWith(
        audioQuality: s.audioQuality.copyWith(streaming: AudioQuality.lossless, mobileStreaming: AudioQuality.low)));
    final t = remote(SourceIds.soundcloud, '7');
    final r = await resolver().resolve(t);
    expect(soundcloud.calls.last.$2, AudioQuality.lossless);
    expect(r.source.headers['Authorization'], 'OAuth soundcloud-token');
    metered = true;
    await resolver().resolve(t);
    expect(soundcloud.calls.last.$2, AudioQuality.low);
  });

  test('unavailable tracks report the availability reason', () async {
    final t = remote(SourceIds.soundcloud, '9',
        availability: const TrackAvailability(
            playback: PlaybackRights.unavailable, offline: OfflineRights.unavailable, reason: AvailabilityReason.deleted));
    await expectLater(
      resolver().resolve(t),
      throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.deleted)),
    );
    expect(soundcloud.calls, isEmpty);
  });

  test('an external-only track plays its linked match (playedTrack = substitute)', () async {
    final sp = remote(SourceIds.spotify, 'sp1',
        availability: const TrackAvailability(playback: PlaybackRights.externalOnly, offline: OfflineRights.unavailable));
    final sc = remote(SourceIds.soundcloud, 'sc1');
    links.add(sp, sc, 0.95);
    final r = await resolver().resolve(sp);
    expect(r.playedTrack, sc);
    expect(r.source.uri.host, 'soundcloud.example');
  });

  test('links are tried in provider-preference order, then by confidence', () async {
    final sp = remote(SourceIds.spotify, 'sp1');
    final dz = remote(SourceIds.deezer, 'dz', availability: full);
    final au = remote(SourceIds.audius, 'au');
    final scLow = remote(SourceIds.soundcloud, 'scLow');
    final scHigh = remote(SourceIds.soundcloud, 'scHigh');
    links
      ..add(sp, dz, 0.99)
      ..add(sp, au, 0.97)
      ..add(sp, scLow, 0.80)
      ..add(sp, scHigh, 0.90);
    soundcloud.results['scHigh'] = const UnplayableTrackException('soundcloud:scHigh', AvailabilityReason.regionRestricted);
    final r = await resolver().resolve(sp);
    expect(soundcloud.calls.map((c) => c.$1), ['scHigh', 'scLow']);
    expect(r.playedTrack, scLow);

    // With a different preference order audius comes first.
    await settings.update((s) => s.copyWith(
        services: s.services.copyWith(providerOrder: [SourceIds.audius, SourceIds.soundcloud, SourceIds.deezer])));
    final r2 = await resolver().resolve(sp);
    expect(r2.playedTrack, au);
  });

  test('preview-only links are used only when nothing else works', () async {
    final sp = remote(SourceIds.spotify, 'sp1');
    final dz = remote(SourceIds.deezer, 'dz', availability: previewAvail);
    final sc = remote(SourceIds.soundcloud, 'sc');
    links
      ..add(sp, dz, 0.99)
      ..add(sp, sc, 0.7);
    await settings.update((s) => s.copyWith(
        services: s.services.copyWith(providerOrder: [SourceIds.deezer, SourceIds.soundcloud])));
    final r = await resolver().resolve(sp);
    expect(r.playedTrack, sc, reason: 'full-length beats a higher-ranked preview');
    expect(r.source.isPreview, isFalse);

    soundcloud.results['sc'] = const NetworkException('down');
    final r2 = await resolver().resolve(sp);
    expect(r2.playedTrack, dz);
    expect(r2.source.isPreview, isTrue);
  });

  test("a source's own preview is kept only when no full link exists", () async {
    final dz = remote(SourceIds.deezer, 'dz', availability: previewAvail);
    final r = await resolver().resolve(dz);
    expect(r.source.isPreview, isTrue);
    expect(r.playedTrack, dz);

    final sc = remote(SourceIds.soundcloud, 'sc');
    links.add(dz, sc, 0.9);
    final r2 = await resolver().resolve(dz);
    expect(r2.playedTrack, sc);
    expect(r2.source.isPreview, isFalse);
  });

  test('the most informative reason is reported', () async {
    final sp = remote(SourceIds.spotify, 'sp1');
    final sc = remote(SourceIds.soundcloud, 'sc');
    links.add(sp, sc, 0.9);
    soundcloud.results['sc'] = const NetworkException('no route');
    await expectLater(
      resolver().resolve(sp),
      throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'reason', AvailabilityReason.offline)),
    );
    expect(StreamResolverImpl.mostInformative([AvailabilityReason.unknown]), AvailabilityReason.unknown);
    expect(
      StreamResolverImpl.mostInformative([AvailabilityReason.externalOnly, AvailabilityReason.deleted]),
      AvailabilityReason.deleted,
    );
  });

  test('source exceptions map to reason codes', () async {
    final a = remote(SourceIds.soundcloud, 'a');
    soundcloud.results['a'] = MissingCredentialsException(SourceIds.soundcloud, const ['clientId']);
    await expectLater(resolver().resolve(a),
        throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'r', AvailabilityReason.credentialsMissing)));
    soundcloud.results['a'] = const AuthRequiredException(SourceIds.soundcloud, 'connect');
    await expectLater(resolver().resolve(a),
        throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'r', AvailabilityReason.notAuthorized)));
    final sp = remote(SourceIds.spotify, 'sp');
    await expectLater(resolver().resolve(sp),
        throwsA(isA<UnplayableTrackException>().having((e) => e.reason, 'r', AvailabilityReason.externalOnly)));
  });

  test('disabled sources are skipped', () async {
    await settings.update((s) => s.copyWith(services: s.services.copyWith(disabledSources: {SourceIds.soundcloud})));
    final sp = remote(SourceIds.spotify, 'sp1');
    final sc = remote(SourceIds.soundcloud, 'sc');
    final au = remote(SourceIds.audius, 'au');
    links
      ..add(sp, sc, 0.99)
      ..add(sp, au, 0.5);
    final r = await resolver().resolve(sp);
    expect(r.playedTrack, au);
    expect(soundcloud.calls, isEmpty);
  });

  test('cancellation aborts resolution', () async {
    final token = CancelToken()..cancel();
    await expectLater(resolver().resolve(remote(SourceIds.soundcloud, 'z'), cancel: token),
        throwsA(isA<OperationCanceledException>()));
  });

  test('default settings expose the documented provider order', () {
    expect(const AppSettings().services.providerOrder.first, SourceIds.soundcloud);
  });
}
