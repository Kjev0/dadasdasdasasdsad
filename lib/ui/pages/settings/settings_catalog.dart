import 'package:flutter/material.dart';

import '../../../core/platform/platform_info.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../actions/command_registry.dart';
import '../../actions/routes.dart';
import 'sections/about_section.dart';
import 'sections/appearance_section.dart';
import 'sections/downloads_section.dart';
import 'sections/import_settings_section.dart';
import 'sections/language_accessibility_section.dart';
import 'sections/performance_section.dart';
import 'sections/playback_section.dart';
import 'sections/privacy_section.dart';
import 'sections/services_section.dart';
import 'sections/shortcuts_section.dart';
import 'sections/system_sections.dart';

/// Static description of one settings section: icon, body, the labels of
/// the settings inside it (for search) and where it is shown.
class SettingsSectionInfo {
  const SettingsSectionInfo({
    required this.id,
    required this.icon,
    required this.build,
    required this.keywords,
    this.desktopOnly = false,
  });

  final String id;
  final IconData icon;

  /// Builds the section body; [showHeading] is false when the page chrome
  /// already shows the title (mobile).
  final Widget Function(bool showHeading) build;
  final List<String> Function(AppLocalizations l10n) keywords;
  final bool desktopOnly;

  String title(AppLocalizations l10n) => CommandRegistry.sectionLabel(l10n, id);

  bool visibleOn(PlatformInfo platform) => !desktopOnly || platform.isDesktop;
}

