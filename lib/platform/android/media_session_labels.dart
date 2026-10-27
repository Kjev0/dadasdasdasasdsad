/// User-visible strings used by the Android media session: notification
/// button labels (read by TalkBack), notification channel name, and the
/// Android Auto / media browser folder titles.
///
/// The media session runs inside the audio service and may be created before
/// any widget (and therefore before `AppLocalizations`) exists, so these are
/// plain Dart constants selected by language code. English and Danish are
/// provided, matching the app's supported locales.
class MediaSessionLabels {
  const MediaSessionLabels({
    required this.previous,
    required this.play,
    required this.pause,
    required this.next,
    required this.like,
    required this.unlike,
    required this.recentlyPlayed,
    required this.playlists,
    required this.favorites,
    required this.searchResults,
    required this.oneTrack,
    required this.manyTracks,
    required this.channelName,
    required this.channelDescription,
  });

  final String previous;
  final String play;
  final String pause;
  final String next;
  final String like;
  final String unlike;
  final String recentlyPlayed;
  final String playlists;
  final String favorites;
  final String searchResults;

  /// Subtitle for a playlist with exactly one track.
  final String oneTrack;

  /// Subtitle template for playlists with 0 or 2+ tracks; `{count}` is
  /// replaced with the number.
  final String manyTracks;

  /// Name of the playback notification channel (Android system settings).
  final String channelName;
  final String channelDescription;

  /// "12 tracks" / "1 track".
  String trackCount(int count) => count == 1 ? oneTrack : manyTracks.replaceAll('{count}', '$count');

  static const en = MediaSessionLabels(
    previous: 'Previous',
    play: 'Play',
    pause: 'Pause',
    next: 'Next',
    like: 'Add to favorites',
    unlike: 'Remove from favorites',
    recentlyPlayed: 'Recently played',
    playlists: 'Playlists',
    favorites: 'Favorites',
    searchResults: 'Search results',
    oneTrack: '1 track',
    manyTracks: '{count} tracks',
    channelName: 'Playback',
    channelDescription: 'Playback controls for the current track',
  );

  static const da = MediaSessionLabels(
    previous: 'Forrige',
    play: 'Afspil',
    pause: 'Pause',
    next: 'Næste',
    like: 'Føj til favoritter',
    unlike: 'Fjern fra favoritter',
    recentlyPlayed: 'Senest afspillet',
    playlists: 'Playlister',
    favorites: 'Favoritter',
    searchResults: 'Søgeresultater',
    oneTrack: '1 nummer',
    manyTracks: '{count} numre',
    channelName: 'Afspilning',
    channelDescription: 'Afspilningsknapper for det aktuelle nummer',
  );

  /// Picks the labels for a language code or locale name such as `da`,
  /// `da_DK` or `da-DK`. Unknown or null codes fall back to English.
  static MediaSessionLabels forLocale(String? localeName) {
    final language = (localeName ?? '').split(RegExp('[_.-]')).first.toLowerCase();
    return switch (language) {
      'da' => da,
      _ => en,
    };
  }
}
