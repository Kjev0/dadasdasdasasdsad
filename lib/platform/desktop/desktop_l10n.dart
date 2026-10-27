import 'dart:ui' show Locale, PlatformDispatcher;

import '../../l10n/gen/app_localizations.dart';
import '../../settings/settings_store.dart';

/// Resolves [AppLocalizations] outside the widget tree (tray menu, desktop
/// notifications, hotkey errors). Follows `AppSettings.localeCode`, then the
/// system language, and falls back to English for unsupported languages.
AppLocalizations desktopLocalizations(String? localeCode, {Locale? systemLocale}) {
  final supported = AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
  final candidates = <String?>[
    localeCode,
    (systemLocale ?? _systemLocale())?.languageCode,
    'en',
  ];
  for (final code in candidates) {
    if (code != null && supported.contains(code)) return lookupAppLocalizations(Locale(code));
  }
  return lookupAppLocalizations(const Locale('en'));
}

/// Convenience: a strings provider bound to a [SettingsStore], evaluated on
/// every call so locale changes apply immediately.
AppLocalizations Function() desktopStringsFor(SettingsStore settings) =>
    () => desktopLocalizations(settings.current.localeCode);

Locale? _systemLocale() {
  try {
    return PlatformDispatcher.instance.locale;
  } catch (_) {
    return null;
  }
}
