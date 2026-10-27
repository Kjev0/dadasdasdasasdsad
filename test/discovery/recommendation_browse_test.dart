import 'package:fermata/core/contracts/discovery.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/discovery/recommendations/moods.dart';
import 'package:fermata/discovery/util/text_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/world.dart';

void main() {
  late World w;

  setUp(() async => w = await World.create());
  tearDown(() async => w.dispose());

  group('smart queue continuation', () {
    test('related to the last tracks, never one of them, only in-app playable', () async {
      final recent = [w.known['Gamma']![5], w.known['Beta']![0], w.known['Beta']![1]];
      // The same song as a recent one on another provider must not come back.
      w.audius.related['beta0'] = [
        tr(SourceIds.audius, 'beta1dup', title: recent.last.title, artist: 'Beta'),
        ...w.audius.related['beta0']!,
      ];
      // Deezer previews are not acceptable for autoplay.
      w.deezer.catalog.add(tr(SourceIds.deezer, 'dzBeta', title: 'Beta beta0', artist: 'Beta'));
      w.deezer.related['dzBeta'] = [tr(SourceIds.deezer, 'dzPreviewOnly', title: 'Only Here', artist: 'Previewer')];

      final next = await w.service(persist: false).smartQueueContinuation(recent, limit: 10);
      expect(next, hasLength(10));
      final recentIds = {for (final t in recent) t.id};
      final recentKeys = {for (final t in recent) TextKeys.track(t)};
      for (final t in next) {
        expect(recentIds, isNot(contains(t.id)));
        expect(recentKeys, isNot(contains(TextKeys.track(t))));
        expect(t.availability.playback, PlaybackRights.full);
        expect(t.sourceId, isNot(SourceIds.deezer));
      }
      // Seeds are the most recent first: Beta-related songs lead.
      expect(next.first.id, startsWith('audius:rt_beta'));
    });

    test('stays inside the queue silo', () async {
      final sc = FakeSource(SourceIds.soundcloud);
      w.registry.register(sc);
      final scSeed = tr(SourceIds.soundcloud, 'seed', title: 'Cloud Seed', artist: 'Cloud Artist');
      sc.related['seed'] = [for (var i = 0; i < 4; i++) tr(SourceIds.soundcloud, 'c$i', artist: 'Cloud $i')];
      sc.catalog.addAll(w.known['Beta']!.map((t) => tr(SourceIds.soundcloud, 'x${t.sourceTrackId}', title: t.title, artist: 'Beta')));
      sc.related['xbeta0'] = [tr(SourceIds.soundcloud, 'scRel', artist: 'Cloud Rel')];

      // A SoundCloud queue continues with SoundCloud (or local) tracks only.
      final scNext = await w.service(persist: false).smartQueueContinuation([scSeed]);
      expect(scNext, isNotEmpty);
      expect(scNext.every((t) => t.sourceId == SourceIds.soundcloud || t.isLocal), isTrue);

      // An open queue never receives SoundCloud tracks.
      final openNext = await w.service(persist: false).smartQueueContinuation([w.known['Beta']![0]]);
      expect(openNext, isNotEmpty);
      expect(openNext.any((t) => t.sourceId == SourceIds.soundcloud), isFalse);
    });

    test('empty input → empty, failing sources → local fallbacks', () async {
      expect(await w.service(persist: false).smartQueueContinuation(const []), isEmpty);
      w.audius.failWith = const NetworkException('offline');
      w.deezer.failWith = const NetworkException('offline');
      final local = w.tracks.items.first;
      final next = await w.service(persist: false).smartQueueContinuation([local]);
      expect(next, isNotEmpty);
      expect(next.every((t) => t.isLocal && t.id != local.id), isTrue);
    });
  });

  group('similarTo', () {
    test('Deezer radio is resolved to playable equivalents; previews only after', () async {
      final seed = w.deezer.catalog.firstWhere((t) => t.sourceTrackId == 'dzSeed');
      final similar = await w.service(persist: false).similarTo(seed);
      final shared = similar.where((t) => t.title.startsWith('Shared Hit')).toList();
      expect(shared, hasLength(4));
      expect(shared.every((t) => t.sourceId == SourceIds.audius), isTrue, reason: 'resolved by search');
      expect(similar.any((t) => t.id == seed.id), isFalse);
      final firstPreview = similar.indexWhere((t) => t.availability.playback == PlaybackRights.preview);
      if (firstPreview >= 0) {
        expect(similar.skip(firstPreview).every((t) => t.availability.playback == PlaybackRights.preview), isTrue);
      }
      expect(similar.map((t) => t.id), contains('deezer:dzOnly'), reason: 'unresolvable kept as labeled preview');
    });

    test('uses the same artist when nothing related is known', () async {
      final seed = w.known['Alpha']![14];
      final similar = await w.service(persist: false).similarTo(seed, limit: 10);
      expect(similar, isNotEmpty);
      expect(similar.length, lessThanOrEqualTo(10));
      expect(similar.any((t) => t.id == seed.id), isFalse);
    });

    test('a SoundCloud seed only gets SoundCloud/local results', () async {
      final sc = FakeSource(SourceIds.soundcloud);
      w.registry.register(sc);
      final seed = tr(SourceIds.soundcloud, 'seed', title: 'Cloud Seed', artist: 'Alpha');
      sc.related['seed'] = [for (var i = 0; i < 3; i++) tr(SourceIds.soundcloud, 'c$i', artist: 'Cloud $i')];
      final similar = await w.service(persist: false).similarTo(seed);
      expect(similar, isNotEmpty);
      expect(similar.every((t) => t.sourceId == SourceIds.soundcloud || t.isLocal), isTrue);
    });
  });

  test('similarArtists merges sources and excludes the artist itself', () async {
    final artists = await w.service(persist: false).similarArtists('Alpha');
    expect([for (final a in artists) a.name], ['Rel One', 'Deezer Rel', 'Rel Two', 'Rel Three']);
  });

  test('genres: playable sources first, then metadata, then the library; deduped', () async {
    expect(await w.service(persist: false).genres(), ['Electronic', 'Rock', 'Jazz', 'Pop', 'Ambient']);
  });

  test('genreTracks: genre charts and local files; unknown genres are isolated', () async {
    final svc = w.service(persist: false);
    final ambient = await svc.genreTracks('Ambient');
    expect(ambient.where((t) => t.isLocal), hasLength(10));
    expect(ambient.where((t) => t.sourceId == SourceIds.audius), hasLength(8));
    // Deezer throws for "Ambient" (not a Deezer genre) — no effect.
    expect(w.deezer.calls['trending'], 1);
  });

  test('newReleases: playable first, deduped by artist+title', () async {
    final albums = await w.service(persist: false).newReleases();
    expect([for (final a in albums) a.id], ['audius:alb0', 'audius:alb1', 'audius:alb2']);
  });

  group('moods', () {
    test('eight moods with localization keys, search seeds and genre tags', () {
      final moods = w.service(persist: false).moods;
      expect([for (final m in moods) m.id], ['focus', 'chill', 'workout', 'party', 'sleep', 'commute', 'happy', 'melancholy']);
      for (final m in moods) {
        expect(m.labelKey, startsWith('mood'));
        expect(m.queries, isNotEmpty);
        expect(m.genres, isNotEmpty);
      }
      expect(Moods.focus.genresFor(SourceIds.deezer), isNot(Moods.focus.category.genres));
    });

    test('moodTracks combines search seeds, genre charts and local files', () async {
      final tracks = await w.service(persist: false).moodTracks(Moods.focus.category);
      final ids = {for (final t in tracks) t.id};
      expect(ids.where((id) => id.startsWith('audius:focus')), isNotEmpty, reason: 'search seeds');
      expect(ids.where((id) => id.startsWith('audius:gLo-Fi') || id.startsWith('audius:gAmbient')), isNotEmpty);
      expect(ids.where((id) => id.startsWith('local:')), isNotEmpty, reason: 'local Ambient files');
      expect(tracks.length, lessThanOrEqualTo(50));
    });
  });

  test('custom moods work without per-source overrides', () async {
    const custom = MoodCategory(id: 'x', labelKey: 'moodX', queries: ['focus music'], genres: ['Ambient']);
    final tracks = await w.service(persist: false).moodTracks(custom);
    expect(tracks, isNotEmpty);
  });

  test('provider calls are memoized across shelves', () async {
    final svc = w.service(persist: false);
    await svc.similarTo(w.known['Beta']![0]);
    final calls = w.audius.calls['relatedTracks'];
    await svc.smartQueueContinuation([w.known['Beta']![0]]);
    expect(w.audius.calls['relatedTracks'], calls);
  });

  test('timeouts isolate slow sources', () async {
    final slow = _SlowSource(SourceIds.jamendo);
    w.registry.register(slow);
    final svc = w.service(persist: false, sourceTimeout: const Duration(milliseconds: 300));
    final started = DateTime.now();
    final similar = await svc.similarArtists('Alpha');
    expect(similar, isNotEmpty, reason: 'the other sources still answer');
    expect(DateTime.now().difference(started), lessThan(const Duration(seconds: 5)));
    expect(slow.calls, isEmpty, reason: 'the hanging call is not counted as a result');
  });
}

/// A source whose artist search never answers (until the per-call timeout).
class _SlowSource extends FakeSource {
  _SlowSource(super.id);

  @override
  Future<Never> searchArtists(String query, {String? cursor, int limit = 20, cancel}) async {
    await Future<void>.delayed(const Duration(minutes: 5));
    throw StateError('unreachable');
  }
}
