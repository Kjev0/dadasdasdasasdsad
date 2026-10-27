import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/contracts/discovery.dart';
import '../../core/errors.dart';
import '../../core/models/download.dart';
import '../../core/models/playback.dart';
import '../../core/models/track.dart';
import '../../core/util/cancel_token.dart';
import '../actions/track_actions.dart';
import '../widgets/util/async_utils.dart';

/// The most recent playback failure, as long as it concerns the current
/// queue item (cleared when the track changes).
class PlaybackFailureNotifier extends Notifier<PlaybackFailed?> {
  @override
  PlaybackFailed? build() {
    final playback = ref.watch(playbackProvider);
    final sub = playback.events.listen((e) {
      switch (e) {
        case PlaybackFailed():
          state = e;
        case TrackStarted():
          state = null;
        default:
          break;
      }
    });
    ref.onDispose(sub.cancel);
    return null;
  }

  void dismiss() => state = null;
}

final playbackFailureProvider = NotifierProvider<PlaybackFailureNotifier, PlaybackFailed?>(PlaybackFailureNotifier.new);

/// `AvailabilityReason` of the failure, when it is one.
String? failureReason(PlaybackFailed failure) {
  final e = failure.error;
  return switch (e) {
    UnplayableTrackException(:final reason) => reason,
    DownloadNotPermittedException(:final reason) => reason,
    _ => null,
  };
}

/// Lyrics for a track (null when none were found). Obsolete requests are
/// canceled when the provider is disposed.
final lyricsProvider = FutureProvider.autoDispose.family<Lyrics?, Track>(
  (ref, track) async {
    final cancel = CancelToken();
    ref.onDispose(cancel.cancel);
    return ref.watch(lyricsServiceProvider).lyricsFor(track, cancel: cancel);
  },
  retry: noRetry,
);

/// Download eligibility for a track — null when the provider's terms never
/// allow downloads (no download UI at all then).
final downloadEligibilityProvider = FutureProvider.autoDispose.family<DownloadEligibility?, Track>(
  (ref, track) async {
    ref.watch(downloadedIdsProvider);
    if (!TrackActions.policyAllowsDownload(track)) return null;
    return ref.watch(downloadManagerProvider).checkEligibility(track);
  },
  retry: noRetry,
);

/// Available output devices (desktop). Refresh with `ref.invalidate`.
final outputDevicesProvider = FutureProvider.autoDispose<List<AudioOutputDevice>>(
  (ref) => ref.watch(playbackProvider).outputDevices(),
  retry: noRetry,
);
