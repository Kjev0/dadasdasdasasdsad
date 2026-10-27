import '../../settings/app_settings.dart';
import '../backend/audio_backend.dart';

/// What the engine must do in response to an [AudioInterruption].
enum InterruptionAction { pause, resume, duck, unduck }

/// Fermata's audio-focus policy (players run with `handleInterruptions:
/// false`, so this is the only place deciding):
/// * permanent focus loss → pause (no automatic resume),
/// * transient loss → pause; resume afterwards when it was playing and
///   `resumeAfterInterruption` is on,
/// * transient "may duck" → lower the volume when
///   `duckOnTransientInterruption`, otherwise treat as transient loss,
/// * becoming noisy (headphones unplugged) → pause when
///   `pauseOnHeadphonesDisconnect`.
///
/// Any explicit user transport action cancels a pending automatic resume
/// ([userTookControl]).
class InterruptionPolicy {
  bool _resumeOnEnd = false;
  bool _ducked = false;

  bool get ducked => _ducked;
  bool get willResume => _resumeOnEnd;

  void userTookControl() => _resumeOnEnd = false;

  List<InterruptionAction> handle(
    AudioInterruption event, {
    required bool isPlaying,
    required PlaybackSettings settings,
  }) {
    switch (event.kind) {
      case AudioInterruptionKind.becomingNoisy:
        if (!settings.pauseOnHeadphonesDisconnect || !isPlaying) return const [];
        _resumeOnEnd = false;
        return const [InterruptionAction.pause];
      case AudioInterruptionKind.permanentLoss:
        if (!event.begin) return _end();
        _resumeOnEnd = false;
        return isPlaying ? const [InterruptionAction.pause] : const [];
      case AudioInterruptionKind.transientPause:
        if (!event.begin) return _end();
        return _transientPause(isPlaying, settings);
      case AudioInterruptionKind.transientDuck:
        if (!event.begin) return _end();
        if (settings.duckOnTransientInterruption) {
          if (_ducked) return const [];
          _ducked = true;
          return const [InterruptionAction.duck];
        }
        return _transientPause(isPlaying, settings);
    }
  }

  List<InterruptionAction> _transientPause(bool isPlaying, PlaybackSettings settings) {
    if (!isPlaying) return const [];
    _resumeOnEnd = settings.resumeAfterInterruption;
    return const [InterruptionAction.pause];
  }

  List<InterruptionAction> _end() {
    final actions = <InterruptionAction>[];
    if (_ducked) {
      _ducked = false;
      actions.add(InterruptionAction.unduck);
    }
    if (_resumeOnEnd) {
      _resumeOnEnd = false;
      actions.add(InterruptionAction.resume);
    }
    return actions;
  }
}
