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
