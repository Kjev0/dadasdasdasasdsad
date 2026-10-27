import '../models/auth.dart';
import '../models/catalog.dart';
import '../models/download.dart';
import '../models/playback.dart';
import '../models/track.dart';
import '../util/cancel_token.dart';

/// What a source can do. The UI only offers actions a source declares.
enum SourceCapability {
  searchTracks,
  searchArtists,
  searchAlbums,
  searchPlaylists,

  /// Full-length streaming inside Fermata.
  stream,

  /// Only previews can be played inside Fermata.
  previewOnly,

  /// Playback must happen in the provider's app/site ([MusicSource.externalPlaybackUri]).
  externalPlayback,

  /// Some tracks may be downloaded (per-track rights still apply).
  download,

  /// Read the connected user's playlists / likes.
  userLibrary,

  /// Fetch a playlist by id/URL (public or the user's).
  playlistImport,
  isrcLookup,
  relatedTracks,
  trending,
  artistPages,
  albumPages,
  genres,
  newReleases,

  /// Account connection via OAuth.
  oauth,
}

/// The plugin API: every music provider implements this.
///
/// Rules for implementations (see docs/PLUGINS.md):
/// * Never fabricate results. If the API cannot be reached or credentials are
///   missing, throw the appropriate [FermataException].
/// * Throw `UnsupportedSourceOperation` for operations not in [capabilities].
/// * Use `FermataHttp` for all network calls (timeouts, retries, cancellation).
/// * Map provider restrictions faithfully into [TrackAvailability].
/// * Never ask for or store user passwords; OAuth only.
abstract class MusicSource {
  /// Stable id, see `SourceIds`.
  String get id;

  /// Human-readable name ("SoundCloud").
  String get displayName;

  Set<SourceCapability> get capabilities;

  bool supports(SourceCapability c) => capabilities.contains(c);

  /// One-paragraph English description of what this integration can and
  /// cannot do (shown in Connected services; localized by the UI when known).
  String get limitationsNote;

  /// Link to the provider's own terms / attribution requirements.
  Uri? get termsUrl;

  // ---- Lifecycle & auth -------------------------------------------------

  /// Load tokens/credentials. Must not throw for missing credentials.
  Future<void> init();

  /// Whether developer credentials are configured.
  CredentialStatus get credentialStatus;

  SourceAuthState get authState;
  Stream<SourceAuthState> get authStateChanges;

  /// Start the OAuth flow (opens the system browser). Completes when
  /// connected; throws on failure/cancel.
  Future<void> connect();

  /// Revoke/delete tokens locally (and remotely where the API supports it).
  Future<void> disconnect();

  /// Whether the source can currently serve requests (credentials present,
  /// connected if required).
  bool get isReady;

  // ---- Catalog ------------------------------------------------------------

  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel});

  Future<Page<Artist>> searchArtists(String query, {String? cursor, int limit = 20, CancelToken? cancel});

  Future<Page<Album>> searchAlbums(String query, {String? cursor, int limit = 20, CancelToken? cancel});

  Future<Page<Playlist>> searchPlaylists(String query, {String? cursor, int limit = 20, CancelToken? cancel});

  /// Fresh metadata + availability for a track. Returns null if deleted.
  Future<Track?> getTrack(String sourceTrackId, {CancelToken? cancel});

  Future<Artist?> getArtist(String sourceArtistId, {CancelToken? cancel});

  Future<Page<Track>> artistTopTracks(String sourceArtistId, {String? cursor, int limit = 30, CancelToken? cancel});

  Future<List<Artist>> relatedArtists(String sourceArtistId, {int limit = 12, CancelToken? cancel});

  Future<Page<Track>> albumTracks(String sourceAlbumId, {String? cursor, CancelToken? cancel});

  /// [idOrUrl] may be a provider id or a share URL.
  Future<PlaylistDetail> getPlaylist(String idOrUrl, {String? cursor, CancelToken? cancel});

  Future<List<Track>> relatedTracks(String sourceTrackId, {int limit = 20, CancelToken? cancel});

  Future<List<Track>> trending({String? genre, int limit = 30, CancelToken? cancel});

  Future<List<Album>> newReleases({int limit = 20, CancelToken? cancel});

  Future<List<String>> genres({CancelToken? cancel});

  Future<Track?> lookupByIsrc(String isrc, {CancelToken? cancel});

  // ---- User library (requires connection) ------------------------------

  Future<List<Playlist>> userPlaylists({CancelToken? cancel});

  Future<Page<Track>> userLikedTracks({String? cursor, CancelToken? cancel});

  // ---- Playback & downloads --------------------------------------------

  /// Resolve a directly playable URL. Throws `UnplayableTrackException`
  /// with an `AvailabilityReason` when not permitted/possible.
  Future<PlayableSource> resolveStream(Track track, {AudioQuality quality = AudioQuality.high, CancelToken? cancel});

  /// URL that opens the track in the provider's own app or website.
  Uri? externalPlaybackUri(Track track);

  /// Returns an authorized download location if — and only if — the source
  /// explicitly permits downloading this track; otherwise null.
  Future<DownloadAuthorization?> authorizeDownload(Track track, {CancelToken? cancel});

  Future<void> dispose();
}

// A convenience base class `MusicSourceBase` (unsupported operations throw
// `UnsupportedSourceOperation`, auth defaults to "not required") lives in
// lib/sources/base/music_source_base.dart.

/// Holds all registered sources, ordered by user preference.
abstract class SourceRegistry {
  List<MusicSource> get all;

  /// Sources ordered by the user's provider preference (settings).
  List<MusicSource> get ordered;

  MusicSource? byId(String id);

  MusicSource require(String id);

  void register(MusicSource source);

  /// Emits whenever a source's auth state or the preference order changes.
  Stream<void> get changes;

  /// Search all ready sources concurrently. Results arrive per source as they
  /// complete; failures are reported in [SourceSearchResults.error].
  Stream<SourceSearchResults> searchAll(
    String query, {
    Set<SearchType> types = const {SearchType.tracks, SearchType.artists, SearchType.albums, SearchType.playlists},
    Set<String>? onlySources,
    CancelToken? cancel,
  });
}
