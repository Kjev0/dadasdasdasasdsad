import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_da.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('da'),
    Locale('en'),
  ];

  /// Product name; do not translate.
  ///
  /// In en, this message translates to:
  /// **'Fermata'**
  String get appName;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @actionLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get actionLearnMore;

  /// No description provided for @actionRestoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get actionRestoreDefaults;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorGeneric;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Check your connection and try again.'**
  String get errorOffline;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Try again.'**
  String get errorTimeout;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'The service is busy. Try again in a moment.'**
  String get errorRateLimited;

  /// No description provided for @errorAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'Reconnect your {service} account to continue.'**
  String errorAuthRequired(String service);

  /// No description provided for @errorCredentialsMissing.
  ///
  /// In en, this message translates to:
  /// **'{service} needs developer credentials before it can be used.'**
  String errorCredentialsMissing(String service);

  /// No description provided for @errorUnsupported.
  ///
  /// In en, this message translates to:
  /// **'{service} doesn\'t support this.'**
  String errorUnsupported(String service);

  /// No description provided for @reasonDeleted.
  ///
  /// In en, this message translates to:
  /// **'This track was deleted.'**
  String get reasonDeleted;

  /// No description provided for @reasonPrivate.
  ///
  /// In en, this message translates to:
  /// **'This track is private.'**
  String get reasonPrivate;

  /// No description provided for @reasonRegionRestricted.
  ///
  /// In en, this message translates to:
  /// **'Not available in your region.'**
  String get reasonRegionRestricted;

  /// No description provided for @reasonSubscriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Requires a subscription on the provider.'**
  String get reasonSubscriptionRequired;

  /// No description provided for @reasonNotStreamable.
  ///
  /// In en, this message translates to:
  /// **'The artist hasn\'t allowed streaming.'**
  String get reasonNotStreamable;

  /// No description provided for @reasonPreviewOnly.
  ///
  /// In en, this message translates to:
  /// **'Only a preview is available.'**
  String get reasonPreviewOnly;

  /// No description provided for @reasonExternalOnly.
  ///
  /// In en, this message translates to:
  /// **'Plays in the provider\'s own app.'**
  String get reasonExternalOnly;

  /// No description provided for @reasonFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The file is missing.'**
  String get reasonFileMissing;

  /// No description provided for @reasonNotAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Not authorized.'**
  String get reasonNotAuthorized;

  /// No description provided for @reasonCredentialsMissing.
  ///
  /// In en, this message translates to:
  /// **'Provider not set up.'**
  String get reasonCredentialsMissing;

  /// No description provided for @reasonOffline.
  ///
  /// In en, this message translates to:
  /// **'Unavailable offline.'**
  String get reasonOffline;

  /// No description provided for @reasonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unavailable.'**
  String get reasonUnknown;

  /// No description provided for @offlineUserOwned.
  ///
  /// In en, this message translates to:
  /// **'Your file'**
  String get offlineUserOwned;

  /// No description provided for @offlineDownloadable.
  ///
  /// In en, this message translates to:
  /// **'Downloadable'**
  String get offlineDownloadable;

  /// No description provided for @offlineStreamOnly.
  ///
  /// In en, this message translates to:
  /// **'Stream only'**
  String get offlineStreamOnly;

  /// No description provided for @offlineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available offline'**
  String get offlineUnavailable;

  /// No description provided for @reasonSiloed.
  ///
  /// In en, this message translates to:
  /// **'SoundCloud tracks play in their own queue (SoundCloud\'s terms).'**
  String get reasonSiloed;

  /// Disabled first item of the tray menu when nothing is loaded.
  ///
  /// In en, this message translates to:
  /// **'Not playing'**
  String get desktopTrayNotPlaying;

  /// Disabled first item of the tray menu: current track.
  ///
  /// In en, this message translates to:
  /// **'{title} — {artist}'**
  String desktopTrayNowPlaying(String title, String artist);

  /// No description provided for @desktopTrayPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get desktopTrayPlay;

  /// No description provided for @desktopTrayPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get desktopTrayPause;

  /// No description provided for @desktopTrayPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get desktopTrayPrevious;

  /// No description provided for @desktopTrayNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get desktopTrayNext;

  /// No description provided for @desktopTrayShow.
  ///
  /// In en, this message translates to:
  /// **'Show Fermata'**
  String get desktopTrayShow;

  /// No description provided for @desktopTrayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit Fermata'**
  String get desktopTrayQuit;

  /// Tray icon tooltip when nothing is playing.
  ///
  /// In en, this message translates to:
  /// **'Fermata'**
  String get desktopTrayTooltipIdle;

  /// Tray icon tooltip with the current track.
  ///
  /// In en, this message translates to:
  /// **'Fermata — {title} · {artist}'**
  String desktopTrayTooltipTrack(String title, String artist);

  /// No description provided for @desktopTrayTooltipTitleOnly.
  ///
  /// In en, this message translates to:
  /// **'Fermata — {title}'**
  String desktopTrayTooltipTitleOnly(String title);

  /// No description provided for @desktopTrayUnavailableGnome.
  ///
  /// In en, this message translates to:
  /// **'GNOME only shows tray icons with the AppIndicator extension. Without it, closing the window minimizes Fermata instead, and you can bring it back from the dock or the media controls.'**
  String get desktopTrayUnavailableGnome;

  /// No description provided for @desktopTrayUnavailableNoHost.
  ///
  /// In en, this message translates to:
  /// **'This desktop has no system tray (no StatusNotifier host is running). Closing the window minimizes Fermata instead.'**
  String get desktopTrayUnavailableNoHost;

  /// No description provided for @desktopTrayUnavailableNoBus.
  ///
  /// In en, this message translates to:
  /// **'Fermata can\'t reach the desktop session bus, so it can\'t show a tray icon. Closing the window minimizes Fermata instead.'**
  String get desktopTrayUnavailableNoBus;

  /// No description provided for @desktopTrayUnavailableIconMissing.
  ///
  /// In en, this message translates to:
  /// **'The tray icon file is missing from this installation, so the tray icon is turned off. Reinstalling Fermata should fix this.'**
  String get desktopTrayUnavailableIconMissing;

  /// No description provided for @desktopTrayUnavailableDisabled.
  ///
  /// In en, this message translates to:
  /// **'The tray icon is turned off. Closing the window minimizes Fermata instead.'**
  String get desktopTrayUnavailableDisabled;

  /// No description provided for @desktopTrayUnavailableFailed.
  ///
  /// In en, this message translates to:
  /// **'The system tray refused the icon. Closing the window minimizes Fermata instead.'**
  String get desktopTrayUnavailableFailed;

  /// No description provided for @desktopTrayUnavailableUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This platform has no system tray.'**
  String get desktopTrayUnavailableUnsupported;

  /// No description provided for @desktopCloseDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Close Fermata?'**
  String get desktopCloseDialogTitle;

  /// No description provided for @desktopCloseDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Fermata can keep playing in the background. You can bring it back from the tray icon or your desktop\'s media controls.'**
  String get desktopCloseDialogBody;

  /// No description provided for @desktopCloseDialogKeepPlaying.
  ///
  /// In en, this message translates to:
  /// **'Keep playing in background'**
  String get desktopCloseDialogKeepPlaying;

  /// No description provided for @desktopCloseDialogQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get desktopCloseDialogQuit;

  /// No description provided for @desktopCloseDialogRemember.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask again'**
  String get desktopCloseDialogRemember;

  /// No description provided for @desktopHotkeyErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'“{binding}” isn\'t a valid shortcut.'**
  String desktopHotkeyErrorInvalid(String binding);

  /// No description provided for @desktopHotkeyErrorNeedsModifier.
  ///
  /// In en, this message translates to:
  /// **'“{binding}” needs Ctrl, Alt, Shift or Super, otherwise it would block normal typing in every app.'**
  String desktopHotkeyErrorNeedsModifier(String binding);

  /// No description provided for @desktopHotkeyErrorDuplicate.
  ///
  /// In en, this message translates to:
  /// **'“{binding}” is already used by another global shortcut.'**
  String desktopHotkeyErrorDuplicate(String binding);

  /// No description provided for @desktopHotkeyErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t register “{binding}”. Another app may already be using it.'**
  String desktopHotkeyErrorFailed(String binding);

  /// No description provided for @desktopHotkeysUnsupportedWayland.
  ///
  /// In en, this message translates to:
  /// **'Global shortcuts don\'t work in Wayland sessions. Use your desktop\'s keyboard settings instead: media keys and commands like “playerctl play-pause” control Fermata through MPRIS.'**
  String get desktopHotkeysUnsupportedWayland;

  /// No description provided for @desktopHotkeysUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'Global shortcuts aren\'t available on this platform.'**
  String get desktopHotkeysUnsupportedPlatform;

  /// No description provided for @desktopUnknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown artist'**
  String get desktopUnknownArtist;

  /// No description provided for @playerPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlay;

  /// No description provided for @playerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// No description provided for @playerNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get playerNext;

  /// No description provided for @playerPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get playerPrevious;

  /// No description provided for @playerShuffleOn.
  ///
  /// In en, this message translates to:
  /// **'Shuffle is on'**
  String get playerShuffleOn;

  /// No description provided for @playerShuffleOff.
  ///
  /// In en, this message translates to:
  /// **'Shuffle is off'**
  String get playerShuffleOff;

  /// No description provided for @playerRepeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat is off'**
  String get playerRepeatOff;

  /// No description provided for @playerRepeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeating all'**
  String get playerRepeatAll;

  /// No description provided for @playerRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeating one track'**
  String get playerRepeatOne;

  /// No description provided for @playerLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get playerLike;

  /// No description provided for @playerUnlike.
  ///
  /// In en, this message translates to:
  /// **'Remove from Liked songs'**
  String get playerUnlike;

  /// No description provided for @playerLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get playerLyrics;

  /// No description provided for @playerQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get playerQueue;

  /// No description provided for @playerArtwork.
  ///
  /// In en, this message translates to:
  /// **'Artwork'**
  String get playerArtwork;

  /// No description provided for @playerOutputDevice.
  ///
  /// In en, this message translates to:
  /// **'Output device'**
  String get playerOutputDevice;

  /// No description provided for @playerSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get playerSystemDefault;

  /// No description provided for @playerNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No other output devices found'**
  String get playerNoDevices;

  /// No description provided for @playerVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get playerVolume;

  /// No description provided for @playerMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get playerMute;

  /// No description provided for @playerUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get playerUnmute;

  /// No description provided for @playerSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playerSpeed;

  /// No description provided for @playerSpeedValue.
  ///
  /// In en, this message translates to:
  /// **'{speed}×'**
  String playerSpeedValue(String speed);

  /// No description provided for @playerSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get playerSleepTimer;

  /// No description provided for @playerSleepOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get playerSleepOff;

  /// No description provided for @playerSleepMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute} other{{minutes} minutes}}'**
  String playerSleepMinutes(int minutes);

  /// No description provided for @playerSleepEndOfTrack.
  ///
  /// In en, this message translates to:
  /// **'End of track'**
  String get playerSleepEndOfTrack;

  /// No description provided for @playerSleepRemaining.
  ///
  /// In en, this message translates to:
  /// **'Pauses in {time}'**
  String playerSleepRemaining(String time);

  /// No description provided for @playerSleepAtEndOfTrack.
  ///
  /// In en, this message translates to:
  /// **'Pauses after this track'**
  String get playerSleepAtEndOfTrack;

  /// No description provided for @playerMiniPlayer.
  ///
  /// In en, this message translates to:
  /// **'Mini player'**
  String get playerMiniPlayer;

  /// No description provided for @playerExitMiniPlayer.
  ///
  /// In en, this message translates to:
  /// **'Back to full window'**
  String get playerExitMiniPlayer;

  /// No description provided for @playerAlwaysOnTop.
  ///
  /// In en, this message translates to:
  /// **'Keep on top'**
  String get playerAlwaysOnTop;

  /// No description provided for @playerNothingPlaying.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get playerNothingPlaying;

  /// No description provided for @playerNothingPlayingHint.
  ///
  /// In en, this message translates to:
  /// **'Pick an album, playlist or track to start listening.'**
  String get playerNothingPlayingHint;

  /// No description provided for @playerSeek.
  ///
  /// In en, this message translates to:
  /// **'Playback position'**
  String get playerSeek;

  /// No description provided for @playerElapsed.
  ///
  /// In en, this message translates to:
  /// **'{time} elapsed'**
  String playerElapsed(String time);

  /// No description provided for @playerRemaining.
  ///
  /// In en, this message translates to:
  /// **'{time} remaining'**
  String playerRemaining(String time);

  /// No description provided for @playerOpenNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Open now playing'**
  String get playerOpenNowPlaying;

  /// No description provided for @playerCloseNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Close now playing'**
  String get playerCloseNowPlaying;

  /// No description provided for @playerPlayingFrom.
  ///
  /// In en, this message translates to:
  /// **'Playing from {origin}'**
  String playerPlayingFrom(String origin);

  /// No description provided for @playerAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get playerAddToPlaylist;

  /// No description provided for @playerDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get playerDownload;

  /// No description provided for @playerDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get playerDownloaded;

  /// No description provided for @playerOpenOn.
  ///
  /// In en, this message translates to:
  /// **'Open on {provider}'**
  String playerOpenOn(String provider);

  /// No description provided for @playerUploaderOn.
  ///
  /// In en, this message translates to:
  /// **'Uploader on {provider}'**
  String playerUploaderOn(String provider);

  /// No description provided for @playerCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get playerCopyLink;

  /// No description provided for @playerMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get playerMore;

  /// No description provided for @playerChipPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get playerChipPreview;

  /// No description provided for @playerChipYourFile.
  ///
  /// In en, this message translates to:
  /// **'Your file'**
  String get playerChipYourFile;

  /// No description provided for @playerChipDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get playerChipDownloaded;

  /// No description provided for @playerPreviewFrom.
  ///
  /// In en, this message translates to:
  /// **'{seconds}-second preview · {provider}'**
  String playerPreviewFrom(int seconds, String provider);

  /// No description provided for @playerUnplayable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t play this track'**
  String get playerUnplayable;

  /// No description provided for @playerSkippedUnplayable.
  ///
  /// In en, this message translates to:
  /// **'Skipped a track that can\'t be played'**
  String get playerSkippedUnplayable;

  /// No description provided for @playerShowArtwork.
  ///
  /// In en, this message translates to:
  /// **'Show artwork'**
  String get playerShowArtwork;

  /// No description provided for @playerShowLyrics.
  ///
  /// In en, this message translates to:
  /// **'Show lyrics'**
  String get playerShowLyrics;

  /// No description provided for @playerShowQueue.
  ///
  /// In en, this message translates to:
  /// **'Show queue'**
  String get playerShowQueue;

  /// No description provided for @playerLyricsAttribution.
  ///
  /// In en, this message translates to:
  /// **'Lyrics: {provider}'**
  String playerLyricsAttribution(String provider);

  /// No description provided for @playerLyricsNotFound.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found for this track.'**
  String get playerLyricsNotFound;

  /// No description provided for @playerLyricsInstrumental.
  ///
  /// In en, this message translates to:
  /// **'Instrumental'**
  String get playerLyricsInstrumental;

  /// No description provided for @playerLyricsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Lyrics are turned off in Settings.'**
  String get playerLyricsDisabled;

  /// No description provided for @playerLyricsError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load lyrics.'**
  String get playerLyricsError;

  /// No description provided for @playerLyricsSeekTo.
  ///
  /// In en, this message translates to:
  /// **'Jump to this line'**
  String get playerLyricsSeekTo;

  /// No description provided for @playerQueueNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get playerQueueNowPlaying;

  /// No description provided for @playerQueueUpNext.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get playerQueueUpNext;

  /// No description provided for @playerQueueHistory.
  ///
  /// In en, this message translates to:
  /// **'Played earlier'**
  String get playerQueueHistory;

  /// No description provided for @playerQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your queue is empty'**
  String get playerQueueEmpty;

  /// No description provided for @playerQueueEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Play an album, playlist or track and it shows up here.'**
  String get playerQueueEmptyHint;

  /// No description provided for @playerQueueClear.
  ///
  /// In en, this message translates to:
  /// **'Clear queue'**
  String get playerQueueClear;

  /// No description provided for @playerQueueClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the queue?'**
  String get playerQueueClearTitle;

  /// No description provided for @playerQueueClearMessage.
  ///
  /// In en, this message translates to:
  /// **'All upcoming tracks are removed. The current track keeps playing.'**
  String get playerQueueClearMessage;

  /// No description provided for @playerQueueRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get playerQueueRemove;

  /// No description provided for @playerQueuePlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get playerQueuePlayNext;

  /// No description provided for @playerQueueSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get playerQueueSuggested;

  /// No description provided for @playerQueueRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from queue'**
  String get playerQueueRemoved;

  /// No description provided for @playerQueueReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get playerQueueReorder;

  /// No description provided for @playerQueueCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tracks} =1{1 track} other{{count} tracks}}'**
  String playerQueueCount(int count);

  /// No description provided for @playerOriginSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get playerOriginSearch;

  /// No description provided for @playerOriginSmartQueue.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get playerOriginSmartQueue;

  /// No description provided for @playerOriginLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your library'**
  String get playerOriginLibrary;

  /// No description provided for @playerOriginFavorites.
  ///
  /// In en, this message translates to:
  /// **'Liked songs'**
  String get playerOriginFavorites;

  /// No description provided for @playerSiloTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a new queue?'**
  String get playerSiloTitle;

  /// No description provided for @playerSiloMessage.
  ///
  /// In en, this message translates to:
  /// **'SoundCloud tracks play in their own queue (SoundCloud\'s terms). Start a new queue?'**
  String get playerSiloMessage;

  /// No description provided for @playerSiloConfirm.
  ///
  /// In en, this message translates to:
  /// **'Start new queue'**
  String get playerSiloConfirm;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearchHint;

  /// No description provided for @settingsSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No settings match “{query}”.'**
  String settingsSearchNoResults(String query);

  /// No description provided for @settingsRestoreAll.
  ///
  /// In en, this message translates to:
  /// **'Restore all defaults'**
  String get settingsRestoreAll;

  /// No description provided for @settingsRestoreAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore all settings?'**
  String get settingsRestoreAllTitle;

  /// No description provided for @settingsRestoreAllBody.
  ///
  /// In en, this message translates to:
  /// **'Every setting goes back to its default. Your library, playlists, connected accounts and download folder are kept.'**
  String get settingsRestoreAllBody;

  /// No description provided for @settingsRestoreSection.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults for this section'**
  String get settingsRestoreSection;

  /// No description provided for @settingsRestoreSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore “{section}” defaults?'**
  String settingsRestoreSectionTitle(String section);

  /// No description provided for @settingsRestoreSectionBody.
  ///
  /// In en, this message translates to:
  /// **'The settings in this section go back to their defaults.'**
  String get settingsRestoreSectionBody;

  /// No description provided for @settingsRestoredToast.
  ///
  /// In en, this message translates to:
  /// **'Defaults restored'**
  String get settingsRestoredToast;

  /// No description provided for @settingsBack.
  ///
  /// In en, this message translates to:
  /// **'Back to settings'**
  String get settingsBack;

  /// No description provided for @settingsSectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This section isn\'t available on this device.'**
  String get settingsSectionUnavailable;

  /// No description provided for @settingsOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingsOn;

  /// No description provided for @settingsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsOff;

  /// No description provided for @settingsValueFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get settingsValueFull;

  /// No description provided for @settingsValueReduced.
  ///
  /// In en, this message translates to:
  /// **'Reduced'**
  String get settingsValueReduced;

  /// No description provided for @settingsValueLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get settingsValueLow;

  /// No description provided for @settingsValueMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsValueMedium;

  /// No description provided for @settingsValueHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get settingsValueHigh;

  /// No description provided for @settingsValueNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get settingsValueNormal;

  /// No description provided for @settingsValueLossless.
  ///
  /// In en, this message translates to:
  /// **'Lossless'**
  String get settingsValueLossless;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get settingsSaved;

  /// No description provided for @settingsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get settingsNotAvailable;

  /// No description provided for @settingsOpenLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link.'**
  String get settingsOpenLinkFailed;

  /// No description provided for @settingsSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {location}'**
  String settingsSavedTo(String location);

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsAccent.
  ///
  /// In en, this message translates to:
  /// **'Accent colour'**
  String get settingsAccent;

  /// No description provided for @settingsAccentGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get settingsAccentGold;

  /// No description provided for @settingsAccentCoral.
  ///
  /// In en, this message translates to:
  /// **'Coral'**
  String get settingsAccentCoral;

  /// No description provided for @settingsAccentMint.
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get settingsAccentMint;

  /// No description provided for @settingsAccentIce.
  ///
  /// In en, this message translates to:
  /// **'Ice'**
  String get settingsAccentIce;

  /// No description provided for @settingsAccentMono.
  ///
  /// In en, this message translates to:
  /// **'Monochrome'**
  String get settingsAccentMono;

  /// No description provided for @settingsDensity.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get settingsDensity;

  /// No description provided for @settingsDensityComfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get settingsDensityComfortable;

  /// No description provided for @settingsDensityCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get settingsDensityCompact;

  /// No description provided for @settingsArtworkBackdrop.
  ///
  /// In en, this message translates to:
  /// **'Artwork backdrop'**
  String get settingsArtworkBackdrop;

  /// No description provided for @settingsArtworkBackdropHint.
  ///
  /// In en, this message translates to:
  /// **'Shows a soft, tinted version of the cover behind Now Playing.'**
  String get settingsArtworkBackdropHint;

  /// No description provided for @settingsHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get settingsHighContrast;

  /// No description provided for @settingsHighContrastHint.
  ///
  /// In en, this message translates to:
  /// **'Stronger text, borders and accent colours.'**
  String get settingsHighContrastHint;

  /// No description provided for @settingsGlassIntro.
  ///
  /// In en, this message translates to:
  /// **'An optional glass-inspired look: the sidebar, player and sheets become translucent and let your artwork shine through. Text always stays readable.'**
  String get settingsGlassIntro;

  /// No description provided for @settingsGlassToggle.
  ///
  /// In en, this message translates to:
  /// **'Liquid Glass'**
  String get settingsGlassToggle;

  /// No description provided for @settingsGlassToggleHint.
  ///
  /// In en, this message translates to:
  /// **'Off by default. Translucent surfaces with a soft blur.'**
  String get settingsGlassToggleHint;

  /// No description provided for @settingsGlassIntensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get settingsGlassIntensity;

  /// No description provided for @settingsGlassIntensityHint.
  ///
  /// In en, this message translates to:
  /// **'How much of the background shows through.'**
  String get settingsGlassIntensityHint;

  /// No description provided for @settingsGlassIntensityDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on Liquid Glass to adjust the intensity.'**
  String get settingsGlassIntensityDisabled;

  /// No description provided for @settingsGlassBlurOff.
  ///
  /// In en, this message translates to:
  /// **'Blur is turned off by the current performance mode, so glass will use a lighter translucent style.'**
  String get settingsGlassBlurOff;

  /// No description provided for @settingsGlassReadability.
  ///
  /// In en, this message translates to:
  /// **'Fermata raises the opacity of glass surfaces automatically whenever that is needed to keep text readable.'**
  String get settingsGlassReadability;

  /// No description provided for @settingsSecondsShort.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String settingsSecondsShort(int seconds);

  /// No description provided for @settingsTransitionsGroup.
  ///
  /// In en, this message translates to:
  /// **'Transitions'**
  String get settingsTransitionsGroup;

  /// No description provided for @settingsCrossfade.
  ///
  /// In en, this message translates to:
  /// **'Crossfade'**
  String get settingsCrossfade;

  /// No description provided for @settingsCrossfadeHint.
  ///
  /// In en, this message translates to:
  /// **'Blend the end of a track into the next one.'**
  String get settingsCrossfadeHint;

  /// No description provided for @settingsGapless.
  ///
  /// In en, this message translates to:
  /// **'Gapless playback'**
  String get settingsGapless;

  /// No description provided for @settingsGaplessHint.
  ///
  /// In en, this message translates to:
  /// **'No silence between tracks that belong together, like live albums.'**
  String get settingsGaplessHint;

  /// No description provided for @settingsGaplessCrossfadeNote.
  ///
  /// In en, this message translates to:
  /// **'Not used while crossfade is on — crossfade already joins the tracks.'**
  String get settingsGaplessCrossfadeNote;

  /// No description provided for @settingsPreviousThreshold.
  ///
  /// In en, this message translates to:
  /// **'Restart before going back'**
  String get settingsPreviousThreshold;

  /// No description provided for @settingsPreviousThresholdHint.
  ///
  /// In en, this message translates to:
  /// **'“Previous” restarts the track when more than {seconds} s have played.'**
  String settingsPreviousThresholdHint(int seconds);

  /// No description provided for @settingsPreviousThresholdAlways.
  ///
  /// In en, this message translates to:
  /// **'“Previous” always goes to the previous track.'**
  String get settingsPreviousThresholdAlways;

  /// No description provided for @settingsVolumeGroup.
  ///
  /// In en, this message translates to:
  /// **'Volume & speed'**
  String get settingsVolumeGroup;

  /// No description provided for @settingsNormalize.
  ///
  /// In en, this message translates to:
  /// **'Volume normalization'**
  String get settingsNormalize;

  /// No description provided for @settingsNormalizeHint.
  ///
  /// In en, this message translates to:
  /// **'Plays tracks at a similar loudness.'**
  String get settingsNormalizeHint;

  /// No description provided for @settingsNormalizationMode.
  ///
  /// In en, this message translates to:
  /// **'Normalization method'**
  String get settingsNormalizationMode;

  /// No description provided for @settingsNormalizationModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn on volume normalization first.'**
  String get settingsNormalizationModeDisabled;

  /// No description provided for @settingsNormalizationTrack.
  ///
  /// In en, this message translates to:
  /// **'ReplayGain (track)'**
  String get settingsNormalizationTrack;

  /// No description provided for @settingsNormalizationTrackHint.
  ///
  /// In en, this message translates to:
  /// **'Uses the loudness information stored in each file.'**
  String get settingsNormalizationTrackHint;

  /// No description provided for @settingsNormalizationAlbum.
  ///
  /// In en, this message translates to:
  /// **'ReplayGain (album)'**
  String get settingsNormalizationAlbum;

  /// No description provided for @settingsNormalizationAlbumHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps the intended differences between tracks of one album.'**
  String get settingsNormalizationAlbumHint;

  /// No description provided for @settingsNormalizationLoudness.
  ///
  /// In en, this message translates to:
  /// **'Loudness (EBU R128)'**
  String get settingsNormalizationLoudness;

  /// No description provided for @settingsNormalizationLoudnessHint.
  ///
  /// In en, this message translates to:
  /// **'Measures loudness while playing; works for streams without tags.'**
  String get settingsNormalizationLoudnessHint;

  /// No description provided for @settingsPreamp.
  ///
  /// In en, this message translates to:
  /// **'Pre-amplification'**
  String get settingsPreamp;

  /// No description provided for @settingsPreampHint.
  ///
  /// In en, this message translates to:
  /// **'Extra gain applied on top of normalization.'**
  String get settingsPreampHint;

  /// No description provided for @settingsSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get settingsSpeed;

  /// No description provided for @settingsSpeedHint.
  ///
  /// In en, this message translates to:
  /// **'Applies now and is remembered for next time.'**
  String get settingsSpeedHint;

  /// No description provided for @settingsStartupQueueGroup.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get settingsStartupQueueGroup;

  /// No description provided for @settingsRestoreQueue.
  ///
  /// In en, this message translates to:
  /// **'Restore queue on startup'**
  String get settingsRestoreQueue;

  /// No description provided for @settingsRestoreQueueHint.
  ///
  /// In en, this message translates to:
  /// **'Continue where you left off, including the position in the track.'**
  String get settingsRestoreQueueHint;

  /// No description provided for @settingsAutoplay.
  ///
  /// In en, this message translates to:
  /// **'Start playing on startup'**
  String get settingsAutoplay;

  /// No description provided for @settingsAutoplayHint.
  ///
  /// In en, this message translates to:
  /// **'Resume the restored queue as soon as Fermata opens.'**
  String get settingsAutoplayHint;

  /// No description provided for @settingsAutoplayDisabled.
  ///
  /// In en, this message translates to:
  /// **'Needs “Restore queue on startup”.'**
  String get settingsAutoplayDisabled;

  /// No description provided for @settingsSmartQueue.
  ///
  /// In en, this message translates to:
  /// **'Smart queue'**
  String get settingsSmartQueue;

  /// No description provided for @settingsSmartQueueHint.
  ///
  /// In en, this message translates to:
  /// **'When the queue runs out, add similar tracks.'**
  String get settingsSmartQueueHint;

  /// No description provided for @settingsSkipUnplayable.
  ///
  /// In en, this message translates to:
  /// **'Skip unplayable tracks'**
  String get settingsSkipUnplayable;

  /// No description provided for @settingsSkipUnplayableHint.
  ///
  /// In en, this message translates to:
  /// **'Move on automatically when a track can\'t be played, and tell you why.'**
  String get settingsSkipUnplayableHint;

  /// No description provided for @settingsExtrasGroup.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer & lyrics'**
  String get settingsExtrasGroup;

  /// No description provided for @settingsSleepFade.
  ///
  /// In en, this message translates to:
  /// **'Fade out at sleep timer'**
  String get settingsSleepFade;

  /// No description provided for @settingsSleepFadeHint.
  ///
  /// In en, this message translates to:
  /// **'Lower the volume gently before the sleep timer pauses.'**
  String get settingsSleepFadeHint;

  /// No description provided for @settingsLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get settingsLyrics;

  /// No description provided for @settingsLyricsHint.
  ///
  /// In en, this message translates to:
  /// **'Look up lyrics on LRCLIB and read lyrics stored in your files.'**
  String get settingsLyricsHint;

  /// No description provided for @settingsInterruptionsGroup.
  ///
  /// In en, this message translates to:
  /// **'Headphones & interruptions'**
  String get settingsInterruptionsGroup;

  /// No description provided for @settingsPauseOnDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Pause when headphones disconnect'**
  String get settingsPauseOnDisconnect;

  /// No description provided for @settingsPauseOnDisconnectHint.
  ///
  /// In en, this message translates to:
  /// **'Stops the music from suddenly playing through the speaker.'**
  String get settingsPauseOnDisconnectHint;

  /// No description provided for @settingsResumeAfterInterruption.
  ///
  /// In en, this message translates to:
  /// **'Resume after interruptions'**
  String get settingsResumeAfterInterruption;

  /// No description provided for @settingsResumeAfterInterruptionHint.
  ///
  /// In en, this message translates to:
  /// **'Continue after a call or another app\'s sound has finished.'**
  String get settingsResumeAfterInterruptionHint;

  /// No description provided for @settingsDuck.
  ///
  /// In en, this message translates to:
  /// **'Lower volume for short sounds'**
  String get settingsDuck;

  /// No description provided for @settingsDuckHint.
  ///
  /// In en, this message translates to:
  /// **'Navigation prompts and notifications play over quieter music instead of pausing it.'**
  String get settingsDuckHint;

  /// No description provided for @settingsQualityIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose how good streams and downloads should sound. Higher quality uses more data and storage.'**
  String get settingsQualityIntro;

  /// No description provided for @settingStreamingQuality.
  ///
  /// In en, this message translates to:
  /// **'Streaming quality'**
  String get settingStreamingQuality;

  /// No description provided for @settingsStreamingQualityHint.
  ///
  /// In en, this message translates to:
  /// **'On Wi-Fi and wired connections.'**
  String get settingsStreamingQualityHint;

  /// No description provided for @settingsMobileQuality.
  ///
  /// In en, this message translates to:
  /// **'Mobile data quality'**
  String get settingsMobileQuality;

  /// No description provided for @settingsMobileQualityHint.
  ///
  /// In en, this message translates to:
  /// **'On mobile data and other metered connections.'**
  String get settingsMobileQualityHint;

  /// No description provided for @settingsDownloadQuality.
  ///
  /// In en, this message translates to:
  /// **'Download quality'**
  String get settingsDownloadQuality;

  /// No description provided for @settingsDownloadQualityHint.
  ///
  /// In en, this message translates to:
  /// **'For tracks a source allows you to download.'**
  String get settingsDownloadQualityHint;

  /// No description provided for @settingsQualityProviders.
  ///
  /// In en, this message translates to:
  /// **'Each provider decides which qualities it offers. Fermata uses the closest available quality, which can be lower than your choice — Deezer, for example, only offers 30-second previews.'**
  String get settingsQualityProviders;

  /// No description provided for @settingsOutputGroup.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get settingsOutputGroup;

  /// No description provided for @settingsOutputDevice.
  ///
  /// In en, this message translates to:
  /// **'Output device'**
  String get settingsOutputDevice;

  /// No description provided for @settingsOutputDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Where Fermata plays its sound.'**
  String get settingsOutputDeviceHint;

  /// No description provided for @settingsOutputDeviceSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsOutputDeviceSystem;

  /// No description provided for @settingsOutputDeviceDefault.
  ///
  /// In en, this message translates to:
  /// **'{name} (default)'**
  String settingsOutputDeviceDefault(String name);

  /// No description provided for @settingsOutputDevicesFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t list the output devices.'**
  String get settingsOutputDevicesFailed;

  /// No description provided for @settingsOutputDeviceFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t switch to this output device.'**
  String get settingsOutputDeviceFailed;

  /// No description provided for @settingsDownloadFolder.
  ///
  /// In en, this message translates to:
  /// **'Download folder'**
  String get settingsDownloadFolder;

  /// No description provided for @settingsDownloadFolderChange.
  ///
  /// In en, this message translates to:
  /// **'Change…'**
  String get settingsDownloadFolderChange;

  /// No description provided for @settingsDownloadFolderMoving.
  ///
  /// In en, this message translates to:
  /// **'Moving…'**
  String get settingsDownloadFolderMoving;

  /// No description provided for @settingsDownloadFolderPick.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder for downloads'**
  String get settingsDownloadFolderPick;

  /// No description provided for @settingsDownloadFolderMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Move downloads?'**
  String get settingsDownloadFolderMoveTitle;

  /// No description provided for @settingsDownloadFolderMoveBody.
  ///
  /// In en, this message translates to:
  /// **'Your downloaded tracks will be moved to {path}. This can take a while for large collections; you can keep listening meanwhile.'**
  String settingsDownloadFolderMoveBody(String path);

  /// No description provided for @settingsDownloadFolderMove.
  ///
  /// In en, this message translates to:
  /// **'Move downloads'**
  String get settingsDownloadFolderMove;

  /// No description provided for @settingsDownloadFolderMoved.
  ///
  /// In en, this message translates to:
  /// **'Downloads moved'**
  String get settingsDownloadFolderMoved;

  /// No description provided for @settingsDownloadFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t move the downloads. Nothing was changed.'**
  String get settingsDownloadFolderFailed;

  /// No description provided for @settingsDownloadFolderFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t move the downloads: {detail}'**
  String settingsDownloadFolderFailedDetail(String detail);

  /// No description provided for @settingWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Download on Wi-Fi only'**
  String get settingWifiOnly;

  /// No description provided for @settingsWifiOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Downloads wait for Wi-Fi or a wired connection.'**
  String get settingsWifiOnlyHint;

  /// No description provided for @settingsWarnMobile.
  ///
  /// In en, this message translates to:
  /// **'Warn before using mobile data'**
  String get settingsWarnMobile;

  /// No description provided for @settingsWarnMobileHint.
  ///
  /// In en, this message translates to:
  /// **'Ask before a download starts on a metered connection.'**
  String get settingsWarnMobileHint;

  /// No description provided for @settingsWarnMobileDisabled.
  ///
  /// In en, this message translates to:
  /// **'Not needed while downloads wait for Wi-Fi.'**
  String get settingsWarnMobileDisabled;

  /// No description provided for @settingsMaxConcurrent.
  ///
  /// In en, this message translates to:
  /// **'Simultaneous downloads'**
  String get settingsMaxConcurrent;

  /// No description provided for @settingsMaxConcurrentHint.
  ///
  /// In en, this message translates to:
  /// **'How many tracks download at the same time.'**
  String get settingsMaxConcurrentHint;

  /// No description provided for @settingsVerifyIntegrity.
  ///
  /// In en, this message translates to:
  /// **'Verify downloads'**
  String get settingsVerifyIntegrity;

  /// No description provided for @settingsVerifyIntegrityHint.
  ///
  /// In en, this message translates to:
  /// **'Check every finished file before it\'s used, so a broken download never plays.'**
  String get settingsVerifyIntegrityHint;

  /// No description provided for @settingsNotifyComplete.
  ///
  /// In en, this message translates to:
  /// **'Notify when downloads finish'**
  String get settingsNotifyComplete;

  /// No description provided for @settingsNotifyCompleteHint.
  ///
  /// In en, this message translates to:
  /// **'A system notification when a batch of downloads is done.'**
  String get settingsNotifyCompleteHint;

  /// No description provided for @settingsNotificationsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'System notifications aren\'t available on this device; Fermata shows the progress in the app instead.'**
  String get settingsNotificationsUnsupported;

  /// No description provided for @settingsOfflineGroup.
  ///
  /// In en, this message translates to:
  /// **'What can be offline'**
  String get settingsOfflineGroup;

  /// No description provided for @settingsOfflineIntro.
  ///
  /// In en, this message translates to:
  /// **'Every track belongs to one of four categories. Fermata follows each provider\'s terms and never stores streams as files.'**
  String get settingsOfflineIntro;

  /// No description provided for @settingsOfflineUserOwned.
  ///
  /// In en, this message translates to:
  /// **'Music files you added from your own folders. Always available offline.'**
  String get settingsOfflineUserOwned;

  /// No description provided for @settingsOfflineDownloadable.
  ///
  /// In en, this message translates to:
  /// **'The provider allows downloading this track (for example Audius or Jamendo tracks the artist made downloadable). You start each download yourself.'**
  String get settingsOfflineDownloadable;

  /// No description provided for @settingsOfflineStreamOnly.
  ///
  /// In en, this message translates to:
  /// **'Can be played while you\'re online, but the provider doesn\'t allow storing it — SoundCloud, for example.'**
  String get settingsOfflineStreamOnly;

  /// No description provided for @settingsOfflineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be made available offline at all, such as previews or tracks that only play in the provider\'s own app.'**
  String get settingsOfflineUnavailable;

  /// No description provided for @settingsAutoDownloadNote.
  ///
  /// In en, this message translates to:
  /// **'Automatic downloads (for example for a whole playlist) only include sources that permit them: your own files. None of the streaming providers currently allow automatic downloads.'**
  String get settingsAutoDownloadNote;

  /// No description provided for @settingsUsageGroup.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get settingsUsageGroup;

  /// No description provided for @settingsUsageFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t calculate the storage usage.'**
  String get settingsUsageFailed;

  /// No description provided for @settingsUsageTotal.
  ///
  /// In en, this message translates to:
  /// **'{size} used by Fermata'**
  String settingsUsageTotal(String size);

  /// No description provided for @settingsUsageFree.
  ///
  /// In en, this message translates to:
  /// **'{size} free on this disk'**
  String settingsUsageFree(String size);

  /// No description provided for @settingsUsageDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads ({count})'**
  String settingsUsageDownloads(int count);

  /// No description provided for @settingsUsageArtwork.
  ///
  /// In en, this message translates to:
  /// **'Artwork cache'**
  String get settingsUsageArtwork;

  /// No description provided for @settingsUsageStreamCache.
  ///
  /// In en, this message translates to:
  /// **'Stream cache'**
  String get settingsUsageStreamCache;

  /// No description provided for @settingsUsageDatabase.
  ///
  /// In en, this message translates to:
  /// **'Library database'**
  String get settingsUsageDatabase;

  /// No description provided for @settingsUsageLimit.
  ///
  /// In en, this message translates to:
  /// **'Downloads use {used} of {limit}'**
  String settingsUsageLimit(String used, String limit);

  /// No description provided for @settingsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get settingsRefresh;

  /// No description provided for @settingsLimitsGroup.
  ///
  /// In en, this message translates to:
  /// **'Limits'**
  String get settingsLimitsGroup;

  /// No description provided for @settingsDownloadLimit.
  ///
  /// In en, this message translates to:
  /// **'Download storage limit'**
  String get settingsDownloadLimit;

  /// No description provided for @settingsDownloadLimitHint.
  ///
  /// In en, this message translates to:
  /// **'The most space downloads may use.'**
  String get settingsDownloadLimitHint;

  /// No description provided for @settingsUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get settingsUnlimited;

  /// No description provided for @settingsAutoCleanup.
  ///
  /// In en, this message translates to:
  /// **'Clean up automatically'**
  String get settingsAutoCleanup;

  /// No description provided for @settingsAutoCleanupHint.
  ///
  /// In en, this message translates to:
  /// **'When the limit is reached, remove the downloads you played least recently.'**
  String get settingsAutoCleanupHint;

  /// No description provided for @settingsAutoCleanupDisabled.
  ///
  /// In en, this message translates to:
  /// **'Set a storage limit to use automatic clean-up.'**
  String get settingsAutoCleanupDisabled;

  /// No description provided for @settingsArtworkCache.
  ///
  /// In en, this message translates to:
  /// **'Artwork cache size'**
  String get settingsArtworkCache;

  /// No description provided for @settingsArtworkCacheHint.
  ///
  /// In en, this message translates to:
  /// **'Covers are kept so they load instantly and work offline.'**
  String get settingsArtworkCacheHint;

  /// No description provided for @settingsMaintenanceGroup.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get settingsMaintenanceGroup;

  /// No description provided for @settingsCleanUpNow.
  ///
  /// In en, this message translates to:
  /// **'Clean up now'**
  String get settingsCleanUpNow;

  /// No description provided for @settingsCleanUpNowHint.
  ///
  /// In en, this message translates to:
  /// **'Apply the storage limit right away.'**
  String get settingsCleanUpNowHint;

  /// No description provided for @settingsCleanUpNowAction.
  ///
  /// In en, this message translates to:
  /// **'Clean up'**
  String get settingsCleanUpNowAction;

  /// No description provided for @settingsNothingToClean.
  ///
  /// In en, this message translates to:
  /// **'Nothing to clean up — you\'re within the limit.'**
  String get settingsNothingToClean;

  /// No description provided for @settingsFreed.
  ///
  /// In en, this message translates to:
  /// **'Freed {size}'**
  String settingsFreed(String size);

  /// No description provided for @settingsClearArtwork.
  ///
  /// In en, this message translates to:
  /// **'Clear artwork cache'**
  String get settingsClearArtwork;

  /// No description provided for @settingsClearArtworkHint.
  ///
  /// In en, this message translates to:
  /// **'Covers will be downloaded again when needed.'**
  String get settingsClearArtworkHint;

  /// No description provided for @settingsClearArtworkAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClearArtworkAction;

  /// No description provided for @settingsVerifyDownloads.
  ///
  /// In en, this message translates to:
  /// **'Verify downloads'**
  String get settingsVerifyDownloads;

  /// No description provided for @settingsVerifyDownloadsHint.
  ///
  /// In en, this message translates to:
  /// **'Check every downloaded file for damage.'**
  String get settingsVerifyDownloadsHint;

  /// No description provided for @settingsVerifyDownloadsAction.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get settingsVerifyDownloadsAction;

  /// No description provided for @settingsVerifyOk.
  ///
  /// In en, this message translates to:
  /// **'All downloads are intact.'**
  String get settingsVerifyOk;

  /// No description provided for @settingsVerifyBroken.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 damaged download found. Retry it on the Downloads page.} other{{count} damaged downloads found. Retry them on the Downloads page.}}'**
  String settingsVerifyBroken(int count);

  /// No description provided for @settingsMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String settingsMinutesShort(int minutes);

  /// No description provided for @settingsHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String settingsHoursShort(int hours);

  /// No description provided for @settingsModeBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get settingsModeBalanced;

  /// No description provided for @settingsModePerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get settingsModePerformance;

  /// No description provided for @settingsModeBatterySaver.
  ///
  /// In en, this message translates to:
  /// **'Battery saver'**
  String get settingsModeBatterySaver;

  /// No description provided for @settingsModeDataSaver.
  ///
  /// In en, this message translates to:
  /// **'Data saver'**
  String get settingsModeDataSaver;

  /// No description provided for @settingsModeVisualQuality.
  ///
  /// In en, this message translates to:
  /// **'Visual quality'**
  String get settingsModeVisualQuality;

  /// No description provided for @settingsModeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get settingsModeCustom;

  /// No description provided for @settingsModeBalancedHint.
  ///
  /// In en, this message translates to:
  /// **'The default: full animations, blur and medium artwork.'**
  String get settingsModeBalancedHint;

  /// No description provided for @settingsModePerformanceHint.
  ///
  /// In en, this message translates to:
  /// **'Reduces animations and turns off blur and artwork prefetching.'**
  String get settingsModePerformanceHint;

  /// No description provided for @settingsModeBatterySaverHint.
  ///
  /// In en, this message translates to:
  /// **'Turns off animations, blur, preloading and background sync, and uses smaller artwork.'**
  String get settingsModeBatterySaverHint;

  /// No description provided for @settingsModeDataSaverHint.
  ///
  /// In en, this message translates to:
  /// **'Lowers streaming quality, waits for Wi-Fi to download and stops preloading.'**
  String get settingsModeDataSaverHint;

  /// No description provided for @settingsModeVisualQualityHint.
  ///
  /// In en, this message translates to:
  /// **'Full animations, blur and the sharpest artwork.'**
  String get settingsModeVisualQualityHint;

  /// No description provided for @settingsModeCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Your own combination of the settings below.'**
  String get settingsModeCustomHint;

  /// No description provided for @settingsPerformanceIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick a mode to change several settings at once. Changing any single setting below switches to Custom.'**
  String get settingsPerformanceIntro;

  /// No description provided for @settingsActiveNow.
  ///
  /// In en, this message translates to:
  /// **'Active now: {mode}'**
  String settingsActiveNow(String mode);

  /// No description provided for @settingsActiveNowReducedMotion.
  ///
  /// In en, this message translates to:
  /// **'Your system or accessibility settings ask for reduced motion, so animations are reduced.'**
  String get settingsActiveNowReducedMotion;

  /// No description provided for @settingsGranularGroup.
  ///
  /// In en, this message translates to:
  /// **'Individual settings'**
  String get settingsGranularGroup;

  /// No description provided for @settingsGranularIntro.
  ///
  /// In en, this message translates to:
  /// **'Adjusting any of these switches the mode to Custom.'**
  String get settingsGranularIntro;

  /// No description provided for @settingAnimations.
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get settingAnimations;

  /// No description provided for @settingsAnimationsHint.
  ///
  /// In en, this message translates to:
  /// **'Transitions and motion throughout the app.'**
  String get settingsAnimationsHint;

  /// No description provided for @settingBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get settingBlur;

  /// No description provided for @settingsBlurHint.
  ///
  /// In en, this message translates to:
  /// **'Background blur for glass and Now Playing. Off uses plain translucent surfaces.'**
  String get settingsBlurHint;

  /// No description provided for @settingArtworkQuality.
  ///
  /// In en, this message translates to:
  /// **'Artwork quality'**
  String get settingArtworkQuality;

  /// No description provided for @settingsArtworkQualityHint.
  ///
  /// In en, this message translates to:
  /// **'Lower quality decodes smaller images and uses less memory.'**
  String get settingsArtworkQualityHint;

  /// No description provided for @settingPreloadNext.
  ///
  /// In en, this message translates to:
  /// **'Preload next track'**
  String get settingPreloadNext;

  /// No description provided for @settingsPreloadNextHint.
  ///
  /// In en, this message translates to:
  /// **'Prepares the next track early for seamless transitions.'**
  String get settingsPreloadNextHint;

  /// No description provided for @settingPrefetchArtwork.
  ///
  /// In en, this message translates to:
  /// **'Prefetch artwork'**
  String get settingPrefetchArtwork;

  /// No description provided for @settingsPrefetchArtworkHint.
  ///
  /// In en, this message translates to:
  /// **'Downloads covers of upcoming tracks ahead of time.'**
  String get settingsPrefetchArtworkHint;

  /// No description provided for @settingBackgroundSync.
  ///
  /// In en, this message translates to:
  /// **'Background sync'**
  String get settingBackgroundSync;

  /// No description provided for @settingsBackgroundSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Refreshes connected services, recommendations and permitted downloads periodically.'**
  String get settingsBackgroundSyncHint;

  /// No description provided for @settingsSyncInterval.
  ///
  /// In en, this message translates to:
  /// **'Sync every'**
  String get settingsSyncInterval;

  /// No description provided for @settingsSyncIntervalDisabled.
  ///
  /// In en, this message translates to:
  /// **'Background sync is off.'**
  String get settingsSyncIntervalDisabled;

  /// No description provided for @settingsSaversIntro.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts into the matching performance modes. Each one lists exactly what it changes.'**
  String get settingsSaversIntro;

  /// No description provided for @settingsSaverTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Use this mode'**
  String get settingsSaverTurnOn;

  /// No description provided for @settingsSaverTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off (back to Balanced)'**
  String get settingsSaverTurnOff;

  /// No description provided for @settingsBatterySaverNote.
  ///
  /// In en, this message translates to:
  /// **'Reduces the work Fermata does while you listen. Playback itself is not affected.'**
  String get settingsBatterySaverNote;

  /// No description provided for @settingsDataSaverNote.
  ///
  /// In en, this message translates to:
  /// **'Also sets streaming quality to Low and downloads to Wi-Fi only. Turning it off keeps those two settings; change them under Audio quality and Downloads.'**
  String get settingsDataSaverNote;

  /// No description provided for @settingsSaversAndroidNote.
  ///
  /// In en, this message translates to:
  /// **'Android\'s own battery optimization can also stop music in the background. You can allow Fermata to keep running under Background playback.'**
  String get settingsSaversAndroidNote;

  /// No description provided for @settingsSaversCustomNote.
  ///
  /// In en, this message translates to:
  /// **'Want something in between? Pick Custom under Performance and adjust each setting.'**
  String get settingsSaversCustomNote;

  /// No description provided for @settingsServicesIntro.
  ///
  /// In en, this message translates to:
  /// **'Connect the services you use. Each card says exactly what Fermata can and can\'t do with that service.'**
  String get settingsServicesIntro;

  /// No description provided for @settingsTokensNotPersistent.
  ///
  /// In en, this message translates to:
  /// **'Your system has no secure key storage (for example GNOME Keyring or KWallet), so sign-ins are only kept until Fermata closes and you\'ll need to reconnect after a restart. Install and unlock a keyring to stay signed in.'**
  String get settingsTokensNotPersistent;

  /// No description provided for @settingsNoPasswords.
  ///
  /// In en, this message translates to:
  /// **'Fermata never asks for your passwords. You sign in on the service\'s own website, and Fermata only keeps the access it was granted, in your system\'s secure storage.'**
  String get settingsNoPasswords;

  /// No description provided for @settingsStatusNotRequired.
  ///
  /// In en, this message translates to:
  /// **'No account needed'**
  String get settingsStatusNotRequired;

  /// No description provided for @settingsStatusCredentialsMissing.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get settingsStatusCredentialsMissing;

  /// No description provided for @settingsStatusNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get settingsStatusNotConnected;

  /// No description provided for @settingsStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get settingsStatusConnecting;

  /// No description provided for @settingsStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsStatusConnected;

  /// No description provided for @settingsStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Sign-in expired'**
  String get settingsStatusExpired;

  /// No description provided for @settingsStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get settingsStatusError;

  /// No description provided for @settingsStatusSemantics.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String settingsStatusSemantics(String status);

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String settingsAccount(String name);

  /// No description provided for @settingsScopes.
  ///
  /// In en, this message translates to:
  /// **'Access granted: {scopes}'**
  String settingsScopes(String scopes);

  /// No description provided for @settingsExpiredHint.
  ///
  /// In en, this message translates to:
  /// **'Your {service} sign-in has expired. Reconnect to continue.'**
  String settingsExpiredHint(String service);

  /// No description provided for @settingsErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Problem: {detail}'**
  String settingsErrorDetail(String detail);

  /// No description provided for @settingsCredentialsMissingHint.
  ///
  /// In en, this message translates to:
  /// **'{service} needs developer credentials (an app registration) before you can use it. Enter them below — they are not your account password.'**
  String settingsCredentialsMissingHint(String service);

  /// No description provided for @settingsCanSearch.
  ///
  /// In en, this message translates to:
  /// **'Search its catalog'**
  String get settingsCanSearch;

  /// No description provided for @settingsCanStream.
  ///
  /// In en, this message translates to:
  /// **'Play full tracks in Fermata'**
  String get settingsCanStream;

  /// No description provided for @settingsCanPreview.
  ///
  /// In en, this message translates to:
  /// **'Play previews in Fermata'**
  String get settingsCanPreview;

  /// No description provided for @settingsCanExternal.
  ///
  /// In en, this message translates to:
  /// **'Open tracks in {service} for playback'**
  String settingsCanExternal(String service);

  /// No description provided for @settingsCanDownload.
  ///
  /// In en, this message translates to:
  /// **'Download single tracks the artist allows'**
  String get settingsCanDownload;

  /// No description provided for @settingsCanLibrary.
  ///
  /// In en, this message translates to:
  /// **'Read your playlists and liked tracks'**
  String get settingsCanLibrary;

  /// No description provided for @settingsCanImport.
  ///
  /// In en, this message translates to:
  /// **'Import playlists'**
  String get settingsCanImport;

  /// No description provided for @settingsCanIsrc.
  ///
  /// In en, this message translates to:
  /// **'Precise matching by ISRC'**
  String get settingsCanIsrc;

  /// No description provided for @settingsCanDiscover.
  ///
  /// In en, this message translates to:
  /// **'Recommendations, charts and new releases'**
  String get settingsCanDiscover;

  /// No description provided for @settingsCantStream.
  ///
  /// In en, this message translates to:
  /// **'Can\'t play full tracks inside Fermata'**
  String get settingsCantStream;

  /// No description provided for @settingsCantDownload.
  ///
  /// In en, this message translates to:
  /// **'No downloads'**
  String get settingsCantDownload;

  /// No description provided for @settingsSiloed.
  ///
  /// In en, this message translates to:
  /// **'{service} tracks play in their own queue ({service}\'s terms)'**
  String settingsSiloed(String service);

  /// No description provided for @settingsCantLibrary.
  ///
  /// In en, this message translates to:
  /// **'No access to your account\'s library'**
  String get settingsCantLibrary;

  /// No description provided for @settingsConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get settingsConnect;

  /// No description provided for @settingsReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get settingsReconnect;

  /// No description provided for @settingsDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get settingsDisconnect;

  /// No description provided for @settingsConnectingHint.
  ///
  /// In en, this message translates to:
  /// **'Finish signing in in your browser. Fermata never sees your password.'**
  String get settingsConnectingHint;

  /// No description provided for @settingsConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to {service}'**
  String settingsConnected(String service);

  /// No description provided for @settingsConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to {service}.'**
  String settingsConnectFailed(String service);

  /// No description provided for @settingsDisconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect {service}?'**
  String settingsDisconnectTitle(String service);

  /// No description provided for @settingsDisconnectBody.
  ///
  /// In en, this message translates to:
  /// **'Fermata forgets its access to your {service} account. Imported playlists stay in your library.'**
  String settingsDisconnectBody(String service);

  /// No description provided for @settingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get settingsTerms;

  /// No description provided for @settingsCredOverride.
  ///
  /// In en, this message translates to:
  /// **'Use your own developer credentials'**
  String get settingsCredOverride;

  /// No description provided for @settingsCredTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer credentials'**
  String get settingsCredTitle;

  /// No description provided for @settingsCredIntro.
  ///
  /// In en, this message translates to:
  /// **'Values from the app you registered with {service}. They identify Fermata to {service}; your own account still signs in on {service}\'s website.'**
  String settingsCredIntro(String service);

  /// No description provided for @settingsCredOrigin.
  ///
  /// In en, this message translates to:
  /// **'Currently used: {origin}'**
  String settingsCredOrigin(String origin);

  /// No description provided for @settingsCredOriginNone.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get settingsCredOriginNone;

  /// No description provided for @settingsCredOriginBuild.
  ///
  /// In en, this message translates to:
  /// **'built into this version of Fermata'**
  String get settingsCredOriginBuild;

  /// No description provided for @settingsCredOriginFile.
  ///
  /// In en, this message translates to:
  /// **'the file {path}'**
  String settingsCredOriginFile(String path);

  /// No description provided for @settingsCredOriginUser.
  ///
  /// In en, this message translates to:
  /// **'entered by you'**
  String get settingsCredOriginUser;

  /// No description provided for @settingsCredRegister.
  ///
  /// In en, this message translates to:
  /// **'Register an app'**
  String get settingsCredRegister;

  /// No description provided for @settingsCredRedirects.
  ///
  /// In en, this message translates to:
  /// **'Redirect URIs to register'**
  String get settingsCredRedirects;

  /// No description provided for @settingsCredRedirectDesktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop (Linux and Windows)'**
  String get settingsCredRedirectDesktop;

  /// No description provided for @settingsCredRedirectAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android'**
  String get settingsCredRedirectAndroid;

  /// No description provided for @settingsCredRedirectCustom.
  ///
  /// In en, this message translates to:
  /// **'Your custom redirect URI'**
  String get settingsCredRedirectCustom;

  /// No description provided for @settingsCredClientId.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get settingsCredClientId;

  /// No description provided for @settingsCredClientSecret.
  ///
  /// In en, this message translates to:
  /// **'Client secret'**
  String get settingsCredClientSecret;

  /// No description provided for @settingsCredApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get settingsCredApiKey;

  /// No description provided for @settingsCredRedirectUri.
  ///
  /// In en, this message translates to:
  /// **'Redirect URI'**
  String get settingsCredRedirectUri;

  /// No description provided for @settingsCredOptional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get settingsCredOptional;

  /// No description provided for @settingsCredShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get settingsCredShow;

  /// No description provided for @settingsCredHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get settingsCredHide;

  /// No description provided for @settingsCredRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill in: {fields}'**
  String settingsCredRequired(String fields);

  /// No description provided for @settingsCredSaved.
  ///
  /// In en, this message translates to:
  /// **'Credentials for {service} saved'**
  String settingsCredSaved(String service);

  /// No description provided for @settingsCredSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the credentials.'**
  String get settingsCredSaveFailed;

  /// No description provided for @settingsCredRemoved.
  ///
  /// In en, this message translates to:
  /// **'Your credentials were removed'**
  String get settingsCredRemoved;

  /// No description provided for @settingsCredRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove mine'**
  String get settingsCredRemove;

  /// No description provided for @settingsCredNoPasswords.
  ///
  /// In en, this message translates to:
  /// **'Never enter your account password here.'**
  String get settingsCredNoPasswords;

  /// No description provided for @settingsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get settingsCopy;

  /// No description provided for @settingsCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get settingsCopied;

  /// No description provided for @settingsProviderOrder.
  ///
  /// In en, this message translates to:
  /// **'Provider order'**
  String get settingsProviderOrder;

  /// No description provided for @settingsProviderOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Used to order search results, to pick a stream when a track exists on several services, and as match targets for imports. Turn a service off to leave it out everywhere.'**
  String get settingsProviderOrderHint;

  /// No description provided for @settingsDragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get settingsDragToReorder;

  /// No description provided for @settingsMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get settingsMoveUp;

  /// No description provided for @settingsMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get settingsMoveDown;

  /// No description provided for @settingsSourceEnabled.
  ///
  /// In en, this message translates to:
  /// **'Use {service}'**
  String settingsSourceEnabled(String service);

  /// No description provided for @settingsPreferSoundCloud.
  ///
  /// In en, this message translates to:
  /// **'Prefer SoundCloud in discovery'**
  String get settingsPreferSoundCloud;

  /// No description provided for @settingsPreferSoundCloudHint.
  ///
  /// In en, this message translates to:
  /// **'Build mixes and recommendations from SoundCloud first when it\'s connected.'**
  String get settingsPreferSoundCloudHint;

  /// No description provided for @settingsImportIntro.
  ///
  /// In en, this message translates to:
  /// **'How Fermata finds your tracks on other services when you import a playlist. These are the defaults; you can change them for each import.'**
  String get settingsImportIntro;

  /// No description provided for @settingsReviewMode.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get settingsReviewMode;

  /// No description provided for @settingsReviewAuto.
  ///
  /// In en, this message translates to:
  /// **'Accept confident matches'**
  String get settingsReviewAuto;

  /// No description provided for @settingsReviewAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Matches above the threshold are accepted; you review the rest.'**
  String get settingsReviewAutoHint;

  /// No description provided for @settingsReviewAll.
  ///
  /// In en, this message translates to:
  /// **'Review every match'**
  String get settingsReviewAll;

  /// No description provided for @settingsReviewAllHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing is accepted until you confirm it.'**
  String get settingsReviewAllHint;

  /// No description provided for @settingsAutoAcceptThreshold.
  ///
  /// In en, this message translates to:
  /// **'Auto-accept threshold'**
  String get settingsAutoAcceptThreshold;

  /// No description provided for @settingsAutoAcceptThresholdHint.
  ///
  /// In en, this message translates to:
  /// **'How sure Fermata must be before it accepts a match by itself.'**
  String get settingsAutoAcceptThresholdHint;

  /// No description provided for @settingsAutoAcceptThresholdDisabled.
  ///
  /// In en, this message translates to:
  /// **'Only used when confident matches are accepted automatically.'**
  String get settingsAutoAcceptThresholdDisabled;

  /// No description provided for @settingsSkipUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Skip unavailable tracks'**
  String get settingsSkipUnavailable;

  /// No description provided for @settingsSkipUnavailableHint.
  ///
  /// In en, this message translates to:
  /// **'Leave out tracks that can\'t be played on any target service.'**
  String get settingsSkipUnavailableHint;

  /// No description provided for @settingsPreferredProvider.
  ///
  /// In en, this message translates to:
  /// **'Preferred service'**
  String get settingsPreferredProvider;

  /// No description provided for @settingsPreferredProviderHint.
  ///
  /// In en, this message translates to:
  /// **'When several services have the track, prefer this one.'**
  String get settingsPreferredProviderHint;

  /// No description provided for @settingsNoPreference.
  ///
  /// In en, this message translates to:
  /// **'No preference (use provider order)'**
  String get settingsNoPreference;

  /// No description provided for @settingsAllowPreviewOnly.
  ///
  /// In en, this message translates to:
  /// **'Allow preview-only matches'**
  String get settingsAllowPreviewOnly;

  /// No description provided for @settingsAllowPreviewOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Accept matches that only play a short preview, such as Deezer.'**
  String get settingsAllowPreviewOnlyHint;

  /// No description provided for @settingsImportVersionsNote.
  ///
  /// In en, this message translates to:
  /// **'A remix, live, acoustic or other version is never accepted automatically when the original was a different version.'**
  String get settingsImportVersionsNote;

  /// No description provided for @settingsImportPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Import a playlist'**
  String get settingsImportPlaylist;

  /// No description provided for @settingsNotifyTrackChange.
  ///
  /// In en, this message translates to:
  /// **'When the track changes'**
  String get settingsNotifyTrackChange;

  /// No description provided for @settingsNotifyTrackChangeHint.
  ///
  /// In en, this message translates to:
  /// **'A small desktop notification with the new track.'**
  String get settingsNotifyTrackChangeHint;

  /// No description provided for @settingsNotifyDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get settingsNotifyDownloads;

  /// No description provided for @settingsNotifyDownloadsHint.
  ///
  /// In en, this message translates to:
  /// **'When downloads finish or fail.'**
  String get settingsNotifyDownloadsHint;

  /// No description provided for @settingsMediaNotificationNote.
  ///
  /// In en, this message translates to:
  /// **'The playback controls notification is part of background playback and is always shown while music plays.'**
  String get settingsMediaNotificationNote;

  /// No description provided for @settingsPermissionGroup.
  ///
  /// In en, this message translates to:
  /// **'Permission'**
  String get settingsPermissionGroup;

  /// No description provided for @settingsNotificationPermission.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationPermission;

  /// No description provided for @settingsNotificationPermissionMissing.
  ///
  /// In en, this message translates to:
  /// **'Not allowed. Android needs your permission before Fermata can show playback controls and download messages.'**
  String get settingsNotificationPermissionMissing;

  /// No description provided for @settingsPermissionAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get settingsPermissionAllowed;

  /// No description provided for @settingsAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get settingsAllow;

  /// No description provided for @settingsOpenSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'System settings'**
  String get settingsOpenSystemSettings;

  /// No description provided for @settingsBackgroundIntro.
  ///
  /// In en, this message translates to:
  /// **'Fermata plays in a foreground service with a media notification, so music keeps going when you leave the app or lock the screen.'**
  String get settingsBackgroundIntro;

  /// No description provided for @settingsBackgroundDesktop.
  ///
  /// In en, this message translates to:
  /// **'Closing the window keeps the music playing. Fermata stays in the system tray — or minimized when there is no tray — and your media keys keep working. Choose Quit in the tray menu to stop completely.'**
  String get settingsBackgroundDesktop;

  /// No description provided for @settingsRestartRequired.
  ///
  /// In en, this message translates to:
  /// **'Restart Fermata to apply the changed background setting.'**
  String get settingsRestartRequired;

  /// No description provided for @settingsStopServiceOnPause.
  ///
  /// In en, this message translates to:
  /// **'Let Android stop playback when paused'**
  String get settingsStopServiceOnPause;

  /// No description provided for @settingsStopServiceOnPauseHint.
  ///
  /// In en, this message translates to:
  /// **'While paused, the notification can be swiped away and Android may close Fermata to save battery. Applies after restarting Fermata.'**
  String get settingsStopServiceOnPauseHint;

  /// No description provided for @settingsResumeOnHeadset.
  ///
  /// In en, this message translates to:
  /// **'Resume when headphones connect'**
  String get settingsResumeOnHeadset;

  /// No description provided for @settingsResumeOnHeadsetHint.
  ///
  /// In en, this message translates to:
  /// **'Continue playing when headphones or a Bluetooth device reconnect shortly after they were disconnected.'**
  String get settingsResumeOnHeadsetHint;

  /// No description provided for @settingsBatteryGroup.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization'**
  String get settingsBatteryGroup;

  /// No description provided for @settingsBatteryOptimized.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization is on'**
  String get settingsBatteryOptimized;

  /// No description provided for @settingsBatteryOptimizedHint.
  ///
  /// In en, this message translates to:
  /// **'Android may stop music in the background on some devices. Allowing background activity is optional and only changes this for Fermata.'**
  String get settingsBatteryOptimizedHint;

  /// No description provided for @settingsBatteryUnrestricted.
  ///
  /// In en, this message translates to:
  /// **'Background activity is allowed'**
  String get settingsBatteryUnrestricted;

  /// No description provided for @settingsBatteryUnrestrictedHint.
  ///
  /// In en, this message translates to:
  /// **'Android won\'t restrict Fermata in the background.'**
  String get settingsBatteryUnrestrictedHint;

  /// No description provided for @settingsAllowBackground.
  ///
  /// In en, this message translates to:
  /// **'Allow background activity'**
  String get settingsAllowBackground;

  /// No description provided for @settingsOemNote.
  ///
  /// In en, this message translates to:
  /// **'Some manufacturers add their own battery limits on top of Android\'s. If music still stops in the background, allow Fermata in your phone\'s battery settings as well — dontkillmyapp.com explains how for each brand.'**
  String get settingsOemNote;

  /// No description provided for @settingsCloseBehavior.
  ///
  /// In en, this message translates to:
  /// **'When closing the window'**
  String get settingsCloseBehavior;

  /// No description provided for @settingsCloseToTray.
  ///
  /// In en, this message translates to:
  /// **'Keep playing in the tray'**
  String get settingsCloseToTray;

  /// No description provided for @settingsCloseToTrayHint.
  ///
  /// In en, this message translates to:
  /// **'The window hides; music keeps playing.'**
  String get settingsCloseToTrayHint;

  /// No description provided for @settingsCloseMinimize.
  ///
  /// In en, this message translates to:
  /// **'Keep playing minimized'**
  String get settingsCloseMinimize;

  /// No description provided for @settingsCloseMinimizeHint.
  ///
  /// In en, this message translates to:
  /// **'No tray is available, so the window is minimized; music keeps playing.'**
  String get settingsCloseMinimizeHint;

  /// No description provided for @settingsCloseAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get settingsCloseAsk;

  /// No description provided for @settingsCloseAskHint.
  ///
  /// In en, this message translates to:
  /// **'Choose between keeping the music playing and quitting.'**
  String get settingsCloseAskHint;

  /// No description provided for @settingsCloseQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit Fermata'**
  String get settingsCloseQuit;

  /// No description provided for @settingsCloseQuitHint.
  ///
  /// In en, this message translates to:
  /// **'Playback stops and Fermata closes.'**
  String get settingsCloseQuitHint;

  /// No description provided for @settingsShowTrayIcon.
  ///
  /// In en, this message translates to:
  /// **'Show tray icon'**
  String get settingsShowTrayIcon;

  /// No description provided for @settingsShowTrayIconHint.
  ///
  /// In en, this message translates to:
  /// **'Quick controls and the current track in the system tray.'**
  String get settingsShowTrayIconHint;

  /// No description provided for @settingsRememberWindow.
  ///
  /// In en, this message translates to:
  /// **'Remember window size and position'**
  String get settingsRememberWindow;

  /// No description provided for @settingsRememberWindowHint.
  ///
  /// In en, this message translates to:
  /// **'Opens where you left it last time.'**
  String get settingsRememberWindowHint;

  /// No description provided for @settingsQuitNote.
  ///
  /// In en, this message translates to:
  /// **'To stop completely, choose Quit in the tray menu — or pick “Ask every time” above to get a Quit button when you close the window.'**
  String get settingsQuitNote;

  /// No description provided for @settingsLaunchAtLogin.
  ///
  /// In en, this message translates to:
  /// **'Launch at login'**
  String get settingsLaunchAtLogin;

  /// No description provided for @settingsLaunchAtLoginHint.
  ///
  /// In en, this message translates to:
  /// **'Start Fermata when you sign in to your computer.'**
  String get settingsLaunchAtLoginHint;

  /// No description provided for @settingsLaunchAtLoginUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not available on this system.'**
  String get settingsLaunchAtLoginUnsupported;

  /// No description provided for @settingsLaunchAtLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the login setting.'**
  String get settingsLaunchAtLoginFailed;

  /// No description provided for @settingsStartMinimized.
  ///
  /// In en, this message translates to:
  /// **'Start minimized'**
  String get settingsStartMinimized;

  /// No description provided for @settingsStartMinimizedHint.
  ///
  /// In en, this message translates to:
  /// **'Start in the tray (or minimized) instead of showing the window.'**
  String get settingsStartMinimizedHint;

  /// No description provided for @settingsShortcutsIntro.
  ///
  /// In en, this message translates to:
  /// **'Click a shortcut to record a new one. Conflicts are shown in red.'**
  String get settingsShortcutsIntro;

  /// No description provided for @settingsShortcutsInApp.
  ///
  /// In en, this message translates to:
  /// **'In Fermata'**
  String get settingsShortcutsInApp;

  /// No description provided for @settingsShortcutsGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global shortcuts'**
  String get settingsShortcutsGlobal;

  /// No description provided for @settingsShortcutsGlobalHint.
  ///
  /// In en, this message translates to:
  /// **'Work everywhere, even when Fermata is in the background.'**
  String get settingsShortcutsGlobalHint;

  /// No description provided for @settingsGlobalHotkeys.
  ///
  /// In en, this message translates to:
  /// **'Use global shortcuts'**
  String get settingsGlobalHotkeys;

  /// No description provided for @settingsGlobalHotkeysHint.
  ///
  /// In en, this message translates to:
  /// **'Fermata registers these keys with your desktop.'**
  String get settingsGlobalHotkeysHint;

  /// No description provided for @settingsShortcutNone.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsShortcutNone;

  /// No description provided for @settingsShortcutConflict.
  ///
  /// In en, this message translates to:
  /// **'Also used by: {actions}'**
  String settingsShortcutConflict(String actions);

  /// No description provided for @settingsShortcutChangeSemantics.
  ///
  /// In en, this message translates to:
  /// **'{action}: {binding}. Change shortcut'**
  String settingsShortcutChangeSemantics(String action, String binding);

  /// No description provided for @settingsShortcutMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get settingsShortcutMore;

  /// No description provided for @settingsShortcutChange.
  ///
  /// In en, this message translates to:
  /// **'Record new shortcut'**
  String get settingsShortcutChange;

  /// No description provided for @settingsShortcutReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get settingsShortcutReset;

  /// No description provided for @settingsShortcutRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove shortcut'**
  String get settingsShortcutRemove;

  /// No description provided for @settingsShortcutRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Shortcut for “{action}”'**
  String settingsShortcutRecordTitle(String action);

  /// No description provided for @settingsShortcutRecordHint.
  ///
  /// In en, this message translates to:
  /// **'Press the key combination you want to use. Press Esc to cancel.'**
  String get settingsShortcutRecordHint;

  /// No description provided for @settingsShortcutWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for keys…'**
  String get settingsShortcutWaiting;

  /// No description provided for @settingsShortcutNeedsModifier.
  ///
  /// In en, this message translates to:
  /// **'Global shortcuts need Ctrl, Alt, Shift or Super, otherwise they would block typing in other apps.'**
  String get settingsShortcutNeedsModifier;

  /// No description provided for @settingsFileInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t a Fermata file, or it is damaged.'**
  String get settingsFileInvalid;

  /// No description provided for @settingsRecordHistory.
  ///
  /// In en, this message translates to:
  /// **'Listening history'**
  String get settingsRecordHistory;

  /// No description provided for @settingsRecordHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Remember what you play, on this device only. Used for History, Recently played and your mixes.'**
  String get settingsRecordHistoryHint;

  /// No description provided for @settingsPersonalized.
  ///
  /// In en, this message translates to:
  /// **'Personalized recommendations'**
  String get settingsPersonalized;

  /// No description provided for @settingsPersonalizedHint.
  ///
  /// In en, this message translates to:
  /// **'Mixes and suggestions are calculated on this device from your history and favorites. Off shows only trending music, new releases and genres.'**
  String get settingsPersonalizedHint;

  /// No description provided for @settingsSaveSearches.
  ///
  /// In en, this message translates to:
  /// **'Search history'**
  String get settingsSaveSearches;

  /// No description provided for @settingsSaveSearchesHint.
  ///
  /// In en, this message translates to:
  /// **'Show your recent searches in Search.'**
  String get settingsSaveSearchesHint;

  /// No description provided for @settingsNoTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'No analytics or tracking'**
  String get settingsNoTrackingTitle;

  /// No description provided for @settingsNoTracking.
  ///
  /// In en, this message translates to:
  /// **'Fermata has no analytics, no ads, no crash reporting and no account of its own. Nothing about what you listen to leaves this device unless a service you connected needs it to play the music.'**
  String get settingsNoTracking;

  /// No description provided for @settingsNetworkIntro.
  ///
  /// In en, this message translates to:
  /// **'Fermata only connects to:'**
  String get settingsNetworkIntro;

  /// No description provided for @settingsNetworkProviders.
  ///
  /// In en, this message translates to:
  /// **'The music services you use — to search, stream, read your playlists and import. Requests go directly from this device to the service.'**
  String get settingsNetworkProviders;

  /// No description provided for @settingsNetworkLyricsOn.
  ///
  /// In en, this message translates to:
  /// **'LRCLIB, to look up lyrics for the track that is playing (title, artist, album and duration are sent).'**
  String get settingsNetworkLyricsOn;

  /// No description provided for @settingsNetworkLyricsOff.
  ///
  /// In en, this message translates to:
  /// **'LRCLIB is not contacted because lyrics are turned off.'**
  String get settingsNetworkLyricsOff;

  /// No description provided for @settingsNetworkUpdatesOn.
  ///
  /// In en, this message translates to:
  /// **'GitHub, once a day, to see whether a new version of Fermata exists. Nothing about you is sent.'**
  String get settingsNetworkUpdatesOn;

  /// No description provided for @settingsNetworkUpdatesOff.
  ///
  /// In en, this message translates to:
  /// **'GitHub only when you press “Check now” under Updates.'**
  String get settingsNetworkUpdatesOff;

  /// No description provided for @settingsNetworkArtwork.
  ///
  /// In en, this message translates to:
  /// **'The services\' image servers, to download cover art (kept in the artwork cache).'**
  String get settingsNetworkArtwork;

  /// No description provided for @settingsNetworkSignIn.
  ///
  /// In en, this message translates to:
  /// **'A service\'s own sign-in page in your browser when you connect it.'**
  String get settingsNetworkSignIn;

  /// No description provided for @settingsYourDataGroup.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsYourDataGroup;

  /// No description provided for @settingsDeleteHistory.
  ///
  /// In en, this message translates to:
  /// **'Delete listening history'**
  String get settingsDeleteHistory;

  /// No description provided for @settingsDeleteHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Removes every play from History and statistics.'**
  String get settingsDeleteHistoryHint;

  /// No description provided for @settingsDeleteHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete listening history?'**
  String get settingsDeleteHistoryTitle;

  /// No description provided for @settingsDeleteHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'History, “Recently played” and listening statistics are deleted. Your mixes will start fresh.'**
  String get settingsDeleteHistoryBody;

  /// No description provided for @settingsDeleteHistoryDone.
  ///
  /// In en, this message translates to:
  /// **'Listening history deleted'**
  String get settingsDeleteHistoryDone;

  /// No description provided for @settingsClearSearches.
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get settingsClearSearches;

  /// No description provided for @settingsClearSearchesHint.
  ///
  /// In en, this message translates to:
  /// **'Removes your recent searches.'**
  String get settingsClearSearchesHint;

  /// No description provided for @settingsClearSearchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear search history?'**
  String get settingsClearSearchesTitle;

  /// No description provided for @settingsClearSearchesBody.
  ///
  /// In en, this message translates to:
  /// **'Your recent searches are removed.'**
  String get settingsClearSearchesBody;

  /// No description provided for @settingsClearSearchesDone.
  ///
  /// In en, this message translates to:
  /// **'Search history cleared'**
  String get settingsClearSearchesDone;

  /// No description provided for @settingsClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClearAction;

  /// No description provided for @settingsExportSettings.
  ///
  /// In en, this message translates to:
  /// **'Export settings'**
  String get settingsExportSettings;

  /// No description provided for @settingsExportSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Save your settings as a file. It contains no passwords or sign-ins.'**
  String get settingsExportSettingsHint;

  /// No description provided for @settingsImportSettings.
  ///
  /// In en, this message translates to:
  /// **'Import settings'**
  String get settingsImportSettings;

  /// No description provided for @settingsImportSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Replace your settings with an exported file.'**
  String get settingsImportSettingsHint;

  /// No description provided for @settingsImportSettingsDone.
  ///
  /// In en, this message translates to:
  /// **'Settings imported'**
  String get settingsImportSettingsDone;

  /// No description provided for @settingsExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsExportAction;

  /// No description provided for @settingsImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get settingsImportAction;

  /// No description provided for @settingsBackupLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back up library'**
  String get settingsBackupLibrary;

  /// No description provided for @settingsBackupLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Playlists, favorites, history and track links as one file. Music files are not included.'**
  String get settingsBackupLibraryHint;

  /// No description provided for @settingsRestoreLibrary.
  ///
  /// In en, this message translates to:
  /// **'Restore library'**
  String get settingsRestoreLibrary;

  /// No description provided for @settingsRestoreLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Bring back a library backup.'**
  String get settingsRestoreLibraryHint;

  /// No description provided for @settingsRestoreLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore library backup?'**
  String get settingsRestoreLibraryTitle;

  /// No description provided for @settingsRestoreLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'Merge adds the backup to your current library. Replace removes your current playlists, favorites and history first.'**
  String get settingsRestoreLibraryBody;

  /// No description provided for @settingsRestoreMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get settingsRestoreMerge;

  /// No description provided for @settingsRestoreReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get settingsRestoreReplace;

  /// No description provided for @settingsRestoreLibraryDone.
  ///
  /// In en, this message translates to:
  /// **'Library restored'**
  String get settingsRestoreLibraryDone;

  /// No description provided for @settingsDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get settingsDeleteAll;

  /// No description provided for @settingsDeleteAllHint.
  ///
  /// In en, this message translates to:
  /// **'Playlists, favorites, history, searches and sign-ins. Your music files stay on disk.'**
  String get settingsDeleteAllHint;

  /// No description provided for @settingsDeleteAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all your data?'**
  String get settingsDeleteAllTitle;

  /// No description provided for @settingsDeleteAllBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes your playlists, favorites, listening and search history, track links and cached metadata, and signs you out of every service. Music files on your disk are never deleted, and your settings are kept. This can\'t be undone.'**
  String get settingsDeleteAllBody;

  /// No description provided for @settingsDeleteAllWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get settingsDeleteAllWord;

  /// No description provided for @settingsDeleteAllAction.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get settingsDeleteAllAction;

  /// No description provided for @settingsDeleteAllDone.
  ///
  /// In en, this message translates to:
  /// **'All your data was deleted'**
  String get settingsDeleteAllDone;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System language'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageSystemHint.
  ///
  /// In en, this message translates to:
  /// **'Follows your device. Languages Fermata doesn\'t have yet fall back to English.'**
  String get settingsLanguageSystemHint;

  /// No description provided for @settingsMotion.
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get settingsMotion;

  /// No description provided for @settingsMotionHint.
  ///
  /// In en, this message translates to:
  /// **'“System” follows your device\'s reduce-motion setting.'**
  String get settingsMotionHint;

  /// No description provided for @settingsMotionSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsMotionSystem;

  /// No description provided for @settingsMotionReduce.
  ///
  /// In en, this message translates to:
  /// **'Reduce'**
  String get settingsMotionReduce;

  /// No description provided for @settingsMotionFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get settingsMotionFull;

  /// No description provided for @settingsTextScale.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsTextScale;

  /// No description provided for @settingsTextScaleHint.
  ///
  /// In en, this message translates to:
  /// **'On top of your system\'s text size.'**
  String get settingsTextScaleHint;

  /// No description provided for @settingsTextScalePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Night Drive'**
  String get settingsTextScalePreviewTitle;

  /// No description provided for @settingsTextScalePreviewBody.
  ///
  /// In en, this message translates to:
  /// **'This is how titles and descriptions will look.'**
  String get settingsTextScalePreviewBody;

  /// No description provided for @settingsLargerTargets.
  ///
  /// In en, this message translates to:
  /// **'Larger touch targets'**
  String get settingsLargerTargets;

  /// No description provided for @settingsLargerTargetsHint.
  ///
  /// In en, this message translates to:
  /// **'Bigger buttons and rows that are easier to hit.'**
  String get settingsLargerTargetsHint;

  /// No description provided for @settingsAccessibilityNote.
  ///
  /// In en, this message translates to:
  /// **'Fermata works with screen readers (TalkBack, Orca, Narrator) and can be used entirely with the keyboard on desktop.'**
  String get settingsAccessibilityNote;

  /// No description provided for @settingsCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Installed version'**
  String get settingsCurrentVersion;

  /// No description provided for @settingsAutoUpdateCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates automatically'**
  String get settingsAutoUpdateCheck;

  /// No description provided for @settingsAutoUpdateCheckHint.
  ///
  /// In en, this message translates to:
  /// **'Off by default. Once a day, Fermata asks GitHub for the latest release; nothing about you is sent. Fermata never installs anything by itself.'**
  String get settingsAutoUpdateCheckHint;

  /// No description provided for @settingsCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get settingsCheckNow;

  /// No description provided for @settingsCheckNowHint.
  ///
  /// In en, this message translates to:
  /// **'Asks GitHub once for the latest release.'**
  String get settingsCheckNowHint;

  /// No description provided for @settingsCheckNowAction.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get settingsCheckNowAction;

  /// No description provided for @settingsUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date ({version}).'**
  String settingsUpToDate(String version);

  /// No description provided for @settingsUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available.'**
  String settingsUpdateAvailable(String version);

  /// No description provided for @settingsNoReleases.
  ///
  /// In en, this message translates to:
  /// **'No release has been published yet.'**
  String get settingsNoReleases;

  /// No description provided for @settingsUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates. Check your connection and try again.'**
  String get settingsUpdateFailed;

  /// No description provided for @settingsUpdateHowLinux.
  ///
  /// In en, this message translates to:
  /// **'To update, download the newer release and run its setup.sh the same way you installed Fermata. Your library, settings and sign-ins are kept.'**
  String get settingsUpdateHowLinux;

  /// No description provided for @settingsUpdateHowWindows.
  ///
  /// In en, this message translates to:
  /// **'To update, download and run the newer setup.exe. It replaces the installed version and keeps your library, settings and sign-ins.'**
  String get settingsUpdateHowWindows;

  /// No description provided for @settingsUpdateHowAndroid.
  ///
  /// In en, this message translates to:
  /// **'To update, install the newer app.apk over this one. Your data is kept.'**
  String get settingsUpdateHowAndroid;

  /// No description provided for @settingsReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get settingsReleaseNotes;

  /// No description provided for @settingsTagline.
  ///
  /// In en, this message translates to:
  /// **'A calm, local-first music player for your files and the services you use.'**
  String get settingsTagline;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get settingsPlatform;

  /// No description provided for @settingsLogFile.
  ///
  /// In en, this message translates to:
  /// **'Log file'**
  String get settingsLogFile;

  /// No description provided for @settingsExportDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Export diagnostics'**
  String get settingsExportDiagnostics;

  /// No description provided for @settingsExportDiagnosticsHint.
  ///
  /// In en, this message translates to:
  /// **'Saves recent logs and a summary of your setup to a file you can attach to a bug report. Contains no passwords, sign-ins or keys.'**
  String get settingsExportDiagnosticsHint;

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get settingsLicenses;

  /// No description provided for @settingsLicensesHint.
  ///
  /// In en, this message translates to:
  /// **'The licenses of the software Fermata is built with.'**
  String get settingsLicensesHint;

  /// No description provided for @settingsLicensesAction.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get settingsLicensesAction;

  /// No description provided for @settingsAttributions.
  ///
  /// In en, this message translates to:
  /// **'Attributions'**
  String get settingsAttributions;

  /// No description provided for @settingsAttributionSoundCloud.
  ///
  /// In en, this message translates to:
  /// **'SoundCloud: tracks and artwork are provided by SoundCloud and its creators. Each SoundCloud track links to the track and its uploader on soundcloud.com.'**
  String get settingsAttributionSoundCloud;

  /// No description provided for @settingsAttributionDeezer.
  ///
  /// In en, this message translates to:
  /// **'Deezer: catalog data and 30-second previews are provided by Deezer.'**
  String get settingsAttributionDeezer;

  /// No description provided for @settingsAttributionAudius.
  ///
  /// In en, this message translates to:
  /// **'Audius: tracks are streamed from the Audius network and belong to their artists.'**
  String get settingsAttributionAudius;

  /// No description provided for @settingsAttributionJamendo.
  ///
  /// In en, this message translates to:
  /// **'Jamendo: music is provided by Jamendo under each artist\'s Creative Commons license.'**
  String get settingsAttributionJamendo;

  /// No description provided for @settingsAttributionLrclib.
  ///
  /// In en, this message translates to:
  /// **'Lyrics: provided by LRCLIB (lrclib.net), a free community lyrics database.'**
  String get settingsAttributionLrclib;

  /// No description provided for @settingsAttributionSpotifyYouTube.
  ///
  /// In en, this message translates to:
  /// **'Spotify and YouTube Music content is shown as supplied by those services and opens in their own apps.'**
  String get settingsAttributionSpotifyYouTube;

  /// No description provided for @settingsCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get settingsCredits;

  /// No description provided for @settingsCreditsBody.
  ///
  /// In en, this message translates to:
  /// **'Made with Flutter. Typeface: Manrope (SIL Open Font License). Playback by libmpv/media_kit on desktop and ExoPlayer/just_audio on Android. Thanks to everyone who builds the open-source software listed under licenses.'**
  String get settingsCreditsBody;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get navPlaylists;

  /// No description provided for @navDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get navDownloads;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Liked songs'**
  String get navFavorites;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get navQueue;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get navNowPlaying;

  /// No description provided for @navImport.
  ///
  /// In en, this message translates to:
  /// **'Import a playlist'**
  String get navImport;

  /// No description provided for @shellYourPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Your playlists'**
  String get shellYourPlaylists;

  /// No description provided for @shellNoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get shellNoPlaylists;

  /// No description provided for @shellPageNotFound.
  ///
  /// In en, this message translates to:
  /// **'This page doesn\'t exist.'**
  String get shellPageNotFound;

  /// No description provided for @shellGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get shellGoHome;

  /// No description provided for @shellCommandPalette.
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get shellCommandPalette;

  /// No description provided for @shellLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get shellLoading;

  /// No description provided for @paletteHint.
  ///
  /// In en, this message translates to:
  /// **'Search commands, playlists and tracks'**
  String get paletteHint;

  /// No description provided for @paletteNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get paletteNoResults;

  /// No description provided for @paletteGroupNavigation.
  ///
  /// In en, this message translates to:
  /// **'Go to'**
  String get paletteGroupNavigation;

  /// No description provided for @paletteGroupPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get paletteGroupPlayer;

  /// No description provided for @paletteGroupSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get paletteGroupSettings;

  /// No description provided for @paletteGroupPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get paletteGroupPlaylists;

  /// No description provided for @paletteGroupTracks.
  ///
  /// In en, this message translates to:
  /// **'In your library'**
  String get paletteGroupTracks;

  /// No description provided for @paletteFooter.
  ///
  /// In en, this message translates to:
  /// **'Up and down to move · Enter to run · Esc to close'**
  String get paletteFooter;

  /// No description provided for @cmdPlayPause.
  ///
  /// In en, this message translates to:
  /// **'Play or pause'**
  String get cmdPlayPause;

  /// No description provided for @cmdNext.
  ///
  /// In en, this message translates to:
  /// **'Next track'**
  String get cmdNext;

  /// No description provided for @cmdPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous track'**
  String get cmdPrevious;

  /// No description provided for @cmdSeekForward.
  ///
  /// In en, this message translates to:
  /// **'Skip forward 10 seconds'**
  String get cmdSeekForward;

  /// No description provided for @cmdSeekBackward.
  ///
  /// In en, this message translates to:
  /// **'Skip back 10 seconds'**
  String get cmdSeekBackward;

  /// No description provided for @cmdVolumeUp.
  ///
  /// In en, this message translates to:
  /// **'Volume up'**
  String get cmdVolumeUp;

  /// No description provided for @cmdVolumeDown.
  ///
  /// In en, this message translates to:
  /// **'Volume down'**
  String get cmdVolumeDown;

  /// No description provided for @cmdToggleShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle on or off'**
  String get cmdToggleShuffle;

  /// No description provided for @cmdCycleRepeat.
  ///
  /// In en, this message translates to:
  /// **'Change repeat mode'**
  String get cmdCycleRepeat;

  /// No description provided for @cmdLike.
  ///
  /// In en, this message translates to:
  /// **'Like the current track'**
  String get cmdLike;

  /// No description provided for @cmdSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get cmdSearch;

  /// No description provided for @cmdCommandPalette.
  ///
  /// In en, this message translates to:
  /// **'Open the command palette'**
  String get cmdCommandPalette;

  /// No description provided for @cmdNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Show now playing'**
  String get cmdNowPlaying;

  /// No description provided for @cmdQueue.
  ///
  /// In en, this message translates to:
  /// **'Show the queue'**
  String get cmdQueue;

  /// No description provided for @cmdSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get cmdSettings;

  /// No description provided for @cmdGlobalPlayPause.
  ///
  /// In en, this message translates to:
  /// **'Play or pause (system-wide)'**
  String get cmdGlobalPlayPause;

  /// No description provided for @cmdGlobalNext.
  ///
  /// In en, this message translates to:
  /// **'Next track (system-wide)'**
  String get cmdGlobalNext;

  /// No description provided for @cmdGlobalPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous track (system-wide)'**
  String get cmdGlobalPrevious;

  /// No description provided for @cmdGlobalShowWindow.
  ///
  /// In en, this message translates to:
  /// **'Show Fermata (system-wide)'**
  String get cmdGlobalShowWindow;

  /// No description provided for @cmdMiniPlayer.
  ///
  /// In en, this message translates to:
  /// **'Mini player on or off'**
  String get cmdMiniPlayer;

  /// No description provided for @cmdClearQueue.
  ///
  /// In en, this message translates to:
  /// **'Clear the queue'**
  String get cmdClearQueue;

  /// No description provided for @cmdStop.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get cmdStop;

  /// No description provided for @shellSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance & theme'**
  String get shellSectionAppearance;

  /// No description provided for @shellSectionGlass.
  ///
  /// In en, this message translates to:
  /// **'Liquid Glass'**
  String get shellSectionGlass;

  /// No description provided for @shellSectionPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get shellSectionPlayback;

  /// No description provided for @shellSectionAudioQuality.
  ///
  /// In en, this message translates to:
  /// **'Audio quality'**
  String get shellSectionAudioQuality;

  /// No description provided for @shellSectionDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get shellSectionDownloads;

  /// No description provided for @shellSectionStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage & cache'**
  String get shellSectionStorage;

  /// No description provided for @shellSectionPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get shellSectionPerformance;

  /// No description provided for @shellSectionSavers.
  ///
  /// In en, this message translates to:
  /// **'Battery & data saver'**
  String get shellSectionSavers;

  /// No description provided for @shellSectionServices.
  ///
  /// In en, this message translates to:
  /// **'Connected services'**
  String get shellSectionServices;

  /// No description provided for @shellSectionImport.
  ///
  /// In en, this message translates to:
  /// **'Playlist import & matching'**
  String get shellSectionImport;

  /// No description provided for @shellSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get shellSectionNotifications;

  /// No description provided for @shellSectionBackground.
  ///
  /// In en, this message translates to:
  /// **'Background playback'**
  String get shellSectionBackground;

  /// No description provided for @shellSectionDesktop.
  ///
  /// In en, this message translates to:
  /// **'System tray & window'**
  String get shellSectionDesktop;

  /// No description provided for @shellSectionStartup.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get shellSectionStartup;

  /// No description provided for @shellSectionShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get shellSectionShortcuts;

  /// No description provided for @shellSectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get shellSectionPrivacy;

  /// No description provided for @shellSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get shellSectionLanguage;

  /// No description provided for @shellSectionAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get shellSectionAccessibility;

  /// No description provided for @shellSectionUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get shellSectionUpdates;

  /// No description provided for @shellSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About & diagnostics'**
  String get shellSectionAbout;

  /// No description provided for @shellErrorStorage.
  ///
  /// In en, this message translates to:
  /// **'There isn\'t enough space, or the folder can\'t be written to.'**
  String get shellErrorStorage;

  /// No description provided for @shellErrorDownloadNotPermitted.
  ///
  /// In en, this message translates to:
  /// **'This track can\'t be downloaded.'**
  String get shellErrorDownloadNotPermitted;

  /// No description provided for @shellAddedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to queue'**
  String get shellAddedToQueue;

  /// No description provided for @shellPlayingNext.
  ///
  /// In en, this message translates to:
  /// **'Plays next'**
  String get shellPlayingNext;

  /// No description provided for @shellAddedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added to {playlist}'**
  String shellAddedToPlaylist(String playlist);

  /// No description provided for @shellTracksAddedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track added to {playlist}} other{{count} tracks added to {playlist}}}'**
  String shellTracksAddedToPlaylist(int count, String playlist);

  /// No description provided for @shellLiked.
  ///
  /// In en, this message translates to:
  /// **'Added to Liked songs'**
  String get shellLiked;

  /// No description provided for @shellUnliked.
  ///
  /// In en, this message translates to:
  /// **'Removed from Liked songs'**
  String get shellUnliked;

  /// No description provided for @shellDownloadQueued.
  ///
  /// In en, this message translates to:
  /// **'Download added'**
  String get shellDownloadQueued;

  /// No description provided for @shellDownloadsQueued.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 download added} other{{count} downloads added}}'**
  String shellDownloadsQueued(int count);

  /// No description provided for @shellDownloadsRejected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track can\'t be downloaded} other{{count} tracks can\'t be downloaded}}'**
  String shellDownloadsRejected(int count);

  /// No description provided for @shellDownloadRemoved.
  ///
  /// In en, this message translates to:
  /// **'Download removed'**
  String get shellDownloadRemoved;

  /// No description provided for @shellLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get shellLinkCopied;

  /// No description provided for @shellCouldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link.'**
  String get shellCouldNotOpenLink;

  /// No description provided for @shellNewPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get shellNewPlaylist;

  /// No description provided for @shellPlaylistNameHint.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get shellPlaylistNameHint;

  /// No description provided for @shellCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get shellCreate;

  /// No description provided for @shellAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get shellAdd;

  /// No description provided for @shellAddToPlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get shellAddToPlaylistTitle;

  /// No description provided for @shellAddToPlaylistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Create your first playlist to add tracks to it.'**
  String get shellAddToPlaylistEmpty;

  /// No description provided for @shellTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String shellTypeToConfirm(String word);

  /// No description provided for @shellSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String shellSelectedCount(int count);

  /// No description provided for @shellSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get shellSelectAll;

  /// No description provided for @shellClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get shellClearSelection;

  /// No description provided for @shellSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get shellSelect;

  /// No description provided for @shellScrollLeft.
  ///
  /// In en, this message translates to:
  /// **'Scroll left'**
  String get shellScrollLeft;

  /// No description provided for @shellScrollRight.
  ///
  /// In en, this message translates to:
  /// **'Scroll right'**
  String get shellScrollRight;

  /// No description provided for @shellSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get shellSeeAll;

  /// No description provided for @shellSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get shellSearchHint;

  /// No description provided for @shellClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get shellClearSearch;

  /// No description provided for @shellBadgePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get shellBadgePreview;

  /// No description provided for @shellBadgeExternal.
  ///
  /// In en, this message translates to:
  /// **'Plays on {provider}'**
  String shellBadgeExternal(String provider);

  /// No description provided for @shellBadgeDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get shellBadgeDownloaded;

  /// No description provided for @shellBadgeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get shellBadgeUnavailable;

  /// No description provided for @shellBadgeExplicit.
  ///
  /// In en, this message translates to:
  /// **'Explicit'**
  String get shellBadgeExplicit;

  /// No description provided for @shellMenuPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get shellMenuPlay;

  /// No description provided for @shellMenuPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get shellMenuPlayNext;

  /// No description provided for @shellMenuAddToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get shellMenuAddToQueue;

  /// No description provided for @shellMenuAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get shellMenuAddToPlaylist;

  /// No description provided for @shellMenuLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get shellMenuLike;

  /// No description provided for @shellMenuUnlike.
  ///
  /// In en, this message translates to:
  /// **'Remove from Liked songs'**
  String get shellMenuUnlike;

  /// No description provided for @shellMenuDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get shellMenuDownload;

  /// No description provided for @shellMenuRemoveDownload.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get shellMenuRemoveDownload;

  /// No description provided for @shellMenuGoToArtist.
  ///
  /// In en, this message translates to:
  /// **'Go to artist'**
  String get shellMenuGoToArtist;

  /// No description provided for @shellMenuGoToAlbum.
  ///
  /// In en, this message translates to:
  /// **'Go to album'**
  String get shellMenuGoToAlbum;

  /// No description provided for @shellMenuOpenOn.
  ///
  /// In en, this message translates to:
  /// **'Open on {provider}'**
  String shellMenuOpenOn(String provider);

  /// No description provided for @shellMenuCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get shellMenuCopyLink;

  /// No description provided for @shellMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get shellMoreOptions;

  /// No description provided for @shellNowPlayingIndicator.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get shellNowPlayingIndicator;

  /// No description provided for @shellGlassPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Track title'**
  String get shellGlassPreviewTitle;

  /// No description provided for @shellGlassPreviewArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get shellGlassPreviewArtist;

  /// No description provided for @shellGlassModeSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid surfaces'**
  String get shellGlassModeSolid;

  /// No description provided for @shellGlassModeTranslucent.
  ///
  /// In en, this message translates to:
  /// **'Translucent, no blur'**
  String get shellGlassModeTranslucent;

  /// No description provided for @shellGlassModeBlurred.
  ///
  /// In en, this message translates to:
  /// **'Translucent with blur'**
  String get shellGlassModeBlurred;

  /// No description provided for @shellFileYourFile.
  ///
  /// In en, this message translates to:
  /// **'Local file'**
  String get shellFileYourFile;

  /// No description provided for @shellCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Close Fermata?'**
  String get shellCloseTitle;

  /// No description provided for @shellCloseMessage.
  ///
  /// In en, this message translates to:
  /// **'Fermata can keep playing in the system tray, or quit completely.'**
  String get shellCloseMessage;

  /// No description provided for @shellCloseMinimize.
  ///
  /// In en, this message translates to:
  /// **'Keep playing in tray'**
  String get shellCloseMinimize;

  /// No description provided for @shellCloseQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get shellCloseQuit;

  /// No description provided for @shellCloseRemember.
  ///
  /// In en, this message translates to:
  /// **'Remember my choice'**
  String get shellCloseRemember;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['da', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'da':
      return AppLocalizationsDa();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
