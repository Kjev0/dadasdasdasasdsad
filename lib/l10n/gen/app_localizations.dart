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
