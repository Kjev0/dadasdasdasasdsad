/// Measures wall-clock time actually spent playing (pauses excluded).
class ListenClock {
  ListenClock(this._now);

  final DateTime Function() _now;
  Duration _accumulated = Duration.zero;
  DateTime? _runningSince;

  bool get running => _runningSince != null;

  void start() => _runningSince ??= _now();

  void pause() {
    final since = _runningSince;
    if (since == null) return;
    final delta = _now().difference(since);
    if (!delta.isNegative) _accumulated += delta;
    _runningSince = null;
  }

  Duration get elapsed {
    final since = _runningSince;
    if (since == null) return _accumulated;
    final delta = _now().difference(since);
    return delta.isNegative ? _accumulated : _accumulated + delta;
  }
}
