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
