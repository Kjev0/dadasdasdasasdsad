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
  String get reasonSiloed =>
      'SoundCloud-numre afspilles i deres egen kø (SoundClouds vilkår).';

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

  @override
  String get importTitle => 'Importér en playliste';

  @override
  String get importBack => 'Tilbage';

  @override
  String get importStepSource => 'Kilde';

  @override
  String get importStepPlaylist => 'Playliste';

  @override
  String get importStepOptions => 'Matchning';

  @override
  String importStepOf(int step, int total, String name) {
    return 'Trin $step af $total: $name';
  }

  @override
  String get importChooseSource => 'Hvor er playlisten?';

  @override
  String get importChooseSourceHint =>
      'Fermata finder hvert nummer hos de tjenester, du vælger bagefter, og beholder et link til originalen.';

  @override
  String get importM3uTitle => 'En playlistefil (M3U)';

  @override
  String get importM3uHint =>
      'Numre fra en .m3u- eller .m3u8-fil på denne enhed.';

  @override
  String get importM3uUnreadable => 'Playlistefilen kan ikke læses.';

  @override
  String get importM3uEmpty =>
      'Der blev ikke fundet nogen numre i playlistefilen.';

  @override
  String importSourceNotSetUp(String service) {
    return '$service er ikke sat op endnu.';
  }

  @override
  String get importSourceLinkOnly =>
      'Offentlige playlister via link. Forbind for at se dine egne playlister.';

  @override
  String get importSourceConnectFirst => 'Forbind din konto for at importere.';

  @override
  String importSourceSignedIn(String name) {
    return 'Logget ind som $name';
  }

  @override
  String get importSetUp => 'Sæt op';

  @override
  String importChooseWhat(String service) {
    return 'Hvad vil du importere fra $service?';
  }

  @override
  String get importPasteLink => 'Indsæt et link til en playliste';

  @override
  String importPasteLinkHint(String service) {
    return 'Et link eller id til en playliste hos $service';
  }

  @override
  String get importContinue => 'Fortsæt';

  @override
  String get importLikedTracks => 'Likede numre';

  @override
  String importLikedTracksHint(String service) {
    return 'Alle numre, du har liket hos $service.';
  }

  @override
  String importLikedName(String service) {
    return 'Liket hos $service';
  }

  @override
  String get importYourPlaylists => 'Dine playlister';

  @override
  String get importNoPlaylists => 'Du har ingen playlister der endnu.';

  @override
  String importTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre',
      one: '1 nummer',
    );
    return '$_temp0';
  }

  @override
  String importConnectForLibrary(String service) {
    return 'Forbind din $service-konto i Indstillinger for at importere dine egne playlister og likede numre.';
  }

  @override
  String get importOptionsTitle => 'Hvor skal Fermata lede?';

  @override
  String importSummaryPlaylist(String name, String service) {
    return '“$name” fra $service';
  }

  @override
  String importSummaryLink(String service) {
    return 'Et playlistelink fra $service';
  }

  @override
  String importSummaryLiked(String service) {
    return 'Dine likede numre hos $service';
  }

  @override
  String importSummaryM3u(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre',
      one: '1 nummer',
    );
    return '“$name” ($_temp0)';
  }

  @override
  String get importTargets => 'Find match hos';

  @override
  String get importTargetsHint =>
      'I denne rækkefølge. Den første tjeneste med et godt match bruges til afspilning.';

  @override
  String get importNoTargets =>
      'Ingen af dine tjenester kan afspille matchene. Forbind først en tjeneste som SoundCloud eller Audius.';

  @override
  String get importTargetNotReady => 'Ikke forbundet eller ikke sat op';

  @override
  String get importMatchingGroup => 'Matchning';

  @override
  String get importStart => 'Start import';

  @override
  String importFetchingLiked(int count) {
    return 'Hentede $count likede numre…';
  }

  @override
  String get importNothingToImport => 'Der er ingen numre at importere.';

  @override
  String get importStartFailed => 'Importen kunne ikke startes.';

  @override
  String get importReviewTitle => 'Gennemgå match';

  @override
  String get importReviewHint =>
      'Tjek de match, Fermata ikke var sikker på. Intet gemmes, før du trykker Gem.';

  @override
  String get importUntitled => 'Importeret playliste';

  @override
  String get importImporting => 'Importerer…';

  @override
  String get importPhaseFetching => 'Henter playlisten…';

  @override
  String get importPhaseMatchingStart => 'Finder match…';

  @override
  String importPhaseMatching(int processed, int total) {
    return '$processed af $total numre matchet';
  }

  @override
  String get importPhaseSaving => 'Gemmer…';

  @override
  String get importCancelImport => 'Annullér import';

  @override
  String get importCancelTitle => 'Annullér denne import?';

  @override
  String get importCancelBody => 'Dine valg forkastes. Intet er gemt endnu.';

  @override
  String get importCanceled => 'Importen blev annulleret.';

  @override
  String get importFailed => 'Importen mislykkedes';

  @override
  String get importStartNew => 'Start en ny import';

  @override
  String get importSessionMissing => 'Denne import er ikke tilgængelig længere';

  @override
  String get importSessionMissingHint =>
      'Igangværende importer gemmes, indtil Fermata lukkes.';

  @override
  String importFilterAll(int count) {
    return 'Alle · $count';
  }

  @override
  String get importFilterEmpty => 'Ingen numre med denne status.';

  @override
  String get importDecisionAuto => 'Automatisk accepteret';

  @override
  String get importDecisionAccepted => 'Accepteret';

  @override
  String get importDecisionReview => 'Skal gennemgås';

  @override
  String get importDecisionNotFound => 'Ikke fundet';

  @override
  String get importDecisionRejected => 'Afvist';

  @override
  String get importDecisionSkipped => 'Sprunget over';

  @override
  String importAcceptAllHigh(int count) {
    return 'Acceptér alle sikre ($count)';
  }

  @override
  String get importSavePlaylist => 'Gem playliste';

  @override
  String get importSaveTitle => 'Navngiv playlisten';

  @override
  String get importSavePendingTitle => 'Nogle numre skal stadig gennemgås';

  @override
  String importSavePendingBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre er ikke gennemgået. De gemmes uden match.',
      one: '1 nummer er ikke gennemgået. Det gemmes uden match.',
    );
    return '$_temp0';
  }

  @override
  String get importSaveAnyway => 'Gem alligevel';

  @override
  String get importSaved => 'Playliste gemt';

  @override
  String get importSaveFailed => 'Playlisten kunne ikke gemmes.';

  @override
  String get importDoneTitle => 'Playliste gemt';

  @override
  String get importDoneAll => 'Alle numre har et match.';

  @override
  String importDoneMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre har intet match.',
      one: '1 nummer har intet match.',
    );
    return '$_temp0';
  }

  @override
  String get importOpenPlaylist => 'Åbn playliste';

  @override
  String get importShowMissing => 'Vis manglende numre';

  @override
  String importMissingTitle(int count) {
    return 'Numre uden match ($count)';
  }

  @override
  String importReportHeader(String name, int count) {
    return 'Numre uden match i “$name” ($count):';
  }

  @override
  String get importOriginal => 'Original';

  @override
  String get importMatch => 'Match';

  @override
  String get importNoMatch => 'Intet match fundet';

  @override
  String get importOnlyOtherVersions =>
      'Kun andre versioner fundet — vælg selv en, hvis den er rigtig.';

  @override
  String get importAccept => 'Acceptér';

  @override
  String get importReject => 'Afvis';

  @override
  String get importSkip => 'Spring over';

  @override
  String importOtherCandidates(int count) {
    return 'Kandidater ($count)';
  }

  @override
  String importCandidatesTitle(String title) {
    return 'Kandidater til “$title”';
  }

  @override
  String get importUseThis => 'Brug denne';

  @override
  String get importDifferentVersionWarning =>
      'Dette er en anden version end originalen.';

  @override
  String get importSearch => 'Søg';

  @override
  String importSearchFor(String title) {
    return 'Søg efter “$title”';
  }

  @override
  String get importSearchNoResults => 'Intet fundet. Prøv andre ord.';

  @override
  String get importSearchResults => 'Resultater';

  @override
  String get importMatchedByIsrc => 'Samme ISRC';

  @override
  String importConfidenceSemantics(String level, int percent) {
    return 'Sikkerhed $level, $percent procent';
  }

  @override
  String get importConfidenceExact => 'Præcis';

  @override
  String get importConfidenceHigh => 'Høj';

  @override
  String get importConfidenceMedium => 'Mellem';

  @override
  String get importConfidenceLow => 'Lav';

  @override
  String get importConfidenceNone => 'Ingen';

  @override
  String get importDiffRemix => 'Remix';

  @override
  String get importDiffLive => 'Live';

  @override
  String get importDiffAcoustic => 'Akustisk';

  @override
  String get importDiffExtended => 'Forlænget';

  @override
  String get importDiffRadioEdit => 'Radioversion';

  @override
  String get importDiffInstrumental => 'Instrumental';

  @override
  String get importDiffKaraoke => 'Karaoke';

  @override
  String get importDiffCover => 'Coverversion';

  @override
  String get importDiffRemaster => 'Remaster';

  @override
  String get importDiffSped => 'Hurtigere';

  @override
  String get importDiffSlowed => 'Langsommere';

  @override
  String get importDiffDemo => 'Demo';

  @override
  String get importDiffExplicit => 'Forskel i eksplicit indhold';

  @override
  String get importDiffDuration => 'Anden længde';

  @override
  String get importDiffAlbum => 'Andet album';

  @override
  String get importDiffYear => 'Andet år';

  @override
  String get importDiffArtist => 'Anden kunstner';

  @override
  String get importDiffFeatured => 'Andre gæstekunstnere';

  @override
  String get importDiffTitle => 'Anden titel';

  @override
  String get importDiffPreview => 'Kun smagsprøve';

  @override
  String importOpenOn(String service) {
    return 'Åbn på $service';
  }

  @override
  String get importOpenUploader => 'Uploader';

  @override
  String get onboardingSkip => 'Spring over';

  @override
  String get onboardingBack => 'Tilbage';

  @override
  String get onboardingNext => 'Næste';

  @override
  String get onboardingGetStarted => 'Kom i gang';

  @override
  String get onboardingFinish => 'Begynd at lytte';

  @override
  String onboardingStepOf(int step, int total) {
    return 'Trin $step af $total';
  }

  @override
  String get onboardingWelcomeTitle => 'Velkommen til Fermata';

  @override
  String get onboardingWelcomeBody =>
      'En rolig musikafspiller til den musik, du ejer, og de tjenester, du allerede bruger.';

  @override
  String get onboardingPointFiles =>
      'Dine egne filer kommer først og virker altid offline.';

  @override
  String get onboardingPointServices =>
      'Søg i SoundCloud, Audius og flere på ét sted, og tag dine playlister med.';

  @override
  String get onboardingPointBackground =>
      'Spiller videre i baggrunden, med dine medietaster og låseskærmen.';

  @override
  String get onboardingPointPrivacy =>
      'Ingen reklamer, ingen sporing. Anbefalinger beregnes på din enhed.';

  @override
  String get onboardingMusicTitle => 'Tilføj din musik';

  @override
  String get onboardingMusicBody =>
      'Vælg de mapper, hvor dine musikfiler ligger. Fermata læser dem i baggrunden og holder øje med nye filer.';

  @override
  String get onboardingAudioPermissionRationale =>
      'For at afspille musikken på din telefon skal Fermata have tilladelse til at læse dine lydfiler. Den læser kun musik — aldrig billeder, beskeder eller andre filer.';

  @override
  String get onboardingAllowAudio => 'Giv adgang til musik';

  @override
  String get onboardingAudioDenied =>
      'Uden denne tilladelse kan Fermata ikke se dine musikfiler. Du kan tillade det senere i systemindstillingerne.';

  @override
  String get onboardingSuggestedFolder => 'Din musikmappe';

  @override
  String get onboardingAdd => 'Tilføj';

  @override
  String get onboardingChooseFolder => 'Vælg en mappe…';

  @override
  String get onboardingFolderMissing => 'Den mappe findes ikke længere.';

  @override
  String get onboardingScanning => 'Fermata læser din musik i baggrunden.';

  @override
  String get onboardingMusicLater =>
      'Du kan tilføje eller fjerne mapper når som helst under Bibliotek.';

  @override
  String get onboardingServicesTitle => 'Forbind dine tjenester';

  @override
  String get onboardingServicesBody =>
      'Valgfrit. Forbind en konto for at søge i den, streame fra den og importere dine playlister. Du logger ind på tjenestens egen hjemmeside — Fermata ser aldrig din adgangskode.';

  @override
  String get onboardingRecommended => 'Anbefalet';

  @override
  String get onboardingServiceHint => 'Log ind for at bruge din konto.';

  @override
  String get onboardingNeedsCredentials =>
      'Kræver først udviklernøgler — du kan sætte det op senere i Indstillinger.';

  @override
  String onboardingConnectedAs(String name) {
    return 'Forbundet som $name';
  }

  @override
  String onboardingNoAccountNeeded(String services) {
    return 'Ingen konto nødvendig til: $services.';
  }

  @override
  String get onboardingServicesLater =>
      'Du kan forbinde eller afbryde tjenester når som helst i Indstillinger → Forbundne tjenester.';

  @override
  String get onboardingBackgroundTitle => 'Musik der spiller videre';

  @override
  String get onboardingBackgroundAndroid =>
      'Fermata spiller videre, når du skifter app eller låser telefonen. En notifikation viser afspilningsknapperne.';

  @override
  String get onboardingNotificationRationale =>
      'Android spørger, før apps må vise notifikationer. Fermata bruger dem til afspilningsknapperne og til færdige downloads — aldrig til reklamer.';

  @override
  String get onboardingAllowNotifications => 'Tillad notifikationer';

  @override
  String get onboardingNotificationsAllowed => 'Notifikationer er tilladt.';

  @override
  String get onboardingBatteryNote =>
      'Hvis musikken stopper i baggrunden på din telefon, så se Indstillinger → Baggrundsafspilning.';

  @override
  String get onboardingBackgroundTray =>
      'Når du lukker vinduet, stopper musikken ikke: Fermata bliver i systembakken. Afslut fra bakkemenuen, når du er færdig.';

  @override
  String get onboardingBackgroundNoTray =>
      'Når du lukker vinduet, stopper musikken ikke. Dit skrivebord har ingen systembakke, så Fermata minimeres i stedet.';

  @override
  String get onboardingMediaKeys =>
      'Medietaster og skrivebordets mediekontroller virker, mens Fermata er i baggrunden.';

  @override
  String get pagesPlay => 'Afspil';

  @override
  String get pagesShuffle => 'Bland';

  @override
  String pagesHoursMinutes(int hours, int minutes) {
    return '$hours t $minutes min';
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
      other: '$count numre',
      one: '1 nummer',
      zero: 'Ingen numre',
    );
    return '$_temp0';
  }

  @override
  String get pagesToday => 'I dag';

  @override
  String get pagesYesterday => 'I går';

  @override
  String get pagesDownloadEligible => 'Download';

  @override
  String get pagesOpenSettings => 'Åbn indstillinger';

  @override
  String get pagesImportAndMatch => 'Importér og match';

  @override
  String get pagesMore => 'Mere';

  @override
  String get pagesSort => 'Sortér';

  @override
  String get pagesFilter => 'Filtrér';

  @override
  String get pagesAscending => 'Stigende';

  @override
  String get pagesDescending => 'Faldende';

  @override
  String get pagesClearFilters => 'Ryd filtre';

  @override
  String get pagesNoMatches => 'Intet passer til filtrene.';

  @override
  String get pagesLoadMore => 'Indlæs flere';

  @override
  String get pagesRemove => 'Fjern';

  @override
  String pagesOpenOnProvider(String provider) {
    return 'Åbn på $provider';
  }

  @override
  String pagesDataFrom(String provider) {
    return 'Data fra $provider';
  }

  @override
  String get shelfContinueListening => 'Fortsæt med at lytte';

  @override
  String shelfDailyMix(int number) {
    return 'Dagens mix $number';
  }

  @override
  String get shelfDiscoverWeekly => 'Ugens opdagelser';

  @override
  String shelfBecauseYouLiked(String artist) {
    return 'Fordi du kan lide $artist';
  }

  @override
  String get shelfTrending => 'Populært lige nu';

  @override
  String get shelfNewReleases => 'Nye udgivelser';

  @override
  String get shelfRecentlyAdded => 'Senest tilføjet';

  @override
  String get moodFocus => 'Fokus';

  @override
  String get moodChill => 'Afslapning';

  @override
  String get moodWorkout => 'Træning';

  @override
  String get moodParty => 'Fest';

  @override
  String get moodSleep => 'Søvn';

  @override
  String get moodCommute => 'På farten';

  @override
  String get moodHappy => 'Godt humør';

  @override
  String get moodMelancholy => 'Melankoli';

  @override
  String get homeGoodMorning => 'Godmorgen';

  @override
  String get homeGoodAfternoon => 'God eftermiddag';

  @override
  String get homeGoodEvening => 'Godaften';

  @override
  String get homeGoodNight => 'God nat';

  @override
  String get homeSubtitle =>
      'Udvalgt ud fra det, du lytter til — beregnet på denne enhed.';

  @override
  String get homeMix => 'Mix';

  @override
  String get homeShelf => 'Samling';

  @override
  String get homeMadeForYou => 'Lavet til dig';

  @override
  String get homeFirstRunTitle => 'Lad os hente din musik ind';

  @override
  String get homeFirstRunMessage =>
      'Fermata afspiller dine egne filer og de tjenester, du forbinder. Start med en af disse.';

  @override
  String get homeAddFolderTitle => 'Tilføj en musikmappe';

  @override
  String get homeAddFolderBody =>
      'Dine filer bliver, hvor de er, og kan afspilles offline.';

  @override
  String get homeConnectTitle => 'Forbind en tjeneste';

  @override
  String get homeConnectBody => 'SoundCloud, Audius, Jamendo og flere.';

  @override
  String get homeConnectAction => 'Forbundne tjenester';

  @override
  String get homeExploreTitle => 'Udforsk';

  @override
  String get homeExploreBody =>
      'Gennemse stemninger, genrer og det, der er populært.';

  @override
  String get homeExploreAction => 'Begynd at udforske';

  @override
  String get searchHint => 'Sange, kunstnere, albums eller et delingslink';

  @override
  String get searchFilterAll => 'Alle';

  @override
  String get searchEmptyTitle => 'Søg i det hele på én gang';

  @override
  String get searchEmptyMessage =>
      'Dit bibliotek og alle forbundne tjenester. Indsæt et playlistelink for at åbne eller importere den.';

  @override
  String get searchBrowseExplore => 'Gå til Udforsk';

  @override
  String get searchHistoryOff =>
      'Søgehistorik er slået fra, så søgninger gemmes ikke.';

  @override
  String get searchRecent => 'Seneste søgninger';

  @override
  String get searchClearRecent => 'Ryd';

  @override
  String searchRemoveRecent(String query) {
    return 'Fjern \"$query\"';
  }

  @override
  String searchFor(String query) {
    return 'Søg efter \"$query\"';
  }

  @override
  String get searchInYourLibrary => 'I dit bibliotek';

  @override
  String get searchTopResult => 'Bedste resultat';

  @override
  String get searchTracks => 'Numre';

  @override
  String get searchArtists => 'Kunstnere';

  @override
  String get searchAlbums => 'Albums';

  @override
  String get searchPlaylists => 'Playlister';

  @override
  String searchShowAll(int count) {
    return 'Vis alle $count';
  }

  @override
  String searchNoResults(String query) {
    return 'Ingen resultater for \"$query\"';
  }

  @override
  String get searchNoResultsHint =>
      'Tjek stavningen, eller prøv med færre ord.';

  @override
  String get searchConnectedServices => 'Forbundne tjenester';

  @override
  String searchNotSearched(String sources) {
    return 'Ikke søgt i: $sources';
  }

  @override
  String searchSourceNotConnected(String service) {
    return '$service er ikke forbundet.';
  }

  @override
  String get searchNeedsCredentials => 'skal sættes op';

  @override
  String get searchNotConnected => 'ikke forbundet';

  @override
  String get searchKindTrack => 'Nummer';

  @override
  String get searchKindArtist => 'Kunstner';

  @override
  String get searchKindAlbum => 'Album';

  @override
  String get searchKindPlaylist => 'Playliste';

  @override
  String searchLinkTrack(String provider) {
    return 'Link til nummer på $provider';
  }

  @override
  String searchLinkPlaylist(String provider) {
    return 'Link til playliste på $provider';
  }

  @override
  String searchLinkAlbum(String provider) {
    return 'Link til album på $provider';
  }

  @override
  String searchLinkArtist(String provider) {
    return 'Link til kunstner på $provider';
  }

  @override
  String searchLinkGeneric(String provider) {
    return 'Link til $provider';
  }

  @override
  String get searchOpenPlaylist => 'Åbn playliste';

  @override
  String get searchOpenAlbum => 'Åbn album';

  @override
  String get searchOpenArtist => 'Åbn kunstner';

  @override
  String searchSourceMissing(String provider) {
    return '$provider er ikke tilgængelig i denne version af Fermata.';
  }

  @override
  String get searchLinkNotFound =>
      'Nummeret blev ikke fundet. Det er måske slettet eller gjort privat.';

  @override
  String get exploreSubtitle =>
      'Stemninger, genrer og ny musik fra dine tjenester.';

  @override
  String get exploreMoods => 'Stemninger';

  @override
  String get exploreGenres => 'Genrer';

  @override
  String get exploreNoGenres =>
      'Ingen genrer endnu. Tilføj musik eller forbind en tjeneste.';

  @override
  String get exploreGenre => 'Genre';

  @override
  String get exploreMood => 'Stemning';

  @override
  String get exploreNothingFound =>
      'Intet at afspille lige nu. Prøv igen senere, eller forbind en anden tjeneste.';

  @override
  String get libraryTabTracks => 'Numre';

  @override
  String get libraryTabAlbums => 'Albums';

  @override
  String get libraryTabArtists => 'Kunstnere';

  @override
  String get libraryTabFolders => 'Mapper';

  @override
  String get libraryPermissionNeeded =>
      'Fermata skal have adgang til din musik for at tilføje en mappe.';

  @override
  String get libraryOpenSystemSettings => 'Åbn indstillinger';

  @override
  String get libraryAddFolder => 'Tilføj mappe';

  @override
  String libraryFolderAdded(String folder) {
    return '$folder er tilføjet — scanner nu';
  }

  @override
  String get libraryLocalFiles => 'Lokale filer';

  @override
  String get libraryEmptyTitle => 'Dit bibliotek er tomt';

  @override
  String get libraryEmptyMessage =>
      'Tilføj en musikmappe, eller importér en fil. Numre, du synes om eller afspiller fra tjenester, vises også her.';

  @override
  String get libraryImportFile => 'Importér en fil';

  @override
  String get libraryImportFileFailed =>
      'Filen kan ikke tilføjes. Fermata læser MP3, FLAC, M4A, Ogg, Opus, WAV og AIFF.';

  @override
  String libraryImportFileDone(String title) {
    return '\"$title\" er tilføjet';
  }

  @override
  String get libraryFilterHint => 'Filtrér dit bibliotek';

  @override
  String get libraryQuickDownloaded => 'Downloadet';

  @override
  String librarySortedBy(String field) {
    return 'Sorteret efter $field';
  }

  @override
  String get librarySortTitle => 'Titel';

  @override
  String get librarySortArtist => 'Kunstner';

  @override
  String get librarySortAlbum => 'Album';

  @override
  String get librarySortYear => 'År';

  @override
  String get librarySortDuration => 'Varighed';

  @override
  String get librarySortDateAdded => 'Tilføjet';

  @override
  String get librarySortPlayCount => 'Mest afspillet';

  @override
  String get librarySortLastPlayed => 'Sidst afspillet';

  @override
  String get librarySortGenre => 'Genre';

  @override
  String get libraryFilterAvailability => 'Tilgængelighed';

  @override
  String get libraryFilterDownloaded => 'Downloadet';

  @override
  String get libraryFilterLocal => 'Kun lokale filer';

  @override
  String get libraryFilterOffline => 'Tilgængelig offline';

  @override
  String get libraryFilterFavorites => 'Synes godt om';

  @override
  String get libraryFilterSource => 'Kilde';

  @override
  String get libraryFilterGenre => 'Genre';

  @override
  String get libraryAnyGenre => 'Alle genrer';

  @override
  String get libraryFilterYear => 'År';

  @override
  String get libraryFrom => 'Fra';

  @override
  String get libraryTo => 'Til';

  @override
  String get libraryFilterDuration => 'Varighed (minutter)';

  @override
  String get libraryMinMinutes => 'Mindst';

  @override
  String get libraryMaxMinutes => 'Højst';

  @override
  String get libraryFilterAlbums => 'Filtrér albums';

  @override
  String get libraryNoAlbums => 'Ingen albums endnu';

  @override
  String get libraryFilterArtists => 'Filtrér kunstnere';

  @override
  String get libraryNoArtists => 'Ingen kunstnere endnu';

  @override
  String get libraryFolders => 'Musikmapper';

  @override
  String get libraryFoldersHintDesktop =>
      'Overvågede mapper scannes automatisk igen, når filer ændres.';

  @override
  String get libraryFoldersHintAndroid =>
      'Mapperne scannes igen, hver gang Fermata starter.';

  @override
  String get libraryNoFolders => 'Ingen musikmapper endnu';

  @override
  String get libraryNoFoldersMessage =>
      'Tilføj de mapper, hvor du har din musik. Filer bliver aldrig flyttet eller uploadet.';

  @override
  String get libraryRescanAll => 'Scan igen';

  @override
  String get libraryFullRescan => 'Fuld scanning';

  @override
  String get libraryRescanFolder => 'Scan mappen igen';

  @override
  String get libraryRemoveFolder => 'Fjern mappe';

  @override
  String get libraryRemoveFolderTitle => 'Fjern mappen?';

  @override
  String libraryRemoveFolderMessage(String path) {
    return 'Numre fra $path fjernes fra dit bibliotek. Selve filerne slettes ikke.';
  }

  @override
  String get libraryWatchFolder => 'Hold øje med ændringer';

  @override
  String get libraryNeverScanned => 'Ikke scannet endnu';

  @override
  String libraryScannedOn(String date) {
    return 'Scannet $date';
  }

  @override
  String get libraryScanEnumerating => 'Leder efter musik …';

  @override
  String libraryScanProgress(int scanned, int total) {
    return 'Scanner $scanned af $total filer';
  }

  @override
  String get libraryScanDone => 'Scanningen er færdig';

  @override
  String get libraryScanFailed => 'Scanningen stoppede';

  @override
  String libraryScanCounts(int added, int updated, int removed) {
    return '$added tilføjet · $updated opdateret · $removed fjernet';
  }

  @override
  String libraryScanErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filer kunne ikke læses',
      one: '1 fil kunne ikke læses',
    );
    return '$_temp0';
  }

  @override
  String get libraryTools => 'Værktøjer';

  @override
  String get libraryMissingFiles => 'Manglende filer';

  @override
  String get libraryMissingFilesHint =>
      'Numre, hvis fil er flyttet eller slettet uden for Fermata. De kommer tilbage, hvis filen dukker op igen.';

  @override
  String get libraryNoMissingFiles => 'Ingen manglende filer';

  @override
  String get libraryRemoveAllMissing => 'Fjern alle fra biblioteket';

  @override
  String get libraryDuplicates => 'Dubletter';

  @override
  String get libraryDuplicatesHint => 'Numre, der ligner kopier af hinanden.';

  @override
  String get libraryNoDuplicates => 'Ingen dubletter fundet';

  @override
  String get libraryDuplicateSameFile => 'Identiske filer';

  @override
  String get libraryDuplicateSameIsrc => 'Samme indspilning (ISRC)';

  @override
  String get libraryDuplicateSameMetadata => 'Samme titel, kunstner og længde';

  @override
  String get libraryRemoveFromLibrary => 'Fjern fra biblioteket';

  @override
  String libraryRemoveFromLibraryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fjern $count numre fra dit bibliotek?',
      one: 'Fjern 1 nummer fra dit bibliotek?',
    );
    return '$_temp0';
  }

  @override
  String get libraryRemoveFromLibraryMessage => 'Filer på disken slettes ikke.';

  @override
  String libraryRemovedFromLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre fjernet',
      one: '1 nummer fjernet',
    );
    return '$_temp0';
  }

  @override
  String get libraryTrackDetails => 'Detaljer';

  @override
  String get libraryDetailDuration => 'Længde';

  @override
  String get libraryDetailFormat => 'Format';

  @override
  String get libraryDetailBitrate => 'Bitrate';

  @override
  String libraryKbps(int kbps) {
    return '$kbps kbps';
  }

  @override
  String get libraryDetailSampleRate => 'Samplingsfrekvens';

  @override
  String libraryKhz(String khz) {
    return '$khz kHz';
  }

  @override
  String get libraryDetailBitDepth => 'Bitdybde';

  @override
  String libraryBits(int bits) {
    return '$bits bit';
  }

  @override
  String get libraryDetailChannels => 'Kanaler';

  @override
  String get libraryDetailSize => 'Filstørrelse';

  @override
  String get libraryDetailReplayGain => 'ReplayGain';

  @override
  String get libraryDetailSource => 'Kilde';

  @override
  String get libraryDetailOffline => 'Offline';

  @override
  String get libraryDetailFile => 'Fil';

  @override
  String get libraryEditTags => 'Redigér tags';

  @override
  String get libraryTagTitle => 'Titel';

  @override
  String get libraryTagArtists => 'Kunstnere';

  @override
  String get libraryTagArtistsHint => 'Adskil flere kunstnere med ;';

  @override
  String get libraryTagAlbum => 'Album';

  @override
  String get libraryTagAlbumArtist => 'Albumkunstner';

  @override
  String get libraryTagYear => 'År';

  @override
  String get libraryTagGenre => 'Genre';

  @override
  String get libraryTagTrackNumber => 'Nummer';

  @override
  String get libraryTagDiscNumber => 'Disk';

  @override
  String get libraryTagsFileHint =>
      'Ændringer skrives til filen, når formatet tillader det; ellers gemmes de kun i dit bibliotek.';

  @override
  String get libraryTagsOverrideOnly =>
      'På denne enhed ændres filen ikke: dine rettelser gemmes i Fermatas bibliotek.';

  @override
  String get libraryTagsSavedToFile => 'Tags er gemt i filen';

  @override
  String get libraryTagsSavedAsOverride =>
      'Gemt i dit bibliotek (filen blev ikke ændret)';

  @override
  String get playlistsNewSmart => 'Smart playliste';

  @override
  String get playlistsImport => 'Importér';

  @override
  String get playlistsImportFromService => 'Importér fra en tjeneste';

  @override
  String get playlistsImportM3u => 'Importér M3U-fil';

  @override
  String get playlistsImportM3uEmpty =>
      'Der blev ikke fundet nogen afspillelige filer i playlistefilen.';

  @override
  String playlistsImportedM3u(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre importeret til $name',
      one: '1 nummer importeret til $name',
    );
    return '$_temp0';
  }

  @override
  String playlistsCreated(String name) {
    return '$name er oprettet';
  }

  @override
  String get playlistsEmptyMessage =>
      'Lav en fra bunden, lad en smart playliste fylde sig selv, eller hent en fra en anden tjeneste.';

  @override
  String get playlistsFilterYours => 'Dine';

  @override
  String get playlistsFilterSmart => 'Smarte';

  @override
  String get playlistsFilterImported => 'Importerede';

  @override
  String get playlistsShowList => 'Vis som liste';

  @override
  String get playlistsShowGrid => 'Vis som gitter';

  @override
  String get playlistKindLocal => 'Playliste';

  @override
  String get playlistKindSmart => 'Smart playliste';

  @override
  String playlistKindImported(String provider) {
    return 'Importeret fra $provider';
  }

  @override
  String playlistOnProvider(String provider) {
    return 'Playliste på $provider';
  }

  @override
  String playlistBy(String owner) {
    return 'af $owner';
  }

  @override
  String get playlistDescription => 'Beskrivelse (valgfri)';

  @override
  String get playlistEditDetails => 'Redigér detaljer';

  @override
  String get playlistEditRules => 'Redigér regler';

  @override
  String get playlistChangeArtwork => 'Skift billede';

  @override
  String get playlistArtworkUpdated => 'Billedet er opdateret';

  @override
  String get playlistExportM3u => 'Eksportér som M3U';

  @override
  String playlistExported(String location) {
    return 'Gemt i $location';
  }

  @override
  String get playlistAutoDownload => 'Download automatisk';

  @override
  String get playlistAutoDownloadOn => 'Automatisk download er slået til';

  @override
  String get playlistAutoDownloadTitle => 'Download playlisten automatisk?';

  @override
  String get playlistAutoDownloadExplain =>
      'Fermata downloader kun numre automatisk, når det er dine egne filer, eller når udbyderen tillader automatisk download. Ingen af streamingtjenesterne tillader det i dag, så deres numre forbliver online — du kan stadig selv downloade enkelte numre fra Audius eller Jamendo, hvor kunstneren tillader det.';

  @override
  String get playlistAutoDownloadConfirm => 'Slå til';

  @override
  String get playlistDedupe => 'Fjern dubletter';

  @override
  String get playlistNoDuplicates => 'Ingen dubletter fundet';

  @override
  String playlistDuplicatesRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dubletter fjernet',
      one: '1 dublet fjernet',
    );
    return '$_temp0';
  }

  @override
  String playlistDeleteTitle(String name) {
    return 'Slet \"$name\"?';
  }

  @override
  String get playlistDeleteMessage =>
      'Playlisten fjernes. Dens numre bliver i dit bibliotek.';

  @override
  String playlistDeleted(String name) {
    return '$name er slettet';
  }

  @override
  String get playlistNotFound => 'Playlisten findes ikke længere.';

  @override
  String get playlistEmpty => 'Playlisten er tom';

  @override
  String get playlistEmptyHint =>
      'Tilføj numre fra søgning, dit bibliotek eller en hvilken som helst nummermenu.';

  @override
  String get playlistSmartEmpty => 'Intet passer til reglerne endnu';

  @override
  String get playlistSmartEmptyHint =>
      'Redigér reglerne, eller afspil og synes om mere musik.';

  @override
  String playlistRulesSummary(int count, String match) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count regler',
      one: '1 regel',
    );
    return '$_temp0, $match';
  }

  @override
  String get playlistReorder => 'Omarranger';

  @override
  String get playlistRemoveFromPlaylist => 'Fjern fra playlisten';

  @override
  String playlistRemovedTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre fjernet',
      one: '1 nummer fjernet',
    );
    return '$_temp0';
  }

  @override
  String playlistPlaysVia(String provider) {
    return 'Afspilles via $provider — skift';
  }

  @override
  String get playlistSaveToLibrary => 'Gem i biblioteket';

  @override
  String playlistSavedToLibrary(String name) {
    return '$name er gemt i dit bibliotek';
  }

  @override
  String get smartNewTitle => 'Ny smart playliste';

  @override
  String get smartEditTitle => 'Redigér smart playliste';

  @override
  String get smartMatch => 'Medtag numre, der opfylder';

  @override
  String get smartMatchAll => 'alle regler';

  @override
  String get smartMatchAny => 'mindst én regel';

  @override
  String get smartAddRule => 'Tilføj regel';

  @override
  String get smartRemoveRule => 'Fjern regel';

  @override
  String get smartValue => 'Værdi';

  @override
  String get smartPickSource => 'Vælg en kilde';

  @override
  String get smartUnitMinutes => 'min';

  @override
  String get smartUnitDays => 'dage';

  @override
  String get smartLimit => 'Højst';

  @override
  String get smartNoLimit => 'Ingen grænse';

  @override
  String get smartPreviewLoading => 'Tæller numre, der passer …';

  @override
  String smartPreviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre passer',
      one: '1 nummer passer',
      zero: 'Ingen numre passer',
    );
    return '$_temp0';
  }

  @override
  String smartPreviewApprox(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cirka $count numre passer',
      one: 'Cirka 1 nummer passer',
    );
    return '$_temp0';
  }

  @override
  String get smartFieldTitle => 'Titel';

  @override
  String get smartFieldArtist => 'Kunstner';

  @override
  String get smartFieldAlbum => 'Album';

  @override
  String get smartFieldGenre => 'Genre';

  @override
  String get smartFieldYear => 'År';

  @override
  String get smartFieldDuration => 'Længde';

  @override
  String get smartFieldPlayCount => 'Antal afspilninger';

  @override
  String get smartFieldLastPlayed => 'Sidst afspillet';

  @override
  String get smartFieldDateAdded => 'Tilføjet';

  @override
  String get smartFieldSource => 'Kilde';

  @override
  String get smartFieldFavorite => 'Synes godt om';

  @override
  String get smartFieldDownloaded => 'Downloadet';

  @override
  String get smartOpContains => 'indeholder';

  @override
  String get smartOpNotContains => 'indeholder ikke';

  @override
  String get smartOpEquals => 'er';

  @override
  String get smartOpNotEquals => 'er ikke';

  @override
  String get smartOpStartsWith => 'starter med';

  @override
  String get smartOpGreaterThan => 'er mere end';

  @override
  String get smartOpLessThan => 'er mindre end';

  @override
  String get smartOpInLastDays => 'inden for de seneste';

  @override
  String get smartOpNotInLastDays => 'ikke inden for de seneste';

  @override
  String get smartOpIsTrue => 'ja';

  @override
  String get smartOpIsFalse => 'nej';

  @override
  String get alternativesFind => 'Find alternativer';

  @override
  String get alternativesTitle => 'Alternativer';

  @override
  String get alternativesLinkedNow => 'Forbundet nu';

  @override
  String get alternativesSuggested => 'Foreslåede match';

  @override
  String get alternativesSearch => 'Søg selv';

  @override
  String get alternativesSearchHint => 'Titel og kunstner, tryk derefter Enter';

  @override
  String get alternativesNone => 'Ingen match fundet.';

  @override
  String get alternativesUse => 'Brug';

  @override
  String get alternativesInUse => 'I brug';

  @override
  String get alternativesUnlink => 'Fjern forbindelse';

  @override
  String alternativesLinked(String provider) {
    return 'Forbundet — afspilles fra $provider';
  }

  @override
  String alternativesScore(int percent, String confidence) {
    return '$percent % · $confidence';
  }

  @override
  String get matchExact => 'præcist match';

  @override
  String get matchHigh => 'meget sandsynligt';

  @override
  String get matchMedium => 'muligt';

  @override
  String get matchLow => 'usandsynligt';

  @override
  String get matchNone => 'intet match';

  @override
  String get diffRemix => 'remix';

  @override
  String get diffLive => 'live';

  @override
  String get diffAcoustic => 'akustisk';

  @override
  String get diffExtended => 'forlænget';

  @override
  String get diffRadioEdit => 'radioversion';

  @override
  String get diffInstrumental => 'instrumental';

  @override
  String get diffKaraoke => 'karaoke';

  @override
  String get diffCover => 'coverversion';

  @override
  String get diffRemaster => 'remaster';

  @override
  String get diffSped => 'speedet op';

  @override
  String get diffSlowed => 'sænket tempo';

  @override
  String get diffDemo => 'demo';

  @override
  String get diffExplicit => 'eksplicit afviger';

  @override
  String get diffDuration => 'længden afviger';

  @override
  String get diffAlbum => 'andet album';

  @override
  String get diffYear => 'andet år';

  @override
  String get diffArtist => 'anden kunstner';

  @override
  String get diffFeatured => 'gæstekunstnere afviger';

  @override
  String get diffTitle => 'titlen afviger';

  @override
  String get diffPreview => 'kun forsmag';

  @override
  String get artistInLibrary => 'Kunstner i dit bibliotek';

  @override
  String artistOnProvider(String provider) {
    return 'Kunstner på $provider';
  }

  @override
  String artistFollowers(String count) {
    return '$count følgere';
  }

  @override
  String get artistTopTracks => 'Populære numre';

  @override
  String get artistTracks => 'Numre';

  @override
  String get artistNoTracks => 'Ingen numre fundet.';

  @override
  String get artistAlbums => 'Albums';

  @override
  String get artistReleases => 'Udgivelser';

  @override
  String get artistRelated => 'Fans lytter også til';

  @override
  String get albumInLibrary => 'Album i dit bibliotek';

  @override
  String albumOnProvider(String provider) {
    return 'Album på $provider';
  }

  @override
  String albumDisc(int number) {
    return 'Disk $number';
  }

  @override
  String get albumEmpty => 'Ingen numre på dette album.';

  @override
  String get downloadsPauseAll => 'Sæt alle på pause';

  @override
  String get downloadsResumeAll => 'Genoptag alle';

  @override
  String get downloadsRetryFailed => 'Prøv mislykkede igen';

  @override
  String get downloadsCancelAll => 'Annullér alle';

  @override
  String get downloadsCancelAllTitle => 'Annullér alle downloads?';

  @override
  String get downloadsCancelAllMessage =>
      'Igangværende downloads stopper, og delvist downloadede filer fjernes.';

  @override
  String get downloadsCancelAllConfirm => 'Annullér downloads';

  @override
  String get downloadsKeepDownloading => 'Fortsæt';

  @override
  String get downloadsPause => 'Pause';

  @override
  String get downloadsResume => 'Genoptag';

  @override
  String get downloadsProgress => 'Downloadstatus';

  @override
  String get downloadsFilterActive => 'Aktive';

  @override
  String get downloadsFilterCompleted => 'Færdige';

  @override
  String get downloadsFilterFailed => 'Mislykkede';

  @override
  String get downloadsActive => 'Downloader';

  @override
  String downloadsActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count i køen',
      one: '1 i køen',
    );
    return '$_temp0';
  }

  @override
  String get downloadsFinished => 'Afsluttede';

  @override
  String get downloadsNothingHere => 'Ingenting her lige nu.';

  @override
  String get downloadsEmptyTitle => 'Ingen downloads endnu';

  @override
  String get downloadsEmptyMessage =>
      'Numre kan kun downloades, hvor udbyderen tillader det — numre fra Audius og Jamendo, som kunstneren har gjort tilgængelige. Dine egne filer kan allerede afspilles offline.';

  @override
  String get downloadsStatusQueued => 'I kø';

  @override
  String get downloadsStatusWaiting => 'Venter';

  @override
  String get downloadsStatusDownloading => 'Downloader';

  @override
  String get downloadsStatusVerifying => 'Kontrollerer';

  @override
  String get downloadsStatusPaused => 'På pause';

  @override
  String get downloadsStatusCompleted => 'Downloadet';

  @override
  String get downloadsStatusFailed => 'Mislykkedes';

  @override
  String get downloadsStatusCanceled => 'Annulleret';

  @override
  String downloadsSizeOf(String received, String total) {
    return '$received af $total';
  }

  @override
  String downloadsSpeed(String speed) {
    return '$speed/s';
  }

  @override
  String downloadsEta(String time) {
    return '$time tilbage';
  }

  @override
  String downloadsAttempts(int count) {
    return '$count forsøg';
  }

  @override
  String get downloadsWaitingWifiTitle => 'Venter på wi-fi';

  @override
  String get downloadsWaitingWifi =>
      'Downloads kører kun på wi-fi. De fortsætter af sig selv, når du får forbindelse.';

  @override
  String get downloadsDownloadSettings => 'Downloadindstillinger';

  @override
  String get downloadsWaitingConnection => 'Venter på internetforbindelse.';

  @override
  String get downloadsWaitingMobileData =>
      'Du bruger mobildata. Downloads venter, til du tillader det eller får wi-fi.';

  @override
  String get downloadsMobileDataTitle => 'Download via mobildata?';

  @override
  String get downloadsMobileDataMessage =>
      'Det kan bruge meget data. Du bliver spurgt igen, næste gang du starter Fermata.';

  @override
  String get downloadsMobileDataConfirm => 'Brug mobildata';

  @override
  String get downloadsMobileDataWait => 'Vent på wi-fi';

  @override
  String get downloadsMobileDataAllowed => 'Downloader via mobildata';

  @override
  String get downloadsStorage => 'Lagerplads';

  @override
  String get downloadsStorageSettings => 'Lagerindstillinger';

  @override
  String downloadsStorageDownloads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Downloads ($count numre)',
      one: 'Downloads (1 nummer)',
    );
    return '$_temp0';
  }

  @override
  String get downloadsStorageArtwork => 'Billedcache';

  @override
  String get downloadsStorageStreamCache => 'Streamingcache';

  @override
  String get downloadsStorageDatabase => 'Biblioteksdatabase';

  @override
  String get downloadsStorageLimit => 'Downloadgrænse';

  @override
  String get downloadsStorageFree => 'Ledigt på enheden';

  @override
  String get downloadsUnlimited => 'Ingen grænse';

  @override
  String get downloadsErrorSourceUnavailable =>
      'Tjenesten er ikke tilgængelig lige nu.';

  @override
  String get downloadsErrorAuth => 'Forbind tjenesten igen for at downloade.';

  @override
  String get downloadsErrorNotFound =>
      'Filen findes ikke længere hos tjenesten.';

  @override
  String get downloadsErrorForbidden => 'Tjenesten afviste downloaden.';

  @override
  String get downloadsErrorServer =>
      'Tjenesten havde et problem. Prøv igen senere.';

  @override
  String get downloadsErrorNotAudio => 'Tjenesten sendte ikke en lydfil.';

  @override
  String get downloadsErrorCorrupt => 'Filen kom beskadiget frem. Prøv igen.';

  @override
  String get downloadsErrorDiskFull => 'Der er ikke nok ledig plads.';

  @override
  String get favoritesEmptyTitle => 'Sange, du synes om, vises her';

  @override
  String get favoritesEmptyMessage =>
      'Tryk på hjertet ved et nummer for at gemme det her.';

  @override
  String get favoritesFilterHint => 'Filtrér sange, du synes om';

  @override
  String get favoritesSortRecent => 'Senest tilføjet';

  @override
  String get historyRecent => 'Senest afspillet';

  @override
  String get historyStats => 'Statistik';

  @override
  String get historyClear => 'Ryd historik';

  @override
  String get historyClearTitle => 'Ryd din lyttehistorik?';

  @override
  String get historyClearMessage =>
      'Senest afspillet og statistik slettes fra denne enhed. Anbefalingerne starter forfra.';

  @override
  String get historyCleared => 'Historikken er ryddet';

  @override
  String get historyRecordingOff =>
      'Lyttehistorik er slået fra, så nye afspilninger gemmes ikke.';

  @override
  String get historyEmptyTitle => 'Intet afspillet endnu';

  @override
  String get historyEmptyMessage =>
      'Det, du lytter til, vises her, sorteret efter dag.';

  @override
  String get historyStatsEmpty => 'Afspil noget musik for at se din statistik.';

  @override
  String historyStatsPeriod(int days) {
    return 'De seneste $days dage, beregnet på denne enhed';
  }

  @override
  String get historyStatsPlays => 'Afspilninger';

  @override
  String get historyStatsTime => 'Lyttetid';

  @override
  String get historyStatsPerDay => 'Afspilninger pr. dag';

  @override
  String get historyStatsTopTracks => 'Mest spillede numre';

  @override
  String get historyStatsTopArtists => 'Mest spillede kunstnere';

  @override
  String get historyStatsTopGenres => 'Mest spillede genrer';

  @override
  String historyPlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count afspilninger',
      one: '1 afspilning',
    );
    return '$_temp0';
  }

  @override
  String historyChartLabel(int days, int total, int peak) {
    return 'Afspilninger pr. dag de seneste $days dage: $total i alt, højst $peak på én dag';
  }

  @override
  String get playerPlay => 'Afspil';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerNext => 'Næste';

  @override
  String get playerPrevious => 'Forrige';

  @override
  String get playerShuffleOn => 'Bland er slået til';

  @override
  String get playerShuffleOff => 'Bland er slået fra';

  @override
  String get playerRepeatOff => 'Gentag er slået fra';

  @override
  String get playerRepeatAll => 'Gentager alle';

  @override
  String get playerRepeatOne => 'Gentager ét nummer';

  @override
  String get playerLike => 'Synes godt om';

  @override
  String get playerUnlike => 'Fjern fra Synes godt om';

  @override
  String get playerLyrics => 'Sangtekst';

  @override
  String get playerQueue => 'Kø';

  @override
  String get playerArtwork => 'Cover';

  @override
  String get playerOutputDevice => 'Lydudgang';

  @override
  String get playerSystemDefault => 'Systemets standard';

  @override
  String get playerNoDevices => 'Der blev ikke fundet andre lydudgange';

  @override
  String get playerVolume => 'Lydstyrke';

  @override
  String get playerMute => 'Slå lyden fra';

  @override
  String get playerUnmute => 'Slå lyden til';

  @override
  String get playerSpeed => 'Afspilningshastighed';

  @override
  String playerSpeedValue(String speed) {
    return '$speed×';
  }

  @override
  String get playerSleepTimer => 'Sovetimer';

  @override
  String get playerSleepOff => 'Fra';

  @override
  String playerSleepMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutter',
      one: '1 minut',
    );
    return '$_temp0';
  }

  @override
  String get playerSleepEndOfTrack => 'Når nummeret slutter';

  @override
  String playerSleepRemaining(String time) {
    return 'Sætter på pause om $time';
  }

  @override
  String get playerSleepAtEndOfTrack => 'Sætter på pause efter dette nummer';

  @override
  String get playerMiniPlayer => 'Miniafspiller';

  @override
  String get playerExitMiniPlayer => 'Tilbage til fuldt vindue';

  @override
  String get playerAlwaysOnTop => 'Hold øverst';

  @override
  String get playerNothingPlaying => 'Der afspilles ikke noget';

  @override
  String get playerNothingPlayingHint =>
      'Vælg et album, en playliste eller et nummer for at komme i gang.';

  @override
  String get playerSeek => 'Afspilningsposition';

  @override
  String playerElapsed(String time) {
    return '$time afspillet';
  }

  @override
  String playerRemaining(String time) {
    return '$time tilbage';
  }

  @override
  String get playerOpenNowPlaying => 'Åbn Afspiller nu';

  @override
  String get playerCloseNowPlaying => 'Luk Afspiller nu';

  @override
  String playerPlayingFrom(String origin) {
    return 'Afspiller fra $origin';
  }

  @override
  String get playerAddToPlaylist => 'Føj til playliste';

  @override
  String get playerDownload => 'Download';

  @override
  String get playerDownloaded => 'Downloadet';

  @override
  String playerOpenOn(String provider) {
    return 'Åbn på $provider';
  }

  @override
  String playerUploaderOn(String provider) {
    return 'Uploader på $provider';
  }

  @override
  String get playerCopyLink => 'Kopiér link';

  @override
  String get playerMore => 'Mere';

  @override
  String get playerChipPreview => 'Smagsprøve';

  @override
  String get playerChipYourFile => 'Din fil';

  @override
  String get playerChipDownloaded => 'Downloadet';

  @override
  String playerPreviewFrom(int seconds, String provider) {
    return '$seconds sekunders smagsprøve · $provider';
  }

  @override
  String get playerUnplayable => 'Nummeret kan ikke afspilles';

  @override
  String get playerSkippedUnplayable =>
      'Sprang et nummer over, som ikke kan afspilles';

  @override
  String get playerShowArtwork => 'Vis cover';

  @override
  String get playerShowLyrics => 'Vis sangtekst';

  @override
  String get playerShowQueue => 'Vis kø';

  @override
  String playerLyricsAttribution(String provider) {
    return 'Sangtekst: $provider';
  }

  @override
  String get playerLyricsNotFound =>
      'Der blev ikke fundet en sangtekst til nummeret.';

  @override
  String get playerLyricsInstrumental => 'Instrumental';

  @override
  String get playerLyricsDisabled =>
      'Sangtekster er slået fra i Indstillinger.';

  @override
  String get playerLyricsError => 'Sangteksten kunne ikke hentes.';

  @override
  String get playerLyricsSeekTo => 'Hop til denne linje';

  @override
  String get playerQueueNowPlaying => 'Afspiller nu';

  @override
  String get playerQueueUpNext => 'Næste i køen';

  @override
  String get playerQueueHistory => 'Spillet tidligere';

  @override
  String get playerQueueEmpty => 'Din kø er tom';

  @override
  String get playerQueueEmptyHint =>
      'Afspil et album, en playliste eller et nummer, så dukker det op her.';

  @override
  String get playerQueueClear => 'Ryd køen';

  @override
  String get playerQueueClearTitle => 'Vil du rydde køen?';

  @override
  String get playerQueueClearMessage =>
      'Alle kommende numre fjernes. Det aktuelle nummer spiller videre.';

  @override
  String get playerQueueRemove => 'Fjern fra køen';

  @override
  String get playerQueuePlayNext => 'Afspil som det næste';

  @override
  String get playerQueueSuggested => 'Forslag';

  @override
  String get playerQueueRemoved => 'Fjernet fra køen';

  @override
  String get playerQueueReorder => 'Træk for at flytte';

  @override
  String playerQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre',
      one: '1 nummer',
      zero: 'Ingen numre',
    );
    return '$_temp0';
  }

  @override
  String get playerOriginSearch => 'Søgning';

  @override
  String get playerOriginSmartQueue => 'Forslag';

  @override
  String get playerOriginLibrary => 'Dit bibliotek';

  @override
  String get playerOriginFavorites => 'Synes godt om';

  @override
  String get playerSiloTitle => 'Vil du starte en ny kø?';

  @override
  String get playerSiloMessage =>
      'SoundCloud-numre afspilles i deres egen kø (SoundClouds vilkår). Vil du starte en ny kø?';

  @override
  String get playerSiloConfirm => 'Start ny kø';

  @override
  String get settingsTitle => 'Indstillinger';

  @override
  String get settingsSearchHint => 'Søg i indstillinger';

  @override
  String settingsSearchNoResults(String query) {
    return 'Ingen indstillinger matcher “$query”.';
  }

  @override
  String get settingsRestoreAll => 'Gendan alle standarder';

  @override
  String get settingsRestoreAllTitle => 'Gendan alle indstillinger?';

  @override
  String get settingsRestoreAllBody =>
      'Alle indstillinger sættes tilbage til standard. Dit bibliotek, dine playlister, forbundne konti og din downloadmappe bevares.';

  @override
  String get settingsRestoreSection => 'Gendan standarder for denne sektion';

  @override
  String settingsRestoreSectionTitle(String section) {
    return 'Gendan standarder for “$section”?';
  }

  @override
  String get settingsRestoreSectionBody =>
      'Indstillingerne i denne sektion sættes tilbage til standard.';

  @override
  String get settingsRestoredToast => 'Standarder gendannet';

  @override
  String get settingsBack => 'Tilbage til indstillinger';

  @override
  String get settingsSectionUnavailable =>
      'Denne sektion er ikke tilgængelig på denne enhed.';

  @override
  String get settingsOn => 'Til';

  @override
  String get settingsOff => 'Fra';

  @override
  String get settingsValueFull => 'Fuld';

  @override
  String get settingsValueReduced => 'Reduceret';

  @override
  String get settingsValueLow => 'Lav';

  @override
  String get settingsValueMedium => 'Mellem';

  @override
  String get settingsValueHigh => 'Høj';

  @override
  String get settingsValueNormal => 'Normal';

  @override
  String get settingsValueLossless => 'Tabsfri';

  @override
  String get settingsSaved => 'Gemt';

  @override
  String get settingsNotAvailable => 'Ikke tilgængelig';

  @override
  String get settingsOpenLinkFailed => 'Linket kunne ikke åbnes.';

  @override
  String settingsSavedTo(String location) {
    return 'Gemt i $location';
  }

  @override
  String get settingsThemeMode => 'Tema';

  @override
  String get settingsThemeDark => 'Mørkt';

  @override
  String get settingsThemeLight => 'Lyst';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsAccent => 'Accentfarve';

  @override
  String get settingsAccentGold => 'Guld';

  @override
  String get settingsAccentCoral => 'Koral';

  @override
  String get settingsAccentMint => 'Mint';

  @override
  String get settingsAccentIce => 'Is';

  @override
  String get settingsAccentMono => 'Monokrom';

  @override
  String get settingsDensity => 'Tæthed';

  @override
  String get settingsDensityComfortable => 'Komfortabel';

  @override
  String get settingsDensityCompact => 'Kompakt';

  @override
  String get settingsArtworkBackdrop => 'Coverbaggrund';

  @override
  String get settingsArtworkBackdropHint =>
      'Viser en blød, farvet udgave af coveret bag Afspiller nu.';

  @override
  String get settingsHighContrast => 'Høj kontrast';

  @override
  String get settingsHighContrastHint =>
      'Tydeligere tekst, kanter og accentfarver.';

  @override
  String get settingsGlassIntro =>
      'Et valgfrit glas-inspireret udseende: sidepanel, afspiller og ark bliver gennemsigtige og lader dine covers skinne igennem. Teksten forbliver altid læsbar.';

  @override
  String get settingsGlassToggle => 'Liquid Glass';

  @override
  String get settingsGlassToggleHint =>
      'Slået fra som standard. Gennemsigtige flader med en blød sløring.';

  @override
  String get settingsGlassIntensity => 'Intensitet';

  @override
  String get settingsGlassIntensityHint =>
      'Hvor meget af baggrunden der skinner igennem.';

  @override
  String get settingsGlassIntensityDisabled =>
      'Slå Liquid Glass til for at justere intensiteten.';

  @override
  String get settingsGlassBlurOff =>
      'Sløring er slået fra af den aktuelle ydelsestilstand, så glasset bruger en lettere gennemsigtig stil.';

  @override
  String get settingsGlassReadability =>
      'Fermata øger automatisk glasfladernes dækkevne, når det er nødvendigt for at holde teksten læsbar.';

  @override
  String settingsSecondsShort(int seconds) {
    return '$seconds s';
  }

  @override
  String get settingsTransitionsGroup => 'Overgange';

  @override
  String get settingsCrossfade => 'Crossfade';

  @override
  String get settingsCrossfadeHint =>
      'Glid fra slutningen af et nummer over i det næste.';

  @override
  String get settingsGapless => 'Afspilning uden pauser';

  @override
  String get settingsGaplessHint =>
      'Ingen stilhed mellem numre, der hører sammen, som på livealbums.';

  @override
  String get settingsGaplessCrossfadeNote =>
      'Bruges ikke, mens crossfade er slået til — crossfade binder allerede numrene sammen.';

  @override
  String get settingsPreviousThreshold =>
      'Start forfra før der springes tilbage';

  @override
  String settingsPreviousThresholdHint(int seconds) {
    return '“Forrige” starter nummeret forfra, når der er spillet mere end $seconds s.';
  }

  @override
  String get settingsPreviousThresholdAlways =>
      '“Forrige” går altid til det forrige nummer.';

  @override
  String get settingsVolumeGroup => 'Lydstyrke og hastighed';

  @override
  String get settingsNormalize => 'Lydstyrkeudligning';

  @override
  String get settingsNormalizeHint =>
      'Afspiller numre med nogenlunde samme lydstyrke.';

  @override
  String get settingsNormalizationMode => 'Udligningsmetode';

  @override
  String get settingsNormalizationModeDisabled =>
      'Slå lydstyrkeudligning til først.';

  @override
  String get settingsNormalizationTrack => 'ReplayGain (nummer)';

  @override
  String get settingsNormalizationTrackHint =>
      'Bruger lydstyrkeinformationen, der er gemt i hver fil.';

  @override
  String get settingsNormalizationAlbum => 'ReplayGain (album)';

  @override
  String get settingsNormalizationAlbumHint =>
      'Bevarer de tilsigtede forskelle mellem numrene på et album.';

  @override
  String get settingsNormalizationLoudness => 'Loudness (EBU R128)';

  @override
  String get settingsNormalizationLoudnessHint =>
      'Måler lydstyrken under afspilning; virker også for streams uden tags.';

  @override
  String get settingsPreamp => 'Forforstærkning';

  @override
  String get settingsPreampHint => 'Ekstra forstærkning oven i udligningen.';

  @override
  String get settingsSpeed => 'Afspilningshastighed';

  @override
  String get settingsSpeedHint =>
      'Gælder med det samme og huskes til næste gang.';

  @override
  String get settingsStartupQueueGroup => 'Kø';

  @override
  String get settingsRestoreQueue => 'Gendan køen ved opstart';

  @override
  String get settingsRestoreQueueHint =>
      'Fortsæt hvor du slap, også positionen i nummeret.';

  @override
  String get settingsAutoplay => 'Begynd afspilning ved opstart';

  @override
  String get settingsAutoplayHint =>
      'Genoptag den gendannede kø, så snart Fermata åbner.';

  @override
  String get settingsAutoplayDisabled => 'Kræver “Gendan køen ved opstart”.';

  @override
  String get settingsSmartQueue => 'Smart kø';

  @override
  String get settingsSmartQueueHint =>
      'Tilføj lignende numre, når køen løber tør.';

  @override
  String get settingsSkipUnplayable =>
      'Spring numre over, der ikke kan afspilles';

  @override
  String get settingsSkipUnplayableHint =>
      'Gå automatisk videre, når et nummer ikke kan afspilles, og fortæl hvorfor.';

  @override
  String get settingsExtrasGroup => 'Sleep timer og sangtekster';

  @override
  String get settingsSleepFade => 'Fade ud ved sleep timer';

  @override
  String get settingsSleepFadeHint =>
      'Skru blidt ned, før sleep timeren sætter på pause.';

  @override
  String get settingsLyrics => 'Sangtekster';

  @override
  String get settingsLyricsHint =>
      'Slå sangtekster op på LRCLIB og læs tekster, der er gemt i dine filer.';

  @override
  String get settingsInterruptionsGroup => 'Hovedtelefoner og afbrydelser';

  @override
  String get settingsPauseOnDisconnect => 'Pause når hovedtelefoner frakobles';

  @override
  String get settingsPauseOnDisconnectHint =>
      'Forhindrer at musikken pludselig spiller i højttaleren.';

  @override
  String get settingsResumeAfterInterruption => 'Fortsæt efter afbrydelser';

  @override
  String get settingsResumeAfterInterruptionHint =>
      'Fortsæt efter et opkald eller en anden apps lyd.';

  @override
  String get settingsDuck => 'Skru ned ved korte lyde';

  @override
  String get settingsDuckHint =>
      'Navigationsbeskeder og notifikationer afspilles over dæmpet musik i stedet for at sætte den på pause.';

  @override
  String get settingsQualityIntro =>
      'Vælg hvor godt streams og downloads skal lyde. Højere kvalitet bruger mere data og plads.';

  @override
  String get settingStreamingQuality => 'Streamingkvalitet';

  @override
  String get settingsStreamingQualityHint =>
      'På Wi-Fi og kablede forbindelser.';

  @override
  String get settingsMobileQuality => 'Kvalitet på mobildata';

  @override
  String get settingsMobileQualityHint =>
      'På mobildata og andre forbindelser med datagrænse.';

  @override
  String get settingsDownloadQuality => 'Downloadkvalitet';

  @override
  String get settingsDownloadQualityHint =>
      'For numre en kilde tillader dig at downloade.';

  @override
  String get settingsQualityProviders =>
      'Hver udbyder bestemmer, hvilke kvaliteter den tilbyder. Fermata bruger den nærmeste tilgængelige kvalitet, som kan være lavere end dit valg — Deezer tilbyder for eksempel kun 30 sekunders smagsprøver.';

  @override
  String get settingsOutputGroup => 'Output';

  @override
  String get settingsOutputDevice => 'Outputenhed';

  @override
  String get settingsOutputDeviceHint => 'Hvor Fermata afspiller lyden.';

  @override
  String get settingsOutputDeviceSystem => 'Systemstandard';

  @override
  String settingsOutputDeviceDefault(String name) {
    return '$name (standard)';
  }

  @override
  String get settingsOutputDevicesFailed => 'Outputenhederne kunne ikke vises.';

  @override
  String get settingsOutputDeviceFailed =>
      'Kunne ikke skifte til denne outputenhed.';

  @override
  String get settingsDownloadFolder => 'Downloadmappe';

  @override
  String get settingsDownloadFolderChange => 'Skift…';

  @override
  String get settingsDownloadFolderMoving => 'Flytter…';

  @override
  String get settingsDownloadFolderPick => 'Vælg en mappe til downloads';

  @override
  String get settingsDownloadFolderMoveTitle => 'Flyt downloads?';

  @override
  String settingsDownloadFolderMoveBody(String path) {
    return 'Dine downloadede numre flyttes til $path. Det kan tage et stykke tid for store samlinger; du kan lytte videre imens.';
  }

  @override
  String get settingsDownloadFolderMove => 'Flyt downloads';

  @override
  String get settingsDownloadFolderMoved => 'Downloads flyttet';

  @override
  String get settingsDownloadFolderFailed =>
      'Downloads kunne ikke flyttes. Intet blev ændret.';

  @override
  String settingsDownloadFolderFailedDetail(String detail) {
    return 'Downloads kunne ikke flyttes: $detail';
  }

  @override
  String get settingWifiOnly => 'Download kun på Wi-Fi';

  @override
  String get settingsWifiOnlyHint =>
      'Downloads venter på Wi-Fi eller en kablet forbindelse.';

  @override
  String get settingsWarnMobile => 'Advar før mobildata bruges';

  @override
  String get settingsWarnMobileHint =>
      'Spørg før en download starter på en forbindelse med datagrænse.';

  @override
  String get settingsWarnMobileDisabled =>
      'Ikke nødvendigt, mens downloads venter på Wi-Fi.';

  @override
  String get settingsMaxConcurrent => 'Samtidige downloads';

  @override
  String get settingsMaxConcurrentHint =>
      'Hvor mange numre der downloades på samme tid.';

  @override
  String get settingsVerifyIntegrity => 'Kontrollér downloads';

  @override
  String get settingsVerifyIntegrityHint =>
      'Kontrollér hver færdig fil, før den bruges, så en ødelagt download aldrig afspilles.';

  @override
  String get settingsNotifyComplete => 'Giv besked når downloads er færdige';

  @override
  String get settingsNotifyCompleteHint =>
      'En systemnotifikation, når en række downloads er færdige.';

  @override
  String get settingsNotificationsUnsupported =>
      'Systemnotifikationer er ikke tilgængelige på denne enhed; Fermata viser fremskridtet i appen i stedet.';

  @override
  String get settingsOfflineGroup => 'Hvad kan være offline';

  @override
  String get settingsOfflineIntro =>
      'Hvert nummer hører til en af fire kategorier. Fermata følger hver udbyders vilkår og gemmer aldrig streams som filer.';

  @override
  String get settingsOfflineUserOwned =>
      'Musikfiler, du har tilføjet fra dine egne mapper. Altid tilgængelige offline.';

  @override
  String get settingsOfflineDownloadable =>
      'Udbyderen tillader at downloade nummeret (for eksempel Audius- eller Jamendo-numre, som kunstneren har gjort downloadbare). Du starter selv hver download.';

  @override
  String get settingsOfflineStreamOnly =>
      'Kan afspilles, mens du er online, men udbyderen tillader ikke at gemme det — for eksempel SoundCloud.';

  @override
  String get settingsOfflineUnavailable =>
      'Kan slet ikke gøres tilgængeligt offline, som smagsprøver eller numre, der kun afspilles i udbyderens egen app.';

  @override
  String get settingsAutoDownloadNote =>
      'Automatiske downloads (for eksempel af en hel playliste) omfatter kun kilder, der tillader det: dine egne filer. Ingen af streamingudbyderne tillader i øjeblikket automatiske downloads.';

  @override
  String get settingsUsageGroup => 'Forbrug';

  @override
  String get settingsUsageFailed => 'Pladsforbruget kunne ikke beregnes.';

  @override
  String settingsUsageTotal(String size) {
    return '$size bruges af Fermata';
  }

  @override
  String settingsUsageFree(String size) {
    return '$size ledigt på disken';
  }

  @override
  String settingsUsageDownloads(int count) {
    return 'Downloads ($count)';
  }

  @override
  String get settingsUsageArtwork => 'Cover-cache';

  @override
  String get settingsUsageStreamCache => 'Stream-cache';

  @override
  String get settingsUsageDatabase => 'Biblioteksdatabase';

  @override
  String settingsUsageLimit(String used, String limit) {
    return 'Downloads bruger $used af $limit';
  }

  @override
  String get settingsRefresh => 'Opdater';

  @override
  String get settingsLimitsGroup => 'Grænser';

  @override
  String get settingsDownloadLimit => 'Pladsgrænse for downloads';

  @override
  String get settingsDownloadLimitHint =>
      'Den største plads, downloads må bruge.';

  @override
  String get settingsUnlimited => 'Ubegrænset';

  @override
  String get settingsAutoCleanup => 'Ryd automatisk op';

  @override
  String get settingsAutoCleanupHint =>
      'Når grænsen nås, fjernes de downloads, du har spillet mindst for nylig.';

  @override
  String get settingsAutoCleanupDisabled =>
      'Angiv en pladsgrænse for at bruge automatisk oprydning.';

  @override
  String get settingsArtworkCache => 'Størrelse på cover-cache';

  @override
  String get settingsArtworkCacheHint =>
      'Covers gemmes, så de vises med det samme og virker offline.';

  @override
  String get settingsMaintenanceGroup => 'Vedligeholdelse';

  @override
  String get settingsCleanUpNow => 'Ryd op nu';

  @override
  String get settingsCleanUpNowHint => 'Anvend pladsgrænsen med det samme.';

  @override
  String get settingsCleanUpNowAction => 'Ryd op';

  @override
  String get settingsNothingToClean =>
      'Intet at rydde op — du er inden for grænsen.';

  @override
  String settingsFreed(String size) {
    return '$size frigjort';
  }

  @override
  String get settingsClearArtwork => 'Ryd cover-cache';

  @override
  String get settingsClearArtworkHint =>
      'Covers hentes igen, når der er brug for dem.';

  @override
  String get settingsClearArtworkAction => 'Ryd';

  @override
  String get settingsVerifyDownloads => 'Kontrollér downloads';

  @override
  String get settingsVerifyDownloadsHint =>
      'Kontrollér alle downloadede filer for skader.';

  @override
  String get settingsVerifyDownloadsAction => 'Kontrollér';

  @override
  String get settingsVerifyOk => 'Alle downloads er i orden.';

  @override
  String settingsVerifyBroken(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count beskadigede downloads fundet. Prøv dem igen på siden Downloads.',
      one: '1 beskadiget download fundet. Prøv igen på siden Downloads.',
    );
    return '$_temp0';
  }

  @override
  String settingsMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String settingsHoursShort(int hours) {
    return '$hours t';
  }

  @override
  String get settingsModeBalanced => 'Balanceret';

  @override
  String get settingsModePerformance => 'Ydelse';

  @override
  String get settingsModeBatterySaver => 'Batterisparer';

  @override
  String get settingsModeDataSaver => 'Datasparer';

  @override
  String get settingsModeVisualQuality => 'Visuel kvalitet';

  @override
  String get settingsModeCustom => 'Tilpasset';

  @override
  String get settingsModeBalancedHint =>
      'Standarden: fulde animationer, sløring og covers i mellemkvalitet.';

  @override
  String get settingsModePerformanceHint =>
      'Reducerer animationer og slår sløring og forudhentning af covers fra.';

  @override
  String get settingsModeBatterySaverHint =>
      'Slår animationer, sløring, forudindlæsning og baggrundssynkronisering fra og bruger mindre covers.';

  @override
  String get settingsModeDataSaverHint =>
      'Sænker streamingkvaliteten, venter på Wi-Fi med downloads og stopper forudindlæsning.';

  @override
  String get settingsModeVisualQualityHint =>
      'Fulde animationer, sløring og de skarpeste covers.';

  @override
  String get settingsModeCustomHint =>
      'Din egen kombination af indstillingerne nedenfor.';

  @override
  String get settingsPerformanceIntro =>
      'Vælg en tilstand for at ændre flere indstillinger på én gang. Ændrer du en enkelt indstilling nedenfor, skiftes der til Tilpasset.';

  @override
  String settingsActiveNow(String mode) {
    return 'Aktiv nu: $mode';
  }

  @override
  String get settingsActiveNowReducedMotion =>
      'Dine system- eller tilgængelighedsindstillinger beder om mindre bevægelse, så animationer er reduceret.';

  @override
  String get settingsGranularGroup => 'Enkelte indstillinger';

  @override
  String get settingsGranularIntro =>
      'Justerer du en af disse, skiftes tilstanden til Tilpasset.';

  @override
  String get settingAnimations => 'Animationer';

  @override
  String get settingsAnimationsHint => 'Overgange og bevægelse i hele appen.';

  @override
  String get settingBlur => 'Sløring';

  @override
  String get settingsBlurHint =>
      'Baggrundssløring til glas og Afspiller nu. Fra bruger almindelige gennemsigtige flader.';

  @override
  String get settingArtworkQuality => 'Coverkvalitet';

  @override
  String get settingsArtworkQualityHint =>
      'Lavere kvalitet afkoder mindre billeder og bruger mindre hukommelse.';

  @override
  String get settingPreloadNext => 'Forudindlæs næste nummer';

  @override
  String get settingsPreloadNextHint =>
      'Gør det næste nummer klar i god tid for glidende overgange.';

  @override
  String get settingPrefetchArtwork => 'Forudhent covers';

  @override
  String get settingsPrefetchArtworkHint =>
      'Henter covers til kommende numre på forhånd.';

  @override
  String get settingBackgroundSync => 'Baggrundssynkronisering';

  @override
  String get settingsBackgroundSyncHint =>
      'Opdaterer forbundne tjenester, anbefalinger og tilladte downloads med jævne mellemrum.';

  @override
  String get settingsSyncInterval => 'Synkroniser hver';

  @override
  String get settingsSyncIntervalDisabled =>
      'Baggrundssynkronisering er slået fra.';

  @override
  String get settingsSaversIntro =>
      'Genveje til de tilsvarende ydelsestilstande. Hver viser præcis, hvad den ændrer.';

  @override
  String get settingsSaverTurnOn => 'Brug denne tilstand';

  @override
  String get settingsSaverTurnOff => 'Slå fra (tilbage til Balanceret)';

  @override
  String get settingsBatterySaverNote =>
      'Reducerer det arbejde, Fermata udfører, mens du lytter. Selve afspilningen påvirkes ikke.';

  @override
  String get settingsDataSaverNote =>
      'Sætter også streamingkvaliteten til Lav og downloads til kun Wi-Fi. Slår du den fra, bevares de to indstillinger; ændr dem under Lydkvalitet og Downloads.';

  @override
  String get settingsSaversAndroidNote =>
      'Androids egen batterioptimering kan også stoppe musik i baggrunden. Du kan tillade Fermata at køre videre under Baggrundsafspilning.';

  @override
  String get settingsSaversCustomNote =>
      'Vil du have noget midt imellem? Vælg Tilpasset under Ydelse og justér hver indstilling.';

  @override
  String get settingsServicesIntro =>
      'Forbind de tjenester, du bruger. Hvert kort fortæller præcis, hvad Fermata kan og ikke kan med tjenesten.';

  @override
  String get settingsTokensNotPersistent =>
      'Dit system har intet sikkert nøglelager (for eksempel GNOME Keyring eller KWallet), så logins gemmes kun, indtil Fermata lukkes, og du skal forbinde igen efter en genstart. Installér og lås en nøglering op for at forblive logget ind.';

  @override
  String get settingsNoPasswords =>
      'Fermata beder aldrig om dine adgangskoder. Du logger ind på tjenestens egen hjemmeside, og Fermata gemmer kun den adgang, den har fået, i dit systems sikre lager.';

  @override
  String get settingsStatusNotRequired => 'Ingen konto nødvendig';

  @override
  String get settingsStatusCredentialsMissing => 'Ikke sat op';

  @override
  String get settingsStatusNotConnected => 'Ikke forbundet';

  @override
  String get settingsStatusConnecting => 'Forbinder…';

  @override
  String get settingsStatusConnected => 'Forbundet';

  @override
  String get settingsStatusExpired => 'Login udløbet';

  @override
  String get settingsStatusError => 'Fejl';

  @override
  String settingsStatusSemantics(String status) {
    return 'Status: $status';
  }

  @override
  String settingsAccount(String name) {
    return 'Logget ind som $name';
  }

  @override
  String settingsScopes(String scopes) {
    return 'Givet adgang: $scopes';
  }

  @override
  String settingsExpiredHint(String service) {
    return 'Dit login til $service er udløbet. Forbind igen for at fortsætte.';
  }

  @override
  String settingsErrorDetail(String detail) {
    return 'Problem: $detail';
  }

  @override
  String settingsCredentialsMissingHint(String service) {
    return '$service kræver udviklernøgler (en app-registrering), før du kan bruge den. Indtast dem nedenfor — de er ikke din adgangskode.';
  }

  @override
  String get settingsCanSearch => 'Søg i kataloget';

  @override
  String get settingsCanStream => 'Afspil hele numre i Fermata';

  @override
  String get settingsCanPreview => 'Afspil smagsprøver i Fermata';

  @override
  String settingsCanExternal(String service) {
    return 'Åbn numre i $service for at afspille dem';
  }

  @override
  String get settingsCanDownload =>
      'Download enkelte numre, som kunstneren tillader';

  @override
  String get settingsCanLibrary => 'Læs dine playlister og likede numre';

  @override
  String get settingsCanImport => 'Importér playlister';

  @override
  String get settingsCanIsrc => 'Præcis matchning via ISRC';

  @override
  String get settingsCanDiscover => 'Anbefalinger, hitlister og nye udgivelser';

  @override
  String get settingsCantStream => 'Kan ikke afspille hele numre i Fermata';

  @override
  String get settingsCantDownload => 'Ingen downloads';

  @override
  String settingsSiloed(String service) {
    return 'Numre fra $service afspilles i deres egen kø (${service}s vilkår)';
  }

  @override
  String get settingsCantLibrary => 'Ingen adgang til din kontos bibliotek';

  @override
  String get settingsConnect => 'Forbind';

  @override
  String get settingsReconnect => 'Forbind igen';

  @override
  String get settingsDisconnect => 'Afbryd forbindelse';

  @override
  String get settingsConnectingHint =>
      'Gør login færdigt i din browser. Fermata ser aldrig din adgangskode.';

  @override
  String settingsConnected(String service) {
    return 'Forbundet til $service';
  }

  @override
  String settingsConnectFailed(String service) {
    return 'Kunne ikke forbinde til $service.';
  }

  @override
  String settingsDisconnectTitle(String service) {
    return 'Afbryd forbindelsen til $service?';
  }

  @override
  String settingsDisconnectBody(String service) {
    return 'Fermata glemmer sin adgang til din $service-konto. Importerede playlister bliver i dit bibliotek.';
  }

  @override
  String get settingsTerms => 'Vilkår';

  @override
  String get settingsCredOverride => 'Brug dine egne udviklernøgler';

  @override
  String get settingsCredTitle => 'Udviklernøgler';

  @override
  String settingsCredIntro(String service) {
    return 'Værdier fra den app, du har registreret hos $service. De identificerer Fermata over for $service; din egen konto logger stadig ind på ${service}s hjemmeside.';
  }

  @override
  String settingsCredOrigin(String origin) {
    return 'Bruges nu: $origin';
  }

  @override
  String get settingsCredOriginNone => 'ingen';

  @override
  String get settingsCredOriginBuild => 'indbygget i denne version af Fermata';

  @override
  String settingsCredOriginFile(String path) {
    return 'filen $path';
  }

  @override
  String get settingsCredOriginUser => 'indtastet af dig';

  @override
  String get settingsCredRegister => 'Registrér en app';

  @override
  String get settingsCredRedirects =>
      'Omdirigerings-URI\'er der skal registreres';

  @override
  String get settingsCredRedirectDesktop => 'Computer (Linux og Windows)';

  @override
  String get settingsCredRedirectAndroid => 'Android';

  @override
  String get settingsCredRedirectCustom => 'Din egen omdirigerings-URI';

  @override
  String get settingsCredClientId => 'Client ID';

  @override
  String get settingsCredClientSecret => 'Client secret';

  @override
  String get settingsCredApiKey => 'API-nøgle';

  @override
  String get settingsCredRedirectUri => 'Omdirigerings-URI';

  @override
  String get settingsCredOptional => 'valgfri';

  @override
  String get settingsCredShow => 'Vis';

  @override
  String get settingsCredHide => 'Skjul';

  @override
  String settingsCredRequired(String fields) {
    return 'Udfyld venligst: $fields';
  }

  @override
  String settingsCredSaved(String service) {
    return 'Nøgler til $service gemt';
  }

  @override
  String get settingsCredSaveFailed => 'Nøglerne kunne ikke gemmes.';

  @override
  String get settingsCredRemoved => 'Dine nøgler blev fjernet';

  @override
  String get settingsCredRemove => 'Fjern mine';

  @override
  String get settingsCredNoPasswords => 'Indtast aldrig din adgangskode her.';

  @override
  String get settingsCopy => 'Kopiér';

  @override
  String get settingsCopied => 'Kopieret';

  @override
  String get settingsProviderOrder => 'Rækkefølge for udbydere';

  @override
  String get settingsProviderOrderHint =>
      'Bruges til at sortere søgeresultater, til at vælge en stream, når et nummer findes hos flere tjenester, og som mål ved import. Slå en tjeneste fra for at udelade den overalt.';

  @override
  String get settingsDragToReorder => 'Træk for at ændre rækkefølge';

  @override
  String get settingsMoveUp => 'Flyt op';

  @override
  String get settingsMoveDown => 'Flyt ned';

  @override
  String settingsSourceEnabled(String service) {
    return 'Brug $service';
  }

  @override
  String get settingsPreferSoundCloud => 'Foretræk SoundCloud i opdagelse';

  @override
  String get settingsPreferSoundCloudHint =>
      'Byg mixes og anbefalinger fra SoundCloud først, når den er forbundet.';

  @override
  String get settingsImportIntro =>
      'Hvordan Fermata finder dine numre hos andre tjenester, når du importerer en playliste. Dette er standarderne; du kan ændre dem for hver import.';

  @override
  String get settingsReviewMode => 'Gennemgang';

  @override
  String get settingsReviewAuto => 'Acceptér sikre match';

  @override
  String get settingsReviewAutoHint =>
      'Match over grænsen accepteres; du gennemgår resten.';

  @override
  String get settingsReviewAll => 'Gennemgå alle match';

  @override
  String get settingsReviewAllHint => 'Intet accepteres, før du bekræfter det.';

  @override
  String get settingsAutoAcceptThreshold => 'Grænse for automatisk accept';

  @override
  String get settingsAutoAcceptThresholdHint =>
      'Hvor sikker Fermata skal være, før den selv accepterer et match.';

  @override
  String get settingsAutoAcceptThresholdDisabled =>
      'Bruges kun, når sikre match accepteres automatisk.';

  @override
  String get settingsSkipUnavailable => 'Spring utilgængelige numre over';

  @override
  String get settingsSkipUnavailableHint =>
      'Udelad numre, der ikke kan afspilles hos nogen måltjeneste.';

  @override
  String get settingsPreferredProvider => 'Foretrukken tjeneste';

  @override
  String get settingsPreferredProviderHint =>
      'Når flere tjenester har nummeret, foretræk denne.';

  @override
  String get settingsNoPreference =>
      'Ingen præference (brug rækkefølgen for udbydere)';

  @override
  String get settingsAllowPreviewOnly => 'Tillad match med kun smagsprøver';

  @override
  String get settingsAllowPreviewOnlyHint =>
      'Acceptér match, der kun afspiller en kort smagsprøve, som Deezer.';

  @override
  String get settingsImportVersionsNote =>
      'Et remix, en liveversion, en akustisk eller anden version accepteres aldrig automatisk, når originalen var en anden version.';

  @override
  String get settingsImportPlaylist => 'Importér en playliste';

  @override
  String get settingsNotifyTrackChange => 'Når nummeret skifter';

  @override
  String get settingsNotifyTrackChangeHint =>
      'En lille skrivebordsnotifikation med det nye nummer.';

  @override
  String get settingsNotifyDownloads => 'Downloads';

  @override
  String get settingsNotifyDownloadsHint =>
      'Når downloads bliver færdige eller fejler.';

  @override
  String get settingsMediaNotificationNote =>
      'Notifikationen med afspilningsknapper er en del af baggrundsafspilning og vises altid, mens der spiller musik.';

  @override
  String get settingsPermissionGroup => 'Tilladelse';

  @override
  String get settingsNotificationPermission => 'Notifikationer';

  @override
  String get settingsNotificationPermissionMissing =>
      'Ikke tilladt. Android skal have din tilladelse, før Fermata kan vise afspilningsknapper og downloadbeskeder.';

  @override
  String get settingsPermissionAllowed => 'Tilladt';

  @override
  String get settingsAllow => 'Tillad';

  @override
  String get settingsOpenSystemSettings => 'Systemindstillinger';

  @override
  String get settingsBackgroundIntro =>
      'Fermata afspiller i en forgrundstjeneste med en mediennotifikation, så musikken fortsætter, når du forlader appen eller låser skærmen.';

  @override
  String get settingsBackgroundDesktop =>
      'Når du lukker vinduet, fortsætter musikken. Fermata bliver i systembakken — eller minimeret, når der ikke er nogen bakke — og dine medietaster virker stadig. Vælg Afslut i bakkemenuen for at stoppe helt.';

  @override
  String get settingsRestartRequired =>
      'Genstart Fermata for at anvende den ændrede baggrundsindstilling.';

  @override
  String get settingsStopServiceOnPause =>
      'Lad Android stoppe afspilningen ved pause';

  @override
  String get settingsStopServiceOnPauseHint =>
      'Mens der er pause, kan notifikationen swipes væk, og Android kan lukke Fermata for at spare batteri. Gælder efter genstart af Fermata.';

  @override
  String get settingsResumeOnHeadset => 'Fortsæt når hovedtelefoner tilsluttes';

  @override
  String get settingsResumeOnHeadsetHint =>
      'Fortsæt afspilningen, når hovedtelefoner eller en Bluetooth-enhed tilsluttes igen kort efter, de blev frakoblet.';

  @override
  String get settingsBatteryGroup => 'Batterioptimering';

  @override
  String get settingsBatteryOptimized => 'Batterioptimering er slået til';

  @override
  String get settingsBatteryOptimizedHint =>
      'Android kan stoppe musik i baggrunden på nogle enheder. Det er valgfrit at tillade baggrundsaktivitet, og det ændrer det kun for Fermata.';

  @override
  String get settingsBatteryUnrestricted => 'Baggrundsaktivitet er tilladt';

  @override
  String get settingsBatteryUnrestrictedHint =>
      'Android begrænser ikke Fermata i baggrunden.';

  @override
  String get settingsAllowBackground => 'Tillad baggrundsaktivitet';

  @override
  String get settingsOemNote =>
      'Nogle producenter tilføjer deres egne batterigrænser oven i Androids. Hvis musikken stadig stopper i baggrunden, så tillad også Fermata i telefonens batteriindstillinger — dontkillmyapp.com forklarer hvordan for hvert mærke.';

  @override
  String get settingsCloseBehavior => 'Når vinduet lukkes';

  @override
  String get settingsCloseToTray => 'Fortsæt i systembakken';

  @override
  String get settingsCloseToTrayHint => 'Vinduet skjules; musikken fortsætter.';

  @override
  String get settingsCloseMinimize => 'Fortsæt minimeret';

  @override
  String get settingsCloseMinimizeHint =>
      'Der er ingen systembakke, så vinduet minimeres; musikken fortsætter.';

  @override
  String get settingsCloseAsk => 'Spørg hver gang';

  @override
  String get settingsCloseAskHint =>
      'Vælg mellem at fortsætte musikken og at afslutte.';

  @override
  String get settingsCloseQuit => 'Afslut Fermata';

  @override
  String get settingsCloseQuitHint =>
      'Afspilningen stopper, og Fermata lukker.';

  @override
  String get settingsShowTrayIcon => 'Vis ikon i systembakken';

  @override
  String get settingsShowTrayIconHint =>
      'Hurtige knapper og det aktuelle nummer i systembakken.';

  @override
  String get settingsRememberWindow => 'Husk vinduets størrelse og placering';

  @override
  String get settingsRememberWindowHint => 'Åbner, hvor du forlod det sidst.';

  @override
  String get settingsQuitNote =>
      'For at stoppe helt, vælg Afslut i bakkemenuen — eller vælg “Spørg hver gang” ovenfor for at få en Afslut-knap, når du lukker vinduet.';

  @override
  String get settingsLaunchAtLogin => 'Start ved login';

  @override
  String get settingsLaunchAtLoginHint =>
      'Start Fermata, når du logger ind på computeren.';

  @override
  String get settingsLaunchAtLoginUnsupported =>
      'Ikke tilgængelig på dette system.';

  @override
  String get settingsLaunchAtLoginFailed =>
      'Login-indstillingen kunne ikke ændres.';

  @override
  String get settingsStartMinimized => 'Start minimeret';

  @override
  String get settingsStartMinimizedHint =>
      'Start i systembakken (eller minimeret) i stedet for at vise vinduet.';

  @override
  String get settingsShortcutsIntro =>
      'Klik på en genvej for at optage en ny. Konflikter vises med rødt.';

  @override
  String get settingsShortcutsInApp => 'I Fermata';

  @override
  String get settingsShortcutsGlobal => 'Globale genveje';

  @override
  String get settingsShortcutsGlobalHint =>
      'Virker overalt, også når Fermata er i baggrunden.';

  @override
  String get settingsGlobalHotkeys => 'Brug globale genveje';

  @override
  String get settingsGlobalHotkeysHint =>
      'Fermata registrerer disse taster hos dit skrivebord.';

  @override
  String get settingsShortcutNone => 'Ikke angivet';

  @override
  String settingsShortcutConflict(String actions) {
    return 'Bruges også af: $actions';
  }

  @override
  String settingsShortcutChangeSemantics(String action, String binding) {
    return '$action: $binding. Skift genvej';
  }

  @override
  String get settingsShortcutMore => 'Flere valgmuligheder';

  @override
  String get settingsShortcutChange => 'Optag ny genvej';

  @override
  String get settingsShortcutReset => 'Nulstil til standard';

  @override
  String get settingsShortcutRemove => 'Fjern genvej';

  @override
  String settingsShortcutRecordTitle(String action) {
    return 'Genvej til “$action”';
  }

  @override
  String get settingsShortcutRecordHint =>
      'Tryk på den tastekombination, du vil bruge. Tryk Esc for at annullere.';

  @override
  String get settingsShortcutWaiting => 'Venter på taster…';

  @override
  String get settingsShortcutNeedsModifier =>
      'Globale genveje skal bruge Ctrl, Alt, Shift eller Super, ellers ville de blokere for skrivning i andre apps.';

  @override
  String get settingsFileInvalid =>
      'Filen er ikke en Fermata-fil, eller den er beskadiget.';

  @override
  String get settingsRecordHistory => 'Lyttehistorik';

  @override
  String get settingsRecordHistoryHint =>
      'Husk hvad du afspiller, kun på denne enhed. Bruges til Historik, Senest afspillet og dine mixes.';

  @override
  String get settingsPersonalized => 'Personlige anbefalinger';

  @override
  String get settingsPersonalizedHint =>
      'Mixes og forslag beregnes på denne enhed ud fra din historik og dine favoritter. Fra viser kun populær musik, nye udgivelser og genrer.';

  @override
  String get settingsSaveSearches => 'Søgehistorik';

  @override
  String get settingsSaveSearchesHint =>
      'Vis dine seneste søgninger under Søg.';

  @override
  String get settingsNoTrackingTitle => 'Ingen analyse eller sporing';

  @override
  String get settingsNoTracking =>
      'Fermata har ingen analyse, ingen reklamer, ingen nedbrudsrapportering og ingen egen konto. Intet om, hvad du lytter til, forlader enheden, medmindre en tjeneste, du har forbundet, har brug for det for at afspille musikken.';

  @override
  String get settingsNetworkIntro => 'Fermata forbinder kun til:';

  @override
  String get settingsNetworkProviders =>
      'De musiktjenester, du bruger — for at søge, streame, læse dine playlister og importere. Forespørgsler går direkte fra enheden til tjenesten.';

  @override
  String get settingsNetworkLyricsOn =>
      'LRCLIB, for at slå sangtekster op til nummeret, der spiller (titel, kunstner, album og varighed sendes).';

  @override
  String get settingsNetworkLyricsOff =>
      'LRCLIB kontaktes ikke, fordi sangtekster er slået fra.';

  @override
  String get settingsNetworkUpdatesOn =>
      'GitHub, én gang om dagen, for at se om der findes en ny version af Fermata. Intet om dig sendes.';

  @override
  String get settingsNetworkUpdatesOff =>
      'GitHub kun når du trykker “Søg nu” under Opdateringer.';

  @override
  String get settingsNetworkArtwork =>
      'Tjenesternes billedservere, for at hente covers (gemmes i cover-cachen).';

  @override
  String get settingsNetworkSignIn =>
      'En tjenestes egen login-side i din browser, når du forbinder den.';

  @override
  String get settingsYourDataGroup => 'Dine data';

  @override
  String get settingsDeleteHistory => 'Slet lyttehistorik';

  @override
  String get settingsDeleteHistoryHint =>
      'Fjerner alle afspilninger fra Historik og statistik.';

  @override
  String get settingsDeleteHistoryTitle => 'Slet lyttehistorik?';

  @override
  String get settingsDeleteHistoryBody =>
      'Historik, “Senest afspillet” og lyttestatistik slettes. Dine mixes starter forfra.';

  @override
  String get settingsDeleteHistoryDone => 'Lyttehistorik slettet';

  @override
  String get settingsClearSearches => 'Ryd søgehistorik';

  @override
  String get settingsClearSearchesHint => 'Fjerner dine seneste søgninger.';

  @override
  String get settingsClearSearchesTitle => 'Ryd søgehistorik?';

  @override
  String get settingsClearSearchesBody => 'Dine seneste søgninger fjernes.';

  @override
  String get settingsClearSearchesDone => 'Søgehistorik ryddet';

  @override
  String get settingsClearAction => 'Ryd';

  @override
  String get settingsExportSettings => 'Eksportér indstillinger';

  @override
  String get settingsExportSettingsHint =>
      'Gem dine indstillinger som en fil. Den indeholder ingen adgangskoder eller logins.';

  @override
  String get settingsImportSettings => 'Importér indstillinger';

  @override
  String get settingsImportSettingsHint =>
      'Erstat dine indstillinger med en eksporteret fil.';

  @override
  String get settingsImportSettingsDone => 'Indstillinger importeret';

  @override
  String get settingsExportAction => 'Eksportér';

  @override
  String get settingsImportAction => 'Importér';

  @override
  String get settingsBackupLibrary => 'Sikkerhedskopiér bibliotek';

  @override
  String get settingsBackupLibraryHint =>
      'Playlister, favoritter, historik og nummerlinks som én fil. Musikfiler er ikke med.';

  @override
  String get settingsRestoreLibrary => 'Gendan bibliotek';

  @override
  String get settingsRestoreLibraryHint =>
      'Hent en sikkerhedskopi af biblioteket tilbage.';

  @override
  String get settingsRestoreLibraryTitle =>
      'Gendan sikkerhedskopi af biblioteket?';

  @override
  String get settingsRestoreLibraryBody =>
      'Flet tilføjer sikkerhedskopien til dit nuværende bibliotek. Erstat fjerner først dine nuværende playlister, favoritter og historik.';

  @override
  String get settingsRestoreMerge => 'Flet';

  @override
  String get settingsRestoreReplace => 'Erstat';

  @override
  String get settingsRestoreLibraryDone => 'Bibliotek gendannet';

  @override
  String get settingsDeleteAll => 'Slet alle data';

  @override
  String get settingsDeleteAllHint =>
      'Playlister, favoritter, historik, søgninger og logins. Dine musikfiler bliver på disken.';

  @override
  String get settingsDeleteAllTitle => 'Slet alle dine data?';

  @override
  String get settingsDeleteAllBody =>
      'Dette sletter dine playlister, favoritter, lytte- og søgehistorik, nummerlinks og gemte metadata og logger dig ud af alle tjenester. Musikfiler på din disk slettes aldrig, og dine indstillinger bevares. Det kan ikke fortrydes.';

  @override
  String get settingsDeleteAllWord => 'SLET';

  @override
  String get settingsDeleteAllAction => 'Slet alt';

  @override
  String get settingsDeleteAllDone => 'Alle dine data blev slettet';

  @override
  String get settingsLanguageSystem => 'Systemets sprog';

  @override
  String get settingsLanguageSystemHint =>
      'Følger din enhed. Sprog, Fermata endnu ikke har, falder tilbage til engelsk.';

  @override
  String get settingsMotion => 'Bevægelse';

  @override
  String get settingsMotionHint =>
      '“System” følger enhedens indstilling for reduceret bevægelse.';

  @override
  String get settingsMotionSystem => 'System';

  @override
  String get settingsMotionReduce => 'Reducér';

  @override
  String get settingsMotionFull => 'Fuld';

  @override
  String get settingsTextScale => 'Tekststørrelse';

  @override
  String get settingsTextScaleHint => 'Oven i systemets tekststørrelse.';

  @override
  String get settingsTextScalePreviewTitle => 'Natkørsel';

  @override
  String get settingsTextScalePreviewBody =>
      'Sådan kommer titler og beskrivelser til at se ud.';

  @override
  String get settingsLargerTargets => 'Større trykområder';

  @override
  String get settingsLargerTargetsHint =>
      'Større knapper og rækker, der er nemmere at ramme.';

  @override
  String get settingsAccessibilityNote =>
      'Fermata virker med skærmlæsere (TalkBack, Orca, Oplæser) og kan bruges helt med tastaturet på computeren.';

  @override
  String get settingsCurrentVersion => 'Installeret version';

  @override
  String get settingsAutoUpdateCheck => 'Søg automatisk efter opdateringer';

  @override
  String get settingsAutoUpdateCheckHint =>
      'Slået fra som standard. Én gang om dagen spørger Fermata GitHub om den nyeste version; intet om dig sendes. Fermata installerer aldrig noget af sig selv.';

  @override
  String get settingsCheckNow => 'Søg nu';

  @override
  String get settingsCheckNowHint =>
      'Spørger GitHub én gang om den nyeste version.';

  @override
  String get settingsCheckNowAction => 'Søg';

  @override
  String settingsUpToDate(String version) {
    return 'Du har den nyeste version ($version).';
  }

  @override
  String settingsUpdateAvailable(String version) {
    return 'Version $version er tilgængelig.';
  }

  @override
  String get settingsNoReleases => 'Der er ikke udgivet nogen version endnu.';

  @override
  String get settingsUpdateFailed =>
      'Kunne ikke søge efter opdateringer. Tjek din forbindelse, og prøv igen.';

  @override
  String get settingsUpdateHowLinux =>
      'For at opdatere skal du hente den nyere version og køre dens setup.sh på samme måde, som du installerede Fermata. Dit bibliotek, dine indstillinger og logins bevares.';

  @override
  String get settingsUpdateHowWindows =>
      'For at opdatere skal du hente og køre den nyere setup.exe. Den erstatter den installerede version og bevarer dit bibliotek, dine indstillinger og logins.';

  @override
  String get settingsUpdateHowAndroid =>
      'For at opdatere skal du installere den nyere app.apk oven på denne. Dine data bevares.';

  @override
  String get settingsReleaseNotes => 'Udgivelsesnoter';

  @override
  String get settingsTagline =>
      'En rolig musikafspiller, der sætter dine egne filer først — sammen med de tjenester, du bruger.';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsPlatform => 'Platform';

  @override
  String get settingsLogFile => 'Logfil';

  @override
  String get settingsExportDiagnostics => 'Eksportér diagnosticering';

  @override
  String get settingsExportDiagnosticsHint =>
      'Gemmer de seneste logs og et resumé af din opsætning i en fil, du kan vedhæfte en fejlrapport. Indeholder ingen adgangskoder, logins eller nøgler.';

  @override
  String get settingsLicenses => 'Open source-licenser';

  @override
  String get settingsLicensesHint =>
      'Licenserne for den software, Fermata er bygget med.';

  @override
  String get settingsLicensesAction => 'Vis';

  @override
  String get settingsAttributions => 'Kildeangivelser';

  @override
  String get settingsAttributionSoundCloud =>
      'SoundCloud: numre og covers leveres af SoundCloud og deres skabere. Hvert SoundCloud-nummer linker til nummeret og uploaderen på soundcloud.com.';

  @override
  String get settingsAttributionDeezer =>
      'Deezer: katalogdata og 30 sekunders smagsprøver leveres af Deezer.';

  @override
  String get settingsAttributionAudius =>
      'Audius: numre streames fra Audius-netværket og tilhører deres kunstnere.';

  @override
  String get settingsAttributionJamendo =>
      'Jamendo: musik leveres af Jamendo under hver kunstners Creative Commons-licens.';

  @override
  String get settingsAttributionLrclib =>
      'Sangtekster: leveres af LRCLIB (lrclib.net), en gratis fællesskabsdatabase med sangtekster.';

  @override
  String get settingsAttributionSpotifyYouTube =>
      'Indhold fra Spotify og YouTube Music vises, som tjenesterne leverer det, og åbnes i deres egne apps.';

  @override
  String get settingsCredits => 'Tak til';

  @override
  String get settingsCreditsBody =>
      'Lavet med Flutter. Skrifttype: Manrope (SIL Open Font License). Afspilning med libmpv/media_kit på computer og ExoPlayer/just_audio på Android. Tak til alle, der bygger den open source-software, der står under licenser.';

  @override
  String get navHome => 'Hjem';

  @override
  String get navSearch => 'Søg';

  @override
  String get navExplore => 'Udforsk';

  @override
  String get navLibrary => 'Bibliotek';

  @override
  String get navPlaylists => 'Playlister';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navFavorites => 'Synes godt om';

  @override
  String get navHistory => 'Historik';

  @override
  String get navQueue => 'Kø';

  @override
  String get navSettings => 'Indstillinger';

  @override
  String get navNowPlaying => 'Afspiller nu';

  @override
  String get navImport => 'Importér en playliste';

  @override
  String get shellYourPlaylists => 'Dine playlister';

  @override
  String get shellNoPlaylists => 'Ingen playlister endnu';

  @override
  String get shellPageNotFound => 'Siden findes ikke.';

  @override
  String get shellGoHome => 'Gå til Hjem';

  @override
  String get shellCommandPalette => 'Kommandopalet';

  @override
  String get shellLoading => 'Indlæser';

  @override
  String get paletteHint => 'Søg efter kommandoer, playlister og numre';

  @override
  String get paletteNoResults => 'Ingen resultater';

  @override
  String get paletteGroupNavigation => 'Gå til';

  @override
  String get paletteGroupPlayer => 'Afspiller';

  @override
  String get paletteGroupSettings => 'Indstillinger';

  @override
  String get paletteGroupPlaylists => 'Playlister';

  @override
  String get paletteGroupTracks => 'I dit bibliotek';

  @override
  String get paletteFooter =>
      'Op og ned for at flytte · Enter for at vælge · Esc for at lukke';

  @override
  String get cmdPlayPause => 'Afspil eller sæt på pause';

  @override
  String get cmdNext => 'Næste nummer';

  @override
  String get cmdPrevious => 'Forrige nummer';

  @override
  String get cmdSeekForward => 'Spol 10 sekunder frem';

  @override
  String get cmdSeekBackward => 'Spol 10 sekunder tilbage';

  @override
  String get cmdVolumeUp => 'Skru op';

  @override
  String get cmdVolumeDown => 'Skru ned';

  @override
  String get cmdToggleShuffle => 'Bland til eller fra';

  @override
  String get cmdCycleRepeat => 'Skift gentagelse';

  @override
  String get cmdLike => 'Synes godt om det aktuelle nummer';

  @override
  String get cmdSearch => 'Søg';

  @override
  String get cmdCommandPalette => 'Åbn kommandopaletten';

  @override
  String get cmdNowPlaying => 'Vis Afspiller nu';

  @override
  String get cmdQueue => 'Vis køen';

  @override
  String get cmdSettings => 'Åbn indstillinger';

  @override
  String get cmdGlobalPlayPause => 'Afspil eller pause (i hele systemet)';

  @override
  String get cmdGlobalNext => 'Næste nummer (i hele systemet)';

  @override
  String get cmdGlobalPrevious => 'Forrige nummer (i hele systemet)';

  @override
  String get cmdGlobalShowWindow => 'Vis Fermata (i hele systemet)';

  @override
  String get cmdMiniPlayer => 'Miniafspiller til eller fra';

  @override
  String get cmdClearQueue => 'Ryd køen';

  @override
  String get cmdStop => 'Stop afspilningen';

  @override
  String get shellSectionAppearance => 'Udseende og tema';

  @override
  String get shellSectionGlass => 'Liquid Glass';

  @override
  String get shellSectionPlayback => 'Afspilning';

  @override
  String get shellSectionAudioQuality => 'Lydkvalitet';

  @override
  String get shellSectionDownloads => 'Downloads';

  @override
  String get shellSectionStorage => 'Lagerplads og cache';

  @override
  String get shellSectionPerformance => 'Ydeevne';

  @override
  String get shellSectionSavers => 'Batteri- og datasparer';

  @override
  String get shellSectionServices => 'Forbundne tjenester';

  @override
  String get shellSectionImport => 'Import og matchning af playlister';

  @override
  String get shellSectionNotifications => 'Notifikationer';

  @override
  String get shellSectionBackground => 'Afspilning i baggrunden';

  @override
  String get shellSectionDesktop => 'Systembakke og vindue';

  @override
  String get shellSectionStartup => 'Opstart';

  @override
  String get shellSectionShortcuts => 'Tastaturgenveje';

  @override
  String get shellSectionPrivacy => 'Privatliv';

  @override
  String get shellSectionLanguage => 'Sprog';

  @override
  String get shellSectionAccessibility => 'Tilgængelighed';

  @override
  String get shellSectionUpdates => 'Opdateringer';

  @override
  String get shellSectionAbout => 'Om og diagnosticering';

  @override
  String get shellErrorStorage =>
      'Der er ikke plads nok, eller mappen kan ikke skrives til.';

  @override
  String get shellErrorDownloadNotPermitted =>
      'Dette nummer kan ikke downloades.';

  @override
  String get shellAddedToQueue => 'Føjet til køen';

  @override
  String get shellPlayingNext => 'Afspilles som det næste';

  @override
  String shellAddedToPlaylist(String playlist) {
    return 'Føjet til $playlist';
  }

  @override
  String shellTracksAddedToPlaylist(int count, String playlist) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre føjet til $playlist',
      one: '1 nummer føjet til $playlist',
    );
    return '$_temp0';
  }

  @override
  String get shellLiked => 'Føjet til Synes godt om';

  @override
  String get shellUnliked => 'Fjernet fra Synes godt om';

  @override
  String get shellDownloadQueued => 'Download tilføjet';

  @override
  String shellDownloadsQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads tilføjet',
      one: '1 download tilføjet',
    );
    return '$_temp0';
  }

  @override
  String shellDownloadsRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count numre kan ikke downloades',
      one: '1 nummer kan ikke downloades',
    );
    return '$_temp0';
  }

  @override
  String get shellDownloadRemoved => 'Download fjernet';

  @override
  String get shellLinkCopied => 'Linket er kopieret';

  @override
  String get shellCouldNotOpenLink => 'Linket kunne ikke åbnes.';

  @override
  String get shellNewPlaylist => 'Ny playliste';

  @override
  String get shellPlaylistNameHint => 'Navn på playliste';

  @override
  String get shellCreate => 'Opret';

  @override
  String get shellAdd => 'Tilføj';

  @override
  String get shellAddToPlaylistTitle => 'Føj til playliste';

  @override
  String get shellAddToPlaylistEmpty =>
      'Opret din første playliste for at føje numre til den.';

  @override
  String shellTypeToConfirm(String word) {
    return 'Skriv $word for at bekræfte';
  }

  @override
  String shellSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valgt',
      one: '1 valgt',
    );
    return '$_temp0';
  }

  @override
  String get shellSelectAll => 'Vælg alle';

  @override
  String get shellClearSelection => 'Ryd valg';

  @override
  String get shellSelect => 'Vælg';

  @override
  String get shellScrollLeft => 'Rul til venstre';

  @override
  String get shellScrollRight => 'Rul til højre';

  @override
  String get shellSeeAll => 'Se alle';

  @override
  String get shellSearchHint => 'Søg';

  @override
  String get shellClearSearch => 'Ryd søgning';

  @override
  String get shellBadgePreview => 'Smagsprøve';

  @override
  String shellBadgeExternal(String provider) {
    return 'Afspilles på $provider';
  }

  @override
  String get shellBadgeDownloaded => 'Downloadet';

  @override
  String get shellBadgeUnavailable => 'Ikke tilgængelig';

  @override
  String get shellBadgeExplicit => 'Eksplicit';

  @override
  String get shellMenuPlay => 'Afspil';

  @override
  String get shellMenuPlayNext => 'Afspil som det næste';

  @override
  String get shellMenuAddToQueue => 'Føj til køen';

  @override
  String get shellMenuAddToPlaylist => 'Føj til playliste';

  @override
  String get shellMenuLike => 'Synes godt om';

  @override
  String get shellMenuUnlike => 'Fjern fra Synes godt om';

  @override
  String get shellMenuDownload => 'Download';

  @override
  String get shellMenuRemoveDownload => 'Fjern download';

  @override
  String get shellMenuGoToArtist => 'Gå til kunstner';

  @override
  String get shellMenuGoToAlbum => 'Gå til album';

  @override
  String shellMenuOpenOn(String provider) {
    return 'Åbn på $provider';
  }

  @override
  String get shellMenuCopyLink => 'Kopiér link';

  @override
  String get shellMoreOptions => 'Flere muligheder';

  @override
  String get shellNowPlayingIndicator => 'Afspiller nu';

  @override
  String get shellGlassPreviewTitle => 'Nummerets titel';

  @override
  String get shellGlassPreviewArtist => 'Kunstner';

  @override
  String get shellGlassModeSolid => 'Massive flader';

  @override
  String get shellGlassModeTranslucent => 'Gennemsigtig uden sløring';

  @override
  String get shellGlassModeBlurred => 'Gennemsigtig med sløring';

  @override
  String get shellFileYourFile => 'Lokal fil';

  @override
  String get shellCloseTitle => 'Vil du lukke Fermata?';

  @override
  String get shellCloseMessage =>
      'Fermata kan spille videre i systembakken eller lukke helt ned.';

  @override
  String get shellCloseMinimize => 'Spil videre i systembakken';

  @override
  String get shellCloseQuit => 'Afslut';

  @override
  String get shellCloseRemember => 'Husk mit valg';
}
