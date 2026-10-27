import 'dart:async';

/// Creates a one-shot timer; injectable so tests can fire timers manually.
typedef TimerFactory = Timer Function(Duration duration, void Function() callback);

Timer _defaultTimer(Duration duration, void Function() callback) => Timer(duration, callback);

/// Groups rapid presses of the single headset button into one gesture.
///
/// audio_service maps `KEYCODE_HEADSETHOOK` / `KEYCODE_MEDIA_PLAY_PAUSE` to
/// `MediaButton.media` and delivers every press separately: it does NOT
/// implement the double/triple-press convention (its `onMediaButtonEvent`
/// override bypasses the framework's double-tap handling). This class adds
/// it: presses that follow each other within [window] are counted and
/// [onGesture] is called once with the final count (1, 2, 3; more presses are
/// reported as 3).
///
/// A single press is therefore acted upon after [window] (default 400 ms,
/// slightly above Android's 300 ms double-tap timeout).
class MediaButtonClickDetector {
  MediaButtonClickDetector({
    required this.onGesture,
    this.window = const Duration(milliseconds: 400),
    TimerFactory? timerFactory,
  }) : _timerFactory = timerFactory ?? _defaultTimer;

  /// Called with the number of presses (1..3).
  final FutureOr<void> Function(int presses) onGesture;
  final Duration window;
  final TimerFactory _timerFactory;

  Timer? _timer;
  int _count = 0;

  /// Registers one press of the media button.
  void press() {
    _timer?.cancel();
    _count++;
    if (_count >= 3) {
      _emit();
      return;
    }
    _timer = _timerFactory(window, _emit);
  }

  void _emit() {
    _timer?.cancel();
    _timer = null;
    final count = _count;
    _count = 0;
    if (count > 0) onGesture(count.clamp(1, 3));
  }

  /// Cancels a pending gesture.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _count = 0;
  }
}
