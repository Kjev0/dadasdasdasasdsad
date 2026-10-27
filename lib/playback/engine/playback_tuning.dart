import 'package:flutter/foundation.dart';

/// Timing constants of the engine. Production code uses the defaults; tests
/// may shorten them.
@immutable
class PlaybackTuning {
  const PlaybackTuning({
    this.tickInterval = const Duration(milliseconds: 250),
    this.persistDebounce = const Duration(seconds: 2),
    this.positionPersistInterval = const Duration(seconds: 10),
    this.prefetchLead = const Duration(seconds: 15),
    this.settingsWriteDebounce = const Duration(milliseconds: 500),
    this.sleepFadeDuration = const Duration(seconds: 8),
    this.fadeStep = const Duration(milliseconds: 50),
    this.manualCrossfadeMinPosition = const Duration(seconds: 1),
    this.duckGain = 0.3,
    this.smartQueueContext = 20,
  });

  /// Snapshot emission and housekeeping interval while playing (~4 Hz).
  final Duration tickInterval;

  /// Debounce for queue persistence after edits.
  final Duration persistDebounce;

  /// How often the position is persisted while playing.
  final Duration positionPersistInterval;

  /// Resolve the next item this long before the current one ends.
  final Duration prefetchLead;

  /// Debounce for writing volume/speed to settings.
  final Duration settingsWriteDebounce;

  /// Sleep timer fade-out length.
  final Duration sleepFadeDuration;

  /// Step of volume ramps (crossfade, sleep fade).
  final Duration fadeStep;

  /// Manual skips earlier than this into a track never crossfade.
  final Duration manualCrossfadeMinPosition;

  /// Linear gain while ducked for a transient interruption.
  final double duckGain;

  /// How many recent tracks are passed to the smart queue provider.
  final int smartQueueContext;
}
