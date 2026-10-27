/// Per-source problems encountered while matching one track. Stored in
/// `TrackMatchResult.error` when any target source failed or no target
/// source could be searched; results from the healthy sources are still in
/// the result's candidates.
class SourceMatchFailures implements Exception {
  SourceMatchFailures({
    Map<String, Object> errors = const {},
    List<String> notReady = const [],
    required this.anySourceSearched,
  })  : errors = Map.unmodifiable(errors),
        notReady = List.unmodifiable(notReady);

  /// Source id → the error it threw (typically a `FermataException`:
  /// network, rate limit, missing credentials, auth required...).
  final Map<String, Object> errors;

  /// Target sources skipped because they were not ready (not connected,
  /// credentials missing) or not registered.
  final List<String> notReady;

  /// Whether at least one target source was searched successfully.
  final bool anySourceSearched;

  /// True when no target source could be searched, i.e. "not found" means
  /// "could not look", not "does not exist".
  bool get isTotalFailure => !anySourceSearched;

  @override
  String toString() {
    final parts = [
      for (final e in errors.entries) '${e.key}: ${e.value}',
      if (notReady.isNotEmpty) 'not ready: ${notReady.join(', ')}',
    ];
    return 'SourceMatchFailures(${parts.join('; ')})';
  }
}
