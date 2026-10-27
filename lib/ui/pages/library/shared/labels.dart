import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../../core/contracts/discovery.dart';
import '../../../../core/models/track.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// Localized title of a recommendation shelf. `Shelf.title` is a
/// localization key (see the discovery module's `ShelfTitles`); the
/// parameter travels in `Shelf.subtitle` or the id. Unknown keys are shown
/// literally (plugins may return plain titles).
String shelfTitle(AppLocalizations l10n, Shelf shelf) {
  final mix = _dailyMixNumber(shelf.id);
  return switch (shelf.title) {
    'shelfContinueListening' => l10n.shelfContinueListening,
    'shelfDailyMix' => l10n.shelfDailyMix(mix ?? 1),
    'shelfDiscoverWeekly' => l10n.shelfDiscoverWeekly,
    'shelfBecauseYouLiked' => l10n.shelfBecauseYouLiked(shelf.subtitle ?? ''),
    'shelfTrending' => l10n.shelfTrending,
    'shelfNewReleases' => l10n.shelfNewReleases,
    'shelfGenre' => shelf.subtitle ?? shelf.id.replaceFirst('genre:', ''),
    'shelfRecentlyAdded' => l10n.shelfRecentlyAdded,
    _ => shelf.title,
  };
}

/// Subtitle to show under a shelf title: null where the subtitle is already
/// part of the localized title (artist / genre name).
String? shelfSubtitle(AppLocalizations l10n, Shelf shelf) => switch (shelf.title) {
      'shelfBecauseYouLiked' || 'shelfGenre' => null,
      _ => shelf.subtitle,
    };

int? _dailyMixNumber(String id) => id.startsWith('dailyMix:') ? int.tryParse(id.substring('dailyMix:'.length)) : null;

/// Shelves that read as a "mix" card (one card = one playlist) rather than
/// a row of tracks.
bool isMixShelf(Shelf shelf) => shelf.kind == ShelfKind.mix || shelf.kind == ShelfKind.discoverWeekly;

/// Localized mood name for a `MoodCategory.labelKey`.
String moodLabel(AppLocalizations l10n, MoodCategory mood) => switch (mood.labelKey) {
      'moodFocus' => l10n.moodFocus,
      'moodChill' => l10n.moodChill,
      'moodWorkout' => l10n.moodWorkout,
      'moodParty' => l10n.moodParty,
      'moodSleep' => l10n.moodSleep,
      'moodCommute' => l10n.moodCommute,
      'moodHappy' => l10n.moodHappy,
      'moodMelancholy' => l10n.moodMelancholy,
      _ => mood.id.isEmpty ? mood.labelKey : mood.id[0].toUpperCase() + mood.id.substring(1),
    };

/// Locale name for `intl` formatters.
String localeNameOf(BuildContext context) => Localizations.localeOf(context).toString();

/// `12.3 MB` style sizes (binary units, locale-aware decimals).
String formatBytes(BuildContext context, int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 || value >= 100 || (value * 10).round() % 10 == 0 ? 0 : 1;
  final f = NumberFormat.decimalPatternDigits(locale: localeNameOf(context), decimalDigits: digits);
  return '${f.format(value)} ${units[unit]}';
}

/// "1 h 23 min" / "12 min" (localized).
String formatLongDuration(AppLocalizations l10n, Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return l10n.pagesHoursMinutes(h, m);
  return l10n.pagesMinutes(d.inSeconds > 0 && m == 0 ? 1 : m);
}

/// "12 tracks · 48 min".
String trackStats(AppLocalizations l10n, List<Track> tracks) {
  final total = tracks.fold(Duration.zero, (sum, t) => sum + (t.duration ?? Duration.zero));
  final count = l10n.pagesTrackCount(tracks.length);
  return total == Duration.zero ? count : '$count · ${formatLongDuration(l10n, total)}';
}

/// "Today" / "Yesterday" / a localized date for day group headers.
String dayLabel(BuildContext context, AppLocalizations l10n, DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return l10n.pagesToday;
  if (diff == 1) return l10n.pagesYesterday;
  final locale = localeNameOf(context);
  if (diff < 7) return DateFormat.EEEE(locale).format(d);
  return d.year == now.year ? DateFormat.MMMMd(locale).format(d) : DateFormat.yMMMMd(locale).format(d);
}

/// Short time of day ("14:05" / "2:05 PM").
String timeLabel(BuildContext context, DateTime t) => DateFormat.jm(localeNameOf(context)).format(t);

/// Short date ("27 Oct 2026").
String dateLabel(BuildContext context, DateTime t) => DateFormat.yMMMd(localeNameOf(context)).format(t);
