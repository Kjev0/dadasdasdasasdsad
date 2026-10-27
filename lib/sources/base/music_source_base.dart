import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/contracts/music_source.dart';
import '../../core/errors.dart';
import '../../core/models/auth.dart';
import '../../core/models/catalog.dart';
import '../../core/models/download.dart';
import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import '../../core/util/cancel_token.dart';

/// Convenience base class for providers (see docs/PLUGINS.md).
///
/// Defaults:
/// * every catalog / library / playback operation throws
///   [UnsupportedSourceOperation] — override exactly what the source declares
///   in [capabilities];
/// * auth is [SourceAuthState.notRequired] and [credentialStatus] is
///   [CredentialStatus.notNeeded] (public APIs);
/// * [connect] throws [UnsupportedSourceOperation], [disconnect] is a no-op;
/// * [authorizeDownload] returns null (the contract: only a source that
///   explicitly permits a download returns an authorization);
/// * [externalPlaybackUri] returns the track's own permalink.
///
/// Sources with accounts mix in `OAuthSourceMixin` (lib/sources/auth/),
/// which replaces the auth-related members.
abstract class MusicSourceBase extends MusicSource {
  MusicSourceBase({SourceAuthState initialAuthState = const SourceAuthState.notRequired()})
    : _authState = initialAuthState;

  final StreamController<SourceAuthState> _authController = StreamController<SourceAuthState>.broadcast();
  SourceAuthState _authState;
  bool _disposed = false;

  @override
  Uri? get termsUrl => null;

  // ---- Lifecycle & auth -------------------------------------------------

  @override
  Future<void> init() async {}

  @override
  CredentialStatus get credentialStatus => const CredentialStatus.notNeeded();

  @override
  SourceAuthState get authState => _authState;

  @override
  Stream<SourceAuthState> get authStateChanges => _authController.stream;

  /// Updates [authState] and notifies listeners (the registry forwards this
  /// to the UI). Safe to call after [dispose] (ignored).
  @protected
  void emitAuthState(SourceAuthState state) {
    _authState = state;
    if (!_disposed && !_authController.isClosed) _authController.add(state);
  }

  @override
  Future<void> connect() async =>
      throw UnsupportedSourceOperation(id, 'connect', '$displayName does not use account connections.');

  @override
  Future<void> disconnect() async {}

  /// Ready when credentials are configured and the source either needs no
  /// account or is connected.
  @override
  bool get isReady =>
      credentialStatus.configured &&
      (authState.status == SourceConnectionStatus.notRequired || authState.status == SourceConnectionStatus.connected);

  /// Whether [dispose] has been called.
  @protected
  bool get isDisposed => _disposed;

  // ---- Helpers for subclasses -------------------------------------------

  /// Throws the standard [UnsupportedSourceOperation] for [operation].
  @protected
  Never unsupported(String operation, [String? explanation]) =>
      throw UnsupportedSourceOperation(id, operation, explanation ?? '$displayName does not support $operation.');

  /// Throws [UnsupportedSourceOperation] unless [capability] is declared.
  @protected
  void requireCapability(SourceCapability capability, String operation) {
    if (!supports(capability)) unsupported(operation);
  }

  /// Builds a [Track.id]-compatible id for this source.
  @protected
  String trackIdFor(String sourceTrackId) => Track.makeId(id, sourceTrackId);

  /// Throws [ArgumentError] when [track] belongs to another source.
  @protected
  void checkOwnTrack(Track track) {
    if (track.sourceId != id) {
      throw ArgumentError.value(track.id, 'track', 'Track belongs to ${track.sourceId}, not $id');
    }
  }

  // ---- Catalog ------------------------------------------------------------

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) async =>
      unsupported('searchTracks');

  @override
  Future<Page<Artist>> searchArtists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async =>
      unsupported('searchArtists');

  @override
  Future<Page<Album>> searchAlbums(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async =>
      unsupported('searchAlbums');

  @override
  Future<Page<Playlist>> searchPlaylists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async =>
      unsupported('searchPlaylists');

  @override
  Future<Track?> getTrack(String sourceTrackId, {CancelToken? cancel}) async => unsupported('getTrack');

  @override
  Future<Artist?> getArtist(String sourceArtistId, {CancelToken? cancel}) async => unsupported('getArtist');

  @override
  Future<Page<Track>> artistTopTracks(
    String sourceArtistId, {
    String? cursor,
    int limit = 30,
    CancelToken? cancel,
  }) async => unsupported('artistTopTracks');

  @override
  Future<List<Artist>> relatedArtists(String sourceArtistId, {int limit = 12, CancelToken? cancel}) async =>
      unsupported('relatedArtists');

  @override
  Future<Page<Track>> albumTracks(String sourceAlbumId, {String? cursor, CancelToken? cancel}) async =>
      unsupported('albumTracks');

  @override
  Future<PlaylistDetail> getPlaylist(String idOrUrl, {String? cursor, CancelToken? cancel}) async =>
      unsupported('getPlaylist');

  @override
  Future<List<Track>> relatedTracks(String sourceTrackId, {int limit = 20, CancelToken? cancel}) async =>
      unsupported('relatedTracks');

  @override
  Future<List<Track>> trending({String? genre, int limit = 30, CancelToken? cancel}) async => unsupported('trending');

  @override
  Future<List<Album>> newReleases({int limit = 20, CancelToken? cancel}) async => unsupported('newReleases');

  @override
  Future<List<String>> genres({CancelToken? cancel}) async => unsupported('genres');

  @override
  Future<Track?> lookupByIsrc(String isrc, {CancelToken? cancel}) async => unsupported('lookupByIsrc');

  // ---- User library -------------------------------------------------------

  @override
  Future<List<Playlist>> userPlaylists({CancelToken? cancel}) async => unsupported('userPlaylists');

  @override
  Future<Page<Track>> userLikedTracks({String? cursor, CancelToken? cancel}) async => unsupported('userLikedTracks');

  // ---- Playback & downloads ---------------------------------------------

  @override
  Future<PlayableSource> resolveStream(
    Track track, {
    AudioQuality quality = AudioQuality.high,
    CancelToken? cancel,
  }) async => unsupported('resolveStream', '$displayName cannot stream audio inside Fermata.');

  @override
  Uri? externalPlaybackUri(Track track) => track.sourceId == id ? track.permalink : null;

  @override
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel}) async => null;

  @override
  @mustCallSuper
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _authController.close();
  }
}
