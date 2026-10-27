// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Danish (`da`).
class AppLocalizationsDa extends AppLocalizations {
  AppLocalizationsDa([String locale = 'da']) : super(locale);

  @override
  String get appName => 'Fermata';

  @override
  String get actionCancel => 'Annuller';

  @override
  String get actionSave => 'Gem';

  @override
  String get actionDelete => 'Slet';

  @override
  String get actionRetry => 'Prøv igen';

  @override
  String get actionClose => 'Luk';

  @override
  String get actionDone => 'Færdig';

  @override
  String get actionOk => 'OK';

  @override
  String get actionLearnMore => 'Læs mere';

  @override
  String get actionRestoreDefaults => 'Gendan standarder';

  @override
  String get errorGeneric => 'Noget gik galt.';

  @override
  String get errorOffline =>
      'Du er offline. Tjek din forbindelse, og prøv igen.';

  @override
  String get errorTimeout => 'Forespørgslen tog for lang tid. Prøv igen.';

  @override
  String get errorRateLimited => 'Tjenesten har travlt. Prøv igen om lidt.';

  @override
  String errorAuthRequired(String service) {
    return 'Forbind din $service-konto igen for at fortsætte.';
  }

  @override
  String errorCredentialsMissing(String service) {
    return '$service skal have udvikler-legitimationsoplysninger, før den kan bruges.';
  }

  @override
  String errorUnsupported(String service) {
    return '$service understøtter ikke dette.';
  }

  @override
  String get reasonDeleted => 'Nummeret er slettet.';

  @override
  String get reasonPrivate => 'Nummeret er privat.';

  @override
  String get reasonRegionRestricted => 'Ikke tilgængeligt i dit område.';

  @override
  String get reasonSubscriptionRequired =>
      'Kræver et abonnement hos udbyderen.';

  @override
  String get reasonNotStreamable => 'Kunstneren har ikke tilladt streaming.';

  @override
  String get reasonPreviewOnly => 'Kun et uddrag er tilgængeligt.';

  @override
  String get reasonExternalOnly => 'Afspilles i udbyderens egen app.';

  @override
  String get reasonFileMissing => 'Filen mangler.';

  @override
  String get reasonNotAuthorized => 'Ikke autoriseret.';

  @override
  String get reasonCredentialsMissing => 'Udbyderen er ikke sat op.';

  @override
  String get reasonOffline => 'Ikke tilgængelig offline.';

  @override
  String get reasonUnknown => 'Ikke tilgængelig.';

  @override
  String get offlineUserOwned => 'Din fil';

  @override
  String get offlineDownloadable => 'Kan downloades';

  @override
  String get offlineStreamOnly => 'Kun streaming';

  @override
  String get offlineUnavailable => 'Ikke tilgængelig offline';
}
