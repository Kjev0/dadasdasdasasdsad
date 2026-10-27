import '../models/catalog.dart';
import '../models/library.dart';
import '../models/track.dart';

/// Coarse change notifications so UIs can refresh.
enum LibraryTopic { tracks, playlists, favorites, history, links, folders, searches }

abstract class LibraryChangeBus {
  Stream<Set<LibraryTopic>> get changes;
}

/// Every track Fermata knows about (local files, remote tracks the user
/// interacted with, imported tracks). Remote tracks are stored so playlists,
/// favorites and history work offline.
abstract class TrackRepository {
  /// Insert or update by [Track.id]. Keeps `dateAdded` of existing rows.
  Future<void> upsertTracks(List<Track> tracks);

  Future<Track?> getTrack(String id);

  /// Returns tracks in the order of [ids]; unknown ids are skipped.
  Future<List<Track>> getTracks(List<String> ids);

  Future<List<Track>> query(TrackQuery query);

  Future<int> count(TrackQuery query);

  Future<void> removeTracks(List<String> ids);

  Future<List<AlbumSummary>> albums({String? artist, String? text});

  Future<List<ArtistSummary>> artists({String? text});

  Future<List<String>> genres();

  /// Duplicate candidates among library tracks (same file hash, same ISRC,
  /// or same normalized title+artist+duration±2 s).
  Future<List<DuplicateGroup>> findDuplicates();

  /// Local tracks whose file no longer exists.
  Future<List<Track>> findMissingFiles();
}

abstract class PlaylistRepository {
  Future<List<Playlist>> playlists();

  Future<Playlist?> getPlaylist(String id);

  Future<Playlist> createPlaylist(
    String name, {
    String? description,
    String? sourceId,
    String? sourcePlaylistId,
    Uri? artworkUrl,
  });

  Future<Playlist> createSmartPlaylist(String name, SmartPlaylistRules rules, {String? description});

  Future<void> updatePlaylist(Playlist playlist);

  Future<void> deletePlaylist(String id);

  /// Track ids in order. For smart playlists the rules are evaluated.
  Future<List<String>> playlistTrackIds(String id);

  Future<List<Track>> playlistTracks(String id);

  /// Insert at [position] (default: append). Tracks must already be upserted.
  Future<void> addTracks(String playlistId, List<String> trackIds, {int? position});

  /// Remove the entries at the given positions.
  Future<void> removeAt(String playlistId, List<int> positions);

  Future<void> removeTracks(String playlistId, List<String> trackIds);

  Future<void> move(String playlistId, int from, int to);

  /// Remove duplicate entries (same track id, or linked tracks). Returns the
  /// number of removed entries.
  Future<int> deduplicate(String playlistId);

  Future<List<Playlist>> autoDownloadPlaylists();
}

abstract class FavoritesRepository {
  Future<bool> isFavorite(String trackId);

  /// Upserts [track] and toggles its favorite flag.
  Future<void> setFavorite(Track track, bool favorite);

  Future<List<Track>> favorites();

  Stream<Set<String>> watchFavoriteIds();
}

abstract class HistoryRepository {
  Future<void> recordPlay(PlayRecord record);

  Future<List<PlayRecord>> history({int limit = 200, DateTime? before});

  /// Distinct tracks, most recent first.
  Future<List<Track>> recentlyPlayed({int limit = 30});

  Future<ListeningStats> stats({DateTime? since});

  Future<int> playCount(String trackId);

  Future<void> clearHistory();
}

/// Multiple provider matches for the same logical track.
abstract class TrackLinkRepository {
  /// Symmetric link. Upserts confidence/confirmation if it exists.
  Future<void> link(String trackId, String linkedTrackId, {required double confidence, bool userConfirmed = false});

  Future<void> unlink(String trackId, String linkedTrackId);

  /// All tracks linked to [trackId] (transitively within the group),
  /// best confidence first.
  Future<List<(Track, TrackLink)>> linkedTracks(String trackId);
}

abstract class SearchHistoryRepository {
  Future<void> add(String query);

  Future<List<String>> recent({int limit = 12});

  Future<void> remove(String query);

  Future<void> clear();
}

/// Local folders: scanning, watching, tag reading, M3U.
abstract class LocalLibraryService {
  Future<List<LibraryFolder>> folders();

  Future<void> addFolder(String path, {bool watch = true});

  Future<void> removeFolder(String path, {bool removeTracks = true});

  /// Full or incremental rescan of all folders (or one).
  Stream<ScanProgress> scan({String? folder, bool full = false});

  /// Start watching folders that have `watch == true` (desktop only; on
  /// Android a rescan happens on app start/resume).
  Future<void> startWatching();

  Future<void> stopWatching();

  /// Import tracks from an audio file picked by the user (not in a folder).
  Future<Track?> importFile(String path);

  /// Write edited tags back to the file when the format supports it;
  /// otherwise stores a non-destructive override in the library.
  /// Returns true when the file itself was written.
  Future<bool> editTags(Track track, Track edited);

  bool get supportsFileTagWriting;

  Future<List<Track>> importM3u(String path);

  Future<void> exportM3u(String playlistId, String path, {bool extended = true});
}

/// Destructive data controls (Privacy settings).
abstract class LibraryMaintenance {
  /// Deletes history, favorites, playlists, links, searches and cached
  /// remote metadata. Local audio files are never deleted.
  Future<void> deleteAllUserData();

  /// Backup of all user data (JSON) for Settings → Backup & restore.
  Future<Map<String, Object?>> exportBackup();

  Future<void> importBackup(Map<String, Object?> backup, {bool merge = true});

  Future<int> databaseSizeBytes();
}
