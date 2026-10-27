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
}
