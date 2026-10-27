/// Exponential moving average of transfer speed.
///
/// Bytes are accumulated and folded into the average once per [window] so
/// bursty chunk delivery does not make the displayed speed jump around.
class SpeedMeter {
  SpeedMeter({this.alpha = 0.3, this.window = const Duration(milliseconds: 250), Stopwatch? stopwatch})
      : _clock = stopwatch ?? Stopwatch() {
    _clock.start();
  }

  /// Weight of the newest sample (0..1).
  final double alpha;
  final Duration window;
  final Stopwatch _clock;

  int _pendingBytes = 0;
  int _windowStartUs = 0;
  double? _ema;

  /// Smoothed bytes per second (0 until the first window completes).
  double get bytesPerSecond => _ema ?? 0;

  void add(int bytes) {
    _pendingBytes += bytes;
    final now = _clock.elapsedMicroseconds;
    final elapsed = now - _windowStartUs;
    if (elapsed < window.inMicroseconds) return;
    final sample = _pendingBytes * 1e6 / elapsed;
    _ema = _ema == null ? sample : alpha * sample + (1 - alpha) * _ema!;
    _pendingBytes = 0;
    _windowStartUs = now;
  }
}
