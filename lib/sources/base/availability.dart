import '../../core/errors.dart';
import '../../core/models/track.dart';

/// Common [TrackAvailability] mappers so every provider expresses the same
/// restriction the same way (the UI explains them by [AvailabilityReason]).
abstract final class Availabilities {
  /// Full in-app streaming. [downloadable] only when the provider explicitly
  /// permits downloading this track.
  static TrackAvailability stream({bool downloadable = false, DateTime? checkedAt}) => TrackAvailability(
        playback: PlaybackRights.full,
        offline: downloadable ? OfflineRights.downloadable : OfflineRights.streamOnly,
        checkedAt: checkedAt ?? DateTime.now(),
      );

  /// Only a preview may be played in-app (e.g. Deezer 30 s extracts).
  static TrackAvailability preview(
    Duration duration, {
    String reason = AvailabilityReason.previewOnly,
    DateTime? checkedAt,
  }) =>
      TrackAvailability(
        playback: PlaybackRights.preview,
        offline: OfflineRights.unavailable,
        reason: reason,
        previewDuration: duration,
        checkedAt: checkedAt ?? DateTime.now(),
      );

  /// Playback only in the provider's own app/site.
  static TrackAvailability externalOnly({
    String reason = AvailabilityReason.externalOnly,
    DateTime? checkedAt,
  }) =>
      TrackAvailability(
        playback: PlaybackRights.externalOnly,
        offline: OfflineRights.unavailable,
        reason: reason,
        checkedAt: checkedAt ?? DateTime.now(),
      );

  /// Not playable at all; [reason] is an [AvailabilityReason] code.
  /// [downloadable] covers the rare case where a provider allows fetching
  /// the original file but not streaming it.
  static TrackAvailability unavailable(String reason, {bool downloadable = false, DateTime? checkedAt}) =>
      TrackAvailability(
        playback: PlaybackRights.unavailable,
        offline: downloadable ? OfflineRights.downloadable : OfflineRights.unavailable,
        reason: reason,
        checkedAt: checkedAt ?? DateTime.now(),
      );

  /// A user-owned local file.
  static const TrackAvailability local = TrackAvailability.local();

  /// Throws [UnplayableTrackException] unless [track] can be played inside
  /// Fermata (full or preview).
  static void ensurePlayable(Track track) {
    final a = track.availability;
    if (a.isPlayableInApp) return;
    final reason = a.reason ??
        switch (a.playback) {
          PlaybackRights.externalOnly => AvailabilityReason.externalOnly,
          PlaybackRights.unavailable => AvailabilityReason.notStreamable,
          _ => AvailabilityReason.unknown,
        };
    throw UnplayableTrackException(track.id, reason);
  }

  /// Whether [availability] is older than [maxAge] (or was never verified),
  /// i.e. the source should re-check it before playing or downloading.
  static bool isStale(TrackAvailability availability, {Duration maxAge = const Duration(minutes: 10)}) {
    final at = availability.checkedAt;
    if (at == null || availability.playback == PlaybackRights.unknown) return true;
    return DateTime.now().difference(at) > maxAge;
  }
}
