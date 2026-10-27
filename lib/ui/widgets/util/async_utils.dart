/// Riverpod retry policy that never retries — for UI data whose failure is
/// shown to the user (with a manual retry) instead of being retried silently.
Duration? noRetry(int retryCount, Object error) => null;
