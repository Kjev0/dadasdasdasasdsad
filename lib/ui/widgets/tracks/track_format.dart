/// `m:ss`, or `h:mm:ss` from one hour. Negative durations clamp to zero.
String formatDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Total duration of a set of tracks (unknown durations count as zero).
Duration totalDuration(Iterable<Duration?> durations) =>
    durations.fold(Duration.zero, (sum, d) => sum + (d ?? Duration.zero));
