import 'dart:async';

import '../errors.dart';

/// Cooperative cancellation for obsolete async work (e.g. a search request
/// superseded by a newer query). Pass it down; check [throwIfCanceled] between
/// steps, or listen to [whenCanceled] to abort I/O.
class CancelToken {
  final _completer = Completer<void>();

  bool get isCanceled => _completer.isCompleted;

  Future<void> get whenCanceled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void throwIfCanceled() {
    if (isCanceled) throw const OperationCanceledException();
  }
}

/// Keeps only the latest operation alive: calling [next] cancels the previous
/// token. Typical use: search-as-you-type.
class LatestOnly {
  CancelToken? _current;

  CancelToken next() {
    _current?.cancel();
    return _current = CancelToken();
  }

  void cancel() => _current?.cancel();
}
