import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../settings/app_settings.dart';

/// Human-readable byte size (`1.2 GB`), using the locale's decimal mark.
String formatBytes(int bytes, {String? locale}) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 || value >= 100 ? 0 : 1;
  final f = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: digits);
  return '${f.format(value)} ${units[unit]}';
}

/// Megabytes as a readable size (`2 GB`, `300 MB`).
String formatMegabytes(int mb, {String? locale}) => formatBytes(mb * 1024 * 1024, locale: locale);

/// Localized label of an [AnimationLevel].
String animationLabel(AppLocalizations l10n, AnimationLevel a) => switch (a) {
      AnimationLevel.full => l10n.settingsValueFull,
      AnimationLevel.reduced => l10n.settingsValueReduced,
      AnimationLevel.off => l10n.settingsOff,
    };

/// Localized label of an [ArtworkQuality].
String artworkQualityLabel(AppLocalizations l10n, ArtworkQuality q) => switch (q) {
      ArtworkQuality.low => l10n.settingsValueLow,
      ArtworkQuality.medium => l10n.settingsValueMedium,
      ArtworkQuality.high => l10n.settingsValueHigh,
    };

/// Localizes a raw `ProfileEffect.valueLabel` (enum name, bool or number).
String effectValueLabel(AppLocalizations l10n, String raw) => switch (raw) {
      'true' => l10n.settingsOn,
      'false' || 'off' => l10n.settingsOff,
      'full' => l10n.settingsValueFull,
      'reduced' => l10n.settingsValueReduced,
      'low' => l10n.settingsValueLow,
      'medium' => l10n.settingsValueMedium,
      'high' => l10n.settingsValueHigh,
      'normal' => l10n.settingsValueNormal,
      'lossless' => l10n.settingsValueLossless,
      _ => raw,
    };

/// Localizes a `ProfileEffect.settingKey` (a localization key name).
String effectSettingLabel(AppLocalizations l10n, String key) => switch (key) {
      'settingAnimations' => l10n.settingAnimations,
      'settingBlur' => l10n.settingBlur,
      'settingArtworkQuality' => l10n.settingArtworkQuality,
      'settingPreloadNext' => l10n.settingPreloadNext,
      'settingPrefetchArtwork' => l10n.settingPrefetchArtwork,
      'settingBackgroundSync' => l10n.settingBackgroundSync,
      'settingStreamingQuality' => l10n.settingStreamingQuality,
      'settingWifiOnly' => l10n.settingWifiOnly,
      _ => key,
    };

/// Sync interval label (`30 min`, `2 h`).
String intervalLabel(AppLocalizations l10n, int minutes) =>
    minutes < 60 || minutes % 60 != 0 ? l10n.settingsMinutesShort(minutes) : l10n.settingsHoursShort(minutes ~/ 60);
