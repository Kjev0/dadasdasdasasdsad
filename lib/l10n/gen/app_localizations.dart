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
