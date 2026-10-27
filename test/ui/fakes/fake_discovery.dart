import 'package:fermata/core/contracts/discovery.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';

/// Lyrics keyed by track id; [error] makes every lookup fail.
class FakeLyricsService implements LyricsService {
  final lyrics = <String, Lyrics>{};
  final requested = <String>[];
  Object? error;

  @override
  Future<Lyrics?> lyricsFor(Track track, {CancelToken? cancel}) async {
    requested.add(track.id);
    if (error != null) throw error!;
    return lyrics[track.id];
  }
}

/// Recommendations from preset lists. Set [error] to make shelf queries fail.
class FakeRecommendationService implements RecommendationService {
  List<Shelf> shelves = const [];
  List<Shelf> mixes = const [];
  Shelf? weekly;
  List<Track> similar = const [];
  List<Artist> artists = const [];
  List<Album> releases = const [];
  List<String> genreList = const ['Electronic', 'Jazz', 'Folk'];
  Map<String, List<Track>> genreTrackMap = const {};
  List<Track> moodTrackList = const [];
  List<Track> continuation = const [];
  Object? error;
  final calls = <String>[];

  Future<T> _r<T>(String name, T value) async {
    calls.add(name);
    if (error != null) throw error!;
    return value;
  }

  @override
  Future<List<Shelf>> homeShelves({CancelToken? cancel}) => _r('homeShelves', shelves);

  @override
  Future<List<Shelf>> dailyMixes({int count = 4, CancelToken? cancel}) => _r('dailyMixes', mixes.take(count).toList());

  @override
  Future<Shelf?> discoverWeekly({CancelToken? cancel}) => _r('discoverWeekly', weekly);

  @override
  Future<List<Track>> similarTo(Track track, {int limit = 25, CancelToken? cancel}) => _r('similarTo', similar.take(limit).toList());

  @override
  Future<List<Artist>> similarArtists(String artistName, {int limit = 12, CancelToken? cancel}) =>
      _r('similarArtists', artists.take(limit).toList());

  @override
  Future<List<Album>> newReleases({CancelToken? cancel}) => _r('newReleases', releases);

  @override
  Future<List<String>> genres({CancelToken? cancel}) => _r('genres', genreList);

  @override
  Future<List<Track>> genreTracks(String genre, {CancelToken? cancel}) => _r('genreTracks', genreTrackMap[genre] ?? const []);

  @override
  List<MoodCategory> moods = const [
    MoodCategory(id: 'focus', labelKey: 'moodFocus', queries: ['focus']),
    MoodCategory(id: 'chill', labelKey: 'moodChill', queries: ['chill']),
  ];

  @override
  Future<List<Track>> moodTracks(MoodCategory mood, {CancelToken? cancel}) => _r('moodTracks', moodTrackList);

  @override
  Future<List<Track>> smartQueueContinuation(List<Track> recent, {int limit = 10, CancelToken? cancel}) =>
      _r('smartQueueContinuation', continuation.take(limit).toList());
}
