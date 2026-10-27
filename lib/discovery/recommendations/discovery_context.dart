import 'package:logging/logging.dart';

import '../../core/contracts/library.dart';
import '../../core/contracts/music_source.dart';
import '../../core/models/library.dart';
import '../../core/models/track.dart';
import '../../core/util/cancel_token.dart';
import '../../settings/settings_store.dart';
import 'library_pools.dart';
import 'source_gateway.dart';
import 'taste_profile.dart';

final _log = Logger('discovery.context');

/// Size limits and weights of the recommendation engine.
class DiscoveryTuning {
  const DiscoveryTuning({
    this.taste = const TasteTuning(),
    this.historyLimit = 1000,
    this.mixMinLength = 25,
    this.mixMaxLength = 50,
    this.mixMinPublish = 10,
    this.familiarShare = 0.6,
    this.maxArtistRun = 3,
    this.weeklyLength = 30,
    this.shelfLength = 30,
    this.shelfTtl = const Duration(hours: 6),
    this.weeklyTtl = const Duration(hours: 24),
    this.degradedTtl = const Duration(minutes: 30),
    this.minSiloTracks = 5,
  });

  final TasteTuning taste;

  /// Plays read from history for the taste profile.
  final int historyLimit;
  final int mixMinLength;
  final int mixMaxLength;

  /// Mixes with fewer tracks (not enough material yet) are not shown.
  final int mixMinPublish;

  /// Share of known (familiar) tracks in a Daily Mix.
  final double familiarShare;

  /// No artist more than this many times in a row in a mix.
  final int maxArtistRun;
  final int weeklyLength;
  final int shelfLength;
  final Duration shelfTtl;
  final Duration weeklyTtl;

  /// TTL for results computed while some source failed.
  final Duration degradedTtl;

  /// See `SiloGuard.apply`.
  final int minSiloTracks;
}

/// Dependencies shared by the builders.
class DiscoveryContext {
  DiscoveryContext({
    required this.registry,
    required this.gateway,
    required this.library,
    required this.history,
    required this.favorites,
    required this.settings,
    required this.clock,
    required this.tuning,
  });

  final SourceRegistry registry;
  final SourceGateway gateway;
  final LibraryPools library;
  final HistoryRepository history;
  final FavoritesRepository favorites;
  final SettingsStore settings;
  final DateTime Function() clock;
  final DiscoveryTuning tuning;

  bool get personalized => settings.current.privacy.personalizedRecommendations;

  bool get preferSiloed => gateway.preferSoundCloud;

  Future<List<PlayRecord>> loadHistory() async {
    try {
      return await history.history(limit: tuning.historyLimit);
    } catch (e) {
      _log.warning('Could not read history', e);
      return const [];
    }
  }

  Future<List<Track>> loadFavorites() async {
    try {
      return await favorites.favorites();
    } catch (e) {
      _log.warning('Could not read favorites', e);
      return const [];
    }
  }

  /// The on-device taste profile (history + favorites).
  Future<TasteProfile> buildProfile({CancelToken? cancel}) async {
    final results = await Future.wait([loadHistory(), loadFavorites()]);
    cancel?.throwIfCanceled();
    return TasteProfile.build(
      history: results[0] as List<PlayRecord>,
      favorites: results[1] as List<Track>,
      now: clock(),
      tuning: tuning.taste,
    );
  }

  /// The ready, enabled source that owns [t], if any.
  MusicSource? sourceOf(Track t) {
    if (settings.current.services.disabledSources.contains(t.sourceId)) return null;
    final s = registry.byId(t.sourceId);
    return s != null && s.isReady ? s : null;
  }
}
