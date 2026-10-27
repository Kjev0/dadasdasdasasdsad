/// Discovery module: on-device recommendations, lyrics (LRCLIB + embedded)
/// and the opt-in update checker. See `lib/discovery/README.md`.
library;

export 'lyrics/embedded_lyrics.dart' show EmbeddedLyricsReader, readEmbeddedLyrics, readSidecarLrc;
export 'lyrics/lrc_parser.dart';
export 'lyrics/lrclib_client.dart';
export 'lyrics/lyrics_cache.dart' show LyricsCache, CachedLyrics;
export 'lyrics/lyrics_service_impl.dart';
export 'recommendations/discovery_context.dart' show DiscoveryTuning;
export 'recommendations/moods.dart';
export 'recommendations/recommendation_service_impl.dart';
export 'recommendations/shelf_ids.dart';
export 'recommendations/taste_profile.dart' show TasteTuning, TasteProfile, ArtistAffinity;
export 'update_checker.dart';
export 'updates/semver.dart';
