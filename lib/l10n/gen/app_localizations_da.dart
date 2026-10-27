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

  @override
  String get desktopTrayNotPlaying => 'Der afspilles intet';

  @override
  String desktopTrayNowPlaying(String title, String artist) {
    return '$title — $artist';
  }

  @override
  String get desktopTrayPlay => 'Afspil';

  @override
  String get desktopTrayPause => 'Pause';

  @override
  String get desktopTrayPrevious => 'Forrige';

  @override
  String get desktopTrayNext => 'Næste';

  @override
  String get desktopTrayShow => 'Vis Fermata';

  @override
  String get desktopTrayQuit => 'Afslut Fermata';

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
      'GNOME viser kun ikoner i systembakken med udvidelsen AppIndicator. Uden den bliver Fermata minimeret, når du lukker vinduet, og du kan hente den frem igen fra docken eller mediekontrollerne.';

  @override
  String get desktopTrayUnavailableNoHost =>
      'Skrivebordet har ingen systembakke (der kører ingen StatusNotifier-vært). Når du lukker vinduet, bliver Fermata minimeret i stedet.';

  @override
  String get desktopTrayUnavailableNoBus =>
      'Fermata kan ikke få forbindelse til skrivebordets sessionsbus og kan derfor ikke vise et ikon i systembakken. Når du lukker vinduet, bliver Fermata minimeret i stedet.';

  @override
  String get desktopTrayUnavailableIconMissing =>
      'Ikonfilen til systembakken mangler i installationen, så ikonet er slået fra. Det burde hjælpe at geninstallere Fermata.';

  @override
  String get desktopTrayUnavailableDisabled =>
      'Ikonet i systembakken er slået fra. Når du lukker vinduet, bliver Fermata minimeret i stedet.';

  @override
  String get desktopTrayUnavailableFailed =>
      'Systembakken afviste ikonet. Når du lukker vinduet, bliver Fermata minimeret i stedet.';

  @override
  String get desktopTrayUnavailableUnsupported =>
      'Denne platform har ingen systembakke.';

  @override
  String get desktopCloseDialogTitle => 'Vil du lukke Fermata?';

  @override
  String get desktopCloseDialogBody =>
      'Fermata kan fortsætte med at spille i baggrunden. Du kan hente den frem igen fra ikonet i systembakken eller skrivebordets mediekontroller.';

  @override
  String get desktopCloseDialogKeepPlaying => 'Spil videre i baggrunden';

  @override
  String get desktopCloseDialogQuit => 'Afslut';

  @override
  String get desktopCloseDialogRemember => 'Spørg ikke igen';

  @override
  String desktopHotkeyErrorInvalid(String binding) {
    return '“$binding” er ikke en gyldig genvej.';
  }

  @override
  String desktopHotkeyErrorNeedsModifier(String binding) {
    return '“$binding” skal bruge Ctrl, Alt, Shift eller Super, ellers ville den blokere almindelig indtastning i alle programmer.';
  }

  @override
  String desktopHotkeyErrorDuplicate(String binding) {
    return '“$binding” bruges allerede af en anden global genvej.';
  }

  @override
  String desktopHotkeyErrorFailed(String binding) {
    return 'Kunne ikke registrere “$binding”. Et andet program bruger den måske allerede.';
  }

  @override
  String get desktopHotkeysUnsupportedWayland =>
      'Globale genveje virker ikke i Wayland-sessioner. Brug i stedet skrivebordets tastaturindstillinger: medietaster og kommandoer som “playerctl play-pause” styrer Fermata via MPRIS.';

  @override
  String get desktopHotkeysUnsupportedPlatform =>
      'Globale genveje findes ikke på denne platform.';

  @override
  String get desktopUnknownArtist => 'Ukendt kunstner';
}
