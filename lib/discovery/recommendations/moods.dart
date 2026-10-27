import '../../core/contracts/discovery.dart';
import '../../core/sources/source_ids.dart';

/// A mood with search seeds and genre tags, optionally specialised per
/// source (genre names differ between providers: Audius "Lo-Fi",
/// Deezer "Electro", …).
class MoodDefinition {
  const MoodDefinition(this.category, {this.queriesBySource = const {}, this.genresBySource = const {}});

  final MoodCategory category;

  /// sourceId → search seeds (fallback: [MoodCategory.queries]).
  final Map<String, List<String>> queriesBySource;

  /// sourceId → genre names understood by that source's `trending(genre:)`
  /// (fallback: [MoodCategory.genres]; also used for local library tags).
  final Map<String, List<String>> genresBySource;

  List<String> queriesFor(String sourceId) => queriesBySource[sourceId] ?? category.queries;

  List<String> genresFor(String sourceId) => genresBySource[sourceId] ?? category.genres;
}

/// The built-in moods. Labels are localization keys (`moodFocus`, …).
///
/// Audius genre names come from its `/genres/popular` vocabulary; Deezer
/// names from `GET /genre` (both probed 2026-10). Unknown names are skipped
/// by the sources (the call fails in isolation).
abstract final class Moods {
  static const focus = MoodDefinition(
    MoodCategory(
      id: 'focus',
      labelKey: 'moodFocus',
      queries: ['focus music', 'deep focus', 'study beats', 'concentration'],
      genres: ['Ambient', 'Lo-Fi', 'Classical', 'Downtempo'],
    ),
    genresBySource: {
      SourceIds.audius: ['Lo-Fi', 'Ambient', 'Downtempo'],
      SourceIds.deezer: ['Classical', 'Electro'],
    },
  );

  static const chill = MoodDefinition(
    MoodCategory(
      id: 'chill',
      labelKey: 'moodChill',
      queries: ['chill', 'chillout', 'lofi chill', 'relaxing'],
      genres: ['Lo-Fi', 'Downtempo', 'Chillout', 'Ambient'],
    ),
    genresBySource: {
      SourceIds.audius: ['Lo-Fi', 'Downtempo', 'Tropical House'],
      SourceIds.deezer: ['R&B', 'Jazz'],
    },
  );

  static const workout = MoodDefinition(
    MoodCategory(
      id: 'workout',
      labelKey: 'moodWorkout',
      queries: ['workout', 'gym motivation', 'running', 'pump up'],
      genres: ['Electronic', 'Hip-Hop', 'Drum & Bass', 'Trap', 'Hardstyle'],
    ),
    genresBySource: {
      SourceIds.audius: ['Trap', 'Drum & Bass', 'Hardstyle', 'Hip-Hop/Rap'],
      SourceIds.deezer: ['Rap/Hip Hop', 'Dance', 'Metal'],
    },
  );

  static const party = MoodDefinition(
    MoodCategory(
      id: 'party',
      labelKey: 'moodParty',
      queries: ['party', 'dance party', 'club mix', 'party anthems'],
      genres: ['Dance', 'House', 'Pop', 'Electronic', 'Disco'],
    ),
    genresBySource: {
      SourceIds.audius: ['House', 'Tech House', 'Disco', 'Electronic'],
      SourceIds.deezer: ['Dance', 'Pop', 'Reggaeton'],
    },
  );

  static const sleep = MoodDefinition(
    MoodCategory(
      id: 'sleep',
      labelKey: 'moodSleep',
      queries: ['sleep music', 'calm piano', 'ambient sleep', 'night relaxation'],
      genres: ['Ambient', 'Classical', 'New Age'],
    ),
    genresBySource: {
      SourceIds.audius: ['Ambient', 'Classical'],
      SourceIds.deezer: ['Classical'],
    },
  );

  static const commute = MoodDefinition(
    MoodCategory(
      id: 'commute',
      labelKey: 'moodCommute',
      queries: ['road trip', 'driving music', 'commute', 'indie drive'],
      genres: ['Pop', 'Alternative', 'Rock', 'Indie'],
    ),
    genresBySource: {
      SourceIds.audius: ['Alternative', 'Pop', 'Rock'],
      SourceIds.deezer: ['Alternative', 'Rock', 'Pop'],
    },
  );

  static const happy = MoodDefinition(
    MoodCategory(
      id: 'happy',
      labelKey: 'moodHappy',
      queries: ['happy', 'feel good', 'good vibes', 'sunshine'],
      genres: ['Pop', 'Funk', 'Soul', 'Reggae'],
    ),
    genresBySource: {
      SourceIds.audius: ['Funk', 'Pop', 'Reggae'],
      SourceIds.deezer: ['Soul & Funk', 'Pop', 'Reggae'],
    },
  );

  static const melancholy = MoodDefinition(
    MoodCategory(
      id: 'melancholy',
      labelKey: 'moodMelancholy',
      queries: ['melancholy', 'sad songs', 'rainy day', 'heartbreak'],
      genres: ['Acoustic', 'Folk', 'Alternative', 'Ambient'],
    ),
    genresBySource: {
      SourceIds.audius: ['Acoustic', 'Folk', 'Alternative'],
      SourceIds.deezer: ['Folk', 'Alternative', 'Blues'],
    },
  );

  static const all = [focus, chill, workout, party, sleep, commute, happy, melancholy];

  /// Definition for a category (by id); custom categories get no overrides.
  static MoodDefinition of(MoodCategory category) {
    for (final m in all) {
      if (m.category.id == category.id) return m;
    }
    return MoodDefinition(category);
  }
}
