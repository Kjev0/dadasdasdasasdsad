import 'dart:async';
import 'dart:collection';

import 'package:logging/logging.dart';

import '../../core/errors.dart';
import '../../core/util/cancel_token.dart';

final _log = Logger('discovery.calls');

/// A child token that is canceled when [parent] is canceled (or manually).
CancelToken childToken(CancelToken? parent) {
  final child = CancelToken();
  if (parent != null) {
    if (parent.isCanceled) {
      child.cancel();
    } else {
      unawaited(parent.whenCanceled.then((_) => child.cancel()));
    }
  }
  return child;
}

/// Limits how many source calls run at once so a Home refresh does not
/// fire dozens of parallel requests at a provider (rate limits).
class ConcurrencyLimiter {
  ConcurrencyLimiter(this.maxConcurrent) : assert(maxConcurrent > 0);

  final int maxConcurrent;
  int _active = 0;
  final _waiters = Queue<Completer<void>>();

  Future<T> run<T>(Future<T> Function() task) async {
    if (_active >= maxConcurrent) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _active++;
    try {
      return await task();
    } finally {
      _active--;
      if (_waiters.isNotEmpty) _waiters.removeFirst().complete();
    }
  }
}

/// Runs one provider call in isolation: failures (typed or not), timeouts
/// and unsupported operations become `null` so one broken source never
/// breaks a shelf. Only cancellation of [cancel] propagates.
Future<T?> attempt<T>(
  String what,
  Future<T> Function(CancelToken token) call, {
  CancelToken? cancel,
  Duration timeout = const Duration(seconds: 15),
  ConcurrencyLimiter? limiter,
  void Function(Object error)? onError,
}) async {
  cancel?.throwIfCanceled();
  final token = childToken(cancel);
  Future<T> run() {
    cancel?.throwIfCanceled();
    return call(token).timeout(timeout, onTimeout: () {
      token.cancel();
      throw TimeoutException('$what timed out', timeout);
    });
  }

  try {
    return await (limiter == null ? run() : limiter.run(run));
  } on OperationCanceledException {
    if (cancel?.isCanceled ?? false) rethrow;
    return null;
  } on UnsupportedSourceOperation catch (e) {
    _log.finer('$what unsupported: ${e.message}');
    return null;
  } on FermataException catch (e) {
    _log.fine('$what failed: ${e.code}');
    onError?.call(e);
    return null;
  } on TimeoutException catch (e) {
    _log.fine('$what timed out');
    onError?.call(e);
    return null;
  } catch (e) {
    // Non-typed failures (bugs or unexpected payloads in a provider) are
    // isolated too, but logged louder.
    if (cancel?.isCanceled ?? false) throw const OperationCanceledException();
    _log.warning('$what threw unexpectedly', e);
    onError?.call(e);
    return null;
  }
}