/// Every section in display order (ids from [SettingsSections]).
final List<SettingsSectionInfo> settingsCatalog = [
  SettingsSectionInfo(
    id: SettingsSections.appearance,
    icon: Icons.palette_outlined,
    build: (h) => AppearanceSection(showHeading: h),
    keywords: (l) => [l.settingsThemeMode, l.settingsThemeDark, l.settingsThemeLight, l.settingsAccent, l.settingsDensity, l.settingsArtworkBackdrop, l.settingsHighContrast],
  ),
  SettingsSectionInfo(
    id: SettingsSections.glass,
    icon: Icons.blur_on_rounded,
    build: (h) => GlassSection(showHeading: h),
    keywords: (l) => [l.settingsGlassToggle, l.settingsGlassIntensity, l.settingBlur],
  ),
  SettingsSectionInfo(
    id: SettingsSections.playback,
    icon: Icons.play_circle_outline_rounded,
    build: (h) => PlaybackSection(showHeading: h),
    keywords: (l) => [
      l.settingsCrossfade, l.settingsGapless, l.settingsNormalize, l.settingsNormalizationMode, l.settingsPreamp, l.settingsSpeed,
      l.settingsRestoreQueue, l.settingsAutoplay, l.settingsSmartQueue, l.settingsSkipUnplayable, l.settingsPreviousThreshold,
      l.settingsSleepFade, l.settingsLyrics, l.settingsPauseOnDisconnect, l.settingsResumeAfterInterruption, l.settingsDuck,
    ],
  ),
  SettingsSectionInfo(
    id: SettingsSections.audioQuality,
    icon: Icons.graphic_eq_rounded,
    build: (h) => AudioQualitySection(showHeading: h),
    keywords: (l) => [l.settingStreamingQuality, l.settingsMobileQuality, l.settingsDownloadQuality, l.settingsOutputDevice],
  ),
  SettingsSectionInfo(
    id: SettingsSections.downloads,
    icon: Icons.download_outlined,
    build: (h) => DownloadsSection(showHeading: h),
    keywords: (l) => [l.settingsDownloadFolder, l.settingWifiOnly, l.settingsWarnMobile, l.settingsMaxConcurrent, l.settingsVerifyIntegrity, l.settingsNotifyComplete, l.settingsOfflineGroup],
  ),
  SettingsSectionInfo(
    id: SettingsSections.storage,
    icon: Icons.storage_rounded,
    build: (h) => StorageSection(showHeading: h),
    keywords: (l) => [l.settingsUsageGroup, l.settingsDownloadLimit, l.settingsArtworkCache, l.settingsAutoCleanup, l.settingsCleanUpNow, l.settingsClearArtwork, l.settingsVerifyDownloads],
  ),
  SettingsSectionInfo(
    id: SettingsSections.performance,
    icon: Icons.speed_rounded,
    build: (h) => PerformanceSection(showHeading: h),
    keywords: (l) => [
      l.settingsModeBalanced, l.settingsModePerformance, l.settingsModeVisualQuality, l.settingsModeCustom, l.settingAnimations, l.settingBlur,
      l.settingArtworkQuality, l.settingPreloadNext, l.settingPrefetchArtwork, l.settingBackgroundSync, l.settingsSyncInterval,
    ],
  ),
  SettingsSectionInfo(
    id: SettingsSections.savers,
    icon: Icons.battery_saver_outlined,
    build: (h) => SaversSection(showHeading: h),
    keywords: (l) => [l.settingsModeBatterySaver, l.settingsModeDataSaver],
  ),
  SettingsSectionInfo(
    id: SettingsSections.services,
    icon: Icons.hub_outlined,
    build: (h) => ServicesSection(showHeading: h),
    keywords: (l) => [l.settingsConnect, l.settingsCredTitle, l.settingsProviderOrder, l.settingsPreferSoundCloud, 'SoundCloud', 'Spotify', 'Deezer', 'Audius', 'YouTube', 'Jamendo'],
  ),
  SettingsSectionInfo(
    id: SettingsSections.import,
    icon: Icons.playlist_add_check_rounded,
    build: (h) => ImportSettingsSection(showHeading: h),
    keywords: (l) => [l.settingsReviewMode, l.settingsAutoAcceptThreshold, l.settingsSkipUnavailable, l.settingsPreferredProvider, l.settingsAllowPreviewOnly, l.settingsImportPlaylist],
  ),
  SettingsSectionInfo(
    id: SettingsSections.notifications,
    icon: Icons.notifications_none_rounded,
    build: (h) => NotificationsSection(showHeading: h),
    keywords: (l) => [l.settingsNotifyTrackChange, l.settingsNotifyDownloads, l.settingsNotificationPermission],
  ),
  SettingsSectionInfo(
    id: SettingsSections.background,
    icon: Icons.music_note_outlined,
    build: (h) => BackgroundSection(showHeading: h),
    keywords: (l) => [l.settingsStopServiceOnPause, l.settingsResumeOnHeadset, l.settingsBatteryGroup, l.settingsAllowBackground],
  ),
  SettingsSectionInfo(
    id: SettingsSections.desktop,
    icon: Icons.desktop_windows_outlined,
    build: (h) => DesktopSection(showHeading: h),
    keywords: (l) => [l.settingsCloseBehavior, l.settingsShowTrayIcon, l.settingsRememberWindow],
    desktopOnly: true,
  ),
  SettingsSectionInfo(
    id: SettingsSections.startup,
    icon: Icons.power_settings_new_rounded,
    build: (h) => StartupSection(showHeading: h),
    keywords: (l) => [l.settingsLaunchAtLogin, l.settingsStartMinimized],
    desktopOnly: true,
  ),
  SettingsSectionInfo(
    id: SettingsSections.shortcuts,
    icon: Icons.keyboard_outlined,
    build: (h) => ShortcutsSection(showHeading: h),
    keywords: (l) => [l.settingsShortcutsInApp, l.settingsGlobalHotkeys, for (final a in CommandRegistry.allBindableActions) CommandRegistry.labelFor(l, a)],
    desktopOnly: true,
  ),
  SettingsSectionInfo(
    id: SettingsSections.privacy,
    icon: Icons.privacy_tip_outlined,
    build: (h) => PrivacySection(showHeading: h),
    keywords: (l) => [
      l.settingsRecordHistory, l.settingsPersonalized, l.settingsSaveSearches, l.settingsNoTrackingTitle, l.settingsDeleteHistory,
      l.settingsClearSearches, l.settingsDeleteAll, l.settingsExportSettings, l.settingsImportSettings, l.settingsBackupLibrary, l.settingsRestoreLibrary,
    ],
  ),
  SettingsSectionInfo(
    id: SettingsSections.language,
    icon: Icons.translate_rounded,
    build: (h) => LanguageSection(showHeading: h),
    keywords: (l) => [l.settingsLanguageSystem, 'English', 'Dansk'],
  ),
  SettingsSectionInfo(
    id: SettingsSections.accessibility,
    icon: Icons.accessibility_new_rounded,
    build: (h) => AccessibilitySection(showHeading: h),
    keywords: (l) => [l.settingsMotion, l.settingsHighContrast, l.settingsTextScale, l.settingsLargerTargets],
  ),
  SettingsSectionInfo(
    id: SettingsSections.updates,
    icon: Icons.system_update_alt_rounded,
    build: (h) => UpdatesSection(showHeading: h),
    keywords: (l) => [l.settingsCurrentVersion, l.settingsAutoUpdateCheck, l.settingsCheckNow, l.settingsReleaseNotes],
  ),
  SettingsSectionInfo(
    id: SettingsSections.about,
    icon: Icons.info_outline_rounded,
    build: (h) => AboutSection(showHeading: h),
    keywords: (l) => [l.settingsVersion, l.settingsLicenses, l.settingsAttributions, l.settingsExportDiagnostics, l.settingsLogFile],
  ),
];

SettingsSectionInfo? settingsSectionById(String? id) => settingsCatalog.where((s) => s.id == id).firstOrNull;

/// One search hit: a setting label (or the section title) inside a section.
class SettingsSearchHit {
  const SettingsSearchHit(this.section, this.label);

  final SettingsSectionInfo section;
  final String label;
}

/// Case- and accent-insensitive search over section titles and the labels
/// of the settings inside them.
List<SettingsSearchHit> searchSettings(AppLocalizations l10n, PlatformInfo platform, String query) {
  final q = foldForSearch(query.trim());
  if (q.isEmpty) return const [];
  final hits = <SettingsSearchHit>[];
  for (final s in settingsCatalog) {
    if (!s.visibleOn(platform)) continue;
    final title = s.title(l10n);
    if (foldForSearch(title).contains(q)) hits.add(SettingsSearchHit(s, title));
    for (final k in s.keywords(l10n).toSet()) {
      if (k != title && foldForSearch(k).contains(q)) hits.add(SettingsSearchHit(s, k));
    }
  }
  return hits;
}

/// Lowercases and strips common accents (so "lydstyrke" finds "Lydstyrke",
/// "cafe" finds "Café").
String foldForSearch(String s) {
  const from = 'àáâãäåèéêëìíîïòóôõöùúûüýÿñç';
  const to = 'aaaaaaeeeeiiiiooooouuuuyync';
  final lower = s.toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}
