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
}
