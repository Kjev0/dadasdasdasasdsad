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
  String get reasonSiloed =>
      'SoundCloud tracks play in their own queue (SoundCloud\'s terms).';

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
  String get importTitle => 'Import a playlist';

  @override
  String get importBack => 'Back';

  @override
  String get importStepSource => 'Source';

  @override
  String get importStepPlaylist => 'Playlist';

  @override
  String get importStepOptions => 'Matching';

  @override
  String importStepOf(int step, int total, String name) {
    return 'Step $step of $total: $name';
  }

  @override
  String get importChooseSource => 'Where is the playlist?';

  @override
  String get importChooseSourceHint =>
      'Fermata finds each track on the services you choose next and keeps a link to the original.';

  @override
  String get importM3uTitle => 'A playlist file (M3U)';

  @override
  String get importM3uHint =>
      'Tracks from an .m3u or .m3u8 file on this device.';

  @override
  String get importM3uUnreadable => 'This playlist file can\'t be read.';

  @override
  String get importM3uEmpty => 'No tracks were found in this playlist file.';

  @override
  String importSourceNotSetUp(String service) {
    return '$service isn\'t set up yet.';
  }

  @override
  String get importSourceLinkOnly =>
      'Public playlists by link. Connect to see your own playlists.';

  @override
  String get importSourceConnectFirst => 'Connect your account to import.';

  @override
  String importSourceSignedIn(String name) {
    return 'Signed in as $name';
  }

  @override
  String get importSetUp => 'Set up';

  @override
  String importChooseWhat(String service) {
    return 'What do you want to import from $service?';
  }

  @override
  String get importPasteLink => 'Paste a playlist link';

  @override
  String importPasteLinkHint(String service) {
    return 'A $service playlist link or ID';
  }

  @override
  String get importContinue => 'Continue';

  @override
  String get importLikedTracks => 'Liked tracks';

  @override
  String importLikedTracksHint(String service) {
    return 'Every track you liked on $service.';
  }

  @override
  String importLikedName(String service) {
    return 'Liked on $service';
  }

  @override
  String get importYourPlaylists => 'Your playlists';

  @override
  String get importNoPlaylists => 'You have no playlists there yet.';

  @override
  String importTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String importConnectForLibrary(String service) {
    return 'Connect your $service account in Settings to import your own playlists and liked tracks.';
  }

  @override
  String get importOptionsTitle => 'Where should Fermata look?';

  @override
  String importSummaryPlaylist(String name, String service) {
    return '“$name” from $service';
  }

  @override
  String importSummaryLink(String service) {
    return 'A playlist link from $service';
  }

  @override
  String importSummaryLiked(String service) {
    return 'Your liked tracks on $service';
  }

  @override
  String importSummaryM3u(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '“$name” ($_temp0)';
  }

  @override
  String get importTargets => 'Find matches on';

  @override
  String get importTargetsHint =>
      'In this order. The first service with a good match is used for playback.';

  @override
  String get importNoTargets =>
      'None of your services can play the matches. Connect a service such as SoundCloud or Audius first.';

  @override
  String get importTargetNotReady => 'Not connected or not set up';

  @override
  String get importMatchingGroup => 'Matching';

  @override
  String get importStart => 'Start import';

  @override
  String importFetchingLiked(int count) {
    return 'Fetched $count liked tracks…';
  }

  @override
  String get importNothingToImport => 'There are no tracks to import.';

  @override
  String get importStartFailed => 'The import couldn\'t be started.';

  @override
  String get importReviewTitle => 'Review matches';

  @override
  String get importReviewHint =>
      'Check the matches Fermata wasn\'t sure about. Nothing is saved until you press Save.';

  @override
  String get importUntitled => 'Imported playlist';

  @override
  String get importImporting => 'Importing…';

  @override
  String get importPhaseFetching => 'Fetching the playlist…';

  @override
  String get importPhaseMatchingStart => 'Finding matches…';

  @override
  String importPhaseMatching(int processed, int total) {
    return 'Matched $processed of $total tracks';
  }

  @override
  String get importPhaseSaving => 'Saving…';

  @override
  String get importCancelImport => 'Cancel import';

  @override
  String get importCancelTitle => 'Cancel this import?';

  @override
  String get importCancelBody =>
      'Your review choices are discarded. Nothing has been saved yet.';

  @override
  String get importCanceled => 'The import was canceled.';

  @override
  String get importFailed => 'The import failed';

  @override
  String get importStartNew => 'Start a new import';

  @override
  String get importSessionMissing => 'This import isn\'t available anymore';

  @override
  String get importSessionMissingHint =>
      'Imports in progress are kept until Fermata closes.';

  @override
  String importFilterAll(int count) {
    return 'All · $count';
  }

  @override
  String get importFilterEmpty => 'No tracks with this status.';

  @override
  String get importDecisionAuto => 'Auto-accepted';

  @override
  String get importDecisionAccepted => 'Accepted';

  @override
  String get importDecisionReview => 'Needs review';

  @override
  String get importDecisionNotFound => 'Not found';

  @override
  String get importDecisionRejected => 'Rejected';

  @override
  String get importDecisionSkipped => 'Skipped';

  @override
  String importAcceptAllHigh(int count) {
    return 'Accept all high-confidence ($count)';
  }

  @override
  String get importSavePlaylist => 'Save playlist';

  @override
  String get importSaveTitle => 'Name the playlist';

  @override
  String get importSavePendingTitle => 'Some tracks still need review';

  @override
  String importSavePendingBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count tracks haven\'t been reviewed. They will be saved without a match.',
      one: '1 track hasn\'t been reviewed. It will be saved without a match.',
    );
    return '$_temp0';
  }

  @override
  String get importSaveAnyway => 'Save anyway';

  @override
  String get importSaved => 'Playlist saved';

  @override
  String get importSaveFailed => 'The playlist couldn\'t be saved.';

  @override
  String get importDoneTitle => 'Playlist saved';

  @override
  String get importDoneAll => 'Every track has a match.';

  @override
  String importDoneMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks have no match.',
      one: '1 track has no match.',
    );
    return '$_temp0';
  }

  @override
  String get importOpenPlaylist => 'Open playlist';

  @override
  String get importShowMissing => 'Show missing tracks';

  @override
  String importMissingTitle(int count) {
    return 'Tracks without a match ($count)';
  }

  @override
  String importReportHeader(String name, int count) {
    return 'Tracks without a match in “$name” ($count):';
  }

  @override
  String get importOriginal => 'Original';

  @override
  String get importMatch => 'Match';

  @override
  String get importNoMatch => 'No match found';

  @override
  String get importOnlyOtherVersions =>
      'Only other versions found — choose one yourself if it\'s right.';

  @override
  String get importAccept => 'Accept';

  @override
  String get importReject => 'Reject';

  @override
  String get importSkip => 'Skip';

  @override
  String importOtherCandidates(int count) {
    return 'Candidates ($count)';
  }

  @override
  String importCandidatesTitle(String title) {
    return 'Candidates for “$title”';
  }

  @override
  String get importUseThis => 'Use this';

  @override
  String get importDifferentVersionWarning =>
      'This is a different version than the original.';

  @override
  String get importSearch => 'Search';

  @override
  String importSearchFor(String title) {
    return 'Search for “$title”';
  }

  @override
  String get importSearchNoResults => 'Nothing found. Try other words.';

  @override
  String get importSearchResults => 'Results';

  @override
  String get importMatchedByIsrc => 'Same ISRC';

  @override
  String importConfidenceSemantics(String level, int percent) {
    return 'Confidence $level, $percent percent';
  }

  @override
  String get importConfidenceExact => 'Exact';

  @override
  String get importConfidenceHigh => 'High';

  @override
  String get importConfidenceMedium => 'Medium';

  @override
  String get importConfidenceLow => 'Low';

  @override
  String get importConfidenceNone => 'None';

  @override
  String get importDiffRemix => 'Remix';

  @override
  String get importDiffLive => 'Live';

  @override
  String get importDiffAcoustic => 'Acoustic';

  @override
  String get importDiffExtended => 'Extended';

  @override
  String get importDiffRadioEdit => 'Radio edit';

  @override
  String get importDiffInstrumental => 'Instrumental';

  @override
  String get importDiffKaraoke => 'Karaoke';

  @override
  String get importDiffCover => 'Cover';

  @override
  String get importDiffRemaster => 'Remaster';

  @override
  String get importDiffSped => 'Sped up';

  @override
  String get importDiffSlowed => 'Slowed';

  @override
  String get importDiffDemo => 'Demo';

  @override
  String get importDiffExplicit => 'Explicit mismatch';

  @override
  String get importDiffDuration => 'Different length';

  @override
  String get importDiffAlbum => 'Different album';

  @override
  String get importDiffYear => 'Different year';

  @override
  String get importDiffArtist => 'Different artist';

  @override
  String get importDiffFeatured => 'Different featured artists';

  @override
  String get importDiffTitle => 'Different title';

  @override
  String get importDiffPreview => 'Preview only';

  @override
  String importOpenOn(String service) {
    return 'Open on $service';
  }

  @override
  String get importOpenUploader => 'Uploader';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get onboardingFinish => 'Start listening';

  @override
  String onboardingStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get onboardingWelcomeTitle => 'Welcome to Fermata';

  @override
  String get onboardingWelcomeBody =>
      'A calm music player for the music you own and the services you already use.';

  @override
  String get onboardingPointFiles =>
      'Your own files come first and always work offline.';

  @override
  String get onboardingPointServices =>
      'Search SoundCloud, Audius and more in one place, and bring your playlists with you.';

  @override
  String get onboardingPointBackground =>
      'Keeps playing in the background, with your media keys and lock screen.';

  @override
  String get onboardingPointPrivacy =>
      'No ads, no tracking. Recommendations are calculated on your device.';

  @override
  String get onboardingMusicTitle => 'Add your music';

  @override
  String get onboardingMusicBody =>
      'Choose the folders where your music files are. Fermata reads them in the background and keeps watching for new files.';

  @override
  String get onboardingAudioPermissionRationale =>
      'To play the music stored on your phone, Fermata needs permission to read your audio files. It only reads music — never photos, messages or other files.';

  @override
  String get onboardingAllowAudio => 'Allow access to music';

  @override
  String get onboardingAudioDenied =>
      'Without this permission Fermata can\'t see your music files. You can allow it later in the system settings.';

  @override
  String get onboardingSuggestedFolder => 'Your Music folder';

  @override
  String get onboardingAdd => 'Add';

  @override
  String get onboardingChooseFolder => 'Choose a folder…';

  @override
  String get onboardingFolderMissing => 'That folder doesn\'t exist anymore.';

  @override
  String get onboardingScanning =>
      'Fermata is reading your music in the background.';

  @override
  String get onboardingMusicLater =>
      'You can add or remove folders any time in Library.';

  @override
  String get onboardingServicesTitle => 'Connect your services';

  @override
  String get onboardingServicesBody =>
      'Optional. Connect an account to search it, stream it and import your playlists. You sign in on the service\'s own website — Fermata never sees your password.';

  @override
  String get onboardingRecommended => 'Recommended';

  @override
  String get onboardingServiceHint => 'Sign in to use your account.';

  @override
  String get onboardingNeedsCredentials =>
      'Needs developer credentials first — you can set this up later in Settings.';

  @override
  String onboardingConnectedAs(String name) {
    return 'Connected as $name';
  }

  @override
  String onboardingNoAccountNeeded(String services) {
    return 'No account needed for: $services.';
  }

  @override
  String get onboardingServicesLater =>
      'You can connect or disconnect services any time in Settings → Connected services.';

  @override
  String get onboardingBackgroundTitle => 'Music that keeps playing';

  @override
  String get onboardingBackgroundAndroid =>
      'Fermata keeps playing when you switch apps or lock your phone. A notification shows the playback controls.';

  @override
  String get onboardingNotificationRationale =>
      'Android asks before apps may show notifications. Fermata uses them for the playback controls and for finished downloads — never for advertising.';

  @override
  String get onboardingAllowNotifications => 'Allow notifications';

  @override
  String get onboardingNotificationsAllowed => 'Notifications are allowed.';

  @override
  String get onboardingBatteryNote =>
      'If music stops in the background on your phone, see Settings → Background playback.';

  @override
  String get onboardingBackgroundTray =>
      'Closing the window doesn\'t stop the music: Fermata stays in the system tray. Quit from the tray menu when you\'re done.';

  @override
  String get onboardingBackgroundNoTray =>
      'Closing the window doesn\'t stop the music. Your desktop has no system tray, so Fermata minimizes instead.';

  @override
  String get onboardingMediaKeys =>
      'Media keys and your desktop\'s media controls work while Fermata is in the background.';

  @override
  String get pagesPlay => 'Play';

  @override
  String get pagesShuffle => 'Shuffle';

  @override
  String pagesHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String pagesMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String pagesTrackCount(int count) {
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
  String get pagesToday => 'Today';

  @override
  String get pagesYesterday => 'Yesterday';

  @override
  String get pagesDownloadEligible => 'Download';

  @override
  String get pagesOpenSettings => 'Open settings';

  @override
  String get pagesImportAndMatch => 'Import & match';

  @override
  String get pagesMore => 'More';

  @override
  String get pagesSort => 'Sort';

  @override
  String get pagesFilter => 'Filter';

  @override
  String get pagesAscending => 'Ascending';

  @override
  String get pagesDescending => 'Descending';

  @override
  String get pagesClearFilters => 'Clear filters';

  @override
  String get pagesNoMatches => 'Nothing matches these filters.';

  @override
  String get pagesLoadMore => 'Load more';

  @override
  String get pagesRemove => 'Remove';

  @override
  String get pagesRename => 'Rename';

  @override
  String pagesOpenOnProvider(String provider) {
    return 'Open on $provider';
  }

  @override
  String pagesDataFrom(String provider) {
    return 'Data from $provider';
  }

  @override
  String get shelfContinueListening => 'Continue listening';

  @override
  String shelfDailyMix(int number) {
    return 'Daily Mix $number';
  }

  @override
  String get shelfDiscoverWeekly => 'Discover Weekly';

  @override
  String shelfBecauseYouLiked(String artist) {
    return 'Because you like $artist';
  }

  @override
  String get shelfTrending => 'Trending';

  @override
  String get shelfNewReleases => 'New releases';

  @override
  String get shelfRecentlyAdded => 'Recently added';

  @override
  String get moodFocus => 'Focus';

  @override
  String get moodChill => 'Chill';

  @override
  String get moodWorkout => 'Workout';

  @override
  String get moodParty => 'Party';

  @override
  String get moodSleep => 'Sleep';

  @override
  String get moodCommute => 'On the road';

  @override
  String get moodHappy => 'Feel good';

  @override
  String get moodMelancholy => 'Melancholy';

  @override
  String get homeGoodMorning => 'Good morning';

  @override
  String get homeGoodAfternoon => 'Good afternoon';

  @override
  String get homeGoodEvening => 'Good evening';

  @override
  String get homeGoodNight => 'Good night';

  @override
  String get homeSubtitle =>
      'Picked from what you play — worked out on this device.';

  @override
  String get homeMix => 'Mix';

  @override
  String get homeShelf => 'Collection';

  @override
  String get homeMadeForYou => 'Made for you';

  @override
  String get homeFirstRunTitle => 'Let\'s bring in your music';

  @override
  String get homeFirstRunMessage =>
      'Fermata plays your own files and the services you connect. Start with one of these.';

  @override
  String get homeAddFolderTitle => 'Add a music folder';

  @override
  String get homeAddFolderBody =>
      'Your files stay where they are and play offline.';

  @override
  String get homeConnectTitle => 'Connect a service';

  @override
  String get homeConnectBody => 'SoundCloud, Audius, Jamendo and more.';

  @override
  String get homeConnectAction => 'Connected services';

  @override
  String get homeExploreTitle => 'Explore';

  @override
  String get homeExploreBody => 'Browse moods, genres and what is trending.';

  @override
  String get homeExploreAction => 'Start exploring';

  @override
  String get searchHint => 'Songs, artists, albums or a share link';

  @override
  String get searchFilterAll => 'All';

  @override
  String get searchEmptyTitle => 'Search everything at once';

  @override
  String get searchEmptyMessage =>
      'Your library and every connected service. Paste a playlist link to open or import it.';

  @override
  String get searchBrowseExplore => 'Browse Explore';

  @override
  String get searchHistoryOff =>
      'Search history is turned off, so searches are not saved.';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get searchClearRecent => 'Clear';

  @override
  String searchRemoveRecent(String query) {
    return 'Remove \"$query\"';
  }

  @override
  String searchFor(String query) {
    return 'Search for \"$query\"';
  }

  @override
  String get searchInYourLibrary => 'In your library';

  @override
  String get searchTopResult => 'Top result';

  @override
  String get searchTracks => 'Tracks';

  @override
  String get searchArtists => 'Artists';

  @override
  String get searchAlbums => 'Albums';

  @override
  String get searchPlaylists => 'Playlists';

  @override
  String searchShowAll(int count) {
    return 'Show all $count';
  }

  @override
  String searchNoResults(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get searchNoResultsHint => 'Check the spelling, or try fewer words.';

  @override
  String get searchConnectedServices => 'Connected services';

  @override
  String searchNotSearched(String sources) {
    return 'Not searched: $sources';
  }

  @override
  String searchSourceNotConnected(String service) {
    return '$service isn\'t connected.';
  }

  @override
  String get searchNeedsCredentials => 'needs setup';

  @override
  String get searchNotConnected => 'not connected';

  @override
  String get searchKindTrack => 'Track';

  @override
  String get searchKindArtist => 'Artist';

  @override
  String get searchKindAlbum => 'Album';

  @override
  String get searchKindPlaylist => 'Playlist';

  @override
  String searchLinkTrack(String provider) {
    return '$provider track link';
  }

  @override
  String searchLinkPlaylist(String provider) {
    return '$provider playlist link';
  }

  @override
  String searchLinkAlbum(String provider) {
    return '$provider album link';
  }

  @override
  String searchLinkArtist(String provider) {
    return '$provider artist link';
  }

  @override
  String searchLinkGeneric(String provider) {
    return '$provider link';
  }

  @override
  String get searchOpenPlaylist => 'Open playlist';

  @override
  String get searchOpenAlbum => 'Open album';

  @override
  String get searchOpenArtist => 'Open artist';

  @override
  String searchSourceMissing(String provider) {
    return '$provider isn\'t available in this version of Fermata.';
  }

  @override
  String get searchLinkNotFound =>
      'This track couldn\'t be found. It may have been removed or made private.';

  @override
  String get exploreSubtitle =>
      'Moods, genres and new music from your services.';

  @override
  String get exploreMoods => 'Moods';

  @override
  String get exploreGenres => 'Genres';

  @override
  String get exploreNoGenres =>
      'No genres yet. Add music or connect a service.';

  @override
  String get exploreGenre => 'Genre';

  @override
  String get exploreMood => 'Mood';

  @override
  String get exploreNothingFound =>
      'Nothing playable found right now. Try again later or connect another service.';

  @override
  String get libraryTabTracks => 'Tracks';

  @override
  String get libraryTabAlbums => 'Albums';

  @override
  String get libraryTabArtists => 'Artists';

  @override
  String get libraryTabFolders => 'Folders';

  @override
  String get libraryPermissionNeeded =>
      'Fermata needs access to your music to add a folder.';

  @override
  String get libraryOpenSystemSettings => 'Open settings';

  @override
  String get libraryAddFolder => 'Add folder';

  @override
  String libraryFolderAdded(String folder) {
    return 'Added $folder — scanning now';
  }

  @override
  String get libraryLocalFiles => 'Local files';

  @override
  String get libraryEmptyTitle => 'Your library is empty';

  @override
  String get libraryEmptyMessage =>
      'Add a music folder or import a file. Tracks you like or play from services show up here too.';

  @override
  String get libraryImportFile => 'Import a file';

  @override
  String get libraryImportFileFailed =>
      'This file can\'t be added. Fermata reads MP3, FLAC, M4A, Ogg, Opus, WAV and AIFF.';

  @override
  String libraryImportFileDone(String title) {
    return 'Added \"$title\"';
  }

  @override
  String get libraryFilterHint => 'Filter your library';

  @override
  String get libraryQuickDownloaded => 'Downloaded';

  @override
  String librarySortedBy(String field) {
    return 'Sorted by $field';
  }

  @override
  String get librarySortTitle => 'Title';

  @override
  String get librarySortArtist => 'Artist';

  @override
  String get librarySortAlbum => 'Album';

  @override
  String get librarySortYear => 'Year';

  @override
  String get librarySortDuration => 'Duration';

  @override
  String get librarySortDateAdded => 'Date added';

  @override
  String get librarySortPlayCount => 'Most played';

  @override
  String get librarySortLastPlayed => 'Last played';

  @override
  String get librarySortGenre => 'Genre';

  @override
  String get libraryFilterAvailability => 'Availability';

  @override
  String get libraryFilterDownloaded => 'Downloaded';

  @override
  String get libraryFilterLocal => 'Local files only';

  @override
  String get libraryFilterOffline => 'Available offline';

  @override
  String get libraryFilterFavorites => 'Liked songs';

  @override
  String get libraryFilterSource => 'Source';

  @override
  String get libraryFilterGenre => 'Genre';

  @override
  String get libraryAnyGenre => 'Any genre';

  @override
  String get libraryFilterYear => 'Year';

  @override
  String get libraryFrom => 'From';

  @override
  String get libraryTo => 'To';

  @override
  String get libraryFilterDuration => 'Duration (minutes)';

  @override
  String get libraryMinMinutes => 'At least';

  @override
  String get libraryMaxMinutes => 'At most';

  @override
  String get libraryFilterAlbums => 'Filter albums';

  @override
  String get libraryNoAlbums => 'No albums yet';

  @override
  String get libraryFilterArtists => 'Filter artists';

  @override
  String get libraryNoArtists => 'No artists yet';

  @override
  String get libraryFolders => 'Music folders';

  @override
  String get libraryFoldersHintDesktop =>
      'Watched folders are rescanned automatically when files change.';

  @override
  String get libraryFoldersHintAndroid =>
      'Folders are rescanned each time Fermata starts.';

  @override
  String get libraryNoFolders => 'No music folders yet';

  @override
  String get libraryNoFoldersMessage =>
      'Add the folders where you keep music. Files are never moved or uploaded.';

  @override
  String get libraryRescanAll => 'Rescan';

  @override
  String get libraryFullRescan => 'Full rescan';

  @override
  String get libraryRescanFolder => 'Rescan folder';

  @override
  String get libraryRemoveFolder => 'Remove folder';

  @override
  String get libraryRemoveFolderTitle => 'Remove this folder?';

  @override
  String libraryRemoveFolderMessage(String path) {
    return 'Tracks from $path leave your library. The files themselves aren\'t deleted.';
  }

  @override
  String get libraryWatchFolder => 'Watch for changes';

  @override
  String get libraryNeverScanned => 'Not scanned yet';

  @override
  String libraryScannedOn(String date) {
    return 'Scanned $date';
  }

  @override
  String get libraryScanEnumerating => 'Looking for music…';

  @override
  String libraryScanProgress(int scanned, int total) {
    return 'Scanning $scanned of $total files';
  }

  @override
  String get libraryScanDone => 'Scan complete';

  @override
  String get libraryScanFailed => 'The scan stopped';

  @override
  String libraryScanCounts(int added, int updated, int removed) {
    return '$added added · $updated updated · $removed removed';
  }

  @override
  String libraryScanErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files couldn\'t be read',
      one: '1 file couldn\'t be read',
    );
    return '$_temp0';
  }

  @override
  String get libraryTools => 'Tools';

  @override
  String get libraryMissingFiles => 'Missing files';

  @override
  String get libraryMissingFilesHint =>
      'Tracks whose file was moved or deleted outside Fermata. They come back if the file returns.';

  @override
  String get libraryNoMissingFiles => 'No missing files';

  @override
  String get libraryRemoveAllMissing => 'Remove all from library';

  @override
  String get libraryDuplicates => 'Duplicates';

  @override
  String get libraryDuplicatesHint =>
      'Tracks that look like copies of each other.';

  @override
  String get libraryNoDuplicates => 'No duplicates found';

  @override
  String get libraryDuplicateSameFile => 'Identical files';

  @override
  String get libraryDuplicateSameIsrc => 'Same recording (ISRC)';

  @override
  String get libraryDuplicateSameMetadata => 'Same title, artist and length';

  @override
  String get libraryRemoveFromLibrary => 'Remove from library';

  @override
  String libraryRemoveFromLibraryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count tracks from your library?',
      one: 'Remove 1 track from your library?',
    );
    return '$_temp0';
  }

  @override
  String get libraryRemoveFromLibraryMessage =>
      'Files on disk aren\'t deleted.';

  @override
  String libraryRemovedFromLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks removed',
      one: '1 track removed',
    );
    return '$_temp0';
  }

  @override
  String get libraryTrackDetails => 'Details';

  @override
  String get libraryDetailDuration => 'Length';

  @override
  String get libraryDetailFormat => 'Format';

  @override
  String get libraryDetailBitrate => 'Bitrate';

  @override
  String libraryKbps(int kbps) {
    return '$kbps kbps';
  }

  @override
  String get libraryDetailSampleRate => 'Sample rate';

  @override
  String libraryKhz(String khz) {
    return '$khz kHz';
  }

  @override
  String get libraryDetailBitDepth => 'Bit depth';

  @override
  String libraryBits(int bits) {
    return '$bits-bit';
  }

  @override
  String get libraryDetailChannels => 'Channels';

  @override
  String get libraryDetailSize => 'File size';

  @override
  String get libraryDetailReplayGain => 'ReplayGain';

  @override
  String get libraryDetailSource => 'Source';

  @override
  String get libraryDetailOffline => 'Offline';

  @override
  String get libraryDetailFile => 'File';

  @override
  String get libraryEditTags => 'Edit tags';

  @override
  String get libraryTagTitle => 'Title';

  @override
  String get libraryTagArtists => 'Artists';

  @override
  String get libraryTagArtistsHint => 'Separate several artists with ;';

  @override
  String get libraryTagAlbum => 'Album';

  @override
  String get libraryTagAlbumArtist => 'Album artist';

  @override
  String get libraryTagYear => 'Year';

  @override
  String get libraryTagGenre => 'Genre';

  @override
  String get libraryTagTrackNumber => 'Track no.';

  @override
  String get libraryTagDiscNumber => 'Disc no.';

  @override
  String get libraryTagsFileHint =>
      'Changes are written to the file when its format allows it; otherwise they\'re kept in your library only.';

  @override
  String get libraryTagsOverrideOnly =>
      'On this device the file isn\'t changed: your edits are saved in Fermata\'s library.';

  @override
  String get libraryTagsSavedToFile => 'Tags saved to the file';

  @override
  String get libraryTagsSavedAsOverride =>
      'Saved in your library (the file wasn\'t changed)';

  @override
  String get playlistsNewSmart => 'Smart playlist';

  @override
  String get playlistsImport => 'Import';

  @override
  String get playlistsImportFromService => 'Import from a service';

  @override
  String get playlistsImportM3u => 'Import M3U file';

  @override
  String get playlistsImportM3uEmpty =>
      'No playable files were found in that playlist file.';

  @override
  String playlistsImportedM3u(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count tracks into $name',
      one: 'Imported 1 track into $name',
    );
    return '$_temp0';
  }

  @override
  String playlistsCreated(String name) {
    return 'Created $name';
  }

  @override
  String get playlistsEmptyMessage =>
      'Make one from scratch, let a smart playlist fill itself, or bring one over from another service.';

  @override
  String get playlistsFilterYours => 'Yours';

  @override
  String get playlistsFilterSmart => 'Smart';

  @override
  String get playlistsFilterImported => 'Imported';

  @override
  String get playlistsShowList => 'Show as list';

  @override
  String get playlistsShowGrid => 'Show as grid';

  @override
  String get playlistKindLocal => 'Playlist';

  @override
  String get playlistKindSmart => 'Smart playlist';

  @override
  String playlistKindImported(String provider) {
    return 'Imported from $provider';
  }

  @override
  String playlistOnProvider(String provider) {
    return 'Playlist on $provider';
  }

  @override
  String playlistBy(String owner) {
    return 'by $owner';
  }

  @override
  String get playlistDescription => 'Description (optional)';

  @override
  String get playlistEditDetails => 'Edit details';

  @override
  String get playlistEditRules => 'Edit rules';

  @override
  String get playlistChangeArtwork => 'Change artwork';

  @override
  String get playlistArtworkUpdated => 'Artwork updated';

  @override
  String get playlistExportM3u => 'Export as M3U';

  @override
  String playlistExported(String location) {
    return 'Saved to $location';
  }

  @override
  String get playlistAutoDownload => 'Download automatically';

  @override
  String get playlistAutoDownloadOn => 'Auto-download on';

  @override
  String get playlistAutoDownloadTitle =>
      'Download this playlist automatically?';

  @override
  String get playlistAutoDownloadExplain =>
      'Fermata only downloads tracks automatically when they\'re your own files or the provider permits automatic downloads. None of the streaming services allow that today, so their tracks stay online — you can still download single Audius or Jamendo tracks yourself where the artist allows it.';

  @override
  String get playlistAutoDownloadConfirm => 'Turn on';

  @override
  String get playlistDedupe => 'Remove duplicates';

  @override
  String get playlistNoDuplicates => 'No duplicates found';

  @override
  String playlistDuplicatesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count duplicates',
      one: 'Removed 1 duplicate',
    );
    return '$_temp0';
  }

  @override
  String playlistDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get playlistDeleteMessage =>
      'The playlist is removed. Its tracks stay in your library.';

  @override
  String playlistDeleted(String name) {
    return 'Deleted $name';
  }

  @override
  String get playlistNotFound => 'This playlist doesn\'t exist anymore.';

  @override
  String get playlistEmpty => 'This playlist is empty';

  @override
  String get playlistEmptyHint =>
      'Add tracks from search, your library or any track menu.';

  @override
  String get playlistSmartEmpty => 'Nothing matches the rules yet';

  @override
  String get playlistSmartEmptyHint =>
      'Edit the rules, or play and like more music.';

  @override
  String playlistRulesSummary(int count, String match) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
    );
    return '$_temp0, $match';
  }

  @override
  String get playlistReorder => 'Reorder';

  @override
  String get playlistRemoveFromPlaylist => 'Remove from playlist';

  @override
  String playlistRemovedTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count tracks',
      one: 'Removed 1 track',
    );
    return '$_temp0';
  }

  @override
  String playlistPlaysVia(String provider) {
    return 'Plays via $provider — change';
  }

  @override
  String get playlistSaveToLibrary => 'Save to library';

  @override
  String playlistSavedToLibrary(String name) {
    return 'Saved $name to your library';
  }

  @override
  String get smartNewTitle => 'New smart playlist';

  @override
  String get smartEditTitle => 'Edit smart playlist';

  @override
  String get smartMatch => 'Include tracks that match';

  @override
  String get smartMatchAll => 'all rules';

  @override
  String get smartMatchAny => 'any rule';

  @override
  String get smartAddRule => 'Add rule';

  @override
  String get smartRemoveRule => 'Remove rule';

  @override
  String get smartValue => 'Value';

  @override
  String get smartPickSource => 'Choose a source';

  @override
  String get smartUnitMinutes => 'min';

  @override
  String get smartUnitDays => 'days';

  @override
  String get smartLimit => 'Limit';

  @override
  String get smartNoLimit => 'No limit';

  @override
  String get smartPreviewLoading => 'Counting matching tracks…';

  @override
  String smartPreviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks match',
      one: '1 track matches',
      zero: 'No tracks match',
    );
    return '$_temp0';
  }

  @override
  String smartPreviewApprox(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'About $count tracks match',
      one: 'About 1 track matches',
    );
    return '$_temp0';
  }

  @override
  String get smartFieldTitle => 'Title';

  @override
  String get smartFieldArtist => 'Artist';

  @override
  String get smartFieldAlbum => 'Album';

  @override
  String get smartFieldGenre => 'Genre';

  @override
  String get smartFieldYear => 'Year';

  @override
  String get smartFieldDuration => 'Length';

  @override
  String get smartFieldPlayCount => 'Play count';

  @override
  String get smartFieldLastPlayed => 'Last played';

  @override
  String get smartFieldDateAdded => 'Date added';

  @override
  String get smartFieldSource => 'Source';

  @override
  String get smartFieldFavorite => 'Liked';

  @override
  String get smartFieldDownloaded => 'Downloaded';

  @override
  String get smartOpContains => 'contains';

  @override
  String get smartOpNotContains => 'doesn\'t contain';

  @override
  String get smartOpEquals => 'is';

  @override
  String get smartOpNotEquals => 'isn\'t';

  @override
  String get smartOpStartsWith => 'starts with';

  @override
  String get smartOpGreaterThan => 'is more than';

  @override
  String get smartOpLessThan => 'is less than';

  @override
  String get smartOpInLastDays => 'in the last';

  @override
  String get smartOpNotInLastDays => 'not in the last';

  @override
  String get smartOpIsTrue => 'yes';

  @override
  String get smartOpIsFalse => 'no';

  @override
  String get alternativesFind => 'Find alternatives';

  @override
  String get alternativesTitle => 'Alternatives';

  @override
  String get alternativesLinkedNow => 'Linked now';

  @override
  String get alternativesSuggested => 'Suggested matches';

  @override
  String get alternativesSearch => 'Search yourself';

  @override
  String get alternativesSearchHint => 'Title and artist, then press Enter';

  @override
  String get alternativesNone => 'No matches found.';

  @override
  String get alternativesUse => 'Use';

  @override
  String get alternativesInUse => 'In use';

  @override
  String get alternativesUnlink => 'Unlink';

  @override
  String alternativesLinked(String provider) {
    return 'Linked — plays from $provider';
  }

  @override
  String alternativesScore(int percent, String confidence) {
    return '$percent% · $confidence';
  }

  @override
  String get matchExact => 'exact match';

  @override
  String get matchHigh => 'very likely';

  @override
  String get matchMedium => 'possible';

  @override
  String get matchLow => 'unlikely';

  @override
  String get matchNone => 'no match';

  @override
  String get diffRemix => 'remix';

  @override
  String get diffLive => 'live';

  @override
  String get diffAcoustic => 'acoustic';

  @override
  String get diffExtended => 'extended';

  @override
  String get diffRadioEdit => 'radio edit';

  @override
  String get diffInstrumental => 'instrumental';

  @override
  String get diffKaraoke => 'karaoke';

  @override
  String get diffCover => 'cover';

  @override
  String get diffRemaster => 'remaster';

  @override
  String get diffSped => 'sped up';

  @override
  String get diffSlowed => 'slowed';

  @override
  String get diffDemo => 'demo';

  @override
  String get diffExplicit => 'explicit differs';

  @override
  String get diffDuration => 'length differs';

  @override
  String get diffAlbum => 'other album';

  @override
  String get diffYear => 'other year';

  @override
  String get diffArtist => 'other artist';

  @override
  String get diffFeatured => 'featured artists differ';

  @override
  String get diffTitle => 'title differs';

  @override
  String get diffPreview => 'preview only';

  @override
  String get artistInLibrary => 'Artist in your library';

  @override
  String artistOnProvider(String provider) {
    return 'Artist on $provider';
  }

  @override
  String artistFollowers(String count) {
    return '$count followers';
  }

  @override
  String get artistTopTracks => 'Popular tracks';

  @override
  String get artistTracks => 'Tracks';

  @override
  String get artistNoTracks => 'No tracks found.';

  @override
  String get artistAlbums => 'Albums';

  @override
  String get artistReleases => 'Releases';

  @override
  String get artistRelated => 'Fans also like';

  @override
  String get albumInLibrary => 'Album in your library';

  @override
  String albumOnProvider(String provider) {
    return 'Album on $provider';
  }

  @override
  String albumDisc(int number) {
    return 'Disc $number';
  }

  @override
  String get albumEmpty => 'No tracks on this album.';

  @override
  String get downloadsPauseAll => 'Pause all';

  @override
  String get downloadsResumeAll => 'Resume all';

  @override
  String get downloadsPause => 'Pause';

  @override
  String get downloadsResume => 'Resume';

  @override
  String get downloadsProgress => 'Download progress';

  @override
  String get downloadsFilterActive => 'Active';

  @override
  String get downloadsFilterCompleted => 'Completed';

  @override
  String get downloadsFilterFailed => 'Failed';

  @override
  String get downloadsActive => 'Downloading';

  @override
  String downloadsActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in the queue',
      one: '1 in the queue',
    );
    return '$_temp0';
  }

  @override
  String get downloadsFinished => 'Finished';

  @override
  String get downloadsNothingHere => 'Nothing here right now.';

  @override
  String get downloadsEmptyTitle => 'No downloads yet';

  @override
  String get downloadsEmptyMessage =>
      'Tracks can be downloaded only where the provider allows it — Audius and Jamendo tracks the artist made downloadable. Your own files already play offline.';

  @override
  String get downloadsStatusQueued => 'Queued';

  @override
  String get downloadsStatusWaiting => 'Waiting';

  @override
  String get downloadsStatusDownloading => 'Downloading';

  @override
  String get downloadsStatusVerifying => 'Checking';

  @override
  String get downloadsStatusPaused => 'Paused';

  @override
  String get downloadsStatusCompleted => 'Downloaded';

  @override
  String get downloadsStatusFailed => 'Failed';

  @override
  String get downloadsStatusCanceled => 'Canceled';

  @override
  String downloadsSizeOf(String received, String total) {
    return '$received of $total';
  }

  @override
  String downloadsSpeed(String speed) {
    return '$speed/s';
  }

  @override
  String downloadsEta(String time) {
    return '$time left';
  }

  @override
  String downloadsAttempts(int count) {
    return '$count attempts';
  }

  @override
  String get downloadsWaitingWifiTitle => 'Waiting for Wi-Fi';

  @override
  String get downloadsWaitingWifi =>
      'Downloads only run on Wi-Fi. They continue by themselves when you connect.';

  @override
  String get downloadsDownloadSettings => 'Download settings';

  @override
  String get downloadsWaitingConnection =>
      'Waiting for an internet connection.';

  @override
  String get downloadsWaitingMobileData =>
      'You\'re on mobile data. Downloads wait until you allow it or connect to Wi-Fi.';

  @override
  String get downloadsMobileDataTitle => 'Download over mobile data?';

  @override
  String get downloadsMobileDataMessage =>
      'This can use a lot of data. You\'ll be asked again the next time you start Fermata.';

  @override
  String get downloadsMobileDataConfirm => 'Use mobile data';

  @override
  String get downloadsMobileDataWait => 'Wait for Wi-Fi';

  @override
  String get downloadsMobileDataAllowed => 'Downloading over mobile data';

  @override
  String get downloadsStorage => 'Storage';

  @override
  String get downloadsStorageSettings => 'Storage settings';

  @override
  String downloadsStorageDownloads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Downloads ($count tracks)',
      one: 'Downloads (1 track)',
    );
    return '$_temp0';
  }

  @override
  String get downloadsStorageArtwork => 'Artwork cache';

  @override
  String get downloadsStorageStreamCache => 'Stream cache';

  @override
  String get downloadsStorageDatabase => 'Library database';

  @override
  String get downloadsStorageLimit => 'Download limit';

  @override
  String get downloadsStorageFree => 'Free on this device';

  @override
  String get downloadsUnlimited => 'No limit';

  @override
  String get downloadsErrorSourceUnavailable =>
      'The service isn\'t available right now.';

  @override
  String get downloadsErrorAuth => 'Reconnect the service to download.';

  @override
  String get downloadsErrorNotFound => 'The file is gone from the service.';

  @override
  String get downloadsErrorForbidden => 'The service refused the download.';

  @override
  String get downloadsErrorServer =>
      'The service had a problem. Try again later.';

  @override
  String get downloadsErrorNotAudio =>
      'The service didn\'t send an audio file.';

  @override
  String get downloadsErrorCorrupt => 'The file arrived damaged. Try again.';

  @override
  String get downloadsErrorDiskFull => 'Not enough free space.';

  @override
  String get favoritesEmptyTitle => 'Songs you like show up here';

  @override
  String get favoritesEmptyMessage =>
      'Tap the heart on any track to keep it close.';

  @override
  String get favoritesFilterHint => 'Filter liked songs';

  @override
  String get favoritesSortRecent => 'Recently liked';

  @override
  String get historyRecent => 'Recently played';

  @override
  String get historyStats => 'Statistics';

  @override
  String get historyClear => 'Clear history';

  @override
  String get historyClearTitle => 'Clear your listening history?';

  @override
  String get historyClearMessage =>
      'Recently played and statistics are deleted from this device. Recommendations start over.';

  @override
  String get historyCleared => 'History cleared';

  @override
  String get historyRecordingOff =>
      'Listening history is turned off, so new plays aren\'t saved.';

  @override
  String get historyEmptyTitle => 'Nothing played yet';

  @override
  String get historyEmptyMessage =>
      'What you listen to shows up here, grouped by day.';

  @override
  String get historyStatsEmpty => 'Play some music to see your statistics.';

  @override
  String historyStatsPeriod(int days) {
    return 'Last $days days, calculated on this device';
  }

  @override
  String get historyStatsPlays => 'Plays';

  @override
  String get historyStatsTime => 'Listening time';

  @override
  String get historyStatsPerDay => 'Plays per day';

  @override
  String get historyStatsTopTracks => 'Top tracks';

  @override
  String get historyStatsTopArtists => 'Top artists';

  @override
  String get historyStatsTopGenres => 'Top genres';

  @override
  String historyPlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plays',
      one: '1 play',
    );
    return '$_temp0';
  }

  @override
  String historyChartLabel(int days, int total, int peak) {
    return 'Plays per day over the last $days days: $total in total, at most $peak in one day';
  }

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
  String get settingsTitle => 'Settings';

  @override
  String get settingsSearchHint => 'Search settings';

  @override
  String settingsSearchNoResults(String query) {
    return 'No settings match “$query”.';
  }

  @override
  String get settingsRestoreAll => 'Restore all defaults';

  @override
  String get settingsRestoreAllTitle => 'Restore all settings?';

  @override
  String get settingsRestoreAllBody =>
      'Every setting goes back to its default. Your library, playlists, connected accounts and download folder are kept.';

  @override
  String get settingsRestoreSection => 'Restore defaults for this section';

  @override
  String settingsRestoreSectionTitle(String section) {
    return 'Restore “$section” defaults?';
  }

  @override
  String get settingsRestoreSectionBody =>
      'The settings in this section go back to their defaults.';

  @override
  String get settingsRestoredToast => 'Defaults restored';

  @override
  String get settingsBack => 'Back to settings';

  @override
  String get settingsSectionUnavailable =>
      'This section isn\'t available on this device.';

  @override
  String get settingsOn => 'On';

  @override
  String get settingsOff => 'Off';

  @override
  String get settingsValueFull => 'Full';

  @override
  String get settingsValueReduced => 'Reduced';

  @override
  String get settingsValueLow => 'Low';

  @override
  String get settingsValueMedium => 'Medium';

  @override
  String get settingsValueHigh => 'High';

  @override
  String get settingsValueNormal => 'Normal';

  @override
  String get settingsValueLossless => 'Lossless';

  @override
  String get settingsSaved => 'Saved';

  @override
  String get settingsNotAvailable => 'Not available';

  @override
  String get settingsOpenLinkFailed => 'Couldn\'t open the link.';

  @override
  String settingsSavedTo(String location) {
    return 'Saved to $location';
  }

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsAccent => 'Accent colour';

  @override
  String get settingsAccentGold => 'Gold';

  @override
  String get settingsAccentCoral => 'Coral';

  @override
  String get settingsAccentMint => 'Mint';

  @override
  String get settingsAccentIce => 'Ice';

  @override
  String get settingsAccentMono => 'Monochrome';

  @override
  String get settingsDensity => 'Density';

  @override
  String get settingsDensityComfortable => 'Comfortable';

  @override
  String get settingsDensityCompact => 'Compact';

  @override
  String get settingsArtworkBackdrop => 'Artwork backdrop';

  @override
  String get settingsArtworkBackdropHint =>
      'Shows a soft, tinted version of the cover behind Now Playing.';

  @override
  String get settingsHighContrast => 'High contrast';

  @override
  String get settingsHighContrastHint =>
      'Stronger text, borders and accent colours.';

  @override
  String get settingsGlassIntro =>
      'An optional glass-inspired look: the sidebar, player and sheets become translucent and let your artwork shine through. Text always stays readable.';

  @override
  String get settingsGlassToggle => 'Liquid Glass';

  @override
  String get settingsGlassToggleHint =>
      'Off by default. Translucent surfaces with a soft blur.';

  @override
  String get settingsGlassIntensity => 'Intensity';

  @override
  String get settingsGlassIntensityHint =>
      'How much of the background shows through.';

  @override
  String get settingsGlassIntensityDisabled =>
      'Turn on Liquid Glass to adjust the intensity.';

  @override
  String get settingsGlassBlurOff =>
      'Blur is turned off by the current performance mode, so glass will use a lighter translucent style.';

  @override
  String get settingsGlassReadability =>
      'Fermata raises the opacity of glass surfaces automatically whenever that is needed to keep text readable.';

  @override
  String settingsSecondsShort(int seconds) {
    return '$seconds s';
  }

  @override
  String get settingsTransitionsGroup => 'Transitions';

  @override
  String get settingsCrossfade => 'Crossfade';

  @override
  String get settingsCrossfadeHint =>
      'Blend the end of a track into the next one.';

  @override
  String get settingsGapless => 'Gapless playback';

  @override
  String get settingsGaplessHint =>
      'No silence between tracks that belong together, like live albums.';

  @override
  String get settingsGaplessCrossfadeNote =>
      'Not used while crossfade is on — crossfade already joins the tracks.';

  @override
  String get settingsPreviousThreshold => 'Restart before going back';

  @override
  String settingsPreviousThresholdHint(int seconds) {
    return '“Previous” restarts the track when more than $seconds s have played.';
  }

  @override
  String get settingsPreviousThresholdAlways =>
      '“Previous” always goes to the previous track.';

  @override
  String get settingsVolumeGroup => 'Volume & speed';

  @override
  String get settingsNormalize => 'Volume normalization';

  @override
  String get settingsNormalizeHint => 'Plays tracks at a similar loudness.';

  @override
  String get settingsNormalizationMode => 'Normalization method';

  @override
  String get settingsNormalizationModeDisabled =>
      'Turn on volume normalization first.';

  @override
  String get settingsNormalizationTrack => 'ReplayGain (track)';

  @override
  String get settingsNormalizationTrackHint =>
      'Uses the loudness information stored in each file.';

  @override
  String get settingsNormalizationAlbum => 'ReplayGain (album)';

  @override
  String get settingsNormalizationAlbumHint =>
      'Keeps the intended differences between tracks of one album.';

  @override
  String get settingsNormalizationLoudness => 'Loudness (EBU R128)';

  @override
  String get settingsNormalizationLoudnessHint =>
      'Measures loudness while playing; works for streams without tags.';

  @override
  String get settingsPreamp => 'Pre-amplification';

  @override
  String get settingsPreampHint =>
      'Extra gain applied on top of normalization.';

  @override
  String get settingsSpeed => 'Playback speed';

  @override
  String get settingsSpeedHint =>
      'Applies now and is remembered for next time.';

  @override
  String get settingsStartupQueueGroup => 'Queue';

  @override
  String get settingsRestoreQueue => 'Restore queue on startup';

  @override
  String get settingsRestoreQueueHint =>
      'Continue where you left off, including the position in the track.';

  @override
  String get settingsAutoplay => 'Start playing on startup';

  @override
  String get settingsAutoplayHint =>
      'Resume the restored queue as soon as Fermata opens.';

  @override
  String get settingsAutoplayDisabled => 'Needs “Restore queue on startup”.';

  @override
  String get settingsSmartQueue => 'Smart queue';

  @override
  String get settingsSmartQueueHint =>
      'When the queue runs out, add similar tracks.';

  @override
  String get settingsSkipUnplayable => 'Skip unplayable tracks';

  @override
  String get settingsSkipUnplayableHint =>
      'Move on automatically when a track can\'t be played, and tell you why.';

  @override
  String get settingsExtrasGroup => 'Sleep timer & lyrics';

  @override
  String get settingsSleepFade => 'Fade out at sleep timer';

  @override
  String get settingsSleepFadeHint =>
      'Lower the volume gently before the sleep timer pauses.';

  @override
  String get settingsLyrics => 'Lyrics';

  @override
  String get settingsLyricsHint =>
      'Look up lyrics on LRCLIB and read lyrics stored in your files.';

  @override
  String get settingsInterruptionsGroup => 'Headphones & interruptions';

  @override
  String get settingsPauseOnDisconnect => 'Pause when headphones disconnect';

  @override
  String get settingsPauseOnDisconnectHint =>
      'Stops the music from suddenly playing through the speaker.';

  @override
  String get settingsResumeAfterInterruption => 'Resume after interruptions';

  @override
  String get settingsResumeAfterInterruptionHint =>
      'Continue after a call or another app\'s sound has finished.';

  @override
  String get settingsDuck => 'Lower volume for short sounds';

  @override
  String get settingsDuckHint =>
      'Navigation prompts and notifications play over quieter music instead of pausing it.';

  @override
  String get settingsQualityIntro =>
      'Choose how good streams and downloads should sound. Higher quality uses more data and storage.';

  @override
  String get settingStreamingQuality => 'Streaming quality';

  @override
  String get settingsStreamingQualityHint => 'On Wi-Fi and wired connections.';

  @override
  String get settingsMobileQuality => 'Mobile data quality';

  @override
  String get settingsMobileQualityHint =>
      'On mobile data and other metered connections.';

  @override
  String get settingsDownloadQuality => 'Download quality';

  @override
  String get settingsDownloadQualityHint =>
      'For tracks a source allows you to download.';

  @override
  String get settingsQualityProviders =>
      'Each provider decides which qualities it offers. Fermata uses the closest available quality, which can be lower than your choice — Deezer, for example, only offers 30-second previews.';

  @override
  String get settingsOutputGroup => 'Output';

  @override
  String get settingsOutputDevice => 'Output device';

  @override
  String get settingsOutputDeviceHint => 'Where Fermata plays its sound.';

  @override
  String get settingsOutputDeviceSystem => 'System default';

  @override
  String settingsOutputDeviceDefault(String name) {
    return '$name (default)';
  }

  @override
  String get settingsOutputDevicesFailed =>
      'Couldn\'t list the output devices.';

  @override
  String get settingsOutputDeviceFailed =>
      'Couldn\'t switch to this output device.';

  @override
  String get settingsDownloadFolder => 'Download folder';

  @override
  String get settingsDownloadFolderChange => 'Change…';

  @override
  String get settingsDownloadFolderMoving => 'Moving…';

  @override
  String get settingsDownloadFolderPick => 'Choose a folder for downloads';

  @override
  String get settingsDownloadFolderMoveTitle => 'Move downloads?';

  @override
  String settingsDownloadFolderMoveBody(String path) {
    return 'Your downloaded tracks will be moved to $path. This can take a while for large collections; you can keep listening meanwhile.';
  }

  @override
  String get settingsDownloadFolderMove => 'Move downloads';

  @override
  String get settingsDownloadFolderMoved => 'Downloads moved';

  @override
  String get settingsDownloadFolderFailed =>
      'Couldn\'t move the downloads. Nothing was changed.';

  @override
  String settingsDownloadFolderFailedDetail(String detail) {
    return 'Couldn\'t move the downloads: $detail';
  }

  @override
  String get settingWifiOnly => 'Download on Wi-Fi only';

  @override
  String get settingsWifiOnlyHint =>
      'Downloads wait for Wi-Fi or a wired connection.';

  @override
  String get settingsWarnMobile => 'Warn before using mobile data';

  @override
  String get settingsWarnMobileHint =>
      'Ask before a download starts on a metered connection.';

  @override
  String get settingsWarnMobileDisabled =>
      'Not needed while downloads wait for Wi-Fi.';

  @override
  String get settingsMaxConcurrent => 'Simultaneous downloads';

  @override
  String get settingsMaxConcurrentHint =>
      'How many tracks download at the same time.';

  @override
  String get settingsVerifyIntegrity => 'Verify downloads';

  @override
  String get settingsVerifyIntegrityHint =>
      'Check every finished file before it\'s used, so a broken download never plays.';

  @override
  String get settingsNotifyComplete => 'Notify when downloads finish';

  @override
  String get settingsNotifyCompleteHint =>
      'A system notification when a batch of downloads is done.';

  @override
  String get settingsNotificationsUnsupported =>
      'System notifications aren\'t available on this device; Fermata shows the progress in the app instead.';

  @override
  String get settingsOfflineGroup => 'What can be offline';

  @override
  String get settingsOfflineIntro =>
      'Every track belongs to one of four categories. Fermata follows each provider\'s terms and never stores streams as files.';

  @override
  String get settingsOfflineUserOwned =>
      'Music files you added from your own folders. Always available offline.';

  @override
  String get settingsOfflineDownloadable =>
      'The provider allows downloading this track (for example Audius or Jamendo tracks the artist made downloadable). You start each download yourself.';

  @override
  String get settingsOfflineStreamOnly =>
      'Can be played while you\'re online, but the provider doesn\'t allow storing it — SoundCloud, for example.';

  @override
  String get settingsOfflineUnavailable =>
      'Can\'t be made available offline at all, such as previews or tracks that only play in the provider\'s own app.';

  @override
  String get settingsAutoDownloadNote =>
      'Automatic downloads (for example for a whole playlist) only include sources that permit them: your own files. None of the streaming providers currently allow automatic downloads.';

  @override
  String get settingsUsageGroup => 'Usage';

  @override
  String get settingsUsageFailed => 'Couldn\'t calculate the storage usage.';

  @override
  String settingsUsageTotal(String size) {
    return '$size used by Fermata';
  }

  @override
  String settingsUsageFree(String size) {
    return '$size free on this disk';
  }

  @override
  String settingsUsageDownloads(int count) {
    return 'Downloads ($count)';
  }

  @override
  String get settingsUsageArtwork => 'Artwork cache';

  @override
  String get settingsUsageStreamCache => 'Stream cache';

  @override
  String get settingsUsageDatabase => 'Library database';

  @override
  String settingsUsageLimit(String used, String limit) {
    return 'Downloads use $used of $limit';
  }

  @override
  String get settingsRefresh => 'Refresh';

  @override
  String get settingsLimitsGroup => 'Limits';

  @override
  String get settingsDownloadLimit => 'Download storage limit';

  @override
  String get settingsDownloadLimitHint => 'The most space downloads may use.';

  @override
  String get settingsUnlimited => 'Unlimited';

  @override
  String get settingsAutoCleanup => 'Clean up automatically';

  @override
  String get settingsAutoCleanupHint =>
      'When the limit is reached, remove the downloads you played least recently.';

  @override
  String get settingsAutoCleanupDisabled =>
      'Set a storage limit to use automatic clean-up.';

  @override
  String get settingsArtworkCache => 'Artwork cache size';

  @override
  String get settingsArtworkCacheHint =>
      'Covers are kept so they load instantly and work offline.';

  @override
  String get settingsMaintenanceGroup => 'Maintenance';

  @override
  String get settingsCleanUpNow => 'Clean up now';

  @override
  String get settingsCleanUpNowHint => 'Apply the storage limit right away.';

  @override
  String get settingsCleanUpNowAction => 'Clean up';

  @override
  String get settingsNothingToClean =>
      'Nothing to clean up — you\'re within the limit.';

  @override
  String settingsFreed(String size) {
    return 'Freed $size';
  }

  @override
  String get settingsClearArtwork => 'Clear artwork cache';

  @override
  String get settingsClearArtworkHint =>
      'Covers will be downloaded again when needed.';

  @override
  String get settingsClearArtworkAction => 'Clear';

  @override
  String get settingsVerifyDownloads => 'Verify downloads';

  @override
  String get settingsVerifyDownloadsHint =>
      'Check every downloaded file for damage.';

  @override
  String get settingsVerifyDownloadsAction => 'Verify';

  @override
  String get settingsVerifyOk => 'All downloads are intact.';

  @override
  String settingsVerifyBroken(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count damaged downloads found. Retry them on the Downloads page.',
      one: '1 damaged download found. Retry it on the Downloads page.',
    );
    return '$_temp0';
  }

  @override
  String settingsMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String settingsHoursShort(int hours) {
    return '$hours h';
  }

  @override
  String get settingsModeBalanced => 'Balanced';

  @override
  String get settingsModePerformance => 'Performance';

  @override
  String get settingsModeBatterySaver => 'Battery saver';

  @override
  String get settingsModeDataSaver => 'Data saver';

  @override
  String get settingsModeVisualQuality => 'Visual quality';

  @override
  String get settingsModeCustom => 'Custom';

  @override
  String get settingsModeBalancedHint =>
      'The default: full animations, blur and medium artwork.';

  @override
  String get settingsModePerformanceHint =>
      'Reduces animations and turns off blur and artwork prefetching.';

  @override
  String get settingsModeBatterySaverHint =>
      'Turns off animations, blur, preloading and background sync, and uses smaller artwork.';

  @override
  String get settingsModeDataSaverHint =>
      'Lowers streaming quality, waits for Wi-Fi to download and stops preloading.';

  @override
  String get settingsModeVisualQualityHint =>
      'Full animations, blur and the sharpest artwork.';

  @override
  String get settingsModeCustomHint =>
      'Your own combination of the settings below.';

  @override
  String get settingsPerformanceIntro =>
      'Pick a mode to change several settings at once. Changing any single setting below switches to Custom.';

  @override
  String settingsActiveNow(String mode) {
    return 'Active now: $mode';
  }

  @override
  String get settingsActiveNowReducedMotion =>
      'Your system or accessibility settings ask for reduced motion, so animations are reduced.';

  @override
  String get settingsGranularGroup => 'Individual settings';

  @override
  String get settingsGranularIntro =>
      'Adjusting any of these switches the mode to Custom.';

  @override
  String get settingAnimations => 'Animations';

  @override
  String get settingsAnimationsHint =>
      'Transitions and motion throughout the app.';

  @override
  String get settingBlur => 'Blur';

  @override
  String get settingsBlurHint =>
      'Background blur for glass and Now Playing. Off uses plain translucent surfaces.';

  @override
  String get settingArtworkQuality => 'Artwork quality';

  @override
  String get settingsArtworkQualityHint =>
      'Lower quality decodes smaller images and uses less memory.';

  @override
  String get settingPreloadNext => 'Preload next track';

  @override
  String get settingsPreloadNextHint =>
      'Prepares the next track early for seamless transitions.';

  @override
  String get settingPrefetchArtwork => 'Prefetch artwork';

  @override
  String get settingsPrefetchArtworkHint =>
      'Downloads covers of upcoming tracks ahead of time.';

  @override
  String get settingBackgroundSync => 'Background sync';

  @override
  String get settingsBackgroundSyncHint =>
      'Refreshes connected services, recommendations and permitted downloads periodically.';

  @override
  String get settingsSyncInterval => 'Sync every';

  @override
  String get settingsSyncIntervalDisabled => 'Background sync is off.';

  @override
  String get settingsSaversIntro =>
      'Shortcuts into the matching performance modes. Each one lists exactly what it changes.';

  @override
  String get settingsSaverTurnOn => 'Use this mode';

  @override
  String get settingsSaverTurnOff => 'Turn off (back to Balanced)';

  @override
  String get settingsBatterySaverNote =>
      'Reduces the work Fermata does while you listen. Playback itself is not affected.';

  @override
  String get settingsDataSaverNote =>
      'Also sets streaming quality to Low and downloads to Wi-Fi only. Turning it off keeps those two settings; change them under Audio quality and Downloads.';

  @override
  String get settingsSaversAndroidNote =>
      'Android\'s own battery optimization can also stop music in the background. You can allow Fermata to keep running under Background playback.';

  @override
  String get settingsSaversCustomNote =>
      'Want something in between? Pick Custom under Performance and adjust each setting.';

  @override
  String get settingsServicesIntro =>
      'Connect the services you use. Each card says exactly what Fermata can and can\'t do with that service.';

  @override
  String get settingsTokensNotPersistent =>
      'Your system has no secure key storage (for example GNOME Keyring or KWallet), so sign-ins are only kept until Fermata closes and you\'ll need to reconnect after a restart. Install and unlock a keyring to stay signed in.';

  @override
  String get settingsNoPasswords =>
      'Fermata never asks for your passwords. You sign in on the service\'s own website, and Fermata only keeps the access it was granted, in your system\'s secure storage.';

  @override
  String get settingsStatusNotRequired => 'No account needed';

  @override
  String get settingsStatusCredentialsMissing => 'Not set up';

  @override
  String get settingsStatusNotConnected => 'Not connected';

  @override
  String get settingsStatusConnecting => 'Connecting…';

  @override
  String get settingsStatusConnected => 'Connected';

  @override
  String get settingsStatusExpired => 'Sign-in expired';

  @override
  String get settingsStatusError => 'Error';

  @override
  String settingsStatusSemantics(String status) {
    return 'Status: $status';
  }

  @override
  String settingsAccount(String name) {
    return 'Signed in as $name';
  }

  @override
  String settingsScopes(String scopes) {
    return 'Access granted: $scopes';
  }

  @override
  String settingsExpiredHint(String service) {
    return 'Your $service sign-in has expired. Reconnect to continue.';
  }

  @override
  String settingsErrorDetail(String detail) {
    return 'Problem: $detail';
  }

  @override
  String settingsCredentialsMissingHint(String service) {
    return '$service needs developer credentials (an app registration) before you can use it. Enter them below — they are not your account password.';
  }

  @override
  String get settingsCanSearch => 'Search its catalog';

  @override
  String get settingsCanStream => 'Play full tracks in Fermata';

  @override
  String get settingsCanPreview => 'Play previews in Fermata';

  @override
  String settingsCanExternal(String service) {
    return 'Open tracks in $service for playback';
  }

  @override
  String get settingsCanDownload => 'Download single tracks the artist allows';

  @override
  String get settingsCanLibrary => 'Read your playlists and liked tracks';

  @override
  String get settingsCanImport => 'Import playlists';

  @override
  String get settingsCanIsrc => 'Precise matching by ISRC';

  @override
  String get settingsCanDiscover => 'Recommendations, charts and new releases';

  @override
  String get settingsCantStream => 'Can\'t play full tracks inside Fermata';

  @override
  String get settingsCantDownload => 'No downloads';

  @override
  String settingsSiloed(String service) {
    return '$service tracks play in their own queue ($service\'s terms)';
  }

  @override
  String get settingsCantLibrary => 'No access to your account\'s library';

  @override
  String get settingsConnect => 'Connect';

  @override
  String get settingsReconnect => 'Reconnect';

  @override
  String get settingsDisconnect => 'Disconnect';

  @override
  String get settingsConnectingHint =>
      'Finish signing in in your browser. Fermata never sees your password.';

  @override
  String settingsConnected(String service) {
    return 'Connected to $service';
  }

  @override
  String settingsConnectFailed(String service) {
    return 'Couldn\'t connect to $service.';
  }

  @override
  String settingsDisconnectTitle(String service) {
    return 'Disconnect $service?';
  }

  @override
  String settingsDisconnectBody(String service) {
    return 'Fermata forgets its access to your $service account. Imported playlists stay in your library.';
  }

  @override
  String get settingsTerms => 'Terms';

  @override
  String get settingsCredOverride => 'Use your own developer credentials';

  @override
  String get settingsCredTitle => 'Developer credentials';

  @override
  String settingsCredIntro(String service) {
    return 'Values from the app you registered with $service. They identify Fermata to $service; your own account still signs in on $service\'s website.';
  }

  @override
  String settingsCredOrigin(String origin) {
    return 'Currently used: $origin';
  }

  @override
  String get settingsCredOriginNone => 'none';

  @override
  String get settingsCredOriginBuild => 'built into this version of Fermata';

  @override
  String settingsCredOriginFile(String path) {
    return 'the file $path';
  }

  @override
  String get settingsCredOriginUser => 'entered by you';

  @override
  String get settingsCredRegister => 'Register an app';

  @override
  String get settingsCredRedirects => 'Redirect URIs to register';

  @override
  String get settingsCredRedirectDesktop => 'Desktop (Linux and Windows)';

  @override
  String get settingsCredRedirectAndroid => 'Android';

  @override
  String get settingsCredRedirectCustom => 'Your custom redirect URI';

  @override
  String get settingsCredClientId => 'Client ID';

  @override
  String get settingsCredClientSecret => 'Client secret';

  @override
  String get settingsCredApiKey => 'API key';

  @override
  String get settingsCredRedirectUri => 'Redirect URI';

  @override
  String get settingsCredOptional => 'optional';

  @override
  String get settingsCredShow => 'Show';

  @override
  String get settingsCredHide => 'Hide';

  @override
  String settingsCredRequired(String fields) {
    return 'Please fill in: $fields';
  }

  @override
  String settingsCredSaved(String service) {
    return 'Credentials for $service saved';
  }

  @override
  String get settingsCredSaveFailed => 'Couldn\'t save the credentials.';

  @override
  String get settingsCredRemoved => 'Your credentials were removed';

  @override
  String get settingsCredRemove => 'Remove mine';

  @override
  String get settingsCredNoPasswords =>
      'Never enter your account password here.';

  @override
  String get settingsCopy => 'Copy';

  @override
  String get settingsCopied => 'Copied';

  @override
  String get settingsProviderOrder => 'Provider order';

  @override
  String get settingsProviderOrderHint =>
      'Used to order search results, to pick a stream when a track exists on several services, and as match targets for imports. Turn a service off to leave it out everywhere.';

  @override
  String get settingsDragToReorder => 'Drag to reorder';

  @override
  String get settingsMoveUp => 'Move up';

  @override
  String get settingsMoveDown => 'Move down';

  @override
  String settingsSourceEnabled(String service) {
    return 'Use $service';
  }

  @override
  String get settingsPreferSoundCloud => 'Prefer SoundCloud in discovery';

  @override
  String get settingsPreferSoundCloudHint =>
      'Build mixes and recommendations from SoundCloud first when it\'s connected.';

  @override
  String get settingsImportIntro =>
      'How Fermata finds your tracks on other services when you import a playlist. These are the defaults; you can change them for each import.';

  @override
  String get settingsReviewMode => 'Review';

  @override
  String get settingsReviewAuto => 'Accept confident matches';

  @override
  String get settingsReviewAutoHint =>
      'Matches above the threshold are accepted; you review the rest.';

  @override
  String get settingsReviewAll => 'Review every match';

  @override
  String get settingsReviewAllHint =>
      'Nothing is accepted until you confirm it.';

  @override
  String get settingsAutoAcceptThreshold => 'Auto-accept threshold';

  @override
  String get settingsAutoAcceptThresholdHint =>
      'How sure Fermata must be before it accepts a match by itself.';

  @override
  String get settingsAutoAcceptThresholdDisabled =>
      'Only used when confident matches are accepted automatically.';

  @override
  String get settingsSkipUnavailable => 'Skip unavailable tracks';

  @override
  String get settingsSkipUnavailableHint =>
      'Leave out tracks that can\'t be played on any target service.';

  @override
  String get settingsPreferredProvider => 'Preferred service';

  @override
  String get settingsPreferredProviderHint =>
      'When several services have the track, prefer this one.';

  @override
  String get settingsNoPreference => 'No preference (use provider order)';

  @override
  String get settingsAllowPreviewOnly => 'Allow preview-only matches';

  @override
  String get settingsAllowPreviewOnlyHint =>
      'Accept matches that only play a short preview, such as Deezer.';

  @override
  String get settingsImportVersionsNote =>
      'A remix, live, acoustic or other version is never accepted automatically when the original was a different version.';

  @override
  String get settingsImportPlaylist => 'Import a playlist';

  @override
  String get settingsNotifyTrackChange => 'When the track changes';

  @override
  String get settingsNotifyTrackChangeHint =>
      'A small desktop notification with the new track.';

  @override
  String get settingsNotifyDownloads => 'Downloads';

  @override
  String get settingsNotifyDownloadsHint => 'When downloads finish or fail.';

  @override
  String get settingsMediaNotificationNote =>
      'The playback controls notification is part of background playback and is always shown while music plays.';

  @override
  String get settingsPermissionGroup => 'Permission';

  @override
  String get settingsNotificationPermission => 'Notifications';

  @override
  String get settingsNotificationPermissionMissing =>
      'Not allowed. Android needs your permission before Fermata can show playback controls and download messages.';

  @override
  String get settingsPermissionAllowed => 'Allowed';

  @override
  String get settingsAllow => 'Allow';

  @override
  String get settingsOpenSystemSettings => 'System settings';

  @override
  String get settingsBackgroundIntro =>
      'Fermata plays in a foreground service with a media notification, so music keeps going when you leave the app or lock the screen.';

  @override
  String get settingsBackgroundDesktop =>
      'Closing the window keeps the music playing. Fermata stays in the system tray — or minimized when there is no tray — and your media keys keep working. Choose Quit in the tray menu to stop completely.';

  @override
  String get settingsRestartRequired =>
      'Restart Fermata to apply the changed background setting.';

  @override
  String get settingsStopServiceOnPause =>
      'Let Android stop playback when paused';

  @override
  String get settingsStopServiceOnPauseHint =>
      'While paused, the notification can be swiped away and Android may close Fermata to save battery. Applies after restarting Fermata.';

  @override
  String get settingsResumeOnHeadset => 'Resume when headphones connect';

  @override
  String get settingsResumeOnHeadsetHint =>
      'Continue playing when headphones or a Bluetooth device reconnect shortly after they were disconnected.';

  @override
  String get settingsBatteryGroup => 'Battery optimization';

  @override
  String get settingsBatteryOptimized => 'Battery optimization is on';

  @override
  String get settingsBatteryOptimizedHint =>
      'Android may stop music in the background on some devices. Allowing background activity is optional and only changes this for Fermata.';

  @override
  String get settingsBatteryUnrestricted => 'Background activity is allowed';

  @override
  String get settingsBatteryUnrestrictedHint =>
      'Android won\'t restrict Fermata in the background.';

  @override
  String get settingsAllowBackground => 'Allow background activity';

  @override
  String get settingsOemNote =>
      'Some manufacturers add their own battery limits on top of Android\'s. If music still stops in the background, allow Fermata in your phone\'s battery settings as well — dontkillmyapp.com explains how for each brand.';

  @override
  String get settingsCloseBehavior => 'When closing the window';

  @override
  String get settingsCloseToTray => 'Keep playing in the tray';

  @override
  String get settingsCloseToTrayHint =>
      'The window hides; music keeps playing.';

  @override
  String get settingsCloseMinimize => 'Keep playing minimized';

  @override
  String get settingsCloseMinimizeHint =>
      'No tray is available, so the window is minimized; music keeps playing.';

  @override
  String get settingsCloseAsk => 'Ask every time';

  @override
  String get settingsCloseAskHint =>
      'Choose between keeping the music playing and quitting.';

  @override
  String get settingsCloseQuit => 'Quit Fermata';

  @override
  String get settingsCloseQuitHint => 'Playback stops and Fermata closes.';

  @override
  String get settingsShowTrayIcon => 'Show tray icon';

  @override
  String get settingsShowTrayIconHint =>
      'Quick controls and the current track in the system tray.';

  @override
  String get settingsRememberWindow => 'Remember window size and position';

  @override
  String get settingsRememberWindowHint => 'Opens where you left it last time.';

  @override
  String get settingsQuitNote =>
      'To stop completely, choose Quit in the tray menu — or pick “Ask every time” above to get a Quit button when you close the window.';

  @override
  String get settingsLaunchAtLogin => 'Launch at login';

  @override
  String get settingsLaunchAtLoginHint =>
      'Start Fermata when you sign in to your computer.';

  @override
  String get settingsLaunchAtLoginUnsupported =>
      'Not available on this system.';

  @override
  String get settingsLaunchAtLoginFailed =>
      'Couldn\'t change the login setting.';

  @override
  String get settingsStartMinimized => 'Start minimized';

  @override
  String get settingsStartMinimizedHint =>
      'Start in the tray (or minimized) instead of showing the window.';

  @override
  String get settingsShortcutsIntro =>
      'Click a shortcut to record a new one. Conflicts are shown in red.';

  @override
  String get settingsShortcutsInApp => 'In Fermata';

  @override
  String get settingsShortcutsGlobal => 'Global shortcuts';

  @override
  String get settingsShortcutsGlobalHint =>
      'Work everywhere, even when Fermata is in the background.';

  @override
  String get settingsGlobalHotkeys => 'Use global shortcuts';

  @override
  String get settingsGlobalHotkeysHint =>
      'Fermata registers these keys with your desktop.';

  @override
  String get settingsShortcutNone => 'Not set';

  @override
  String settingsShortcutConflict(String actions) {
    return 'Also used by: $actions';
  }

  @override
  String settingsShortcutChangeSemantics(String action, String binding) {
    return '$action: $binding. Change shortcut';
  }

  @override
  String get settingsShortcutMore => 'More options';

  @override
  String get settingsShortcutChange => 'Record new shortcut';

  @override
  String get settingsShortcutReset => 'Reset to default';

  @override
  String get settingsShortcutRemove => 'Remove shortcut';

  @override
  String settingsShortcutRecordTitle(String action) {
    return 'Shortcut for “$action”';
  }

  @override
  String get settingsShortcutRecordHint =>
      'Press the key combination you want to use. Press Esc to cancel.';

  @override
  String get settingsShortcutWaiting => 'Waiting for keys…';

  @override
  String get settingsShortcutNeedsModifier =>
      'Global shortcuts need Ctrl, Alt, Shift or Super, otherwise they would block typing in other apps.';

  @override
  String get settingsFileInvalid =>
      'This file isn\'t a Fermata file, or it is damaged.';

  @override
  String get settingsRecordHistory => 'Listening history';

  @override
  String get settingsRecordHistoryHint =>
      'Remember what you play, on this device only. Used for History, Recently played and your mixes.';

  @override
  String get settingsPersonalized => 'Personalized recommendations';

  @override
  String get settingsPersonalizedHint =>
      'Mixes and suggestions are calculated on this device from your history and favorites. Off shows only trending music, new releases and genres.';

  @override
  String get settingsSaveSearches => 'Search history';

  @override
  String get settingsSaveSearchesHint => 'Show your recent searches in Search.';

  @override
  String get settingsNoTrackingTitle => 'No analytics or tracking';

  @override
  String get settingsNoTracking =>
      'Fermata has no analytics, no ads, no crash reporting and no account of its own. Nothing about what you listen to leaves this device unless a service you connected needs it to play the music.';

  @override
  String get settingsNetworkIntro => 'Fermata only connects to:';

  @override
  String get settingsNetworkProviders =>
      'The music services you use — to search, stream, read your playlists and import. Requests go directly from this device to the service.';

  @override
  String get settingsNetworkLyricsOn =>
      'LRCLIB, to look up lyrics for the track that is playing (title, artist, album and duration are sent).';

  @override
  String get settingsNetworkLyricsOff =>
      'LRCLIB is not contacted because lyrics are turned off.';

  @override
  String get settingsNetworkUpdatesOn =>
      'GitHub, once a day, to see whether a new version of Fermata exists. Nothing about you is sent.';

  @override
  String get settingsNetworkUpdatesOff =>
      'GitHub only when you press “Check now” under Updates.';

  @override
  String get settingsNetworkArtwork =>
      'The services\' image servers, to download cover art (kept in the artwork cache).';

  @override
  String get settingsNetworkSignIn =>
      'A service\'s own sign-in page in your browser when you connect it.';

  @override
  String get settingsYourDataGroup => 'Your data';

  @override
  String get settingsDeleteHistory => 'Delete listening history';

  @override
  String get settingsDeleteHistoryHint =>
      'Removes every play from History and statistics.';

  @override
  String get settingsDeleteHistoryTitle => 'Delete listening history?';

  @override
  String get settingsDeleteHistoryBody =>
      'History, “Recently played” and listening statistics are deleted. Your mixes will start fresh.';

  @override
  String get settingsDeleteHistoryDone => 'Listening history deleted';

  @override
  String get settingsClearSearches => 'Clear search history';

  @override
  String get settingsClearSearchesHint => 'Removes your recent searches.';

  @override
  String get settingsClearSearchesTitle => 'Clear search history?';

  @override
  String get settingsClearSearchesBody => 'Your recent searches are removed.';

  @override
  String get settingsClearSearchesDone => 'Search history cleared';

  @override
  String get settingsClearAction => 'Clear';

  @override
  String get settingsExportSettings => 'Export settings';

  @override
  String get settingsExportSettingsHint =>
      'Save your settings as a file. It contains no passwords or sign-ins.';

  @override
  String get settingsImportSettings => 'Import settings';

  @override
  String get settingsImportSettingsHint =>
      'Replace your settings with an exported file.';

  @override
  String get settingsImportSettingsDone => 'Settings imported';

  @override
  String get settingsExportAction => 'Export';

  @override
  String get settingsImportAction => 'Import';

  @override
  String get settingsBackupLibrary => 'Back up library';

  @override
  String get settingsBackupLibraryHint =>
      'Playlists, favorites, history and track links as one file. Music files are not included.';

  @override
  String get settingsRestoreLibrary => 'Restore library';

  @override
  String get settingsRestoreLibraryHint => 'Bring back a library backup.';

  @override
  String get settingsRestoreLibraryTitle => 'Restore library backup?';

  @override
  String get settingsRestoreLibraryBody =>
      'Merge adds the backup to your current library. Replace removes your current playlists, favorites and history first.';

  @override
  String get settingsRestoreMerge => 'Merge';

  @override
  String get settingsRestoreReplace => 'Replace';

  @override
  String get settingsRestoreLibraryDone => 'Library restored';

  @override
  String get settingsDeleteAll => 'Delete all data';

  @override
  String get settingsDeleteAllHint =>
      'Playlists, favorites, history, searches and sign-ins. Your music files stay on disk.';

  @override
  String get settingsDeleteAllTitle => 'Delete all your data?';

  @override
  String get settingsDeleteAllBody =>
      'This deletes your playlists, favorites, listening and search history, track links and cached metadata, and signs you out of every service. Music files on your disk are never deleted, and your settings are kept. This can\'t be undone.';

  @override
  String get settingsDeleteAllWord => 'DELETE';

  @override
  String get settingsDeleteAllAction => 'Delete everything';

  @override
  String get settingsDeleteAllDone => 'All your data was deleted';

  @override
  String get settingsLanguageSystem => 'System language';

  @override
  String get settingsLanguageSystemHint =>
      'Follows your device. Languages Fermata doesn\'t have yet fall back to English.';

  @override
  String get settingsMotion => 'Motion';

  @override
  String get settingsMotionHint =>
      '“System” follows your device\'s reduce-motion setting.';

  @override
  String get settingsMotionSystem => 'System';

  @override
  String get settingsMotionReduce => 'Reduce';

  @override
  String get settingsMotionFull => 'Full';

  @override
  String get settingsTextScale => 'Text size';

  @override
  String get settingsTextScaleHint => 'On top of your system\'s text size.';

  @override
  String get settingsTextScalePreviewTitle => 'Night Drive';

  @override
  String get settingsTextScalePreviewBody =>
      'This is how titles and descriptions will look.';

  @override
  String get settingsLargerTargets => 'Larger touch targets';

  @override
  String get settingsLargerTargetsHint =>
      'Bigger buttons and rows that are easier to hit.';

  @override
  String get settingsAccessibilityNote =>
      'Fermata works with screen readers (TalkBack, Orca, Narrator) and can be used entirely with the keyboard on desktop.';

  @override
  String get settingsCurrentVersion => 'Installed version';

  @override
  String get settingsAutoUpdateCheck => 'Check for updates automatically';

  @override
  String get settingsAutoUpdateCheckHint =>
      'Off by default. Once a day, Fermata asks GitHub for the latest release; nothing about you is sent. Fermata never installs anything by itself.';

  @override
  String get settingsCheckNow => 'Check now';

  @override
  String get settingsCheckNowHint => 'Asks GitHub once for the latest release.';

  @override
  String get settingsCheckNowAction => 'Check';

  @override
  String settingsUpToDate(String version) {
    return 'You\'re up to date ($version).';
  }

  @override
  String settingsUpdateAvailable(String version) {
    return 'Version $version is available.';
  }

  @override
  String get settingsNoReleases => 'No release has been published yet.';

  @override
  String get settingsUpdateFailed =>
      'Couldn\'t check for updates. Check your connection and try again.';

  @override
  String get settingsUpdateHowLinux =>
      'To update, download the newer release and run its setup.sh the same way you installed Fermata. Your library, settings and sign-ins are kept.';

  @override
  String get settingsUpdateHowWindows =>
      'To update, download and run the newer setup.exe. It replaces the installed version and keeps your library, settings and sign-ins.';

  @override
  String get settingsUpdateHowAndroid =>
      'To update, install the newer app.apk over this one. Your data is kept.';

  @override
  String get settingsReleaseNotes => 'Release notes';

  @override
  String get settingsTagline =>
      'A calm, local-first music player for your files and the services you use.';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsPlatform => 'Platform';

  @override
  String get settingsLogFile => 'Log file';

  @override
  String get settingsExportDiagnostics => 'Export diagnostics';

  @override
  String get settingsExportDiagnosticsHint =>
      'Saves recent logs and a summary of your setup to a file you can attach to a bug report. Contains no passwords, sign-ins or keys.';

  @override
  String get settingsLicenses => 'Open-source licenses';

  @override
  String get settingsLicensesHint =>
      'The licenses of the software Fermata is built with.';

  @override
  String get settingsLicensesAction => 'View';

  @override
  String get settingsAttributions => 'Attributions';

  @override
  String get settingsAttributionSoundCloud =>
      'SoundCloud: tracks and artwork are provided by SoundCloud and its creators. Each SoundCloud track links to the track and its uploader on soundcloud.com.';

  @override
  String get settingsAttributionDeezer =>
      'Deezer: catalog data and 30-second previews are provided by Deezer.';

  @override
  String get settingsAttributionAudius =>
      'Audius: tracks are streamed from the Audius network and belong to their artists.';

  @override
  String get settingsAttributionJamendo =>
      'Jamendo: music is provided by Jamendo under each artist\'s Creative Commons license.';

  @override
  String get settingsAttributionLrclib =>
      'Lyrics: provided by LRCLIB (lrclib.net), a free community lyrics database.';

  @override
  String get settingsAttributionSpotifyYouTube =>
      'Spotify and YouTube Music content is shown as supplied by those services and opens in their own apps.';

  @override
  String get settingsCredits => 'Credits';

  @override
  String get settingsCreditsBody =>
      'Made with Flutter. Typeface: Manrope (SIL Open Font License). Playback by libmpv/media_kit on desktop and ExoPlayer/just_audio on Android. Thanks to everyone who builds the open-source software listed under licenses.';

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
