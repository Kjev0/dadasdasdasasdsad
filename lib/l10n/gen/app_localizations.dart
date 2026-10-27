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

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import a playlist'**
  String get importTitle;

  /// No description provided for @importBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get importBack;

  /// No description provided for @importStepSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get importStepSource;

  /// No description provided for @importStepPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get importStepPlaylist;

  /// No description provided for @importStepOptions.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get importStepOptions;

  /// No description provided for @importStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}: {name}'**
  String importStepOf(int step, int total, String name);

  /// No description provided for @importChooseSource.
  ///
  /// In en, this message translates to:
  /// **'Where is the playlist?'**
  String get importChooseSource;

  /// No description provided for @importChooseSourceHint.
  ///
  /// In en, this message translates to:
  /// **'Fermata finds each track on the services you choose next and keeps a link to the original.'**
  String get importChooseSourceHint;

  /// No description provided for @importM3uTitle.
  ///
  /// In en, this message translates to:
  /// **'A playlist file (M3U)'**
  String get importM3uTitle;

  /// No description provided for @importM3uHint.
  ///
  /// In en, this message translates to:
  /// **'Tracks from an .m3u or .m3u8 file on this device.'**
  String get importM3uHint;

  /// No description provided for @importM3uUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This playlist file can\'t be read.'**
  String get importM3uUnreadable;

  /// No description provided for @importM3uEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tracks were found in this playlist file.'**
  String get importM3uEmpty;

  /// No description provided for @importSourceNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'{service} isn\'t set up yet.'**
  String importSourceNotSetUp(String service);

  /// No description provided for @importSourceLinkOnly.
  ///
  /// In en, this message translates to:
  /// **'Public playlists by link. Connect to see your own playlists.'**
  String get importSourceLinkOnly;

  /// No description provided for @importSourceConnectFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect your account to import.'**
  String get importSourceConnectFirst;

  /// No description provided for @importSourceSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String importSourceSignedIn(String name);

  /// No description provided for @importSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get importSetUp;

  /// No description provided for @importChooseWhat.
  ///
  /// In en, this message translates to:
  /// **'What do you want to import from {service}?'**
  String importChooseWhat(String service);

  /// No description provided for @importPasteLink.
  ///
  /// In en, this message translates to:
  /// **'Paste a playlist link'**
  String get importPasteLink;

  /// No description provided for @importPasteLinkHint.
  ///
  /// In en, this message translates to:
  /// **'A {service} playlist link or ID'**
  String importPasteLinkHint(String service);

  /// No description provided for @importContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get importContinue;

  /// No description provided for @importLikedTracks.
  ///
  /// In en, this message translates to:
  /// **'Liked tracks'**
  String get importLikedTracks;

  /// No description provided for @importLikedTracksHint.
  ///
  /// In en, this message translates to:
  /// **'Every track you liked on {service}.'**
  String importLikedTracksHint(String service);

  /// No description provided for @importLikedName.
  ///
  /// In en, this message translates to:
  /// **'Liked on {service}'**
  String importLikedName(String service);

  /// No description provided for @importYourPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Your playlists'**
  String get importYourPlaylists;

  /// No description provided for @importNoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'You have no playlists there yet.'**
  String get importNoPlaylists;

  /// No description provided for @importTrackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String importTrackCount(int count);

  /// No description provided for @importConnectForLibrary.
  ///
  /// In en, this message translates to:
  /// **'Connect your {service} account in Settings to import your own playlists and liked tracks.'**
  String importConnectForLibrary(String service);

  /// No description provided for @importOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Where should Fermata look?'**
  String get importOptionsTitle;

  /// No description provided for @importSummaryPlaylist.
  ///
  /// In en, this message translates to:
  /// **'“{name}” from {service}'**
  String importSummaryPlaylist(String name, String service);

  /// No description provided for @importSummaryLink.
  ///
  /// In en, this message translates to:
  /// **'A playlist link from {service}'**
  String importSummaryLink(String service);

  /// No description provided for @importSummaryLiked.
  ///
  /// In en, this message translates to:
  /// **'Your liked tracks on {service}'**
  String importSummaryLiked(String service);

  /// No description provided for @importSummaryM3u.
  ///
  /// In en, this message translates to:
  /// **'“{name}” ({count, plural, =1{1 track} other{{count} tracks}})'**
  String importSummaryM3u(String name, int count);

  /// No description provided for @importTargets.
  ///
  /// In en, this message translates to:
  /// **'Find matches on'**
  String get importTargets;

  /// No description provided for @importTargetsHint.
  ///
  /// In en, this message translates to:
  /// **'In this order. The first service with a good match is used for playback.'**
  String get importTargetsHint;

  /// No description provided for @importNoTargets.
  ///
  /// In en, this message translates to:
  /// **'None of your services can play the matches. Connect a service such as SoundCloud or Audius first.'**
  String get importNoTargets;

  /// No description provided for @importTargetNotReady.
  ///
  /// In en, this message translates to:
  /// **'Not connected or not set up'**
  String get importTargetNotReady;

  /// No description provided for @importMatchingGroup.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get importMatchingGroup;

  /// No description provided for @importStart.
  ///
  /// In en, this message translates to:
  /// **'Start import'**
  String get importStart;

  /// No description provided for @importFetchingLiked.
  ///
  /// In en, this message translates to:
  /// **'Fetched {count} liked tracks…'**
  String importFetchingLiked(int count);

  /// No description provided for @importNothingToImport.
  ///
  /// In en, this message translates to:
  /// **'There are no tracks to import.'**
  String get importNothingToImport;

  /// No description provided for @importStartFailed.
  ///
  /// In en, this message translates to:
  /// **'The import couldn\'t be started.'**
  String get importStartFailed;

  /// No description provided for @importReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review matches'**
  String get importReviewTitle;

  /// No description provided for @importReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Check the matches Fermata wasn\'t sure about. Nothing is saved until you press Save.'**
  String get importReviewHint;

  /// No description provided for @importUntitled.
  ///
  /// In en, this message translates to:
  /// **'Imported playlist'**
  String get importUntitled;

  /// No description provided for @importImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get importImporting;

  /// No description provided for @importPhaseFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching the playlist…'**
  String get importPhaseFetching;

  /// No description provided for @importPhaseMatchingStart.
  ///
  /// In en, this message translates to:
  /// **'Finding matches…'**
  String get importPhaseMatchingStart;

  /// No description provided for @importPhaseMatching.
  ///
  /// In en, this message translates to:
  /// **'Matched {processed} of {total} tracks'**
  String importPhaseMatching(int processed, int total);

  /// No description provided for @importPhaseSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get importPhaseSaving;

  /// No description provided for @importCancelImport.
  ///
  /// In en, this message translates to:
  /// **'Cancel import'**
  String get importCancelImport;

  /// No description provided for @importCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this import?'**
  String get importCancelTitle;

  /// No description provided for @importCancelBody.
  ///
  /// In en, this message translates to:
  /// **'Your review choices are discarded. Nothing has been saved yet.'**
  String get importCancelBody;

  /// No description provided for @importCanceled.
  ///
  /// In en, this message translates to:
  /// **'The import was canceled.'**
  String get importCanceled;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'The import failed'**
  String get importFailed;

  /// No description provided for @importStartNew.
  ///
  /// In en, this message translates to:
  /// **'Start a new import'**
  String get importStartNew;

  /// No description provided for @importSessionMissing.
  ///
  /// In en, this message translates to:
  /// **'This import isn\'t available anymore'**
  String get importSessionMissing;

  /// No description provided for @importSessionMissingHint.
  ///
  /// In en, this message translates to:
  /// **'Imports in progress are kept until Fermata closes.'**
  String get importSessionMissingHint;

  /// No description provided for @importFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All · {count}'**
  String importFilterAll(int count);

  /// No description provided for @importFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tracks with this status.'**
  String get importFilterEmpty;

  /// No description provided for @importDecisionAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto-accepted'**
  String get importDecisionAuto;

  /// No description provided for @importDecisionAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get importDecisionAccepted;

  /// No description provided for @importDecisionReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get importDecisionReview;

  /// No description provided for @importDecisionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get importDecisionNotFound;

  /// No description provided for @importDecisionRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get importDecisionRejected;

  /// No description provided for @importDecisionSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get importDecisionSkipped;

  /// No description provided for @importAcceptAllHigh.
  ///
  /// In en, this message translates to:
  /// **'Accept all high-confidence ({count})'**
  String importAcceptAllHigh(int count);

  /// No description provided for @importSavePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Save playlist'**
  String get importSavePlaylist;

  /// No description provided for @importSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Name the playlist'**
  String get importSaveTitle;

  /// No description provided for @importSavePendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Some tracks still need review'**
  String get importSavePendingTitle;

  /// No description provided for @importSavePendingBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track hasn\'t been reviewed. It will be saved without a match.} other{{count} tracks haven\'t been reviewed. They will be saved without a match.}}'**
  String importSavePendingBody(int count);

  /// No description provided for @importSaveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get importSaveAnyway;

  /// No description provided for @importSaved.
  ///
  /// In en, this message translates to:
  /// **'Playlist saved'**
  String get importSaved;

  /// No description provided for @importSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The playlist couldn\'t be saved.'**
  String get importSaveFailed;

  /// No description provided for @importDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlist saved'**
  String get importDoneTitle;

  /// No description provided for @importDoneAll.
  ///
  /// In en, this message translates to:
  /// **'Every track has a match.'**
  String get importDoneAll;

  /// No description provided for @importDoneMissing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track has no match.} other{{count} tracks have no match.}}'**
  String importDoneMissing(int count);

  /// No description provided for @importOpenPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Open playlist'**
  String get importOpenPlaylist;

  /// No description provided for @importShowMissing.
  ///
  /// In en, this message translates to:
  /// **'Show missing tracks'**
  String get importShowMissing;

  /// No description provided for @importMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Tracks without a match ({count})'**
  String importMissingTitle(int count);

  /// No description provided for @importReportHeader.
  ///
  /// In en, this message translates to:
  /// **'Tracks without a match in “{name}” ({count}):'**
  String importReportHeader(String name, int count);

  /// No description provided for @importOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get importOriginal;

  /// No description provided for @importMatch.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get importMatch;

  /// No description provided for @importNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No match found'**
  String get importNoMatch;

  /// No description provided for @importOnlyOtherVersions.
  ///
  /// In en, this message translates to:
  /// **'Only other versions found — choose one yourself if it\'s right.'**
  String get importOnlyOtherVersions;

  /// No description provided for @importAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get importAccept;

  /// No description provided for @importReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get importReject;

  /// No description provided for @importSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get importSkip;

  /// No description provided for @importOtherCandidates.
  ///
  /// In en, this message translates to:
  /// **'Candidates ({count})'**
  String importOtherCandidates(int count);

  /// No description provided for @importCandidatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Candidates for “{title}”'**
  String importCandidatesTitle(String title);

  /// No description provided for @importUseThis.
  ///
  /// In en, this message translates to:
  /// **'Use this'**
  String get importUseThis;

  /// No description provided for @importDifferentVersionWarning.
  ///
  /// In en, this message translates to:
  /// **'This is a different version than the original.'**
  String get importDifferentVersionWarning;

  /// No description provided for @importSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get importSearch;

  /// No description provided for @importSearchFor.
  ///
  /// In en, this message translates to:
  /// **'Search for “{title}”'**
  String importSearchFor(String title);

  /// No description provided for @importSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found. Try other words.'**
  String get importSearchNoResults;

  /// No description provided for @importSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get importSearchResults;

  /// No description provided for @importMatchedByIsrc.
  ///
  /// In en, this message translates to:
  /// **'Same ISRC'**
  String get importMatchedByIsrc;

  /// No description provided for @importConfidenceSemantics.
  ///
  /// In en, this message translates to:
  /// **'Confidence {level}, {percent} percent'**
  String importConfidenceSemantics(String level, int percent);

  /// No description provided for @importConfidenceExact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get importConfidenceExact;

  /// No description provided for @importConfidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get importConfidenceHigh;

  /// No description provided for @importConfidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get importConfidenceMedium;

  /// No description provided for @importConfidenceLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get importConfidenceLow;

  /// No description provided for @importConfidenceNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get importConfidenceNone;

  /// No description provided for @importDiffRemix.
  ///
  /// In en, this message translates to:
  /// **'Remix'**
  String get importDiffRemix;

  /// No description provided for @importDiffLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get importDiffLive;

  /// No description provided for @importDiffAcoustic.
  ///
  /// In en, this message translates to:
  /// **'Acoustic'**
  String get importDiffAcoustic;

  /// No description provided for @importDiffExtended.
  ///
  /// In en, this message translates to:
  /// **'Extended'**
  String get importDiffExtended;

  /// No description provided for @importDiffRadioEdit.
  ///
  /// In en, this message translates to:
  /// **'Radio edit'**
  String get importDiffRadioEdit;

  /// No description provided for @importDiffInstrumental.
  ///
  /// In en, this message translates to:
  /// **'Instrumental'**
  String get importDiffInstrumental;

  /// No description provided for @importDiffKaraoke.
  ///
  /// In en, this message translates to:
  /// **'Karaoke'**
  String get importDiffKaraoke;

  /// No description provided for @importDiffCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get importDiffCover;

  /// No description provided for @importDiffRemaster.
  ///
  /// In en, this message translates to:
  /// **'Remaster'**
  String get importDiffRemaster;

  /// No description provided for @importDiffSped.
  ///
  /// In en, this message translates to:
  /// **'Sped up'**
  String get importDiffSped;

  /// No description provided for @importDiffSlowed.
  ///
  /// In en, this message translates to:
  /// **'Slowed'**
  String get importDiffSlowed;

  /// No description provided for @importDiffDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get importDiffDemo;

  /// No description provided for @importDiffExplicit.
  ///
  /// In en, this message translates to:
  /// **'Explicit mismatch'**
  String get importDiffExplicit;

  /// No description provided for @importDiffDuration.
  ///
  /// In en, this message translates to:
  /// **'Different length'**
  String get importDiffDuration;

  /// No description provided for @importDiffAlbum.
  ///
  /// In en, this message translates to:
  /// **'Different album'**
  String get importDiffAlbum;

  /// No description provided for @importDiffYear.
  ///
  /// In en, this message translates to:
  /// **'Different year'**
  String get importDiffYear;

  /// No description provided for @importDiffArtist.
  ///
  /// In en, this message translates to:
  /// **'Different artist'**
  String get importDiffArtist;

  /// No description provided for @importDiffFeatured.
  ///
  /// In en, this message translates to:
  /// **'Different featured artists'**
  String get importDiffFeatured;

  /// No description provided for @importDiffTitle.
  ///
  /// In en, this message translates to:
  /// **'Different title'**
  String get importDiffTitle;

  /// No description provided for @importDiffPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview only'**
  String get importDiffPreview;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingFinish.
  ///
  /// In en, this message translates to:
  /// **'Start listening'**
  String get onboardingFinish;

  /// No description provided for @onboardingStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String onboardingStepOf(int step, int total);

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Fermata'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'A calm music player for the music you own and the services you already use.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingPointFiles.
  ///
  /// In en, this message translates to:
  /// **'Your own files come first and always work offline.'**
  String get onboardingPointFiles;

  /// No description provided for @onboardingPointServices.
  ///
  /// In en, this message translates to:
  /// **'Search SoundCloud, Audius and more in one place, and bring your playlists with you.'**
  String get onboardingPointServices;

  /// No description provided for @onboardingPointBackground.
  ///
  /// In en, this message translates to:
  /// **'Keeps playing in the background, with your media keys and lock screen.'**
  String get onboardingPointBackground;

  /// No description provided for @onboardingPointPrivacy.
  ///
  /// In en, this message translates to:
  /// **'No ads, no tracking. Recommendations are calculated on your device.'**
  String get onboardingPointPrivacy;

  /// No description provided for @onboardingMusicTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your music'**
  String get onboardingMusicTitle;

  /// No description provided for @onboardingMusicBody.
  ///
  /// In en, this message translates to:
  /// **'Choose the folders where your music files are. Fermata reads them in the background and keeps watching for new files.'**
  String get onboardingMusicBody;

  /// No description provided for @onboardingAudioPermissionRationale.
  ///
  /// In en, this message translates to:
  /// **'To play the music stored on your phone, Fermata needs permission to read your audio files. It only reads music — never photos, messages or other files.'**
  String get onboardingAudioPermissionRationale;

  /// No description provided for @onboardingAllowAudio.
  ///
  /// In en, this message translates to:
  /// **'Allow access to music'**
  String get onboardingAllowAudio;

  /// No description provided for @onboardingAudioDenied.
  ///
  /// In en, this message translates to:
  /// **'Without this permission Fermata can\'t see your music files. You can allow it later in the system settings.'**
  String get onboardingAudioDenied;

  /// No description provided for @onboardingSuggestedFolder.
  ///
  /// In en, this message translates to:
  /// **'Your Music folder'**
  String get onboardingSuggestedFolder;

  /// No description provided for @onboardingAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get onboardingAdd;

  /// No description provided for @onboardingChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder…'**
  String get onboardingChooseFolder;

  /// No description provided for @onboardingFolderMissing.
  ///
  /// In en, this message translates to:
  /// **'That folder doesn\'t exist anymore.'**
  String get onboardingFolderMissing;

  /// No description provided for @onboardingScanning.
  ///
  /// In en, this message translates to:
  /// **'Fermata is reading your music in the background.'**
  String get onboardingScanning;

  /// No description provided for @onboardingMusicLater.
  ///
  /// In en, this message translates to:
  /// **'You can add or remove folders any time in Library.'**
  String get onboardingMusicLater;

  /// No description provided for @onboardingServicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your services'**
  String get onboardingServicesTitle;

  /// No description provided for @onboardingServicesBody.
  ///
  /// In en, this message translates to:
  /// **'Optional. Connect an account to search it, stream it and import your playlists. You sign in on the service\'s own website — Fermata never sees your password.'**
  String get onboardingServicesBody;

  /// No description provided for @onboardingRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get onboardingRecommended;

  /// No description provided for @onboardingServiceHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use your account.'**
  String get onboardingServiceHint;

  /// No description provided for @onboardingNeedsCredentials.
  ///
  /// In en, this message translates to:
  /// **'Needs developer credentials first — you can set this up later in Settings.'**
  String get onboardingNeedsCredentials;

  /// No description provided for @onboardingConnectedAs.
  ///
  /// In en, this message translates to:
  /// **'Connected as {name}'**
  String onboardingConnectedAs(String name);

  /// No description provided for @onboardingNoAccountNeeded.
  ///
  /// In en, this message translates to:
  /// **'No account needed for: {services}.'**
  String onboardingNoAccountNeeded(String services);

  /// No description provided for @onboardingServicesLater.
  ///
  /// In en, this message translates to:
  /// **'You can connect or disconnect services any time in Settings → Connected services.'**
  String get onboardingServicesLater;

  /// No description provided for @onboardingBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Music that keeps playing'**
  String get onboardingBackgroundTitle;

  /// No description provided for @onboardingBackgroundAndroid.
  ///
  /// In en, this message translates to:
  /// **'Fermata keeps playing when you switch apps or lock your phone. A notification shows the playback controls.'**
  String get onboardingBackgroundAndroid;

  /// No description provided for @onboardingNotificationRationale.
  ///
  /// In en, this message translates to:
  /// **'Android asks before apps may show notifications. Fermata uses them for the playback controls and for finished downloads — never for advertising.'**
  String get onboardingNotificationRationale;

  /// No description provided for @onboardingAllowNotifications.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get onboardingAllowNotifications;

  /// No description provided for @onboardingNotificationsAllowed.
  ///
  /// In en, this message translates to:
  /// **'Notifications are allowed.'**
  String get onboardingNotificationsAllowed;

  /// No description provided for @onboardingBatteryNote.
  ///
  /// In en, this message translates to:
  /// **'If music stops in the background on your phone, see Settings → Background playback.'**
  String get onboardingBatteryNote;

  /// No description provided for @onboardingBackgroundTray.
  ///
  /// In en, this message translates to:
  /// **'Closing the window doesn\'t stop the music: Fermata stays in the system tray. Quit from the tray menu when you\'re done.'**
  String get onboardingBackgroundTray;

  /// No description provided for @onboardingBackgroundNoTray.
  ///
  /// In en, this message translates to:
  /// **'Closing the window doesn\'t stop the music. Your desktop has no system tray, so Fermata minimizes instead.'**
  String get onboardingBackgroundNoTray;

  /// No description provided for @onboardingMediaKeys.
  ///
  /// In en, this message translates to:
  /// **'Media keys and your desktop\'s media controls work while Fermata is in the background.'**
  String get onboardingMediaKeys;

  /// No description provided for @pagesPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get pagesPlay;

  /// No description provided for @pagesShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get pagesShuffle;

  /// No description provided for @pagesHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String pagesHoursMinutes(int hours, int minutes);

  /// No description provided for @pagesMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String pagesMinutes(int minutes);

  /// No description provided for @pagesTrackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tracks} =1{1 track} other{{count} tracks}}'**
  String pagesTrackCount(int count);

  /// No description provided for @pagesToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get pagesToday;

  /// No description provided for @pagesYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get pagesYesterday;

  /// No description provided for @pagesDownloadEligible.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get pagesDownloadEligible;

  /// No description provided for @pagesOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get pagesOpenSettings;

  /// No description provided for @pagesImportAndMatch.
  ///
  /// In en, this message translates to:
  /// **'Import & match'**
  String get pagesImportAndMatch;

  /// No description provided for @pagesMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get pagesMore;

  /// No description provided for @pagesSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get pagesSort;

  /// No description provided for @pagesFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get pagesFilter;

  /// No description provided for @pagesAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get pagesAscending;

  /// No description provided for @pagesDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get pagesDescending;

  /// No description provided for @pagesClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get pagesClearFilters;

  /// No description provided for @pagesNoMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches these filters.'**
  String get pagesNoMatches;

  /// No description provided for @pagesLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get pagesLoadMore;

  /// No description provided for @pagesRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get pagesRemove;

  /// No description provided for @pagesRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get pagesRename;

  /// No description provided for @pagesOpenOnProvider.
  ///
  /// In en, this message translates to:
  /// **'Open on {provider}'**
  String pagesOpenOnProvider(String provider);

  /// No description provided for @pagesDataFrom.
  ///
  /// In en, this message translates to:
  /// **'Data from {provider}'**
  String pagesDataFrom(String provider);

  /// No description provided for @shelfContinueListening.
  ///
  /// In en, this message translates to:
  /// **'Continue listening'**
  String get shelfContinueListening;

  /// No description provided for @shelfDailyMix.
  ///
  /// In en, this message translates to:
  /// **'Daily Mix {number}'**
  String shelfDailyMix(int number);

  /// No description provided for @shelfDiscoverWeekly.
  ///
  /// In en, this message translates to:
  /// **'Discover Weekly'**
  String get shelfDiscoverWeekly;

  /// No description provided for @shelfBecauseYouLiked.
  ///
  /// In en, this message translates to:
  /// **'Because you like {artist}'**
  String shelfBecauseYouLiked(String artist);

  /// No description provided for @shelfTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get shelfTrending;

  /// No description provided for @shelfNewReleases.
  ///
  /// In en, this message translates to:
  /// **'New releases'**
  String get shelfNewReleases;

  /// No description provided for @shelfRecentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get shelfRecentlyAdded;

  /// No description provided for @moodFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get moodFocus;

  /// No description provided for @moodChill.
  ///
  /// In en, this message translates to:
  /// **'Chill'**
  String get moodChill;

  /// No description provided for @moodWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get moodWorkout;

  /// No description provided for @moodParty.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get moodParty;

  /// No description provided for @moodSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get moodSleep;

  /// No description provided for @moodCommute.
  ///
  /// In en, this message translates to:
  /// **'On the road'**
  String get moodCommute;

  /// No description provided for @moodHappy.
  ///
  /// In en, this message translates to:
  /// **'Feel good'**
  String get moodHappy;

  /// No description provided for @moodMelancholy.
  ///
  /// In en, this message translates to:
  /// **'Melancholy'**
  String get moodMelancholy;

  /// No description provided for @homeGoodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGoodMorning;

  /// No description provided for @homeGoodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGoodAfternoon;

  /// No description provided for @homeGoodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGoodEvening;

  /// No description provided for @homeGoodNight.
  ///
  /// In en, this message translates to:
  /// **'Good night'**
  String get homeGoodNight;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Picked from what you play — worked out on this device.'**
  String get homeSubtitle;

  /// No description provided for @homeMix.
  ///
  /// In en, this message translates to:
  /// **'Mix'**
  String get homeMix;

  /// No description provided for @homeShelf.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get homeShelf;

  /// No description provided for @homeMadeForYou.
  ///
  /// In en, this message translates to:
  /// **'Made for you'**
  String get homeMadeForYou;

  /// No description provided for @homeFirstRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s bring in your music'**
  String get homeFirstRunTitle;

  /// No description provided for @homeFirstRunMessage.
  ///
  /// In en, this message translates to:
  /// **'Fermata plays your own files and the services you connect. Start with one of these.'**
  String get homeFirstRunMessage;

  /// No description provided for @homeAddFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a music folder'**
  String get homeAddFolderTitle;

  /// No description provided for @homeAddFolderBody.
  ///
  /// In en, this message translates to:
  /// **'Your files stay where they are and play offline.'**
  String get homeAddFolderBody;

  /// No description provided for @homeConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect a service'**
  String get homeConnectTitle;

  /// No description provided for @homeConnectBody.
  ///
  /// In en, this message translates to:
  /// **'SoundCloud, Audius, Jamendo and more.'**
  String get homeConnectBody;

  /// No description provided for @homeConnectAction.
  ///
  /// In en, this message translates to:
  /// **'Connected services'**
  String get homeConnectAction;

  /// No description provided for @homeExploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get homeExploreTitle;

  /// No description provided for @homeExploreBody.
  ///
  /// In en, this message translates to:
  /// **'Browse moods, genres and what is trending.'**
  String get homeExploreBody;

  /// No description provided for @homeExploreAction.
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get homeExploreAction;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Songs, artists, albums or a share link'**
  String get searchHint;

  /// No description provided for @searchFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchFilterAll;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Search everything at once'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Your library and every connected service. Paste a playlist link to open or import it.'**
  String get searchEmptyMessage;

  /// No description provided for @searchBrowseExplore.
  ///
  /// In en, this message translates to:
  /// **'Browse Explore'**
  String get searchBrowseExplore;

  /// No description provided for @searchHistoryOff.
  ///
  /// In en, this message translates to:
  /// **'Search history is turned off, so searches are not saved.'**
  String get searchHistoryOff;

  /// No description provided for @searchRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecent;

  /// No description provided for @searchClearRecent.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClearRecent;

  /// No description provided for @searchRemoveRecent.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{query}\"'**
  String searchRemoveRecent(String query);

  /// No description provided for @searchFor.
  ///
  /// In en, this message translates to:
  /// **'Search for \"{query}\"'**
  String searchFor(String query);

  /// No description provided for @searchInYourLibrary.
  ///
  /// In en, this message translates to:
  /// **'In your library'**
  String get searchInYourLibrary;

  /// No description provided for @searchTopResult.
  ///
  /// In en, this message translates to:
  /// **'Top result'**
  String get searchTopResult;

  /// No description provided for @searchTracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get searchTracks;

  /// No description provided for @searchArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get searchArtists;

  /// No description provided for @searchAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get searchAlbums;

  /// No description provided for @searchPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get searchPlaylists;

  /// No description provided for @searchShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all {count}'**
  String searchShowAll(int count);

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String searchNoResults(String query);

  /// No description provided for @searchNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling, or try fewer words.'**
  String get searchNoResultsHint;

  /// No description provided for @searchConnectedServices.
  ///
  /// In en, this message translates to:
  /// **'Connected services'**
  String get searchConnectedServices;

  /// No description provided for @searchNotSearched.
  ///
  /// In en, this message translates to:
  /// **'Not searched: {sources}'**
  String searchNotSearched(String sources);

  /// No description provided for @searchSourceNotConnected.
  ///
  /// In en, this message translates to:
  /// **'{service} isn\'t connected.'**
  String searchSourceNotConnected(String service);

  /// No description provided for @searchNeedsCredentials.
  ///
  /// In en, this message translates to:
  /// **'needs setup'**
  String get searchNeedsCredentials;

  /// No description provided for @searchNotConnected.
  ///
  /// In en, this message translates to:
  /// **'not connected'**
  String get searchNotConnected;

  /// No description provided for @searchKindTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get searchKindTrack;

  /// No description provided for @searchKindArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get searchKindArtist;

  /// No description provided for @searchKindAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get searchKindAlbum;

  /// No description provided for @searchKindPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get searchKindPlaylist;

  /// No description provided for @searchLinkTrack.
  ///
  /// In en, this message translates to:
  /// **'{provider} track link'**
  String searchLinkTrack(String provider);

  /// No description provided for @searchLinkPlaylist.
  ///
  /// In en, this message translates to:
  /// **'{provider} playlist link'**
  String searchLinkPlaylist(String provider);

  /// No description provided for @searchLinkAlbum.
  ///
  /// In en, this message translates to:
  /// **'{provider} album link'**
  String searchLinkAlbum(String provider);

  /// No description provided for @searchLinkArtist.
  ///
  /// In en, this message translates to:
  /// **'{provider} artist link'**
  String searchLinkArtist(String provider);

  /// No description provided for @searchLinkGeneric.
  ///
  /// In en, this message translates to:
  /// **'{provider} link'**
  String searchLinkGeneric(String provider);

  /// No description provided for @searchOpenPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Open playlist'**
  String get searchOpenPlaylist;

  /// No description provided for @searchOpenAlbum.
  ///
  /// In en, this message translates to:
  /// **'Open album'**
  String get searchOpenAlbum;

  /// No description provided for @searchOpenArtist.
  ///
  /// In en, this message translates to:
  /// **'Open artist'**
  String get searchOpenArtist;

  /// No description provided for @searchSourceMissing.
  ///
  /// In en, this message translates to:
  /// **'{provider} isn\'t available in this version of Fermata.'**
  String searchSourceMissing(String provider);

  /// No description provided for @searchLinkNotFound.
  ///
  /// In en, this message translates to:
  /// **'This track couldn\'t be found. It may have been removed or made private.'**
  String get searchLinkNotFound;

  /// No description provided for @exploreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Moods, genres and new music from your services.'**
  String get exploreSubtitle;

  /// No description provided for @exploreMoods.
  ///
  /// In en, this message translates to:
  /// **'Moods'**
  String get exploreMoods;

  /// No description provided for @exploreGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get exploreGenres;

  /// No description provided for @exploreNoGenres.
  ///
  /// In en, this message translates to:
  /// **'No genres yet. Add music or connect a service.'**
  String get exploreNoGenres;

  /// No description provided for @exploreGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get exploreGenre;

  /// No description provided for @exploreMood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get exploreMood;

  /// No description provided for @exploreNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing playable found right now. Try again later or connect another service.'**
  String get exploreNothingFound;

  /// No description provided for @libraryTabTracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get libraryTabTracks;

  /// No description provided for @libraryTabAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get libraryTabAlbums;

  /// No description provided for @libraryTabArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get libraryTabArtists;

  /// No description provided for @libraryTabFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get libraryTabFolders;

  /// No description provided for @libraryPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Fermata needs access to your music to add a folder.'**
  String get libraryPermissionNeeded;

  /// No description provided for @libraryOpenSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get libraryOpenSystemSettings;

  /// No description provided for @libraryAddFolder.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get libraryAddFolder;

  /// No description provided for @libraryFolderAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {folder} — scanning now'**
  String libraryFolderAdded(String folder);

  /// No description provided for @libraryLocalFiles.
  ///
  /// In en, this message translates to:
  /// **'Local files'**
  String get libraryLocalFiles;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a music folder or import a file. Tracks you like or play from services show up here too.'**
  String get libraryEmptyMessage;

  /// No description provided for @libraryImportFile.
  ///
  /// In en, this message translates to:
  /// **'Import a file'**
  String get libraryImportFile;

  /// No description provided for @libraryImportFileFailed.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be added. Fermata reads MP3, FLAC, M4A, Ogg, Opus, WAV and AIFF.'**
  String get libraryImportFileFailed;

  /// No description provided for @libraryImportFileDone.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\"'**
  String libraryImportFileDone(String title);

  /// No description provided for @libraryFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter your library'**
  String get libraryFilterHint;

  /// No description provided for @libraryQuickDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get libraryQuickDownloaded;

  /// No description provided for @librarySortedBy.
  ///
  /// In en, this message translates to:
  /// **'Sorted by {field}'**
  String librarySortedBy(String field);

  /// No description provided for @librarySortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get librarySortTitle;

  /// No description provided for @librarySortArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get librarySortArtist;

  /// No description provided for @librarySortAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get librarySortAlbum;

  /// No description provided for @librarySortYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get librarySortYear;

  /// No description provided for @librarySortDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get librarySortDuration;

  /// No description provided for @librarySortDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get librarySortDateAdded;

  /// No description provided for @librarySortPlayCount.
  ///
  /// In en, this message translates to:
  /// **'Most played'**
  String get librarySortPlayCount;

  /// No description provided for @librarySortLastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last played'**
  String get librarySortLastPlayed;

  /// No description provided for @librarySortGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get librarySortGenre;

  /// No description provided for @libraryFilterAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get libraryFilterAvailability;

  /// No description provided for @libraryFilterDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get libraryFilterDownloaded;

  /// No description provided for @libraryFilterLocal.
  ///
  /// In en, this message translates to:
  /// **'Local files only'**
  String get libraryFilterLocal;

  /// No description provided for @libraryFilterOffline.
  ///
  /// In en, this message translates to:
  /// **'Available offline'**
  String get libraryFilterOffline;

  /// No description provided for @libraryFilterFavorites.
  ///
  /// In en, this message translates to:
  /// **'Liked songs'**
  String get libraryFilterFavorites;

  /// No description provided for @libraryFilterSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get libraryFilterSource;

  /// No description provided for @libraryFilterGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get libraryFilterGenre;

  /// No description provided for @libraryAnyGenre.
  ///
  /// In en, this message translates to:
  /// **'Any genre'**
  String get libraryAnyGenre;

  /// No description provided for @libraryFilterYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get libraryFilterYear;

  /// No description provided for @libraryFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get libraryFrom;

  /// No description provided for @libraryTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get libraryTo;

  /// No description provided for @libraryFilterDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get libraryFilterDuration;

  /// No description provided for @libraryMinMinutes.
  ///
  /// In en, this message translates to:
  /// **'At least'**
  String get libraryMinMinutes;

  /// No description provided for @libraryMaxMinutes.
  ///
  /// In en, this message translates to:
  /// **'At most'**
  String get libraryMaxMinutes;

  /// No description provided for @libraryFilterAlbums.
  ///
  /// In en, this message translates to:
  /// **'Filter albums'**
  String get libraryFilterAlbums;

  /// No description provided for @libraryNoAlbums.
  ///
  /// In en, this message translates to:
  /// **'No albums yet'**
  String get libraryNoAlbums;

  /// No description provided for @libraryFilterArtists.
  ///
  /// In en, this message translates to:
  /// **'Filter artists'**
  String get libraryFilterArtists;

  /// No description provided for @libraryNoArtists.
  ///
  /// In en, this message translates to:
  /// **'No artists yet'**
  String get libraryNoArtists;

  /// No description provided for @libraryFolders.
  ///
  /// In en, this message translates to:
  /// **'Music folders'**
  String get libraryFolders;

  /// No description provided for @libraryFoldersHintDesktop.
  ///
  /// In en, this message translates to:
  /// **'Watched folders are rescanned automatically when files change.'**
  String get libraryFoldersHintDesktop;

  /// No description provided for @libraryFoldersHintAndroid.
  ///
  /// In en, this message translates to:
  /// **'Folders are rescanned each time Fermata starts.'**
  String get libraryFoldersHintAndroid;

  /// No description provided for @libraryNoFolders.
  ///
  /// In en, this message translates to:
  /// **'No music folders yet'**
  String get libraryNoFolders;

  /// No description provided for @libraryNoFoldersMessage.
  ///
  /// In en, this message translates to:
  /// **'Add the folders where you keep music. Files are never moved or uploaded.'**
  String get libraryNoFoldersMessage;

  /// No description provided for @libraryRescanAll.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get libraryRescanAll;

  /// No description provided for @libraryFullRescan.
  ///
  /// In en, this message translates to:
  /// **'Full rescan'**
  String get libraryFullRescan;

  /// No description provided for @libraryRescanFolder.
  ///
  /// In en, this message translates to:
  /// **'Rescan folder'**
  String get libraryRescanFolder;

  /// No description provided for @libraryRemoveFolder.
  ///
  /// In en, this message translates to:
  /// **'Remove folder'**
  String get libraryRemoveFolder;

  /// No description provided for @libraryRemoveFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this folder?'**
  String get libraryRemoveFolderTitle;

  /// No description provided for @libraryRemoveFolderMessage.
  ///
  /// In en, this message translates to:
  /// **'Tracks from {path} leave your library. The files themselves aren\'t deleted.'**
  String libraryRemoveFolderMessage(String path);

  /// No description provided for @libraryWatchFolder.
  ///
  /// In en, this message translates to:
  /// **'Watch for changes'**
  String get libraryWatchFolder;

  /// No description provided for @libraryNeverScanned.
  ///
  /// In en, this message translates to:
  /// **'Not scanned yet'**
  String get libraryNeverScanned;

  /// No description provided for @libraryScannedOn.
  ///
  /// In en, this message translates to:
  /// **'Scanned {date}'**
  String libraryScannedOn(String date);

  /// No description provided for @libraryScanEnumerating.
  ///
  /// In en, this message translates to:
  /// **'Looking for music…'**
  String get libraryScanEnumerating;

  /// No description provided for @libraryScanProgress.
  ///
  /// In en, this message translates to:
  /// **'Scanning {scanned} of {total} files'**
  String libraryScanProgress(int scanned, int total);

  /// No description provided for @libraryScanDone.
  ///
  /// In en, this message translates to:
  /// **'Scan complete'**
  String get libraryScanDone;

  /// No description provided for @libraryScanFailed.
  ///
  /// In en, this message translates to:
  /// **'The scan stopped'**
  String get libraryScanFailed;

  /// No description provided for @libraryScanCounts.
  ///
  /// In en, this message translates to:
  /// **'{added} added · {updated} updated · {removed} removed'**
  String libraryScanCounts(int added, int updated, int removed);

  /// No description provided for @libraryScanErrors.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file couldn\'t be read} other{{count} files couldn\'t be read}}'**
  String libraryScanErrors(int count);

  /// No description provided for @libraryTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get libraryTools;

  /// No description provided for @libraryMissingFiles.
  ///
  /// In en, this message translates to:
  /// **'Missing files'**
  String get libraryMissingFiles;

  /// No description provided for @libraryMissingFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Tracks whose file was moved or deleted outside Fermata. They come back if the file returns.'**
  String get libraryMissingFilesHint;

  /// No description provided for @libraryNoMissingFiles.
  ///
  /// In en, this message translates to:
  /// **'No missing files'**
  String get libraryNoMissingFiles;

  /// No description provided for @libraryRemoveAllMissing.
  ///
  /// In en, this message translates to:
  /// **'Remove all from library'**
  String get libraryRemoveAllMissing;

  /// No description provided for @libraryDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Duplicates'**
  String get libraryDuplicates;

  /// No description provided for @libraryDuplicatesHint.
  ///
  /// In en, this message translates to:
  /// **'Tracks that look like copies of each other.'**
  String get libraryDuplicatesHint;

  /// No description provided for @libraryNoDuplicates.
  ///
  /// In en, this message translates to:
  /// **'No duplicates found'**
  String get libraryNoDuplicates;

  /// No description provided for @libraryDuplicateSameFile.
  ///
  /// In en, this message translates to:
  /// **'Identical files'**
  String get libraryDuplicateSameFile;

  /// No description provided for @libraryDuplicateSameIsrc.
  ///
  /// In en, this message translates to:
  /// **'Same recording (ISRC)'**
  String get libraryDuplicateSameIsrc;

  /// No description provided for @libraryDuplicateSameMetadata.
  ///
  /// In en, this message translates to:
  /// **'Same title, artist and length'**
  String get libraryDuplicateSameMetadata;

  /// No description provided for @libraryRemoveFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get libraryRemoveFromLibrary;

  /// No description provided for @libraryRemoveFromLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Remove 1 track from your library?} other{Remove {count} tracks from your library?}}'**
  String libraryRemoveFromLibraryTitle(int count);

  /// No description provided for @libraryRemoveFromLibraryMessage.
  ///
  /// In en, this message translates to:
  /// **'Files on disk aren\'t deleted.'**
  String get libraryRemoveFromLibraryMessage;

  /// No description provided for @libraryRemovedFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track removed} other{{count} tracks removed}}'**
  String libraryRemovedFromLibrary(int count);

  /// No description provided for @libraryTrackDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get libraryTrackDetails;

  /// No description provided for @libraryDetailDuration.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get libraryDetailDuration;

  /// No description provided for @libraryDetailFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get libraryDetailFormat;

  /// No description provided for @libraryDetailBitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get libraryDetailBitrate;

  /// No description provided for @libraryKbps.
  ///
  /// In en, this message translates to:
  /// **'{kbps} kbps'**
  String libraryKbps(int kbps);

  /// No description provided for @libraryDetailSampleRate.
  ///
  /// In en, this message translates to:
  /// **'Sample rate'**
  String get libraryDetailSampleRate;

  /// No description provided for @libraryKhz.
  ///
  /// In en, this message translates to:
  /// **'{khz} kHz'**
  String libraryKhz(String khz);

  /// No description provided for @libraryDetailBitDepth.
  ///
  /// In en, this message translates to:
  /// **'Bit depth'**
  String get libraryDetailBitDepth;

  /// No description provided for @libraryBits.
  ///
  /// In en, this message translates to:
  /// **'{bits}-bit'**
  String libraryBits(int bits);

  /// No description provided for @libraryDetailChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get libraryDetailChannels;

  /// No description provided for @libraryDetailSize.
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get libraryDetailSize;

  /// No description provided for @libraryDetailReplayGain.
  ///
  /// In en, this message translates to:
  /// **'ReplayGain'**
  String get libraryDetailReplayGain;

  /// No description provided for @libraryDetailSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get libraryDetailSource;

  /// No description provided for @libraryDetailOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get libraryDetailOffline;

  /// No description provided for @libraryDetailFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get libraryDetailFile;

  /// No description provided for @libraryEditTags.
  ///
  /// In en, this message translates to:
  /// **'Edit tags'**
  String get libraryEditTags;

  /// No description provided for @libraryTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get libraryTagTitle;

  /// No description provided for @libraryTagArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get libraryTagArtists;

  /// No description provided for @libraryTagArtistsHint.
  ///
  /// In en, this message translates to:
  /// **'Separate several artists with ;'**
  String get libraryTagArtistsHint;

  /// No description provided for @libraryTagAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get libraryTagAlbum;

  /// No description provided for @libraryTagAlbumArtist.
  ///
  /// In en, this message translates to:
  /// **'Album artist'**
  String get libraryTagAlbumArtist;

  /// No description provided for @libraryTagYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get libraryTagYear;

  /// No description provided for @libraryTagGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get libraryTagGenre;

  /// No description provided for @libraryTagTrackNumber.
  ///
  /// In en, this message translates to:
  /// **'Track no.'**
  String get libraryTagTrackNumber;

  /// No description provided for @libraryTagDiscNumber.
  ///
  /// In en, this message translates to:
  /// **'Disc no.'**
  String get libraryTagDiscNumber;

  /// No description provided for @libraryTagsFileHint.
  ///
  /// In en, this message translates to:
  /// **'Changes are written to the file when its format allows it; otherwise they\'re kept in your library only.'**
  String get libraryTagsFileHint;

  /// No description provided for @libraryTagsOverrideOnly.
  ///
  /// In en, this message translates to:
  /// **'On this device the file isn\'t changed: your edits are saved in Fermata\'s library.'**
  String get libraryTagsOverrideOnly;

  /// No description provided for @libraryTagsSavedToFile.
  ///
  /// In en, this message translates to:
  /// **'Tags saved to the file'**
  String get libraryTagsSavedToFile;

  /// No description provided for @libraryTagsSavedAsOverride.
  ///
  /// In en, this message translates to:
  /// **'Saved in your library (the file wasn\'t changed)'**
  String get libraryTagsSavedAsOverride;

  /// No description provided for @playlistsNewSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart playlist'**
  String get playlistsNewSmart;

  /// No description provided for @playlistsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get playlistsImport;

  /// No description provided for @playlistsImportFromService.
  ///
  /// In en, this message translates to:
  /// **'Import from a service'**
  String get playlistsImportFromService;

  /// No description provided for @playlistsImportM3u.
  ///
  /// In en, this message translates to:
  /// **'Import M3U file'**
  String get playlistsImportM3u;

  /// No description provided for @playlistsImportM3uEmpty.
  ///
  /// In en, this message translates to:
  /// **'No playable files were found in that playlist file.'**
  String get playlistsImportM3uEmpty;

  /// No description provided for @playlistsImportedM3u.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 track into {name}} other{Imported {count} tracks into {name}}}'**
  String playlistsImportedM3u(int count, String name);

  /// No description provided for @playlistsCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {name}'**
  String playlistsCreated(String name);

  /// No description provided for @playlistsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Make one from scratch, let a smart playlist fill itself, or bring one over from another service.'**
  String get playlistsEmptyMessage;

  /// No description provided for @playlistsFilterYours.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get playlistsFilterYours;

  /// No description provided for @playlistsFilterSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get playlistsFilterSmart;

  /// No description provided for @playlistsFilterImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get playlistsFilterImported;

  /// No description provided for @playlistsShowList.
  ///
  /// In en, this message translates to:
  /// **'Show as list'**
  String get playlistsShowList;

  /// No description provided for @playlistsShowGrid.
  ///
  /// In en, this message translates to:
  /// **'Show as grid'**
  String get playlistsShowGrid;

  /// No description provided for @playlistKindLocal.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlistKindLocal;

  /// No description provided for @playlistKindSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart playlist'**
  String get playlistKindSmart;

  /// No description provided for @playlistKindImported.
  ///
  /// In en, this message translates to:
  /// **'Imported from {provider}'**
  String playlistKindImported(String provider);

  /// No description provided for @playlistOnProvider.
  ///
  /// In en, this message translates to:
  /// **'Playlist on {provider}'**
  String playlistOnProvider(String provider);

  /// No description provided for @playlistBy.
  ///
  /// In en, this message translates to:
  /// **'by {owner}'**
  String playlistBy(String owner);

  /// No description provided for @playlistDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get playlistDescription;

  /// No description provided for @playlistEditDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get playlistEditDetails;

  /// No description provided for @playlistEditRules.
  ///
  /// In en, this message translates to:
  /// **'Edit rules'**
  String get playlistEditRules;

  /// No description provided for @playlistChangeArtwork.
  ///
  /// In en, this message translates to:
  /// **'Change artwork'**
  String get playlistChangeArtwork;

  /// No description provided for @playlistArtworkUpdated.
  ///
  /// In en, this message translates to:
  /// **'Artwork updated'**
  String get playlistArtworkUpdated;

  /// No description provided for @playlistExportM3u.
  ///
  /// In en, this message translates to:
  /// **'Export as M3U'**
  String get playlistExportM3u;

  /// No description provided for @playlistExported.
  ///
  /// In en, this message translates to:
  /// **'Saved to {location}'**
  String playlistExported(String location);

  /// No description provided for @playlistAutoDownload.
  ///
  /// In en, this message translates to:
  /// **'Download automatically'**
  String get playlistAutoDownload;

  /// No description provided for @playlistAutoDownloadOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-download on'**
  String get playlistAutoDownloadOn;

  /// No description provided for @playlistAutoDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download this playlist automatically?'**
  String get playlistAutoDownloadTitle;

  /// No description provided for @playlistAutoDownloadExplain.
  ///
  /// In en, this message translates to:
  /// **'Fermata only downloads tracks automatically when they\'re your own files or the provider permits automatic downloads. None of the streaming services allow that today, so their tracks stay online — you can still download single Audius or Jamendo tracks yourself where the artist allows it.'**
  String get playlistAutoDownloadExplain;

  /// No description provided for @playlistAutoDownloadConfirm.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get playlistAutoDownloadConfirm;

  /// No description provided for @playlistDedupe.
  ///
  /// In en, this message translates to:
  /// **'Remove duplicates'**
  String get playlistDedupe;

  /// No description provided for @playlistNoDuplicates.
  ///
  /// In en, this message translates to:
  /// **'No duplicates found'**
  String get playlistNoDuplicates;

  /// No description provided for @playlistDuplicatesRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Removed 1 duplicate} other{Removed {count} duplicates}}'**
  String playlistDuplicatesRemoved(int count);

  /// No description provided for @playlistDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String playlistDeleteTitle(String name);

  /// No description provided for @playlistDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'The playlist is removed. Its tracks stay in your library.'**
  String get playlistDeleteMessage;

  /// No description provided for @playlistDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}'**
  String playlistDeleted(String name);

  /// No description provided for @playlistNotFound.
  ///
  /// In en, this message translates to:
  /// **'This playlist doesn\'t exist anymore.'**
  String get playlistNotFound;

  /// No description provided for @playlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'This playlist is empty'**
  String get playlistEmpty;

  /// No description provided for @playlistEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add tracks from search, your library or any track menu.'**
  String get playlistEmptyHint;

  /// No description provided for @playlistSmartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches the rules yet'**
  String get playlistSmartEmpty;

  /// No description provided for @playlistSmartEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Edit the rules, or play and like more music.'**
  String get playlistSmartEmptyHint;

  /// No description provided for @playlistRulesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rule} other{{count} rules}}, {match}'**
  String playlistRulesSummary(int count, String match);

  /// No description provided for @playlistRemoveFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get playlistRemoveFromPlaylist;

  /// No description provided for @playlistRemovedTracks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Removed 1 track} other{Removed {count} tracks}}'**
  String playlistRemovedTracks(int count);

  /// No description provided for @playlistPlaysVia.
  ///
  /// In en, this message translates to:
  /// **'Plays via {provider} — change'**
  String playlistPlaysVia(String provider);

  /// No description provided for @playlistSaveToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Save to library'**
  String get playlistSaveToLibrary;

  /// No description provided for @playlistSavedToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Saved {name} to your library'**
  String playlistSavedToLibrary(String name);

  /// No description provided for @smartNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New smart playlist'**
  String get smartNewTitle;

  /// No description provided for @smartEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit smart playlist'**
  String get smartEditTitle;

  /// No description provided for @smartMatch.
  ///
  /// In en, this message translates to:
  /// **'Include tracks that match'**
  String get smartMatch;

  /// No description provided for @smartMatchAll.
  ///
  /// In en, this message translates to:
  /// **'all rules'**
  String get smartMatchAll;

  /// No description provided for @smartMatchAny.
  ///
  /// In en, this message translates to:
  /// **'any rule'**
  String get smartMatchAny;

  /// No description provided for @smartAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get smartAddRule;

  /// No description provided for @smartRemoveRule.
  ///
  /// In en, this message translates to:
  /// **'Remove rule'**
  String get smartRemoveRule;

  /// No description provided for @smartValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get smartValue;

  /// No description provided for @smartPickSource.
  ///
  /// In en, this message translates to:
  /// **'Choose a source'**
  String get smartPickSource;

  /// No description provided for @smartUnitMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get smartUnitMinutes;

  /// No description provided for @smartUnitDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get smartUnitDays;

  /// No description provided for @smartLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get smartLimit;

  /// No description provided for @smartNoLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get smartNoLimit;

  /// No description provided for @smartPreviewLoading.
  ///
  /// In en, this message translates to:
  /// **'Counting matching tracks…'**
  String get smartPreviewLoading;

  /// No description provided for @smartPreviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tracks match} =1{1 track matches} other{{count} tracks match}}'**
  String smartPreviewCount(int count);

  /// No description provided for @smartPreviewApprox.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{About 1 track matches} other{About {count} tracks match}}'**
  String smartPreviewApprox(int count);

  /// No description provided for @smartFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get smartFieldTitle;

  /// No description provided for @smartFieldArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get smartFieldArtist;

  /// No description provided for @smartFieldAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get smartFieldAlbum;

  /// No description provided for @smartFieldGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get smartFieldGenre;

  /// No description provided for @smartFieldYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get smartFieldYear;

  /// No description provided for @smartFieldDuration.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get smartFieldDuration;

  /// No description provided for @smartFieldPlayCount.
  ///
  /// In en, this message translates to:
  /// **'Play count'**
  String get smartFieldPlayCount;

  /// No description provided for @smartFieldLastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last played'**
  String get smartFieldLastPlayed;

  /// No description provided for @smartFieldDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get smartFieldDateAdded;

  /// No description provided for @smartFieldSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get smartFieldSource;

  /// No description provided for @smartFieldFavorite.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get smartFieldFavorite;

  /// No description provided for @smartFieldDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get smartFieldDownloaded;

  /// No description provided for @smartOpContains.
  ///
  /// In en, this message translates to:
  /// **'contains'**
  String get smartOpContains;

  /// No description provided for @smartOpNotContains.
  ///
  /// In en, this message translates to:
  /// **'doesn\'t contain'**
  String get smartOpNotContains;

  /// No description provided for @smartOpEquals.
  ///
  /// In en, this message translates to:
  /// **'is'**
  String get smartOpEquals;

  /// No description provided for @smartOpNotEquals.
  ///
  /// In en, this message translates to:
  /// **'isn\'t'**
  String get smartOpNotEquals;

  /// No description provided for @smartOpStartsWith.
  ///
  /// In en, this message translates to:
  /// **'starts with'**
  String get smartOpStartsWith;

  /// No description provided for @smartOpGreaterThan.
  ///
  /// In en, this message translates to:
  /// **'is more than'**
  String get smartOpGreaterThan;

  /// No description provided for @smartOpLessThan.
  ///
  /// In en, this message translates to:
  /// **'is less than'**
  String get smartOpLessThan;

  /// No description provided for @smartOpInLastDays.
  ///
  /// In en, this message translates to:
  /// **'in the last'**
  String get smartOpInLastDays;

  /// No description provided for @smartOpNotInLastDays.
  ///
  /// In en, this message translates to:
  /// **'not in the last'**
  String get smartOpNotInLastDays;

  /// No description provided for @smartOpIsTrue.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get smartOpIsTrue;

  /// No description provided for @smartOpIsFalse.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get smartOpIsFalse;

  /// No description provided for @alternativesFind.
  ///
  /// In en, this message translates to:
  /// **'Find alternatives'**
  String get alternativesFind;

  /// No description provided for @alternativesTitle.
  ///
  /// In en, this message translates to:
  /// **'Alternatives'**
  String get alternativesTitle;

  /// No description provided for @alternativesLinkedNow.
  ///
  /// In en, this message translates to:
  /// **'Linked now'**
  String get alternativesLinkedNow;

  /// No description provided for @alternativesSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested matches'**
  String get alternativesSuggested;

  /// No description provided for @alternativesSearch.
  ///
  /// In en, this message translates to:
  /// **'Search yourself'**
  String get alternativesSearch;

  /// No description provided for @alternativesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Title and artist, then press Enter'**
  String get alternativesSearchHint;

  /// No description provided for @alternativesNone.
  ///
  /// In en, this message translates to:
  /// **'No matches found.'**
  String get alternativesNone;

  /// No description provided for @alternativesUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get alternativesUse;

  /// No description provided for @alternativesInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get alternativesInUse;

  /// No description provided for @alternativesUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get alternativesUnlink;

  /// No description provided for @alternativesLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked — plays from {provider}'**
  String alternativesLinked(String provider);

  /// No description provided for @alternativesScore.
  ///
  /// In en, this message translates to:
  /// **'{percent}% · {confidence}'**
  String alternativesScore(int percent, String confidence);

  /// No description provided for @matchExact.
  ///
  /// In en, this message translates to:
  /// **'exact match'**
  String get matchExact;

  /// No description provided for @matchHigh.
  ///
  /// In en, this message translates to:
  /// **'very likely'**
  String get matchHigh;

  /// No description provided for @matchMedium.
  ///
  /// In en, this message translates to:
  /// **'possible'**
  String get matchMedium;

  /// No description provided for @matchLow.
  ///
  /// In en, this message translates to:
  /// **'unlikely'**
  String get matchLow;

  /// No description provided for @matchNone.
  ///
  /// In en, this message translates to:
  /// **'no match'**
  String get matchNone;

  /// No description provided for @diffRemix.
  ///
  /// In en, this message translates to:
  /// **'remix'**
  String get diffRemix;

  /// No description provided for @diffLive.
  ///
  /// In en, this message translates to:
  /// **'live'**
  String get diffLive;

  /// No description provided for @diffAcoustic.
  ///
  /// In en, this message translates to:
  /// **'acoustic'**
  String get diffAcoustic;

  /// No description provided for @diffExtended.
  ///
  /// In en, this message translates to:
  /// **'extended'**
  String get diffExtended;

  /// No description provided for @diffRadioEdit.
  ///
  /// In en, this message translates to:
  /// **'radio edit'**
  String get diffRadioEdit;

  /// No description provided for @diffInstrumental.
  ///
  /// In en, this message translates to:
  /// **'instrumental'**
  String get diffInstrumental;

  /// No description provided for @diffKaraoke.
  ///
  /// In en, this message translates to:
  /// **'karaoke'**
  String get diffKaraoke;

  /// No description provided for @diffCover.
  ///
  /// In en, this message translates to:
  /// **'cover'**
  String get diffCover;

  /// No description provided for @diffRemaster.
  ///
  /// In en, this message translates to:
  /// **'remaster'**
  String get diffRemaster;

  /// No description provided for @diffSped.
  ///
  /// In en, this message translates to:
  /// **'sped up'**
  String get diffSped;

  /// No description provided for @diffSlowed.
  ///
  /// In en, this message translates to:
  /// **'slowed'**
  String get diffSlowed;

  /// No description provided for @diffDemo.
  ///
  /// In en, this message translates to:
  /// **'demo'**
  String get diffDemo;

  /// No description provided for @diffExplicit.
  ///
  /// In en, this message translates to:
  /// **'explicit differs'**
  String get diffExplicit;

  /// No description provided for @diffDuration.
  ///
  /// In en, this message translates to:
  /// **'length differs'**
  String get diffDuration;

  /// No description provided for @diffAlbum.
  ///
  /// In en, this message translates to:
  /// **'other album'**
  String get diffAlbum;

  /// No description provided for @diffYear.
  ///
  /// In en, this message translates to:
  /// **'other year'**
  String get diffYear;

  /// No description provided for @diffArtist.
  ///
  /// In en, this message translates to:
  /// **'other artist'**
  String get diffArtist;

  /// No description provided for @diffFeatured.
  ///
  /// In en, this message translates to:
  /// **'featured artists differ'**
  String get diffFeatured;

  /// No description provided for @diffTitle.
  ///
  /// In en, this message translates to:
  /// **'title differs'**
  String get diffTitle;

  /// No description provided for @diffPreview.
  ///
  /// In en, this message translates to:
  /// **'preview only'**
  String get diffPreview;

  /// No description provided for @artistInLibrary.
  ///
  /// In en, this message translates to:
  /// **'Artist in your library'**
  String get artistInLibrary;

  /// No description provided for @artistOnProvider.
  ///
  /// In en, this message translates to:
  /// **'Artist on {provider}'**
  String artistOnProvider(String provider);

  /// No description provided for @artistFollowers.
  ///
  /// In en, this message translates to:
  /// **'{count} followers'**
  String artistFollowers(String count);

  /// No description provided for @artistTopTracks.
  ///
  /// In en, this message translates to:
  /// **'Popular tracks'**
  String get artistTopTracks;

  /// No description provided for @artistTracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get artistTracks;

  /// No description provided for @artistNoTracks.
  ///
  /// In en, this message translates to:
  /// **'No tracks found.'**
  String get artistNoTracks;

  /// No description provided for @artistAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get artistAlbums;

  /// No description provided for @artistReleases.
  ///
  /// In en, this message translates to:
  /// **'Releases'**
  String get artistReleases;

  /// No description provided for @artistRelated.
  ///
  /// In en, this message translates to:
  /// **'Fans also like'**
  String get artistRelated;

  /// No description provided for @albumInLibrary.
  ///
  /// In en, this message translates to:
  /// **'Album in your library'**
  String get albumInLibrary;

  /// No description provided for @albumOnProvider.
  ///
  /// In en, this message translates to:
  /// **'Album on {provider}'**
  String albumOnProvider(String provider);

  /// No description provided for @albumDisc.
  ///
  /// In en, this message translates to:
  /// **'Disc {number}'**
  String albumDisc(int number);

  /// No description provided for @albumEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tracks on this album.'**
  String get albumEmpty;

  /// No description provided for @downloadsPauseAll.
  ///
  /// In en, this message translates to:
  /// **'Pause all'**
  String get downloadsPauseAll;

  /// No description provided for @downloadsResumeAll.
  ///
  /// In en, this message translates to:
  /// **'Resume all'**
  String get downloadsResumeAll;

  /// No description provided for @downloadsPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get downloadsPause;

  /// No description provided for @downloadsResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get downloadsResume;

  /// No description provided for @downloadsProgress.
  ///
  /// In en, this message translates to:
  /// **'Download progress'**
  String get downloadsProgress;

  /// No description provided for @downloadsFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get downloadsFilterActive;

  /// No description provided for @downloadsFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get downloadsFilterCompleted;

  /// No description provided for @downloadsFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get downloadsFilterFailed;

  /// No description provided for @downloadsActive.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadsActive;

  /// No description provided for @downloadsActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 in the queue} other{{count} in the queue}}'**
  String downloadsActiveCount(int count);

  /// No description provided for @downloadsFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get downloadsFinished;

  /// No description provided for @downloadsNothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here right now.'**
  String get downloadsNothingHere;

  /// No description provided for @downloadsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet'**
  String get downloadsEmptyTitle;

  /// No description provided for @downloadsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Tracks can be downloaded only where the provider allows it — Audius and Jamendo tracks the artist made downloadable. Your own files already play offline.'**
  String get downloadsEmptyMessage;

  /// No description provided for @downloadsStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get downloadsStatusQueued;

  /// No description provided for @downloadsStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get downloadsStatusWaiting;

  /// No description provided for @downloadsStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadsStatusDownloading;

  /// No description provided for @downloadsStatusVerifying.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get downloadsStatusVerifying;

  /// No description provided for @downloadsStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadsStatusPaused;

  /// No description provided for @downloadsStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloadsStatusCompleted;

  /// No description provided for @downloadsStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get downloadsStatusFailed;

  /// No description provided for @downloadsStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get downloadsStatusCanceled;

  /// No description provided for @downloadsSizeOf.
  ///
  /// In en, this message translates to:
  /// **'{received} of {total}'**
  String downloadsSizeOf(String received, String total);

  /// No description provided for @downloadsSpeed.
  ///
  /// In en, this message translates to:
  /// **'{speed}/s'**
  String downloadsSpeed(String speed);

  /// No description provided for @downloadsEta.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String downloadsEta(String time);

  /// No description provided for @downloadsAttempts.
  ///
  /// In en, this message translates to:
  /// **'{count} attempts'**
  String downloadsAttempts(int count);

  /// No description provided for @downloadsWaitingWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Wi-Fi'**
  String get downloadsWaitingWifiTitle;

  /// No description provided for @downloadsWaitingWifi.
  ///
  /// In en, this message translates to:
  /// **'Downloads only run on Wi-Fi. They continue by themselves when you connect.'**
  String get downloadsWaitingWifi;

  /// No description provided for @downloadsDownloadSettings.
  ///
  /// In en, this message translates to:
  /// **'Download settings'**
  String get downloadsDownloadSettings;

  /// No description provided for @downloadsWaitingConnection.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an internet connection.'**
  String get downloadsWaitingConnection;

  /// No description provided for @downloadsWaitingMobileData.
  ///
  /// In en, this message translates to:
  /// **'You\'re on mobile data. Downloads wait until you allow it or connect to Wi-Fi.'**
  String get downloadsWaitingMobileData;

  /// No description provided for @downloadsMobileDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Download over mobile data?'**
  String get downloadsMobileDataTitle;

  /// No description provided for @downloadsMobileDataMessage.
  ///
  /// In en, this message translates to:
  /// **'This can use a lot of data. You\'ll be asked again the next time you start Fermata.'**
  String get downloadsMobileDataMessage;

  /// No description provided for @downloadsMobileDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Use mobile data'**
  String get downloadsMobileDataConfirm;

  /// No description provided for @downloadsMobileDataWait.
  ///
  /// In en, this message translates to:
  /// **'Wait for Wi-Fi'**
  String get downloadsMobileDataWait;

  /// No description provided for @downloadsMobileDataAllowed.
  ///
  /// In en, this message translates to:
  /// **'Downloading over mobile data'**
  String get downloadsMobileDataAllowed;

  /// No description provided for @downloadsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get downloadsStorage;

  /// No description provided for @downloadsStorageSettings.
  ///
  /// In en, this message translates to:
  /// **'Storage settings'**
  String get downloadsStorageSettings;

  /// No description provided for @downloadsStorageDownloads.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Downloads (1 track)} other{Downloads ({count} tracks)}}'**
  String downloadsStorageDownloads(int count);

  /// No description provided for @downloadsStorageArtwork.
  ///
  /// In en, this message translates to:
  /// **'Artwork cache'**
  String get downloadsStorageArtwork;

  /// No description provided for @downloadsStorageStreamCache.
  ///
  /// In en, this message translates to:
  /// **'Stream cache'**
  String get downloadsStorageStreamCache;

  /// No description provided for @downloadsStorageDatabase.
  ///
  /// In en, this message translates to:
  /// **'Library database'**
  String get downloadsStorageDatabase;

  /// No description provided for @downloadsStorageLimit.
  ///
  /// In en, this message translates to:
  /// **'Download limit'**
  String get downloadsStorageLimit;

  /// No description provided for @downloadsStorageFree.
  ///
  /// In en, this message translates to:
  /// **'Free on this device'**
  String get downloadsStorageFree;

  /// No description provided for @downloadsUnlimited.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get downloadsUnlimited;

  /// No description provided for @downloadsErrorSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service isn\'t available right now.'**
  String get downloadsErrorSourceUnavailable;

  /// No description provided for @downloadsErrorAuth.
  ///
  /// In en, this message translates to:
  /// **'Reconnect the service to download.'**
  String get downloadsErrorAuth;

  /// No description provided for @downloadsErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'The file is gone from the service.'**
  String get downloadsErrorNotFound;

  /// No description provided for @downloadsErrorForbidden.
  ///
  /// In en, this message translates to:
  /// **'The service refused the download.'**
  String get downloadsErrorForbidden;

  /// No description provided for @downloadsErrorServer.
  ///
  /// In en, this message translates to:
  /// **'The service had a problem. Try again later.'**
  String get downloadsErrorServer;

  /// No description provided for @downloadsErrorNotAudio.
  ///
  /// In en, this message translates to:
  /// **'The service didn\'t send an audio file.'**
  String get downloadsErrorNotAudio;

  /// No description provided for @downloadsErrorCorrupt.
  ///
  /// In en, this message translates to:
  /// **'The file arrived damaged. Try again.'**
  String get downloadsErrorCorrupt;

  /// No description provided for @downloadsErrorDiskFull.
  ///
  /// In en, this message translates to:
  /// **'Not enough free space.'**
  String get downloadsErrorDiskFull;

  /// No description provided for @favoritesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Songs you like show up here'**
  String get favoritesEmptyTitle;

  /// No description provided for @favoritesEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any track to keep it close.'**
  String get favoritesEmptyMessage;

  /// No description provided for @favoritesFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter liked songs'**
  String get favoritesFilterHint;

  /// No description provided for @favoritesSortRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently liked'**
  String get favoritesSortRecent;

  /// No description provided for @historyRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get historyRecent;

  /// No description provided for @historyStats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get historyStats;

  /// No description provided for @historyClear.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get historyClear;

  /// No description provided for @historyClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear your listening history?'**
  String get historyClearTitle;

  /// No description provided for @historyClearMessage.
  ///
  /// In en, this message translates to:
  /// **'Recently played and statistics are deleted from this device. Recommendations start over.'**
  String get historyClearMessage;

  /// No description provided for @historyCleared.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get historyCleared;

  /// No description provided for @historyRecordingOff.
  ///
  /// In en, this message translates to:
  /// **'Listening history is turned off, so new plays aren\'t saved.'**
  String get historyRecordingOff;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing played yet'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'What you listen to shows up here, grouped by day.'**
  String get historyEmptyMessage;

  /// No description provided for @historyStatsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Play some music to see your statistics.'**
  String get historyStatsEmpty;

  /// No description provided for @historyStatsPeriod.
  ///
  /// In en, this message translates to:
  /// **'Last {days} days, calculated on this device'**
  String historyStatsPeriod(int days);

  /// No description provided for @historyStatsPlays.
  ///
  /// In en, this message translates to:
  /// **'Plays'**
  String get historyStatsPlays;

  /// No description provided for @historyStatsTime.
  ///
  /// In en, this message translates to:
  /// **'Listening time'**
  String get historyStatsTime;

  /// No description provided for @historyStatsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Plays per day'**
  String get historyStatsPerDay;

  /// No description provided for @historyStatsTopTracks.
  ///
  /// In en, this message translates to:
  /// **'Top tracks'**
  String get historyStatsTopTracks;

  /// No description provided for @historyStatsTopArtists.
  ///
  /// In en, this message translates to:
  /// **'Top artists'**
  String get historyStatsTopArtists;

  /// No description provided for @historyStatsTopGenres.
  ///
  /// In en, this message translates to:
  /// **'Top genres'**
  String get historyStatsTopGenres;

  /// No description provided for @historyPlays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 play} other{{count} plays}}'**
  String historyPlays(int count);

  /// No description provided for @historyChartLabel.
  ///
  /// In en, this message translates to:
  /// **'Plays per day over the last {days} days: {total} in total, at most {peak} in one day'**
  String historyChartLabel(int days, int total, int peak);

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
