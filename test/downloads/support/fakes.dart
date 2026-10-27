import 'dart:async';

import 'package:fermata/core/contracts/library.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/contracts/platform.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/download.dart';
import 'package:fermata/core/models/library.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/downloads/network/network_status.dart';

/// Minimal source: only what the download manager uses.
class FakeSource implements MusicSource {
  FakeSource({
    this.id = 'fake',
    Set<SourceCapability>? capabilities,
    this.ready = true,
    this.credentialsConfigured = true,
  }) : capabilities = capabilities ?? {SourceCapability.stream, SourceCapability.download};

  @override
  final String id;

  @override
  final Set<SourceCapability> capabilities;

  bool ready;
  bool credentialsConfigured;

  /// Returns the authorization for a track (null = not permitted).
  DownloadAuthorization? Function(Track track) authorize = (_) => null;

  /// Thrown by [authorizeDownload] instead of authorizing when non-null.
  Object? authorizeError;
  int authorizeCalls = 0;

  @override
  bool supports(SourceCapability c) => capabilities.contains(c);

  @override
  String get displayName => 'Fake';

  @override
  bool get isReady => ready;

  @override
  CredentialStatus get credentialStatus => credentialsConfigured
      ? const CredentialStatus.notNeeded()
      : const CredentialStatus(configured: false, origin: CredentialOrigin.none, missing: ['clientId']);

  @override
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel}) async {
    authorizeCalls++;
    final error = authorizeError;
    if (error != null) throw error;
    return authorize(track);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRegistry implements SourceRegistry {
  FakeRegistry(List<MusicSource> sources) : _sources = {for (final s in sources) s.id: s};

  final Map<String, MusicSource> _sources;

  @override
  MusicSource? byId(String id) => _sources[id];

  @override
  List<MusicSource> get all => _sources.values.toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTrackRepository implements TrackRepository {
  final tracks = <String, Track>{};
  int upserts = 0;

  @override
  Future<void> upsertTracks(List<Track> list) async {
    upserts++;
    for (final t in list) {
      tracks[t.id] = t;
    }
  }

  @override
  Future<Track?> getTrack(String id) async => tracks[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePlaylistRepository implements PlaylistRepository {
  final autoDownload = <Playlist>[];
  final entries = <String, List<Track>>{};
  int autoDownloadCalls = 0;

  @override
  Future<List<Playlist>> autoDownloadPlaylists() async {
    autoDownloadCalls++;
    return List.of(autoDownload);
  }

  @override
  Future<List<Track>> playlistTracks(String id) async => List.of(entries[id] ?? const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHistoryRepository implements HistoryRepository {
  /// Any order; served newest first.
  final records = <PlayRecord>[];

  void played(Track track, DateTime at) => records.add(
      PlayRecord(track: track, playedAt: at, listened: const Duration(minutes: 3), completed: true));

  @override
  Future<List<PlayRecord>> history({int limit = 200, DateTime? before}) async {
    final sorted = records.where((r) => before == null || r.playedAt.isBefore(before)).toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return sorted.take(limit).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNetworkStatus extends NetworkStatus {
  FakeNetworkStatus([this._state = const NetworkState.wifi()]);

  NetworkState _state;
  final _controller = StreamController<NetworkState>.broadcast();

  set state(NetworkState next) {
    if (next == _state) return;
    _state = next;
    _controller.add(next);
  }

  @override
  NetworkState get current => _state;

  @override
  Stream<NetworkState> get changes => _controller.stream;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() => _controller.close();
}

class FakeNotifier implements SystemNotifier {
  FakeNotifier({this.isSupported = true});

  @override
  final bool isSupported;

  final shown = <({String id, String title, String? body})>[];

  @override
  Future<void> show({required String id, required String title, String? body, String? iconPath}) async {
    shown.add((id: id, title: title, body: body));
  }
}

/// Builds a remote track with the given offline rights.
Track remoteTrack(
  String sid, {
  String sourceId = 'fake',
  String title = 'Song',
  String artist = 'Artist',
  String? album = 'Album',
  int? trackNumber = 1,
  OfflineRights offline = OfflineRights.downloadable,
  Uri? artworkUrl,
  String? reason,
}) =>
    Track(
      sourceId: sourceId,
      sourceTrackId: sid,
      title: title,
      artists: [ArtistRef(artist)],
      album: album,
      trackNumber: trackNumber,
      artworkUrl: artworkUrl,
      availability: TrackAvailability(playback: PlaybackRights.full, offline: offline, reason: reason),
    );

Playlist autoPlaylist(String id) => Playlist(id: id, name: 'Auto $id', kind: PlaylistKind.local, autoDownload: true);
