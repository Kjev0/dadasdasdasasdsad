/// Stable shelf ids and the localization keys used as [Shelf.title].
///
/// `Shelf.title` is a localization key; parameters travel in
/// `Shelf.subtitle` (artist / genre name) or in the id (mix number):
///
/// | id                       | title key               | subtitle            |
/// |--------------------------|-------------------------|---------------------|
/// | `continueListening`      | `shelfContinueListening`| –                   |
/// | `dailyMix:<n>` (1–4)     | `shelfDailyMix`         | top artists, "A, B" |
/// | `discoverWeekly`         | `shelfDiscoverWeekly`   | –                   |
/// | `becauseYouLiked:<key>`  | `shelfBecauseYouLiked`  | artist name         |
/// | `trending`               | `shelfTrending`         | –                   |
/// | `newReleases`            | `shelfNewReleases`      | –                   |
/// | `genre:<name>`           | `shelfGenre`            | genre name          |
/// | `recentlyAdded`          | `shelfRecentlyAdded`    | –                   |
abstract final class ShelfIds {
  static const continueListening = 'continueListening';
  static const dailyMixPrefix = 'dailyMix:';
  static const discoverWeekly = 'discoverWeekly';
  static const becauseYouLikedPrefix = 'becauseYouLiked:';
  static const trending = 'trending';
  static const newReleases = 'newReleases';
  static const genrePrefix = 'genre:';
  static const recentlyAdded = 'recentlyAdded';

  static String dailyMix(int number) => '$dailyMixPrefix$number';

  /// 1-based Daily Mix number of [shelfId], or null.
  static int? dailyMixNumber(String shelfId) =>
      shelfId.startsWith(dailyMixPrefix) ? int.tryParse(shelfId.substring(dailyMixPrefix.length)) : null;

  static String becauseYouLiked(String artistKey) => '$becauseYouLikedPrefix$artistKey';

  static String genre(String name) => '$genrePrefix$name';

  /// Shelves derived from the user's history/favorites. Never produced
  /// when `privacy.personalizedRecommendations` is off.
  static bool isPersonal(String shelfId) =>
      shelfId == continueListening ||
      shelfId == discoverWeekly ||
      shelfId.startsWith(dailyMixPrefix) ||
      shelfId.startsWith(becauseYouLikedPrefix);
}

/// Localization keys for shelf titles (see [ShelfIds]).
abstract final class ShelfTitles {
  static const continueListening = 'shelfContinueListening';
  static const dailyMix = 'shelfDailyMix';
  static const discoverWeekly = 'shelfDiscoverWeekly';
  static const becauseYouLiked = 'shelfBecauseYouLiked';
  static const trending = 'shelfTrending';
  static const newReleases = 'shelfNewReleases';
  static const genre = 'shelfGenre';
  static const recentlyAdded = 'shelfRecentlyAdded';
}
