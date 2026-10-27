import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/discovery.dart';
import '../../../core/contracts/library.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/util/async_utils.dart';
import '../library/shared/revisions.dart';

/// Home shelves from the recommendation service (continue listening, daily
/// mixes, discover weekly, trending, new releases, recently added).
/// Refetches when history, library, favorites, sources or the
/// personalization setting change; empty shelves are dropped.
final homeShelvesProvider = FutureProvider.autoDispose<List<Shelf>>(
  (ref) async {
    watchLibrary(ref, LibraryTopic.history);
    watchLibrary(ref, LibraryTopic.tracks);
    watchLibrary(ref, LibraryTopic.favorites);
    watchSources(ref);
    ref.watch(settingsProvider.select((s) => s.privacy.personalizedRecommendations));
    final token = providerCancelToken(ref);
    final shelves = await ref.watch(recommendationsProvider).homeShelves(cancel: token);
    return [for (final s in shelves) if (s.tracks.isNotEmpty) s];
  },
  retry: noRetry,
);

/// Part of the day used for the Home greeting.
enum DayPart { morning, afternoon, evening, night }

DayPart dayPartOf(DateTime t) {
  final h = t.hour;
  if (h >= 5 && h < 12) return DayPart.morning;
  if (h >= 12 && h < 18) return DayPart.afternoon;
  if (h >= 18 && h < 23) return DayPart.evening;
  return DayPart.night;
}

/// Localized greeting for [t].
String greetingFor(AppLocalizations l10n, DateTime t) => switch (dayPartOf(t)) {
      DayPart.morning => l10n.homeGoodMorning,
      DayPart.afternoon => l10n.homeGoodAfternoon,
      DayPart.evening => l10n.homeGoodEvening,
      DayPart.night => l10n.homeGoodNight,
    };
