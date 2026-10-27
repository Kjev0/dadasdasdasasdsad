// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Fermata';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionClose => 'Close';

  @override
  String get actionDone => 'Done';

  @override
  String get actionOk => 'OK';

  @override
  String get actionLearnMore => 'Learn more';

  @override
  String get actionRestoreDefaults => 'Restore defaults';

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get errorOffline =>
      'You\'re offline. Check your connection and try again.';

  @override
  String get errorTimeout => 'The request timed out. Try again.';

  @override
  String get errorRateLimited => 'The service is busy. Try again in a moment.';

  @override
  String errorAuthRequired(String service) {
    return 'Reconnect your $service account to continue.';
  }

  @override
  String errorCredentialsMissing(String service) {
    return '$service needs developer credentials before it can be used.';
  }

  @override
  String errorUnsupported(String service) {
    return '$service doesn\'t support this.';
  }

  @override
  String get reasonDeleted => 'This track was deleted.';

  @override
  String get reasonPrivate => 'This track is private.';

  @override
  String get reasonRegionRestricted => 'Not available in your region.';

  @override
  String get reasonSubscriptionRequired =>
      'Requires a subscription on the provider.';

  @override
  String get reasonNotStreamable => 'The artist hasn\'t allowed streaming.';

  @override
  String get reasonPreviewOnly => 'Only a preview is available.';

  @override
  String get reasonExternalOnly => 'Plays in the provider\'s own app.';

  @override
  String get reasonFileMissing => 'The file is missing.';

  @override
  String get reasonNotAuthorized => 'Not authorized.';

  @override
  String get reasonCredentialsMissing => 'Provider not set up.';

  @override
  String get reasonOffline => 'Unavailable offline.';

  @override
  String get reasonUnknown => 'Unavailable.';

  @override
  String get offlineUserOwned => 'Your file';

  @override
  String get offlineDownloadable => 'Downloadable';

  @override
  String get offlineStreamOnly => 'Stream only';

  @override
  String get offlineUnavailable => 'Not available offline';

  @override
  String get desktopTrayNotPlaying => 'Not playing';

  @override
  String desktopTrayNowPlaying(String title, String artist) {
    return '$title — $artist';
  }

  @override
  String get desktopTrayPlay => 'Play';

  @override
  String get desktopTrayPause => 'Pause';

  @override
  String get desktopTrayPrevious => 'Previous';

  @override
  String get desktopTrayNext => 'Next';

  @override
  String get desktopTrayShow => 'Show Fermata';

  @override
  String get desktopTrayQuit => 'Quit Fermata';

  @override
  String get desktopTrayTooltipIdle => 'Fermata';

  @override
  String desktopTrayTooltipTrack(String title, String artist) {
    return 'Fermata — $title · $artist';
  }

  @override
  String desktopTrayTooltipTitleOnly(String title) {
    return 'Fermata — $title';
  }

  @override
  String get desktopTrayUnavailableGnome =>
      'GNOME only shows tray icons with the AppIndicator extension. Without it, closing the window minimizes Fermata instead, and you can bring it back from the dock or the media controls.';

  @override
  String get desktopTrayUnavailableNoHost =>
      'This desktop has no system tray (no StatusNotifier host is running). Closing the window minimizes Fermata instead.';

  @override
  String get desktopTrayUnavailableNoBus =>
      'Fermata can\'t reach the desktop session bus, so it can\'t show a tray icon. Closing the window minimizes Fermata instead.';

  @override
  String get desktopTrayUnavailableIconMissing =>
      'The tray icon file is missing from this installation, so the tray icon is turned off. Reinstalling Fermata should fix this.';

  @override
  String get desktopTrayUnavailableDisabled =>
      'The tray icon is turned off. Closing the window minimizes Fermata instead.';

  @override
  String get desktopTrayUnavailableFailed =>
      'The system tray refused the icon. Closing the window minimizes Fermata instead.';

  @override
  String get desktopTrayUnavailableUnsupported =>
      'This platform has no system tray.';

  @override
  String get desktopCloseDialogTitle => 'Close Fermata?';

  @override
  String get desktopCloseDialogBody =>
      'Fermata can keep playing in the background. You can bring it back from the tray icon or your desktop\'s media controls.';

  @override
  String get desktopCloseDialogKeepPlaying => 'Keep playing in background';

  @override
  String get desktopCloseDialogQuit => 'Quit';

  @override
  String get desktopCloseDialogRemember => 'Don\'t ask again';

  @override
  String desktopHotkeyErrorInvalid(String binding) {
    return '“$binding” isn\'t a valid shortcut.';
  }

  @override
  String desktopHotkeyErrorNeedsModifier(String binding) {
    return '“$binding” needs Ctrl, Alt, Shift or Super, otherwise it would block normal typing in every app.';
  }

  @override
  String desktopHotkeyErrorDuplicate(String binding) {
    return '“$binding” is already used by another global shortcut.';
  }

  @override
  String desktopHotkeyErrorFailed(String binding) {
    return 'Couldn\'t register “$binding”. Another app may already be using it.';
  }

  @override
  String get desktopHotkeysUnsupportedWayland =>
      'Global shortcuts don\'t work in Wayland sessions. Use your desktop\'s keyboard settings instead: media keys and commands like “playerctl play-pause” control Fermata through MPRIS.';

  @override
  String get desktopHotkeysUnsupportedPlatform =>
      'Global shortcuts aren\'t available on this platform.';

  @override
  String get desktopUnknownArtist => 'Unknown artist';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerNext => 'Next';

  @override
  String get playerPrevious => 'Previous';

  @override
  String get playerShuffleOn => 'Shuffle is on';

  @override
  String get playerShuffleOff => 'Shuffle is off';

  @override
  String get playerRepeatOff => 'Repeat is off';

  @override
  String get playerRepeatAll => 'Repeating all';

  @override
  String get playerRepeatOne => 'Repeating one track';

  @override
  String get playerLike => 'Like';

  @override
  String get playerUnlike => 'Remove from Liked songs';

  @override
  String get playerLyrics => 'Lyrics';

  @override
  String get playerQueue => 'Queue';

  @override
  String get playerArtwork => 'Artwork';

  @override
  String get playerOutputDevice => 'Output device';

  @override
  String get playerSystemDefault => 'System default';

  @override
  String get playerNoDevices => 'No other output devices found';

  @override
  String get playerVolume => 'Volume';

  @override
  String get playerMute => 'Mute';

  @override
  String get playerUnmute => 'Unmute';

  @override
  String get playerSpeed => 'Playback speed';

  @override
  String playerSpeedValue(String speed) {
    return '$speed×';
  }

  @override
  String get playerSleepTimer => 'Sleep timer';

  @override
  String get playerSleepOff => 'Off';

  @override
  String playerSleepMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get playerSleepEndOfTrack => 'End of track';

  @override
  String playerSleepRemaining(String time) {
    return 'Pauses in $time';
  }

  @override
  String get playerSleepAtEndOfTrack => 'Pauses after this track';

  @override
  String get playerMiniPlayer => 'Mini player';

  @override
  String get playerExitMiniPlayer => 'Back to full window';

  @override
  String get playerAlwaysOnTop => 'Keep on top';

  @override
  String get playerNothingPlaying => 'Nothing playing';

  @override
  String get playerNothingPlayingHint =>
      'Pick an album, playlist or track to start listening.';

  @override
  String get playerSeek => 'Playback position';

  @override
  String playerElapsed(String time) {
    return '$time elapsed';
  }

  @override
  String playerRemaining(String time) {
    return '$time remaining';
  }

  @override
  String get playerOpenNowPlaying => 'Open now playing';

  @override
  String get playerCloseNowPlaying => 'Close now playing';

  @override
  String playerPlayingFrom(String origin) {
    return 'Playing from $origin';
  }

  @override
  String get playerAddToPlaylist => 'Add to playlist';

  @override
  String get playerDownload => 'Download';

  @override
  String get playerDownloaded => 'Downloaded';

  @override
  String playerOpenOn(String provider) {
    return 'Open on $provider';
  }

  @override
  String playerUploaderOn(String provider) {
    return 'Uploader on $provider';
  }

  @override
  String get playerCopyLink => 'Copy link';

  @override
  String get playerMore => 'More';

  @override
  String get playerChipPreview => 'Preview';

  @override
  String get playerChipYourFile => 'Your file';

  @override
  String get playerChipDownloaded => 'Downloaded';

  @override
  String playerPreviewFrom(int seconds, String provider) {
    return '$seconds-second preview · $provider';
  }

  @override
  String get playerUnplayable => 'Can\'t play this track';

  @override
  String get playerSkippedUnplayable => 'Skipped a track that can\'t be played';

  @override
  String get playerShowArtwork => 'Show artwork';

  @override
  String get playerShowLyrics => 'Show lyrics';

  @override
  String get playerShowQueue => 'Show queue';

  @override
  String playerLyricsAttribution(String provider) {
    return 'Lyrics: $provider';
  }

  @override
  String get playerLyricsNotFound => 'No lyrics found for this track.';

  @override
  String get playerLyricsInstrumental => 'Instrumental';

  @override
  String get playerLyricsDisabled => 'Lyrics are turned off in Settings.';

  @override
  String get playerLyricsError => 'Couldn\'t load lyrics.';

  @override
  String get playerLyricsSeekTo => 'Jump to this line';

  @override
  String get playerQueueNowPlaying => 'Now playing';

  @override
  String get playerQueueUpNext => 'Up next';

  @override
  String get playerQueueHistory => 'Played earlier';

  @override
  String get playerQueueEmpty => 'Your queue is empty';

  @override
  String get playerQueueEmptyHint =>
      'Play an album, playlist or track and it shows up here.';

  @override
  String get playerQueueClear => 'Clear queue';

  @override
  String get playerQueueClearTitle => 'Clear the queue?';

  @override
  String get playerQueueClearMessage =>
      'All upcoming tracks are removed. The current track keeps playing.';

  @override
  String get playerQueueRemove => 'Remove from queue';

  @override
  String get playerQueuePlayNext => 'Play next';

  @override
  String get playerQueueSuggested => 'Suggested';

  @override
  String get playerQueueRemoved => 'Removed from queue';

  @override
  String get playerQueueReorder => 'Drag to reorder';

  @override
  String playerQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
      zero: 'No tracks',
    );
    return '$_temp0';
  }

  @override
  String get playerOriginSearch => 'Search';

  @override
  String get playerOriginSmartQueue => 'Suggestions';

  @override
  String get playerOriginLibrary => 'Your library';

  @override
  String get playerOriginFavorites => 'Liked songs';

  @override
  String get playerSiloTitle => 'Start a new queue?';

  @override
  String get playerSiloMessage =>
      'SoundCloud tracks play in their own queue (SoundCloud\'s terms). Start a new queue?';

  @override
  String get playerSiloConfirm => 'Start new queue';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navExplore => 'Explore';

  @override
  String get navLibrary => 'Library';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navFavorites => 'Liked songs';

  @override
  String get navHistory => 'History';

  @override
  String get navQueue => 'Queue';

  @override
  String get navSettings => 'Settings';

  @override
  String get navNowPlaying => 'Now playing';

  @override
  String get navImport => 'Import a playlist';

  @override
  String get shellYourPlaylists => 'Your playlists';

  @override
  String get shellNoPlaylists => 'No playlists yet';

  @override
  String get shellPageNotFound => 'This page doesn\'t exist.';

  @override
  String get shellGoHome => 'Go to Home';

  @override
  String get shellCommandPalette => 'Command palette';

  @override
  String get shellLoading => 'Loading';

  @override
  String get paletteHint => 'Search commands, playlists and tracks';

  @override
  String get paletteNoResults => 'No matches';

  @override
  String get paletteGroupNavigation => 'Go to';

  @override
  String get paletteGroupPlayer => 'Player';

  @override
  String get paletteGroupSettings => 'Settings';

  @override
  String get paletteGroupPlaylists => 'Playlists';

  @override
  String get paletteGroupTracks => 'In your library';

  @override
  String get paletteFooter =>
      'Up and down to move · Enter to run · Esc to close';

  @override
  String get cmdPlayPause => 'Play or pause';

  @override
  String get cmdNext => 'Next track';

  @override
  String get cmdPrevious => 'Previous track';

  @override
  String get cmdSeekForward => 'Skip forward 10 seconds';

  @override
  String get cmdSeekBackward => 'Skip back 10 seconds';

  @override
  String get cmdVolumeUp => 'Volume up';

  @override
  String get cmdVolumeDown => 'Volume down';

  @override
  String get cmdToggleShuffle => 'Shuffle on or off';

  @override
  String get cmdCycleRepeat => 'Change repeat mode';

  @override
  String get cmdLike => 'Like the current track';

  @override
  String get cmdSearch => 'Search';

  @override
  String get cmdCommandPalette => 'Open the command palette';

  @override
  String get cmdNowPlaying => 'Show now playing';

  @override
  String get cmdQueue => 'Show the queue';

  @override
  String get cmdSettings => 'Open settings';

  @override
  String get cmdGlobalPlayPause => 'Play or pause (system-wide)';

  @override
  String get cmdGlobalNext => 'Next track (system-wide)';

  @override
  String get cmdGlobalPrevious => 'Previous track (system-wide)';

  @override
  String get cmdGlobalShowWindow => 'Show Fermata (system-wide)';

  @override
  String get cmdMiniPlayer => 'Mini player on or off';

  @override
  String get cmdClearQueue => 'Clear the queue';

  @override
  String get cmdStop => 'Stop playback';

  @override
  String get shellSectionAppearance => 'Appearance & theme';

  @override
  String get shellSectionGlass => 'Liquid Glass';

  @override
  String get shellSectionPlayback => 'Playback';

  @override
  String get shellSectionAudioQuality => 'Audio quality';

  @override
  String get shellSectionDownloads => 'Downloads';

  @override
  String get shellSectionStorage => 'Storage & cache';

  @override
  String get shellSectionPerformance => 'Performance';

  @override
  String get shellSectionSavers => 'Battery & data saver';

  @override
  String get shellSectionServices => 'Connected services';

  @override
  String get shellSectionImport => 'Playlist import & matching';

  @override
  String get shellSectionNotifications => 'Notifications';

  @override
  String get shellSectionBackground => 'Background playback';

  @override
  String get shellSectionDesktop => 'System tray & window';

  @override
  String get shellSectionStartup => 'Startup';

  @override
  String get shellSectionShortcuts => 'Keyboard shortcuts';

  @override
  String get shellSectionPrivacy => 'Privacy';

  @override
  String get shellSectionLanguage => 'Language';

  @override
  String get shellSectionAccessibility => 'Accessibility';

  @override
  String get shellSectionUpdates => 'Updates';

  @override
  String get shellSectionAbout => 'About & diagnostics';

  @override
  String get shellErrorStorage =>
      'There isn\'t enough space, or the folder can\'t be written to.';

  @override
  String get shellErrorDownloadNotPermitted =>
      'This track can\'t be downloaded.';

  @override
  String get shellAddedToQueue => 'Added to queue';

  @override
  String get shellPlayingNext => 'Plays next';

  @override
  String shellAddedToPlaylist(String playlist) {
    return 'Added to $playlist';
  }

  @override
  String shellTracksAddedToPlaylist(int count, String playlist) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks added to $playlist',
      one: '1 track added to $playlist',
    );
    return '$_temp0';
  }

  @override
  String get shellLiked => 'Added to Liked songs';

  @override
  String get shellUnliked => 'Removed from Liked songs';

  @override
  String get shellDownloadQueued => 'Download added';

  @override
  String shellDownloadsQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads added',
      one: '1 download added',
    );
    return '$_temp0';
  }

  @override
  String shellDownloadsRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks can\'t be downloaded',
      one: '1 track can\'t be downloaded',
    );
    return '$_temp0';
  }

  @override
  String get shellDownloadRemoved => 'Download removed';

  @override
  String get shellLinkCopied => 'Link copied';

  @override
  String get shellCouldNotOpenLink => 'Couldn\'t open the link.';

  @override
  String get shellNewPlaylist => 'New playlist';

  @override
  String get shellPlaylistNameHint => 'Playlist name';

  @override
  String get shellCreate => 'Create';

  @override
  String get shellAdd => 'Add';

  @override
  String get shellAddToPlaylistTitle => 'Add to playlist';

  @override
  String get shellAddToPlaylistEmpty =>
      'Create your first playlist to add tracks to it.';

  @override
  String shellTypeToConfirm(String word) {
    return 'Type $word to confirm';
  }

  @override
  String shellSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get shellSelectAll => 'Select all';

  @override
  String get shellClearSelection => 'Clear selection';

  @override
  String get shellSelect => 'Select';

  @override
  String get shellScrollLeft => 'Scroll left';

  @override
  String get shellScrollRight => 'Scroll right';

  @override
  String get shellSeeAll => 'See all';

  @override
  String get shellSearchHint => 'Search';

  @override
  String get shellClearSearch => 'Clear search';

  @override
  String get shellBadgePreview => 'Preview';

  @override
  String shellBadgeExternal(String provider) {
    return 'Plays on $provider';
  }

  @override
  String get shellBadgeDownloaded => 'Downloaded';

  @override
  String get shellBadgeUnavailable => 'Unavailable';

  @override
  String get shellBadgeExplicit => 'Explicit';

  @override
  String get shellMenuPlay => 'Play';

  @override
  String get shellMenuPlayNext => 'Play next';

  @override
  String get shellMenuAddToQueue => 'Add to queue';

  @override
  String get shellMenuAddToPlaylist => 'Add to playlist';

  @override
  String get shellMenuLike => 'Like';

  @override
  String get shellMenuUnlike => 'Remove from Liked songs';

  @override
  String get shellMenuDownload => 'Download';

  @override
  String get shellMenuRemoveDownload => 'Remove download';

  @override
  String get shellMenuGoToArtist => 'Go to artist';

  @override
  String get shellMenuGoToAlbum => 'Go to album';

  @override
  String shellMenuOpenOn(String provider) {
    return 'Open on $provider';
  }

  @override
  String get shellMenuCopyLink => 'Copy link';

  @override
  String get shellMoreOptions => 'More options';

  @override
  String get shellNowPlayingIndicator => 'Now playing';

  @override
  String get shellGlassPreviewTitle => 'Track title';

  @override
  String get shellGlassPreviewArtist => 'Artist';

  @override
  String get shellGlassModeSolid => 'Solid surfaces';

  @override
  String get shellGlassModeTranslucent => 'Translucent, no blur';

  @override
  String get shellGlassModeBlurred => 'Translucent with blur';

  @override
  String get shellFileYourFile => 'Local file';

  @override
  String get shellCloseTitle => 'Close Fermata?';

  @override
  String get shellCloseMessage =>
      'Fermata can keep playing in the system tray, or quit completely.';

  @override
  String get shellCloseMinimize => 'Keep playing in tray';

  @override
  String get shellCloseQuit => 'Quit';

  @override
  String get shellCloseRemember => 'Remember my choice';
}
