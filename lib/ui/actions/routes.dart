import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';

/// Route paths used by the router and every page. Always build locations
/// through these helpers (they encode path segments).
abstract final class AppRoutes {
  static const root = '/';
  static const home = '/home';
  static const search = '/search';
  static const explore = '/explore';
  static const libraryPath = '/library';
  static const playlists = '/playlists';
  static const downloads = '/downloads';
  static const favorites = '/favorites';
  static const history = '/history';
  static const queue = '/queue';
  static const nowPlaying = '/now-playing';
  static const settings = '/settings';
  static const import = '/import';
  static const onboarding = '/onboarding';

  static String _e(String s) => Uri.encodeComponent(s);

  /// `/library?tab=<tab>` (tabs are defined by the Library page).
  static String library({String? tab}) => tab == null ? libraryPath : '$libraryPath?tab=${_e(tab)}';

  static String playlist(String id) => '$playlists/${_e(id)}';

  /// Artist page. For local files [artistId] is the artist name.
  static String artist(String sourceId, String artistId) => '/artist/${_e(sourceId)}/${_e(artistId)}';

  /// Album page. For local files [albumId] is the album title.
  static String album(String sourceId, String albumId) => '/album/${_e(sourceId)}/${_e(albumId)}';

  static String settingsSection(String section) => '$settings/${_e(section)}';

  static String importSession(String sessionId) => '$import/${_e(sessionId)}';

  /// Now playing opened on a given panel: `artwork`, `lyrics` or `queue`.
  static String nowPlayingView(String view) => '$nowPlaying?view=${_e(view)}';

  /// Artist route for the primary artist of [track], if one can be built.
  static String? artistForTrack(Track track) {
    if (track.artists.isEmpty) return null;
    final a = track.artists.first;
    if (a.sourceArtistId != null && a.sourceArtistId!.isNotEmpty) return artist(track.sourceId, a.sourceArtistId!);
    if (track.isLocal && a.name.isNotEmpty) return artist(SourceIds.local, a.name);
    return null;
  }

  /// Album route for [track] (`extra['albumId']` or
  /// `extra['<sourceId>.albumId']` for remote tracks, the album title for
  /// local files), if one can be built.
  static String? albumForTrack(Track track) {
    final albumId = track.extra['albumId'] ?? track.extra['${track.sourceId}.albumId'];
    if (albumId != null && albumId.isNotEmpty) return album(track.sourceId, albumId);
    if (track.isLocal && (track.album ?? '').isNotEmpty) return album(SourceIds.local, track.album!);
    return null;
  }
}

/// The uploader's page on the provider (`extra['uploaderUrl']` or
/// `extra['<sourceId>.uploaderUrl']`), used for SoundCloud attribution.
Uri? uploaderUriOf(Track track) {
  final raw = track.extra['uploaderUrl'] ?? track.extra['${track.sourceId}.uploaderUrl'];
  return raw == null ? null : Uri.tryParse(raw);
}

/// Section ids for `/settings/:section`. The Settings page (ui-settings)
/// must accept these ids; the command palette and other pages deep-link
/// with them.
abstract final class SettingsSections {
  static const appearance = 'appearance';
  static const glass = 'glass';
  static const playback = 'playback';
  static const audioQuality = 'audioQuality';
  static const downloads = 'downloads';
  static const storage = 'storage';
  static const performance = 'performance';
  static const savers = 'savers';
  static const services = 'services';
  static const import = 'import';
  static const notifications = 'notifications';
  static const background = 'background';
  static const desktop = 'desktop';
  static const startup = 'startup';
  static const shortcuts = 'shortcuts';
  static const privacy = 'privacy';
  static const language = 'language';
  static const accessibility = 'accessibility';
  static const updates = 'updates';
  static const about = 'about';

  static const all = [
    appearance,
    glass,
    playback,
    audioQuality,
    downloads,
    storage,
    performance,
    savers,
    services,
    import,
    notifications,
    background,
    desktop,
    startup,
    shortcuts,
    privacy,
    language,
    accessibility,
    updates,
    about,
  ];
}
