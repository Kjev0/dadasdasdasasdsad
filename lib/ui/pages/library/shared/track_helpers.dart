import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/track.dart';
import '../../../../core/sources/source_ids.dart';
import '../../../../core/sources/source_policies.dart';
import '../../../actions/track_actions.dart';
import '../../../widgets/tracks/track_menu.dart';

/// Tracks of [tracks] that may share a queue with [start] under the
/// providers' terms (SoundCloud streams play in their own queue; local
/// files join any queue). The start track keeps its position.
TrackPlayContext siloSafeContext(List<Track> tracks, int index, {String? origin, String? originLabel}) {
  final start = tracks[index];
  final silo = SourcePolicies.of(start.sourceId).siloedPlayback ? start.sourceId : null;
  final kept = <Track>[];
  var newIndex = 0;
  for (var i = 0; i < tracks.length; i++) {
    final t = tracks[i];
    if (i == index) {
      newIndex = kept.length;
      kept.add(t);
    } else if (SourcePolicies.canJoinSilo(silo, t.sourceId)) {
      kept.add(t);
    }
  }
  return TrackPlayContext(tracks: kept, index: newIndex, origin: origin, originLabel: originLabel);
}

/// Tracks that can be played inside Fermata (full or preview, or not yet
/// checked).
bool isPlayableInApp(Track t) =>
    t.availability.isPlayableInApp || t.availability.playback == PlaybackRights.unknown;

/// Plays [tracks] (or a shuffled order) respecting the SoundCloud silo: the
/// queue is built around the first playable track. [canPlay] decides which
/// tracks are queued (default: playable inside Fermata; imported playlists
/// also queue tracks with a linked match, which the stream resolver plays).
Future<void> playCollection(
  BuildContext context,
  WidgetRef ref,
  List<Track> tracks, {
  int startIndex = 0,
  bool shuffle = false,
  String? origin,
  String? originLabel,
  bool Function(Track track)? canPlay,
}) async {
  final test = canPlay ?? isPlayableInApp;
  final playable = [for (final t in tracks) if (test(t)) t];
  if (playable.isEmpty) return;
  var start = 0;
  if (!shuffle && startIndex > 0 && startIndex < tracks.length) {
    final i = playable.indexOf(tracks[startIndex]);
    if (i >= 0) start = i;
  }
  if (shuffle) start = Random().nextInt(playable.length);
  final ctx = siloSafeContext(playable, start, origin: origin, originLabel: originLabel);
  await TrackActions(context, ref).play(
    ctx.tracks,
    startIndex: ctx.index,
    origin: origin,
    originLabel: originLabel,
    shuffle: shuffle,
  );
}

/// Sorts source ids by the user's provider preference (unknown ids last, in
/// their original order).
List<String> orderByPreference(Iterable<String> ids, List<String> preference) {
  final list = ids.toList();
  int rank(String id) {
    final i = preference.indexOf(id);
    return i < 0 ? preference.length : i;
  }

  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
  indexed.sort((a, b) {
    final r = rank(a.$2).compareTo(rank(b.$2));
    return r != 0 ? r : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Whether any of [tracks] may be downloaded under its provider's policy
/// (never SoundCloud, Deezer, Spotify or YouTube).
bool anyDownloadable(Iterable<Track> tracks) => tracks.any(TrackActions.policyAllowsDownload);

/// True for sources whose tracks are only previews in Fermata.
bool isPreviewTrack(Track t) => t.availability.playback == PlaybackRights.preview;

/// True when [t] plays only in the provider's app/site.
bool isExternalTrack(Track t) => t.availability.playback == PlaybackRights.externalOnly;

/// Whether [sourceId] is a remote provider (not the local library).
bool isRemoteSource(String sourceId) => sourceId != SourceIds.local;

/// Album order: disc, track number, then title.
List<Track> sortAlbumTracks(List<Track> tracks) {
  final list = [...tracks];
  list.sort((a, b) {
    final d = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
    if (d != 0) return d;
    final n = (a.trackNumber ?? 1 << 20).compareTo(b.trackNumber ?? 1 << 20);
    if (n != 0) return n;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return list;
}

/// [siloSafeContext] for every row of a long list, computed once: one
/// filtered list per playback silo (open queue / SoundCloud), so tapping a
/// row never mixes SoundCloud streams with other services.
class SiloPartition {
  SiloPartition(this.tracks);

  final List<Track> tracks;
  final _lists = <String?, (List<Track>, Map<int, int>)>{};

  (List<Track>, Map<int, int>) _forSilo(String? silo) => _lists.putIfAbsent(silo, () {
        final list = <Track>[];
        final index = <int, int>{};
        for (var i = 0; i < tracks.length; i++) {
          if (SourcePolicies.canJoinSilo(silo, tracks[i].sourceId)) {
            index[i] = list.length;
            list.add(tracks[i]);
          }
        }
        return (list, index);
      });

  TrackPlayContext contextFor(int i, {String? origin, String? originLabel}) {
    final t = tracks[i];
    final silo = SourcePolicies.of(t.sourceId).siloedPlayback ? t.sourceId : null;
    final (list, index) = _forSilo(silo);
    return TrackPlayContext(tracks: list, index: index[i] ?? 0, origin: origin, originLabel: originLabel);
  }
}
